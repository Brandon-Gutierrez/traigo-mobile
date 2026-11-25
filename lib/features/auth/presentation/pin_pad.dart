import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Los recuadros de un código numérico. El que sigue se marca en violeta.
///
/// Con [obscure] muestra un punto por número (PIN); si no, el número escrito
/// (código de verificación).
class DigitBoxes extends StatelessWidget {
  const DigitBoxes({
    super.key,
    required this.value,
    required this.length,
    required this.semanticName,
    this.obscure = true,
    this.boxWidth = 62,
    this.boxHeight = 66,
    this.gap = 12,
  });

  final String value;
  final int length;

  /// Para el lector de pantalla. Ej: «PIN».
  final String semanticName;
  final bool obscure;
  final double boxWidth;
  final double boxHeight;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$semanticName, ${value.length} de $length números ingresados',
      child: ExcludeSemantics(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // En pantallas angostas los recuadros se achican para no salirse.
            final width = math.min(
              boxWidth,
              (constraints.maxWidth - gap * (length - 1)) / length,
            );
            return Row(
              children: [
                for (var i = 0; i < length; i++) ...[
                  if (i > 0) SizedBox(width: gap),
                  _box(i, width),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _box(int index, double width) {
    final active = index == value.length;
    const side = BorderSide(color: AppColors.violet, width: 2);
    final filled = index < value.length;
    return Container(
      width: width,
      height: boxHeight,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: active ? AppColors.bg : AppColors.alt,
        border: active
            ? const Border(
                top: side,
                left: side,
                right: side,
                bottom: BorderSide(color: AppColors.violet, width: 3),
              )
            : const Border(bottom: BorderSide(color: AppColors.ink, width: 3)),
      ),
      child: Text(
        filled ? (obscure ? '•' : value[index]) : '',
        textScaler: TextScaler.noScaling,
        style: AppText.display(obscure ? 34 : 30),
      ),
    );
  }
}

/// Teclado numérico grande del diseño: 1 al 9, 0 y borrar.
class PinPad extends StatelessWidget {
  const PinPad({super.key, required this.onDigit, required this.onBackspace});

  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;

  static const _rows = [
    ['1', '2', '3'],
    ['4', '5', '6'],
    ['7', '8', '9'],
    ['', '0', '<'],
  ];

  static const _keyHeight = 58.0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var r = 0; r < _rows.length; r++) ...[
          if (r > 0) const SizedBox(height: 12),
          Row(
            children: [
              for (var c = 0; c < 3; c++) ...[
                if (c > 0) const SizedBox(width: 12),
                Expanded(child: _key(_rows[r][c])),
              ],
            ],
          ),
        ],
      ],
    );
  }

  Widget _key(String value) {
    if (value.isEmpty) return const SizedBox(height: _keyHeight);
    final erase = value == '<';
    final onTap = erase ? onBackspace : () => onDigit(value);
    return Semantics(
      key: ValueKey(erase ? 'pin-backspace' : 'pin-key-$value'),
      button: true,
      label: erase ? 'Borrar' : value,
      excludeSemantics: true,
      onTap: onTap,
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.ink, width: 3)),
        ),
        child: Material(
          color: AppColors.alt,
          child: InkWell(
            onTap: onTap,
            splashColor: AppColors.rule,
            highlightColor: AppColors.rule,
            child: SizedBox(
              height: _keyHeight,
              child: Center(
                child: erase
                    ? const Icon(Icons.backspace_outlined, size: 26, color: AppColors.ink)
                    : Text(
                        value,
                        textScaler: TextScaler.noScaling,
                        style: AppText.display(28, weight: FontWeight.w600),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
