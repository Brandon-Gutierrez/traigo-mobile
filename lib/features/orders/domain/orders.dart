/// Ventas registradas desde la app.
library;

import '../../../core/money/money.dart';
import '../../../core/network/json.dart';
import '../../../core/network/paged_result.dart';
import '../../../core/network/upload_file.dart';
import '../../catalog/domain/pricing.dart';
import 'payment_method.dart';

export '../../../core/network/upload_file.dart';
export 'payment_method.dart';

/// Cómo llegó la venta. La app no registra ventas web.
enum OrderOrigin {
  inPerson('in_person', 'Presencial'),
  whatsapp('whatsapp', 'WhatsApp'),
  wholesale('wholesale', 'Mayorista'),
  web('web', 'Web');

  const OrderOrigin(this.apiValue, this.label);
  final String apiValue;
  final String label;

  static OrderOrigin fromApi(String value) => values.firstWhere((o) => o.apiValue == value);
}

enum OrderStatus {
  pendingPayment('pending_payment', 'Por pagar'),
  paymentReview('payment_review', 'Comprobante en revisión'),
  paid('paid', 'Pagado'),
  ready('ready', 'Listo para entregar'),
  delivered('delivered', 'Entregado'),
  cancelled('cancelled', 'Cancelado'),
  expired('expired', 'Vencido'),
  returned('returned', 'Devuelto');

  const OrderStatus(this.apiValue, this.label);
  final String apiValue;
  final String label;

  static OrderStatus fromApi(String value) => values.firstWhere((s) => s.apiValue == value);
}

enum DeliveryType {
  pickup('pickup', 'Recojo'),
  delivery('delivery', 'Delivery');

  const DeliveryType(this.apiValue, this.label);
  final String apiValue;
  final String label;

  static DeliveryType fromApi(String value) => values.firstWhere((t) => t.apiValue == value);
}

enum PaymentStatus {
  pending('pending'),
  submitted('submitted'),
  confirmed('confirmed'),
  rejected('rejected'),
  reversed('reversed');

  const PaymentStatus(this.apiValue);
  final String apiValue;

  static PaymentStatus fromApi(String value) =>
      values.firstWhere((s) => s.apiValue == value);
}

/// Comisión de una venta: pendiente hasta que se cobra.
enum CommissionStatus {
  pending('pending'),
  earned('earned'),
  cancelled('cancelled');

  const CommissionStatus(this.apiValue);
  final String apiValue;

  static CommissionStatus fromApi(String value) =>
      values.firstWhere((s) => s.apiValue == value);
}

/// Pestañas de «Mis pedidos». `paid` incluye los listos para entregar.
enum OrderFilter {
  all(null, 'Todos'),
  toPay('pending_payment', 'Por pagar'),
  inReview('payment_review', 'En revisión'),
  paid('paid', 'Pagados'),
  delivered('delivered', 'Entregados');

  const OrderFilter(this.apiValue, this.label);
  final String? apiValue;
  final String label;
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
      );

  final String id;

  /// Ej: `N-1046`.
  final String number;
  final DateTime createdAt;
  final String customerName;
  final String itemsLabel;
  final Money total;
  final PaymentMethod paymentMethod;
  final OrderStatus status;
}

class OrderLine {
  const OrderLine({
    required this.productId,
    required this.itemCode,
    required this.name,
    required this.quantity,
    required this.priceType,
    required this.unitPrice,
    required this.total,
  });

  factory OrderLine.fromJson(Json json) => OrderLine(
        productId: json.str('product_id'),
        itemCode: json.str('item_code'),
        name: json.str('name'),
        quantity: json.integer('quantity'),
        priceType: PriceType.fromApi(json.str('price_type')),
        unitPrice: json.money('unit_price'),
        total: json.money('line_total'),
      );

  final String productId;
  final String itemCode;
  final String name;
  final int quantity;
  final PriceType priceType;
  final Money unitPrice;
  final Money total;
}

class OrderPayment {
  const OrderPayment({
    required this.method,
    required this.status,
    this.reference,
    this.proofUrl,
    this.submittedAt,
    this.rejectReason,
  });

  factory OrderPayment.fromJson(Json json) => OrderPayment(
        method: PaymentMethod.fromApi(json.str('method')),
        status: PaymentStatus.fromApi(json.str('status')),
        reference: json.strOrNull('reference'),
        proofUrl: json.strOrNull('proof_url'),
        submittedAt: json.dateOrNull('submitted_at'),
        rejectReason: json.strOrNull('reject_reason'),
      );

