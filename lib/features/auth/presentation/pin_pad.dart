import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/ui/hard_pressable.dart';

/// Los recuadros del PIN. Muestra un punto por cada número ingresado y marca
/// con sombra naranja el recuadro que sigue.
class PinBoxes extends StatelessWidget {
  const PinBoxes({super.key, required this.filled, this.length = 4});

  final int filled;
  final int length;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'PIN, $filled de $length números ingresados',
      child: ExcludeSemantics(
        child: Row(
          children: [
            for (var i = 0; i < length; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              Container(
                width: 62,
                height: 66,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.card,
                  border: Border.all(color: AppColors.ink, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: i == filled ? AppColors.orange : AppColors.ink,
                      offset: const Offset(3, 3),
                    ),
                  ],
                ),
                child: Text(
                  i < filled ? '•' : '',
                  style: AppText.body(34, FontWeight.w800, color: AppColors.ink),
                ),
              ),
            ],
          ],
        ),
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
    if (value.isEmpty) return const SizedBox(height: 62);
    if (value == '<') {
      return KeyedSubtree(
        key: const ValueKey('pin-backspace'),
        child: HardPressable(
          onTap: onBackspace,
          height: 62,
          semanticLabel: 'Borrar',
          child: const Icon(Icons.backspace_outlined, size: 26, color: AppColors.ink),
        ),
      );
    }
    return KeyedSubtree(
      key: ValueKey('pin-key-$value'),
      child: HardPressable(
        onTap: () => onDigit(value),
        height: 62,
        child: Text(value, style: AppText.body(28, FontWeight.w700, color: AppColors.ink)),
      ),
    );
  }
}
