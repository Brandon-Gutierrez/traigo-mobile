import 'package:flutter_test/flutter_test.dart';
import 'package:traigo/core/demo/demo_backend.dart';
import 'package:traigo/core/money/money.dart';
import 'package:traigo/core/network/api_exception.dart';
import 'package:traigo/features/catalog/domain/catalog.dart';
import 'package:traigo/features/orders/domain/orders.dart';
import 'package:traigo/features/waste/domain/waste.dart';

/// El servidor de prueba debe comportarse como el backend real descrito en
/// docs/api-contract.md. Estas pruebas fijan esas reglas.
CreateOrderInput sale({
  String requestId = 'req-1',
  List<SaleLineInput>? lines,
  PaymentMethod payment = PaymentMethod.qr,
  DeliveryInput? delivery,
  String customer = 'Carla Rojas',
}) {
  return CreateOrderInput(
    clientRequestId: requestId,
    lines: lines ??
        [
          SaleLineInput(
            kind: CatalogKind.product,
            itemId: '1',
            quantity: 1,
            unitPrice: Money.parse('120'),
          ),
        ],
    customer: CustomerInput(name: customer, whatsapp: '74567890'),
    paymentMethod: payment,
    delivery: delivery ?? const DeliveryInput(type: DeliveryType.handoff),
  );
}

int stockOf(DemoBackend b, CatalogKind kind, String id) =>
    b.catalogItem(kind, id).stock;

