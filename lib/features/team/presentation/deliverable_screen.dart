import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../app/app_routes.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/chamfer.dart';
import '../../../core/ui/cut_button.dart';
import '../../../core/ui/error_panel.dart';
import '../../../core/ui/ficha.dart';
import '../../../core/ui/form_pieces.dart';
import '../../../core/ui/photo_field.dart';
import '../../../core/ui/refreshable_page.dart';
import '../../../core/ui/skeleton_block.dart';
import '../../auth/presentation/auth_frame.dart' show FormError;
import '../application/team_providers.dart';
import '../domain/my_week.dart';
import 'submit_errors.dart';
import 'week_widgets.dart';

/// Una entrega técnica de Sistemas: su prueba de aceptación, lo enviado y,
/// mientras Jime no la valide, el formulario para enviarla.
class DeliverableScreen extends ConsumerWidget {
  const DeliverableScreen({
    super.key,
    required this.tab,
    required this.deliverableId,
    this.weekNumber,
  });

  final String tab;
  final String deliverableId;
  final int? weekNumber;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final week = ref.watch(myWeekProvider(weekNumber));
    final back = tab == AppRoutes.evidence ? 'Evidencia' : 'Mi semana';

    return RefreshablePage(
      onRefresh: () {
        ref.invalidate(myWeekProvider(weekNumber));
        return ref.read(myWeekProvider(weekNumber).future);
      },
      children: [
        BackLink(back, onTap: () => context.go(tab)),
        ...week.when(
          skipLoadingOnRefresh: true,
          data: (data) {
            final deliverable =
                data.deliverables.where((d) => d.id == deliverableId).firstOrNull;
            if (deliverable == null) {
              return [
                Text(
                  'No encontramos esa entrega en esta semana.',
                  style: AppText.body(15, FontWeight.w400, color: AppColors.muted),
                ),
              ];
            }
            return [_DeliverableBody(data, deliverable, tab: tab)];
          },
          loading: () => const [
            SkeletonBlock(height: 120),
            SizedBox(height: 14),
            SkeletonBlock(height: 160),
          ],
          error: (error, _) => [
            ErrorPanel(
              message: errorMessage(error),
              onRetry: () => ref.invalidate(myWeekProvider(weekNumber)),
            ),
          ],
        ),
      ],
    );
  }
}

class _DeliverableBody extends StatelessWidget {
  const _DeliverableBody(this.week, this.deliverable, {required this.tab});

  final MyWeek week;
  final Deliverable deliverable;
  final String tab;

  @override
  Widget build(BuildContext context) {
    final deliveredOn = deliverable.deliveredOn;
    final evidenceUrl = deliverable.evidenceUrl;
    final canSubmit = week.acceptsEvidence && !deliverable.isValidated;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Entrega técnica', style: AppText.display(28, height: 1.15)),
        const SizedBox(height: 12),
        ChamferBox(
          color: AppColors.alt,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(deliverable.title, style: AppText.body(16, FontWeight.w600, height: 1.2)),
              const SizedBox(height: 8),
              Text('PRUEBA DE ACEPTACIÓN', style: AppText.label()),
              const SizedBox(height: 2),
              Text(deliverable.acceptanceTest,
                  style: AppText.body(14, FontWeight.w400, height: 1.3)),
              const SizedBox(height: 6),
              Text('VENCE ${dayMonth(deliverable.dueOn)}', style: AppText.mono(12)),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: StatusMark(deliverableMark(deliverable.status), deliverable.status.label),
        ),
        if (deliverable.reviewNote != null) ...[
          const SizedBox(height: 8),
          SideNote('Jime: ${deliverable.reviewNote}', alert: true),
        ],
        if (evidenceUrl != null) ...[
          const SizedBox(height: 14),
          const SectionHeader('Lo que enviaste'),
          AttachmentRow(
            kind: attachmentImage(evidenceUrl) == null
                ? EvidenceKind.link
                : EvidenceKind.photo,
            url: evidenceUrl,
            title: attachmentImage(evidenceUrl) == null
                ? evidenceUrl.replaceFirst(RegExp(r'^https?://'), '')
                : attachmentName(evidenceUrl),
            children: [
              if (deliveredOn != null)
                Text(
                  'Fecha de entrega: ${dayMonth(deliveredOn)}',
                  style: AppText.body(12.5, FontWeight.w400, color: AppColors.muted),
                ),
            ],
          ),
        ],
        const SizedBox(height: 14),
        if (canSubmit)
          _DeliverableForm(
            key: ValueKey(deliverable.id),
            deliverable: deliverable,
            onSent: () => context.go(tab),
          )
        else
          SideNote(
            switch (deliverable.status) {
              DeliverableStatus.onTime => 'Jime ya la validó: llegó a tiempo.',
              DeliverableStatus.late => 'Jime la validó, pero fuera de plazo.',
              _ => 'Esta semana ya se cerró: no se puede enviar.',
            },
            alert: deliverable.status == DeliverableStatus.late,
          ),
      ],
    );
  }
}

