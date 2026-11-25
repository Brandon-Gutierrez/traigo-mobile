import 'package:flutter_test/flutter_test.dart';
import 'package:traigo/core/money/money.dart';
import 'package:traigo/core/network/api_exception.dart';
import 'package:traigo/features/catalog/data/catalog_api_repository.dart';
import 'package:traigo/features/catalog/domain/pricing.dart';
import 'package:traigo/features/orders/data/orders_api_repository.dart';
import 'package:traigo/features/orders/domain/orders.dart';

import '../fixtures/sales_samples.dart';
import '../support/fake_http_adapter.dart';

void main() {
  late ApiHarness h;

  setUp(() => h = ApiHarness());

  String path() => h.adapter.last.uri.path.replaceFirst('/api/v1', '');

  group('catálogo', () {
    test('busca por texto y categoría, y trae el pedido mayorista mínimo', () async {
      h.adapter.reply(200, catalogResponse);

      final page = await CatalogApiRepository(h.api)
          .list(search: ' messi ', categoryId: 'c1', page: 2);

      expect(path(), '/catalog');
      expect(h.adapter.last.uri.queryParameters,
          {'search': 'messi', 'category': 'c1', 'page': '2'});
      expect(page.wholesaleMinOrder, Money.parse('1000'));
      final item = page.items.items.single;
      expect(item.priceWholesale, Money.parse('82'));
      expect(item.wholesaleMinQty, 24);
      expect(item.available, 45);
      expect(item.commissionPct, isNull, reason: '% por definir');
    });

    test('sin búsqueda no envía parámetros vacíos', () async {
      h.adapter.reply(200, catalogResponse);
      await CatalogApiRepository(h.api).list(search: '  ');
      expect(h.adapter.last.uri.queryParameters, {'page': '1'});
    });

    test('lee categorías y el detalle', () async {
      h.adapter
        ..reply(200, categoriesResponse)
        ..reply(200, catalogDetailResponse);
      final repo = CatalogApiRepository(h.api);

      expect((await repo.categories()).map((c) => c.count), [9, 36, 17]);
      final item = await repo.item('p-8107');
      expect(path(), '/catalog/p-8107');
      expect(item.imageUrls, isEmpty);
    });
  });

  group('ventas', () {
    NewSale sale() => NewSale(
          clientUuid: '6f1a4f3e-0000-4000-8000-000000000001',
          origin: OrderOrigin.wholesale,
          customerName: 'Comercio El Hogar',
          customerPhone: '71234567',
          deliveryType: DeliveryType.pickup,
          paymentMethod: PaymentMethod.transfer,
          lines: const [
            (productId: 'p-8107', quantity: 24),
            (productId: 'p-1109', quantity: 10),
          ],
          expectedTotal: Money.parse('2268'),
        );

    test('filtra «Mis pedidos» por estado', () async {
      h.adapter
        ..reply(200, ordersResponse)
        ..reply(200, ordersResponse);
      final repo = OrdersApiRepository(h.api);

      final page = await repo.list(filter: OrderFilter.inReview);
      expect(h.adapter.last.uri.queryParameters, {'status': 'payment_review', 'page': '1'});
      expect(page.items.single.status, OrderStatus.paymentReview);

      await repo.list();
      expect(h.adapter.last.uri.queryParameters, {'page': '1'});
    });

    test('registrar envía productos, total esperado y la clave contra duplicados',
        () async {
      h.adapter.reply(201, orderDetailResponse);

      final order = await OrdersApiRepository(h.api).create(sale());

      expect(h.adapter.last.method, 'POST');
      expect(path(), '/orders');
      expect(h.adapter.last.data, newSaleRequest);
      expect(h.adapter.last.headers['Idempotency-Key'], sale().clientUuid);
      expect(order.lines.single.priceType, PriceType.unit);
      expect(order.payment?.status, PaymentStatus.submitted);
      expect(order.commission?.amount, isNull);
      expect(order.timeline.where((s) => s.at == null), hasLength(3));
      expect(order.canCancel, isTrue);
    });

    test('si cambió el precio o falta stock llega el motivo', () async {
      h.adapter
        ..reply(409, priceChangedError)
        ..reply(409, insufficientStockError);
      final repo = OrdersApiRepository(h.api);

      for (final code in ['price_changed', 'insufficient_stock']) {
        await expectLater(
          repo.create(sale()),
          throwsA(isA<ConflictException>().having((e) => e.code, 'code', code)),
        );
      }
    });

    test('detalle y cancelación', () async {
      h.adapter
        ..reply(200, orderDetailResponse)
        ..reply(200, orderDetailResponse);
      final repo = OrdersApiRepository(h.api);

      await repo.detail('o-1046');
      expect(path(), '/orders/o-1046');

      await repo.cancel('o-1046', reason: 'El cliente se arrepintió');
      expect(path(), '/orders/o-1046/cancel');
      expect(h.adapter.last.data, {'reason': 'El cliente se arrepintió'});
    });
  });
}
