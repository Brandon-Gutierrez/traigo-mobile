/// Caja del día, despachos, stock y conteos de la demo.
///
/// La caja se calcula con los pedidos de la demo. Los cierres anteriores, sus
/// observaciones y el conteo son de ejemplo.
library;

import '../../features/auth/domain/auth.dart';
import '../../features/home/domain/home.dart';
import '../../features/warehouse/domain/warehouse.dart';
import '../money/money.dart';
import '../network/api_exception.dart';
import 'demo_audit.dart';
import 'demo_sales.dart';

class DemoWarehouse {
  DemoWarehouse({required this._now, required this._sales, DemoAudit? audit})
      : _audit = audit ?? DemoAudit(now: _now) {
    _seed();
  }

  /// Desde este día se pide el cierre de caja de cada día, aunque sea en cero.
  static final firstDay = DateTime(2026, 12, 1);

  final DateTime Function() _now;
  final DemoSales _sales;
  final DemoAudit _audit;

  final Map<DateTime, _Closing> _closings = {};
  final List<_Count> _counts = [];

  /// Productos de cada conteo ya corregidos con un ajuste.
  final Set<(String, String)> _adjusted = {};

  /// Envíos ya recibidos, por su clave contra duplicados.
  final Map<String, CashDay> _sentClosings = {};
  final Map<String, StockLevel> _sentMovements = {};
  final Map<String, String> _sentCounts = {};
  int _nextCount = 2;

  DateTime get _today => _dateOnly(_now());

  static DateTime _dateOnly(DateTime at) => DateTime(at.year, at.month, at.day);

  // ──────────────────────────────────────────────────────────── despachos

  List<Dispatch> dispatches(Member member) {
    _requireWarehouse(member);
    return _sales.dispatchQueue();
  }

  void markReady(Member member, String orderId) {
    _requireWarehouse(member);
    _sales.markReady(orderId);
  }

  void markDelivered(Member member, String orderId) {
    _requireWarehouse(member);
    _sales.markDelivered(orderId);
  }

  // ───────────────────────────────────────────────────────────────── caja

  CashDay cashToday(Member member) {
    _requireWarehouse(member);
    return _day(_today);
  }

  CashDay cashDay(Member member, DateTime date) {
    _requireWarehouse(member);
    final day = _dateOnly(date);
    _requireCashDay(day);
    return _day(day);
  }

  CashDay sendClosing(Member member, NewCashClosing closing) {
    _requireWarehouse(member);
    final repeated = _sentClosings[closing.clientUuid];
    if (repeated != null) return repeated;

    final date = _dateOnly(closing.businessDate);
    _requireCashDay(date);
    final existing = _closings[date];
    if (existing != null && existing.status != CashStatus.observed) {
      throw const ConflictException(
        code: 'closing_already_sent',
        message: 'El cierre de ese día ya se envió.',
      );
    }

    final lines = [
      for (final line in _day(date).lines)
        CashLine(
          method: line.method,
          ordersCount: line.ordersCount,
          expected: line.expected,
          counted: closing.counted[line.method] ??
              (throw ValidationException(
                message: 'Falta lo recibido por ${line.method.label}.',
              )),
        ),
    ];
    final note = closing.note?.trim() ?? '';
    final balanced = lines.every((l) => l.difference!.isZero);
    if (!balanced && note.isEmpty) {
      throw const ValidationException(
        code: 'difference_needs_note',
        message: 'La caja no cuadra: explica la diferencia.',
      );
    }

    _closings[date] = _Closing(
      status: CashStatus.sent,
      lines: lines,
      closedByName: member.name,
      sentAt: _now(),
      note: note.isEmpty ? null : note,
    );
    _audit.log(member.name, 'Envió el cierre de caja del ${date.day} dic');
    return _sentClosings[closing.clientUuid] = _day(date);
  }

  /// Lo que se ve en el Inicio de almacén.
  CashToday todaySummary() {
    final day = _day(_today);
    return CashToday(
      collected: day.collected,
      paidOrders: day.paidOrders,
      pendingOrders: day.pendingOrders,
      status: day.status,
      pendingDays: day.pendingDays.length,
    );
  }

  /// Cierres que Jime todavía no revisa.
  int get closingsToReview =>
      _closings.values.where((c) => c.status == CashStatus.sent).length;

  /// Los cierres enviados que esperan a Jime.
  List<CashDay> sentClosings() => [
        for (final MapEntry(key: date, value: closing) in _closings.entries)
          if (closing.status == CashStatus.sent) _day(date),
      ];

  CashDay closingById(String id) => _day(_dateOfClosing(id));

  /// Al validar, el efectivo de ese día queda confirmado.
  CashDay validateClosing(String id) {
    final date = _dateOfClosing(id);
    final closing = _requireSent(date);
    _closings[date] = closing.reviewed(CashStatus.validated);
    _sales.confirmCashOn(date);
    return _day(date);
  }

