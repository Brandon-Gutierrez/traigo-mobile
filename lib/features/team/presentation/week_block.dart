import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/money/money.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/chamfer.dart';
import '../../../core/ui/ficha.dart';

/// El bloque cian del día: cuánto cobró el equipo frente a la meta de la
/// semana.
class WeekBlock extends StatelessWidget {
  const WeekBlock({
    super.key,
    required this.title,
    required this.percent,
    required this.collected,
    required this.target,
  });

  final String title;
  final int percent;
  final Money collected;
  final Money target;

  /// Debajo de este ancho el detalle pasa bajo la cifra grande.
  static const _sideBySideWidth = 270.0;

  @override
  Widget build(BuildContext context) {
    final figure = Text(
      '$percent %',
      maxLines: 1,
      softWrap: false,
      // La cifra ya es enorme: no necesita crecer más con la letra del sistema.
      textScaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.1),
      style: AppText.display(48, weight: FontWeight.w800, height: 1.05),
    );
    final detail = Text(
      'cobrado ${collected.formatInline()} de ${target.formatInline()}',
      style: AppText.body(14.5, FontWeight.w400, height: 1.25),
    );

    return SizedBox(
      width: double.infinity,
      child: ChamferBox(
        color: AppColors.cyan,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title.toUpperCase(), style: AppText.label(color: AppColors.ink)),
            const SizedBox(height: 2),
            LayoutBuilder(
              builder: (context, constraints) => constraints.maxWidth < _sideBySideWidth
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [figure, detail],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [figure, const SizedBox(width: 10), Flexible(child: detail)],
                    ),
            ),
            const SizedBox(height: 8),
            TickRuler(
              count: 20,
              filled: math.min(20, percent ~/ 5),
              semanticLabel: '$percent por ciento de la meta del equipo',
              on: AppColors.ink,
              off: AppColors.bg,
            ),
          ],
        ),
      ),
    );
  }
}
