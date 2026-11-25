/// Almacén: cierre de caja diario de todo el equipo y conteo de inventario.
library;

import '../../../core/money/money.dart';
import '../../../core/network/json.dart';
import '../../orders/domain/orders.dart';
import 'cash_status.dart';

export '../../orders/domain/payment_method.dart';
export 'cash_status.dart';

class CashLine {
  const CashLine({
    required this.method,
    required this.ordersCount,
    required this.expected,
    this.counted,
    this.note,
  });

  factory CashLine.fromJson(Json json) => CashLine(
        method: PaymentMethod.fromApi(json.str('method')),
        ordersCount: json.integer('orders_count'),
        expected: json.money('expected'),
        counted: json.moneyOrNull('counted'),
        note: json.strOrNull('note'),
      );

  final PaymentMethod method;
  final int ordersCount;

  /// Según los pedidos cobrados.
  final Money expected;

  /// Lo que se contó; `null` antes de cerrar.
  final Money? counted;
  final String? note;

  Money? get difference => counted == null ? null : counted! - expected;
}

class PendingCollection {
  const PendingCollection({
    required this.orderId,
    required this.number,
    required this.customerName,
    required this.method,
    required this.total,
    this.sellerName,
    this.detail,
  });

  factory PendingCollection.fromJson(Json json) => PendingCollection(
        orderId: json.str('order_id'),
        number: json.str('number'),
        customerName: json.str('customer_name'),
        method: PaymentMethod.fromApi(json.str('payment_method')),
        total: json.money('total'),
        sellerName: json.strOrNull('seller_name'),
        detail: json.strOrNull('detail'),
      );

  final String orderId;
  final String number;
  final String customerName;
  final PaymentMethod method;
  final Money total;
  final String? sellerName;

  /// Ej: «sin comprobante».
  final String? detail;
}

/// La caja de un día, antes y después de cerrarla.
class CashDay {
  const CashDay({
    required this.businessDate,
    required this.status,
    required this.collected,
    required this.paidOrders,
    required this.pendingOrders,
    required this.lines,
    required this.pending,
    this.closingId,
    this.closedByName,
    this.sentAt,
    this.note,
    this.reviewNote,
  });

  factory CashDay.fromJson(Json json) => CashDay(
        closingId: json.strOrNull('closing_id'),
        businessDate: json.date('business_date'),
        status: CashStatus.fromApi(json.str('status')),
        collected: json.money('collected'),
        paidOrders: json.integer('paid_orders'),
        pendingOrders: json.integer('pending_orders'),
        lines: json.list('lines').map(CashLine.fromJson).toList(),
        pending: json.list('pending').map(PendingCollection.fromJson).toList(),
        closedByName: json.strOrNull('closed_by_name'),
        sentAt: json.dateOrNull('sent_at'),
        note: json.strOrNull('note'),
        reviewNote: json.strOrNull('review_note'),
      );

  final String? closingId;
  final DateTime businessDate;
  final CashStatus status;
  final Money collected;
  final int paidOrders;
  final int pendingOrders;
  final List<CashLine> lines;
  final List<PendingCollection> pending;
  final String? closedByName;
  final DateTime? sentAt;

  /// Explicación de la diferencia.
  final String? note;

  /// Lo que pidió corregir Jime.
  final String? reviewNote;

  /// Se puede enviar si todavía no se envió o si Jime pidió corregir.
  bool get canSend => status == CashStatus.open || status == CashStatus.observed;
}

class NewCashClosing {
  const NewCashClosing({
    required this.clientUuid,
    required this.businessDate,
    required this.counted,
    this.note,
  });

  final String clientUuid;
  final DateTime businessDate;

  /// Lo contado por forma de pago.
  final Map<PaymentMethod, Money> counted;

  /// Obligatoria si alguna forma de pago no cuadra.
  final String? note;
}

class CountedProduct {
  const CountedProduct({
    required this.productId,
    required this.itemCode,
    required this.systemQty,
    required this.countedQty,
  });

