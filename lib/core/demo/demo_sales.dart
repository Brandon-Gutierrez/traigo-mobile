import 'dart:convert';

import '../../features/auth/domain/auth.dart';
import '../../features/catalog/domain/catalog.dart';
import '../../features/catalog/domain/pricing.dart';
import '../../features/home/domain/home.dart';
import '../../features/orders/domain/orders.dart';
import '../../features/warehouse/domain/warehouse.dart';
import '../money/money.dart';
import '../network/api_exception.dart';
import '../network/paged_result.dart';
import 'demo_backend.dart';
import 'demo_catalog.dart';

/// Catálogo y ventas de la demo, con las mismas reglas que el contrato:
/// precio por mayor por producto, reserva de stock, venta registrada una sola
/// vez y comprobantes. Vive en memoria: al reiniciar la app vuelve a empezar.
class DemoSales {
  DemoSales({required this._now}) {
    for (final product in demoCatalog) {
      _stock[_productId(product.code)] = _Stock(product.stock, product.reserved);
    }
    // Reservas de los pedidos de ejemplo que la lista de stock no contaba.
    for (final (code, quantity) in const [('A397462', 1), ('A433734', 4), ('8850', 4)]) {
      _stock[_productId(code)]!.reserved += quantity;
    }
    _orders.addAll(_seedOrders());
  }

  static const catalogPageSize = 30;
  static const ordersPageSize = 20;

  static const _categoryNames = ['Tomatodos', 'Macetas', 'Juguetes'];

  /// La hora actual en el calendario de la demo.
  final DateTime Function() _now;
  final Map<String, _Stock> _stock = {};
  final List<_DemoOrder> _orders = [];
  final Map<String, ({String fingerprint, String orderId})> _requests = {};
  int _nextNumber = 1047;

  static String _productId(String code) => 'p-$code';

  // ──────────────────────────────────────────────────────────── catálogo

  List<CatalogCategory> categories() => [
        for (final name in _categoryNames)
          CatalogCategory(
            id: name.toLowerCase(),
            name: name,
            count: demoCatalog.where((p) => p.category == name).length,
          ),
      ];

  PagedResult<CatalogItem> catalog({String? search, String? categoryId, int page = 1}) {
    final query = _fold(search ?? '').trim();
    final matches = [
      for (final product in demoCatalog)
        if ((categoryId == null || product.category.toLowerCase() == categoryId) &&
            (query.isEmpty || _fold('${product.name} ${product.code}').contains(query)))
          _item(product),
    ]..sort((a, b) => _fold(a.name).compareTo(_fold(b.name)));
    return _page(matches, page, catalogPageSize);
  }

  CatalogItem item(String id) {
    for (final product in demoCatalog) {
      if (_productId(product.code) == id) return _item(product);
    }
    throw const NotFoundException('Ese producto ya no está en el catálogo.');
  }

  CatalogItem _item(DemoProduct product) {
    final id = _productId(product.code);
    final stock = _stock[id]!;
    return CatalogItem(
      id: id,
      itemCode: product.code,
      name: product.name,
      category: product.category,
      priceUnit: Money.fromCents(product.unit * 100),
      priceWholesale: Money.fromCents(product.wholesale * 100),
      wholesaleMinQty: product.minimum,
      stock: stock.stock,
      reserved: stock.reserved,
      available: stock.stock - stock.reserved,
    );
  }

  /// Para buscar sin distinguir mayúsculas ni tildes.
  static String _fold(String text) {
    const accents = 'áàäéèëíìïóòöúùüñ';
    const plain = 'aaaeeeiiiooouuun';
    final lower = text.toLowerCase();
    final buffer = StringBuffer();
    for (final char in lower.split('')) {
      final index = accents.indexOf(char);
      buffer.write(index < 0 ? char : plain[index]);
    }
    return buffer.toString();
  }

  static PagedResult<T> _page<T>(List<T> all, int page, int size) => PagedResult(
        items: all.skip((page - 1) * size).take(size).toList(),
        page: page,
        lastPage: all.isEmpty ? 1 : ((all.length + size - 1) ~/ size),
        total: all.length,
      );

