import 'package:flutter/material.dart';

/// Esquina superior derecha cortada, como los cortes de la «R» y la «A» del logo.
class ChamferClipper extends CustomClipper<Path> {
  const ChamferClipper({this.cut = 14});

  final double cut;

  @override
  Path getClip(Size size) => Path()
    ..moveTo(0, 0)
    ..lineTo(size.width - cut, 0)
    ..lineTo(size.width, cut)
    ..lineTo(size.width, size.height)
    ..lineTo(0, size.height)
    ..close();

  @override
  bool shouldReclip(ChamferClipper oldClipper) => oldClipper.cut != cut;
}

/// Bloque de color plano con la esquina cortada.
class ChamferBox extends StatelessWidget {
  const ChamferBox({
    super.key,
    required this.color,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 14),
    this.cut = 14,
  });

  final Color color;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double cut;

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: ChamferClipper(cut: cut),
      child: ColoredBox(
        color: color,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
