import 'package:flutter/material.dart' show TimeOfDay, immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../auth/application/session_controller.dart';
import '../../catalog/domain/catalog.dart';
import '../../catalog/domain/pricing.dart';
import '../domain/orders.dart';

/// La venta que se está armando. Se conserva al cambiar de pestaña y se
/// descarta si entra otra persona.
@immutable
class SaleDraft {
  const SaleDraft({
    required this.requestKey,
    this.lines = const [],
    this.customerName = '',
    this.customerPhone = '',
    this.origin,
    this.deliveryType = DeliveryType.pickup,
    this.address = '',
    this.paymentMethod = PaymentMethod.qr,
    this.deliveryDate,
    this.deliveryTime,
  });

  /// Clave contra duplicados: se mantiene mientras no se sepa si el servidor
  /// registró la venta, así reintentar no la duplica.
  final String requestKey;
  final List<CartLine> lines;
  final String customerName;
  final String customerPhone;

  /// Cómo llegó el cliente; se elige siempre (sin valor por defecto).
  final OrderOrigin? origin;
  final DeliveryType deliveryType;
  final String address;
  final PaymentMethod paymentMethod;

  /// La entrega acordada con el cliente (sin valor por defecto).
  final DateTime? deliveryDate;
  final TimeOfDay? deliveryTime;

  DateTime? get promisedAt {
    final date = deliveryDate;
    final time = deliveryTime;
    if (date == null || time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  PricedCart get cart => PricedCart(lines);

  int quantityOf(String productId) {
    for (final line in lines) {
      if (line.item.id == productId) return line.quantity;
    }
    return 0;
  }

  /// Qué falta para poder registrar, o `null` si ya se puede. [now] es la hora
  /// actual, para no acordar una entrega en el pasado.
  String? blockedReason(DateTime now) {
    if (lines.isEmpty) return 'Agrega productos';
    if (customerName.trim().isEmpty) return 'Escribe el nombre del cliente';
    if (customerPhone.replaceAll(RegExp(r'\D'), '').length < 7) {
      return 'Escribe su WhatsApp';
    }
    if (origin == null) return 'Elige cómo llegó';
    if (deliveryType == DeliveryType.delivery && address.trim().isEmpty) {
      return 'Escribe la dirección';
    }
    if (deliveryDate == null) return 'Elige el día de entrega';
    final promised = promisedAt;
    if (promised == null) return 'Elige la hora de entrega';
    if (promised.isBefore(now.subtract(NewSale.pastTolerance))) {
      return 'Esa hora ya pasó';
    }
    return null;
  }

  NewSale toSale() => NewSale(
        clientUuid: requestKey,
        origin: origin!,
        customerName: customerName.trim(),
        customerPhone: customerPhone.trim(),
        deliveryType: deliveryType,
        shippingAddress:
            deliveryType == DeliveryType.delivery ? address.trim() : null,
        paymentMethod: paymentMethod,
        lines: [
          for (final line in lines) (productId: line.item.id, quantity: line.quantity),
        ],
        expectedTotal: cart.total,
        promisedAt: promisedAt!,
      );

  SaleDraft copyWith({
    String? requestKey,
    List<CartLine>? lines,
    String? customerName,
    String? customerPhone,
    OrderOrigin? origin,
    DeliveryType? deliveryType,
    String? address,
    PaymentMethod? paymentMethod,
    DateTime? deliveryDate,
    TimeOfDay? deliveryTime,
  }) =>
      SaleDraft(
        requestKey: requestKey ?? this.requestKey,
        lines: lines ?? this.lines,
        customerName: customerName ?? this.customerName,
        customerPhone: customerPhone ?? this.customerPhone,
        origin: origin ?? this.origin,
        deliveryType: deliveryType ?? this.deliveryType,
        address: address ?? this.address,
        paymentMethod: paymentMethod ?? this.paymentMethod,
        deliveryDate: deliveryDate ?? this.deliveryDate,
        deliveryTime: deliveryTime ?? this.deliveryTime,
      );
}

final saleDraftProvider =
    NotifierProvider<SaleDraftController, SaleDraft>(SaleDraftController.new);

class SaleDraftController extends Notifier<SaleDraft> {
  static const _uuid = Uuid();

  @override
  SaleDraft build() {
    ref.watch(sessionMemberIdProvider);
    return SaleDraft(requestKey: _uuid.v4());
  }

  /// Agrega una unidad de un producto que todavía no está en la venta.
  void add(CatalogItem item) {
    if (item.soldOut || state.quantityOf(item.id) > 0) return;
    state = state.copyWith(lines: [...state.lines, CartLine(item, 1)]);
  }

  /// Cambia la cantidad sin pasar de lo disponible. Cero quita el producto.
  void setQuantity(String productId, int quantity) {
    state = state.copyWith(
      lines: [
        for (final line in state.lines)
          if (line.item.id != productId)
            line
          else if (quantity > 0)
            CartLine(line.item, quantity.clamp(1, line.item.available)),
      ],
    );
  }

  /// Trae precios y stock nuevos del servidor. Si se agotó, se quita.
  void refreshItem(CatalogItem item) {
    state = state.copyWith(
      lines: [
        for (final line in state.lines)
          if (line.item.id != item.id)
            line
          else if (!item.soldOut)
            CartLine(item, line.quantity.clamp(1, item.available)),
      ],
    );
  }

  void edit(SaleDraft Function(SaleDraft draft) change) => state = change(state);

  /// Después de un rechazo definitivo: el siguiente envío es otra petición.
  void renewRequestKey() => state = state.copyWith(requestKey: _uuid.v4());

  void reset() => state = SaleDraft(requestKey: _uuid.v4());
}
