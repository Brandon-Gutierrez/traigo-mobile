import '../../../core/money/money.dart';
import '../../auth/domain/auth.dart';

/// Una línea de la venta con su precio y su mínimo.
class PricedLine {
  const PricedLine({
    required this.unitPrice,
    required this.minPrice,
    required this.quantity,
  });

  final Money unitPrice;
  final Money minPrice;
  final int quantity;

  bool get isBelowMinimum => unitPrice < minPrice;
}

class CommissionPreview {
  const CommissionPreview({
    required this.total,
    required this.gain,
    required this.personal,
    required this.fund,
    required this.hasLineBelowMinimum,
  });

  /// Lo que se cobra al cliente.
  final Money total;

  /// Suma de (precio − mínimo) × cantidad. Cero si hay una línea bajo mínimo.
  final Money gain;
  final Money personal;
  final Money fund;

  /// Si es verdadero la venta no se puede registrar.
  final bool hasLineBelowMinimum;
}

/// Vista previa de la comisión mientras el vendedor ajusta precios.
///
/// Es solo una ayuda visual: al registrar la venta el servidor vuelve a
/// calcular todo y su resultado es el que vale.
abstract final class CommissionCalculator {
  static CommissionPreview preview(Iterable<PricedLine> lines, CommissionRules rules) {
    var total = Money.zero;
    var gain = Money.zero;
    var below = false;

    for (final line in lines) {
      total += line.unitPrice * line.quantity;
      if (line.isBelowMinimum) {
        below = true;
      } else {
        gain += (line.unitPrice - line.minPrice) * line.quantity;
      }
    }

    if (below) gain = Money.zero;

    return CommissionPreview(
      total: total,
      gain: gain,
      personal: gain.percent(rules.personalRate),
      fund: gain.percent(rules.fundRate),
      hasLineBelowMinimum: below,
    );
  }
}
