import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/async_page.dart';
import '../../../core/ui/form_pieces.dart';
import '../../team/presentation/week_widgets.dart' show OpenRow;
import '../application/control_providers.dart';
import '../domain/review.dart';
import 'panel_widgets.dart';

/// La bandeja de Jime: pagos, evidencias, caja y entregas por validar,
/// primero lo más antiguo.
class PendingScreen extends StatelessWidget {
  const PendingScreen({super.key, this.type});

  final PendingType? type;

  static String _tag(PendingType type) => switch (type) {
        PendingType.payment => 'PAGO',
        PendingType.evidence => 'EVIDENCIA',
        PendingType.cashClosing => 'CAJA',
        PendingType.deliverable => 'ENTREGA',
      };

  static String _route(PendingItem item) => switch (item.type) {
        PendingType.payment => AppRoutes.pendingPayment(item.id),
        PendingType.evidence => AppRoutes.pendingEvidence(item.id),
        PendingType.cashClosing => AppRoutes.pendingCash(item.id),
        PendingType.deliverable => AppRoutes.pendingDeliverable(item.id),
      };

  @override
  Widget build(BuildContext context) {
    return AsyncPage(
      key: ValueKey(type),
      provider: pendingListProvider(type),
      header: [
        const PageTitle('Pendientes'),
        const SizedBox(height: 4),
        UnderlineTabs<PendingType?>(
          options: [(null, 'Todo'), for (final t in PendingType.values) (t, t.label)],
          selected: type,
          onSelected: (value) => context.go(
            value == null ? AppRoutes.pending : AppRoutes.pendingOfType(value.apiValue),
          ),
        ),
      ],
      builder: (context, ref, items) {
        final now = ref.watch(nowProvider)();
        return [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              items.isEmpty
                  ? 'No queda nada por revisar.'
                  : '${items.length} por revisar · primero los más antiguos',
              style: AppText.body(14, FontWeight.w400, color: AppColors.muted),
            ),
          ),
          for (final item in items)
            OpenRow(
              onTap: () => context.go(_route(item)),
              children: [
                Wrap(
                  spacing: 8,
                  children: [
                    Text(
                      _tag(item.type),
                      style: AppText.mono(11, weight: FontWeight.w700, color: AppColors.violet),
                    ),
                    Text(timeAgo(item.createdAt, now),
                        style: AppText.mono(11.5, color: AppColors.muted)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(item.title, style: AppText.body(15.5, FontWeight.w600, height: 1.2)),
                Text(
                  item.amount == null
                      ? item.subtitle
                      : '${item.subtitle} · ${item.amount!.formatInline()}',
                  style: AppText.body(13, FontWeight.w400, color: AppColors.muted),
                ),
              ],
            ),
        ];
      },
    );
  }
}
