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
import '../../auth/application/session_controller.dart';
import '../../auth/presentation/auth_frame.dart' show FormError;
import '../../orders/domain/orders.dart';
import '../../orders/presentation/order_widgets.dart';
import '../application/team_providers.dart';
import '../domain/kpi.dart';
import '../domain/my_week.dart';
import 'order_picker_sheet.dart';
import 'submit_errors.dart';
import 'week_widgets.dart';

/// La evidencia de un indicador: lo enviado y, mientras Jime no la valide,
/// el formulario para subir más.
class IndicatorScreen extends ConsumerWidget {
  const IndicatorScreen({
    super.key,
    required this.tab,
    required this.resultId,
    this.weekNumber,
  });

  /// La pestaña desde la que se abrió (a la que se vuelve).
  final String tab;
  final String resultId;
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
          // Al refrescar se mantiene lo que ya estaba (y lo que se escribió).
          skipLoadingOnRefresh: true,
          data: (data) {
            final item = data.indicators
                .where((i) => i.indicator.id == resultId)
                .firstOrNull;
            if (item == null) {
              return [
                Text(
                  'No encontramos ese indicador en esta semana.',
                  style: AppText.body(15, FontWeight.w400, color: AppColors.muted),
                ),
              ];
            }
            return [_IndicatorBody(data, item, tab: tab)];
          },
          loading: () => const [
            SkeletonBlock(height: 100),
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

class _IndicatorBody extends ConsumerWidget {
  const _IndicatorBody(this.week, this.item, {required this.tab});

  final MyWeek week;
  final WeekIndicator item;
  final String tab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(todayProvider)();
    final canSell = ref.watch(sessionControllerProvider).value?.member.role.canSell ?? false;
    final canUpload = week.acceptsEvidence && !item.isValidated;
    final indicator = item.indicator;
    final target = '${kpiNumber(indicator.target)}'
        '${item.unit == KpiUnit.percent ? ' %' : ''}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(canUpload ? 'Subir evidencia' : 'Evidencia',
            style: AppText.display(28, height: 1.15)),
        const SizedBox(height: 12),
        ChamferBox(
          color: AppColors.alt,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(indicator.name, style: AppText.body(16, FontWeight.w600, height: 1.2)),
              const SizedBox(height: 2),
              Text(
                item.howVerified,
                style: AppText.body(13, FontWeight.w400, color: AppColors.muted, height: 1.3),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 16,
                children: [
                  for (final fact in [
                    'META $target',
                    'PESO ${(indicator.weight * 100).round()} %',
                    week.week.label.toUpperCase(),
                  ])
                    Text(fact, style: AppText.mono(12)),
                ],
              ),
            ],
          ),
        ),
        if (item.evidence.isNotEmpty) ...[
          const SizedBox(height: 14),
          const SectionHeader('Lo que enviaste'),
          for (final evidence in item.evidence) _SentEvidence(evidence, today),
        ],
        const SizedBox(height: 14),
        if (canUpload)
          _EvidenceForm(
            // Cada indicador tiene su propio formulario.
            key: ValueKey(indicator.id),
            resultId: indicator.id,
            canSell: canSell,
            onSent: () => context.go(tab),
          )
        else
          SideNote(
            item.isValidated
                ? 'Jime ya validó este indicador: no hace falta agregar más.'
                : 'Esta semana ya se cerró: no se puede subir más evidencia.',
          ),
      ],
    );
  }
}

class _SentEvidence extends StatelessWidget {
  const _SentEvidence(this.evidence, this.today);

  final Evidence evidence;
  final DateTime today;

  static String _title(Evidence e) => switch (e.kind) {
        EvidenceKind.photo => e.url == null ? 'Foto' : attachmentName(e.url!),
        EvidenceKind.link => e.url?.replaceFirst(RegExp(r'^https?://'), '') ?? 'Enlace',
        EvidenceKind.order => 'Pedido ${e.orderNumber ?? ''}'.trim(),
      };

  @override
  Widget build(BuildContext context) {
    final muted = AppText.body(12.5, FontWeight.w400, color: AppColors.muted, height: 1.3);
    final (kind, text) = switch (evidence.status) {
      EvidenceStatus.validated => (MarkKind.ok, 'Validada'),
      EvidenceStatus.observed => (MarkKind.bad, 'Observada'),
      EvidenceStatus.inReview || EvidenceStatus.missing => (MarkKind.pending, 'En revisión'),
    };
    return AttachmentRow(
      kind: evidence.kind,
      url: evidence.url,
      title: _title(evidence),
      children: [
        const SizedBox(height: 2),
        Text('Enviada ${longDate(evidence.submittedAt, today)}', style: muted),
        if (evidence.note != null) Text('«${evidence.note}»', style: muted),
        const SizedBox(height: 3),
        StatusMark(kind, text),
        if (evidence.reviewNote != null) ...[
          const SizedBox(height: 3),
          Text(
            'Jime: ${evidence.reviewNote}',
            style: AppText.body(12.5, FontWeight.w600, color: AppColors.alert, height: 1.3),
          ),
        ],
      ],
    );
  }
}

