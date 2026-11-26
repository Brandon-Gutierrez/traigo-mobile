/// Las 8 entregas de Sistemas y la revisión de cada una.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/async_page.dart';
import '../../../core/ui/chamfer.dart';
import '../../../core/ui/dialogs.dart';
import '../../../core/ui/ficha.dart';
import '../../../core/ui/form_pieces.dart';
import '../../team/domain/my_week.dart';
import '../../team/presentation/week_widgets.dart';
import '../application/control_providers.dart';
import 'panel_widgets.dart';

class DeliverablesScreen extends StatelessWidget {
  const DeliverablesScreen({
    super.key,
    required this.backLabel,
    required this.backRoute,
    required this.routeFor,
  });

  final String backLabel;
  final String backRoute;
  final String Function(String id) routeFor;

  @override
  Widget build(BuildContext context) {
    return AsyncPage(
      provider: controlDeliverablesProvider,
      header: [
        BackLink(backLabel, onTap: () => context.go(backRoute)),
        const PageTitle('Entregas de Sistemas', size: 28),
        const SizedBox(height: 4),
        Text(
          'El primer bono pide las 4 de cada uno, validadas y a tiempo.',
          style: AppText.body(14, FontWeight.w400, color: AppColors.muted),
        ),
      ],
      builder: (context, ref, deliverables) {
        final members = {for (final d in deliverables) d.memberName ?? ''};
        return [
          for (final member in members) ...[
            const SizedBox(height: 14),
            SectionHeader(
              '$member · ${deliverables.where((d) => d.memberName == member && d.status == DeliverableStatus.onTime).length} '
              'de ${deliverables.where((d) => d.memberName == member).length}',
            ),
            for (final d in deliverables.where((d) => d.memberName == member))
              OpenRow(
                onTap: () => context.go(routeFor(d.id)),
                children: [
                  Text(d.title, style: AppText.body(14.5, FontWeight.w600, height: 1.2)),
                  Text(
                    'VENCE ${dayMonth(d.dueOn)}'
                    '${d.deliveredOn == null ? '' : ' · REAL ${dayMonth(d.deliveredOn!)}'}',
                    style: AppText.mono(11.5, color: AppColors.muted),
                  ),
                  const SizedBox(height: 3),
                  StatusMark(deliverableMark(d.status), d.status.label),
                ],
              ),
          ],
          const SizedBox(height: 10),
          const HintText(
            'El avance parcial no habilita el bono. Valida solo con la prueba de '
            'aceptación y su evidencia.',
          ),
        ];
      },
    );
  }
}

class DeliverableReviewScreen extends StatelessWidget {
  const DeliverableReviewScreen({
    super.key,
    required this.deliverableId,
    required this.listRoute,
  });

  final String deliverableId;
  final String listRoute;

  @override
  Widget build(BuildContext context) {
    return AsyncPage(
      provider: controlDeliverablesProvider,
      header: [BackLink('Entregas', onTap: () => context.go(listRoute))],
      builder: (context, ref, deliverables) {
        final deliverable = deliverables.where((d) => d.id == deliverableId).firstOrNull;
        if (deliverable == null) {
          return [
            Text(
              'No encontramos esa entrega.',
              style: AppText.body(15, FontWeight.w400, color: AppColors.muted),
            ),
          ];
        }
        return [
          _ReviewBody(deliverable, listRoute: listRoute, key: ValueKey(deliverable.id)),
        ];
      },
    );
  }
}

class _ReviewBody extends ConsumerStatefulWidget {
  const _ReviewBody(this.deliverable, {required this.listRoute, super.key});

  final Deliverable deliverable;
  final String listRoute;

  @override
  ConsumerState<_ReviewBody> createState() => _ReviewBodyState();
}

class _ReviewBodyState extends ConsumerState<_ReviewBody> {
  /// La fecha real: viene la que puso quien entregó y Jime la comprueba.
  late DateTime? _deliveredOn = widget.deliverable.deliveredOn;

  Deliverable get _d => widget.deliverable;

