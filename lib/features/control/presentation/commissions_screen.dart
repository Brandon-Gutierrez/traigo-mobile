import 'package:flutter/material.dart';
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
import '../../auth/application/session_controller.dart';
import '../../auth/domain/auth.dart';
import '../../team/presentation/week_widgets.dart' show SideNote;
import '../application/control_providers.dart';
import '../domain/payouts.dart';
import 'panel_widgets.dart';

const _months = [
  'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto',
  'septiembre', 'octubre', 'noviembre', 'diciembre',
];

String monthName(String key) => _months[int.parse(key.split('-')[1]) - 1];

/// `31 dic`.
String _shortDay(DateTime date) => '${date.day} ${_months[date.month - 1].substring(0, 3)}';

String _capitalized(String text) => '${text[0].toUpperCase()}${text.substring(1)}';

/// La comisión del mes de quienes venden. Jime la envía cuando el mes termina.
class CommissionsScreen extends ConsumerStatefulWidget {
  const CommissionsScreen({super.key, this.backToMore = false});

  /// Jime la abre desde «Más»; Dirección la tiene en su barra.
  final bool backToMore;

  @override
  ConsumerState<CommissionsScreen> createState() => _CommissionsScreenState();
}

class _CommissionsScreenState extends ConsumerState<CommissionsScreen> {
  /// El mes que tocó la persona; `null` = el que toca mirar.
  String? _chosen;

  @override
  Widget build(BuildContext context) {
    return AsyncPage(
      provider: commissionsViewProvider(_chosen),
      header: [
        if (widget.backToMore)
          BackLink('Más', onTap: () => context.go(AppRoutes.more)),
      ],
      builder: (context, ref, view) {
        final previous = view.previous;
        return [
          if (previous != null)
            UnderlineTabs<String>(
              options: [
                for (final key in [previous, view.current])
                  (key, _capitalized(monthName(key))),
              ],
              selected: view.data.month,
              onSelected: (month) => setState(() => _chosen = month),
            ),
          ..._content(context, ref, view.data),
        ];
      },
    );
  }

  List<Widget> _content(BuildContext context, WidgetRef ref, MonthCommissions data) {
    final role = ref.watch(sessionControllerProvider).value?.member.role;
    final today = ref.watch(todayProvider)();
    final settlesOn = data.settlesOn;
    final sendFrom = settlesOn?.add(const Duration(days: 1));
    final monthEnded = sendFrom != null && !today.isBefore(sendFrom);
    final total = data.total;
    final canSend = data.status == SettlementStatus.open ||
        data.status == SettlementStatus.returned;

    final String? blocked;
    if (!monthEnded) {
      blocked = sendFrom == null ? 'El mes no terminó' : 'Se envía desde el ${_shortDay(sendFrom)}';
    } else if (data.ratesPending) {
      blocked = 'Falta definir el %';
    } else {
      blocked = null;
    }

    return [
      PageTitle('Comisiones',
          subtitle: '${monthName(data.month)} · ${monthEnded ? 'mes terminado' : 'en curso'}'),
      const SizedBox(height: 10),
      if (data.ratesPending) ...[
        const SideNote(
          'Hay ventas cobradas sin % de comisión, así que faltan montos. El % de cada '
          'producto se propone en Precios y lo autoriza Dirección.',
        ),
        if (role == MemberRole.control)
          Align(
            alignment: Alignment.centerLeft,
            child: TextLink('Ir a Precios', onTap: () => context.go(AppRoutes.morePrices)),
          )
        else
          const SizedBox(height: 10),
      ],
      if (data.returnReason != null) ...[
        SideNote('Dirección la devolvió: ${data.returnReason}', alert: true),
        const SizedBox(height: 10),
      ],
      SizedBox(
        width: double.infinity,
        child: ChamferBox(
          color: AppColors.cyan,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('POR LIQUIDAR', style: AppText.label(color: AppColors.ink)),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  total?.formatFixed() ?? '[% por definir]',
                  style: total == null
                      ? AppText.mono(18, weight: FontWeight.w700)
                      : AppText.display(40, weight: FontWeight.w800, height: 1.1),
                ),
              ),
              if (settlesOn != null)
                Text(
                  'Se liquida el ${_shortDay(settlesOn)} · cobros y devoluciones descontados',
                  style: AppText.body(13.5, FontWeight.w400),
                ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),
      const SectionHeader('Por persona'),
      for (final row in data.members) _Person(row),
      const SizedBox(height: 8),
      const HintText(
        'Una persona por venta. Se paga una vez al mes y es independiente del bono '
        'semanal. Nadie puede cambiar la suya.',
      ),
      const SizedBox(height: 10),
      Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        children: [
          Text('Liquidación', style: AppText.body(14, FontWeight.w400)),
          StatusMark(
            data.status == SettlementStatus.authorized || data.status == SettlementStatus.paid
                ? MarkKind.ok
                : MarkKind.pending,
            data.status.label,
          ),
        ],
      ),
      if (role == MemberRole.control && canSend) ...[
        const SizedBox(height: 10),
        ActionButton(
          label: blocked ?? 'Enviar a Dirección',
          confirm: () => confirmAction(
            context,
            title: '¿Enviar la liquidación?',
            body: 'Dirección revisa y autoriza las comisiones de '
                '${monthName(data.month)}.',
            action: 'Enviar',
          ),
          onPressed: blocked != null
              ? null
              : () async {
                  if (!context.mounted) return;
                  await runPanelAction(
                    context,
                    () => ref.read(payoutsRepositoryProvider).sendCommissions(data.month),
                    success: 'Liquidación enviada a Dirección.',
                  );
                },
        ),
      ],
      if (role == MemberRole.control && data.status == SettlementStatus.authorized) ...[
        const SizedBox(height: 10),
        ActionButton(
          label: 'Marcar como pagada',
          confirm: () => confirmAction(
            context,
            title: '¿Marcar las comisiones como pagadas?',
            body: 'Queda registrado el pago de ${monthName(data.month)}.',
            action: 'Marcar pagada',
          ),
          onPressed: () async {
            if (!context.mounted) return;
            await runPanelAction(
              context,
              () => ref.read(payoutsRepositoryProvider).markCommissionsPaid(data.month),
              success: 'Comisiones marcadas como pagadas.',
            );
          },
        ),
      ],
    ];
  }
}

class _Person extends StatelessWidget {
  const _Person(this.row);

  final CommissionRow row;

  @override
  Widget build(BuildContext context) {
    final amount = row.amount;
    final sales = row.paidSales == 1 ? '1 venta cobrada' : '${row.paidSales} ventas cobradas';
    return Container(
      key: ValueKey('commission-${row.id}'),
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.rule, width: 2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: [
              Text(row.name, style: AppText.display(18)),
              Text(
                amount?.formatFixed() ?? '[% por definir]',
                style: amount == null
                    ? AppText.mono(11.5, color: AppColors.muted)
                    : AppText.mono(15, weight: FontWeight.w700),
              ),
            ],
          ),
          Text(sales, style: AppText.body(13, FontWeight.w400, color: AppColors.muted)),
          if (!row.adjustments.isZero)
            Text(
              'Incluye devoluciones: ${row.adjustments.formatFixed()}',
              style: AppText.body(12.5, FontWeight.w400, color: AppColors.alert),
            ),
        ],
      ),
    );
  }
}
