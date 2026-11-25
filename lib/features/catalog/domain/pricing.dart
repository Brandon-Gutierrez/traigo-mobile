/// Reglas de precio del Excel de precios y mínimos mayoristas:
///
/// - El precio por mayor se aplica a un producto cuando se piden al menos sus
///   unidades mínimas del **mismo código**,
/// - y solo si los productos que llegan a su mínimo suman, a precio por mayor,
///   el pedido mínimo (Bs 1.000). Se pueden juntar varios códigos.
/// - Si no, todo va a precio por unidad.
///
/// El servidor calcula los precios definitivos; la app usa estas mismas reglas
/// para mostrar el total antes de registrar y lo envía para que se compare.
library;

import '../../../core/money/money.dart';
import 'catalog.dart';

enum PriceType {
  unit('unit'),
  wholesale('wholesale'),
  combo('combo');

  const PriceType(this.apiValue);
  final String apiValue;

  static PriceType fromApi(String value) => values.firstWhere((t) => t.apiValue == value);
}

class CartLine {
  const CartLine(this.item, this.quantity) : assert(quantity > 0);

  final CatalogItem item;
  final int quantity;

  /// Llegó al mínimo de su código.
  bool get reachesMinimum {
    final minimum = item.wholesaleMinQty;
    return item.priceWholesale != null && minimum != null && quantity >= minimum;
  }
}

class PricedLine {
  const PricedLine({required this.line, required this.priceType, required this.unitPrice});

  final CartLine line;
  final PriceType priceType;
  final Money unitPrice;

  Money get total => unitPrice * line.quantity;

  /// Cuántas unidades faltan para el mínimo de este código (`null` si ya llegó
  /// o si no tiene precio por mayor).
  int? get missingForMinimum {
    final minimum = line.item.wholesaleMinQty;
    if (minimum == null || line.quantity >= minimum) return null;
    return minimum - line.quantity;
  }
}

class PricedCart {
  const PricedCart({
    required this.lines,
    required this.eligibleWholesale,
    required this.wholesaleMinOrder,
  });

  final List<PricedLine> lines;

  /// Suma, a precio por mayor, de los códigos que llegan a su mínimo.
  final Money eligibleWholesale;
  final Money wholesaleMinOrder;

  bool get wholesaleApplies =>
      !eligibleWholesale.isZero && eligibleWholesale >= wholesaleMinOrder;

  /// Cuánto falta para el pedido mínimo, si algún código ya llegó a su mínimo.
  Money? get missingForMinOrder => eligibleWholesale.isZero || wholesaleApplies
      ? null
      : wholesaleMinOrder - eligibleWholesale;

  Money get total => lines.fold(Money.zero, (sum, line) => sum + line.total);
}

abstract final class PricingRules {
  static PricedCart price(List<CartLine> lines, {required Money wholesaleMinOrder}) {
    final eligible = lines.where((l) => l.reachesMinimum).fold(
          Money.zero,
          (sum, l) => sum + l.item.priceWholesale! * l.quantity,
        );
    final applies = !eligible.isZero && eligible >= wholesaleMinOrder;

    return PricedCart(
      eligibleWholesale: eligible,
      wholesaleMinOrder: wholesaleMinOrder,
      lines: [
        for (final line in lines)
          if (applies && line.reachesMinimum)
            PricedLine(
              line: line,
              priceType: PriceType.wholesale,
              unitPrice: line.item.priceWholesale!,
            )
          else
            PricedLine(line: line, priceType: PriceType.unit, unitPrice: line.item.priceUnit),
      ],
    );
  }
}
