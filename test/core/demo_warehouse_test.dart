import 'package:flutter_test/flutter_test.dart';
import 'package:traigo/core/demo/demo_backend.dart';
import 'package:traigo/core/demo/demo_sales.dart';
import 'package:traigo/core/demo/demo_warehouse.dart';
import 'package:traigo/core/money/money.dart';
import 'package:traigo/core/network/api_exception.dart';
import 'package:traigo/features/auth/domain/auth.dart';
import 'package:traigo/features/orders/domain/orders.dart';
import 'package:traigo/features/warehouse/domain/warehouse.dart';

Matcher conflict(String code) =>
    throwsA(isA<ConflictException>().having((e) => e.code, 'code', code));
Matcher invalid([String? code]) => throwsA(
    isA<ValidationException>().having((e) => e.code, 'code', code ?? anything));
final Matcher notFound = throwsA(isA<NotFoundException>());

void main() {
  late DemoBackend backend;
  late Member isai;
  late Member alison;

  setUp(() {
    backend = DemoBackend(clock: () => DateTime(2026, 11, 24, 18));
    Member member(String code) => DemoBackend.members.firstWhere((m) => m.code == code);
    isai = member('ISA-03');
    alison = member('ALI-04');
  });

  final today = DateTime(2026, 12, 6);

  group('despachos', () {
    List<Dispatch> queue() => backend.warehouse.dispatches(isai);

    test('van primero los de entrega más cercana y al final los sin hora', () {
      expect(queue().map((d) => d.number), ['N-1043', 'N-1045', 'N-1042', 'N-1041']);
      expect(queue().where((d) => d.isLate).map((d) => d.number), ['N-1043', 'N-1045']);
      final web = queue().last;
      expect(web.promisedAt, isNull);
      expect(web.isLate, isFalse);
      expect(web.lines.single.quantity, 1);
    });

    test('listo y después entregado: sale de la bodega', () {
      expect(() => backend.warehouse.markDelivered(isai, '1045'), conflict('invalid_status'),
          reason: 'primero se marca listo');

      backend.warehouse.markReady(isai, '1045');
      backend.warehouse.markDelivered(isai, '1045');

      expect(queue().map((d) => d.orderId), isNot(contains('1045')));
      final level = backend.sales.stockLevel('p-8923');
      expect((level.stock, level.reserved), (0, 0));
      final order = backend.sales.order(alison, '1045');
      expect(order.summary.status, OrderStatus.delivered);
      expect(order.timeline.every((s) => s.at != null), isTrue);
    });

    test('solo almacén', () {
      expect(() => backend.warehouse.dispatches(alison), notFound);
      expect(() => backend.warehouse.cashToday(alison), notFound);
    });
  });

  group('caja', () {
    CashDay day([DateTime? date]) => date == null
        ? backend.warehouse.cashToday(isai)
        : backend.warehouse.cashDay(isai, date);

    CashLine line(CashDay day, PaymentMethod method) =>
        day.lines.firstWhere((l) => l.method == method);

    NewCashClosing closing(CashDay from, {String key = 'c-1', String? cash, String? note}) =>
        NewCashClosing(
          clientUuid: key,
          businessDate: from.businessDate,
          counted: {
            for (final l in from.lines)
              l.method: l.method == PaymentMethod.cash && cash != null
                  ? Money.parse(cash)
                  : l.expected,
          },
          note: note,
        );

    test('lo de hoy sale de los pedidos y avisa lo que falta de antes', () {
      final today = day();

      expect(today.lines.map((l) => l.method),
          [PaymentMethod.qr, PaymentMethod.transfer, PaymentMethod.cash]);
      expect(line(today, PaymentMethod.qr).expected, Money.parse('563'));
      expect(line(today, PaymentMethod.transfer).expected, Money.parse('2016'));
      expect(line(today, PaymentMethod.cash).expected, Money.parse('836'));
      expect(today.collected, Money.parse('3415'));
      expect(today.pending.single.number, 'N-1044');
      expect(today.pending.single.sellerName, 'Kim');
      expect(today.pendingDays.map((d) => (d.date.day, d.status)),
          [(3, CashStatus.open), (4, CashStatus.observed)]);
    });

    test('una venta en efectivo entra en la caja de hoy', () {
      backend.sales.create(
        alison,
        NewSale(
          clientUuid: 's-1',
          origin: OrderOrigin.inPerson,
          customerName: 'Ana',
          deliveryType: DeliveryType.pickup,
          paymentMethod: PaymentMethod.cash,
          lines: const [(productId: 'p-8107', quantity: 1)],
          expectedTotal: Money.parse('87'),
          promisedAt: DateTime(2026, 12, 6, 19),
        ),
      );

      expect(line(day(), PaymentMethod.cash).expected, Money.parse('923'));
    });

    test('el observado trae lo contado y lo que pidió Jime', () {
      final observed = day(DateTime(2026, 12, 4));

      expect(observed.status, CashStatus.observed);
      expect(observed.canSend, isTrue);
      expect(line(observed, PaymentMethod.cash).expected, Money.parse('890'));
      expect(line(observed, PaymentMethod.cash).counted, Money.parse('840'));
      expect(observed.reviewNote, isNotEmpty);
      expect(observed.pendingDays, isEmpty, reason: 'solo hoy los lista');
    });

    test('con diferencia exige explicarla; enviado, ya no se reenvía', () {
      final open = day();
      expect(
        () => backend.warehouse.sendClosing(isai, closing(open, cash: '800')),
        invalid('difference_needs_note'),
      );

      final sent = backend.warehouse
          .sendClosing(isai, closing(open, cash: '800', note: 'Falta cambio.'));
      expect(sent.status, CashStatus.sent);
      expect(sent.closedByName, 'Isaí');
      expect(line(sent, PaymentMethod.cash).difference, Money.parse('-36'));
      expect(
        backend.warehouse
            .sendClosing(isai, closing(open, cash: '800', note: 'Falta cambio.'))
            .status,
        CashStatus.sent,
        reason: 'misma clave',
      );
      expect(
        () => backend.warehouse.sendClosing(isai, closing(open, key: 'c-2')),
        conflict('closing_already_sent'),
      );
      expect(backend.warehouse.closingsToReview, 2, reason: 'el sábado 5 y hoy');
    });

    test('un día anterior sin cobros también se envía y deja de estar pendiente', () {
      final thursday = day(DateTime(2026, 12, 3));
      expect(thursday.collected, Money.zero);

      backend.warehouse.sendClosing(isai, closing(thursday));

      expect(day().pendingDays.map((d) => d.date.day), [4]);
    });

    test('el sábado 5 ya está enviado a Jime', () {
      final saturday = day(DateTime(2026, 12, 5));

      expect(saturday.status, CashStatus.sent);
      expect(saturday.canSend, isFalse);
      expect(backend.warehouse.closingsToReview, 1);
    });

    test('hay que mandar todas las formas de pago y solo días de la campaña', () {
      final open = day();
      expect(
        () => backend.warehouse.sendClosing(
          isai,
          NewCashClosing(
            clientUuid: 'c-9',
            businessDate: open.businessDate,
            counted: {PaymentMethod.qr: Money.parse('563')},
          ),
        ),
        invalid(),
      );
      expect(() => day(DateTime(2026, 11, 30)), notFound);
      expect(() => day(today.add(const Duration(days: 1))), notFound);
    });

    test('un cobro después de enviar pasa al siguiente cierre', () {
      // La demo vive el 6; para llegar al 7 hace falta un reloj propio.
      var now = DateTime(2026, 12, 6, 12);
      final sales = DemoSales(now: () => now);
      final warehouse = DemoWarehouse(now: () => now, sales: sales);
      final sunday = warehouse.sendClosing(isai, closing(warehouse.cashToday(isai)));

      now = DateTime(2026, 12, 6, 19);
      final late = sales.create(
        alison,
        NewSale(
          clientUuid: 's-1',
          origin: OrderOrigin.inPerson,
          customerName: 'Ana',
          deliveryType: DeliveryType.pickup,
          paymentMethod: PaymentMethod.cash,
          lines: const [(productId: 'p-8107', quantity: 1)],
          expectedTotal: Money.parse('87'),
          promisedAt: DateTime(2026, 12, 6, 20),
        ),
      );
      PaymentStatus lateStatus() => sales.order(alison, late.summary.id).payment!.status;

      expect(warehouse.cashToday(isai).collected, sunday.collected,
          reason: 'lo enviado no cambia');
      warehouse.validateClosing(sunday.closingId!);
      expect(lateStatus(), PaymentStatus.submitted, reason: 'no estaba en ese cierre');

      now = DateTime(2026, 12, 7, 10);
      final monday = warehouse.cashToday(isai);
      expect(monday.collected, Money.parse('87'));
      expect(warehouse.cashDay(isai, DateTime(2026, 12, 3)).collected, Money.zero,
          reason: 'un día anterior no se lo lleva');

      final sent = warehouse.sendClosing(isai, closing(monday, key: 'c-2'));
      warehouse.validateClosing(sent.closingId!);
      expect(lateStatus(), PaymentStatus.confirmed);
      expect(warehouse.cashDay(isai, today).collected, sunday.collected);
    });
  });

  group('stock', () {
    StockLevel move(StockEntryType type, int quantity,
            {String key = 'm-1', String? note, String? countId, String product = 'p-8109'}) =>
        backend.warehouse.registerStock(
          isai,
          clientUuid: key,
          productId: product,
          type: type,
          quantity: quantity,
          note: note,
          inventoryCountId: countId,
        );

    test('un ingreso suma una sola vez', () {
      expect(move(StockEntryType.purchase, 12).stock, 72);
      expect(move(StockEntryType.purchase, 12).stock, 72, reason: 'misma clave');
      expect(backend.sales.item('p-8109').available, 48);
    });

    test('los ajustes llevan motivo y no bajan de lo reservado', () {
      expect(() => move(StockEntryType.adjustmentOut, 1), invalid('note_required'));
      expect(() => move(StockEntryType.adjustmentOut, 37, note: 'Rotos'),
          conflict('below_reserved'));
      expect(move(StockEntryType.adjustmentOut, 36, key: 'm-2', note: 'Rotos').available, 0);
    });

    test('el ajuste de un conteo es exacto y una sola vez', () {
      final count = backend.warehouse.counts(isai).single;
      final item = count.items.firstWhere((i) => i.productId == 'p-8109');
      expect(item.difference, -2);
      expect(item.needsAdjustment, isTrue);

      expect(
        () => move(StockEntryType.adjustmentOut, 1, note: 'x', countId: count.id),
        invalid(),
      );
      final level =
          move(StockEntryType.adjustmentOut, 2, key: 'm-3', note: 'Rotos', countId: count.id);
      expect(level.stock, 58);
      expect(backend.warehouse.counts(isai).single.items.first.adjusted, isTrue);
      expect(
        () => move(StockEntryType.adjustmentOut, 2,
            key: 'm-4', note: 'Rotos', countId: count.id),
        conflict('already_adjusted'),
      );
    });

    test('un conteo guarda lo que había en bodega y no cambia el stock', () {
      final saved = backend.warehouse.submitCount(
        isai,
        clientUuid: 'n-1',
        countedOn: today,
        counted: {'p-8866': 20},
      );

      expect(saved.items.single.systemQty, 24);
      expect(saved.items.single.difference, -4);
      expect(backend.sales.stockLevel('p-8866').stock, 24);
      expect(backend.warehouse.counts(isai).first.id, saved.id);
    });
  });
}
