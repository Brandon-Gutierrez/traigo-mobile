import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/api_paths.dart';
import '../../../core/storage/token_storage.dart';
import '../domain/auth.dart';

class AuthApiRepository implements AuthRepository {
  AuthApiRepository(this._api, this._tokens);

  final ApiClient _api;
  final TokenStorage _tokens;

  @override
  Future<LoginOutcome> login({
    required String code,
    required String pin,
    required String deviceName,
  }) async {
    final json = await _api.post(
      ApiPaths.login,
      body: {'code': code.trim().toUpperCase(), 'pin': pin, 'device_name': deviceName},
    );
    final data = json.obj('data');
    final challenge = data.objOrNull('two_factor');
    if (challenge != null) {
      return NeedsSecondStep(TwoFactorChallenge.fromJson(challenge));
    }
    return SignedIn(await _open(data));
  }

  @override
  Future<Session> verifyTwoFactor({
    required String challengeId,
    required String code,
    required String deviceName,
  }) async {
    final json = await _api.post(
      ApiPaths.twoFactor,
      body: {'challenge_id': challengeId, 'code': code, 'device_name': deviceName},
    );
    return _open(json.obj('data'));
  }

  @override
  Future<TwoFactorChallenge> resendTwoFactor(String challengeId) async {
    final json = await _api.post(ApiPaths.twoFactorResend, body: {'challenge_id': challengeId});
    return TwoFactorChallenge.fromJson(json.obj('data'));
  }

  Future<Session> _open(Json data) async {
    await _tokens.write(data.str('token'));
    return Session.fromJson(data);
  }

  @override
  Future<Session?> restore() async {
    final token = await _tokens.read();
    if (token == null || token.isEmpty) return null;
    try {
      final json = await _api.get(ApiPaths.me);
      return Session.fromJson(json.obj('data'));
    } on UnauthorizedException {
      // El token ya no sirve (revocado o vencido).
      await _tokens.clear();
      return null;
    }
    // Un NetworkException se propaga a propósito: sin internet no hay que
    // sacar a nadie de su sesión.
  }

  @override
  Future<void> logout() async {
    try {
      await _api.postNoContent(ApiPaths.logout);
    } on ApiException {
      // Aunque el servidor no responda, el celular olvida el token.
    } finally {
      await _tokens.clear();
    }
  }
}
