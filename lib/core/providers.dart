import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/data/auth_api_repository.dart';
import '../features/auth/domain/auth.dart';
import '../features/catalog/data/catalog_api_repository.dart';
import '../features/catalog/domain/catalog.dart';
import '../features/home/data/home_api_repository.dart';
import '../features/home/domain/home.dart';
import '../features/orders/data/orders_api_repository.dart';
import '../features/orders/domain/orders.dart';
import '../features/stock/data/stock_api_repository.dart';
import '../features/stock/domain/stock.dart';
import '../features/waste/data/waste_api_repository.dart';
import '../features/waste/domain/waste.dart';
import 'config/app_config.dart';
import 'demo/demo_backend.dart';
import 'demo/demo_repositories.dart';
import 'network/api_client.dart';
import 'storage/last_code_storage.dart';
import 'storage/token_storage.dart';

// ---------------------------------------------------------------------------
// Este archivo es el ÚNICO lugar donde se decide si la app usa datos de
// prueba o el backend real. El resto de la app solo conoce las interfaces
// (AuthRepository, CatalogRepository, ...).
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

/// Servidor de prueba en memoria. Solo se usa en modo demo.
final demoBackendProvider = Provider<DemoBackend>((ref) => DemoBackend());

Duration _latency(Ref ref) => ref.watch(appConfigProvider).demoLatency;
bool _isDemo(Ref ref) => ref.watch(appConfigProvider).isDemo;

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final tokens = ref.watch(tokenStorageProvider);
  if (_isDemo(ref)) {
    return DemoAuthRepository(ref.watch(demoBackendProvider), _latency(ref), tokens);
  }
  return AuthApiRepository(ref.watch(apiClientProvider), tokens);
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

final homeRepositoryProvider = Provider<HomeRepository>((ref) {
  if (_isDemo(ref)) {
    return DemoHomeRepository(ref.watch(demoBackendProvider), _latency(ref));
  }
  return HomeApiRepository(ref.watch(apiClientProvider));
});

final stockRepositoryProvider = Provider<StockRepository>((ref) {
  if (_isDemo(ref)) {
    return DemoStockRepository(ref.watch(demoBackendProvider), _latency(ref));
  }
  return StockApiRepository(ref.watch(apiClientProvider));
});

final wasteRepositoryProvider = Provider<WasteRepository>((ref) {
  if (_isDemo(ref)) {
    return DemoWasteRepository(ref.watch(demoBackendProvider), _latency(ref));
  }
  return WasteApiRepository(ref.watch(apiClientProvider));
});
