/// Cumplimiento, cierre semanal, bono y comisiones.
library;

import '../../../core/money/money.dart';
import '../../../core/network/json.dart';
import '../../team/domain/bonus.dart';

class ComplianceRow {
  const ComplianceRow({
    required this.id,
    required this.name,
    required this.title,
    required this.partialScorePercent,
    required this.minimumPercent,
    required this.compliance,
    required this.indicatorsLoaded,
    required this.indicatorsTotal,
    this.scorePercent,
    this.deliverablesOnTime,
    this.deliverablesTotal,
    this.closedReason,
  });

  factory ComplianceRow.fromJson(Json json) => ComplianceRow(
        closedReason: json.strOrNull('closed_reason'),
        id: json.str('id'),
        name: json.str('name'),
        title: json.str('title'),
        scorePercent: json.integerOrNull('score_percent'),
        partialScorePercent: json.integer('partial_score_percent'),
        minimumPercent: json.integer('minimum_percent'),
        compliance: Compliance.fromApi(json.str('compliance')),
        indicatorsLoaded: json.integer('indicators_loaded'),
        indicatorsTotal: json.integer('indicators_total'),
        deliverablesOnTime: json.integerOrNull('deliverables_on_time'),
        deliverablesTotal: json.integerOrNull('deliverables_total'),
      );

  final String id;
  final String name;
  final String title;
  final int? scorePercent;
  final int partialScorePercent;
  final int minimumPercent;
  final Compliance compliance;
  final int indicatorsLoaded;
  final int indicatorsTotal;
  final int? deliverablesOnTime;
  final int? deliverablesTotal;

  /// Jime cerró a mano a esta persona, que seguía pendiente.
  final String? closedReason;

  /// Puntos que faltan para el mínimo (solo si no cumple).
  int? get missingPoints => compliance != Compliance.fails || scorePercent == null
      ? null
      : (minimumPercent - scorePercent!).clamp(0, 100);
}

/// El cumplimiento de todo el equipo en una semana.
class ComplianceWeek {
  const ComplianceWeek({
    required this.weekNumber,
    required this.week,
    required this.currentWeek,
    required this.rows,
  });

  factory ComplianceWeek.fromJson(Json json) {
    final meta = json.obj('meta');
    final week = meta.obj('week');
    return ComplianceWeek(
      weekNumber: week.integer('number'),
      week: BonusWeek.fromJson(week),
      currentWeek: meta.integer('current_week'),
      rows: json.list('data').map(ComplianceRow.fromJson).toList(),
    );
  }

  final int weekNumber;
  final BonusWeek week;

  /// La semana en curso: hasta ahí se puede avanzar.
  final int currentWeek;
  final List<ComplianceRow> rows;
}

enum WeekClosingStatus {
  open('open', 'Abierto'),
  sent('sent', 'Enviado a Dirección'),
  authorized('authorized', 'Autorizado'),
  returned('returned', 'Devuelto a Jime'),
  paid('paid', 'Pagado');

  const WeekClosingStatus(this.apiValue, this.label);
  final String apiValue;
  final String label;

  static WeekClosingStatus fromApi(String value) =>
      values.firstWhere((s) => s.apiValue == value);
}

/// Uno de los 4 controles del cierre, con su explicación.
class ClosingCheck {
  const ClosingCheck({required this.ok, required this.detail});

  factory ClosingCheck.fromJson(Json json) =>
      ClosingCheck(ok: json.flag('ok'), detail: json.str('detail'));

  final bool ok;
  final String detail;
}

/// Quien sigue pendiente. Para enviar el cierre, Jime tiene que resolverlo o
/// cerrarlo como «no cumple» con un motivo.
class PendingMember {
  const PendingMember({required this.id, required this.name, required this.pendingReason});

  factory PendingMember.fromJson(Json json) => PendingMember(
        id: json.str('id'),
        name: json.str('name'),
        pendingReason: json.str('pending_reason'),
      );

