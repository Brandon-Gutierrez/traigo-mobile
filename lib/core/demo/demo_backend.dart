import 'dart:math' as math;

import '../../features/auth/domain/auth.dart';
import '../../features/catalog/domain/catalog.dart';
import '../../features/home/domain/home.dart';
import '../../features/orders/domain/commission_calculator.dart';
import '../../features/orders/domain/orders.dart';
import '../../features/stock/domain/stock.dart';
import '../../features/waste/domain/waste.dart';
import '../money/money.dart';
import '../network/api_exception.dart';
import '../network/paged_result.dart';

/// «Servidor» de prueba en memoria. Aplica las mismas reglas que debe aplicar
/// el backend real (ver docs/api-contract.md), así la app se puede desarrollar
/// y demostrar completa sin Laravel:
///
/// - Ingreso con `ANA-07` y PIN `1234`.
/// - Vender por debajo del mínimo se rechaza (422 `price_below_minimum`).
/// - Vender más de lo que hay se rechaza (409 `insufficient_stock`).
/// - Registrar dos veces la misma venta devuelve el mismo pedido (idempotencia).
/// - Cancelar solo se puede mientras el pago no esté confirmado.
/// - La merma queda pendiente y no toca el stock hasta que el admin la apruebe.
class DemoBackend {
  DemoBackend({DateTime Function()? clock}) : _clock = clock ?? DateTime.now {
    _seed();
  }

  static const sellerCode = 'ANA-07';
  static const sellerPin = '1234';

  static const _ordersPageSize = 20;
  static const _catalogPageSize = 30;

  final DateTime Function() _clock;

  final Seller seller = const Seller(id: '1', code: sellerCode, name: 'Ana López');
  final CommissionRules rules = const CommissionRules(personalRate: 0.40, fundRate: 0.25);

  final List<_Product> _products = [];
  final List<_Combo> _combos = [];
  final List<_Order> _orders = [];
  final List<StockMovement> _movements = [];
  final List<WasteReport> _waste = [];

  final Map<String, String> _orderByRequest = {};
  final Map<String, String> _wasteByRequest = {};

  int _nextOrder = 132;
  int _nextMovement = 1;
  int _nextWaste = 19;

  // ---------------------------------------------------------------- Sesión

  Session login(String code, String pin) {
    if (code.trim().toUpperCase() != sellerCode || pin != sellerPin) {
      throw const UnauthorizedException('Código o PIN incorrectos.');
    }
    return Session(seller: seller, rules: rules);
  }

  Session get session => Session(seller: seller, rules: rules);

  // -------------------------------------------------------------- Catálogo

  PagedResult<CatalogItem> listCatalog({
    String? search,
    String? category,
    CatalogKind? kind,
    int page = 1,
  }) {
    final query = search?.trim().toLowerCase() ?? '';
    final all = [
      ..._products.map(_itemOfProduct),
      ..._combos.map(_itemOfCombo),
    ].where((item) {
      if (kind != null && item.kind != kind) return false;
      if (category != null && item.category != category) return false;
      if (query.isEmpty) return true;
      return item.name.toLowerCase().contains(query) ||
          item.code.toLowerCase().contains(query);
    }).toList();
    return _paginate(all, page, _catalogPageSize);
  }

  List<String> categories() => const ['Audio', 'Hogar', 'Cocina', 'Bienestar', 'Combos'];

  CatalogItem catalogItem(CatalogKind kind, String id) => switch (kind) {
        CatalogKind.product => _itemOfProduct(_product(id)),
        CatalogKind.combo => _itemOfCombo(_combo(id)),
      };

  // --------------------------------------------------------------- Pedidos

  PagedResult<OrderSummary> listOrders({OrderStatus? status, int page = 1}) {
    final all = _orders.where((o) => status == null || o.status == status).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return _paginate(all.map(_summaryOf).toList(), page, _ordersPageSize);
  }

  OrderDetail order(String id) => _detailOf(_order(id));

