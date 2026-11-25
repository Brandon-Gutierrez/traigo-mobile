import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/ui/phase_placeholder.dart';
import '../features/auth/application/session_controller.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/splash_screen.dart';
import '../features/auth/presentation/two_step_screen.dart';
import '../features/control/presentation/control_summary_screen.dart';
import '../features/home/presentation/home_screen.dart';
import 'app_routes.dart';
import 'app_shell.dart';
import 'role_navigation.dart';

export 'app_routes.dart';

final routerProvider = Provider<GoRouter>((ref) {
  // go_router revisa el `redirect` cada vez que este contador cambia.
  final refresh = ValueNotifier<int>(0);
  ref.listen(sessionControllerProvider, (_, _) => refresh.value++);
  ref.listen(secondStepProvider, (_, _) => refresh.value++);
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

      final member = session.value?.member;
      if (member == null) {
        final target = ref.read(secondStepProvider) == null
            ? AppRoutes.login
            : AppRoutes.verify;
        return location == target ? null : target;
      }

      // Cada rol solo entra a las pantallas de su barra.
      final allowed = navItemsFor(member.role).any((item) => item.route == location);
      return allowed ? null : startRouteFor(member.role);
    },
    routes: [
      GoRoute(path: AppRoutes.splash, builder: (_, _) => const SplashScreen()),
      GoRoute(path: AppRoutes.login, builder: (_, _) => const LoginScreen()),
      GoRoute(path: AppRoutes.verify, builder: (_, _) => const TwoStepScreen()),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => AppShell(shell: shell),
        // Una rama por pestaña, en el orden de [AppRoutes.tabs].
        branches: [
          for (final route in AppRoutes.tabs)
            StatefulShellBranch(
              routes: [GoRoute(path: route, builder: (_, _) => _screenFor(route))],
            ),
        ],
      ),
    ],
  );
});

Widget _screenFor(String route) => switch (route) {
      AppRoutes.home => const HomeScreen(),
      AppRoutes.summary => const ControlSummaryScreen(),
      AppRoutes.catalog => const PhasePlaceholder(
          title: 'Catálogo',
          phase: 2,
          summary: 'Los 62 productos con precio por unidad y por mayor, stock '
              'disponible y el mínimo mayorista de cada código.',
        ),
      AppRoutes.sell => const PhasePlaceholder(
          title: 'Registrar venta',
          phase: 2,
          summary: 'Productos, cliente, forma de pago y comprobante. El precio por '
              'mayor se aplica solo: con el mínimo de cada código y pedidos desde Bs 1.000.',
        ),
      AppRoutes.cash => const PhasePlaceholder(
          title: 'Cierre de caja',
          phase: 4,
          summary: 'La caja del día de todo el equipo por forma de pago, con sus '
              'comprobantes, para enviarla a Jime.',
        ),
      AppRoutes.evidence => const PhasePlaceholder(
          title: 'Evidencia',
          phase: 3,
          summary: 'Subir fotos o enlaces que respalden cada indicador. Jime carga '
              'el valor real y valida.',
        ),
      AppRoutes.team => const PhasePlaceholder(
          title: 'Equipo',
          phase: 3,
          summary: 'El avance del equipo en la semana y las metas de la campaña, '
              'del 1 de diciembre al 14 de enero.',
        ),
      AppRoutes.week => const PhasePlaceholder(
          title: 'Mi semana',
          phase: 3,
          summary: 'Tu KPI indicador por indicador, con meta, peso y evidencia. '
              'Para Sistemas, también las entregas técnicas.',
        ),
      AppRoutes.pending => const PhasePlaceholder(
          title: 'Pendientes',
          phase: 5,
          summary: 'Pagos, evidencias, cierre de caja y entregas de Sistemas por '
              'validar, primero los más antiguos.',
        ),
      AppRoutes.close => const PhasePlaceholder(
          title: 'Cierre semanal',
          phase: 5,
          summary: 'Ventas cobradas, KPI de cada integrante y el bono que pasa a '
              'Dirección.',
        ),
      AppRoutes.bonuses => const PhasePlaceholder(
          title: 'Bonos',
          phase: 5,
          summary: 'El premio de cada semana por escalón y la parte de cada '
              'integrante según cumpla su KPI.',
        ),
      AppRoutes.commissions => const PhasePlaceholder(
          title: 'Comisiones',
          phase: 5,
          summary: 'La comisión del mes de quienes venden y su estado de pago.',
        ),
      AppRoutes.approve => const PhasePlaceholder(
          title: 'Autorizar pagos',
          phase: 5,
          summary: 'Revisar y autorizar el bono y las comisiones que validó Jime.',
        ),
      AppRoutes.more => const PhasePlaceholder(
          title: 'Más',
          phase: 5,
          summary: 'Caja, comisiones, precios, entregas técnicas e historial de cambios.',
        ),
      _ => throw StateError('Ruta sin pantalla: $route'),
    };
