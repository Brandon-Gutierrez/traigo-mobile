import '../../../core/money/money.dart';
import '../../../core/network/json.dart';
import '../../orders/domain/orders.dart';

class TodaySummary {
  const TodaySummary({
    required this.commission,
    required this.salesCount,
    required this.soldTotal,
  });

  factory TodaySummary.fromJson(Json json) => TodaySummary(
        commission: json.money('commission'),
        salesCount: json.integer('sales_count'),
        soldTotal: json.money('sold_total'),
      );

  /// «Ganaste hoy».
  final Money commission;
  final int salesCount;
  final Money soldTotal;
}

class MonthSummary {
  const MonthSummary({
    required this.personalCommission,
    required this.fundShare,
    required this.estimatedTotal,
  });

  factory MonthSummary.fromJson(Json json) => MonthSummary(
        personalCommission: json.money('personal_commission'),
        fundShare: json.money('fund_share'),
        estimatedTotal: json.money('estimated_total'),
      );

  final Money personalCommission;

  /// Parte que le toca del fondo común del equipo.
  final Money fundShare;
  final Money estimatedTotal;
}

class FundProgress {
  const FundProgress({required this.current, required this.goal, this.prizeLabel});

  factory FundProgress.fromJson(Json json) => FundProgress(
        current: json.money('current'),
        goal: json.money('goal'),
        prizeLabel: json.strOrNull('prize_label'),
      );

  final Money current;
  final Money goal;

  /// Premio del hito. `null` mientras el dueño no lo defina.
  final String? prizeLabel;

  Money get remaining => goal > current ? goal - current : Money.zero;

  /// Entre 0 y 1, para la barra de avance.
  double get progress =>
      goal.cents == 0 ? 0 : (current.cents / goal.cents).clamp(0.0, 1.0);
}

class HomeSummary {
  const HomeSummary({
    required this.today,
    required this.month,
    required this.fund,
    required this.recentOrders,
    this.payoutNote,
  });

  factory HomeSummary.fromJson(Json json) => HomeSummary(
        today: TodaySummary.fromJson(json.obj('today')),
        month: MonthSummary.fromJson(json.obj('month')),
        fund: FundProgress.fromJson(json.obj('fund')),
        payoutNote: json.strOrNull('payout_note'),
        recentOrders: json.list('recent_orders').map(OrderSummary.fromJson).toList(),
      );

  final TodaySummary today;
  final MonthSummary month;
  final FundProgress fund;

  /// Cómo y cuándo se pagan las comisiones. `null` = todavía por definir.
  final String? payoutNote;

  /// Últimas ventas, para la lista «Ventas de hoy».
  final List<OrderSummary> recentOrders;
}

abstract interface class HomeRepository {
  Future<HomeSummary> load();
}
