import '../../features/auth/domain/auth.dart';
import '../../features/catalog/domain/catalog.dart';
import '../../features/control/domain/control_summary.dart';
import '../../features/home/domain/home.dart';
import '../../features/orders/domain/orders.dart';
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

  static const _tokenPrefix = 'demo-token:';

  /// Token de una sesión de demo del integrante [memberId].
  static String tokenFor(String memberId) => '$_tokenPrefix$memberId';

  final TokenStorage _tokens;

  @override
  Future<LoginOutcome> login({
    required String code,
    required String pin,
    required String deviceName,
  }) async {
    final outcome = await run(() => backend.login(code, pin));
    if (outcome case SignedIn(:final session)) {
      await _tokens.write(tokenFor(session.member.id));
    }
    return outcome;
  }

  @override
  Future<Session> verifyTwoFactor({
    required String challengeId,
    required String code,
    required String deviceName,
  }) async {
    final session = await run(() => backend.verifyTwoFactor(challengeId, code));
    await _tokens.write(tokenFor(session.member.id));
    return session;
  }

  @override
  Future<TwoFactorChallenge> resendTwoFactor(String challengeId) =>
      run(() => backend.resendTwoFactor(challengeId));

  @override
  Future<Session?> restore() async {
    final token = await _tokens.read();
    if (token == null || !token.startsWith(_tokenPrefix)) return null;
    final member = backend.memberById(token.substring(_tokenPrefix.length));
    if (member == null) return null;
    return run(() {
      backend.current = member;
      return Session(member: member);
    });
  }

  @override
  Future<void> logout() async {
    backend.current = null;
    await _tokens.clear();
  }
}

class DemoHomeRepository extends _DemoRepository implements HomeRepository {
  const DemoHomeRepository(super.backend, super.latency);

  @override
  Future<TeamHome> load() => run(backend.home);
}

class DemoCatalogRepository extends _DemoRepository implements CatalogRepository {
  const DemoCatalogRepository(super.backend, super.latency);

  @override
  Future<PagedResult<CatalogItem>> list({String? search, String? categoryId, int page = 1}) =>
      run(() {
        backend.requireMember();
        return backend.sales.catalog(search: search, categoryId: categoryId, page: page);
      });

  @override
  Future<List<CatalogCategory>> categories() => run(() {
        backend.requireMember();
        return backend.sales.categories();
      });

  @override
  Future<CatalogItem> item(String id) => run(() {
        backend.requireMember();
        return backend.sales.item(id);
      });
}

class DemoOrdersRepository extends _DemoRepository implements OrdersRepository {
  const DemoOrdersRepository(super.backend, super.latency);

  @override
  Future<PagedResult<OrderSummary>> list({
    OrderFilter filter = OrderFilter.all,
    int page = 1,
  }) =>
      run(() => backend.sales.orders(backend.requireMember(), filter: filter, page: page));

  @override
  Future<OrderDetail> detail(String id) =>
      run(() => backend.sales.order(backend.requireMember(), id));

  @override
  Future<OrderDetail> create(NewSale sale) =>
      run(() => backend.sales.create(backend.requireMember(), sale));

  @override
  Future<OrderDetail> cancel(String id, {String? reason}) =>
      run(() => backend.sales.cancel(backend.requireMember(), id));

  @override
  Future<OrderDetail> uploadProof(
    String id, {
    required UploadFile file,
    required String clientUuid,
    String? reference,
  }) =>
      run(() => backend.sales.uploadProof(
            backend.requireMember(),
            id,
            filename: file.filename,
            reference: reference,
          ));
}

class DemoControlRepository extends _DemoRepository implements ControlRepository {
  const DemoControlRepository(super.backend, super.latency);

  @override
  Future<ControlSummary> summary() => run(backend.controlSummary);
}
