import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/ui/brand_logo.dart';
import '../../../core/ui/ficha.dart';
import '../application/session_controller.dart';

/// Pide confirmar y cierra la sesión.
Future<void> confirmLogout(BuildContext context, WidgetRef ref) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('¿Cerrar sesión?'),
      content: const Text('Tendrás que ingresar otra vez con tu código y tu PIN.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          style: TextButton.styleFrom(foregroundColor: AppColors.alert),
          child: const Text('Cerrar sesión'),
        ),
      ],
    ),
  );
  if (confirmed == true) {
    await ref.read(sessionControllerProvider.notifier).logout();
  }
}

/// Encabezado de la primera pantalla de cada rol: marca, saludo, puesto y el
/// botón para cerrar sesión.
class AccountHeader extends ConsumerWidget {
  const AccountHeader({super.key, required this.greeting, required this.detail});

  final String greeting;

  /// Puesto y código. Se muestra en mayúsculas.
  final String detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const BrandLogo(BrandAsset.wordmark, width: 96),
              const SizedBox(height: 8),
              Text(greeting, style: AppText.display(30, height: 1.1)),
              const SizedBox(height: 4),
              Text(
                detail.toUpperCase(),
                style: AppText.mono(12, color: AppColors.muted, letterSpacing: 0.5),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        SquareIconButton(
          icon: Icons.logout,
          tooltip: 'Cerrar sesión',
          onPressed: () => confirmLogout(context, ref),
        ),
      ],
    );
  }
}
