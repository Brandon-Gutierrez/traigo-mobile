import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/cut_button.dart';
import '../../../core/ui/error_panel.dart';
import '../../../core/ui/form_pieces.dart';
import '../../../core/ui/refreshable_page.dart';
import '../../../core/ui/skeleton_block.dart';
import '../application/orders_providers.dart';
import '../domain/orders.dart';
import 'order_widgets.dart';

/// Los pedidos que registré, del más nuevo al más antiguo.
class MyOrdersScreen extends ConsumerStatefulWidget {
  const MyOrdersScreen({super.key});

  @override
  ConsumerState<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends ConsumerState<MyOrdersScreen> {
  OrderFilter _filter = OrderFilter.all;
  int _pages = 1;

  OrdersPageQuery _query(int page) => (filter: _filter, page: page);

  @override
  Widget build(BuildContext context) {
    final pages = [
      for (var page = 1; page <= _pages; page++)
        ref.watch(ordersPageProvider(_query(page))),
    ];
    final orders = [for (final page in pages) ...?page.value?.items];
    final first = pages.first;
    final last = pages.last;
    final today = ref.watch(todayProvider)();

    return RefreshablePage(
      onRefresh: () {
        ref.invalidate(ordersPageProvider);
        return ref.read(ordersPageProvider(_query(1)).future);
      },
      children: [
        BackLink('Inicio', onTap: () => context.go(AppRoutes.home)),
        Text('Mis pedidos', style: AppText.display(30, height: 1.1)),
        const SizedBox(height: 4),
        Text(
          'Solo se ven los que registraste tú',
          style: AppText.body(14, FontWeight.w400, color: AppColors.muted),
        ),
        const SizedBox(height: 6),
        UnderlineTabs<OrderFilter>(
          options: [for (final f in OrderFilter.values) (f, f.label)],
          selected: _filter,
          onSelected: (f) => setState(() {
            _filter = f;
            _pages = 1;
          }),
        ),
        const SizedBox(height: 4),
        if (orders.isEmpty && first.isLoading)
          for (var i = 0; i < 3; i++) ...const [SizedBox(height: 8), SkeletonBlock(height: 76)]
        else if (orders.isEmpty && first.hasError)
          ErrorPanel(
            message: errorMessage(first.error!),
            onRetry: () => ref.invalidate(ordersPageProvider(_query(1))),
          )
        else if (orders.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              _filter == OrderFilter.all
                  ? 'Todavía no registraste pedidos.'
                  : 'No tienes pedidos en «${_filter.label}».',
              style: AppText.body(15, FontWeight.w400, color: AppColors.muted),
            ),
          )
        else ...[
          for (final order in orders)
            _OrderRow(
              order: order,
              date: shortDate(order.createdAt, today),
              onTap: () => context.go(AppRoutes.order(order.id)),
            ),
          if (last.value?.hasMore ?? false) ...[
            const SizedBox(height: 12),
            CutButton(
              label: 'Ver pedidos anteriores',
              height: 48,
              fontSize: 17,
              color: AppColors.ink,
              onPressed: () => setState(() => _pages++),
            ),
          ],
        ],
      ],
    );
  }
}

class _OrderRow extends StatelessWidget {
  const _OrderRow({required this.order, required this.date, required this.onTap});

  final OrderSummary order;
  final String date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: InkWell(
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
                    Text(
                      '${order.number}  $date',
                      style: AppText.mono(11.5, color: AppColors.muted),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      order.customerName,
                      style: AppText.body(15.5, FontWeight.w600, height: 1.2),
                    ),
                    Text(
                      order.itemsLabel,
                      style: AppText.body(13, FontWeight.w400, color: AppColors.muted),
                    ),
                    const SizedBox(height: 3),
                    OrderStatusMark(order.status),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(order.total.format(), style: AppText.display(17)),
                  Text(
                    order.paymentMethod.label,
                    style: AppText.body(12, FontWeight.w400, color: AppColors.muted),
                  ),
                ],
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}
