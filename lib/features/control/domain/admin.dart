/// La pestaña «Más»: precios, historial, reportes, respaldo y accesos.
library;

import '../../../core/money/money.dart';
import '../../../core/network/json.dart';
import '../../../core/network/paged_result.dart';

class PriceValues {
  const PriceValues({
    this.priceUnit,
    this.priceWholesale,
    this.wholesaleMinQty,
    this.commissionPct,
    this.cost,
  });

  factory PriceValues.fromJson(Json json) => PriceValues(
        priceUnit: json.moneyOrNull('price_unit'),
        priceWholesale: json.moneyOrNull('price_wholesale'),
        wholesaleMinQty: json.integerOrNull('wholesale_min_qty'),
        commissionPct: json['commission_pct'] == null ? null : json.rate('commission_pct'),
        cost: json.moneyOrNull('cost'),
      );

  final Money? priceUnit;
  final Money? priceWholesale;
  final int? wholesaleMinQty;

  /// % por producto. `null` = por definir.
  final double? commissionPct;
  final Money? cost;
}

/// Un cambio propuesto que espera la aprobación de Dirección.
class PriceChange {
  const PriceChange({
    required this.id,
    required this.proposed,
    required this.requestedBy,
    required this.requestedAt,
    this.reason,
  });

  factory PriceChange.fromJson(Json json) => PriceChange(
        id: json.str('id'),
        proposed: PriceValues.fromJson(json.obj('proposed')),
        requestedBy: json.str('requested_by'),
        requestedAt: json.date('requested_at'),
        reason: json.strOrNull('reason'),
      );

  final String id;

  /// Solo trae los valores que cambian.
  final PriceValues proposed;
  final String requestedBy;
  final DateTime requestedAt;
  final String? reason;
}

class PriceSheet {
  const PriceSheet({
    required this.productId,
    required this.itemCode,
    required this.name,
    required this.category,
    required this.current,
    this.pendingChange,
  });

  factory PriceSheet.fromJson(Json json) {
    final pending = json.objOrNull('pending_change');
    return PriceSheet(
      productId: json.str('product_id'),
      itemCode: json.str('item_code'),
      name: json.str('name'),
      category: json.str('category'),
      current: PriceValues.fromJson(json.obj('current')),
      pendingChange: pending == null ? null : PriceChange.fromJson(pending),
    );
  }

  final String productId;
  final String itemCode;
  final String name;
  final String category;

  /// El costo solo lo reciben Jime y Dirección.
  final PriceValues current;
  final PriceChange? pendingChange;
}

class AuditEntry {
  const AuditEntry({
    required this.id,
    required this.at,
    required this.actorName,
    required this.description,
  });

  factory AuditEntry.fromJson(Json json) => AuditEntry(
        id: json.str('id'),
        at: json.date('at'),
        actorName: json.str('actor_name'),
        description: json.str('description'),
      );

  final String id;
  final DateTime at;
  final String actorName;

  /// Ya redactado en español por el servidor.
  final String description;
}

class SystemStatus {
  const SystemStatus({this.lastBackupAt, this.restoreTestedAt});

  factory SystemStatus.fromJson(Json json) => SystemStatus(
        lastBackupAt: json.dateOrNull('last_backup_at'),
        restoreTestedAt: json.dateOrNull('restore_tested_at'),
      );

  final DateTime? lastBackupAt;
  final DateTime? restoreTestedAt;
}

enum ReportType {
  /// KPI, bonos, cierre y pagos de una semana (`period`: número de semana).
  week('week'),

  /// Caja de un día por forma de pago (`period`: fecha).
  cash('cash'),

  /// Comisiones de un mes por persona y producto (`period`: `2026-12`).
  commissions('commissions');

  const ReportType(this.apiValue);
  final String apiValue;
}

abstract interface class AdminRepository {
  Future<PriceSheet> priceSheet(String productId);

  /// Solo se envían los valores que cambian; quedan esperando a Dirección.
  Future<PriceSheet> proposePrice(String productId, PriceValues proposed, {String? reason});

  Future<PagedResult<AuditEntry>> audit({int page = 1});

  /// El archivo de Excel.
  Future<List<int>> downloadReport(ReportType type, {required String period});

  Future<SystemStatus> systemStatus();

  /// Para quien olvidó su PIN. Cierra sus sesiones.
  Future<void> resetPin(String memberId, String newPin);

  /// Celular perdido: cierra todas las sesiones de la persona.
  Future<void> revokeSessions(String memberId);
}