  OrderDetail createOrder(CreateOrderInput input) {
    final existing = _orderByRequest[input.clientRequestId];
    if (existing != null) return order(existing);

    _validateSaleFields(input);

    final needed = <String, int>{};
    final priced = <PricedLine>[];
    final lines = <OrderLine>[];

    for (final line in input.lines) {
      final item = catalogItem(line.kind, line.itemId);
      if (line.quantity < 1) {
        throw ValidationException(
          message: 'La cantidad de ${item.name} debe ser al menos 1.',
          fieldErrors: {'lines': ['Cantidad inválida para ${item.name}.']},
        );
      }
      if (line.unitPrice < item.minPrice) {
        throw ValidationException(
          code: 'price_below_minimum',
          message: 'No puedes vender ${item.name} por debajo de ${item.minPrice.format()}.',
          data: {
            'kind': item.kind.apiValue,
            'item_id': item.id,
            'min_price': item.minPrice.toApi(),
          },
        );
      }
      for (final need in _productNeeds(item, line.quantity)) {
        needed[need.$1] = (needed[need.$1] ?? 0) + need.$2;
      }
      priced.add(PricedLine(
        unitPrice: line.unitPrice,
        minPrice: item.minPrice,
        quantity: line.quantity,
      ));
      lines.add(OrderLine(
        kind: item.kind,
        itemId: item.id,
        code: item.code,
        name: item.name,
        quantity: line.quantity,
        unitPrice: line.unitPrice,
        minPrice: item.minPrice,
      ));
    }

    for (final entry in needed.entries) {
      final product = _product(entry.key);
      if (product.stock < entry.value) {
        throw ConflictException(
          code: 'insufficient_stock',
          message: 'Solo quedan ${product.stock} de ${product.name}.',
          data: {'kind': 'product', 'item_id': product.id, 'available': product.stock},
        );
      }
    }

    // Todo válido: descontar stock y registrar el pedido.
    for (final entry in needed.entries) {
      _product(entry.key).stock -= entry.value;
    }
    final preview = CommissionCalculator.preview(priced, rules);
    final number = _nextOrder++;
    final now = _clock();

    final created = _Order(
      number: number,
      createdAt: now,
      customerName: input.customer.name.trim(),
      customerWhatsapp: input.customer.whatsapp.trim(),
      delivery: OrderDelivery(
        type: input.delivery.type,
        address: input.delivery.address?.trim(),
        city: input.delivery.city?.trim(),
      ),
      lines: lines,
      breakdown: CommissionBreakdown(
        gain: preview.gain,
        personal: preview.personal,
        fund: preview.fund,
      ),
      total: preview.total,
      payment: input.paymentMethod,
      status: OrderStatus.pendingPayment,
      commissionState: CommissionState.pending,
      proof: input.paymentMethod == PaymentMethod.qr
          ? ProofStatus.missing
          : ProofStatus.notRequired,
      registeredAt: now,
      isSeed: false,
    );
    _orders.add(created);
    _orderByRequest[input.clientRequestId] = created.id;

    for (final line in lines) {
      _addMovement(
        at: now,
        delta: -line.quantity,
        itemName: line.name,
        description: 'Venta #$number de ${seller.firstName}',
        type: StockMovementType.sale,
      );
    }
    return _detailOf(created);
  }

  OrderDetail cancelOrder(String id) {
    final target = _order(id);
    if (!target.status.isCancellable) {
      throw const ConflictException(
        code: 'not_cancellable',
        message: 'Este pedido ya no se puede cancelar porque el pago fue confirmado. '
            'Escribe al administrador.',
      );
    }
    for (final line in target.lines) {
      final item = catalogItem(line.kind, line.itemId);
      for (final need in _productNeeds(item, line.quantity)) {
        _product(need.$1).stock += need.$2;
      }
      _addMovement(
        at: _clock(),
        delta: line.quantity,
        itemName: line.name,
        description: 'Pedido #${target.number} cancelado',
        type: StockMovementType.cancelled,
      );
    }
    target
      ..status = OrderStatus.cancelled
      ..commissionState = CommissionState.reverted;
    return _detailOf(target);
  }

  OrderDetail uploadPaymentProof(String id) {
    final target = _order(id);
    if (target.payment != PaymentMethod.qr) {
      throw const ValidationException(
        message: 'Este pedido se paga en efectivo y no lleva comprobante.',
      );
    }
    target
      ..proof = ProofStatus.uploaded
      ..proofUploadedAt = _clock();
    return _detailOf(target);
  }

