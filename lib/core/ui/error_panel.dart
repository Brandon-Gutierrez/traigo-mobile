import 'package:flutter/material.dart';

import '../network/api_exception.dart';
import '../theme/app_theme.dart';
import 'cut_button.dart';

/// Texto de error listo para mostrar, venga de la API o de un fallo inesperado.
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: AppColors.alt,
        border: Border(bottom: BorderSide(color: AppColors.alert, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(message, style: AppText.body(15, FontWeight.w600, color: AppColors.alert, height: 1.35)),
          const SizedBox(height: 14),
          CutButton(
            label: 'Reintentar',
            height: 48,
            fontSize: 17,
            color: AppColors.ink,
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}