  final String id;
  final String name;

  /// Qué le falta. Ej: «2 de 4 entregas validadas».
  final String pendingReason;
}

class WeeklyClosing {
  const WeeklyClosing({
    required this.weekNumber,
    required this.currentWeek,
    required this.sendableFrom,
    required this.week,
    required this.status,
    required this.paymentsReconciled,
    required this.kpiEvidence,
    required this.duplicates,
    required this.direction,
    required this.pendingMembers,
    this.observations,
    this.returnReason,
  });

  factory WeeklyClosing.fromJson(Json json) {
    final week = json.obj('week');
    final checks = json.obj('checks');
    return WeeklyClosing(
      weekNumber: week.integer('number'),
      currentWeek: json.integer('current_week'),
      sendableFrom: json.date('sendable_from'),
      week: BonusWeek.fromJson(week),
      status: WeekClosingStatus.fromApi(json.str('status')),
      paymentsReconciled: ClosingCheck.fromJson(checks.obj('payments_reconciled')),
      kpiEvidence: ClosingCheck.fromJson(checks.obj('kpi_evidence')),
      duplicates: ClosingCheck.fromJson(checks.obj('duplicates_cleared')),
      direction: ClosingCheck.fromJson(checks.obj('direction_approval')),
      pendingMembers: json.list('pending_members').map(PendingMember.fromJson).toList(),
      observations: json.strOrNull('observations'),
      returnReason: json.strOrNull('return_reason'),
    );
  }

  final int weekNumber;
  final int currentWeek;

  /// Desde este día se puede enviar: cuando la semana ya terminó.
  final DateTime sendableFrom;
  final BonusWeek week;
  final WeekClosingStatus status;
  final ClosingCheck paymentsReconciled;
  final ClosingCheck kpiEvidence;
  final ClosingCheck duplicates;
  final ClosingCheck direction;

  final List<PendingMember> pendingMembers;
  final String? observations;
  final String? returnReason;
}

class BonusRow {
  const BonusRow({
    required this.id,
    required this.name,
    required this.shareRate,
    required this.compliance,
    required this.shareAmount,
    this.amount,
    this.paidAt,
    this.closedReason,
  });

  factory BonusRow.fromJson(Json json) => BonusRow(
        closedReason: json.strOrNull('closed_reason'),
        id: json.str('id'),
        name: json.str('name'),
        shareRate: json.rate('fund_share_rate'),
        compliance: Compliance.fromApi(json.str('compliance')),
        shareAmount: json.money('share_amount'),
        amount: json.moneyOrNull('amount'),
        paidAt: json.dateOrNull('paid_at'),
      );

  final String id;
  final String name;
  final double shareRate;
  final Compliance compliance;

  /// Lo que valdría su parte.
  final Money shareAmount;

  /// Lo que le toca; `null` mientras esté pendiente.
  final Money? amount;
  final DateTime? paidAt;

  /// Motivo, si Jime cerró a mano a esta persona.
  final String? closedReason;
}

class WeekBonus {
  const WeekBonus({
    required this.weekNumber,
    required this.currentWeek,
    required this.week,
    required this.status,
    required this.collected,
    required this.achievementPercent,
    required this.level,
    required this.releaseFactor,
    required this.fund,
    required this.payable,
    required this.unpaid,
    required this.members,
  });

  factory WeekBonus.fromJson(Json json) {
    final week = json.obj('week');
    return WeekBonus(
      weekNumber: week.integer('number'),
      currentWeek: json.integer('current_week'),
      week: BonusWeek.fromJson(week),
      status: WeekClosingStatus.fromApi(json.str('status')),
      collected: json.money('collected'),
      achievementPercent: json.integer('achievement_percent'),
      level: BonusLevel.values.byName(json.str('tier')),
      releaseFactor: json.rate('release_factor'),
      fund: json.money('fund'),
      payable: json.money('payable'),
      unpaid: json.money('unpaid'),
      members: json.list('members').map(BonusRow.fromJson).toList(),
    );
  }