  Future<void> _pickDate() async {
    final today = ref.read(todayProvider)();
    FocusManager.instance.primaryFocus?.unfocus();
    final picked = await showDatePicker(
      context: context,
      initialDate: _deliveredOn ?? today,
      firstDate: _d.dueOn.subtract(const Duration(days: 90)),
      lastDate: today,
      helpText: 'Fecha real de entrega',
    );
    if (picked != null && mounted) setState(() => _deliveredOn = picked);
  }

  Future<void> _validate() async {
    final date = _deliveredOn!;
    final ok = await runPanelAction(
      context,
      () => ref.read(reviewRepositoryProvider).validateDeliverable(_d.id, deliveredOn: date),
      success: 'Entrega validada.',
    );
    if (ok && mounted) context.go(widget.listRoute);
  }

  Future<void> _reject() async {
    final reason = await askReason(
      context,
      title: '¿No validar la entrega?',
      body: 'Quien entrega ve tu nota y puede volver a enviarla.',
      label: 'Qué falta',
      action: 'No validar',
      destructive: true,
    );
    if (reason == null || !mounted) return;
    final ok = await runPanelAction(
      context,
      () => ref.read(reviewRepositoryProvider).rejectDeliverable(_d.id, note: reason),
      success: 'Entrega no validada.',
    );
    if (ok && mounted) context.go(widget.listRoute);
  }

  @override
  Widget build(BuildContext context) {
    final d = _d;
    final url = d.evidenceUrl;
    final date = _deliveredOn;
    final dateText = date == null ? 'Sin fecha' : '${dayMonth(date)}/${date.year}';
    final late = date != null && date.isAfter(d.dueOn);
    final waiting = d.status == DeliverableStatus.inReview;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Revisar entrega', style: AppText.display(26, height: 1.15)),
        const SizedBox(height: 10),
        ChamferBox(
          color: AppColors.alt,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text((d.memberName ?? '').toUpperCase(),
                  style: AppText.mono(11.5, color: AppColors.muted)),
              Text(d.title, style: AppText.body(16, FontWeight.w600, height: 1.2)),
              const SizedBox(height: 8),
              Text('PRUEBA DE ACEPTACIÓN', style: AppText.label()),
              Text(d.acceptanceTest, style: AppText.body(14, FontWeight.w400, height: 1.3)),
              const SizedBox(height: 6),
              Text('VENCE ${dayMonth(d.dueOn)}', style: AppText.mono(12)),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: StatusMark(deliverableMark(d.status), d.status.label),
        ),
        if (d.reviewNote != null) ...[
          const SizedBox(height: 8),
          SideNote('Tu nota: ${d.reviewNote}', alert: true),
        ],
        const SizedBox(height: 12),
        const SectionHeader('Evidencia'),
        if (url == null)
          Text(
            'Todavía no la envió.',
            style: AppText.body(14, FontWeight.w400, color: AppColors.muted),
          )
        else
          AttachmentRow(
            kind: attachmentImage(url) == null ? EvidenceKind.link : EvidenceKind.photo,
            url: url,
            title: attachmentImage(url) == null
                ? url.replaceFirst(RegExp(r'^https?://'), '')
                : attachmentName(url),
          ),
        if (waiting) ...[
          const SizedBox(height: 12),
          Labeled(
            'Fecha real de entrega',
            child: PickerField(
              value: dateText,
              icon: Icons.calendar_today_outlined,
              semanticLabel: 'Fecha real de entrega: $dateText. Cambiar',
              onTap: _pickDate,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            late ? 'Quedará fuera de plazo: vencía el ${dayMonth(d.dueOn)}.' : 'Quedará a tiempo.',
            style: AppText.body(13, FontWeight.w600,
                color: late ? AppColors.alert : AppColors.violet),
          ),
          const SizedBox(height: 12),
          ActionButton(label: 'Validar', onPressed: date == null ? null : _validate),
          Center(child: TextLink('No validar…', color: AppColors.ink, onTap: _reject)),
        ],
      ],
    );
  }
}
