import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traigo/app/router.dart';
import 'package:traigo/core/providers.dart';
import 'package:traigo/features/orders/application/sale_draft.dart';
import 'package:traigo/features/warehouse/application/count_draft.dart';

import '../../support/sales_helpers.dart';
import '../../support/test_app.dart';

/// Ninguna pantalla de la fase 4 debe desbordar en un celular de 320 de ancho
/// con la letra agrandada.
void main() {
  Future<void> openSmall(WidgetTester tester, String code, String route) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await openTab(tester, code, null, width: 320, height: 640, overrides: [
      clockProvider.overrideWithValue(() => DateTime(2026, 11, 24, 18)),
    ]);
    containerOf(tester).read(routerProvider).go(route);
    await tester.pumpAndSettle();
  }

  Future<void> scrollThrough(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.drag(find.byType(ListView).first, const Offset(0, -350));
      await tester.pumpAndSettle();
    }
  }

  final screens = {
    'caja de hoy': AppRoutes.cash,
    'caja observada': AppRoutes.cashDay(DateTime(2026, 12, 4)),
    'caja enviada': AppRoutes.cashDay(DateTime(2026, 12, 3)),
    'despachos': AppRoutes.dispatches,
    'stock': AppRoutes.stock,
    'conteos': AppRoutes.stockCounts,
    'stock de un producto largo': AppRoutes.stockProduct('p-HGTW-6C'),
    'conteo guardado': AppRoutes.count('ic-demo-1'),
    'agregar al conteo': AppRoutes.newCountAdd,
  };

  for (final MapEntry(key: name, value: route) in screens.entries) {
    testWidgets('$name cabe en 320 de ancho con letra grande', (tester) async {
      await openSmall(tester, 'ISA-03', route);
      await scrollThrough(tester);

      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('la caja con montos grandes y con diferencia cabe', (tester) async {
    await openSmall(tester, 'ISA-03', AppRoutes.cash);

    for (final method in ['qr', 'transfer', 'cash']) {
      final input = find.descendant(
        of: find.byKey(ValueKey('cash-$method')),
        matching: find.byType(TextField),
      );
      await scrollUntil(tester, input);
      await tester.enterText(input, '999.999,99');
      await tester.pumpAndSettle();
    }
    await scrollThrough(tester);

    expect(tester.takeException(), isNull);
  });

  testWidgets('un conteo nuevo con productos largos y su aviso de ajuste caben',
      (tester) async {
    await openSmall(tester, 'ISA-03', AppRoutes.home);
    final container = containerOf(tester);
    final sales = container.read(demoBackendProvider).sales;
    container.read(countDraftProvider.notifier)
      ..add(sales.item('p-HGTW-6C'))
      ..add(sales.item('p-8866'))
      ..setCounted('p-8866', 99999);
    container.read(routerProvider).go(AppRoutes.newCount);
    await tester.pumpAndSettle();
    await scrollThrough(tester);
    expect(tester.takeException(), isNull);

    container.read(routerProvider).go(AppRoutes.count('ic-demo-1'));
    await tester.pumpAndSettle();
    await scrollUntil(tester, find.text('Ajustar −2'));
    await tester.tap(find.text('Ajustar −2'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('el paso 2 con otro día elegido y los selectores caben', (tester) async {
    await openSmall(tester, 'ALI-04', AppRoutes.home);
    final container = containerOf(tester);
    final sales = container.read(demoBackendProvider).sales;
    container.read(saleDraftProvider.notifier)
      ..add(sales.item('p-8107'))
      ..edit((d) => d.copyWith(
            deliveryDate: DateTime(2026, 12, 28),
            deliveryTime: const TimeOfDay(hour: 23, minute: 59),
          ));
    container.read(routerProvider).go(AppRoutes.sellCustomer);
    await tester.pumpAndSettle();
    await scrollUntil(tester, find.text('28/12'));
    await tester.tap(find.text('28/12'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    await scrollUntil(tester, find.text('23:59'));
    await tester.tap(find.text('23:59'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    await scrollThrough(tester);

    expect(tester.takeException(), isNull);
  });
}
