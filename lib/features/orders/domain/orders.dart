import '../../../core/money/money.dart';
import '../../../core/network/api_client.dart' show UploadFile;
import '../../../core/network/json.dart';
import '../../../core/network/paged_result.dart';
import '../../catalog/domain/catalog.dart';

enum PaymentMethod {
  qr('qr'),
  cash('cash');

  const PaymentMethod(this.apiValue);
  final String apiValue;

  static PaymentMethod fromApi(String v) => values.firstWhere((e) => e.apiValue == v);
}

enum DeliveryType {
  /// Entrega en mano o encuentro con el vendedor.
  handoff('handoff'),

  /// Delivery propio en Cochabamba. Pide dirección.
  delivery('delivery'),

  /// Envío a otra ciudad por flota. Pide ciudad.
  otherCity('other_city'),

  /// El cliente recoge en el punto.
  pickup('pickup');

  const DeliveryType(this.apiValue);
  final String apiValue;

  static DeliveryType fromApi(String v) => values.firstWhere((e) => e.apiValue == v);
}

enum OrderStatus {
  pendingPayment('pending_payment'),
  preparing('preparing'),
  onTheWay('on_the_way'),
  delivered('delivered'),
  returned('returned'),
  cancelled('cancelled');

  const OrderStatus(this.apiValue);
  final String apiValue;

  static OrderStatus fromApi(String v) => values.firstWhere((e) => e.apiValue == v);

  /// El vendedor solo puede cancelar mientras el admin no confirme el pago.
  bool get isCancellable => this == OrderStatus.pendingPayment;
}

enum CommissionState {
  /// Se genera al confirmar el pago y queda en espera hasta la entrega.
  pending('pending'),

  /// Se aprueba cuando el pedido se entrega.
  approved('approved'),

  /// Se revierte si el pedido se devuelve o se cancela.
  reverted('reverted');

  const CommissionState(this.apiValue);
  final String apiValue;

  static CommissionState fromApi(String v) => values.firstWhere((e) => e.apiValue == v);
}

enum ProofStatus {
  /// Pago con QR y todavía no se subió la foto.
  missing('missing'),
  uploaded('uploaded'),
  confirmed('confirmed'),
  rejected('rejected'),

  /// Pago en efectivo: no hay comprobante.
  notRequired('not_required');

  const ProofStatus(this.apiValue);
  final String apiValue;

  static ProofStatus fromApi(String v) => values.firstWhere((e) => e.apiValue == v);
}

class OrderCommission {
  const OrderCommission({required this.amount, required this.state});

  factory OrderCommission.fromJson(Json json) => OrderCommission(
        amount: json.money('amount'),
        state: CommissionState.fromApi(json.str('state')),
      );

  final Money amount;
  final CommissionState state;
}

class OrderSummary {
  const OrderSummary({
    required this.id,
    required this.number,
    required this.createdAt,
    required this.customerName,
    required this.itemsLabel,
    required this.total,
    required this.paymentMethod,
    required this.status,
    required this.commission,
  });

  factory OrderSummary.fromJson(Json json) => OrderSummary(
        id: json.str('id'),
        number: json.str('number'),
        createdAt: json.date('created_at'),
        customerName: json.str('customer_name'),
        itemsLabel: json.str('items_label'),
        total: json.money('total'),
        paymentMethod: PaymentMethod.fromApi(json.str('payment_method')),
        status: OrderStatus.fromApi(json.str('status')),
        commission: OrderCommission.fromJson(json.obj('commission')),
      );

  final String id;

  /// Número visible del pedido, sin el «#». Ej: `131`.
  final String number;
  final DateTime createdAt;
  final String customerName;

  /// Resumen en una línea. Ej: `Lámpara luna LED × 1`.
  final String itemsLabel;
  final Money total;
  final PaymentMethod paymentMethod;
  final OrderStatus status;
  final OrderCommission commission;
}

class OrderLine {
  const OrderLine({
    required this.kind,
    required this.itemId,
    required this.code,
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.minPrice,
  });

  factory OrderLine.fromJson(Json json) => OrderLine(
        kind: CatalogKind.fromApi(json.str('kind')),
        itemId: json.str('item_id'),
        code: json.str('code'),
        name: json.str('name'),
        quantity: json.integer('quantity'),
        unitPrice: json.money('unit_price'),
        minPrice: json.money('min_price'),
      );

  final CatalogKind kind;
  final String itemId;
  final String code;
  final String name;
  final int quantity;
  final Money unitPrice;
  final Money minPrice;

  Money get lineTotal => unitPrice * quantity;
}

/// Cómo se reparte la ganancia de la venta. Lo calcula el servidor.
class CommissionBreakdown {
  const CommissionBreakdown({
    required this.gain,
    required this.personal,
    required this.fund,
  });

  factory CommissionBreakdown.fromJson(Json json) => CommissionBreakdown(
        gain: json.money('gain'),
        personal: json.money('personal'),
        fund: json.money('fund'),
      );

  /// Suma de (precio vendido − mínimo) × cantidad.
  final Money gain;
  final Money personal;
  final Money fund;
}

class PaymentProof {
  const PaymentProof({
    required this.status,
    this.url,
    this.uploadedAt,
    this.rejectionReason,
  });

  factory PaymentProof.fromJson(Json json) => PaymentProof(
        status: ProofStatus.fromApi(json.str('status')),
        url: json.strOrNull('url'),
        uploadedAt: json.dateOrNull('uploaded_at'),
        rejectionReason: json.strOrNull('rejection_reason'),
      );

