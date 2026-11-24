import '../../../core/network/json.dart';

class Seller {
  const Seller({required this.id, required this.code, required this.name});

  factory Seller.fromJson(Json json) => Seller(
        id: json.str('id'),
        code: json.str('code'),
        name: json.str('name'),
      );

  final String id;

  /// Código que escribe el vendedor al ingresar. Ej: `ANA-07`.
  final String code;
  final String name;

  String get firstName => name.split(' ').first;
}

/// Porcentajes que fija el admin. La app solo los usa para mostrar una
/// vista previa de la comisión; el monto real lo calcula siempre el servidor.
class CommissionRules {
  const CommissionRules({required this.personalRate, required this.fundRate});

  factory CommissionRules.fromJson(Json json) => CommissionRules(
        personalRate: json.rate('personal_rate'),
        fundRate: json.rate('fund_rate'),
      );

  /// 0.40 = 40 % de la ganancia de la venta para el vendedor.
  final double personalRate;

  /// 0.25 = 25 % de la ganancia de la venta al fondo del equipo.
  final double fundRate;

  int get personalPercent => (personalRate * 100).round();
  int get fundPercent => (fundRate * 100).round();
}

class Session {
  const Session({required this.seller, required this.rules});

  factory Session.fromJson(Json json) => Session(
        seller: Seller.fromJson(json.obj('seller')),
        rules: CommissionRules.fromJson(json.obj('rules')),
      );

  final Seller seller;
  final CommissionRules rules;
}

abstract interface class AuthRepository {
  /// Ingresa con código + PIN. Guarda el token y devuelve la sesión.
  /// Lanza [UnauthorizedException] si el código o el PIN no coinciden.
  Future<Session> login({
    required String code,
    required String pin,
    required String deviceName,
  });

  /// Recupera la sesión con el token guardado. `null` si no hay token o ya
  /// no es válido.
  Future<Session?> restore();

  /// Revoca el token en el servidor y lo borra del celular.
  Future<void> logout();
}
