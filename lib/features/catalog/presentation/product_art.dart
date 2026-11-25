import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Imagen de un producto: la foto del servidor si existe; si no, el dibujo de
/// su categoría (los de los mockups).
class ProductTile extends StatelessWidget {
  const ProductTile({super.key, required this.category, this.imageUrl, this.size = 56});

  final String category;
  final String? imageUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final art = _ArtKind.of(category);
    final drawing = ColoredBox(
      color: art.background,
      child: Center(
        child: CustomPaint(size: Size.square(size * 0.8), painter: _ArtPainter(art)),
      ),
    );
    final url = imageUrl;
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: url == null || !url.startsWith('http')
            ? drawing
            : Image.network(url, fit: BoxFit.cover, errorBuilder: (_, _, _) => drawing),
      ),
    );
  }
}

enum _ArtKind {
  bottle(Color(0xFFCDEFFD)),
  planter(Color(0xFFCFFAF7)),
  toy(Color(0xFFE3D8FF));

  const _ArtKind(this.background);
  final Color background;

  static _ArtKind of(String category) => switch (category) {
        'Tomatodos' => bottle,
        'Macetas' => planter,
        _ => toy,
      };
}

/// Dibujos en una cuadrícula de 120 × 120. Un color nulo es solo contorno.
class _ArtPainter extends CustomPainter {
  const _ArtPainter(this.kind);

  final _ArtKind kind;

  static const _round = Radius.circular(8);

  List<(Path, Color?)> get _shapes => switch (kind) {
        _ArtKind.bottle => [
            (
              Path()
                ..moveTo(38, 30)
                ..lineTo(82, 30)
                ..lineTo(82, 108)
                ..arcToPoint(const Offset(74, 116), radius: _round)
                ..lineTo(46, 116)
                ..arcToPoint(const Offset(38, 108), radius: _round)
                ..close(),
              AppColors.violet,
            ),
            (Path()..addRect(const Rect.fromLTWH(42, 12, 36, 18)), AppColors.ink),
            (Path()..addRect(const Rect.fromLTWH(47, 52, 26, 20)), AppColors.bg),
            (
              Path()
                ..moveTo(38, 90)
                ..lineTo(82, 90),
              null,
            ),
          ],
        _ArtKind.planter => [
            (
              Path()
                ..moveTo(32, 50)
                ..lineTo(88, 50)
                ..lineTo(81, 102)
                ..arcToPoint(const Offset(73, 109), radius: _round)
                ..lineTo(47, 109)
                ..arcToPoint(const Offset(39, 102), radius: _round)
                ..close(),
              const Color(0xFFD9C2FF),
            ),
            (Path()..addRect(const Rect.fromLTWH(26, 38, 68, 14)), AppColors.violet),
            (
              Path()
                ..moveTo(60, 38)
                ..cubicTo(58, 22, 46, 14, 34, 14)
                ..cubicTo(36, 28, 46, 36, 60, 38)
                ..close(),
              AppColors.cyan,
            ),
            (
              Path()
                ..moveTo(60, 38)
                ..cubicTo(62, 24, 74, 16, 88, 18)
                ..cubicTo(84, 32, 74, 38, 60, 38)
                ..close(),
              AppColors.sky,
            ),
          ],
        _ArtKind.toy => [
            (
              Path()
                ..addPolygon(const [
                  Offset(10, 80),
                  Offset(18, 56),
                  Offset(72, 56),
                  Offset(92, 80),
                  Offset(100, 80),
                  Offset(100, 100),
                  Offset(10, 100),
                ], true),
              AppColors.violet,
            ),
            (
              Path()
                ..addPolygon(const [
                  Offset(24, 60),
                  Offset(44, 60),
                  Offset(44, 76),
                  Offset(18, 76),
                ], true)
                ..addPolygon(const [
                  Offset(52, 60),
                  Offset(68, 60),
                  Offset(80, 76),
                  Offset(52, 76),
                ], true),
              AppColors.cyan,
            ),
            (
              Path()..addOval(Rect.fromCircle(center: const Offset(40, 100), radius: 10)),
              AppColors.ink,
            ),
            (
              Path()..addOval(Rect.fromCircle(center: const Offset(80, 100), radius: 10)),
              AppColors.ink,
            ),
          ],
      };

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 120, size.height / 120);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.4
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..color = AppColors.ink;
    for (final (path, color) in _shapes) {
      if (color != null) canvas.drawPath(path, Paint()..color = color);
      canvas.drawPath(path, stroke);
    }
  }

  @override
  bool shouldRepaint(_ArtPainter oldDelegate) => oldDelegate.kind != kind;
}
