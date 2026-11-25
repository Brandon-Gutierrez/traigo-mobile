import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/ui/chamfer.dart';
import 'role_navigation.dart';

/// Barra inferior del diseño: la acción principal del rol va al centro, en un
/// bloque violeta elevado; la pestaña activa lleva un bloque cian detrás del
/// ícono y su nombre en negrita.
class AppBottomBar extends StatelessWidget {
  const AppBottomBar({
    super.key,
    required this.items,
    required this.currentBranch,
    required this.onSelected,
    this.pendingCount,
  });

  final List<NavItem> items;
  final int currentBranch;
  final ValueChanged<NavItem> onSelected;

  /// Cosas por revisar (solo Jime).
  final int? pendingCount;

  static const height = 84.0;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Container(
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: AppColors.bg,
        border: Border(top: BorderSide(color: AppColors.ink, width: 3)),
      ),
      child: SizedBox(
        height: height - 3,
        // La barra no crece con la letra del sistema más allá de lo que cabe.
        child: MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.2,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final item in items)
                  Expanded(
                    child: _BarItem(
                      item: item,
                      selected: item.branch == currentBranch,
                      count: item.showsPending ? pendingCount : null,
                      onTap: () => onSelected(item),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BarItem extends StatelessWidget {
  const _BarItem({
    required this.item,
    required this.selected,
    required this.count,
    required this.onTap,
  });

  final NavItem item;
  final bool selected;
  final int? count;
  final VoidCallback onTap;

  /// Alto reservado al ícono; el bloque central es más alto y sobresale.
  static const _iconSlot = 36.0;
  static const _centralSize = 56.0;

  @override
  Widget build(BuildContext context) {
    final count = this.count;
    final hasCount = count != null && count > 0;

    return Semantics(
      button: true,
      selected: selected,
      label: hasCount ? '${item.label}, $count por revisar' : item.label,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              SizedBox(
                height: _iconSlot,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.bottomCenter,
                  children: [
                    if (item.central) _central() else _plain(),
                    if (hasCount)
                      Positioned(
                        top: -2,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Transform.translate(
                            offset: const Offset(17, 0),
                            child: _Badge(count),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  item.label,
                  maxLines: 1,
                  style: AppText.body(
                    12.5,
                    selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? AppColors.ink : AppColors.muted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _plain() {
    final icon = SizedBox(
      width: 36,
      height: 32,
      child: Icon(item.icon, size: 24, color: AppColors.ink),
    );
    return Align(
      alignment: Alignment.center,
      child: selected
          ? ClipPath(
              clipper: const ChamferClipper(cut: 10),
              child: ColoredBox(color: AppColors.cyan, child: icon),
            )
          : icon,
    );
  }

  Widget _central() {
    return Positioned(
      bottom: 0,
      width: _centralSize,
      height: _centralSize,
      child: ClipPath(
        clipper: const ChamferClipper(),
        child: ColoredBox(
          color: AppColors.violet,
          child: Icon(item.icon, size: 28, color: AppColors.bg),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.count);

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 18),
      height: 18,
      padding: const EdgeInsets.symmetric(horizontal: 3),
      color: AppColors.ink,
      // `widthFactor` deja la caja del ancho del número (mínimo 18).
      child: Center(
        widthFactor: 1,
        child: Text(
          count > 99 ? '99+' : '$count',
          textScaler: TextScaler.noScaling,
          style: AppText.mono(11, weight: FontWeight.w700, color: AppColors.bg),
        ),
      ),
    );
  }
}
