import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../core/money/money.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/async_page.dart';
import '../../../core/ui/chamfer.dart';
import '../../../core/ui/dialogs.dart';
import '../../../core/ui/ficha.dart';
import '../../../core/ui/form_pieces.dart';
import '../../orders/presentation/order_widgets.dart';
import '../../team/presentation/week_widgets.dart' show SideNote;
import '../../warehouse/domain/warehouse.dart';
import '../../warehouse/presentation/cash_table.dart';
import '../application/control_providers.dart';
import 'panel_widgets.dart';

/// Validar el cierre de caja que envió almacén, o pedir que lo corrija.
class CashReviewScreen extends StatelessWidget {
  const CashReviewScreen({super.key, required this.closingId});

  final String closingId;

  @override
  Widget build(BuildContext context) {
    return AsyncPage(
      provider: cashReviewProvider(closingId),
      header: [BackLink('Pendientes', onTap: () => context.go(AppRoutes.pending))],
      builder: (context, ref, day) {
        final today = ref.watch(todayProvider)();
        final sentAt = day.sentAt;
        final paid = day.paidOrders == 1 ? '1 pedido cobrado' : '${day.paidOrders} pedidos cobrados';

        Future<bool> askValidate() => confirmAction(
              context,
              title: '¿Validar el cierre?',
              body: 'El efectivo de ese día queda confirmado: cuenta para el bono y las '
                  'comisiones. No se puede deshacer.',
              action: 'Validar',
            );

        Future<void> validate() async {
          if (!context.mounted) return;
          final done = await runPanelAction(
            context,
            () => ref.read(reviewRepositoryProvider).validateCashClosing(closingId),
            success: 'Cierre validado.',
          );
          if (done && context.mounted) context.go(AppRoutes.pending);
        }

        Future<void> observe() async {
          final reason = await askReason(
            context,
            title: '¿Pedir una corrección?',
            body: 'Almacén ve tu nota y vuelve a enviar el cierre de ese día.',
            label: 'Qué corregir',
            action: 'Pedir corrección',
          );
          if (reason == null || !context.mounted) return;
          final done = await runPanelAction(
            context,
            () => ref.read(reviewRepositoryProvider).observeCashClosing(closingId, note: reason),
            success: 'Pediste la corrección.',
          );
          if (done && context.mounted) context.go(AppRoutes.pending);
        }

        final difference = day.lines.fold(
          Money.zero,
          (sum, l) => sum + (l.difference ?? Money.zero),
        );

        return [
          PageTitle(
            'Cierre de caja',
            size: 26,
            subtitle: [
              weekdayDate(day.businessDate),
              if (sentAt != null)
                'enviado por ${day.closedByName ?? 'almacén'} ${longDate(sentAt, today)}',
            ].join(' · '),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ChamferBox(
              color: AppColors.cyan,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('COBRADO SEGÚN PEDIDOS', style: AppText.label(color: AppColors.ink)),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(day.collected.format(),
                        style: AppText.display(40, weight: FontWeight.w800, height: 1.1)),
                  ),
                  Text(
                    day.pendingOrders == 0 ? paid : '$paid · ${day.pendingOrders} por cobrar',
                    style: AppText.body(13.5, FontWeight.w400),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          const SectionHeader('Por método de pago'),
          SentCashLines(day),
          if (difference.isZero && day.note == null) const SizedBox(height: 2),
          ...pendingCollections(day),
          const SizedBox(height: 10),
          const HintText(
            'Validar confirma el efectivo recibido. El valor del KPI «Cierre de caja '
            'diaria» lo cargas tú en Cumplimiento.',
          ),
          const SizedBox(height: 10),
          if (day.status == CashStatus.sent) ...[
            ActionButton(label: 'Validar cierre', confirm: askValidate, onPressed: validate),
            Center(
              child: TextLink('Pedir corrección', color: AppColors.ink, onTap: observe),
            ),
          ] else
            SideNote(
              day.status == CashStatus.observed
                  ? 'Pediste corregir: ${day.reviewNote}'
                  : 'Este cierre está ${day.status.label.toLowerCase()}.',
            ),
        ];
      },
    );
  }
}
