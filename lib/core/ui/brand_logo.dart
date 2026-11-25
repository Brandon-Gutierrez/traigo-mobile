import 'package:flutter/material.dart';

/// Logo oficial, recortado de los archivos del cliente.
enum BrandAsset {
  /// «TRAIGO» a color.
  wordmark('assets/brand/wordmark-color.png', 683 / 108, 'Traigo'),

  /// «TRAIGO» con «Accesorios & Tecnología».
  lockup('assets/brand/lockup-color.png', 683 / 186, 'Traigo, accesorios y tecnología');

  const BrandAsset(this.path, this.aspectRatio, this.semanticLabel);

  final String path;
  final double aspectRatio;
  final String semanticLabel;
}

class BrandLogo extends StatelessWidget {
  const BrandLogo(this.asset, {super.key, required this.width});

  final BrandAsset asset;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      asset.path,
      width: width,
      height: width / asset.aspectRatio,
      semanticLabel: asset.semanticLabel,
      filterQuality: FilterQuality.medium,
    );
  }
}
