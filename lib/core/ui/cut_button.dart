import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'chamfer.dart';

/// Botón principal del diseño: bloque plano con la esquina cortada.
/// Deshabilitado ([onPressed] nulo) queda gris y su texto explica qué falta.
class CutButton extends StatelessWidget {
  const CutButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
    this.height = 58,
    this.color = AppColors.violet,
    this.foreground = AppColors.bg,
    this.fontSize = 20,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final double height;
  final Color color;
  final Color foreground;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !busy;
    final background = enabled || busy ? color : AppColors.off;
    final text = enabled || busy ? foreground : AppColors.muted;

    return Semantics(
      button: true,
      enabled: enabled,
      child: ClipPath(
        clipper: const ChamferClipper(),
        child: Material(
          color: background,
          child: InkWell(
            onTap: enabled ? onPressed : null,
            child: SizedBox(
              height: height,
              width: double.infinity,
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (busy) ...[
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: text),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.display(fontSize, color: text),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