  CashDay observeClosing(String id, String note) {
    if (note.trim().isEmpty) {
      throw const ValidationException(message: 'Escribe qué hay que corregir.');
    }
    final date = _dateOfClosing(id);
    final closing = _requireSent(date);
    _closings[date] = closing.reviewed(CashStatus.observed, note.trim());
    return _day(date);
  }

  DateTime _dateOfClosing(String id) {
    for (final date in _closings.keys) {
      if (_closingId(date) == id) return date;
    }
    throw const NotFoundException('No encontramos ese cierre.');
  }

  _Closing _requireSent(DateTime date) {
    final closing = _closings[date]!;
    if (closing.status != CashStatus.sent) {
      throw const ConflictException(
        code: 'already_reviewed',
        message: 'Ese cierre ya se revisó.',
      );
    }
    return closing;
  }

  static String _closingId(DateTime date) => 'cc-demo-${date.day}';

  /// Días anteriores sin enviar o que Jime observó, del más antiguo al más nuevo.
  List<PendingDay> _pendingDays() => [
        for (var day = firstDay;
            day.isBefore(_today);
            day = DateTime(day.year, day.month, day.day + 1))
          if ((_closings[day]?.status ?? CashStatus.open)
              case final status && (CashStatus.open || CashStatus.observed))
            PendingDay(date: day, status: status),
      ];

  void _requireCashDay(DateTime day) {
    if (day.isBefore(firstDay) || day.isAfter(_today)) {
      throw const NotFoundException('Ese día no tiene caja.');
    }
  }

  CashDay _day(DateTime date) {
    final closing = _closings[date];
    // Enviado o validado se muestra como se envió; observado se recalcula para
    // corregirlo, con lo que se había contado.
    final frozen = closing != null && closing.status != CashStatus.observed;
    final lines = frozen ? closing.lines : _expectedLines(date, closing);
    final pending = _sales.pendingOn(date);

    return CashDay(
      closingId: closing == null ? null : _closingId(date),
      businessDate: date,
      status: closing?.status ?? CashStatus.open,
      collected: lines.fold(Money.zero, (sum, l) => sum + l.expected),
      paidOrders: lines.fold(0, (sum, l) => sum + l.ordersCount),
      pendingOrders: pending.length,
      lines: lines,
      pending: pending,
      pendingDays: date == _today ? _pendingDays() : const [],
      closedByName: closing?.closedByName,
      sentAt: closing?.sentAt,
      note: closing?.note,
      reviewNote: closing?.reviewNote,
    );
  }

  List<CashLine> _expectedLines(DateTime date, _Closing? previous) {
    final collections = _sales.collectionsOn(date);
    final methods = [
      PaymentMethod.qr,
      PaymentMethod.transfer,
      PaymentMethod.cash,
      // La tarjeta solo existe en la tienda web.
      if (collections.any((c) => c.method == PaymentMethod.card)) PaymentMethod.card,
    ];
    return [
      for (final method in methods)
        CashLine(
          method: method,
          ordersCount: collections.where((c) => c.method == method).length,
          expected: collections
              .where((c) => c.method == method)
              .fold(Money.zero, (sum, c) => sum + c.amount),
          counted: previous?.lines.where((l) => l.method == method).firstOrNull?.counted,
        ),
    ];
  }

  // ────────────────────────────────────────────────────── stock y conteos

  StockLevel registerStock(
    Member member, {
    required String clientUuid,
    required String productId,
    required StockEntryType type,
    required int quantity,
    String? note,
    String? inventoryCountId,
  }) {
    _requireWarehouse(member);
    final repeated = _sentMovements[clientUuid];
    if (repeated != null) return repeated;

    if (quantity < 1) {
      throw const ValidationException(message: 'La cantidad debe ser al menos 1.');
    }
    final isAdjustment =
        type == StockEntryType.adjustmentIn || type == StockEntryType.adjustmentOut;
    if (isAdjustment && (note ?? '').trim().isEmpty) {
      throw const ValidationException(
        code: 'note_required',
        message: 'Escribe el motivo del ajuste.',
      );
    }
    if (inventoryCountId != null) {
      final item = _counts
          .where((c) => c.id == inventoryCountId)
          .expand((c) => c.items)
          .where((i) => i.productId == productId)
          .firstOrNull;
      if (item == null) {
        throw const NotFoundException('Ese producto no está en el conteo.');
      }
      if (_adjusted.contains((inventoryCountId, productId))) {
        throw const ConflictException(
          code: 'already_adjusted',
          message: 'Esa diferencia ya se corrigió.',
        );
      }
      if (!isAdjustment || type.signed(quantity) != item.difference) {
        throw const ValidationException(message: 'El ajuste no coincide con el conteo.');
      }
    }

    final level = _sales.moveStock(productId, type.signed(quantity));
    if (inventoryCountId != null) _adjusted.add((inventoryCountId, productId));
    final signed = type.signed(quantity);
    _audit.log(
      member.name,
      '${isAdjustment ? 'Ajustó' : 'Cargó'} el stock de ${_sales.item(productId).itemCode}: '
      '${signed > 0 ? '+' : '−'}$quantity${isAdjustment ? ' (${note!.trim()})' : ''}',
    );
    return _sentMovements[clientUuid] = level;
  }

