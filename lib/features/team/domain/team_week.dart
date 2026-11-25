/// La pantalla «Equipo»: la meta de la semana, los escalones y la campaña.
library;

import '../../../core/money/money.dart';
import '../../../core/network/json.dart';
import 'bonus.dart';
import 'my_week.dart';

class TierRow {
  const TierRow({
    required this.tier,
    required this.thresholdPercent,
    required this.salesNeeded,
    required this.fund,
    required this.myShare,
  });

  factory TierRow.fromJson(Json json) => TierRow(
        tier: BonusLevel.values.byName(json.str('tier')),
        thresholdPercent: json.integer('threshold_percent'),
        salesNeeded: json.money('sales_needed'),
        fund: json.money('fund'),
        myShare: json.money('my_share'),
      );

  final BonusLevel tier;
  final int thresholdPercent;
  final Money salesNeeded;
  final Money fund;
  final Money myShare;
}

class CampaignWeek {
  const CampaignWeek({required this.number, required this.week, required this.isCurrent});

  factory CampaignWeek.fromJson(Json json) => CampaignWeek(
        number: json.integer('number'),
        week: BonusWeek.fromJson(json),
        isCurrent: json.flag('is_current'),
      );

  final int number;
  final BonusWeek week;
  final bool isCurrent;
}

class TeamWeek {
  const TeamWeek({
    required this.week,
    required this.collected,
    required this.tiers,
    required this.myShareRate,
    required this.myMinimumPercent,
    required this.myPartialScorePercent,
    required this.myCompliance,
    required this.weeks,
  });

  factory TeamWeek.fromJson(Json json) {
    final me = json.obj('me');
    return TeamWeek(
      week: BonusWeek.fromJson(json.obj('week')),
      collected: json.money('collected'),
      tiers: json.list('tiers').map(TierRow.fromJson).toList(),
      myShareRate: me.rate('fund_share_rate'),
      myMinimumPercent: me.integer('minimum_percent'),
      myPartialScorePercent: me.integer('partial_score_percent'),
      myCompliance: Compliance.fromApi(me.str('compliance')),
      weeks: json.list('weeks').map(CampaignWeek.fromJson).toList(),
    );
  }

  final BonusWeek week;
  final Money collected;
  final List<TierRow> tiers;
  final double myShareRate;
  final int myMinimumPercent;
  final int myPartialScorePercent;
  final Compliance myCompliance;

  /// Todas las semanas de la campaña.
  final List<CampaignWeek> weeks;

  int get percent => BonusRules.percent(collected, week.target);
}

abstract interface class TeamRepository {
  Future<TeamWeek> teamWeek();

  /// La semana en curso, o la [weekNumber] pedida.
  Future<MyWeek> myWeek({int? weekNumber});

  /// [resultId] es el `id` del indicador en «Mi semana».
  Future<Evidence> submitEvidence(String resultId, NewEvidence evidence);

  /// Envía una entrega de Sistemas con su evidencia (archivo o enlace).
  Future<Deliverable> submitDeliverable(
    String id, {
    required DateTime deliveredOn,
    required String clientUuid,
    UploadFile? file,
    String? url,
    String? note,
  });
}
