import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/async_page.dart';
import '../../../core/ui/chamfer.dart';
import '../../../core/ui/dialogs.dart';
import '../../../core/ui/ficha.dart';
import '../../../core/ui/form_pieces.dart';
import '../../orders/presentation/order_widgets.dart' show weekdayDate;
import '../../team/presentation/week_widgets.dart' show SideNote;
import '../application/control_providers.dart';
import '../domain/payouts.dart';
import 'panel_widgets.dart';

/// El cierre de la semana de Jime: los 4 controles, quienes siguen pendientes
/// y el envío a Dirección.
class WeeklyClosingScreen extends StatelessWidget {
  const WeeklyClosingScreen({super.key, this.weekNumber});

  /// `null`: la semana que falta cerrar.
  final int? weekNumber;

  @override
  Widget build(BuildContext context) {
    return AsyncPage(
      provider: weeklyClosingProvider(weekNumber),
      header: const [],
      builder: (context, ref, closing) => [
        PageTitle('Cierre de la semana', subtitle: closing.week.label),
        WeekNav(
          shown: closing.weekNumber,
          current: closing.currentWeek,
          chosen: weekNumber,
          onShow: (week) => context.go(AppRoutes.closeWeek(week)),
        ),
        const SizedBox(height: 10),
        _ClosingBody(closing, key: ValueKey((closing.weekNumber, closing.status))),
      ],
    );
  }
}

class _ClosingBody extends ConsumerStatefulWidget {
  const _ClosingBody(this.closing, {super.key});

  final WeeklyClosing closing;

  @override
  ConsumerState<_ClosingBody> createState() => _ClosingBodyState();
}

class _ClosingBodyState extends ConsumerState<_ClosingBody> {
  bool _duplicates = false;

  /// A quienes Jime va a cerrar como «no cumple», y con qué motivo.
  final Map<String, TextEditingController> _closures = {};
  final Set<String> _closing = {};
  final _observations = TextEditingController();

  @override
  void dispose() {
    for (final controller in _closures.values) {
      controller.dispose();
    }
    _observations.dispose();
    super.dispose();
  }

  WeeklyClosing get _data => widget.closing;

  bool get _editable =>
      _data.status == WeekClosingStatus.open || _data.status == WeekClosingStatus.returned;

  TextEditingController _reasonOf(String id) =>
      _closures.putIfAbsent(id, TextEditingController.new);

  String? get _blockedReason {
    if (!_data.paymentsReconciled.ok) return 'Faltan cobros por confirmar';
    if (!_data.kpiEvidence.ok) return 'Falta revisar evidencia';
    if (ref.watch(todayProvider)().isBefore(_data.sendableFrom)) {
      return 'Se envía desde el ${weekdayDate(_data.sendableFrom)}';
    }
    if (!_duplicates) return 'Confirma los duplicados';
    for (final member in _data.pendingMembers) {
      if (!_closing.contains(member.id)) return 'Resuelve a ${member.name}';
      if (_reasonOf(member.id).text.trim().isEmpty) return 'Falta un motivo';
    }
    return null;
  }

  Future<bool> _askSend() {
    final names = [
      for (final m in _data.pendingMembers)
        if (_closing.contains(m.id)) m.name,
    ];
    return confirmAction(
      context,
      title: '¿Enviar el cierre a Dirección?',
      body: names.isEmpty
          ? 'Dirección revisa y autoriza el pago.'
          : '${names.join(', ')} ${names.length == 1 ? 'quedará' : 'quedarán'} como '
              '«no cumple»: su parte no se reparte. Dirección ve el motivo.',
      action: 'Enviar',
    );
  }

