import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'chamfer.dart';

/// Bloque gris que ocupa el lugar de un contenido mientras carga.
class SkeletonBlock extends StatelessWidget {
  const SkeletonBlock({super.key, required this.height, this.width});

  final double height;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return ChamferBox(
      color: AppColors.alt,
      padding: EdgeInsets.zero,
      child: SizedBox(height: height, width: width ?? double.infinity),
    );
  }
}