  // ----------------------------------------------------------------- Inicio

  HomeSummary home() {
    final fresh = _orders.where((o) => !o.isSeed && o.status != OrderStatus.cancelled);
    var personal = Money.zero;
    var fund = Money.zero;
    var sold = Money.zero;
    for (final o in fresh) {
      personal += o.breakdown.personal;
      fund += o.breakdown.fund;
      sold += o.total;
    }
    final monthPersonal = Money.parse('1340.00') + personal;
    const fundShare = Money.fromCents(64333);

    final recent = _orders.where((o) => o.status != OrderStatus.cancelled).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return HomeSummary(
      today: TodaySummary(
        commission: Money.parse('86.40') + personal,
        salesCount: 5 + fresh.length,
        soldTotal: Money.parse('1080.00') + sold,
      ),
      month: MonthSummary(
        personalCommission: monthPersonal,
        fundShare: fundShare,
        estimatedTotal: monthPersonal + fundShare,
      ),
      fund: FundProgress(
        current: Money.parse('3860.00') + fund,
        goal: Money.parse('5000.00'),
      ),
      recentOrders: recent.take(2).map(_summaryOf).toList(),
    );
  }

  // ------------------------------------------------------------------ Stock

  StockSummary stockSummary() {
    final attention = _products
        .map(_itemOfProduct)
        .where((p) => p.stockLevel != StockLevel.ok)
        .toList()
      ..sort((a, b) => a.stock.compareTo(b.stock));
    return StockSummary(
      productsTotal: _products.length,
      lowCount: attention.where((p) => p.stockLevel == StockLevel.low).length,
      outCount: attention.where((p) => p.stockLevel == StockLevel.out).length,
      attention: attention,
    );
  }

  PagedResult<StockMovement> movements({DateTime? day, int page = 1}) {
    final target = day ?? _clock();
    final all = _movements
        .where((m) =>
            m.occurredAt.year == target.year &&
            m.occurredAt.month == target.month &&
            m.occurredAt.day == target.day)
        .toList()
      ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    return _paginate(all, page, _ordersPageSize);
  }

  // ------------------------------------------------------------------ Merma

  WasteReport createWaste(CreateWasteInput input) {
    final existing = _wasteByRequest[input.clientRequestId];
    if (existing != null) return _waste.firstWhere((w) => w.id == existing);

    final product = _product(input.itemId);
    if (input.quantity < 1 || input.quantity > product.stock) {
      throw ValidationException(
        message: 'La cantidad debe estar entre 1 y ${product.stock}.',
        fieldErrors: {'quantity': ['Hay ${product.stock} en bodega.']},
      );
    }
    final now = _clock();
    final report = WasteReport(
      id: '${_nextWaste++}',
      itemId: product.id,
      itemName: product.name,
      quantity: input.quantity,
      reason: input.reason,
      status: WasteStatus.pending,
      note: input.note?.trim().isEmpty ?? true ? null : input.note!.trim(),
      createdAt: now,
    );
    _waste.add(report);
    _wasteByRequest[input.clientRequestId] = report.id;
    _addMovement(
      at: now,
      delta: -input.quantity,
      itemName: product.name,
      description: 'Merma · esperando aprobación',
      type: StockMovementType.waste,
      pending: true,
    );
    return report;
  }

  PagedResult<WasteReport> listWaste({WasteStatus? status, int page = 1}) {
    final all = _waste.where((w) => status == null || w.status == status).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return _paginate(all, page, _ordersPageSize);
  }

  // ---------------------------------------------------------------- Helpers

  void _validateSaleFields(CreateOrderInput input) {
    final errors = <String, List<String>>{};
    if (input.lines.isEmpty) errors['lines'] = ['Agrega al menos un producto.'];
    if (input.customer.name.trim().isEmpty) {
      errors['customer.name'] = ['Escribe el nombre del cliente.'];
    }
    if (input.customer.whatsapp.trim().isEmpty) {
      errors['customer.whatsapp'] = ['Escribe el WhatsApp del cliente.'];
    }
    final delivery = input.delivery;
    if (delivery.type == DeliveryType.delivery && (delivery.address ?? '').trim().isEmpty) {
      errors['delivery.address'] = ['Escribe la dirección de entrega.'];
    }
    if (delivery.type == DeliveryType.otherCity && (delivery.city ?? '').trim().isEmpty) {
      errors['delivery.city'] = ['Escribe la ciudad de destino.'];
    }
    if (errors.isNotEmpty) {
      throw ValidationException(
        message: 'Revisa los datos de la venta.',
        fieldErrors: errors,
      );
    }
  }

