import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import 'hard_pressable.dart';

/// Botón del diseño. Naranja para la acción principal; crema para la
/// secundaria. Sin `onPressed` (o con `busy`) se ve apagado y no responde.
///
/// Una sola acción principal por pantalla.
class HardButton extends StatelessWidget {
  const HardButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.primary = true,
    this.busy = false,
    this.height = 58,
    this.fontSize = 19,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool primary;
  final bool busy;
  final double height;
  final double fontSize;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !busy;
    final textColor = enabled ? AppColors.ink : AppColors.muted;

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (busy) ...[
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2.5, color: textColor),
          ),
          const SizedBox(width: 10),
        ],
        Flexible(
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppText.body(fontSize, FontWeight.w800, color: textColor, height: 1.1),
          ),
        ),
      ],
    );

    final button = HardPressable(
      onTap: enabled ? onPressed : null,
      color: primary ? AppColors.orange : AppColors.card,
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: content,
    );

    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}
