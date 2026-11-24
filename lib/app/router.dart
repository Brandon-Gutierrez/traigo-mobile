import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/ui/phase_placeholder.dart';
import '../features/auth/application/session_controller.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/splash_screen.dart';
import '../features/home/presentation/home_screen.dart';
import 'app_routes.dart';
import 'app_shell.dart';

export 'app_routes.dart';

final routerProvider = Provider<GoRouter>((ref) {
  // go_router revisa el `redirect` cada vez que este contador cambia.
  final refresh = ValueNotifier<int>(0);
  ref.listen(sessionControllerProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: refresh,
    redirect: (context, state) {
      final session = ref.read(sessionControllerProvider);
      final location = state.matchedLocation;

      // Recuperando la sesión, o sin internet al abrir: se queda en la
      // pantalla de arranque (que ofrece reintentar).
      if (session.isLoading || session.hasError) {
        return location == AppRoutes.splash ? null : AppRoutes.splash;
      }

      final signedIn = session.value != null;
      if (!signedIn) return location == AppRoutes.login ? null : AppRoutes.login;
      if (location == AppRoutes.login || location == AppRoutes.splash) {
        return AppRoutes.home;
      }
      return null;
    },
    routes: [
      GoRoute(path: AppRoutes.splash, builder: (_, _) => const SplashScreen()),
      GoRoute(path: AppRoutes.login, builder: (_, _) => const LoginScreen()),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.home,
              builder: (_, _) => const HomeScreen(),
              routes: [
                GoRoute(
                  path: 'waste',
                  builder: (_, _) =>
                      const PhasePlaceholder(title: 'Registrar merma', phase: 'Fase 4'),
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.catalog,
              builder: (_, _) =>
                  const PhasePlaceholder(title: 'Catálogo', phase: 'Fase 2'),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.sell,
              builder: (_, _) =>
                  const PhasePlaceholder(title: 'Registrar venta', phase: 'Fase 2'),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.orders,
              builder: (_, _) =>
                  const PhasePlaceholder(title: 'Mis pedidos', phase: 'Fase 3'),
              routes: [
                GoRoute(
                  path: ':id',
                  builder: (_, state) => PhasePlaceholder(
                    title: 'Pedido #${state.pathParameters['id']}',
                    phase: 'Fase 3',
                  ),
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.stock,
              builder: (_, _) => const PhasePlaceholder(title: 'Stock', phase: 'Fase 4'),
            ),
          ]),
        ],
      ),
    ],
  );
});