  /// Productos y unidades que consume vender [quantity] de [item].
  List<(String, int)> _productNeeds(CatalogItem item, int quantity) {
    if (item.kind == CatalogKind.product) return [(item.id, quantity)];
    final combo = _combo(item.id);
    return [for (final c in combo.components) (c.productId, c.quantity * quantity)];
  }

  void _addMovement({
    required DateTime at,
    required int delta,
    required String itemName,
    required String description,
    required StockMovementType type,
    bool pending = false,
  }) {
    _movements.add(StockMovement(
      id: 'm${_nextMovement++}',
      occurredAt: at,
      quantityDelta: delta,
      itemName: itemName,
      description: description,
      type: type,
      pending: pending,
    ));
  }

  PagedResult<T> _paginate<T>(List<T> all, int page, int size) {
    final lastPage = math.max(1, (all.length / size).ceil());
    final start = (page - 1) * size;
    final items = start >= all.length
        ? <T>[]
        : all.sublist(start, math.min(start + size, all.length));
    return PagedResult(items: items, page: page, lastPage: lastPage, total: all.length);
  }

  _Product _product(String id) => _products.firstWhere(
        (p) => p.id == id,
        orElse: () => throw const NotFoundException('No encontramos ese producto.'),
      );

  _Combo _combo(String id) => _combos.firstWhere(
        (c) => c.id == id,
        orElse: () => throw const NotFoundException('No encontramos ese combo.'),
      );

  _Order _order(String id) => _orders.firstWhere(
        (o) => o.id == id,
        orElse: () => throw const NotFoundException('No encontramos ese pedido.'),
      );

  CatalogItem _itemOfProduct(_Product p) => CatalogItem(
        id: p.id,
        kind: CatalogKind.product,
        code: p.code,
        name: p.name,
        category: p.category,
        suggestedPrice: p.suggested,
        minPrice: p.min,
        stock: p.stock,
        lowStockAlert: p.alert,
      );

  CatalogItem _itemOfCombo(_Combo c) {
    final stock = c.components
        .map((x) => _product(x.productId).stock ~/ x.quantity)
        .reduce(math.min);
    return CatalogItem(
      id: c.id,
      kind: CatalogKind.combo,
      code: c.code,
      name: c.name,
      category: 'Combos',
      suggestedPrice: c.price,
      minPrice: c.min,
      stock: stock,
      lowStockAlert: 5,
      components: [
        for (final x in c.components)
          ComboComponent(name: _product(x.productId).name, quantity: x.quantity),
      ],
    );
  }

  OrderSummary _summaryOf(_Order o) => OrderSummary(
        id: o.id,
        number: '${o.number}',
        createdAt: o.createdAt,
        customerName: o.customerName,
        itemsLabel: o.itemsLabel,
        total: o.total,
        paymentMethod: o.payment,
        status: o.status,
        commission: OrderCommission(amount: o.breakdown.personal, state: o.commissionState),
      );

  OrderDetail _detailOf(_Order o) => OrderDetail(
        id: o.id,
        number: '${o.number}',
        createdAt: o.createdAt,
        customerName: o.customerName,
        itemsLabel: o.itemsLabel,
        total: o.total,
        paymentMethod: o.payment,
        status: o.status,
        commission: OrderCommission(amount: o.breakdown.personal, state: o.commissionState),
        customerWhatsapp: o.customerWhatsapp,
        delivery: o.delivery,
        lines: List.unmodifiable(o.lines),
        breakdown: o.breakdown,
        paymentProof: PaymentProof(status: o.proof, uploadedAt: o.proofUploadedAt),
        timeline: [
          OrderTimelineEvent(key: 'registered', at: o.registeredAt),
          OrderTimelineEvent(key: 'payment_confirmed', at: o.paymentConfirmedAt),
          OrderTimelineEvent(key: 'delivered', at: o.deliveredAt),
        ],
      );

