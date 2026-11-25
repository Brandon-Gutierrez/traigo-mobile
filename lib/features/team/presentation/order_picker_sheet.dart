import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/ui/error_panel.dart';
import '../../../core/ui/ficha.dart';
import '../../../core/ui/skeleton_block.dart';
import '../../orders/application/orders_providers.dart';
import '../../orders/domain/orders.dart';

/// Elegir uno de mis pedidos como evidencia (los anulados no sirven).
Future<OrderSummary?> chooseOrderEvidence(BuildContext context) {
  return showModalBottomSheet<OrderSummary>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    builder: (context) => const _OrderPickerSheet(),
  );
}

class _OrderPickerSheet extends ConsumerStatefulWidget {
  const _OrderPickerSheet();

  @override
  ConsumerState<_OrderPickerSheet> createState() => _OrderPickerSheetState();
}

class _OrderPickerSheetState extends ConsumerState<_OrderPickerSheet> {
  int _pages = 1;

  static const _voided = {OrderStatus.cancelled, OrderStatus.expired, OrderStatus.returned};

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    var hasMore = false;
    for (var page = 1; page <= _pages; page++) {
      final query = (filter: OrderFilter.all, page: page);
      ref.watch(ordersPageProvider(query)).when(
            data: (result) {
              hasMore = page == _pages && result.page < result.lastPage;
              rows.addAll([
                for (final order in result.items)
                  if (!_voided.contains(order.status))
                    _OrderChoice(order, onTap: () => Navigator.pop(context, order)),
              ]);
            },
            loading: () => rows.add(const SkeletonBlock(height: 60)),
            error: (error, _) => rows.add(ErrorPanel(
              message: errorMessage(error),
              onRetry: () => ref.invalidate(ordersPageProvider(query)),
            )),
          );
    }

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.75),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
          children: [
            Text('Elige el pedido', style: AppText.display(22)),
            const SizedBox(height: 8),
            if (rows.isEmpty && !hasMore)
              Text(
                'Todavía no tienes pedidos que adjuntar.',
                style: AppText.body(15, FontWeight.w400, color: AppColors.muted),
              )
            else
              ...rows,
            if (hasMore)
              Center(
                child: TextLink('Ver más pedidos', onTap: () => setState(() => _pages++)),
              ),
          ],
        ),
      ),
    );
  }
}

class _OrderChoice extends StatelessWidget {
  const _OrderChoice(this.order, {required this.onTap});

  final OrderSummary order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.rule, width: 2)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(order.number, style: AppText.mono(11.5, color: AppColors.muted)),
                  Text(order.customerName, style: AppText.body(15, FontWeight.w600)),
                  Text(
                    '${order.itemsLabel} · ${order.status.label}',
                    style: AppText.body(13, FontWeight.w400, color: AppColors.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(order.total.format(), style: AppText.display(16)),
          ],
        ),
      ),
    );
  }
}
