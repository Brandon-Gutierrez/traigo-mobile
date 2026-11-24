import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traigo/core/money/money.dart';
import 'package:traigo/core/network/api_client.dart';
import 'package:traigo/core/network/api_exception.dart';
import 'package:traigo/features/auth/data/auth_api_repository.dart';
import 'package:traigo/features/catalog/data/catalog_api_repository.dart';
import 'package:traigo/features/catalog/domain/catalog.dart';
import 'package:traigo/features/home/data/home_api_repository.dart';
import 'package:traigo/features/orders/data/orders_api_repository.dart';
import 'package:traigo/features/orders/domain/orders.dart';
import 'package:traigo/features/stock/data/stock_api_repository.dart';
import 'package:traigo/features/waste/data/waste_api_repository.dart';
import 'package:traigo/features/waste/domain/waste.dart';

import '../fixtures/api_samples.dart';
import '../support/fake_http_adapter.dart';

/// Comprueban que la app habla el contrato de docs/api-contract.md:
/// rutas, cabeceras, cuerpos y cómo interpreta cada respuesta o error.
CreateOrderInput newSale() => CreateOrderInput(
      clientRequestId: 'b3f1c2d4-0000-4000-8000-000000000001',
      lines: [
        SaleLineInput(
          kind: CatalogKind.product,
          itemId: '1',
          quantity: 1,
          unitPrice: Money.parse('120'),
        ),
      ],
      customer: const CustomerInput(name: 'Mariela Quispe', whatsapp: '71234567'),
      paymentMethod: PaymentMethod.qr,
      delivery: const DeliveryInput(type: DeliveryType.delivery, address: 'Av. Blanco Galindo km 4'),
    );