  final ProofStatus status;
  final String? url;
  final DateTime? uploadedAt;
  final String? rejectionReason;
}

class OrderDelivery {
  const OrderDelivery({required this.type, this.address, this.city});

  factory OrderDelivery.fromJson(Json json) => OrderDelivery(
        type: DeliveryType.fromApi(json.str('type')),
        address: json.strOrNull('address'),
        city: json.strOrNull('city'),
      );

  final DeliveryType type;
  final String? address;
  final String? city;
}

/// Hito de la línea de tiempo del pedido. `at == null` significa pendiente.
class OrderTimelineEvent {
  const OrderTimelineEvent({required this.key, this.at});

  factory OrderTimelineEvent.fromJson(Json json) => OrderTimelineEvent(
        key: json.str('key'),
        at: json.dateOrNull('at'),
      );

  /// `registered`, `payment_confirmed` o `delivered`.
  final String key;
  final DateTime? at;

  bool get isDone => at != null;
}

class OrderDetail extends OrderSummary {
  const OrderDetail({
    required super.id,
    required super.number,
    required super.createdAt,
    required super.customerName,
    required super.itemsLabel,
    required super.total,
    required super.paymentMethod,
    required super.status,
    required super.commission,
    required this.customerWhatsapp,
    required this.delivery,
    required this.lines,
    required this.breakdown,
    required this.paymentProof,
    required this.timeline,
  });

  factory OrderDetail.fromJson(Json json) {
    final summary = OrderSummary.fromJson(json);
    return OrderDetail(
      id: summary.id,
      number: summary.number,
      createdAt: summary.createdAt,
      customerName: summary.customerName,
      itemsLabel: summary.itemsLabel,
      total: summary.total,
      paymentMethod: summary.paymentMethod,
      status: summary.status,
      commission: summary.commission,
      customerWhatsapp: json.strOrNull('customer_whatsapp'),
      delivery: OrderDelivery.fromJson(json.obj('delivery')),
      lines: json.list('lines').map(OrderLine.fromJson).toList(),
      breakdown: CommissionBreakdown.fromJson(json.obj('breakdown')),
      paymentProof: PaymentProof.fromJson(json.obj('payment_proof')),
      timeline: json.list('timeline').map(OrderTimelineEvent.fromJson).toList(),
    );
  }

  final String? customerWhatsapp;
  final OrderDelivery delivery;
  final List<OrderLine> lines;
  final CommissionBreakdown breakdown;
  final PaymentProof paymentProof;
  final List<OrderTimelineEvent> timeline;
}

// ---------------------------------------------------------------------------
// Registrar una venta
// ---------------------------------------------------------------------------

class SaleLineInput {
  const SaleLineInput({
    required this.kind,
    required this.itemId,
    required this.quantity,
    required this.unitPrice,
  });

  final CatalogKind kind;
  final String itemId;
  final int quantity;

  /// Precio al que vendió el vendedor. Debe ser ≥ al mínimo del ítem.
  final Money unitPrice;

  Json toJson() => {
        'kind': kind.apiValue,
        'item_id': itemId,
        'quantity': quantity,
        'unit_price': unitPrice.toApi(),
      };
}

class CustomerInput {
  const CustomerInput({required this.name, required this.whatsapp});

  final String name;
  final String whatsapp;

  Json toJson() => {'name': name, 'whatsapp': whatsapp};
}

class DeliveryInput {
  const DeliveryInput({required this.type, this.address, this.city});

  final DeliveryType type;

  /// Obligatoria si [type] es `delivery`.
  final String? address;

  /// Obligatoria si [type] es `otherCity`.
  final String? city;

  Json toJson() => {'type': type.apiValue, 'address': address, 'city': city};
}

class CreateOrderInput {
  const CreateOrderInput({
    required this.clientRequestId,
    required this.lines,
    required this.customer,
    required this.paymentMethod,
    required this.delivery,
  });

  /// UUID generado en el celular al abrir la pantalla de venta. Viaja como
  /// `Idempotency-Key`: si la red falla y el vendedor reintenta, el servidor
  /// devuelve el mismo pedido en lugar de duplicarlo.
  final String clientRequestId;
  final List<SaleLineInput> lines;
  final CustomerInput customer;
  final PaymentMethod paymentMethod;
  final DeliveryInput delivery;

  Json toJson() => {
        'lines': lines.map((l) => l.toJson()).toList(),
        'customer': customer.toJson(),
        'payment_method': paymentMethod.apiValue,
        'delivery': delivery.toJson(),
      };
}

abstract interface class OrdersRepository {
  /// Mis pedidos, del más nuevo al más antiguo. [status] filtra una pestaña.
  Future<PagedResult<OrderSummary>> list({OrderStatus? status, int page = 1});

  Future<OrderDetail> get(String id);

  /// Registra la venta. Puede lanzar:
  /// - [ValidationException] con `code == 'price_below_minimum'`
  /// - [ConflictException] con `code == 'insufficient_stock'`
  Future<OrderDetail> create(CreateOrderInput input);

  /// Solo mientras el pedido esté «por confirmar». Si no, [ConflictException]
  /// con `code == 'not_cancellable'`.
  Future<OrderDetail> cancel(String id);

  /// Sube la foto del comprobante del QR.
  Future<OrderDetail> uploadPaymentProof(
    String id,
    UploadFile file, {
    void Function(int sent, int total)? onProgress,
  });
}
