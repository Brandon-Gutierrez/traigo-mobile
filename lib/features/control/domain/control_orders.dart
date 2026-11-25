/// Todos los pedidos, como los ve Jime para quitar duplicados y registrar
/// devoluciones.
library;

import '../../../core/network/json.dart';
import '../../orders/domain/orders.dart';

class ControlOrderSummary {
  const ControlOrderSummary({required this.order, this.sellerName});

  factory ControlOrderSummary.fromJson(Json json) => ControlOrderSummary(
        order: OrderSummary.fromJson(json),
        sellerName: json.strOrNull('seller_name'),
      );

  final OrderSummary order;

  /// `null` en las ventas de la tienda web.
  final String? sellerName;
}

class ControlOrder {
  const ControlOrder({
    required this.detail,
    required this.canReturn,
    required this.canMarkDuplicate,
    this.sellerName,
    this.voidReason,
    this.duplicateOfNumber,
  });

  factory ControlOrder.fromJson(Json json) => ControlOrder(
        detail: OrderDetail.fromJson(json),
        sellerName: json.strOrNull('seller_name'),
        canReturn: json.flag('can_return'),
        canMarkDuplicate: json.flag('can_mark_duplicate'),
        voidReason: json.strOrNull('void_reason'),
        duplicateOfNumber: json.strOrNull('duplicate_of_number'),
      );

  final OrderDetail detail;
  final String? sellerName;

  /// Pagado, listo o entregado: se puede devolver.
  final bool canReturn;

  /// Sin cobro confirmado ni entrega: se puede anular como duplicado.
  final bool canMarkDuplicate;

  /// Por qué se devolvió.
  final String? voidReason;

  /// El pedido original, si este se anuló por duplicado.
  final String? duplicateOfNumber;
}
