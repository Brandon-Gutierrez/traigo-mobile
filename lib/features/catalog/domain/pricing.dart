/// Regla de precio (decisión del 24/11/2026):
///
/// - Cada producto va a **precio por mayor** cuando se piden al menos sus
///   unidades mínimas del mismo código.
/// - Si no llega, ese producto va a precio por unidad.
/// - No hay un monto mínimo de pedido (el Excel proponía Bs 1.000; se quitó).
///
/// El servidor calcula los precios definitivos; la app usa esta misma regla
/// para mostrar el total antes de registrar y lo envía para que se compare.
library;

import '../../../core/money/money.dart';
import 'catalog.dart';

enum PriceType {
  unit('unit', 'minorista'),
  wholesale('wholesale', 'mayorista'),
  combo('combo', 'combo');

  const PriceType(this.apiValue, this.label);
  final String apiValue;
  final String label;

  static PriceType fromApi(String value) => values.firstWhere((t) => t.apiValue == value);
}

class CartLine {
  const CartLine(this.item, this.quantity) : assert(quantity > 0);

  final CatalogItem item;
  final int quantity;

  /// Llegó al mínimo de su código: va por mayor.
  bool get reachesMinimum {
    final minimum = item.wholesaleMinQty;
    return item.priceWholesale != null && minimum != null && quantity >= minimum;
  }

  PriceType get priceType => reachesMinimum ? PriceType.wholesale : PriceType.unit;

  Money get unitPrice => reachesMinimum ? item.priceWholesale! : item.priceUnit;

  Money get total => unitPrice * quantity;

  /// Cuántas unidades faltan para el precio por mayor (`null` si ya llegó o si
  /// el producto no tiene precio por mayor).
  int? get missingForMinimum {
    final minimum = item.wholesaleMinQty;
    if (item.priceWholesale == null || minimum == null || quantity >= minimum) {
      return null;
    }
    return minimum - quantity;
  }
}

class PricedCart {
  const PricedCart(this.lines);

  final List<CartLine> lines;

  Money _sum(bool Function(CartLine) include) =>
      lines.where(include).fold(Money.zero, (sum, line) => sum + line.total);

  /// Lo que va por mayor.
  Money get wholesaleTotal => _sum((l) => l.reachesMinimum);

  /// Lo que va por unidad.
  Money get unitTotal => _sum((l) => !l.reachesMinimum);

  int get wholesaleCount => lines.where((l) => l.reachesMinimum).length;

  Money get total => _sum((_) => true);
}
