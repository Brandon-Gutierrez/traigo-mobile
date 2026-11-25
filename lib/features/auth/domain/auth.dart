import '../../../core/network/json.dart';

/// Rol de quien entra a la app. Decide el menú y lo que puede hacer.
enum MemberRole {
  content('content'),
  warehouse('warehouse'),
  wholesale('wholesale'),
  seller('seller'),
  systems('systems'),

  /// Jime: controla y valida.
  control('control'),

  /// Dirección: autoriza incentivos y pagos.
  management('management');

  const MemberRole(this.apiValue);
  final String apiValue;

  static MemberRole fromApi(String value) =>
      values.firstWhere((role) => role.apiValue == value);

  /// Jime y Dirección usan el panel de control; no participan del bono.
  bool get isControlSide => this == control || this == management;

  /// Solo estos roles registran ventas y cobran comisión.
  bool get canSell => this == seller || this == wholesale;
}

class Member {
  const Member({
    required this.id,
    required this.code,
    required this.name,
    required this.role,
    required this.title,
  });

  factory Member.fromJson(Json json) => Member(
        id: json.str('id'),
        code: json.str('code'),
        name: json.str('name'),
        role: MemberRole.fromApi(json.str('role')),
        title: json.str('title'),
      );

  final String id;

  /// Código que escribe al ingresar. Ej: `ALI-04`.
  final String code;
  final String name;
  final MemberRole role;

  /// Puesto tal como se muestra. Ej: «Ventas por comisión».
  final String title;

  String get firstName => name.startsWith('Sistemas') ? name : name.split(' ').first;
}

class Session {
  const Session({required this.member});

  factory Session.fromJson(Json json) =>
      Session(member: Member.fromJson(json.obj('member')));

  final Member member;
}

/// Segundo paso pendiente para quienes validan o autorizan pagos.
class TwoFactorChallenge {
  const TwoFactorChallenge({
    required this.id,
    required this.expiresAt,
    required this.resendAt,
    this.codeLength = 6,
  });

  factory TwoFactorChallenge.fromJson(Json json) => TwoFactorChallenge(
        id: json.str('challenge_id'),
        expiresAt: json.date('expires_at'),
        resendAt: json.date('resend_at'),
        codeLength: json.integerOrNull('code_length') ?? 6,
      );

  final String id;
  final DateTime expiresAt;

  /// Desde cuándo se puede pedir otro código.
  final DateTime resendAt;
  final int codeLength;
}

/// Resultado del primer paso del ingreso.
sealed class LoginOutcome {
  const LoginOutcome();
}

final class SignedIn extends LoginOutcome {
  const SignedIn(this.session);
  final Session session;
}

final class NeedsSecondStep extends LoginOutcome {
  const NeedsSecondStep(this.challenge);
  final TwoFactorChallenge challenge;
}

abstract interface class AuthRepository {
  /// Código + PIN. Guarda el token si no hace falta un segundo paso.
  /// Lanza [UnauthorizedException] si el código o el PIN no coinciden.
  Future<LoginOutcome> login({
    required String code,
    required String pin,
    required String deviceName,
  });

  /// Segundo paso: el código de 6 números. Guarda el token.
  Future<Session> verifyTwoFactor({
    required String challengeId,
    required String code,
    required String deviceName,
  });

  Future<TwoFactorChallenge> resendTwoFactor(String challengeId);

  /// Recupera la sesión con el token guardado. `null` si no hay token o ya
  /// no es válido.
  Future<Session?> restore();

  /// Revoca el token en el servidor y lo borra del celular.
  Future<void> logout();
}
