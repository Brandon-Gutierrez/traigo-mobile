import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_text.dart';

/// Barra inferior del diseño: Inicio, Catálogo, [Vender], Pedidos y Stock.
/// «Vender» es el botón central elevado; la pestaña activa lleva una barra
/// naranja arriba y su nombre en negrita.
class AppBottomBar extends StatelessWidget {
  const AppBottomBar({
    super.key,
    required this.currentIndex,
    required this.onSelected,
  });

  final int currentIndex;
  final ValueChanged<int> onSelected;

  static const _items = [
    (label: 'Inicio', icon: Icons.home_outlined),
    (label: 'Catálogo', icon: Icons.grid_view_outlined),
    (label: 'Vender', icon: Icons.add),
    (label: 'Pedidos', icon: Icons.receipt_long_outlined),
    (label: 'Stock', icon: Icons.inventory_2_outlined),
  ];

  static const _sellIndex = 2;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Container(
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: AppColors.card,
        border: Border(top: BorderSide(color: AppColors.ink, width: 2)),
      ),
      child: SizedBox(
        height: 72,
        child: Row(
          children: [
            for (var i = 0; i < _items.length; i++)
              Expanded(
                child: _BarItem(
                  label: _items[i].label,
                  icon: _items[i].icon,
                  selected: i == currentIndex,
                  raised: i == _sellIndex,
                  onTap: () => onSelected(i),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BarItem extends StatelessWidget {
  const _BarItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.raised,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final bool raised;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            Positioned(
              top: 0,
              left: 12,
              right: 12,
              height: 4,
              child: ColoredBox(color: selected ? AppColors.orange : Colors.transparent),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 26,
                    child: raised
                        ? OverflowBox(
                            maxHeight: 52,
                            alignment: Alignment.bottomCenter,
                            child: Container(
                              width: 52,
                              height: 52,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: AppColors.orange,
                                border: Border.all(color: AppColors.ink, width: 2),
                                boxShadow: const [
                                  BoxShadow(color: AppColors.ink, offset: Offset(3, 3)),
                                ],
                              ),
                              child: Icon(icon, size: 30, color: AppColors.ink),
                            ),
                          )
                        : Icon(icon, size: 26, color: AppColors.ink),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: AppText.body(
                      12,
                      selected ? FontWeight.w800 : FontWeight.w600,
                      color: selected ? AppColors.ink : AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
