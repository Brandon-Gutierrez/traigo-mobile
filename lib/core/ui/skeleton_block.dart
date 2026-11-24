import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Bloque gris que ocupa el lugar de un contenido mientras carga.
class SkeletonBlock extends StatelessWidget {
  const SkeletonBlock({super.key, required this.height, this.width});

  final double height;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: width,
      color: AppColors.line.withValues(alpha: 0.7),
    );
  }
}
