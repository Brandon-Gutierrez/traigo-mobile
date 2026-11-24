import '../../features/auth/domain/auth.dart';
import '../../features/catalog/domain/catalog.dart';
import '../../features/home/domain/home.dart';
import '../../features/orders/domain/orders.dart';
import '../../features/stock/domain/stock.dart';
import '../../features/waste/domain/waste.dart';
import '../network/api_client.dart' show UploadFile;
import '../network/paged_result.dart';
import '../storage/token_storage.dart';
import 'demo_backend.dart';

/// Repositorios de prueba: delegan en [DemoBackend] y agregan una espera
/// artificial para poder ver los estados de carga de las pantallas.
abstract class _DemoRepository {
  const _DemoRepository(this.backend, this.latency);

  final DemoBackend backend;
  final Duration latency;

  Future<T> run<T>(T Function() action) async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    return action();
  }
}

class DemoAuthRepository extends _DemoRepository implements AuthRepository {
  const DemoAuthRepository(super.backend, super.latency, this._tokens);

  static const demoToken = 'demo-token';
  final TokenStorage _tokens;

  @override
  Future<Session> login({
    required String code,
    required String pin,
    required String deviceName,
  }) async {
    final session = await run(() => backend.login(code, pin));
    await _tokens.write(demoToken);
    return session;
  }

  @override
  Future<Session?> restore() async {
    final token = await _tokens.read();
    if (token != demoToken) return null;
    return run(() => backend.session);
  }

  @override
  Future<void> logout() => _tokens.clear();
}

class DemoCatalogRepository extends _DemoRepository implements CatalogRepository {
  const DemoCatalogRepository(super.backend, super.latency);

  @override
  Future<PagedResult<CatalogItem>> list({
    String? search,
    String? category,
    CatalogKind? kind,
    int page = 1,
  }) =>
      run(() => backend.listCatalog(search: search, category: category, kind: kind, page: page));

  @override
  Future<List<String>> categories() => run(backend.categories);

  @override
  Future<CatalogItem> get(CatalogKind kind, String id) =>
      run(() => backend.catalogItem(kind, id));
}

class DemoOrdersRepository extends _DemoRepository implements OrdersRepository {
  const DemoOrdersRepository(super.backend, super.latency);

  @override
  Future<PagedResult<OrderSummary>> list({OrderStatus? status, int page = 1}) =>
      run(() => backend.listOrders(status: status, page: page));

  @override
  Future<OrderDetail> get(String id) => run(() => backend.order(id));

  @override
  Future<OrderDetail> create(CreateOrderInput input) =>
      run(() => backend.createOrder(input));

  @override
  Future<OrderDetail> cancel(String id) => run(() => backend.cancelOrder(id));

  @override
  Future<OrderDetail> uploadPaymentProof(
    String id,
    UploadFile file, {
    void Function(int sent, int total)? onProgress,
  }) async {
    // Simula la subida en tres tramos para poder probar la barra de avance.
    for (final part in const [0.3, 0.7, 1.0]) {
      if (latency > Duration.zero) await Future<void>.delayed(latency);
      onProgress?.call((part * 100).round(), 100);
    }
    return backend.uploadPaymentProof(id);
  }
}

class DemoHomeRepository extends _DemoRepository implements HomeRepository {
  const DemoHomeRepository(super.backend, super.latency);

  @override
  Future<HomeSummary> load() => run(backend.home);
}

class DemoStockRepository extends _DemoRepository implements StockRepository {
  const DemoStockRepository(super.backend, super.latency);

  @override
  Future<StockSummary> summary() => run(backend.stockSummary);

  @override
  Future<PagedResult<StockMovement>> movements({DateTime? day, int page = 1}) =>
      run(() => backend.movements(day: day, page: page));
}

class DemoWasteRepository extends _DemoRepository implements WasteRepository {
  const DemoWasteRepository(super.backend, super.latency);

  @override
  Future<WasteReport> create(CreateWasteInput input) =>
      run(() => backend.createWaste(input));

  @override
  Future<PagedResult<WasteReport>> list({WasteStatus? status, int page = 1}) =>
      run(() => backend.listWaste(status: status, page: page));
}