  // ------------------------------------------------------------------ Datos

  void _seed() {
    final now = _clock();
    DateTime ago(Duration d) => now.subtract(d);

    _products.addAll([
      _Product('1', 'TR-0151', 'Audífonos bluetooth ANC con estuche', 'Audio', 120, 90, 34, 10),
      _Product('2', 'TR-0142', 'Lámpara luna LED recargable', 'Hogar', 89, 65, 12, 10),
      _Product('3', 'TR-0133', 'Termo digital 500 ml', 'Cocina', 75, 48, 3, 10),
      _Product('4', 'TR-0160', 'Mini licuadora portátil USB', 'Cocina', 98, 76, 20, 10),
      _Product('5', 'TR-0120', 'Organizador plegable multiuso', 'Hogar', 45, 36, 58, 15),
      _Product('6', 'TR-0175', 'Proyector de galaxia', 'Hogar', 110, 80, 0, 8),
      _Product('7', 'TR-0166', 'Masajeador de cuello', 'Bienestar', 160, 125, 9, 10),
      _Product('8', 'TR-0128', 'Cortador de verduras 5 en 1', 'Cocina', 65, 48, 25, 10),
    ]);

    _combos.addAll([
      _Combo('1', 'CMB-01', 'Combo Escritorio Pro', 199, 191,
          const [_Part('2', 1), _Part('1', 1), _Part('5', 1)]),
      _Combo('2', 'CMB-02', 'Combo Cocina Rápida', 189, 172,
          const [_Part('4', 1), _Part('3', 1), _Part('8', 1)]),
      _Combo('3', 'CMB-03', 'Combo Regalo Tech', 229, 215,
          const [_Part('1', 1), _Part('7', 1)]),
    ]);

    _Order seeded({
      required int number,
      required DateTime at,
      required String customer,
      required String whatsapp,
      required DeliveryType delivery,
      required String? address,
      required CatalogKind kind,
      required String itemId,
      required int price,
      required PaymentMethod payment,
      required OrderStatus status,
      required CommissionState commission,
      required ProofStatus proof,
    }) {
      final item = catalogItem(kind, itemId);
      final unit = Money.fromCents(price * 100);
      final preview = CommissionCalculator.preview(
        [PricedLine(unitPrice: unit, minPrice: item.minPrice, quantity: 1)],
        rules,
      );
      final confirmed = status != OrderStatus.pendingPayment && status != OrderStatus.cancelled;
      return _Order(
        number: number,
        createdAt: at,
        customerName: customer,
        customerWhatsapp: whatsapp,
        delivery: OrderDelivery(type: delivery, address: address),
        lines: [
          OrderLine(
            kind: kind,
            itemId: item.id,
            code: item.code,
            name: item.name,
            quantity: 1,
            unitPrice: unit,
            minPrice: item.minPrice,
          ),
        ],
        breakdown: CommissionBreakdown(
          gain: preview.gain,
          personal: preview.personal,
          fund: preview.fund,
        ),
        total: preview.total,
        payment: payment,
        status: status,
        commissionState: commission,
        proof: proof,
        proofUploadedAt: proof == ProofStatus.uploaded || proof == ProofStatus.confirmed ? at : null,
        registeredAt: at,
        paymentConfirmedAt: confirmed ? at.add(const Duration(minutes: 20)) : null,
        deliveredAt: status == OrderStatus.delivered ? at.add(const Duration(hours: 1)) : null,
        isSeed: true,
      );
    }

    _orders.addAll([
      seeded(
        number: 131, at: ago(const Duration(minutes: 10)), customer: 'Mariela Quispe',
        whatsapp: '71234567', delivery: DeliveryType.delivery, address: 'Av. Blanco Galindo km 4',
        kind: CatalogKind.combo, itemId: '1', price: 199, payment: PaymentMethod.qr,
        status: OrderStatus.pendingPayment, commission: CommissionState.pending,
        proof: ProofStatus.uploaded,
      ),
      seeded(
        number: 130, at: ago(const Duration(minutes: 38)), customer: 'Valeria Paz',
        whatsapp: '72221010', delivery: DeliveryType.handoff, address: null,
        kind: CatalogKind.product, itemId: '2', price: 85, payment: PaymentMethod.qr,
        status: OrderStatus.preparing, commission: CommissionState.pending,
        proof: ProofStatus.confirmed,
      ),
      seeded(
        number: 129, at: ago(const Duration(minutes: 65)), customer: 'Rodrigo Mendoza',
        whatsapp: '73334455', delivery: DeliveryType.handoff, address: null,
        kind: CatalogKind.product, itemId: '1', price: 120, payment: PaymentMethod.cash,
        status: OrderStatus.delivered, commission: CommissionState.approved,
        proof: ProofStatus.notRequired,
      ),
      seeded(
        number: 126, at: ago(const Duration(hours: 22)), customer: 'Gustavo Terrazas',
        whatsapp: '75550001', delivery: DeliveryType.delivery, address: 'Av. Petrolera 120',
        kind: CatalogKind.product, itemId: '3', price: 64, payment: PaymentMethod.qr,
        status: OrderStatus.returned, commission: CommissionState.reverted,
        proof: ProofStatus.confirmed,
      ),
    ]);

    _addMovement(
      at: ago(const Duration(minutes: 10)), delta: -1, itemName: 'Combo Escritorio Pro',
      description: 'Venta #131 de Ana', type: StockMovementType.sale,
    );
    _addMovement(
      at: ago(const Duration(minutes: 38)), delta: -1, itemName: 'Lámpara luna LED recargable',
      description: 'Venta #130 de Ana', type: StockMovementType.sale,
    );
    _addMovement(
      at: ago(const Duration(minutes: 65)), delta: -1, itemName: 'Audífonos bluetooth ANC con estuche',
      description: 'Venta #129 de Ana', type: StockMovementType.sale,
    );
    _addMovement(
      at: ago(const Duration(minutes: 90)), delta: 20, itemName: 'Audífonos bluetooth ANC con estuche',
      description: 'Ingreso de almacén', type: StockMovementType.entry,
    );
    _addMovement(
      at: ago(const Duration(minutes: 140)), delta: -1, itemName: 'Termo digital 500 ml',
      description: 'Merma · esperando aprobación', type: StockMovementType.waste, pending: true,
    );
  }
}

