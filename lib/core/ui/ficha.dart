/// Piezas de «ficha técnica»: regla de sección, filas con puntos guía,
/// regla de marcas, estado con forma y texto, y enlaces.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Regla gruesa de 3 px con la etiqueta de la sección y, a la derecha, una
/// acción opcional.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.label, {super.key, this.trailing});

  final String label;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ColoredBox(color: AppColors.ink, child: SizedBox(height: 3)),
        ConstrainedBox(
          constraints: BoxConstraints(minHeight: trailing == null ? 28 : 40),
          child: Row(
            children: [
              Expanded(child: Text(label.toUpperCase(), style: AppText.label())),
              ?trailing,
            ],
          ),
        ),
      ],
    );
  }
}

/// «Etiqueta ......... valor». La etiqueta puede partirse en dos líneas; el
/// valor siempre queda pegado a la derecha.
class LeaderRow extends StatelessWidget {
  const LeaderRow(
    this.label,
    this.value, {
    super.key,
    this.labelStyle,
    this.valueStyle,
  });

  final String label;
  final String value;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;

  /// Lo mínimo que se reserva entre la etiqueta y el valor.
  static const _minGap = 24.0;

  @override
  Widget build(BuildContext context) {
    final valueTextStyle = valueStyle ?? AppText.mono(15, weight: FontWeight.w700);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Se mide el valor primero: la etiqueta usa lo que queda y, si no
          // alcanza (letra grande o celular angosto), pasa a dos líneas.
          final measure = TextPainter(
            text: TextSpan(
              text: value,
              style: DefaultTextStyle.of(context).style.merge(valueTextStyle),
            ),
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
          )..layout();
          final labelWidth = math.max(
            0.0,
            constraints.maxWidth - measure.width.ceilToDouble() - _minGap,
          );
          measure.dispose();

          return Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: labelWidth),
                child: Text(label, style: labelStyle ?? AppText.body(15, FontWeight.w400)),
              ),
              const Expanded(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(8, 0, 8, 6),
                  child: SizedBox(height: 2, child: CustomPaint(painter: _DotsPainter())),
                ),
              ),
              Text(value, style: valueTextStyle),
            ],
          );
        },
      ),
    );
  }
}

class _DotsPainter extends CustomPainter {
  const _DotsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AppColors.dot;
    for (var x = 1.0; x < size.width; x += 5) {
      canvas.drawCircle(Offset(x, size.height / 2), 1.1, paint);
    }
  }

  @override
  bool shouldRepaint(_DotsPainter oldDelegate) => false;
}

/// Regla de [count] marcas con las primeras [filled] llenas.
class TickRuler extends StatelessWidget {
  const TickRuler({
    super.key,
    required this.count,
    required this.filled,
    required this.semanticLabel,
    this.height = 14,
    this.on = AppColors.violet,
    this.off = AppColors.rule,
    this.markAt,
  });

  final int count;
  final int filled;
  final String semanticLabel;
  final double height;
  final Color on;
  final Color off;

  /// Marca el mínimo (en %) con una línea de tinta que sobresale.
  final int? markAt;

  @override
  Widget build(BuildContext context) {
    final ticks = SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < count; i++) ...[
            if (i > 0) const SizedBox(width: 2),
            Expanded(child: ColoredBox(color: i < filled ? on : off)),
          ],
        ],
      ),
    );
    final markAt = this.markAt;
    return Semantics(
      label: semanticLabel,
      child: markAt == null
          ? ticks
          : Stack(
              clipBehavior: Clip.none,
              children: [
                ticks,
                Positioned.fill(
                  top: -4,
                  bottom: -4,
                  child: Align(
                    alignment: Alignment(markAt.clamp(0, 100) / 50 - 1, 0),
                    child: const ColoredBox(
                      color: AppColors.ink,
                      child: SizedBox(width: 3, height: double.infinity),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

enum MarkKind { ok, pending, bad }

/// Estado con forma y texto (no depende solo del color): lleno = bien, borde =
/// pendiente, rojo = no cumple.
class StatusMark extends StatelessWidget {
  const StatusMark(this.kind, this.text, {super.key});

  final MarkKind kind;
  final String text;

  @override
  Widget build(BuildContext context) {
    final color = switch (kind) {
      MarkKind.ok => AppColors.violet,
      MarkKind.pending => AppColors.ink,
      MarkKind.bad => AppColors.alert,
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: kind == MarkKind.pending ? null : color,
            border: Border.all(color: color, width: 2),
          ),
        ),
        const SizedBox(width: 6),
        Flexible(child: Text(text, style: AppText.body(13, FontWeight.w600, color: color))),
      ],
    );
  }
}

/// Enlace subrayado en violeta con un área de toque cómoda.
class TextLink extends StatelessWidget {
  const TextLink(this.label, {super.key, required this.onTap, this.color = AppColors.violet});

  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      link: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(
            label,
            style: AppText.body(14, FontWeight.w600, color: color, decoration: TextDecoration.underline),
          ),
        ),
      ),
    );
  }
}

/// Botón cuadrado de 48 con base de tinta (cerrar sesión).
class SquareIconButton extends StatelessWidget {
  const SquareIconButton({super.key, required this.icon, required this.tooltip, required this.onPressed});

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.alt,
        border: Border(bottom: BorderSide(color: AppColors.ink, width: 3)),
      ),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon, color: AppColors.ink),
        constraints: const BoxConstraints.tightFor(width: 48, height: 48),
        style: IconButton.styleFrom(shape: const RoundedRectangleBorder()),
      ),
    );
  }
}
