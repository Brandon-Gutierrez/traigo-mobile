import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/cut_button.dart';
import '../../../core/ui/error_panel.dart';
import '../../../core/ui/ficha.dart';
import '../../../core/ui/form_pieces.dart';
import '../../../core/ui/refreshable_page.dart';
import '../../../core/ui/skeleton_block.dart';
import '../../auth/application/session_controller.dart';
import '../../orders/application/sale_draft.dart';
import '../../orders/presentation/commission_line.dart';
import '../application/catalog_providers.dart';
import '../domain/catalog.dart';
import 'product_art.dart';

/// La ficha de un producto: precios, inventario y (quien vende) su comisión.
class ProductScreen extends ConsumerWidget {
  const ProductScreen({super.key, required this.productId});

  final String productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final product = ref.watch(productProvider(productId));
    final canSell =
        ref.watch(sessionControllerProvider).value?.member.role.canSell ?? false;

    return RefreshablePage(
      onRefresh: () {
        ref.invalidate(productProvider(productId));
        return ref.read(productProvider(productId).future);
      },
      children: [
        BackLink('Catálogo', onTap: () => context.go(AppRoutes.catalog)),
        const SizedBox(height: 4),
        ...product.when(
          data: (item) => [
            _Heading(item),
            const SizedBox(height: 14),
            _Prices(item),
            const SizedBox(height: 14),
            _Stock(item),
            if (canSell) ...[
              const SizedBox(height: 14),
              const SectionHeader('Tu comisión'),
              CommissionLine(
                label: 'Por cada venta de este producto',
                percent: item.commissionPct,
              ),
              const SizedBox(height: 2),
              Text(
                'Se paga una vez al mes, solo por ventas cobradas.',
                style: AppText.body(12.5, FontWeight.w400, color: AppColors.muted),
              ),
              const SizedBox(height: 16),
              _AddToSale(item),
            ],
          ],
          loading: () => const [
            SkeletonBlock(height: 96),
            SizedBox(height: 14),
            SkeletonBlock(height: 120),
          ],
          error: (error, _) => [
            ErrorPanel(
              message: errorMessage(error),
              onRetry: () => ref.invalidate(productProvider(productId)),
            ),
          ],
        ),
      ],
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.item);

  final CatalogItem item;

  @override
  Widget build(BuildContext context) {
    final description = item.description;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            ProductTile(category: item.category, imageUrl: item.imageUrl, size: 96),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${item.itemCode} · ${item.category.toUpperCase()}',
                    style: AppText.mono(12, color: AppColors.muted),
                  ),
                  const SizedBox(height: 4),
                  Text(item.name, style: AppText.display(22, height: 1.15)),
                ],
              ),
            ),
          ],
        ),
        if (description != null) ...[
          const SizedBox(height: 10),
          Text(description, style: AppText.body(14, FontWeight.w400, height: 1.4)),
        ],
      ],
    );
  }
}

class _Prices extends StatelessWidget {
  const _Prices(this.item);

  final CatalogItem item;

  @override
  Widget build(BuildContext context) {
    final wholesale = item.priceWholesale;
    final minimum = item.wholesaleMinQty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader('Precios'),
        LeaderRow(
          'Minorista (1 unidad)',
          item.priceUnit.format(),
          labelStyle: AppText.body(17, FontWeight.w700),
          valueStyle: AppText.mono(17, weight: FontWeight.w700),
        ),
        if (wholesale != null && minimum != null) ...[
          LeaderRow('Mayorista, desde $minimum u.', wholesale.format()),
          const SizedBox(height: 4),
          Text(
            'Con $minimum unidades o más de este producto, cada una cuesta '
            '${wholesale.formatInline()}.',
            style: AppText.body(12.5, FontWeight.w400, color: AppColors.muted, height: 1.35),
          ),
        ],
      ],
    );
  }
}

class _Stock extends StatelessWidget {
  const _Stock(this.item);

  final CatalogItem item;

  @override
  Widget build(BuildContext context) {
    final muted = AppText.body(15, FontWeight.w400, color: AppColors.muted);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader('Inventario'),
        LeaderRow('Disponible', '${item.available} u.'),
        LeaderRow('Reservado por pedidos', '${item.reserved} u.', labelStyle: muted),
        LeaderRow('En bodega', '${item.stock} u.', labelStyle: muted),
      ],
    );
  }
}

class _AddToSale extends ConsumerWidget {
  const _AddToSale(this.item);

  final CatalogItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inSale = ref.watch(saleDraftProvider.select((d) => d.quantityOf(item.id)));

    if (inSale > 0) {
      return CutButton(
        label: 'En tu venta ($inSale u.) · ver',
        color: AppColors.ink,
        onPressed: () => context.go(AppRoutes.sell),
      );
    }
    return CutButton(
      label: item.soldOut ? 'Agotado' : 'Agregar a la venta',
      onPressed: item.soldOut
          ? null
          : () {
              ref.read(saleDraftProvider.notifier).add(item);
              context.go(AppRoutes.sell);
            },
    );
  }
}
