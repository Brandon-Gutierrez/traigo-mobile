import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'app_bottom_bar.dart';

/// Marco de la app con la sesión iniciada: cada pestaña conserva su estado.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: AppBottomBar(
        currentIndex: shell.currentIndex,
        // Tocar la pestaña activa vuelve a su pantalla inicial.
        onSelected: (index) =>
            shell.goBranch(index, initialLocation: index == shell.currentIndex),
      ),
    );
  }
}
