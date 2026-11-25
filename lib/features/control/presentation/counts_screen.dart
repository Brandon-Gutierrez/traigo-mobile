import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/async_page.dart';
import '../../../core/ui/form_pieces.dart';
import '../../warehouse/application/warehouse_providers.dart';
import '../../warehouse/presentation/stock_screen.dart';
import 'panel_widgets.dart';

/// «Más» → Inventario y conteos: Jime ve lo contado contra el sistema. Los
/// ajustes son de almacén.
class ControlCountsScreen extends StatelessWidget {
  const ControlCountsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AsyncPage(
      provider: inventoryCountsProvider,
      header: [
        BackLink('Más', onTap: () => context.go(AppRoutes.more)),
        const PageTitle('Inventario y conteos', size: 28),
        const SizedBox(height: 4),
        const HintText('Exactitud física contra el sistema. Los ajustes los hace almacén.'),
        const SizedBox(height: 10),
      ],
      builder: (context, ref, counts) => [
        if (counts.isEmpty)
          Text(
            'Todavía no hay conteos.',
            style: AppText.body(15, FontWeight.w400, color: AppColors.muted),
          ),
        for (final count in counts)
          CountRow(count, onTap: () => context.go(AppRoutes.moreCount(count.id))),
      ],
    );
  }
}