  /// Del más nuevo al más antiguo. Jime también los ve.
  List<InventoryCount> counts(Member member) {
    if (member.role != MemberRole.control) _requireWarehouse(member);
    return [for (final count in _counts.reversed) _view(count)];
  }

  InventoryCount submitCount(
    Member member, {
    required String clientUuid,
    required DateTime countedOn,
    required Map<String, int> counted,
  }) {
    _requireWarehouse(member);
    final repeated = _sentCounts[clientUuid];
    if (repeated != null) return _view(_counts.firstWhere((c) => c.id == repeated));

    if (counted.isEmpty || counted.values.any((q) => q < 0)) {
      throw const ValidationException(message: 'Revisa las cantidades contadas.');
    }
    final count = _Count(
      id: 'ic-demo-${_nextCount++}',
      countedOn: _dateOnly(countedOn),
      items: [
        for (final MapEntry(key: productId, value: quantity) in counted.entries)
          _counted(productId, quantity),
      ],
    );
    _counts.add(count);
    _sentCounts[clientUuid] = count.id;
    return _view(count);
  }

  /// Compara con lo que hay en bodega (reservado incluido) al guardar.
  CountedProduct _counted(String productId, int quantity, {int? systemQty}) {
    final product = _sales.item(productId);
    return CountedProduct(
      productId: productId,
      itemCode: product.itemCode,
      name: product.name,
      systemQty: systemQty ?? product.stock,
      countedQty: quantity,
    );
  }

  InventoryCount _view(_Count count) => InventoryCount(
        id: count.id,
        countedOn: count.countedOn,
        items: [
          for (final item in count.items)
            CountedProduct(
              productId: item.productId,
              itemCode: item.itemCode,
              name: item.name,
              systemQty: item.systemQty,
              countedQty: item.countedQty,
              adjusted: _adjusted.contains((count.id, item.productId)),
            ),
        ],
      );

  static void _requireWarehouse(Member member) {
    if (member.role != MemberRole.warehouse) {
      throw const NotFoundException('Esto es de almacén.');
    }
  }

  // ─────────────────────────────────────────── cierres y conteo de ejemplo

  void _seed() {
    DateTime dec(int day, [int hour = 0, int minute = 0]) =>
        DateTime(2026, 12, day, hour, minute);

    List<CashLine> lines(List<(PaymentMethod, int, String, String)> data) => [
          for (final (method, orders, expected, counted) in data)
            CashLine(
              method: method,
              ordersCount: orders,
              expected: Money.parse(expected),
              counted: Money.parse(counted),
            ),
        ];

    final empty = lines([
      (PaymentMethod.qr, 0, '0', '0'),
      (PaymentMethod.transfer, 0, '0', '0'),
      (PaymentMethod.cash, 0, '0', '0'),
    ]);
    for (final day in [1, 2]) {
      _closings[dec(day)] = _Closing(
        status: CashStatus.validated,
        lines: empty,
        closedByName: 'Isaí',
        sentAt: dec(day, 19, 0),
      );
    }
    // El del sábado 5 está enviado: Jime lo revisa.
    _closings[dec(5)] = _Closing(
      status: CashStatus.sent,
      lines: [
        for (final line in _expectedLines(dec(5), null))
          CashLine(
            method: line.method,
            ordersCount: line.ordersCount,
            expected: line.expected,
            counted: line.expected,
          ),
      ],
      closedByName: 'Isaí',
      sentAt: dec(5, 18, 30),
    );
    _closings[dec(4)] = _Closing(
      status: CashStatus.observed,
      lines: lines([
        (PaymentMethod.qr, 0, '0', '0'),
        (PaymentMethod.transfer, 0, '0', '0'),
        (PaymentMethod.cash, 1, '890', '840'),
      ]),
      closedByName: 'Isaí',
      sentAt: dec(4, 18, 45),
      note: 'Faltan Bs 50 de cambio.',
      reviewNote: 'Escribe de qué venta es la diferencia y cuándo se repone.',
    );

    _counts.add(_Count(
      id: 'ic-demo-1',
      countedOn: dec(4),
      items: [
        _counted('p-8109', 58, systemQty: 60),
        _counted('p-FSYB-1109W', 120, systemQty: 120),
      ],
    ));
  }
}

class _Closing {
  const _Closing({
    required this.status,
    required this.lines,
    required this.closedByName,
    required this.sentAt,
    this.note,
    this.reviewNote,
  });

  final CashStatus status;
  final List<CashLine> lines;
  final String closedByName;
  final DateTime sentAt;
  final String? note;
  final String? reviewNote;

  _Closing reviewed(CashStatus status, [String? reviewNote]) => _Closing(
        status: status,
        lines: lines,
        closedByName: closedByName,
        sentAt: sentAt,
        note: note,
        reviewNote: reviewNote,
      );
}

class _Count {
  const _Count({required this.id, required this.countedOn, required this.items});

  final String id;
  final DateTime countedOn;
  final List<CountedProduct> items;
}
