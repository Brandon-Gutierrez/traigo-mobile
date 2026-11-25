import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/application/session_controller.dart';
import '../features/auth/domain/auth.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/splash_screen.dart';
import '../features/auth/presentation/two_step_screen.dart';
import '../features/catalog/presentation/catalog_screen.dart';
import '../features/catalog/presentation/product_screen.dart';
import '../features/control/domain/review.dart';
import '../features/control/presentation/access_screen.dart';
import '../features/control/presentation/audit_screen.dart';
import '../features/control/presentation/bonus_screen.dart';
import '../features/control/presentation/cash_review_screen.dart';
import '../features/control/presentation/commissions_screen.dart';
import '../features/control/presentation/compliance_screens.dart';
import '../features/control/presentation/control_summary_screen.dart';
import '../features/control/presentation/counts_screen.dart';
import '../features/control/presentation/deliverables_screens.dart';
import '../features/control/presentation/evidence_review_screen.dart';
import '../features/control/presentation/more_screen.dart';
import '../features/control/presentation/orders_screens.dart';
import '../features/control/presentation/payment_review_screen.dart';
import '../features/control/presentation/pending_screen.dart';
import '../features/control/presentation/price_screens.dart';
import '../features/control/presentation/weekly_closing_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/management/domain/authorizations.dart';
import '../features/management/presentation/authorization_screens.dart';
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
                  builder: (_, state) => _screenFor(route, state),
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
/// «Mis pedidos» además exige vender; despachos y stock, ser de almacén; y en
/// «Más» y Cumplimiento hay cosas que son solo de Jime.
bool canOpen(MemberRole role, String location) {
  bool within(String route) => location == route || location.startsWith('$route/');
  if (within(AppRoutes.orders)) return role.canSell;
  if (within(AppRoutes.dispatches) || within(AppRoutes.stock)) {
    return role == MemberRole.warehouse;
  }
  const controlOnly = [
    AppRoutes.moreDeliverables,
    AppRoutes.moreCommissions,
    AppRoutes.moreCounts,
    AppRoutes.moreOrders,
    AppRoutes.moreAccess,
  ];
  // La semana de cada persona (para cargar sus valores) también es de Jime.
  if (controlOnly.any(within) || location.startsWith('${AppRoutes.compliance}/')) {
    return role == MemberRole.control;
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
      AppRoutes.summary => [
          GoRoute(
            path: 'compliance',
            builder: (_, _) => const ComplianceScreen(),
            routes: [
              GoRoute(
                path: ':memberId',
                builder: (_, state) =>
                    MemberWeekScreen(memberId: state.pathParameters['memberId']!),
                routes: [
                  GoRoute(
                    path: 'indicator/:resultId',
                    builder: (_, state) => EvidenceReviewScreen(
                      resultId: state.pathParameters['resultId']!,
                      backLabel: 'Indicadores',
                      backRoute: AppRoutes.complianceMember(
                        state.pathParameters['memberId']!,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      AppRoutes.pending => [
          GoRoute(
            path: 'payment/:id',
            builder: (_, state) =>
                PaymentReviewScreen(paymentId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: 'evidence/:id',
            builder: (_, state) => EvidenceReviewScreen(
              resultId: state.pathParameters['id']!,
              backLabel: 'Pendientes',
              backRoute: AppRoutes.pending,
            ),
          ),
          GoRoute(
            path: 'cash/:id',
            builder: (_, state) =>
                CashReviewScreen(closingId: state.pathParameters['id']!),
          ),
          _deliverables(
            backLabel: 'Pendientes',
            backRoute: AppRoutes.pending,
            listRoute: AppRoutes.pendingDeliverables,
            routeFor: AppRoutes.pendingDeliverable,
          ),
        ],
      AppRoutes.more => _moreRoutes,
      AppRoutes.approve => [
          GoRoute(
            path: ':type/:id',
            builder: (_, state) => AuthorizationScreen(
              type: AuthorizationType.fromApi(state.pathParameters['type']!),
              id: state.pathParameters['id']!,
            ),
          ),
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

/// Las entregas de Sistemas se abren desde «Pendientes» y desde «Más».
GoRoute _deliverables({
  required String backLabel,
  required String backRoute,
  required String listRoute,
  required String Function(String id) routeFor,
}) =>
    GoRoute(
      path: 'deliverables',
      builder: (_, _) => DeliverablesScreen(
        backLabel: backLabel,
        backRoute: backRoute,
        routeFor: routeFor,
      ),
      routes: [
        GoRoute(
          path: ':id',
          builder: (_, state) => DeliverableReviewScreen(
            deliverableId: state.pathParameters['id']!,
            listRoute: listRoute,
          ),
        ),
      ],
    );

List<GoRoute> get _moreRoutes => [
      _deliverables(
        backLabel: 'Más',
        backRoute: AppRoutes.more,
        listRoute: AppRoutes.moreDeliverables,
        routeFor: AppRoutes.moreDeliverable,
      ),
      GoRoute(
        path: 'prices',
        builder: (_, _) => const PriceListScreen(),
        routes: [
          GoRoute(
            path: ':productId',
            builder: (_, state) =>
                PriceScreen(productId: state.pathParameters['productId']!),
          ),
        ],
      ),
      GoRoute(
        path: 'commissions',
        builder: (_, _) => const CommissionsScreen(backToMore: true),
      ),
      GoRoute(
        path: 'counts',
        builder: (_, _) => const ControlCountsScreen(),
        routes: [
          GoRoute(
            path: ':id',
            builder: (_, state) => CountScreen(
              countId: state.pathParameters['id']!,
              readOnly: true,
              backRoute: AppRoutes.moreCounts,
            ),
          ),
        ],
      ),
      GoRoute(
        path: 'orders',
        builder: (_, _) => const ControlOrdersScreen(),
        routes: [
          GoRoute(
            path: ':id',
            builder: (_, state) =>
                ControlOrderScreen(orderId: state.pathParameters['id']!),
          ),
        ],
      ),
      GoRoute(path: 'audit', builder: (_, _) => const AuditScreen()),
      GoRoute(path: 'access', builder: (_, _) => const AccessScreen()),
    ];

int? _weekOf(GoRouterState state) =>
    int.tryParse(state.uri.queryParameters['week'] ?? '');

/// La pestaña de «Pendientes» elegida viaja en `?type=`.
PendingType? _pendingType(GoRouterState state) {
  final value = state.uri.queryParameters['type'];
  return PendingType.values.where((t) => t.apiValue == value).firstOrNull;
}

Widget _screenFor(String route, GoRouterState state) => switch (route) {
      AppRoutes.home => const HomeScreen(),
      AppRoutes.summary => const ControlSummaryScreen(),
      AppRoutes.catalog => const CatalogScreen(),
      AppRoutes.sell => const SaleProductsScreen(),
      AppRoutes.cash => const CashScreen(),
      AppRoutes.evidence => const EvidenceScreen(),
      AppRoutes.team => const TeamScreen(),
      AppRoutes.week => const WeekScreen(),
      AppRoutes.pending => PendingScreen(type: _pendingType(state)),
      AppRoutes.close => const WeeklyClosingScreen(),
      AppRoutes.bonuses => const BonusScreen(),
      AppRoutes.commissions => const CommissionsScreen(),
      AppRoutes.approve => const AuthorizationsScreen(),
      AppRoutes.more => const MoreScreen(),
      _ => throw StateError('Ruta sin pantalla: $route'),
    };
