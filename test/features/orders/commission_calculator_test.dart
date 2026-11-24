import 'package:flutter_test/flutter_test.dart';
import 'package:traigo/core/money/money.dart';
import 'package:traigo/features/auth/domain/auth.dart';
import 'package:traigo/features/orders/domain/commission_calculator.dart';

PricedLine line(String price, String min, {int qty = 1}) => PricedLine(
      unitPrice: Money.parse(price),
      minPrice: Money.parse(min),
      quantity: qty,
    );

void main() {
  const rules = CommissionRules(personalRate: 0.40, fundRate: 0.25);

  test('repite la cuenta del diseño: audífonos a 120 y lámpara a 85', () {
    final preview = CommissionCalculator.preview(
      [line('120', '90'), line('85', '65')],
      rules,
    );
    expect(preview.total.toApi(), '205.00');
    expect(preview.gain.toApi(), '50.00');
    expect(preview.personal.toApi(), '20.00');
    expect(preview.fund.toApi(), '12.50');
    expect(preview.hasLineBelowMinimum, isFalse);
  });

  test('multiplica la ganancia por la cantidad', () {
    final preview = CommissionCalculator.preview([line('120', '90', qty: 3)], rules);
    expect(preview.total.toApi(), '360.00');
    expect(preview.gain.toApi(), '90.00');
  });

  test('vender justo en el mínimo no deja ganancia pero es válido', () {
    final preview = CommissionCalculator.preview([line('65', '65')], rules);
    expect(preview.gain, Money.zero);
    expect(preview.hasLineBelowMinimum, isFalse);
  });

  test('una línea bajo el mínimo bloquea y anula la ganancia', () {
    final preview = CommissionCalculator.preview(
      [line('120', '90'), line('60', '65')],
      rules,
    );
    expect(preview.hasLineBelowMinimum, isTrue);
    expect(preview.gain, Money.zero);
    expect(preview.personal, Money.zero);
  });

  test('un combo vendido a 199 con mínimo 191 deja Bs 3,20', () {
    final preview = CommissionCalculator.preview([line('199', '191')], rules);
    expect(preview.personal.toApi(), '3.20');
    expect(preview.fund.toApi(), '2.00');
  });
}