enum _Attach { photo, link }

class _DeliverableForm extends ConsumerStatefulWidget {
  const _DeliverableForm({super.key, required this.deliverable, required this.onSent});

  final Deliverable deliverable;
  final VoidCallback onSent;

  @override
  ConsumerState<_DeliverableForm> createState() => _DeliverableFormState();
}

class _DeliverableFormState extends ConsumerState<_DeliverableForm> {
  String _requestKey = const Uuid().v4();
  late DateTime _deliveredOn = widget.deliverable.deliveredOn ?? _today;
  _Attach _attach = _Attach.photo;
  UploadFile? _photo;
  final _link = TextEditingController();
  bool _busy = false;
  String? _error;

  DateTime get _today {
    final now = ref.read(todayProvider)();
    return DateTime(now.year, now.month, now.day);
  }

  @override
  void dispose() {
    _link.dispose();
    super.dispose();
  }

  void _edit([VoidCallback? change]) => setState(() {
        change?.call();
        _requestKey = const Uuid().v4();
        _error = null;
      });

  String? get _blockedReason => switch (_attach) {
        _Attach.photo => _photo == null ? 'Elige una foto' : null,
        _Attach.link => _link.text.trim().isEmpty
            ? 'Escribe el enlace'
            : (normalizeLink(_link.text) == null ? 'Revisa el enlace' : null),
      };

  Future<void> _pickDate() async {
    final today = _today;
    final picked = await showDatePicker(
      context: context,
      initialDate: _deliveredOn.isAfter(today) ? today : _deliveredOn,
      firstDate: widget.deliverable.dueOn.subtract(const Duration(days: 90)),
      lastDate: today,
      helpText: 'Fecha real de entrega',
    );
    if (picked != null && mounted) _edit(() => _deliveredOn = picked);
  }

  Future<void> _send() async {
    FocusScope.of(context).unfocus();
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(teamRepositoryProvider).submitDeliverable(
            widget.deliverable.id,
            deliveredOn: _deliveredOn,
            clientUuid: _requestKey,
            file: _attach == _Attach.photo ? _photo : null,
            url: _attach == _Attach.link ? normalizeLink(_link.text) : null,
          );
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Entrega enviada. Jime la va a revisar.')),
      );
      refreshTeamData(ref);
      widget.onSent();
    } on ApiException catch (e) {
      HapticFeedback.heavyImpact();
      if (!mounted) return;
      setState(() => _error = submitErrorMessage(e));
      if (e is ConflictException) refreshTeamData(ref);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final blocked = _blockedReason;
    final error = _error;
    final due = widget.deliverable.dueOn;
    final isLate = _deliveredOn.isAfter(due);
    final date = '${dayMonth(_deliveredOn)}/${_deliveredOn.year}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.deliverable.status == DeliverableStatus.inReview) ...[
          Text(
            'Si la envías de nuevo, reemplaza la anterior.',
            style: AppText.body(13, FontWeight.w400, color: AppColors.muted),
          ),
          const SizedBox(height: 10),
        ],
        Labeled(
          'Fecha real de entrega',
          child: PickerField(
            value: date,
            icon: Icons.calendar_today_outlined,
            semanticLabel: 'Fecha real de entrega: $date. Cambiar',
            onTap: _busy ? null : _pickDate,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          isLate
              ? 'Con esta fecha queda fuera de plazo: vencía el ${dayMonth(due)}.'
              : 'Jime comprueba la fecha al validar.',
          style: AppText.body(
            13,
            isLate ? FontWeight.w600 : FontWeight.w400,
            color: isLate ? AppColors.alert : AppColors.muted,
          ),
        ),
        const SizedBox(height: 12),
        Labeled(
          '¿Qué adjuntas?',
          child: ChoiceBlocks<_Attach>(
            options: const [(_Attach.photo, 'Foto'), (_Attach.link, 'Enlace')],
            selected: _attach,
            onSelected: (value) {
              if (!_busy && value != _attach) _edit(() => _attach = value);
            },
          ),
        ),
        const SizedBox(height: 12),
        switch (_attach) {
          _Attach.photo => PhotoField(
              file: _photo,
              enabled: !_busy,
              onChanged: (photo) => _edit(() => _photo = photo),
            ),
          _Attach.link => LabeledField(
              label: 'Enlace',
              controller: _link,
              hint: 'https://…',
              enabled: !_busy,
              keyboardType: TextInputType.url,
              inputFormatters: [LengthLimitingTextInputFormatter(500)],
              onChanged: (_) => _edit(),
            ),
        },
        const SizedBox(height: 14),
        const ReviewSteps(),
        if (error != null) ...[const SizedBox(height: 12), FormError(error)],
        const SizedBox(height: 14),
        CutButton(
          label: _busy ? 'Enviando…' : (blocked ?? 'Enviar a Jime'),
          onPressed: blocked == null ? _send : null,
          busy: _busy,
        ),
      ],
    );
  }
}