// --------------------------------------------------------------------------
// Estado interno (mutable) del servidor de prueba
// --------------------------------------------------------------------------

class _Product {
  _Product(this.id, this.code, this.name, this.category, int suggested, int min, this.stock, this.alert)
      : suggested = Money.fromCents(suggested * 100),
        min = Money.fromCents(min * 100);

  final String id;
  final String code;
  final String name;
  final String category;
  final Money suggested;
  final Money min;
  final int alert;
  int stock;
}

class _Part {
  const _Part(this.productId, this.quantity);
  final String productId;
  final int quantity;
}

class _Combo {
  _Combo(this.id, this.code, this.name, int price, int min, this.components)
      : price = Money.fromCents(price * 100),
        min = Money.fromCents(min * 100);

  final String id;
  final String code;
  final String name;
  final Money price;
  final Money min;
  final List<_Part> components;
}

class _Order {
  _Order({
    required this.number,
    required this.createdAt,
    required this.customerName,
    required this.customerWhatsapp,
    required this.delivery,
    required this.lines,
    required this.breakdown,
    required this.total,
    required this.payment,
    required this.status,
    required this.commissionState,
    required this.proof,
    required this.registeredAt,
    required this.isSeed,
    this.proofUploadedAt,
    this.paymentConfirmedAt,
    this.deliveredAt,
  });

  final int number;
  final DateTime createdAt;
  final String customerName;
  final String customerWhatsapp;
  final OrderDelivery delivery;
  final List<OrderLine> lines;
  final CommissionBreakdown breakdown;
  final Money total;
  final PaymentMethod payment;
  final DateTime registeredAt;
  final bool isSeed;

  OrderStatus status;
  CommissionState commissionState;
  ProofStatus proof;
  DateTime? proofUploadedAt;
  DateTime? paymentConfirmedAt;
  DateTime? deliveredAt;

  String get id => '$number';

  String get itemsLabel {
    final first = lines.first;
    final label =
        first.quantity == 1 ? first.name : '${first.name} × ${first.quantity}';
    return lines.length == 1 ? label : '$label y ${lines.length - 1} más';
  }
}
