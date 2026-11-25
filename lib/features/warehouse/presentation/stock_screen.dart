import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/cut_button.dart';
import '../../../core/ui/error_panel.dart';
import '../../../core/ui/form_pieces.dart';
import '../../../core/ui/refreshable_page.dart';
import '../../../core/ui/skeleton_block.dart';
import '../../catalog/presentation/catalog_browser.dart';
import '../../orders/presentation/order_widgets.dart';
import '../../team/presentation/week_widgets.dart' show OpenRow;
import '../application/warehouse_providers.dart';
import '../domain/warehouse.dart';

enum StockTab { products, counts }

/// «Stock y conteos»: el stock de cada producto (para registrar ingresos y
/// ajustes) y los conteos físicos.
class StockScreen extends ConsumerWidget {
  const StockScreen({super.key, this.tab = StockTab.products});

  final StockTab tab;

  List<Widget> _header(BuildContext context) => [
        BackLink('Inicio', onTap: () => context.go(AppRoutes.home)),
        Text('Stock y conteos', style: AppText.display(30, height: 1.1)),
        const SizedBox(height: 6),
        UnderlineTabs<StockTab>(
          options: const [(StockTab.products, 'Productos'), (StockTab.counts, 'Conteos')],
          selected: tab,
          onSelected: (value) => context.go(
            value == StockTab.counts ? AppRoutes.stockCounts : AppRoutes.stock,
          ),
        ),
      ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (tab == StockTab.products) {
      return CatalogBrowser(
        header: _header(context),
        detail: ProductRowDetail.stock,
        onSelect: (item) => context.go(AppRoutes.stockProduct(item.id)),
      );
    }

    final counts = ref.watch(inventoryCountsProvider);
    return RefreshablePage(
      onRefresh: () {
        ref.invalidate(inventoryCountsProvider);
        return ref.read(inventoryCountsProvider.future);
      },
      children: [
        ..._header(context),
        const SizedBox(height: 12),
        CutButton(label: 'Nuevo conteo', onPressed: () => context.go(AppRoutes.newCount)),
        const SizedBox(height: 10),
        ...counts.when(
          data: (data) => data.isEmpty
              ? [
                  Text(
                    'Todavía no hay conteos.',
                    style: AppText.body(15, FontWeight.w400, color: AppColors.muted),
                  ),
                ]
              : [
                  for (final count in data)
                    CountRow(count, onTap: () => context.go(AppRoutes.count(count.id))),
                ],
          loading: () => const [SkeletonBlock(height: 70)],
          error: (error, _) => [
            ErrorPanel(
              message: errorMessage(error),
              onRetry: () => ref.invalidate(inventoryCountsProvider),
            ),
          ],
        ),
      ],
    );
  }
}

/// «2 productos · 1 con diferencia».
String countSummary(InventoryCount count) {
  final products = count.items.length == 1 ? '1 producto' : '${count.items.length} productos';
  final different = count.items.where((i) => i.difference != 0).length;
  if (different == 0) return '$products · todo cuadra';
  return '$products · $different con diferencia';
}

class CountRow extends StatelessWidget {
  const CountRow(this.count, {super.key, required this.onTap});

  final InventoryCount count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final date = weekdayDate(count.countedOn);
    final pending = count.items.where((i) => i.needsAdjustment).length;
    return OpenRow(
      onTap: onTap,
      children: [
        Text('${date[0].toUpperCase()}${date.substring(1)}',
            style: AppText.body(15, FontWeight.w600)),
        Text(countSummary(count),
            style: AppText.body(13, FontWeight.w400, color: AppColors.muted)),
        if (pending > 0)
          Text(
            pending == 1 ? '1 por ajustar' : '$pending por ajustar',
            style: AppText.body(13, FontWeight.w600, color: AppColors.alert),
          ),
      ],
    );
  }
}