  final PaymentMethod method;
  final PaymentStatus status;
  final String? reference;
  final String? proofUrl;
  final DateTime? submittedAt;
  final String? rejectReason;
}

class TimelineStep {
  const TimelineStep({required this.status, this.at});

  factory TimelineStep.fromJson(Json json) => TimelineStep(
        status: OrderStatus.fromApi(json.str('status')),
        at: json.dateOrNull('at'),
      );

  final OrderStatus status;

  /// `null` = todavía no pasó.
  final DateTime? at;
}

class OrderCommission {
  const OrderCommission({required this.status, this.amount});

  factory OrderCommission.fromJson(Json json) => OrderCommission(
        status: CommissionStatus.fromApi(json.str('status')),
        amount: json.moneyOrNull('amount'),
      );

  final CommissionStatus status;

  /// `null` mientras el % del producto esté por definir.
  final Money? amount;
}

class OrderDetail {
  const OrderDetail({
    required this.summary,
    required this.origin,
    required this.deliveryType,
    required this.lines,
    required this.timeline,
    required this.canCancel,
    required this.canUploadProof,
    this.customerPhone,
    this.shippingAddress,
    this.payment,
    this.commission,
  });

  factory OrderDetail.fromJson(Json json) {
    final delivery = json.obj('delivery');
    final payment = json.objOrNull('payment');
    final commission = json.objOrNull('commission');
    return OrderDetail(
      summary: OrderSummary.fromJson(json),
      origin: OrderOrigin.fromApi(json.str('origin')),
      customerPhone: json.strOrNull('customer_phone'),
      deliveryType: DeliveryType.fromApi(delivery.str('type')),
      shippingAddress: delivery.strOrNull('address'),
      lines: json.list('lines').map(OrderLine.fromJson).toList(),
      payment: payment == null ? null : OrderPayment.fromJson(payment),
      timeline: json.list('timeline').map(TimelineStep.fromJson).toList(),
      commission: commission == null ? null : OrderCommission.fromJson(commission),
      canCancel: json.flag('can_cancel'),
      canUploadProof: json.flag('can_upload_proof'),
    );
  }

  final OrderSummary summary;
  final OrderOrigin origin;
  final String? customerPhone;
  final DeliveryType deliveryType;
  final String? shippingAddress;
  final List<OrderLine> lines;
  final OrderPayment? payment;
  final List<TimelineStep> timeline;

  /// Solo quienes venden ven su comisión.
  final OrderCommission? commission;
  final bool canCancel;
  final bool canUploadProof;
}

/// Una venta nueva. La app manda productos y cantidades; el servidor calcula
/// los precios y compara con [expectedTotal], que es lo que se le mostró a la
/// persona. Si no coincide, responde `price_changed` y no registra nada.
class NewSale {
  const NewSale({
    required this.clientUuid,
    required this.origin,
    required this.customerName,
    required this.deliveryType,
    required this.paymentMethod,
    required this.lines,
    required this.expectedTotal,
    this.customerPhone,
    this.shippingAddress,
  });

  /// Se genera al abrir el formulario y se reutiliza en los reintentos, así un
  /// corte de internet no registra la venta dos veces.
  final String clientUuid;
  final OrderOrigin origin;
  final String customerName;
  final String? customerPhone;
  final DeliveryType deliveryType;
  final String? shippingAddress;
  final PaymentMethod paymentMethod;
  final List<({String productId, int quantity})> lines;
  final Money expectedTotal;

  Json toJson() => {
        'origin': origin.apiValue,
        'customer': {'name': customerName, 'phone': customerPhone},
        'delivery': {'type': deliveryType.apiValue, 'address': shippingAddress},
        'payment_method': paymentMethod.apiValue,
        'lines': [
          for (final line in lines)
            {'product_id': line.productId, 'quantity': line.quantity},
        ],
        'expected_total': expectedTotal.toApi(),
      };
}

abstract interface class OrdersRepository {
  /// Mis pedidos, del más nuevo al más antiguo.
  Future<PagedResult<OrderSummary>> list({OrderFilter filter = OrderFilter.all, int page = 1});

  Future<OrderDetail> detail(String id);

  /// Lanza [ConflictException] con `insufficient_stock`, `price_changed` o
  /// `product_unavailable`.
  Future<OrderDetail> create(NewSale sale);

  Future<OrderDetail> cancel(String id, {String? reason});

  /// Sube la foto del comprobante; el pedido pasa a «En revisión».
  Future<OrderDetail> uploadProof(
    String id, {
    required UploadFile file,
    required String clientUuid,
    String? reference,
  });
}
