import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traigo/app/router.dart';
import 'package:traigo/core/demo/demo_backend.dart';
import 'package:traigo/core/providers.dart';
import 'package:traigo/features/control/domain/admin.dart';
import 'package:traigo/features/control/domain/review.dart';

import '../../support/panel_helpers.dart';
import '../../support/sales_helpers.dart';
import '../../support/test_app.dart';

/// Ninguna pantalla de la fase 5 debe desbordar en un celular de 320 de ancho
/// con la letra agrandada.
void main() {
  Future<DemoBackend> openSmall(
    WidgetTester tester,
    String code,
    String Function(DemoBackend backend) route,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await openTab(tester, code, null, width: 320, height: 640, overrides: [
      clockProvider.overrideWithValue(() => DateTime(2026, 11, 24, 18)),
    ]);
    final backend = containerOf(tester).read(demoBackendProvider);
    containerOf(tester).read(routerProvider).go(route(backend));
    await tester.pumpAndSettle();
    // Se abrió de verdad: no lo devolvió al Resumen ni falló al cargar.
    expect(find.textContaining('Hola,'), findsNothing);
    expect(find.text('Reintentar'), findsNothing);
    return backend;
  }

  Future<void> scrollThrough(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.drag(find.byType(ListView).first, const Offset(0, -350));
      await tester.pumpAndSettle();
    }
  }

  String evidence(DemoBackend backend) => AppRoutes.pendingEvidence(
      backend.control.pending(type: PendingType.evidence).first.id);

  final control = <String, String Function(DemoBackend)>{
    'pendientes': (_) => AppRoutes.pending,
    'revisar un pago': (_) => AppRoutes.pendingPayment('1046'),
    'revisar una evidencia': evidence,
    'revisar la caja': (_) => AppRoutes.pendingCash('cc-demo-5'),
    'revisar una entrega': (_) => AppRoutes.pendingDeliverable('d-2'),
    'las entregas': (_) => AppRoutes.moreDeliverables,
    'cumplimiento': (_) => AppRoutes.compliance,
    'los indicadores de Sistemas 1': (_) => AppRoutes.complianceMember('6'),
    'el cierre semanal': (_) => AppRoutes.close,
    'los bonos': (_) => AppRoutes.bonuses,
    'las comisiones': (_) => AppRoutes.moreCommissions,
    '«Más»': (_) => AppRoutes.more,
    'la lista de precios': (_) => AppRoutes.morePrices,
    'el precio de un producto largo': (_) => AppRoutes.morePrice('p-HGTW-6C'),
    'un precio esperando a Dirección': (_) => AppRoutes.morePrice('p-8924'),
    'los pedidos': (_) => AppRoutes.moreOrders,
    'un pedido para devolver': (_) => AppRoutes.moreOrder('1043'),
    'un pedido duplicable': (_) => AppRoutes.moreOrder('1036'),
    'los conteos': (_) => AppRoutes.moreCounts,
    'un conteo de solo lectura': (_) => AppRoutes.moreCount('ic-demo-1'),
    'la auditoría': (_) => AppRoutes.moreAudit,
    'los accesos': (_) => AppRoutes.moreAccess,
  };

  for (final MapEntry(key: name, value: route) in control.entries) {
    testWidgets('Jime: $name cabe en 320 de ancho con letra grande', (tester) async {
      await openSmall(tester, 'JIM-01', route);
      await scrollThrough(tester);

      expect(tester.takeException(), isNull);
    });
  }

  final management = <String, String>{
    'por autorizar': AppRoutes.approve,
    'un cambio de precio': AppRoutes.authorization('price_change', 'pc-1'),
    'el precio esperando': AppRoutes.morePrice('p-8924'),
    'un precio vigente': AppRoutes.morePrice('p-HGTW-6C'),
    '«Más»': AppRoutes.more,
    'las comisiones': AppRoutes.commissions,
  };

  for (final MapEntry(key: name, value: route) in management.entries) {
    testWidgets('Dirección: $name cabe en 320 de ancho', (tester) async {
      await openSmall(tester, 'DIR-08', (_) => route);
      await scrollThrough(tester);

      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('el cierre con los cierres a mano abiertos cabe', (tester) async {
    final backend = await openSmall(tester, 'JIM-01', (_) => AppRoutes.compliance);
    reviewEverything(backend);
    containerOf(tester).read(routerProvider).go(AppRoutes.close);
    await tester.pumpAndSettle();

    final close = find.bySemanticsLabel('Cerrar a Sistemas 1 como no cumple');
    await scrollUntil(tester, close);
    await tester.tap(close);
    await tester.pumpAndSettle();
    await scrollThrough(tester);

    expect(tester.takeException(), isNull);
  });

  testWidgets('la autorización del bono y el bono por pagar caben', (tester) async {
    final backend = await openSmall(tester, 'DIR-08', (_) => AppRoutes.approve);
    sendWeek(backend);
    containerOf(tester)
        .read(routerProvider)
        .go(AppRoutes.authorization('weekly_bonus', '1'));
    await tester.pumpAndSettle();
    await scrollThrough(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('el formulario de precio con montos enormes cabe', (tester) async {
    await openSmall(tester, 'JIM-01', (_) => AppRoutes.morePrice('p-8107'));

    for (final label in ['Minorista (Bs)', 'Mayorista (Bs)', 'Costo (Bs)']) {
      await scrollUntil(tester, field(label));
      await tester.enterText(field(label), '999999,99');
      await tester.pumpAndSettle();
    }
    await scrollThrough(tester);

    expect(tester.takeException(), isNull);
  });

  testWidgets('un cambio de precio con todos los valores cabe', (tester) async {
    final backend = await openSmall(tester, 'JIM-01', (_) => AppRoutes.more);
    backend.control.proposePrice(
      'p-HGTW-6C',
      const PriceValues(commissionPct: 12.5, wholesaleMinQty: 100000),
      reason: 'Un motivo bastante largo para ver que el texto se acomoda bien.',
    );
    containerOf(tester).read(routerProvider).go(AppRoutes.morePrice('p-HGTW-6C'));
    await tester.pumpAndSettle();
    await scrollThrough(tester);

    expect(tester.takeException(), isNull);
  });

  testWidgets('las ventanas de motivo, PIN y duplicado caben', (tester) async {
    await openSmall(tester, 'JIM-01', (_) => AppRoutes.moreOrder('1036'));

    await scrollUntil(tester, find.text('Es un duplicado'));
    await tester.tap(find.text('Es un duplicado'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tapAt(const Offset(160, 20));
    await tester.pumpAndSettle();

    containerOf(tester).read(routerProvider).go(AppRoutes.moreOrder('1043'));
    await tester.pumpAndSettle();
    await scrollUntil(tester, find.text('Registrar devolución'));
    await tester.tap(find.text('Registrar devolución'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Volver'));
    await tester.pumpAndSettle();

    containerOf(tester).read(routerProvider).go(AppRoutes.moreAccess);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nuevo PIN').first);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
