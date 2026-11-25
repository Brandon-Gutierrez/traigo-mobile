import 'package:flutter_test/flutter_test.dart';
import 'package:traigo/core/money/money.dart';
import 'package:traigo/features/team/domain/bonus.dart';

/// Reglas del bono semanal del Excel de Jime.
void main() {
  final week = BonusWeek(
    label: '1–6 dic',
    startsOn: DateTime(2026, 12, 1),
    endsOn: DateTime(2026, 12, 6),
    target: Money.parse('40000'),
    basePrize: Money.parse('1500'),
  );

  BonusLevel levelAt(String collected) =>
      BonusRules.levelFor(Money.parse(collected), week.target);

  test('el escalón se alcanza exactamente en 90, 100 y 115 % de la meta', () {
    expect(levelAt('35999.99'), BonusLevel.none);
    expect(levelAt('36000'), BonusLevel.partial);
    expect(levelAt('39999.99'), BonusLevel.partial);
    expect(levelAt('40000'), BonusLevel.complete);
    expect(levelAt('45999.99'), BonusLevel.complete);
    expect(levelAt('46000'), BonusLevel.superior);
  });

  test('el % se redondea hacia abajo: 99,99 % no se anuncia como 100 %', () {
    expect(BonusRules.percent(Money.parse('39999.99'), week.target), 99);
    expect(BonusRules.percent(Money.parse('41600'), week.target), 104);
    expect(BonusRules.percent(Money.parse('10'), Money.zero), 0);
  });

  test('el monto de cada escalón se redondea hacia arriba', () {
    // 90 % de Bs 33,33 son 29,997: hacen falta 30,00.
    expect(
      BonusRules.threshold(Money.parse('33.33'), BonusLevel.partial),
      Money.parse('30'),
    );
  });

  test('el premio es la mitad, entero o 125 % del premio base', () {
    Money prize(BonusLevel level) => BonusRules.prizeAt(week.basePrize, level);
    expect(prize(BonusLevel.none), Money.zero);
    expect(prize(BonusLevel.partial), Money.parse('750'));
    expect(prize(BonusLevel.complete), Money.parse('1500'));
    expect(prize(BonusLevel.superior), Money.parse('1875'));
  });

  test('el siguiente escalón avanza hasta el superior y ahí termina', () {
    expect(BonusRules.nextLevel(BonusLevel.none), BonusLevel.partial);
    expect(BonusRules.nextLevel(BonusLevel.partial), BonusLevel.complete);
    expect(BonusRules.nextLevel(BonusLevel.complete), BonusLevel.superior);
    expect(BonusRules.nextLevel(BonusLevel.superior), isNull);
  });

  test('la parte de quien no cumple no se reparte entre los demás', () {
    const passes = Compliance.passes;
    final result = BonusRules.distribute(
      collected: Money.parse('41600'),
      week: week,
      shares: const [
        BonusShare(name: 'Ailén', rate: 0.20, compliance: passes),
        BonusShare(name: 'Isaí', rate: 0.20, compliance: passes),
        BonusShare(name: 'Kim', rate: 0.20, compliance: Compliance.fails),
        BonusShare(name: 'Alison', rate: 0.20, compliance: passes),
        BonusShare(name: 'Sistemas 1', rate: 0.10, compliance: Compliance.pending),
        BonusShare(name: 'Sistemas 2', rate: 0.10, compliance: passes),
      ],
    );

    expect(result.level, BonusLevel.complete);
    expect(result.prize, Money.parse('1500'));
    expect(result.payable, Money.parse('1050'));
    expect(result.unpaidFailing, Money.parse('300'));
    expect(result.unpaidPending, Money.parse('150'));
    expect(result.payable + result.unpaid, result.prize);
  });

  test('sin llegar al 90 % no hay premio para nadie', () {
    final result = BonusRules.distribute(
      collected: Money.parse('35000'),
      week: week,
      shares: const [BonusShare(name: 'Kim', rate: 0.20, compliance: Compliance.passes)],
    );
    expect(result.prize, Money.zero);
    expect(result.payable, Money.zero);
  });
}
