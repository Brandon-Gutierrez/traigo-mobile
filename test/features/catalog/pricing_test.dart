import 'package:flutter_test/flutter_test.dart';
import 'package:traigo/core/money/money.dart';
import 'package:traigo/features/catalog/domain/catalog.dart';
import 'package:traigo/features/catalog/domain/pricing.dart';

/// Cada producto va por mayor al llegar a su cantidad mínima.
CatalogItem product(String unit, String? wholesale, int? minimum) => CatalogItem(
      id: unit,
      itemCode: unit,
      name: unit,
      category: 'x',
      priceUnit: Money.parse(unit),
      priceWholesale: wholesale == null ? null : Money.parse(wholesale),
      wholesaleMinQty: minimum,
      stock: 1000,
      reserved: 0,
      available: 1000,
    );

final messi = product('87', '82', 24);
final cement = product('30', '25', 24);
final brownPlanter = product('170', '160', 6);

void main() {
  test('como en el mockup: un código por mayor y otro por unidad', () {
    final cart = PricedCart([CartLine(messi, 24), CartLine(cement, 10)]);

    expect(cart.lines.map((l) => l.priceType), [PriceType.wholesale, PriceType.unit]);
    expect(cart.wholesaleTotal, Money.parse('1968'));
    expect(cart.unitTotal, Money.parse('300'));
    expect(cart.total, Money.parse('2268'));
    expect(cart.wholesaleCount, 1);
    expect(cart.lines.last.missingForMinimum, 14);
  });

  test('basta la cantidad mínima: no hay monto mínimo de pedido', () {
    final line = CartLine(brownPlanter, 6);

    expect(line.priceType, PriceType.wholesale);
    expect(line.total, Money.parse('960'), reason: 'aunque no llegue a Bs 1.000');
  });

  test('una unidad menos va por unidad', () {
    final line = CartLine(brownPlanter, 5);

    expect(line.unitPrice, Money.parse('170'));
    expect(line.missingForMinimum, 1);
  });

  test('las unidades de distintos productos no se suman', () {
    final cart = PricedCart([CartLine(messi, 12), CartLine(cement, 12)]);

    expect(cart.wholesaleCount, 0);
    expect(cart.total, Money.parse('1404')); // 12 × 87 + 12 × 30
  });

  test('sin precio por mayor siempre va por unidad', () {
    final line = CartLine(product('2000', null, null), 50);

    expect(line.priceType, PriceType.unit);
    expect(line.missingForMinimum, isNull);
  });
}
