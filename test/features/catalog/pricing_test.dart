import 'package:flutter_test/flutter_test.dart';
import 'package:traigo/core/money/money.dart';
import 'package:traigo/features/catalog/domain/catalog.dart';
import 'package:traigo/features/catalog/domain/pricing.dart';

/// Reglas del Excel de precios y mínimos mayoristas.
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
final planter = product('730', '690', 3);

PricedCart price(List<CartLine> lines) =>
    PricingRules.price(lines, wholesaleMinOrder: Money.parse('1000'));

void main() {
  test('como en el mockup: un código por mayor y otro por unidad', () {
    final cart = price([CartLine(messi, 24), CartLine(cement, 10)]);

    expect(cart.wholesaleApplies, isTrue);
    expect(cart.lines.map((l) => l.priceType), [PriceType.wholesale, PriceType.unit]);
    expect(cart.eligibleWholesale, Money.parse('1968'));
    expect(cart.total, Money.parse('2268'));
    expect(cart.lines.last.missingForMinimum, 14);
  });

  test('llegar al mínimo del código no basta si el pedido no llega a Bs 1.000', () {
    final cart = price([CartLine(cement, 24)]);

    expect(cart.wholesaleApplies, isFalse);
    expect(cart.lines.single.unitPrice, Money.parse('30'));
    expect(cart.missingForMinOrder, Money.parse('400'));
  });

  test('se suman varios códigos si cada uno llega a su mínimo', () {
    final cart = price([CartLine(cement, 24), CartLine(planter, 3)]);

    // 24 × 25 + 3 × 690 = 2.670
    expect(cart.eligibleWholesale, Money.parse('2670'));
    expect(cart.total, Money.parse('2670'));
  });

  test('un código sin su mínimo no suma al pedido mayorista', () {
    final cart = price([CartLine(messi, 23), CartLine(cement, 24)]);

    expect(cart.eligibleWholesale, Money.parse('600'));
    expect(cart.wholesaleApplies, isFalse);
    expect(cart.total, Money.parse('2721')); // 23 × 87 + 24 × 30
  });

  test('exactamente Bs 1.000 ya es pedido mayorista', () {
    final cart = price([CartLine(product('45', '40', 25), 25)]);
    expect(cart.wholesaleApplies, isTrue);
  });

  test('sin precio por mayor siempre va por unidad', () {
    final cart = price([CartLine(product('2000', null, null), 5)]);
    expect(cart.wholesaleApplies, isFalse);
    expect(cart.lines.single.missingForMinimum, isNull);
  });
}
