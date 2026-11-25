import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traigo/app/router.dart';
import 'package:traigo/core/providers.dart';
import 'package:traigo/features/orders/application/sale_draft.dart';
import 'package:traigo/features/orders/domain/orders.dart';

import '../../support/sales_helpers.dart';
import '../../support/test_app.dart';

/// Ninguna pantalla de la fase 2 debe desbordar en un celular de 320 de ancho
/// con la letra agrandada.
void main() {
  final screens = {
    'catálogo': AppRoutes.catalog,
    'ficha con texto largo': AppRoutes.product('p-HGTW-6C'),
    'venta, paso 1': AppRoutes.sell,
    'venta, paso 2': AppRoutes.sellCustomer,
    'agregar producto': AppRoutes.sellAdd,
    'mis pedidos': AppRoutes.orders,
    'detalle de pedido': AppRoutes.order('1046'),
  };

  for (final MapEntry(key: name, value: route) in screens.entries) {
    testWidgets('$name cabe en 320 de ancho con letra grande', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await openTab(tester, 'ALI-04', null, width: 320, height: 640);

      // Una venta con un nombre largo y delivery, para los pasos 1 y 2.
      final container = containerOf(tester);
      final draft = container.read(saleDraftProvider.notifier);
      final sales = container.read(demoBackendProvider).sales;
      draft
        ..add(sales.item('p-HGTW-7C'))
        ..add(sales.item('p-8107'))
        ..setQuantity('p-8107', 24)
        ..edit((d) => d.copyWith(deliveryType: DeliveryType.delivery));

      container.read(routerProvider).go(route);
      await tester.pumpAndSettle();
      for (var i = 0; i < 8; i++) {
        await tester.drag(find.byType(ListView).first, const Offset(0, -350));
        await tester.pumpAndSettle();
      }

      expect(tester.takeException(), isNull);
    });
  }
}
