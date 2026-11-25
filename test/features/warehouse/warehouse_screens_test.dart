import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traigo/app/router.dart';
import 'package:traigo/core/providers.dart';
import 'package:traigo/features/catalog/presentation/catalog_browser.dart';

import '../../support/sales_helpers.dart';
import '../../support/team_helpers.dart';
import '../../support/test_app.dart';

void main() {
  /// Isaí entra a las 18:00 del día de la demo.
  Future<void> open(WidgetTester tester, {String? tab}) => openTab(
        tester,
        'ISA-03',
        tab,
        height: 2400,
        overrides: [clockProvider.overrideWithValue(() => DateTime(2026, 11, 24, 18))],
      );

  Finder inDispatch(String id, String text) => find.descendant(
        of: find.byKey(ValueKey('dispatch-$id')),
        matching: find.text(text),
      );

  Finder cashField(String method) => find.descendant(
        of: find.byKey(ValueKey('cash-$method')),
        matching: find.byType(TextField),
      );

  Future<void> type(WidgetTester tester, Finder finder, String text) async {
    await tester.enterText(finder, text);
    await tester.pumpAndSettle();
  }

  testWidgets('despachos: atrasados marcados, listo y entregado', (tester) async {
    await open(tester);
    expect(find.text('4 por entregar · 2 atrasados'), findsOneWidget);
    await scrollAndTap(tester, find.text('Despachos'));

    expect(find.text('POR PREPARAR (3)'), findsOneWidget);
    expect(find.text('LISTOS PARA ENTREGAR (1)'), findsOneWidget);
    expect(find.text('Atrasado'), findsNWidgets(2));
    expect(inDispatch('1043', 'Acordado: Hoy 12:00'), findsOneWidget);
    expect(inDispatch('1042', 'Acordado: Mañana 10:00'), findsOneWidget);
    expect(inDispatch('1041', 'Sin hora acordada'), findsOneWidget);

    await scrollAndTap(tester, inDispatch('1045', 'Marcar listo'));
    expect(find.text('N-1045 listo para entregar.'), findsOneWidget);
    expect(find.text('LISTOS PARA ENTREGAR (2)'), findsOneWidget);

    await scrollAndTap(tester, inDispatch('1043', 'Marcar entregado'));
    await tester.tap(find.text('Todavía no'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('dispatch-1043')), findsOneWidget);

    await scrollAndTap(tester, inDispatch('1043', 'Marcar entregado'));
    await tester.tap(find.text('Sí, entregado'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('dispatch-1043')), findsNothing);
    expect(find.text('3 por entregar · 1 atrasado'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('caja de hoy: lo recibido, la diferencia explicada y el envío',
      (tester) async {
    await open(tester, tab: 'Caja');

    expect(find.text('DOMINGO 6 DIC · TODO EL EQUIPO'), findsOneWidget);
    expect(find.text('Bs 3.415'), findsOneWidget);
    expect(find.text('5 pedidos cobrados · 1 por cobrar'), findsOneWidget);
    expect(find.text('2 DÍAS POR CERRAR'), findsOneWidget);
    expect(find.text('N-1044 · KIM'), findsOneWidget);
    expect(find.text('Falta lo recibido'), findsOneWidget);

    await type(tester, cashField('qr'), '563');
    await type(tester, cashField('transfer'), '2.016');
    await type(tester, cashField('cash'), '800');
    expect(find.text('Cuadra'), findsNWidgets(2));
    expect(find.text('Diferencia'), findsOneWidget);
    expect(find.text('−Bs 36'), findsOneWidget);
    expect(find.text('Explica la diferencia'), findsOneWidget);

    await type(tester, field('Explica la diferencia'), 'Falta cambio de una venta.');
    await scrollAndTap(tester, find.text('Enviar cierre a Jime'));
    expect(find.text('¿Enviar el cierre del domingo 6 dic?'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Enviar'));
    await tester.pumpAndSettle();

    expect(find.text('Cierre enviado a Jime.'), findsOneWidget);
    expect(find.text('Enviado a Jime'), findsOneWidget);
    expect(find.text('Explicación: Falta cambio de una venta.'), findsOneWidget);
    expect(find.text('Enviar cierre a Jime'), findsNothing);
  });

  testWidgets('un día observado se corrige y vuelve a la caja de hoy', (tester) async {
    await open(tester, tab: 'Caja');
    await scrollAndTap(tester, find.text('Viernes 4 dic'));

    expect(find.text('VIERNES 4 DIC · TODO EL EQUIPO'), findsOneWidget);
    expect(find.textContaining('Jime pidió corregir:'), findsOneWidget);
    expect(find.text('Faltan Bs 50 de cambio.'), findsOneWidget, reason: 'la nota anterior');
    expect(
      tester.widget<TextField>(cashField('cash')).controller!.text,
      '840',
    );
    await type(tester, cashField('cash'), '890');
    await scrollAndTap(tester, find.text('Enviar cierre a Jime'));
    await tester.tap(find.widgetWithText(TextButton, 'Enviar'));
    await tester.pumpAndSettle();

    expect(find.text('DOMINGO 6 DIC · TODO EL EQUIPO'), findsOneWidget);
    expect(find.text('1 DÍA POR CERRAR'), findsOneWidget);
    expect(find.text('Viernes 4 dic'), findsNothing);
  });

  testWidgets('stock: un ingreso se confirma y actualiza las cifras', (tester) async {
    await open(tester);
    await scrollAndTap(tester, find.text('Stock y conteos'));
    await search(tester, '8109');
    expect(find.text('En bodega 60 · reservado 24'), findsOneWidget);
    await scrollAndTap(tester, find.text('Tomatodos de Ronaldo'));

    expect(find.text('Escribe la cantidad'), findsOneWidget);
    await scrollAndTap(tester, find.text('Falta'));
    await type(tester, field('Cantidad'), '40');
    expect(find.text('Solo puedes quitar 36'), findsOneWidget);

    await scrollAndTap(tester, find.text('Ingreso'));
    await type(tester, field('Cantidad'), '12');
    await scrollAndTap(tester, find.text('Registrar'));
    expect(find.textContaining('En bodega quedarán 72.'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Registrar'));
    await tester.pumpAndSettle();

    expect(find.text('Stock actualizado: 72 en bodega.'), findsOneWidget);
    expect(find.text('72 u.'), findsOneWidget);
  });

  testWidgets('un conteo con diferencia se corrige con su motivo', (tester) async {
    await open(tester);
    await scrollAndTap(tester, find.text('Stock y conteos'));
    await scrollAndTap(tester, find.text('Conteos'));

    expect(find.text('Viernes 4 dic'), findsOneWidget);
    expect(find.text('2 productos · 1 con diferencia'), findsOneWidget);
    expect(find.text('1 por ajustar'), findsOneWidget);
    await scrollAndTap(tester, find.text('Viernes 4 dic'));

    await scrollAndTap(tester, find.text('Ajustar −2'));
    final confirm = find.widgetWithText(TextButton, 'Ajustar');
    expect(tester.widget<TextButton>(confirm).onPressed, isNull, reason: 'falta el motivo');
    await type(tester, field('Motivo del ajuste'), 'Dos rotos en el estante.');
    await tester.tap(confirm);
    await tester.pumpAndSettle();

    expect(find.text('Stock corregido: 58 en bodega.'), findsOneWidget);
    expect(find.text('Diferencia −2 · ajustada'), findsOneWidget);
    expect(find.text('Ajustar −2'), findsNothing);
  });

  testWidgets('el conteo nuevo no muestra lo que dice el sistema hasta guardar',
      (tester) async {
    await open(tester);
    await scrollAndTap(tester, find.text('Stock y conteos'));
    await scrollAndTap(tester, find.text('Conteos'));
    await scrollAndTap(tester, find.text('Nuevo conteo'));
    expect(find.text('Agrega productos'), findsOneWidget);

    await scrollAndTap(tester, find.text('+ Agregar producto'));
    await search(tester, '8866');
    expect(find.byType(CatalogBrowser), findsOneWidget);
    expect(find.textContaining('Disponible'), findsNothing);
    expect(find.textContaining('En bodega'), findsNothing);
    await scrollAndTap(tester, find.text('Tomatodos Keep Going Haily 4 colores'));

    expect(find.text('Falta contar 1'), findsOneWidget);
    await type(
      tester,
      find.descendant(
        of: find.byKey(const ValueKey('count-field-p-8866')),
        matching: find.byType(TextField),
      ),
      '20',
    );
    await scrollAndTap(tester, find.text('Guardar conteo'));

    expect(find.text('Conteo guardado.'), findsOneWidget);
    expect(find.text('24 u.'), findsOneWidget);
    expect(find.text('Diferencia −4'), findsOneWidget);

    await tester.tap(backTo('Conteos'));
    await tester.pumpAndSettle();
    await scrollAndTap(tester, find.text('Nuevo conteo'));
    expect(find.text('Agrega productos'), findsOneWidget, reason: 'empieza vacío');
  });

  testWidgets('quien no es de almacén no entra a caja, despachos ni stock',
      (tester) async {
    await openTab(tester, 'ALI-04', null);
    final router = containerOf(tester).read(routerProvider);

    for (final route in [
      AppRoutes.cash,
      AppRoutes.cashDay(DateTime(2026, 12, 4)),
      AppRoutes.dispatches,
      AppRoutes.stock,
      AppRoutes.newCount,
    ]) {
      router.go(route);
      await tester.pumpAndSettle();
      expect(router.routerDelegate.currentConfiguration.uri.path, AppRoutes.home,
          reason: route);
    }
  });
}
