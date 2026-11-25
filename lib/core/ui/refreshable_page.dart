import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Lista de una pantalla principal: respeta el área segura y se actualiza al
/// deslizar hacia abajo.
class RefreshablePage extends StatelessWidget {
  const RefreshablePage({super.key, required this.onRefresh, required this.children});

  /// Vuelve a pedir los datos. Si falla, el error ya se muestra en pantalla
  /// con su botón de reintentar.
  final Future<void> Function() onRefresh;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        color: AppColors.violet,
        backgroundColor: AppColors.bg,
        onRefresh: () async {
          try {
            await onRefresh();
          } catch (_) {}
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 32),
          children: children,
        ),
      ),
    );
  }
}
