import '../../features/auth/domain/auth.dart';
import '../../features/control/domain/control_summary.dart';
import '../../features/home/domain/home.dart';
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

class DemoControlRepository extends _DemoRepository implements ControlRepository {
  const DemoControlRepository(super.backend, super.latency);

  @override
  Future<ControlSummary> summary() => run(backend.controlSummary);
}
