import '../../../core/money/money.dart';
import '../../../core/network/json.dart';
import '../../orders/domain/payment_method.dart';
import '../../team/domain/bonus.dart';
import '../../team/domain/kpi.dart';
import '../../warehouse/domain/cash_status.dart';

export '../../orders/domain/payment_method.dart';
export '../../warehouse/domain/cash_status.dart';

/// Mi KPI de la semana. El puntaje y el resultado los calcula el servidor
/// (con las reglas del Excel); la app solo los muestra.
class MyKpi {
  const MyKpi({
    required this.scorePercent,
    required this.minimumPercent,
    required this.compliance,
    required this.indicators,
    this.deliverables,
    this.closedReason,
  });

  factory MyKpi.fromJson(Json json) {
    final deliverables = json.objOrNull('deliverables');
    return MyKpi(
      closedReason: json.strOrNull('closed_reason'),
      scorePercent: json.integer('score_percent'),
      minimumPercent: json.integer('minimum_percent'),
      compliance: Compliance.fromApi(json.str('compliance')),
      indicators: json.list('indicators').map(KpiIndicator.fromJson).toList(),
      deliverables: deliverables == null ? null : DeliverableProgress.fromJson(deliverables),
    );
  }

  final int scorePercent;
  final int minimumPercent;
  final Compliance compliance;
  final List<KpiIndicator> indicators;

  /// Solo Sistemas: entregas técnicas obligatorias.
  final DeliverableProgress? deliverables;

  /// Motivo, si Jime cerró la semana de esta persona como «no cumple» porque
  /// seguía pendiente.
  final String? closedReason;

  /// Indicadores cuya evidencia todavía no está validada.
  List<KpiIndicator> get awaitingEvidence =>
      indicators.where((i) => i.evidence != EvidenceStatus.validated).toList();
}

class DeliverableProgress {
  const DeliverableProgress({required this.approved, required this.total});

  factory DeliverableProgress.fromJson(Json json) =>
      DeliverableProgress(approved: json.integer('approved'), total: json.integer('total'));

  final int approved;
  final int total;

  bool get complete => approved >= total;
}

class TodaySale {
  const TodaySale({
    required this.id,
    required this.createdAt,
    required this.itemsLabel,
    required this.customerName,
    required this.total,
    required this.paymentMethod,
  });

  factory TodaySale.fromJson(Json json) => TodaySale(
        id: json.str('id'),
        createdAt: json.date('created_at'),
        itemsLabel: json.str('items_label'),
        customerName: json.str('customer_name'),
        total: json.money('total'),
        paymentMethod: PaymentMethod.fromApi(json.str('payment_method')),
      );

  final String id;
  final DateTime createdAt;
  final String itemsLabel;
  final String customerName;
  final Money total;
  final PaymentMethod paymentMethod;
}

/// Comisión del mes de quien vende. Se paga una vez al mes.
class MonthCommission {
  const MonthCommission({required this.amount, this.payNote});

  factory MonthCommission.fromJson(Json json) => MonthCommission(
        amount: json.money('amount'),
        payNote: json.strOrNull('pay_note'),
      );

  final Money amount;

  /// Cuándo se paga. `null` = todavía por definir.
  final String? payNote;
}

/// Caja del día (almacén: cierra la caja de todo el equipo).
class CashToday {
  const CashToday({
    required this.collected,
    required this.paidOrders,
    required this.pendingOrders,
    required this.status,
    this.pendingDays = 0,
  });

  factory CashToday.fromJson(Json json) => CashToday(
        collected: json.money('collected'),
        paidOrders: json.integer('paid_orders'),
        pendingOrders: json.integer('pending_orders'),
        status: CashStatus.fromApi(json.str('status')),
        pendingDays: json.integerOrNull('pending_days') ?? 0,
      );

  final Money collected;
  final int paidOrders;
  final int pendingOrders;
  final CashStatus status;

  /// Días anteriores sin enviar o que Jime observó.
  final int pendingDays;
}

/// Todo lo que muestra el Inicio de un integrante.
class TeamHome {
  const TeamHome({
    required this.week,
    required this.collected,
    required this.fundShareRate,
    required this.kpi,
    this.monthCommission,
    this.todaySales = const [],
    this.cashToday,
  });

  factory TeamHome.fromJson(Json json) {
    final commission = json.objOrNull('month_commission');
    final cash = json.objOrNull('cash_today');
    return TeamHome(
      week: BonusWeek.fromJson(json.obj('week')),
      collected: json.money('collected'),
      fundShareRate: json.rate('fund_share_rate'),
      kpi: MyKpi.fromJson(json.obj('kpi')),
      monthCommission: commission == null ? null : MonthCommission.fromJson(commission),
      todaySales: json.list('today_sales').map(TodaySale.fromJson).toList(),
      cashToday: cash == null ? null : CashToday.fromJson(cash),
    );
  }

  final BonusWeek week;

  /// Ventas cobradas del equipo en la semana.
  final Money collected;

  /// Mi parte del fondo del bono: 0.20 = 20 %.
  final double fundShareRate;
  final MyKpi kpi;

  /// Solo quienes venden.
  final MonthCommission? monthCommission;
  final List<TodaySale> todaySales;

  /// Solo almacén.
  final CashToday? cashToday;

  int get percent => BonusRules.percent(collected, week.target);
  BonusLevel get level => BonusRules.levelFor(collected, week.target);

  /// Mi parte si el equipo cierra en [level] (y yo cumplo mi KPI).
  Money shareAt(BonusLevel level) =>
      BonusRules.prizeAt(week.basePrize, level).percent(fundShareRate);
}

abstract interface class HomeRepository {
  Future<TeamHome> load();
}