  final int weekNumber;
  final int currentWeek;
  final BonusWeek week;
  final WeekClosingStatus status;
  final Money collected;
  final int achievementPercent;
  final BonusLevel level;
  final double releaseFactor;
  final Money fund;
  final Money payable;
  final Money unpaid;
  final List<BonusRow> members;

  /// Solo se paga cuando Dirección lo autorizó.
  bool get readyToPay => status == WeekClosingStatus.authorized;
}

enum SettlementStatus {
  open('open', 'Sin enviar a Dirección'),
  sent('sent', 'Enviada a Dirección'),
  authorized('authorized', 'Autorizada'),
  returned('returned', 'Devuelta'),
  paid('paid', 'Pagada');

  const SettlementStatus(this.apiValue, this.label);
  final String apiValue;
  final String label;

  static SettlementStatus fromApi(String value) =>
      values.firstWhere((s) => s.apiValue == value);
}

class CommissionRow {
  const CommissionRow({
    required this.id,
    required this.name,
    required this.paidSales,
    required this.adjustments,
    this.amount,
  });

  factory CommissionRow.fromJson(Json json) => CommissionRow(
        id: json.str('id'),
        name: json.str('name'),
        amount: json.moneyOrNull('amount'),
        paidSales: json.integer('paid_sales'),
        adjustments: json.money('adjustments'),
      );

  final String id;
  final String name;
  final Money? amount;
  final int paidSales;

  /// Devoluciones descontadas (negativo).
  final Money adjustments;
}

/// El mes como lo pide la API: `2026-12`.
String monthKey(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}';

class MonthCommissions {
  const MonthCommissions({
    required this.month,
    required this.status,
    required this.ratesPending,
    required this.members,
    this.total,
    this.settlesOn,
    this.returnReason,
  });

  factory MonthCommissions.fromJson(Json json) => MonthCommissions(
        month: json.str('month'),
        status: SettlementStatus.fromApi(json.str('status')),
        ratesPending: json.flag('rates_pending'),
        total: json.moneyOrNull('total'),
        members: json.list('members').map(CommissionRow.fromJson).toList(),
        settlesOn: json.dateOrNull('settles_on'),
        returnReason: json.strOrNull('return_reason'),
      );

  /// `2026-12`.
  final String month;
  final SettlementStatus status;

  /// Hay ventas de productos sin % definido: no se puede liquidar.
  final bool ratesPending;
  final Money? total;
  final List<CommissionRow> members;
  final DateTime? settlesOn;
  final String? returnReason;

  /// Hay ventas cobradas o devoluciones que liquidar.
  bool get hasActivity => members.any((m) => m.paidSales > 0 || !m.adjustments.isZero);
}

abstract interface class PayoutsRepository {
  /// Sin [weekNumber], la semana que falta cerrar.
  Future<ComplianceWeek> compliance({int? weekNumber});

  Future<WeeklyClosing> weeklyClosing({int? weekNumber});

  /// Envía el cierre a Dirección. Los cobros y la evidencia los comprueba el
  /// servidor; Jime confirma que no quedan duplicados. [closePending] (id de
  /// integrante → motivo) cierra como «no cumple» a quienes sigan pendientes.
  /// Lanza [ConflictException] con `pending_members`, o [ValidationException]
  /// con `checks_failed` o `not_pending`.
  Future<WeeklyClosing> sendWeeklyClosing(
    int weekNumber, {
    required bool duplicatesCleared,
    Map<String, String> closePending = const {},
    String? observations,
  });

  Future<WeekBonus> bonus({int? weekNumber});

  Future<WeekBonus> markBonusPaid(int weekNumber, String memberId);

  Future<MonthCommissions> commissions(String month);

  Future<MonthCommissions> sendCommissions(String month);

  Future<MonthCommissions> markCommissionsPaid(String month);
}
