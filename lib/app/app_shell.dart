import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/application/session_controller.dart';
import '../features/auth/domain/auth.dart';
import '../features/control/application/control_providers.dart';
import 'app_bottom_bar.dart';
import 'role_navigation.dart';

/// Marco de la app con la sesión iniciada: cada pestaña conserva su estado y
/// la barra inferior cambia con el rol.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(sessionControllerProvider.select((s) => s.value?.member.role));

    return Scaffold(
      body: shell,
      bottomNavigationBar: role == null
          ? null
          : AppBottomBar(
              items: navItemsFor(role),
              currentBranch: shell.currentIndex,
              // Solo Jime necesita el número de pendientes en la barra.
              pendingCount:
                  role == MemberRole.control ? ref.watch(pendingCountProvider) : null,
              // Tocar la pestaña activa vuelve a su pantalla inicial.
              onSelected: (item) => shell.goBranch(
                item.branch,
                initialLocation: item.branch == shell.currentIndex,
              ),
            ),
    );
  }
}
