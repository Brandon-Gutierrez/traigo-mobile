import 'package:flutter_test/flutter_test.dart';
import 'package:traigo/core/demo/demo_backend.dart';
import 'package:traigo/core/money/money.dart';
import 'package:traigo/core/network/api_exception.dart';
import 'package:traigo/features/auth/domain/auth.dart';
import 'package:traigo/features/catalog/domain/catalog.dart';
import 'package:traigo/features/orders/domain/orders.dart';

/// El catálogo y las ventas de la demo siguen las reglas del contrato.
void main() {
  late DemoBackend backend;
  late Member alison;
  late Member kim;

  setUp(() {
    backend = DemoBackend(clock: () => DateTime(2026, 11, 24, 12, 30));
    Member member(String code) => DemoBackend.members.firstWhere((m) => m.code == code);
    alison = member('ALI-04');
    kim = member('KIM-05');
  });

  CatalogItem item(String code) => backend.sales.item('p-$code');

  NewSale sale({
    String key = 'k-1',
    List<(String, int)> lines = const [('8107', 24)],
    String? total,
    PaymentMethod method = PaymentMethod.qr,
    OrderOrigin origin = OrderOrigin.wholesale,
    String name = 'Comercio El Hogar',
  }) =>
      NewSale(
        clientUuid: key,
        origin: origin,
        customerName: name,
        customerPhone: '71234567',
        deliveryType: DeliveryType.pickup,
        paymentMethod: method,
        lines: [for (final (code, qty) in lines) (productId: 'p-$code', quantity: qty)],
        expectedTotal: Money.parse(total ?? '1968'),
      );

  Matcher conflict(String code) =>
      throwsA(isA<ConflictException>().having((e) => e.code, 'code', code));

  group('catálogo', () {
    test('trae los 62 productos en páginas de 30, ordenados por nombre', () {
      final first = backend.sales.catalog();
      expect(first.total, 62);
      expect(first.items, hasLength(30));
      expect(first.lastPage, 3);
      expect(backend.sales.catalog(page: 3).items, hasLength(2));
      expect(first.items.first.name, 'Arma de disparo azul');
    });

    test('busca por nombre o código sin importar tildes ni mayúsculas', () {
      expect(backend.sales.catalog(search: 'CERAMICA').items.map((i) => i.itemCode),
          containsAll(['FSYB-3127', 'FSYB-2622', 'YZTCS-22PS']));
      expect(backend.sales.catalog(search: 'fsyb-1109').items.single.name,
          'Maceta tipo cemento pequeño');
    });

    test('las categorías cuentan sus productos', () {
      expect({for (final c in backend.sales.categories()) c.name: c.count},
          {'Tomatodos': 9, 'Macetas': 36, 'Juguetes': 17});
      expect(backend.sales.catalog(categoryId: 'juguetes').total, 17);
    });
  });

  group('registrar una venta', () {
    test('aplica el precio por mayor, reserva el stock y numera el pedido', () {
      final before = item('8107').available;

      final order = backend.sales.create(kim, sale());

      expect(order.summary.number, 'N-1047');
      expect(order.summary.total, Money.parse('1968'));
      expect(order.summary.status, OrderStatus.pendingPayment);
      expect(order.lines.single.unitPrice, Money.parse('82'));
      expect(item('8107').available, before - 24);
      expect(order.summary.createdAt, DateTime(2026, 12, 6, 12, 30));
    });

    test('con el mínimo basta, aunque el pedido no llegue a Bs 1.000', () {
      final order = backend.sales.create(
        kim,
        sale(lines: const [('HGV-8260WDS', 6)], total: '960'),
      );
      expect(order.lines.single.unitPrice, Money.parse('160'));
    });

    test('reintentar con la misma clave no registra dos veces', () {
      final first = backend.sales.create(kim, sale());
      final again = backend.sales.create(kim, sale());

      expect(again.summary.id, first.summary.id);
      expect(item('8107').reserved, 3 + 24);
      expect(() => backend.sales.create(kim, sale(name: 'Otro')),
          conflict('idempotency_conflict'));
    });

    test('si el total que vio la persona no coincide, no registra', () {
      expect(() => backend.sales.create(kim, sale(total: '2088')), conflict('price_changed'));
      expect(item('8107').reserved, 3);
    });

    test('no vende más de lo disponible', () {
      expect(
        () => backend.sales.create(kim, sale(lines: const [('8107', 46)], total: '3772')),
        throwsA(isA<ConflictException>()
            .having((e) => e.code, 'code', 'insufficient_stock')
            .having((e) => (e.data! as Map)['available'], 'disponible', 45)),
      );
    });

    test('solo quienes venden registran', () {
      final isai = DemoBackend.members.firstWhere((m) => m.code == 'ISA-03');
      expect(() => backend.sales.create(isai, sale()), throwsA(isA<NotFoundException>()));
    });

    test('la venta nueva aparece en el Inicio de quien la hizo', () {
      backend.sales.create(kim, sale());
      backend.login('KIM-05', '1234');
      expect(backend.home().todaySales.map((s) => s.id), ['1047', '1043']);
    });
  });

  group('mis pedidos', () {
    test('cada quien ve solo los suyos, del más nuevo al más antiguo', () {
      expect(backend.sales.orders(alison).items.map((o) => o.number),
          ['N-1046', 'N-1045', 'N-1040', 'N-1038']);
      expect(() => backend.sales.order(alison, '1043'), throwsA(isA<NotFoundException>()));
    });

    test('«Pagados» incluye los listos para entregar', () {
      expect(backend.sales.orders(kim, filter: OrderFilter.paid).items.single.status,
          OrderStatus.ready);
    });

    test('cancelar devuelve el stock; un pagado ya no se cancela', () {
      final before = item('8107').available;

      final cancelled = backend.sales.cancel(alison, '1046');

      expect(cancelled.summary.status, OrderStatus.cancelled);
      expect(cancelled.canCancel, isFalse);
      expect(item('8107').available, before + 2);
      expect(() => backend.sales.cancel(alison, '1045'), conflict('not_cancellable'));
    });

    test('subir otro comprobante reemplaza al anterior y queda en revisión', () {
      final order = backend.sales
          .uploadProof(alison, '1046', filename: 'nuevo.jpg', reference: ' 0045-1 ');

      expect(order.summary.status, OrderStatus.paymentReview);
      expect(order.payment?.proofUrl, endsWith('nuevo.jpg'));
      expect(order.payment?.reference, '0045-1');
      expect(order.canUploadProof, isTrue);
    });

    test('una referencia no se repite y un pagado no admite comprobante', () {
      backend.sales.uploadProof(alison, '1046', filename: 'a.jpg', reference: 'R-1');
      final other = backend.sales.create(alison, sale(key: 'k-2'));

      expect(
        () => backend.sales
            .uploadProof(alison, other.summary.id, filename: 'b.jpg', reference: 'R-1'),
        conflict('reference_duplicated'),
      );
      expect(() => backend.sales.uploadProof(alison, '1045', filename: 'c.jpg'),
          conflict('already_reviewed'));
    });

    test('en efectivo no se sube comprobante', () {
      final order = backend.sales.create(alison, sale(method: PaymentMethod.cash));
      expect(order.canUploadProof, isFalse);
      expect(order.payment?.status, PaymentStatus.submitted);
    });
  });
}
