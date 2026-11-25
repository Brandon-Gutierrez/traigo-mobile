/// Lo que Dirección autoriza o devuelve: bono semanal, comisiones del mes,
/// cambios de precio y promociones. Nadie aprueba lo propio.
library;

import '../../../core/money/money.dart';
import '../../../core/network/json.dart';

enum AuthorizationType {
  weeklyBonus('weekly_bonus', 'Bono semanal'),
  commissions('commissions', 'Comisiones'),
  priceChange('price_change', 'Cambio de precio'),
  promotion('promotion', 'Promoción');

  const AuthorizationType(this.apiValue, this.label);
  final String apiValue;
  final String label;

  static AuthorizationType fromApi(String value) =>
      values.firstWhere((t) => t.apiValue == value);
}

class AuthorizationItem {
  const AuthorizationItem({
    required this.type,
    required this.id,
    required this.title,
    required this.requestedBy,
    required this.requestedAt,
    this.amount,
  });

  factory AuthorizationItem.fromJson(Json json) => AuthorizationItem(
        type: AuthorizationType.fromApi(json.str('type')),
        id: json.str('id'),
        title: json.str('title'),
        requestedBy: json.str('requested_by'),
        requestedAt: json.date('requested_at'),
        amount: json.moneyOrNull('amount'),
      );

  final AuthorizationType type;
  final String id;
  final String title;
  final String requestedBy;
  final DateTime requestedAt;
  final Money? amount;
}

class PayLine {
  const PayLine({required this.name, required this.amount, this.reason});

  factory PayLine.fromJson(Json json) => PayLine(
        name: json.str('name'),
        amount: json.money('amount'),
        reason: json.strOrNull('reason'),
      );

  final String name;
  final Money amount;

  /// Por qué no se paga.
  final String? reason;
}

/// Un cambio de valor (precio, comisión, descuento…).
class ValueChange {
  const ValueChange({required this.label, required this.after, this.before});

  factory ValueChange.fromJson(Json json) => ValueChange(
        label: json.str('label'),
        before: json.strOrNull('before'),
        after: json.str('after'),
      );

  final String label;
  final String? before;
  final String after;
}

class AuthorizationDetail {
  const AuthorizationDetail({
    required this.item,
    required this.pays,
    required this.unpaid,
    required this.checks,
    required this.changes,
    required this.canApprove,
    this.blockedReason,
  });

  factory AuthorizationDetail.fromJson(Json json) => AuthorizationDetail(
        item: AuthorizationItem.fromJson(json),
        pays: json.list('pays').map(PayLine.fromJson).toList(),
        unpaid: json.list('unpaid').map(PayLine.fromJson).toList(),
        checks: json.strings('checks'),
        changes: json.list('changes').map(ValueChange.fromJson).toList(),
        canApprove: json.flag('can_approve'),
        blockedReason: json.strOrNull('blocked_reason'),
      );

  final AuthorizationItem item;
  final List<PayLine> pays;
  final List<PayLine> unpaid;

  /// Los controles que ya hizo Jime, redactados.
  final List<String> checks;
  final List<ValueChange> changes;
  final bool canApprove;

  /// Ej: «Sistemas 1 todavía está pendiente».
  final String? blockedReason;
}

abstract interface class ManagementRepository {
  Future<List<AuthorizationItem>> pending();

  Future<AuthorizationDetail> detail(AuthorizationType type, String id);

  Future<void> approve(AuthorizationType type, String id);

  /// Devuelve a quien lo envió, explicando por qué.
  Future<void> sendBack(AuthorizationType type, String id, {required String reason});
}
