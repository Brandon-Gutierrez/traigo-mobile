/// Reglas del bono grupal semanal, tal como están en el Excel de Jime.
library;

import '../../../core/money/money.dart';
import '../../../core/network/json.dart';

/// Semana de la campaña con su meta de ventas cobradas y su premio base.
class BonusWeek {
  const BonusWeek({
    required this.label,
    required this.startsOn,
    required this.endsOn,
    required this.target,
    required this.basePrize,
  });

  factory BonusWeek.fromJson(Json json) => BonusWeek(
        label: json.str('label'),
        startsOn: json.date('starts_on'),
        endsOn: json.date('ends_on'),
        target: json.money('target'),
        basePrize: json.money('base_prize'),
      );

  /// Ej: «1–6 dic».
  final String label;
  final DateTime startsOn;
  final DateTime endsOn;
  final Money target;
  final Money basePrize;
}

/// Escalón alcanzado: desde qué % de la meta y qué fracción del premio libera.
enum BonusLevel {
  none(0, 0, 'Sin premio'),
  partial(90, 0.5, 'Parcial'),
  complete(100, 1, 'Completo'),
  superior(115, 1.25, 'Superior');

  const BonusLevel(this.fromPercent, this.factor, this.label);

  final int fromPercent;
  final double factor;
  final String label;
}

enum Compliance {
  /// Llegó a su mínimo.
  passes('passes'),

  /// No llegó a su mínimo: no cobra su parte.
  fails('fails'),

  /// Falta cargar algún indicador o validar una entrega.
  pending('pending');

  const Compliance(this.apiValue);
  final String apiValue;

  static Compliance fromApi(String value) =>
      values.firstWhere((c) => c.apiValue == value);
}

/// Parte del fondo de una persona y si cumple.
class BonusShare {
  const BonusShare({required this.name, required this.rate, required this.compliance});

  final String name;

  /// 0.20 = 20 % del fondo.
  final double rate;
  final Compliance compliance;
}

class BonusDistribution {
  const BonusDistribution({
    required this.level,
    required this.prize,
    required this.payable,
    required this.unpaidFailing,
    required this.unpaidPending,
  });

  final BonusLevel level;
  final Money prize;

  /// Lo que se paga a quienes cumplen.
  final Money payable;

  /// Parte de quienes no cumplen: no se reparte a los demás.
  final Money unpaidFailing;

  /// Parte en espera de quienes siguen pendientes.
  final Money unpaidPending;

  Money get unpaid => unpaidFailing + unpaidPending;
}

abstract final class BonusRules {
  /// % de la meta cobrado, redondeado hacia abajo para no anunciar un escalón
  /// que todavía no se alcanzó (99,9 % no es 100 %).
  static int percent(Money collected, Money target) =>
      target.cents == 0 ? 0 : (collected.cents * 100) ~/ target.cents;

  static BonusLevel levelFor(Money collected, Money target) {
    for (final level in [BonusLevel.superior, BonusLevel.complete, BonusLevel.partial]) {
      if (collected >= threshold(target, level)) return level;
    }
    return BonusLevel.none;
  }

  /// Ventas cobradas necesarias para alcanzar [level].
  static Money threshold(Money target, BonusLevel level) =>
      Money.fromCents((target.cents * level.fromPercent + 99) ~/ 100);

  /// El siguiente escalón por alcanzar, o `null` si ya está en el más alto.
  static BonusLevel? nextLevel(BonusLevel current) => switch (current) {
        BonusLevel.none => BonusLevel.partial,
        BonusLevel.partial => BonusLevel.complete,
        BonusLevel.complete => BonusLevel.superior,
        BonusLevel.superior => null,
      };

  static Money prizeAt(Money basePrize, BonusLevel level) => basePrize.percent(level.factor);

  static BonusDistribution distribute({
    required Money collected,
    required BonusWeek week,
    required Iterable<BonusShare> shares,
  }) {
    final level = levelFor(collected, week.target);
    final prize = prizeAt(week.basePrize, level);
    var payable = Money.zero;
    var failing = Money.zero;
    var pending = Money.zero;
    for (final share in shares) {
      final amount = prize.percent(share.rate);
      switch (share.compliance) {
        case Compliance.passes:
          payable += amount;
        case Compliance.fails:
          failing += amount;
        case Compliance.pending:
          pending += amount;
      }
    }
    return BonusDistribution(
      level: level,
      prize: prize,
      payable: payable,
      unpaidFailing: failing,
      unpaidPending: pending,
    );
  }
}
