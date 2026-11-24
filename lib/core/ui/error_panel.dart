import 'package:flutter/material.dart';

import '../network/api_exception.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import 'hard_button.dart';
import 'hard_card.dart';

/// Texto de error listo para el vendedor, venga de la API o de un fallo
/// inesperado.
String errorMessage(Object error) =>
    error is ApiException ? error.message : 'Algo salió mal. Intenta de nuevo.';

/// Aviso de error con botón para reintentar. Se usa en lugar del contenido
/// que no se pudo cargar.
class ErrorPanel extends StatelessWidget {
  const ErrorPanel({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return HardCard(
      color: AppColors.redSoft,
      borderColor: AppColors.red,
      shadowColor: AppColors.red,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            message,
            style: AppText.body(15, FontWeight.w700, color: AppColors.red, height: 1.3),
          ),
          const SizedBox(height: 14),
          HardButton(
            label: 'Reintentar',
            primary: false,
            height: 48,
            fontSize: 16,
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}
