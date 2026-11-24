import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/ui/error_panel.dart';
import '../../../core/ui/traigo_logo.dart';
import '../application/session_controller.dart';

/// Pantalla de arranque: recupera la sesión guardada. Si no hay internet
/// ofrece reintentar en lugar de sacar al vendedor de su cuenta.
class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider);
    final error = session.error;

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const TraigoLogo(size: 76),
              const SizedBox(height: 28),
              if (error == null)
                const CircularProgressIndicator(color: AppColors.orange)
              else
                ErrorPanel(
                  message: errorMessage(error),
                  onRetry: () => ref.invalidate(sessionControllerProvider),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