  factory CountedProduct.fromJson(Json json) => CountedProduct(
        productId: json.str('product_id'),
        itemCode: json.str('item_code'),
        systemQty: json.integer('system_qty'),
        countedQty: json.integer('counted_qty'),
      );

  final String productId;
  final String itemCode;
  final int systemQty;
  final int countedQty;

  int get difference => countedQty - systemQty;
}

class InventoryCount {
  const InventoryCount({required this.id, required this.countedOn, required this.items});

  factory InventoryCount.fromJson(Json json) => InventoryCount(
        id: json.str('id'),
        countedOn: json.date('counted_on'),
        items: json.list('items').map(CountedProduct.fromJson).toList(),
      );

  final String id;
  final DateTime countedOn;
  final List<CountedProduct> items;
}

/// Un pedido pagado que hay que preparar y entregar.
class Dispatch {
  const Dispatch({
    required this.orderId,
    required this.number,
    required this.customerName,
    required this.itemsLabel,
    required this.deliveryType,
    required this.status,
    required this.isLate,
    this.customerPhone,
    this.shippingAddress,
    this.paidAt,
    this.promisedAt,
  });

  factory Dispatch.fromJson(Json json) => Dispatch(
        orderId: json.str('order_id'),
        number: json.str('number'),
        customerName: json.str('customer_name'),
        itemsLabel: json.str('items_label'),
        deliveryType: DeliveryType.fromApi(json.str('delivery_type')),
        status: OrderStatus.fromApi(json.str('status')),
        isLate: json.flag('is_late'),
        customerPhone: json.strOrNull('customer_phone'),
        shippingAddress: json.strOrNull('shipping_address'),
        paidAt: json.dateOrNull('paid_at'),
        promisedAt: json.dateOrNull('promised_at'),
      );

  final String orderId;
  final String number;
  final String customerName;
  final String itemsLabel;
  final DeliveryType deliveryType;

  /// `paid` (por preparar) o `ready` (por entregar).
  final OrderStatus status;

  /// Pasó la hora acordada (KPI «Despachos dentro de plazo»).
  final bool isLate;
  final String? customerPhone;
  final String? shippingAddress;
  final DateTime? paidAt;
  final DateTime? promisedAt;
}

/// Entradas y ajustes que registra almacén. Las ventas y devoluciones las
/// genera el servidor solas.
enum StockEntryType {
  initial('initial', 'Inventario inicial'),
  purchase('purchase', 'Ingreso de mercadería'),
  adjustmentIn('adjustment_in', 'Ajuste (sobra)'),
  adjustmentOut('adjustment_out', 'Ajuste (falta)');

  const StockEntryType(this.apiValue, this.label);
  final String apiValue;
  final String label;

  /// El kardex guarda las salidas con signo negativo.
  int signed(int quantity) => this == adjustmentOut ? -quantity : quantity;
}

class StockLevel {
  const StockLevel({
    required this.productId,
    required this.stock,
    required this.reserved,
    required this.available,
  });

  factory StockLevel.fromJson(Json json) => StockLevel(
        productId: json.str('product_id'),
        stock: json.integer('stock'),
        reserved: json.integer('reserved'),
        available: json.integer('available'),
      );

  final String productId;
  final int stock;
  final int reserved;
  final int available;
}

abstract interface class WarehouseRepository {
  /// Pagados por preparar y listos por entregar, el más urgente primero.
  Future<List<Dispatch>> dispatchQueue();

  Future<void> markReady(String orderId);

  /// Entregado: sale del stock.
  Future<void> markDelivered(String orderId);

  /// [quantity] siempre positiva; el signo lo decide [type].
  Future<StockLevel> registerStock({
    required String clientUuid,
    required String productId,
    required StockEntryType type,
    required int quantity,
    String? note,
  });

  Future<CashDay> cashToday();

  /// Lanza [ValidationException] con `difference_needs_note`.
  Future<CashDay> sendClosing(NewCashClosing closing);

  Future<List<InventoryCount>> counts();

  /// [counted]: id de producto → unidades contadas.
  Future<InventoryCount> submitCount({
    required String clientUuid,
    required DateTime countedOn,
    required Map<String, int> counted,
    String? note,
  });
}
