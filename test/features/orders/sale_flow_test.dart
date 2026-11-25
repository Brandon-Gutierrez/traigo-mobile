import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traigo/core/demo/demo_backend.dart';
import 'package:traigo/core/network/api_exception.dart';
import 'package:traigo/core/providers.dart';
import 'package:traigo/core/network/paged_result.dart';
import 'package:traigo/features/orders/application/sale_draft.dart';
import 'package:traigo/features/orders/domain/orders.dart';

import '../../support/sales_helpers.dart';
import '../../support/test_app.dart';

/// Repositorio de pedidos que falla al registrar las primeras veces.
class FailingOrdersRepository implements OrdersRepository {
  FailingOrdersRepository(this.failures);

  final List<ApiException> failures;
  final DemoBackend backend = DemoBackend()..login('ALI-04', '1234');
  final List<NewSale> sent = [];

  @override
  Future<OrderDetail> create(NewSale sale) async {
    sent.add(sale);
    if (failures.isNotEmpty) throw failures.removeAt(0);
    return backend.sales.create(backend.requireMember(), sale);
  }

  @override
  Future<OrderDetail> detail(String id) async =>
      backend.sales.order(backend.requireMember(), id);

  @override
  Future<PagedResult<OrderSummary>> list({
    OrderFilter filter = OrderFilter.all,
    int page = 1,
  }) async =>
      backend.sales.orders(backend.requireMember(), filter: filter, page: page);

  @override
  Future<OrderDetail> cancel(String id, {String? reason}) => throw UnimplementedError();

  @override
  Future<OrderDetail> uploadProof(
    String id, {
    required UploadFile file,
    required String clientUuid,
    String? reference,
  }) =>
      throw UnimplementedError();
}

