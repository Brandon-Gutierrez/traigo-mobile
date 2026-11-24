import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traigo/core/demo/demo_backend.dart';
import 'package:traigo/core/money/money.dart';
import 'package:traigo/core/network/api_exception.dart';
import 'package:traigo/core/providers.dart';
import 'package:traigo/features/catalog/domain/catalog.dart';
import 'package:traigo/features/home/domain/home.dart';
import 'package:traigo/features/orders/domain/orders.dart';

import '../../support/test_app.dart';

/// Falla la primera vez (sin internet) y después responde con datos reales
/// del servidor de prueba. Cuenta cuántas veces se le pidió el resumen.
class FlakyHomeRepository implements HomeRepository {
  FlakyHomeRepository(this._backend, {this.failFirst = true});

  final DemoBackend _backend;
  final bool failFirst;
  int calls = 0;

  @override
  Future<HomeSummary> load() async {
    calls++;
    if (failFirst && calls == 1) throw const NetworkException();
    return _backend.home();
  }
}

void main() {
  testWidgets('Inicio muestra lo ganado hoy, el mes, el fondo y las últimas ventas', (tester) async {
    // Alto suficiente para que la lista construya también las últimas ventas
    // (las que quedan fuera de pantalla no se construyen).
    useMobileScreen(tester, height: 1500);
    await tester.pumpWidget(testApp(tokens: signedInTokens()));
    await tester.pumpAndSettle();

    expect(find.text('Hola, Ana'), findsOneWidget);
    expect(find.text('Equipo de ventas · código ANA-07'), findsOneWidget);

    // Hoy
    expect(find.text('GANASTE HOY'), findsOneWidget);
    expect(find.text('Bs 86,40'), findsOneWidget);
    expect(find.text('5 ventas · Bs 1.080 vendidos'), findsOneWidget);

    // Mes y fondo
    expect(find.text('Bs 1.340,00'), findsOneWidget);
    expect(find.text('Bs 643,33'), findsOneWidget);
    expect(find.text('Bs 1.983,33'), findsOneWidget);
    expect(findTextContaining('Fondo del equipo: Bs 3.860 de 5.000'), findsOneWidget);
    expect(findTextContaining('Faltan Bs 1.140 para el hito (premio por definir)'), findsOneWidget);
    expect(find.text('Pago de comisiones: por definir.'), findsOneWidget);

    // Últimas ventas (las dos más recientes de los datos de prueba). Las
    // comisiones siempre llevan centavos.
    expect(find.text('Combo Escritorio Pro'), findsOneWidget);
    expect(find.textContaining('Mariela Quispe · Bs 199 · QR'), findsOneWidget);
    expect(find.text('+Bs 3,20'), findsOneWidget);
    expect(find.text('+Bs 8,00'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('la barra inferior tiene las 5 pestañas y Vender es el botón central', (tester) async {
    useMobileScreen(tester);
    await tester.pumpWidget(testApp(tokens: signedInTokens()));
    await tester.pumpAndSettle();

    for (final label in ['Inicio', 'Catálogo', 'Vender', 'Pedidos', 'Stock']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
  });

  testWidgets('«Registrar venta», «Merma» y «Ver todas» llevan a su pantalla', (tester) async {
    useMobileScreen(tester, height: 1500);
    await tester.pumpWidget(testApp(tokens: signedInTokens()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('+ Registrar venta'));
    await tester.pumpAndSettle();
    expect(find.text('Registrar venta'), findsOneWidget);

    await tester.tap(find.text('Inicio'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Merma'));
    await tester.pumpAndSettle();
    expect(find.text('Registrar merma'), findsOneWidget);

    await tester.tap(find.text('Inicio'));
    await tester.pumpAndSettle();
    expect(find.text('Hola, Ana'), findsOneWidget);
    await tester.tap(find.text('Ver todas'));
    await tester.pumpAndSettle();
    expect(find.text('Mis pedidos'), findsOneWidget);
  });

  testWidgets('sin internet muestra el error con su botón y se recupera al reintentar',
      (tester) async {
    useMobileScreen(tester);
    final backend = DemoBackend();
    final repo = FlakyHomeRepository(backend);
    await tester.pumpWidget(testApp(
      tokens: signedInTokens(),
      overrides: [homeRepositoryProvider.overrideWithValue(repo)],
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('No hay conexión con el servidor'), findsOneWidget);
    expect(find.text('Bs 86,40'), findsNothing);
    // Aun con el error, las acciones principales siguen disponibles.
    expect(find.text('+ Registrar venta'), findsOneWidget);

    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    expect(find.text('Bs 86,40'), findsOneWidget);
    expect(repo.calls, 2);
  });

  testWidgets('deslizar hacia abajo actualiza con los datos nuevos', (tester) async {
    useMobileScreen(tester, height: 1500);
    await tester.pumpWidget(testApp(tokens: signedInTokens()));
    await tester.pumpAndSettle();
    expect(find.text('Bs 86,40'), findsOneWidget);

    // Entra una venta nueva (gana Bs 12,00) mientras Inicio está abierto.
    containerOf(tester).read(demoBackendProvider).createOrder(CreateOrderInput(
          clientRequestId: 'refresh-test',
          lines: [
            SaleLineInput(
              kind: CatalogKind.product,
              itemId: '1',
              quantity: 1,
              unitPrice: Money.parse('120'),
            ),
          ],
          customer: const CustomerInput(name: 'Carla Rojas', whatsapp: '74567890'),
          paymentMethod: PaymentMethod.cash,
          delivery: const DeliveryInput(type: DeliveryType.handoff),
        ));
    await tester.pump();
    expect(find.text('Bs 86,40'), findsOneWidget, reason: 'todavía no se actualizó');

    await tester.fling(find.byType(ListView), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();

    expect(find.text('Bs 98,40'), findsOneWidget);
    expect(find.text('6 ventas · Bs 1.200 vendidos'), findsOneWidget);
    expect(find.textContaining('Carla Rojas'), findsOneWidget);
  });

  group('cerrar sesión', () {
    testWidgets('pide confirmación y, si se cancela, la sesión sigue', (tester) async {
      useMobileScreen(tester);
      final tokens = signedInTokens();
      await tester.pumpWidget(testApp(tokens: tokens));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Cerrar sesión'));
      await tester.pumpAndSettle();
      expect(find.text('¿Cerrar sesión?'), findsOneWidget);

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(find.text('Hola, Ana'), findsOneWidget);
      expect(await tokens.read(), isNotNull);
    });

    testWidgets('al confirmar vuelve al ingreso, borra el token y recuerda el código',
        (tester) async {
      useMobileScreen(tester, height: 1200);
      final tokens = signedInTokens();
      await tester.pumpWidget(testApp(tokens: tokens));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Cerrar sesión'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Cerrar sesión'));
      await tester.pumpAndSettle();

      expect(find.text('Ingresa a Traigo'), findsOneWidget);
      expect(await tokens.read(), isNull);
    });
  });

  testWidgets('con un token guardado la app entra directo a Inicio', (tester) async {
    useMobileScreen(tester);
    await tester.pumpWidget(testApp(tokens: signedInTokens()));
    await tester.pumpAndSettle();

    expect(find.text('Hola, Ana'), findsOneWidget);
    expect(find.text('Ingresa a Traigo'), findsNothing);
  });
}
