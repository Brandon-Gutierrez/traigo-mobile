import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Caja táctil del diseño: borde de 2 px, sombra dura y, al presionar, se
/// «hunde» hacia la sombra. Con `onTap == null` queda deshabilitada: fondo
/// apagado, sin sombra y con borde punteado.
///
/// La usan los botones y las teclas del PIN.
class HardPressable extends StatefulWidget {
  const HardPressable({
    super.key,
    required this.onTap,
    required this.child,
    this.color = AppColors.card,
    this.height,
    this.padding,
    this.shadowOffset = 3,
    this.semanticLabel,
  });

  final VoidCallback? onTap;
  final Widget child;
  final Color color;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final double shadowOffset;

  /// Para elementos sin texto (ej. la tecla de borrar).
  final String? semanticLabel;

  @override
  State<HardPressable> createState() => _HardPressableState();
}

class _HardPressableState extends State<HardPressable> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final sink = enabled && _pressed;
    final shadow = !enabled ? 0.0 : (sink ? 1.0 : widget.shadowOffset);
    final shift = sink ? widget.shadowOffset - 1 : 0.0;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    Widget box = AnimatedContainer(
      duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 70),
      transform: Matrix4.translationValues(shift, shift, 0),
      height: widget.height,
      padding: widget.padding,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: enabled ? widget.color : AppColors.disabled,
        border: enabled ? Border.all(color: AppColors.ink, width: 2) : null,
        boxShadow: enabled
            ? [BoxShadow(color: AppColors.ink, offset: Offset(shadow, shadow))]
            : null,
      ),
      child: widget.child,
    );

    if (!enabled) {
      box = CustomPaint(
        foregroundPainter: const _DashedBorderPainter(color: AppColors.muted),
        child: box,
      );
    }

    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => _setPressed(true) : null,
        onTapUp: enabled ? (_) => _setPressed(false) : null,
        onTapCancel: enabled ? () => _setPressed(false) : null,
        onTap: widget.onTap,
        child: box,
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color});

  final Color color;

  static const _dash = 7.0;
  static const _gap = 5.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final path = Path()..addRect(Rect.fromLTWH(1, 1, size.width - 2, size.height - 2));
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + _dash), paint);
        distance += _dash + _gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) => oldDelegate.color != color;
}