  Future<void> _send() async {
    if (!mounted) return;
    final note = _observations.text.trim();
    await runPanelAction(
      context,
      () => ref.read(payoutsRepositoryProvider).sendWeeklyClosing(
            _data.weekNumber,
            duplicatesCleared: _duplicates,
            // Si alguien dejó de estar pendiente, su marca ya no cuenta.
            closePending: {
              for (final member in _data.pendingMembers)
                if (_closing.contains(member.id))
                  member.id: _reasonOf(member.id).text.trim(),
            },
            observations: note.isEmpty ? null : note,
          ),
      success: 'Cierre enviado a Dirección.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final closing = _data;
    final editable = _editable;
    final returned = closing.returnReason;
    final duplicatesOk = editable ? _duplicates : closing.duplicates.ok;
    final blocked = editable ? _blockedReason : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (returned != null) ...[
          SideNote('Dirección lo devolvió: $returned', alert: true),
          const SizedBox(height: 8),
        ],
        _Control(
          title: 'Cobros conciliados',
          check: closing.paymentsReconciled,
          action: closing.paymentsReconciled.ok
              ? null
              : TextLink('Ver pendientes', onTap: () => context.go(AppRoutes.pending)),
        ),
        _Control(
          title: 'KPI con evidencia',
          check: closing.kpiEvidence,
          action: closing.kpiEvidence.ok
              ? null
              : TextLink('Ver evidencias',
                  onTap: () => context.go(AppRoutes.pendingOfType('evidence'))),
        ),
        _Control(
          title: 'Duplicados depurados',
          check: ClosingCheck(ok: duplicatesOk, detail: closing.duplicates.detail),
          onChanged: editable ? (v) => setState(() => _duplicates = v) : null,
          action: editable
              ? TextLink('Revisar pedidos', onTap: () => context.go(AppRoutes.moreOrders))
              : null,
        ),
        _Control(title: 'Aprueba Dirección', check: closing.direction),
        if (editable && closing.pendingMembers.isNotEmpty) ...[
          const SizedBox(height: 12),
          const SectionHeader('Siguen pendientes'),
          const HintText(
            'Carga o valida lo que les falta en Cumplimiento. Si no, ciérralos como '
            '«no cumple» con un motivo.',
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextLink('Ver cumplimiento',
                onTap: () => context.go(AppRoutes.complianceWeek(closing.weekNumber))),
          ),
          for (final member in closing.pendingMembers) _pendingMember(member),
        ],
        const SizedBox(height: 12),
        ChamferBox(
          color: AppColors.alt,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                children: [
                  Text('RESULTADO', style: AppText.label()),
                  StatusMark(
                    switch (closing.status) {
                      WeekClosingStatus.authorized || WeekClosingStatus.paid => MarkKind.ok,
                      WeekClosingStatus.returned => MarkKind.bad,
                      _ => MarkKind.pending,
                    },
                    closing.status.label,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                switch (closing.status) {
                  WeekClosingStatus.open || WeekClosingStatus.returned =>
                    'Pasa a «Autorizado» cuando Dirección apruebe.',
                  WeekClosingStatus.sent => 'Esperando a Dirección.',
                  WeekClosingStatus.authorized =>
                    'Ya puedes marcar los pagos en Bonos.',
                  WeekClosingStatus.paid => 'Todos los pagos de la semana están hechos.',
                },
                style: AppText.body(13.5, FontWeight.w400, height: 1.35),
              ),
            ],
          ),
        ),
        if (editable) ...[
          const SizedBox(height: 10),
          LabeledField(
            label: 'Observaciones (opcional)',
            controller: _observations,
            lines: 2,
            textCapitalization: TextCapitalization.sentences,
            inputFormatters: [LengthLimitingTextInputFormatter(500)],
          ),
          const SizedBox(height: 12),
          ActionButton(
            label: blocked ?? 'Enviar a Dirección',
            confirm: _askSend,
            onPressed: blocked == null ? _send : null,
          ),
        ] else ...[
          if (closing.observations != null) ...[
            const SizedBox(height: 10),
            SideNote('Observaciones: ${closing.observations}'),
          ],
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: TextLink('Ver bonos',
                onTap: () => context.go(AppRoutes.bonusesWeek(closing.weekNumber))),
          ),
        ],
      ],
    );
  }

  Widget _pendingMember(PendingMember member) {
    final closing = _closing.contains(member.id);
    return Container(
      key: ValueKey('pending-${member.id}'),
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.rule, width: 2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(member.name, style: AppText.body(15, FontWeight.w600)),
          Text(member.pendingReason,
              style: AppText.body(13, FontWeight.w400, color: AppColors.muted)),
          Row(
            children: [
              SquareCheck(
                checked: closing,
                label: 'Cerrar a ${member.name} como no cumple',
                onChanged: (v) => setState(
                  () => v ? _closing.add(member.id) : _closing.remove(member.id),
                ),
              ),
              Expanded(
                child: Text('Cerrar como «no cumple»',
                    style: AppText.body(14, FontWeight.w600)),
              ),
            ],
          ),
          if (closing) ...[
            LabeledField(
              label: 'Motivo para ${member.name}',
              controller: _reasonOf(member.id),
              lines: 2,
              textCapitalization: TextCapitalization.sentences,
              inputFormatters: [LengthLimitingTextInputFormatter(300)],
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 4),
          ],
        ],
      ),
    );
  }
}

/// Uno de los 4 controles. [onChanged] = lo confirma Jime.
class _Control extends StatelessWidget {
  const _Control({required this.title, required this.check, this.onChanged, this.action});

  final String title;
  final ClosingCheck check;
  final ValueChanged<bool>? onChanged;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 7),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.rule, width: 2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SquareCheck(checked: check.ok, onChanged: onChanged, label: title),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 6),
                Text(title, style: AppText.display(17)),
                Text(check.detail,
                    style: AppText.body(13, FontWeight.w400,
                        color: AppColors.muted, height: 1.3)),
                const SizedBox(height: 2),
                StatusMark(
                  check.ok ? MarkKind.ok : MarkKind.pending,
                  check.ok ? 'Sí' : 'Pendiente',
                ),
                ?action,
              ],
            ),
          ),
        ],
      ),
    );
  }
}
