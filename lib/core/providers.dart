import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/data/auth_api_repository.dart';
import '../features/auth/domain/auth.dart';
import '../features/catalog/data/catalog_api_repository.dart';
import '../features/catalog/domain/catalog.dart';
import '../features/control/data/admin_api_repository.dart';
import '../features/control/data/control_api_repository.dart';
import '../features/control/data/payouts_api_repository.dart';
import '../features/control/data/review_api_repository.dart';
import '../features/control/domain/admin.dart';
import '../features/control/domain/control_summary.dart';
import '../features/control/domain/payouts.dart';
import '../features/control/domain/review.dart';
import '../features/home/data/home_api_repository.dart';
import '../features/home/domain/home.dart';
import '../features/management/data/management_api_repository.dart';
import '../features/management/domain/authorizations.dart';
import '../features/orders/data/orders_api_repository.dart';
import '../features/orders/domain/orders.dart';
import '../features/team/data/team_api_repository.dart';
import '../features/team/domain/team_week.dart';
import '../features/warehouse/data/warehouse_api_repository.dart';
import '../features/warehouse/domain/warehouse.dart';
import 'config/app_config.dart';
import 'demo/demo_backend.dart';
import 'demo/demo_repositories.dart';
import 'network/api_client.dart';
import 'storage/last_code_storage.dart';
import 'storage/token_storage.dart';

// ---------------------------------------------------------------------------
// Este archivo es el ÚNICO lugar donde se decide si la app usa datos de
// prueba o el backend real. El resto de la app solo conoce las interfaces
// (AuthRepository, HomeRepository, ...).
// ---------------------------------------------------------------------------

final appConfigProvider = Provider<AppConfig>((ref) => AppConfig.fromEnvironment());

final tokenStorageProvider = Provider<TokenStorage>((ref) => const SecureTokenStorage());

final lastCodeStorageProvider =
    Provider<LastCodeStorage>((ref) => const SecureLastCodeStorage());

/// Se dispara cuando la API responde 401 con un token guardado. La sesión
/// escucha este aviso y sale al ingreso.
class SessionExpiredSignal extends Notifier<int> {
  @override
  int build() => 0;

  void fire() => state++;
}

final sessionExpiredProvider =
    NotifierProvider<SessionExpiredSignal, int>(SessionExpiredSignal.new);

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient.create(
    config: ref.watch(appConfigProvider),
    tokens: ref.watch(tokenStorageProvider),
    onUnauthorized: () => ref.read(sessionExpiredProvider.notifier).fire(),
  );
});

/// Reloj de la app (cuentas regresivas). Se reemplaza en las pruebas.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Servidor de prueba en memoria. Solo se usa en modo demo.
final demoBackendProvider =
    Provider<DemoBackend>((ref) => DemoBackend(clock: ref.watch(clockProvider)));

Duration _latency(Ref ref) => ref.watch(appConfigProvider).demoLatency;
bool _isDemo(Ref ref) => ref.watch(appConfigProvider).isDemo;

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final tokens = ref.watch(tokenStorageProvider);
  if (_isDemo(ref)) {
    return DemoAuthRepository(ref.watch(demoBackendProvider), _latency(ref), tokens);
  }
  return AuthApiRepository(ref.watch(apiClientProvider), tokens);
});

final homeRepositoryProvider = Provider<HomeRepository>((ref) {
  if (_isDemo(ref)) {
    return DemoHomeRepository(ref.watch(demoBackendProvider), _latency(ref));
  }
  return HomeApiRepository(ref.watch(apiClientProvider));
});

final controlRepositoryProvider = Provider<ControlRepository>((ref) {
  if (_isDemo(ref)) {
    return DemoControlRepository(ref.watch(demoBackendProvider), _latency(ref));
  }
  return ControlApiRepository(ref.watch(apiClientProvider));
});

final catalogRepositoryProvider = Provider<CatalogRepository>((ref) {
  if (_isDemo(ref)) {
    return DemoCatalogRepository(ref.watch(demoBackendProvider), _latency(ref));
  }
  return CatalogApiRepository(ref.watch(apiClientProvider));
});

final ordersRepositoryProvider = Provider<OrdersRepository>((ref) {
  if (_isDemo(ref)) {
    return DemoOrdersRepository(ref.watch(demoBackendProvider), _latency(ref));
  }
  return OrdersApiRepository(ref.watch(apiClientProvider));
});

/// «Hoy» para las etiquetas de fecha. En la demo, la foto del 6 de diciembre.
final todayProvider = Provider<DateTime Function()>(
  (ref) => _isDemo(ref) ? () => DemoBackend.today : DateTime.now,
);

// ───── Listos para la API; sus datos de demo se agregan junto con la pantalla
// ───── de cada fase.

/// Repositorio que por ahora solo funciona contra el backend.
Provider<T> _apiOnly<T>(int phase, T Function(ApiClient api) create) =>
    Provider<T>((ref) {
      if (_isDemo(ref)) {
        throw UnsupportedError('Los datos de demo de esta parte llegan en la fase $phase.');
      }
      return create(ref.watch(apiClientProvider));
    });

final teamRepositoryProvider = _apiOnly<TeamRepository>(3, TeamApiRepository.new);

final warehouseRepositoryProvider =
    _apiOnly<WarehouseRepository>(4, WarehouseApiRepository.new);

final reviewRepositoryProvider = _apiOnly<ReviewRepository>(5, ReviewApiRepository.new);

final payoutsRepositoryProvider =
    _apiOnly<PayoutsRepository>(5, PayoutsApiRepository.new);

final adminRepositoryProvider = _apiOnly<AdminRepository>(5, AdminApiRepository.new);

final managementRepositoryProvider =
    _apiOnly<ManagementRepository>(5, ManagementApiRepository.new);
