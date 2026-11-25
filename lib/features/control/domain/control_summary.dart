import '../../../core/money/money.dart';
import '../../../core/network/json.dart';
import '../../team/domain/bonus.dart';

/// Lo que Jime tiene por revisar.
class PendingReview {
  const PendingReview({
    required this.payments,
    required this.evidence,
    required this.cashClosings,
    required this.deliverables,
  });

  factory PendingReview.fromJson(Json json) => PendingReview(
        payments: json.integer('payments'),
        evidence: json.integer('evidence'),
        cashClosings: json.integer('cash_closings'),
        deliverables: json.integer('deliverables'),
      );

  final int payments;
  final int evidence;
  final int cashClosings;
  final int deliverables;

  int get total => payments + evidence + cashClosings + deliverables;
}

class MemberResult {
  const MemberResult({
    required this.id,
    required this.name,
    required this.scorePercent,
    required this.minimumPercent,
    required this.compliance,
    required this.fundShareRate,
    this.note,
  });

  factory MemberResult.fromJson(Json json) => MemberResult(
        id: json.str('id'),
        name: json.str('name'),
        scorePercent: json.integer('score_percent'),
        minimumPercent: json.integer('minimum_percent'),
        compliance: Compliance.fromApi(json.str('compliance')),
        fundShareRate: json.rate('fund_share_rate'),
        note: json.strOrNull('note'),
      );

  final String id;
  final String name;
  final int scorePercent;
  final int minimumPercent;
  final Compliance compliance;
  final double fundShareRate;

  /// Por qué está pendiente. Ej: «2 de 4 entregas validadas».
  final String? note;
}

/// El reparto del bono que calculó el servidor.
class BonusResult {
  const BonusResult({
    required this.level,
    required this.prize,
    required this.payable,
    required this.unpaidFailing,
    required this.unpaidPending,
  });

  factory BonusResult.fromJson(Json json) => BonusResult(
        level: BonusLevel.values.byName(json.str('level')),
        prize: json.money('prize'),
        payable: json.money('payable'),
        unpaidFailing: json.money('unpaid_failing'),
        unpaidPending: json.money('unpaid_pending'),
      );

  final BonusLevel level;
  final Money prize;
  final Money payable;
  final Money unpaidFailing;
  final Money unpaidPending;

  Money get unpaid => unpaidFailing + unpaidPending;
}

class ControlSummary {
  const ControlSummary({
    required this.asOf,
    required this.week,
    required this.collected,
    required this.pending,
    required this.members,
    required this.bonus,
  });

  factory ControlSummary.fromJson(Json json) => ControlSummary(
        asOf: json.date('as_of'),
        week: BonusWeek.fromJson(json.obj('week')),
        collected: json.money('collected'),
        pending: PendingReview.fromJson(json.obj('pending')),
        members: json.list('members').map(MemberResult.fromJson).toList(),
        bonus: BonusResult.fromJson(json.obj('bonus')),
      );

  final DateTime asOf;
  final BonusWeek week;
  final Money collected;
  final PendingReview pending;
  final List<MemberResult> members;
  final BonusResult bonus;

  int get percent => BonusRules.percent(collected, week.target);
}

abstract interface class ControlRepository {
  Future<ControlSummary> summary();
}
