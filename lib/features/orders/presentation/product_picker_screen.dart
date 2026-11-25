import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/form_pieces.dart';
import '../../catalog/presentation/catalog_browser.dart';
import '../application/sale_draft.dart';

/// Elegir un producto para la venta, desde el mismo catálogo.
class ProductPickerScreen extends ConsumerWidget {
  const ProductPickerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(saleDraftProvider);

    return CatalogBrowser(
      header: [
        BackLink('Venta', onTap: () => context.go(AppRoutes.sell)),
        Text('Agregar producto', style: AppText.display(28, height: 1.1)),
      ],
      noteFor: (item) {
        final quantity = draft.quantityOf(item.id);
        return quantity == 0 ? null : 'Ya está en la venta: $quantity u.';
      },
      onSelect: (item) {
        if (item.soldOut) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text('${item.name} está agotado.')));
          return;
        }
        ref.read(saleDraftProvider.notifier).add(item);
        context.go(AppRoutes.sell);
      },
    );
  }
}