void main() {
  late DemoBackend backend;

  setUp(() => backend = DemoBackend());

  group('sesión', () {
    test('ingresa con código y PIN correctos, sin importar mayúsculas', () {
      expect(backend.login('ana-07', '1234').seller.name, 'Ana López');
    });

    test('rechaza un PIN incorrecto', () {
      expect(() => backend.login('ANA-07', '0000'), throwsA(isA<UnauthorizedException>()));
    });
  });

  group('catálogo', () {
    test('mezcla productos y combos', () {
      final all = backend.listCatalog().items;
      expect(all.where((i) => i.kind == CatalogKind.product), hasLength(8));
      expect(all.where((i) => i.kind == CatalogKind.combo), hasLength(3));
    });

    test('el stock de un combo es el del componente que más escasea', () {
      // CMB-02 usa el termo, que tiene 3.
      expect(stockOf(backend, CatalogKind.combo, '2'), 3);
    });

    test('busca por nombre o por código sin importar mayúsculas', () {
      expect(backend.listCatalog(search: 'lámpara').items, hasLength(1));
      expect(backend.listCatalog(search: 'tr-0151').items.single.name, contains('Audífonos'));
    });
  });

  group('registrar venta', () {
    test('crea el pedido por confirmar y descuenta el stock', () {
      final before = stockOf(backend, CatalogKind.product, '1');
      final order = backend.createOrder(sale());

      expect(order.status, OrderStatus.pendingPayment);
      expect(order.number, '132');
      expect(order.total.toApi(), '120.00');
      expect(order.breakdown.gain.toApi(), '30.00');
      expect(order.commission.amount.toApi(), '12.00');
      expect(order.commission.state, CommissionState.pending);
      expect(order.paymentProof.status, ProofStatus.missing);
      expect(stockOf(backend, CatalogKind.product, '1'), before - 1);
      expect(backend.listOrders().items.first.id, order.id);
    });

    test('el pago en efectivo no lleva comprobante', () {
      final order = backend.createOrder(sale(payment: PaymentMethod.cash));
      expect(order.paymentProof.status, ProofStatus.notRequired);
    });

    test('rechaza vender por debajo del mínimo y no toca el stock', () {
      final before = stockOf(backend, CatalogKind.product, '1');
      expect(
        () => backend.createOrder(sale(lines: [
          SaleLineInput(
            kind: CatalogKind.product,
            itemId: '1',
            quantity: 1,
            unitPrice: Money.parse('89.99'),
          ),
        ])),
        throwsA(
          isA<ValidationException>().having((e) => e.code, 'code', 'price_below_minimum'),
        ),
      );
      expect(stockOf(backend, CatalogKind.product, '1'), before);
    });

    test('rechaza vender más de lo que hay y avisa cuántas quedan', () {
      expect(
        () => backend.createOrder(sale(lines: [
          SaleLineInput(
            kind: CatalogKind.product,
            itemId: '3', // termo: quedan 3
            quantity: 4,
            unitPrice: Money.parse('75'),
          ),
        ])),
        throwsA(
          isA<ConflictException>()
              .having((e) => e.code, 'code', 'insufficient_stock')
              .having((e) => (e.data as Map)['available'], 'available', 3),
        ),
      );
      expect(stockOf(backend, CatalogKind.product, '3'), 3);
    });

    test('un combo descuenta una unidad de cada producto que lo forma', () {
      final lamp = stockOf(backend, CatalogKind.product, '2');
      final headphones = stockOf(backend, CatalogKind.product, '1');
      final organizer = stockOf(backend, CatalogKind.product, '5');

      backend.createOrder(sale(lines: [
        SaleLineInput(
          kind: CatalogKind.combo,
          itemId: '1',
          quantity: 1,
          unitPrice: Money.parse('199'),
        ),
      ]));

      expect(stockOf(backend, CatalogKind.product, '2'), lamp - 1);
      expect(stockOf(backend, CatalogKind.product, '1'), headphones - 1);
      expect(stockOf(backend, CatalogKind.product, '5'), organizer - 1);
    });

    test('registrar dos veces con la misma clave devuelve el mismo pedido', () {
      final before = stockOf(backend, CatalogKind.product, '1');
      final first = backend.createOrder(sale(requestId: 'dup'));
      final second = backend.createOrder(sale(requestId: 'dup'));

      expect(second.id, first.id);
      expect(stockOf(backend, CatalogKind.product, '1'), before - 1);
    });

    test('exige los datos del cliente y de la entrega', () {
      expect(
        () => backend.createOrder(sale(customer: '  ')),
        throwsA(isA<ValidationException>().having(
          (e) => e.firstErrorFor('customer.name'),
          'customer.name',
          isNotNull,
        )),
      );
      expect(
        () => backend.createOrder(sale(delivery: const DeliveryInput(type: DeliveryType.delivery))),
        throwsA(isA<ValidationException>().having(
          (e) => e.firstErrorFor('delivery.address'),
          'delivery.address',
          isNotNull,
        )),
      );
      expect(
        () => backend.createOrder(sale(delivery: const DeliveryInput(type: DeliveryType.otherCity))),
        throwsA(isA<ValidationException>().having(
          (e) => e.firstErrorFor('delivery.city'),
          'delivery.city',
          isNotNull,
        )),
      );
    });
  });

  group('cancelar y comprobante', () {
    test('cancelar un pedido por confirmar devuelve el stock y revierte la comisión', () {
      final before = stockOf(backend, CatalogKind.product, '1');
      final order = backend.createOrder(sale());
      final cancelled = backend.cancelOrder(order.id);

      expect(cancelled.status, OrderStatus.cancelled);
      expect(cancelled.commission.state, CommissionState.reverted);
      expect(stockOf(backend, CatalogKind.product, '1'), before);
    });

    test('no se puede cancelar un pedido con el pago ya confirmado', () {
      // El #130 de los datos de prueba está en preparación.
      expect(
        () => backend.cancelOrder('130'),
        throwsA(isA<ConflictException>().having((e) => e.code, 'code', 'not_cancellable')),
      );
    });

    test('subir el comprobante lo deja en revisión', () {
      final order = backend.createOrder(sale());
      final updated = backend.uploadPaymentProof(order.id);
      expect(updated.paymentProof.status, ProofStatus.uploaded);
      expect(updated.paymentProof.uploadedAt, isNotNull);
    });

    test('un pago en efectivo no acepta comprobante', () {
      final order = backend.createOrder(sale(payment: PaymentMethod.cash));
      expect(() => backend.uploadPaymentProof(order.id), throwsA(isA<ValidationException>()));
    });
  });

  group('merma', () {
    CreateWasteInput waste({String id = 'w-1', int quantity = 1, String item = '3'}) =>
        CreateWasteInput(
          clientRequestId: id,
          itemId: item,
          quantity: quantity,
          reason: WasteReason.damaged,
          note: 'Se cayó del estante',
        );

    test('queda pendiente y no baja el stock hasta que el admin apruebe', () {
      final before = stockOf(backend, CatalogKind.product, '3');
      final report = backend.createWaste(waste());

      expect(report.status, WasteStatus.pending);
      expect(stockOf(backend, CatalogKind.product, '3'), before);
      expect(backend.movements().items.first.pending, isTrue);
    });

    test('no deja reportar más de lo que hay en bodega', () {
      expect(
        () => backend.createWaste(waste(quantity: 50)),
        throwsA(isA<ValidationException>()),
      );
    });

    test('es idempotente por clave', () {
      final a = backend.createWaste(waste(id: 'same'));
      final b = backend.createWaste(waste(id: 'same'));
      expect(b.id, a.id);
      expect(backend.listWaste().total, 1);
    });
  });

  group('inicio y stock', () {
    test('la comisión del día suma la de las ventas nuevas', () {
      expect(backend.home().today.commission.toApi(), '86.40');
      backend.createOrder(sale()); // gana 12,00
      final home = backend.home();
      expect(home.today.commission.toApi(), '98.40');
      expect(home.today.salesCount, 6);
      expect(home.recentOrders.first.number, '132');
    });

    test('el resumen de stock separa poco stock de agotados', () {
      final summary = backend.stockSummary();
      expect(summary.outCount, 1); // proyector
      expect(summary.lowCount, 2); // termo y masajeador
    });
  });
}
