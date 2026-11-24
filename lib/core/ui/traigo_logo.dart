import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text.dart';

/// Logo PROVISIONAL: una T blanca sobre un círculo azul con un trazo naranja.
/// Se reemplaza por el logo real cuando exista el archivo
/// (assets/images/logo.png): solo hay que cambiar el contenido de este widget.
class TraigoLogo extends StatelessWidget {
  const TraigoLogo({super.key, this.size = 60});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Traigo',
      image: true,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.ink,
          border: Border.all(color: AppColors.ink, width: 2),
        ),
        child: ClipOval(
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                bottom: size * 0.16,
                left: size * 0.16,
                right: size * 0.16,
                height: size * 0.09,
                child: const ColoredBox(color: AppColors.orange),
              ),
              Text(
                'T',
                style: AppText.body(size * 0.56, FontWeight.w800, color: AppColors.card, height: 1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