class _EvidenceForm extends ConsumerStatefulWidget {
  const _EvidenceForm({
    super.key,
    required this.resultId,
    required this.canSell,
    required this.onSent,
  });

  final String resultId;
  final bool canSell;
  final VoidCallback onSent;

  @override
  ConsumerState<_EvidenceForm> createState() => _EvidenceFormState();
}

class _EvidenceFormState extends ConsumerState<_EvidenceForm> {
  /// La misma mientras no cambie lo que se envía: un reintento no duplica.
  String _requestKey = const Uuid().v4();
  EvidenceKind _kind = EvidenceKind.photo;
  UploadFile? _photo;
  OrderSummary? _order;
  final _link = TextEditingController();
  final _note = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _link.dispose();
    _note.dispose();
    super.dispose();
  }

  /// Un cambio en lo que se envía es otro envío.
  void _edit([VoidCallback? change]) => setState(() {
        change?.call();
        _requestKey = const Uuid().v4();
        _error = null;
      });

  /// Lo que falta para poder enviar, o `null` si ya se puede.
  String? get _blockedReason => switch (_kind) {
        EvidenceKind.photo => _photo == null ? 'Elige una foto' : null,
        EvidenceKind.link => _link.text.trim().isEmpty
            ? 'Escribe el enlace'
            : (normalizeLink(_link.text) == null ? 'Revisa el enlace' : null),
        EvidenceKind.order => _order == null ? 'Elige un pedido' : null,
      };

  NewEvidence _build() {
    final note = _note.text.trim().isEmpty ? null : _note.text.trim();
    return switch (_kind) {
      EvidenceKind.photo =>
        NewEvidence.photo(clientUuid: _requestKey, file: _photo!, note: note),
      EvidenceKind.link => NewEvidence.link(
          clientUuid: _requestKey,
          url: normalizeLink(_link.text)!,
          note: note,
        ),
      EvidenceKind.order =>
        NewEvidence.order(clientUuid: _requestKey, orderId: _order!.id, note: note),
    };
  }

  Future<void> _send() async {
    FocusScope.of(context).unfocus();
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(teamRepositoryProvider).submitEvidence(widget.resultId, _build());
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Evidencia enviada. Jime la va a revisar.')),
      );
      refreshTeamData(ref);
      widget.onSent();
    } on ApiException catch (e) {
      HapticFeedback.heavyImpact();
      if (!mounted) return;
      setState(() => _error = submitErrorMessage(e));
      // Cambió algo en el servidor (por ejemplo, Jime ya la validó).
      if (e is ConflictException) refreshTeamData(ref);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _chooseOrder() async {
    final order = await chooseOrderEvidence(context);
    if (order != null && mounted) _edit(() => _order = order);
  }

  @override
  Widget build(BuildContext context) {
    final blocked = _blockedReason;
    final error = _error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Labeled(
          '¿Qué adjuntas?',
          child: ChoiceBlocks<EvidenceKind>(
            options: [
              for (final kind in EvidenceKind.values)
                if (kind != EvidenceKind.order || widget.canSell) (kind, kind.label),
            ],
            selected: _kind,
            onSelected: (kind) {
              if (!_busy && kind != _kind) _edit(() => _kind = kind);
            },
          ),
        ),
        const SizedBox(height: 12),
        switch (_kind) {
          EvidenceKind.photo => PhotoField(
              file: _photo,
              enabled: !_busy,
              onChanged: (photo) => _edit(() => _photo = photo),
            ),
          EvidenceKind.link => LabeledField(
              label: 'Enlace',
              controller: _link,
              hint: 'https://…',
              enabled: !_busy,
              keyboardType: TextInputType.url,
              inputFormatters: [LengthLimitingTextInputFormatter(500)],
              onChanged: (_) => _edit(),
            ),
          EvidenceKind.order => _OrderField(
              order: _order,
              onChoose: _busy ? null : _chooseOrder,
            ),
        },
        const SizedBox(height: 12),
        LabeledField(
          label: 'Nota para Jime (opcional)',
          controller: _note,
          hint: 'Explica lo que adjuntas',
          lines: 2,
          enabled: !_busy,
          textCapitalization: TextCapitalization.sentences,
          inputFormatters: [LengthLimitingTextInputFormatter(500)],
          onChanged: (_) => _edit(),
        ),
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

class _OrderField extends StatelessWidget {
  const _OrderField({required this.order, required this.onChoose});

  final OrderSummary? order;
  final VoidCallback? onChoose;

  @override
  Widget build(BuildContext context) {
    final order = this.order;
    if (order == null) {
      return CutButton(
        label: 'Elegir pedido',
        height: 48,
        fontSize: 17,
        color: AppColors.ink,
        onPressed: onChoose,
      );
    }
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${order.number} · ${order.customerName}',
                  style: AppText.body(15, FontWeight.w600)),
              Text(
                '${order.itemsLabel} · ${order.total.formatInline()}',
                style: AppText.body(13, FontWeight.w400, color: AppColors.muted),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        TextLink('Cambiar', onTap: () => onChoose?.call()),
      ],
    );
  }
}