void main() {
  /// Agrega un producto desde «Agregar producto», buscándolo por código.
  Future<void> pickProduct(WidgetTester tester, String code, String name) async {
    await search(tester, code);
    await scrollAndTap(tester, find.text(name));
  }

  /// Escribe la cantidad de la línea [code].
  Future<void> typeQuantity(WidgetTester tester, String code, int current, int quantity) async {
    await scrollAndTap(
      tester,
      find.descendant(
        of: find.byKey(ValueKey('sale-line-$code')),
        matching: find.text('$current'),
      ),
    );
    await tester.enterText(
      find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField)),
      '$quantity',
    );
    await tester.tap(find.text('Aceptar'));
    await tester.pumpAndSettle();
  }

  /// Deja el paso 2 completo con una venta de 1 Tomatodos de Messi.
  Future<void> fillCustomer(WidgetTester tester) async {
    await tester.enterText(field('Nombre del cliente'), 'Mariela Quispe');
    await tester.enterText(field('WhatsApp'), '71234567');
    await scrollAndTap(tester, find.text('Presencial'));
  }

  testWidgets('una venta completa: precio por mayor, cliente y pedido nuevo', (tester) async {
    await openTab(tester, 'KIM-05', 'Vender', height: 1500);
    expect(find.text('Agrega lo que vas a vender desde el catálogo.'), findsOneWidget);

    await scrollAndTap(tester, find.text('Elegir productos'));
    await pickProduct(tester, '8107', 'Tomatodos de Messi');

    expect(findTextContaining('Minorista Bs 87 c/u'), findsOneWidget);
    expect(findTextContaining('Faltan 23 u. para Bs 82 c/u'), findsOneWidget);

    await typeQuantity(tester, '8107', 1, 24);
    expect(findTextContaining('Mayorista Bs 82 c/u'), findsOneWidget);
    expect(find.text('Llegó al mínimo de 24 u.'), findsOneWidget);

    await scrollAndTap(tester, find.text('+ Agregar otro producto'));
    await pickProduct(tester, 'FSYB-1109W', 'Maceta tipo cemento pequeño');
    await typeQuantity(tester, 'FSYB-1109W', 1, 10);

    expect(findTextContaining('Faltan 14 u. para Bs 25 c/u'), findsOneWidget);
    expect(find.text('Bs 1.968'), findsWidgets);
    expect(find.text('Bs 2.268'), findsOneWidget);

    await scrollAndTap(tester, findTextContaining('Continuar · Bs 2.268'));
    expect(find.text('Cliente y pago'), findsOneWidget);
    expect(find.text('Escribe el nombre del cliente'), findsOneWidget);

    await tester.enterText(field('Nombre del cliente'), 'Comercio El Hogar');
    await tester.pump();
    expect(find.text('Escribe su WhatsApp'), findsOneWidget);
    await tester.enterText(field('WhatsApp'), '71234567');
    await tester.pump();
    expect(find.text('Elige cómo llegó'), findsOneWidget);
    await scrollAndTap(tester, find.text('Mayorista'));
    await scrollAndTap(tester, find.text('Transferencia'));
    await scrollAndTap(tester, findTextContaining('Registrar venta · Bs 2.268'));

    // Abre el pedido nuevo.
    expect(find.textContaining('N-1047 · HOY'), findsOneWidget);
    expect(find.text('Venta N-1047 registrada.'), findsOneWidget);
    expect(find.text('Por pagar'), findsOneWidget);
    expect(find.text('Subir comprobante'), findsOneWidget);

    // «Vender» queda lista para la siguiente venta.
    await tapTab(tester, 'Vender');
    expect(find.text('Elegir productos'), findsOneWidget);

    // El stock quedó reservado.
    await tapTab(tester, 'Catálogo');
    await search(tester, '8107');
    expect(find.text('Disponible 21'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('el delivery pide dirección y el efectivo explica cómo se confirma',
      (tester) async {
    await openTab(tester, 'ALI-04', 'Vender', height: 1500);
    await scrollAndTap(tester, find.text('Elegir productos'));
    await pickProduct(tester, '8107', 'Tomatodos de Messi');
    await scrollAndTap(tester, findTextContaining('Continuar'));
    await fillCustomer(tester);

    await scrollAndTap(tester, find.text('Delivery'));
    expect(find.text('Escribe la dirección'), findsOneWidget);
    await tester.enterText(field('Dirección de entrega'), 'Av. Blanco Galindo km 4');
    await scrollAndTap(tester, find.text('Efectivo'));

    expect(find.text('El efectivo se confirma cuando Jime valida la caja del día.'),
        findsOneWidget);
    expect(findTextContaining('Registrar venta · Bs 87'), findsOneWidget);
  });

  testWidgets('lo escrito se conserva al ir a otra pestaña y volver', (tester) async {
    await openTab(tester, 'ALI-04', 'Vender', height: 1500);
    await scrollAndTap(tester, find.text('Elegir productos'));
    await pickProduct(tester, '8107', 'Tomatodos de Messi');
    await scrollAndTap(tester, findTextContaining('Continuar'));
    await tester.enterText(field('Nombre del cliente'), 'Valeria Paz');

    await tapTab(tester, 'Catálogo');
    await tapTab(tester, 'Vender');

    expect(find.text('Valeria Paz'), findsOneWidget);
  });

  testWidgets('quitar el único producto vuelve al comienzo', (tester) async {
    await openTab(tester, 'ALI-04', 'Vender', height: 1500);
    await scrollAndTap(tester, find.text('Elegir productos'));
    await pickProduct(tester, '8107', 'Tomatodos de Messi');

    await scrollAndTap(tester, find.byTooltip('Quitar Tomatodos de Messi'));

    expect(find.text('Elegir productos'), findsOneWidget);
  });

  testWidgets('si se corta internet, reintentar usa la misma clave', (tester) async {
    final repo = FailingOrdersRepository([const NetworkException()]);
    await openTab(
      tester,
      'ALI-04',
      'Vender',
      height: 1500,
      overrides: [ordersRepositoryProvider.overrideWithValue(repo)],
    );
    await scrollAndTap(tester, find.text('Elegir productos'));
    await pickProduct(tester, '8107', 'Tomatodos de Messi');
    await scrollAndTap(tester, findTextContaining('Continuar'));
    await fillCustomer(tester);

    await scrollAndTap(tester, findTextContaining('Registrar venta ·'));
    expect(find.textContaining('la venta no se registrará dos veces'), findsOneWidget);

    await scrollAndTap(tester, findTextContaining('Registrar venta ·'));

    expect(repo.sent.map((s) => s.clientUuid).toSet(), hasLength(1));
    expect(find.textContaining('N-1047'), findsWidgets);
  });

  testWidgets('si el precio cambió, avisa, y el siguiente envío es otra petición',
      (tester) async {
    final repo = FailingOrdersRepository([
      const ConflictException(
        code: 'price_changed',
        message: 'Los precios cambiaron. Revisa el total antes de registrar.',
      ),
    ]);
    await openTab(
      tester,
      'ALI-04',
      'Vender',
      height: 1500,
      overrides: [ordersRepositoryProvider.overrideWithValue(repo)],
    );
    await scrollAndTap(tester, find.text('Elegir productos'));
    await pickProduct(tester, '8107', 'Tomatodos de Messi');
    await scrollAndTap(tester, findTextContaining('Continuar'));
    await fillCustomer(tester);

    await scrollAndTap(tester, findTextContaining('Registrar venta ·'));

    expect(find.text('Los precios cambiaron. Revisa el total antes de registrar.'),
        findsOneWidget);
    expect(containerOf(tester).read(saleDraftProvider).lines, hasLength(1));
    expect(containerOf(tester).read(saleDraftProvider).requestKey,
        isNot(repo.sent.single.clientUuid));
  });

  testWidgets('si la venta quizá ya se registró, ofrece revisar mis pedidos',
      (tester) async {
    final repo = FailingOrdersRepository([
      const ConflictException(code: 'idempotency_conflict', message: 'x'),
    ]);
    await openTab(
      tester,
      'ALI-04',
      'Vender',
      height: 1500,
      overrides: [ordersRepositoryProvider.overrideWithValue(repo)],
    );
    await scrollAndTap(tester, find.text('Elegir productos'));
    await pickProduct(tester, '8107', 'Tomatodos de Messi');
    await scrollAndTap(tester, findTextContaining('Continuar'));
    await fillCustomer(tester);
    await scrollAndTap(tester, findTextContaining('Registrar venta ·'));

    expect(find.textContaining('Es posible que la venta ya se haya registrado'),
        findsOneWidget);
    await scrollAndTap(tester, find.text('Ver mis pedidos'));
    expect(find.text('Mis pedidos'), findsWidgets);
  });
}