  // ──────────────────────────────────────────────────────────── ventas

  PagedResult<OrderSummary> orders(Member member, {OrderFilter filter = OrderFilter.all, int page = 1}) {
    _requireSeller(member);
    bool matches(OrderStatus status) => switch (filter) {
          OrderFilter.all => true,
          OrderFilter.toPay => status == OrderStatus.pendingPayment,
          OrderFilter.inReview => status == OrderStatus.paymentReview,
          // «Pagados» incluye los que ya están listos para entregar.
          OrderFilter.paid => status == OrderStatus.paid || status == OrderStatus.ready,
          OrderFilter.delivered => status == OrderStatus.delivered,
        };
    final mine = [
      for (final order in _orders)
        if (order.sellerId == member.id && matches(order.status)) order,
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return _page([for (final o in mine) o.summary], page, ordersPageSize);
  }

  OrderDetail order(Member member, String id) => _find(member, id).detail;

  List<TodaySale> todaySales(String memberId, DateTime today) {
    final mine = [
      for (final o in _orders)
        if (o.sellerId == memberId &&
            _sameDay(o.createdAt, today) &&
            o.status != OrderStatus.cancelled)
          o,
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return [
      for (final o in mine)
        TodaySale(
          id: o.id,
          createdAt: o.createdAt,
          itemsLabel: o.summary.itemsLabel,
          customerName: o.customerName,
          total: o.total,
          paymentMethod: o.method,
        ),
    ];
  }

  OrderDetail create(Member member, NewSale sale) {
    _requireSeller(member);
    final fingerprint = jsonEncode(sale.toJson());
    final previous = _requests[sale.clientUuid];
    if (previous != null) {
      if (previous.fingerprint != fingerprint) {
        throw const ConflictException(
          code: 'idempotency_conflict',
          message: 'Esta venta ya se había enviado con otros datos.',
        );
      }
      return _find(member, previous.orderId).detail;
    }

    if (sale.customerName.trim().isEmpty) {
      throw const ValidationException(message: 'Escribe el nombre del cliente.');
    }
    if (sale.deliveryType == DeliveryType.delivery &&
        (sale.shippingAddress ?? '').trim().isEmpty) {
      throw const ValidationException(message: 'Escribe la dirección de entrega.');
    }
    if (sale.origin == OrderOrigin.web || sale.lines.isEmpty) {
      throw const ValidationException(message: 'Revisa los datos de la venta.');
    }
    if (sale.promisedAt.isBefore(_now().subtract(NewSale.pastTolerance))) {
      throw const ValidationException(
        code: 'promised_in_past',
        message: 'La hora de entrega ya pasó.',
      );
    }

    final cart = <CartLine>[];
    for (final line in sale.lines) {
      final product = item(line.productId);
      if (line.quantity < 1) {
        throw const ValidationException(message: 'La cantidad debe ser al menos 1.');
      }
      if (line.quantity > product.available) {
        throw ConflictException(
          code: 'insufficient_stock',
          message: product.available == 0
              ? '${product.name} se agotó.'
              : 'Solo quedan ${product.available} de ${product.name}.',
          data: {'product_id': product.id, 'available': product.available},
        );
      }
      cart.add(CartLine(product, line.quantity));
    }

    final priced = PricedCart(cart);
    if (priced.total != sale.expectedTotal) {
      throw ConflictException(
        code: 'price_changed',
        message: 'Los precios cambiaron. Revisa el total antes de registrar.',
        data: {'total': priced.total.toApi()},
      );
    }

    for (final line in cart) {
      _stock[line.item.id]!.reserved += line.quantity;
    }
    final number = _nextNumber++;
    final createdAt = _now();
    // El efectivo ya se recibió: queda «Pagado» para que almacén lo entregue.
    // Jime lo confirma al validar la caja del día.
    final cash = sale.paymentMethod == PaymentMethod.cash;
    final order = _DemoOrder(
      id: '$number',
      sellerId: member.id,
      createdAt: createdAt,
      origin: sale.origin,
      customerName: sale.customerName.trim(),
      customerPhone: sale.customerPhone,
      deliveryType: sale.deliveryType,
      address: sale.shippingAddress,
      method: sale.paymentMethod,
      promisedAt: sale.promisedAt,
      status: cash ? OrderStatus.paid : OrderStatus.pendingPayment,
      paidAt: cash ? createdAt : null,
      lines: [for (final line in cart) _line(line.item, line.quantity, line.priceType)],
      payment: cash
          ? OrderPayment(
              method: PaymentMethod.cash,
              status: PaymentStatus.submitted,
              submittedAt: createdAt,
            )
          : null,
    );
    _orders.add(order);
    _requests[sale.clientUuid] = (fingerprint: fingerprint, orderId: order.id);
    return order.detail;
  }

  OrderDetail cancel(Member member, String id) {
    final order = _find(member, id);
    if (!order.canCancel) {
      throw const ConflictException(
        code: 'not_cancellable',
        message: 'Este pedido ya no se puede cancelar.',
      );
    }
    for (final line in order.lines) {
      _stock[line.productId]!.reserved -= line.quantity;
    }
    order
      ..status = OrderStatus.cancelled
      ..payment = null;
    return order.detail;
  }

  OrderDetail uploadProof(
    Member member,
    String id, {
    required String filename,
    String? reference,
  }) {
    final order = _find(member, id);
    if (!order.canUploadProof) {
      throw const ConflictException(
        code: 'already_reviewed',
        message: 'Este pedido ya no admite otro comprobante.',
      );
    }
    final cleaned = reference?.trim();
    if (cleaned != null &&
        cleaned.isNotEmpty &&
        _orders.any((o) => o.id != id && o.payment?.reference == cleaned)) {
      throw const ConflictException(
        code: 'reference_duplicated',
        message: 'Ese número de referencia ya se usó en otro pago.',
      );
    }
    order
      ..status = OrderStatus.paymentReview
      ..payment = OrderPayment(
        method: order.method,
        status: PaymentStatus.submitted,
        reference: (cleaned?.isEmpty ?? true) ? null : cleaned,
        proofUrl: 'demo://comprobantes/$filename',
        submittedAt: _now(),
      );
    return order.detail;
  }

  _DemoOrder _find(Member member, String id) {
    _requireSeller(member);
    for (final order in _orders) {
      // Lo de otra persona no existe para quien pregunta.
      if (order.id == id && order.sellerId == member.id) return order;
    }
    throw const NotFoundException('No encontramos ese pedido.');
  }

  // ─────────────────────────────────────────────── para almacén y caja

  /// Pagados por preparar y listos por entregar: primero los de entrega más
  /// cercana y, al final, los que no tienen hora.
  List<Dispatch> dispatchQueue() {
    final now = _now();
    final queue = [
      for (final o in _orders)
        if (o.status == OrderStatus.paid || o.status == OrderStatus.ready) o,
    ]..sort((a, b) {
        final first = a.promisedAt;
        final second = b.promisedAt;
        if (first != null && second != null) return first.compareTo(second);
        if (first != null) return -1;
        if (second != null) return 1;
        return a.paidAt!.compareTo(b.paidAt!);
      });
    return [
      for (final o in queue)
        Dispatch(
          orderId: o.id,
          number: 'N-${o.id}',
          customerName: o.customerName,
          itemsLabel: o.summary.itemsLabel,
          lines: [
            for (final line in o.lines)
              DispatchLine(itemCode: line.itemCode, name: line.name, quantity: line.quantity),
          ],
          deliveryType: o.deliveryType,
          status: o.status,
          isLate: o.promisedAt != null && now.isAfter(o.promisedAt!),
          customerPhone: o.customerPhone,
          shippingAddress: o.address,
          paidAt: o.paidAt,
          promisedAt: o.promisedAt,
        ),
    ];
  }

  void markReady(String id) {
    _inStatus(id, OrderStatus.paid)
      ..status = OrderStatus.ready
      ..readyAt = _now();
  }

  /// Al entregar, lo reservado sale de la bodega.
  void markDelivered(String id) {
    final order = _inStatus(id, OrderStatus.ready);
    for (final line in order.lines) {
      _stock[line.productId]!
        ..stock -= line.quantity
        ..reserved -= line.quantity;
    }
    order
      ..status = OrderStatus.delivered
      ..deliveredAt = _now();
  }

  _DemoOrder _inStatus(String id, OrderStatus expected) {
    final order = _orders.where((o) => o.id == id).firstOrNull;
    if (order == null) throw const NotFoundException('No encontramos ese pedido.');
    if (order.status != expected) {
      throw const ConflictException(
        code: 'invalid_status',
        message: 'El pedido cambió de estado. Revisa la lista.',
      );
    }
    return order;
  }

  /// Los cobros de un día como los suma la caja: comprobantes enviados o
  /// confirmados y el efectivo recibido.
  List<({PaymentMethod method, Money amount})> collectionsOn(DateTime day) => [
        for (final o in _orders)
          if (o.payment case final payment?
              when (payment.status == PaymentStatus.submitted ||
                      payment.status == PaymentStatus.confirmed) &&
                  o.status != OrderStatus.cancelled &&
                  o.status != OrderStatus.returned &&
                  payment.submittedAt != null &&
                  _sameDay(payment.submittedAt!, day))
            (method: payment.method, amount: o.total),
      ];

  /// Pedidos de ese día que todavía no se cobraron.
  List<PendingCollection> pendingOn(DateTime day) => [
        for (final o in _orders)
          if (o.status == OrderStatus.pendingPayment && _sameDay(o.createdAt, day))
            PendingCollection(
              orderId: o.id,
              number: 'N-${o.id}',
              customerName: o.customerName,
              method: o.method,
              total: o.total,
              sellerName: DemoBackend.members.where((m) => m.id == o.sellerId).firstOrNull?.name,
              detail: o.payment?.status == PaymentStatus.rejected
                  ? 'comprobante rechazado'
                  : 'sin comprobante',
            ),
      ];

  StockLevel stockLevel(String productId) {
    final stock = _stock[productId];
    if (stock == null) {
      throw const NotFoundException('Ese producto ya no está en el catálogo.');
    }
    return StockLevel(
      productId: productId,
      stock: stock.stock,
      reserved: stock.reserved,
      available: stock.stock - stock.reserved,
    );
  }

  /// Suma [delta] a la bodega sin dejar menos de lo reservado por pedidos.
  StockLevel moveStock(String productId, int delta) {
    final level = stockLevel(productId);
    if (level.stock + delta < level.reserved) {
      throw ConflictException(
        code: 'below_reserved',
        message: 'No puede quedar menos de las ${level.reserved} unidades '
            'reservadas por pedidos.',
      );
    }
    _stock[productId]!.stock += delta;
    return stockLevel(productId);
  }

  static void _requireSeller(Member member) {
    if (!member.role.canSell) {
      throw const NotFoundException('Solo quienes venden tienen pedidos.');
    }
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static OrderLine _line(CatalogItem product, int quantity, PriceType type) {
    final unit = type == PriceType.wholesale ? product.priceWholesale! : product.priceUnit;
    return OrderLine(
      productId: product.id,
      itemCode: product.itemCode,
      name: product.name,
      category: product.category,
      quantity: quantity,
      priceType: type,
      unitPrice: unit,
      total: unit * quantity,
    );
  }

  // ─────────────────────────────────────────── pedidos de ejemplo (mockups)

  List<_DemoOrder> _seedOrders() {
    OrderLine line(String code, int quantity, [PriceType type = PriceType.unit]) =>
        _line(item(_productId(code)), quantity, type);

    DateTime at(int day, int hour, int minute) => DateTime(2026, 12, day, hour, minute);

    OrderPayment cash(DateTime received) => OrderPayment(
          method: PaymentMethod.cash,
          status: PaymentStatus.submitted,
          submittedAt: received,
        );

    OrderPayment confirmed(PaymentMethod method, String file, DateTime submitted) => OrderPayment(
          method: method,
          status: PaymentStatus.confirmed,
          proofUrl: 'demo://comprobantes/$file',
          submittedAt: submitted,
        );

    return [
      _DemoOrder(
        id: '1046',
        sellerId: '4',
        createdAt: at(6, 11, 9),
        origin: OrderOrigin.whatsapp,
        customerName: 'Mariela Quispe',
        customerPhone: '71234567',
        method: PaymentMethod.qr,
        status: OrderStatus.paymentReview,
        promisedAt: at(6, 18, 0),
        lines: [line('8107', 2)],
        payment: OrderPayment(
          method: PaymentMethod.qr,
          status: PaymentStatus.submitted,
          proofUrl: 'demo://comprobantes/comprobante-qr.jpg',
          submittedAt: at(6, 11, 25),
        ),
      ),
      _DemoOrder(
        id: '1045',
        sellerId: '4',
        createdAt: at(6, 10, 41),
        origin: OrderOrigin.inPerson,
        customerName: 'Valeria Paz',
        customerPhone: '70712233',
        method: PaymentMethod.qr,
        status: OrderStatus.paid,
        promisedAt: at(6, 17, 0),
        lines: [line('8923', 1)],
        paidAt: at(6, 10, 55),
        payment: confirmed(PaymentMethod.qr, 'comprobante-1045.jpg', at(6, 10, 45)),
      ),
      _DemoOrder(
        id: '1044',
        sellerId: '5',
        createdAt: at(6, 11, 30),
        origin: OrderOrigin.whatsapp,
        customerName: 'Ferretería Central',
        customerPhone: '72288110',
        method: PaymentMethod.qr,
        status: OrderStatus.pendingPayment,
        promisedAt: at(8, 10, 0),
        lines: [line('8850', 4)],
      ),
      _DemoOrder(
        id: '1043',
        sellerId: '5',
        createdAt: at(6, 9, 30),
        origin: OrderOrigin.wholesale,
        customerName: 'Comercio El Hogar',
        customerPhone: '71234567',
        deliveryType: DeliveryType.delivery,
        address: 'Av. Blanco Galindo km 4, Cochabamba',
        method: PaymentMethod.transfer,
        status: OrderStatus.ready,
        promisedAt: at(6, 12, 0),
        lines: [line('8109', 24, PriceType.wholesale)],
        paidAt: at(6, 9, 50),
        readyAt: at(6, 10, 30),
        payment: confirmed(PaymentMethod.transfer, 'transferencia-1043.jpg', at(6, 9, 35)),
      ),
      _DemoOrder(
        id: '1042',
        sellerId: '5',
        createdAt: at(6, 10, 50),
        origin: OrderOrigin.wholesale,
        customerName: 'Librería Andina',
        customerPhone: '70455901',
        method: PaymentMethod.cash,
        status: OrderStatus.paid,
        promisedAt: at(7, 10, 0),
        lines: [line('A433734', 4)],
        paidAt: at(6, 10, 50),
        payment: cash(at(6, 10, 50)),
      ),
      // Venta de la tienda web: sin vendedor y sin hora acordada.
      _DemoOrder(
        id: '1041',
        sellerId: null,
        createdAt: at(6, 8, 15),
        origin: OrderOrigin.web,
        customerName: 'Carla Rojas',
        customerPhone: '70123456',
        deliveryType: DeliveryType.delivery,
        address: 'Calle Sucre 245, Cochabamba',
        method: PaymentMethod.qr,
        status: OrderStatus.paid,
        lines: [line('A397462', 1)],
        paidAt: at(6, 8, 40),
        payment: confirmed(PaymentMethod.qr, 'comprobante-1041.jpg', at(6, 8, 16)),
      ),
      _DemoOrder(
        id: '1040',
        sellerId: '4',
        createdAt: at(5, 16, 20),
        origin: OrderOrigin.whatsapp,
        customerName: 'Rosa Mamani',
        customerPhone: '76543210',
        method: PaymentMethod.cash,
        status: OrderStatus.delivered,
        promisedAt: at(5, 18, 0),
        lines: [line('FSYB-1109W', 3)],
        paidAt: at(5, 16, 20),
        readyAt: at(5, 17, 0),
        deliveredAt: at(5, 18, 0),
        payment: cash(at(5, 16, 20)),
      ),
      _DemoOrder(
        id: '1039',
        sellerId: '5',
        createdAt: at(4, 10, 15),
        origin: OrderOrigin.wholesale,
        customerName: 'Tienda Don Luis',
        customerPhone: '79912045',
        method: PaymentMethod.cash,
        status: OrderStatus.delivered,
        promisedAt: at(4, 16, 0),
        lines: [line('8850', 10)],
        paidAt: at(4, 10, 15),
        readyAt: at(4, 14, 0),
        deliveredAt: at(4, 15, 30),
        payment: cash(at(4, 10, 15)),
      ),
      _DemoOrder(
        id: '1038',
        sellerId: '4',
        createdAt: at(1, 15, 5),
        origin: OrderOrigin.inPerson,
        customerName: 'Pedro Alanoca',
        customerPhone: '79988776',
        method: PaymentMethod.qr,
        status: OrderStatus.cancelled,
        promisedAt: at(2, 10, 0),
        lines: [line('A413537', 1)],
      ),
    ];
  }
}

class _Stock {
  _Stock(this.stock, this.reserved);

  int stock;
  int reserved;
}

class _DemoOrder {
  _DemoOrder({
    required this.id,
    required this.sellerId,
    required this.createdAt,
    required this.origin,
    required this.customerName,
    required this.method,
    required this.status,
    required this.lines,
    this.customerPhone,
    this.deliveryType = DeliveryType.pickup,
    this.address,
    this.payment,
    this.promisedAt,
    this.paidAt,
    this.readyAt,
    this.deliveredAt,
  });

  final String id;

  /// `null` en las ventas de la tienda web.
  final String? sellerId;
  final DateTime createdAt;
  final OrderOrigin origin;
  final String customerName;
  final String? customerPhone;
  final DeliveryType deliveryType;
  final String? address;
  final PaymentMethod method;
  OrderStatus status;
  final List<OrderLine> lines;
  OrderPayment? payment;
  final DateTime? promisedAt;
  final DateTime? paidAt;
  DateTime? readyAt;
  DateTime? deliveredAt;

  Money get total => lines.fold(Money.zero, (sum, l) => sum + l.total);

  bool get canCancel =>
      status == OrderStatus.pendingPayment || status == OrderStatus.paymentReview;

  bool get canUploadProof =>
      canCancel && (method == PaymentMethod.qr || method == PaymentMethod.transfer);

  String get _itemsLabel {
    final first = '${lines.first.name} × ${lines.first.quantity}';
    final others = lines.length - 1;
    if (others == 0) return first;
    return '$first y $others ${others == 1 ? 'producto' : 'productos'} más';
  }

  OrderSummary get summary => OrderSummary(
        id: id,
        number: 'N-$id',
        createdAt: createdAt,
        customerName: customerName,
        itemsLabel: _itemsLabel,
        total: total,
        paymentMethod: method,
        status: status,
      );

  OrderDetail get detail => OrderDetail(
        summary: summary,
        origin: origin,
        customerPhone: customerPhone,
        deliveryType: deliveryType,
        shippingAddress: address,
        promisedAt: promisedAt,
        lines: List.unmodifiable(lines),
        payment: payment,
        timeline: [
          TimelineStep(status: OrderStatus.pendingPayment, at: createdAt),
          TimelineStep(status: OrderStatus.paid, at: paidAt),
          TimelineStep(status: OrderStatus.ready, at: readyAt),
          TimelineStep(status: OrderStatus.delivered, at: deliveredAt),
        ],
        // El % de comisión todavía no está definido: el monto va nulo.
        commission: OrderCommission(
          // Se gana cuando Jime confirma el cobro (el efectivo, con la caja).
          status: status == OrderStatus.cancelled
              ? CommissionStatus.cancelled
              : (payment?.status == PaymentStatus.confirmed
                  ? CommissionStatus.earned
                  : CommissionStatus.pending),
        ),
        canCancel: canCancel,
        canUploadProof: canUploadProof,
      );
}
