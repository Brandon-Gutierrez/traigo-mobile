import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/application/session_controller.dart';
import '../../orders/application/sale_draft.dart';
import '../application/catalog_providers.dart';
import 'catalog_browser.dart';

/// El catálogo único: todo el equipo lo consulta; quien vende agrega a la venta
/// desde la ficha.
class CatalogScreen extends ConsumerWidget {
  const CatalogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(catalogCategoriesProvider).value;
    final total = categories?.fold(0, (sum, c) => sum + c.count);
    final canSell =
        ref.watch(sessionControllerProvider).value?.member.role.canSell ?? false;
    final draft = canSell ? ref.watch(saleDraftProvider) : null;

    return CatalogBrowser(
      header: [
        Text('Catálogo', style: AppText.display(30, height: 1.1)),
        const SizedBox(height: 4),
        Text(
          total == null ? 'Precios por unidad y por mayor' : '$total productos',
          style: AppText.body(14, FontWeight.w400, color: AppColors.muted),
        ),
      ],
      noteFor: (item) {
        final quantity = draft?.quantityOf(item.id) ?? 0;
        return quantity == 0 ? null : 'En tu venta: $quantity u.';
      },
      onSelect: (item) => context.go(AppRoutes.product(item.id)),
    );
  }
}
