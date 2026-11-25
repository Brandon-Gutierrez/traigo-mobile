import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/ui/phase_placeholder.dart';
import '../features/auth/application/session_controller.dart';
import '../features/auth/domain/auth.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/splash_screen.dart';
import '../features/auth/presentation/two_step_screen.dart';
import '../features/catalog/presentation/catalog_screen.dart';
import '../features/catalog/presentation/product_screen.dart';
import '../features/control/presentation/control_summary_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/orders/presentation/my_orders_screen.dart';
import '../features/orders/presentation/order_detail_screen.dart';
import '../features/orders/presentation/product_picker_screen.dart';
import '../features/orders/presentation/sale_customer_screen.dart';
import '../features/orders/presentation/sale_products_screen.dart';
import '../features/team/presentation/deliverable_screen.dart';
import '../features/team/presentation/evidence_screen.dart';
import '../features/team/presentation/indicator_screen.dart';
import '../features/team/presentation/team_screen.dart';
import '../features/team/presentation/week_screen.dart';
import '../features/warehouse/presentation/cash_screen.dart';
import '../features/warehouse/presentation/count_screen.dart';
import '../features/warehouse/presentation/dispatches_screen.dart';
import '../features/warehouse/presentation/new_count_screen.dart';
import '../features/warehouse/presentation/stock_product_screen.dart';
import '../features/warehouse/presentation/stock_screen.dart';
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

      return canOpen(member.role, location) ? null : startRouteFor(member.role);
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
              routes: [
                GoRoute(
                  path: route,
                  builder: (_, _) => _screenFor(route),
                  routes: _innerRoutes(route),
                ),
              ],
            ),
        ],
      ),
    ],
  );
});

/// Cada rol entra a las pestañas de su barra y a lo que hay dentro de ellas.
/// «Mis pedidos» además exige vender, y despachos y stock, ser de almacén.
bool canOpen(MemberRole role, String location) {
  bool within(String route) => location == route || location.startsWith('$route/');
  if (within(AppRoutes.orders)) return role.canSell;
  if (within(AppRoutes.dispatches) || within(AppRoutes.stock)) {
    return role == MemberRole.warehouse;
  }
  return navItemsFor(role).any((item) => within(item.route));
}

/// Pantallas dentro de una pestaña.
List<GoRoute> _innerRoutes(String tab) => switch (tab) {
      AppRoutes.home => [
          GoRoute(
            path: 'orders',
            builder: (_, _) => const MyOrdersScreen(),
            routes: [
              GoRoute(
                path: ':id',
                builder: (_, state) =>
                    OrderDetailScreen(orderId: state.pathParameters['id']!),
              ),
            ],
          ),
          GoRoute(path: 'dispatches', builder: (_, _) => const DispatchesScreen()),
          GoRoute(
            path: 'stock',
            builder: (_, state) => StockScreen(
              tab: state.uri.queryParameters['tab'] == 'counts'
                  ? StockTab.counts
                  : StockTab.products,
            ),
            routes: [
              GoRoute(
                path: 'products/:id',
                builder: (_, state) =>
                    StockProductScreen(productId: state.pathParameters['id']!),
              ),
              // Antes que «counts/:id», para que «new» no se lea como un id.
              GoRoute(
                path: 'counts/new',
                builder: (_, _) => const NewCountScreen(),
                routes: [
                  GoRoute(path: 'add', builder: (_, _) => const CountProductPickerScreen()),
                ],
              ),
              GoRoute(
                path: 'counts/:id',
                builder: (_, state) => CountScreen(countId: state.pathParameters['id']!),
              ),
            ],
          ),
        ],
      AppRoutes.cash => [
          GoRoute(
            path: 'day/:date',
            builder: (_, state) {
              final date = DateTime.tryParse(state.pathParameters['date']!);
              return CashScreen(key: ValueKey(date), date: date);
            },
          ),
        ],
      AppRoutes.catalog => [
          GoRoute(
            path: ':id',
            builder: (_, state) => ProductScreen(productId: state.pathParameters['id']!),
          ),
        ],
      AppRoutes.sell => [
          GoRoute(path: 'add', builder: (_, _) => const ProductPickerScreen()),
          GoRoute(path: 'customer', builder: (_, _) => const SaleCustomerScreen()),
        ],
      AppRoutes.week || AppRoutes.evidence => [
          GoRoute(
            path: 'indicator/:id',
            builder: (_, state) => IndicatorScreen(
              tab: tab,
              resultId: state.pathParameters['id']!,
              weekNumber: _weekOf(state),
            ),
          ),
          GoRoute(
            path: 'deliverable/:id',
            builder: (_, state) => DeliverableScreen(
              tab: tab,
              deliverableId: state.pathParameters['id']!,
              weekNumber: _weekOf(state),
            ),
          ),
        ],
      _ => const [],
    };

int? _weekOf(GoRouterState state) =>
    int.tryParse(state.uri.queryParameters['week'] ?? '');

Widget _screenFor(String route) => switch (route) {
      AppRoutes.home => const HomeScreen(),
      AppRoutes.summary => const ControlSummaryScreen(),
      AppRoutes.catalog => const CatalogScreen(),
      AppRoutes.sell => const SaleProductsScreen(),
      AppRoutes.cash => const CashScreen(),
      AppRoutes.evidence => const EvidenceScreen(),
      AppRoutes.team => const TeamScreen(),
      AppRoutes.week => const WeekScreen(),
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
