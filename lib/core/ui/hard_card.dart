import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Tarjeta del diseño «Feria y live»: borde de 2 px y sombra dura (sin
/// difuminado) desplazada hacia abajo y a la derecha.
class HardCard extends StatelessWidget {
  const HardCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.color = AppColors.card,
    this.borderColor = AppColors.ink,
    this.shadowColor = AppColors.ink,
    this.shadowOffset = 3,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final Color borderColor;
  final Color shadowColor;
  final double shadowOffset;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: borderColor, width: 2),
        boxShadow: [
          BoxShadow(color: shadowColor, offset: Offset(shadowOffset, shadowOffset)),
        ],
      ),
      child: child,
    );
  }
}