void main() {
  late ApiHarness h;

  setUp(() => h = ApiHarness());

  group('sesión', () {
    test('login envía código y PIN, guarda el token y devuelve la sesión', () async {
      h.adapter.reply(200, loginResponse);
      final repo = AuthApiRepository(h.api, h.tokens);

      final session = await repo.login(code: ' ANA-07 ', pin: '1234', deviceName: 'Pixel');

      expect(h.adapter.last.method, 'POST');
      expect(h.adapter.last.uri.toString(), 'http://test.local/api/v1/auth/login');
      expect(h.adapter.last.data, {'code': 'ANA-07', 'pin': '1234', 'device_name': 'Pixel'});
      expect(session.seller.code, 'ANA-07');
      expect(session.rules.personalPercent, 40);
      expect(session.rules.fundPercent, 25);
      expect(await h.tokens.read(), '1|k9sPq3');
    });

    test('un PIN incorrecto (401) no cuenta como sesión vencida', () async {
      h.adapter.reply(401, invalidCredentialsError);
      final repo = AuthApiRepository(h.api, h.tokens);

      await expectLater(
        repo.login(code: 'ANA-07', pin: '0000', deviceName: 'Pixel'),
        throwsA(isA<UnauthorizedException>().having((e) => e.message, 'message', 'Código o PIN incorrectos.')),
      );
      expect(h.unauthorizedCalls, 0);
    });

    test('restore sin token no llama al servidor', () async {
      final empty = ApiHarness(token: null);
      expect(await AuthApiRepository(empty.api, empty.tokens).restore(), isNull);
      expect(empty.adapter.requests, isEmpty);
    });

    test('restore con token válido devuelve la sesión', () async {
      h.adapter.reply(200, meResponse);
      final session = await AuthApiRepository(h.api, h.tokens).restore();
      expect(session?.seller.name, 'Ana López');
      expect(h.adapter.last.uri.path, '/api/v1/me');
    });

    test('restore con token revocado (401) lo borra', () async {
      h.adapter.reply(401, {'message': 'Unauthenticated.'});
      expect(await AuthApiRepository(h.api, h.tokens).restore(), isNull);
      expect(await h.tokens.read(), isNull);
    });

    test('restore sin internet NO borra el token', () async {
      h.adapter.failConnection();
      await expectLater(
        AuthApiRepository(h.api, h.tokens).restore(),
        throwsA(isA<NetworkException>()),
      );
      expect(await h.tokens.read(), 'tok');
    });

    test('logout borra el token aunque el servidor falle', () async {
      h.adapter.failConnection();
      await AuthApiRepository(h.api, h.tokens).logout();
      expect(await h.tokens.read(), isNull);
    });
  });

  group('cabeceras y errores generales', () {
    test('toda petición lleva el token Bearer y pide JSON en español', () async {
      h.adapter.reply(200, catalogPage);
      await CatalogApiRepository(h.api).list();

      expect(h.adapter.last.headers['Authorization'], 'Bearer tok');
      expect(h.adapter.last.headers['Accept'], 'application/json');
      expect(h.adapter.last.headers['Accept-Language'], 'es');
    });

    test('un 401 con sesión avisa para cerrarla', () async {
      h.adapter.reply(401, {'message': 'Unauthenticated.'});
      await expectLater(
        CatalogApiRepository(h.api).list(),
        throwsA(isA<UnauthorizedException>()),
      );
      expect(h.unauthorizedCalls, 1);
    });

    test('sin conexión se explica como NetworkException', () async {
      h.adapter.failConnection();
      await expectLater(CatalogApiRepository(h.api).list(), throwsA(isA<NetworkException>()));
    });

    test('un 429 trae cuánto esperar', () async {
      h.adapter.reply(
        429,
        {'message': 'Demasiados intentos.'},
        headers: {'retry-after': ['30']},
      );
      await expectLater(
        AuthApiRepository(h.api, h.tokens).login(code: 'A', pin: '1', deviceName: 'x'),
        throwsA(isA<RateLimitedException>().having((e) => e.retryAfterSeconds, 'retry', 30)),
      );
    });

    test('un 500 es ServerException', () async {
      h.adapter.reply(500, {'message': 'Error interno'});
      await expectLater(
        CatalogApiRepository(h.api).list(),
        throwsA(isA<ServerException>().having((e) => e.statusCode, 'status', 500)),
      );
    });
  });

  group('catálogo', () {
    test('arma la consulta y lee productos, combos y paginación', () async {
      h.adapter.reply(200, catalogPage);
      final page = await CatalogApiRepository(h.api)
          .list(search: ' audí ', category: 'Audio', kind: CatalogKind.product, page: 2);

      expect(h.adapter.last.uri.path, '/api/v1/catalog');
      expect(h.adapter.last.queryParameters, {
        'search': 'audí',
        'category': 'Audio',
        'kind': 'product',
        'page': 2,
        'per_page': 30,
      });
      expect(page.items, hasLength(2));
      expect(page.hasMore, isTrue);
      expect(page.total, 124);

      final product = page.items.first;
      expect(product.minPrice.toApi(), '90.00');
      expect(product.stockLevel, StockLevel.ok);

      final combo = page.items.last;
      expect(combo.isCombo, isTrue);
      expect(combo.components, hasLength(3));
    });

    test('pide un ítem por tipo e id', () async {
      h.adapter.reply(200, {'data': (catalogPage['data'] as List).first});
      final item = await CatalogApiRepository(h.api).get(CatalogKind.product, '1');
      expect(h.adapter.last.uri.path, '/api/v1/catalog/products/1');
      expect(item.code, 'TR-0151');
    });

    test('lista las categorías', () async {
      h.adapter.reply(200, {'data': ['Audio', 'Hogar', 'Combos']});
      expect(await CatalogApiRepository(h.api).categories(), ['Audio', 'Hogar', 'Combos']);
    });
  });

  group('pedidos', () {
    test('registrar una venta manda la clave de idempotencia y el cuerpo del contrato', () async {
      h.adapter.reply(201, orderDetailResponse);
      final order = await OrdersApiRepository(h.api).create(newSale());

      expect(h.adapter.last.method, 'POST');
      expect(h.adapter.last.uri.path, '/api/v1/orders');
      expect(h.adapter.last.headers['Idempotency-Key'], 'b3f1c2d4-0000-4000-8000-000000000001');
      expect(h.adapter.last.data, {
        'lines': [
          {'kind': 'product', 'item_id': '1', 'quantity': 1, 'unit_price': '120.00'},
        ],
        'customer': {'name': 'Mariela Quispe', 'whatsapp': '71234567'},
        'payment_method': 'qr',
        'delivery': {'type': 'delivery', 'address': 'Av. Blanco Galindo km 4', 'city': null},
      });

      expect(order.number, '131');
      expect(order.status, OrderStatus.pendingPayment);
      expect(order.commission.state, CommissionState.pending);
      expect(order.breakdown.personal.toApi(), '3.20');
      expect(order.paymentProof.status, ProofStatus.uploaded);
      expect(order.lines.single.kind, CatalogKind.combo);
      expect(order.timeline.map((e) => e.isDone), [true, false, false]);
    });

    test('precio bajo el mínimo llega como ValidationException con su código', () async {
      h.adapter.reply(422, priceBelowMinimumError);
      await expectLater(
        OrdersApiRepository(h.api).create(newSale()),
        throwsA(isA<ValidationException>()
            .having((e) => e.code, 'code', 'price_below_minimum')
            .having((e) => (e.data as Map)['min_price'], 'min_price', '90.00')
            .having((e) => e.firstErrorFor('lines.0.unit_price'), 'field', isNotNull)),
      );
    });

    test('stock insuficiente llega como ConflictException con lo que queda', () async {
      h.adapter.reply(409, insufficientStockError);
      await expectLater(
        OrdersApiRepository(h.api).create(newSale()),
        throwsA(isA<ConflictException>()
            .having((e) => e.code, 'code', 'insufficient_stock')
            .having((e) => (e.data as Map)['available'], 'available', 3)),
      );
    });

    test('lista con filtro de estado y paginación', () async {
      h.adapter.reply(200, ordersPage);
      final page = await OrdersApiRepository(h.api).list(status: OrderStatus.pendingPayment, page: 1);
      expect(h.adapter.last.queryParameters, {'status': 'pending_payment', 'page': 1});
      expect(page.items.single.customerName, 'Mariela Quispe');
      expect(page.hasMore, isFalse);
    });

    test('cancelar usa POST /orders/{id}/cancel y entiende not_cancellable', () async {
      h.adapter.reply(409, notCancellableError);
      await expectLater(
        OrdersApiRepository(h.api).cancel('131'),
        throwsA(isA<ConflictException>().having((e) => e.code, 'code', 'not_cancellable')),
      );
      expect(h.adapter.last.uri.path, '/api/v1/orders/131/cancel');
    });

    test('subir comprobante manda un multipart con el campo «proof»', () async {
      final file = File('${Directory.systemTemp.path}/traigo_proof_test.jpg')
        ..writeAsBytesSync(List.filled(32, 7));
      addTearDown(() {
        try {
          file.deleteSync();
        } on FileSystemException {
          // En Windows Dio mantiene abierto el archivo hasta que lo recoge el
          // recolector de basura; es solo limpieza de un temporal.
        }
      });

      h.adapter.reply(200, orderDetailResponse);
      await OrdersApiRepository(h.api).uploadPaymentProof(
        '131',
        UploadFile(path: file.path, filename: 'comprobante.jpg'),
      );

      expect(h.adapter.last.uri.path, '/api/v1/orders/131/payment-proof');
      final form = h.adapter.last.data as FormData;
      expect(form.files.single.key, 'proof');
      expect(form.files.single.value.filename, 'comprobante.jpg');
    });
  });

  group('inicio, stock y merma', () {
    test('inicio lee comisión del día, del mes y el fondo', () async {
      h.adapter.reply(200, homeResponse);
      final home = await HomeApiRepository(h.api).load();

      expect(h.adapter.last.uri.path, '/api/v1/home');
      expect(home.today.commission.toApi(), '86.40');
      expect(home.month.estimatedTotal.toApi(), '1983.33');
      expect(home.fund.remaining.toApi(), '1140.00');
      expect(home.fund.progress, closeTo(0.772, 0.001));
      expect(home.payoutNote, isNull);
      expect(home.recentOrders, hasLength(1));
    });

    test('resumen de stock y movimientos del día', () async {
      h.adapter
        ..reply(200, stockSummaryResponse)
        ..reply(200, movementsPage);
      final repo = StockApiRepository(h.api);

      final summary = await repo.summary();
      expect(summary.lowCount, 2);
      expect(summary.attention.single.stockLevel, StockLevel.low);

      final moves = await repo.movements(day: DateTime(2026, 11, 23));
      expect(h.adapter.last.queryParameters, {'date': '2026-11-23', 'page': 1});
      expect(moves.items.single.quantityDelta, -1);
    });

    test('registrar una merma manda multipart con clave de idempotencia', () async {
      h.adapter.reply(201, wasteResponse);
      final report = await WasteApiRepository(h.api).create(const CreateWasteInput(
        clientRequestId: 'w-1',
        itemId: '3',
        quantity: 1,
        reason: WasteReason.damaged,
        note: 'Se cayó del estante',
      ));

      expect(h.adapter.last.uri.path, '/api/v1/waste');
      expect(h.adapter.last.headers['Idempotency-Key'], 'w-1');
      final form = h.adapter.last.data as FormData;
      expect(Map.fromEntries(form.fields), {
        'item_id': '3',
        'quantity': '1',
        'reason': 'damaged',
        'note': 'Se cayó del estante',
      });
      expect(report.status, WasteStatus.pending);
      expect(report.reason, WasteReason.damaged);
    });
  });
}
