import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traigo/app/role_navigation.dart';
import 'package:traigo/app/router.dart';
import 'package:traigo/core/demo/demo_backend.dart';
import 'package:traigo/core/demo/demo_panel_repositories.dart';
import 'package:traigo/core/providers.dart';
import 'package:traigo/core/share/report_sharer.dart';
import 'package:traigo/features/auth/domain/auth.dart';
import 'package:traigo/features/control/application/control_providers.dart';
import 'package:traigo/features/control/domain/admin.dart';
import 'package:traigo/features/control/presentation/panel_widgets.dart';

import '../../support/panel_helpers.dart';
import '../../support/sales_helpers.dart';
import '../../support/test_app.dart';
import '../../support/team_helpers.dart';

/// La casilla del diseño con la etiqueta [label].
Finder check(String label) => find.byWidgetPredicate(
      (w) => w is SquareCheck && w.label.replaceAll(String.fromCharCode(0xA0), ' ') == label,
    );

/// El botón [label] de la ventana abierta.
Finder inDialog(String label) =>
    find.descendant(of: find.byType(AlertDialog), matching: find.text(label));

DemoBackend backendOf(WidgetTester tester) =>
    containerOf(tester).read(demoBackendProvider);

/// Vuelve a leer el panel después de cambiar datos por fuera de la pantalla.
Future<void> reload(WidgetTester tester) async {
  refreshPanelData(containerOf(tester));
  await tester.pumpAndSettle();
}

Future<void> goTo(WidgetTester tester, String route) async {
  containerOf(tester).read(routerProvider).go(route);
  await tester.pumpAndSettle();
}

/// Abre «Más» y la fila [row].
Future<void> openMore(WidgetTester tester, String code, String row) async {
  await openTab(tester, code, 'Más', height: 1300);
  await scrollAndTap(tester, find.text(row));
}

class FakeSharer implements ReportSharer {
  final List<(String, List<int>)> shared = [];

  @override
  Future<void> share(String filename, List<int> bytes) async =>
      shared.add((filename, bytes));
}

/// La demo, pero con Excel: anota lo que se pide.
class ReportsRepository extends DemoAdminRepository {
  ReportsRepository(DemoBackend backend) : super(backend, Duration.zero);

  final List<(ReportType, String)> requested = [];

  @override
  Future<List<int>> downloadReport(ReportType type, {required String period}) async {
    requested.add((type, period));
    return [80, 75, 3, 4];
  }
}

void main() {
  group('bandeja y validaciones', () {
    testWidgets('Jime concilia un comprobante', (tester) async {
      await openTab(tester, 'JIM-01', 'Pendientes', height: 1200);
      expect(find.text('7 por revisar · primero los más antiguos'), findsOneWidget);

      await scrollAndTap(tester, find.text('Mariela Quispe · Alison'));
      expect(find.text('0045-9001'), findsOneWidget);
      expect(find.text('No se repite'), findsOneWidget);
      expect(find.text('Marca el monto y la cuenta'), findsOneWidget);

      await scrollAndTap(tester, check('El monto es Bs 174'));
      await scrollAndTap(tester, check('Llegó a la cuenta de Traigo'));
      await scrollAndTap(tester, find.text('Confirmar pago'));

      expect(find.text('Pago de N-1046 confirmado.'), findsOneWidget);
      expect(find.text('6 por revisar · primero los más antiguos'), findsOneWidget);
    });

    testWidgets('rechazar un comprobante pide el motivo', (tester) async {
      await openTab(tester, 'JIM-01', 'Pendientes', height: 1200);
      await scrollAndTap(tester, find.text('Jorge Peña · Tienda web'));

      await scrollAndTap(tester, find.text('Rechazar comprobante…'));
      await tester.tap(inDialog('Rechazar'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget, reason: 'sin motivo no se cierra');

      await tester.enterText(field('Motivo'), 'No se ve el monto');
      await tester.pump();
      await tester.tap(inDialog('Rechazar'));
      await tester.pumpAndSettle();

      expect(find.text('Comprobante rechazado.'), findsOneWidget);
      expect(find.text('Jorge Peña · Tienda web'), findsNothing);
    });

    testWidgets('carga el valor real de una evidencia', (tester) async {
      await openTab(tester, 'JIM-01', 'Pendientes', height: 1300);
      await scrollAndTap(tester, find.textContaining('Alison · Registro'));

      expect(find.text('Revisar evidencia'), findsOneWidget);
      String? value() =>
          tester.widget<Text>(find.byKey(const ValueKey('actual-value'))).data;
      expect(value(), '1', reason: 'lo que ya estaba cargado');
      await scrollAndTap(tester, find.byTooltip('Bajar valor real'));
      expect(value(), '0');
      await scrollAndTap(tester, find.byTooltip('Subir valor real'));
      expect(value(), '1');
      await scrollAndTap(tester, find.text('Validar y guardar'));

      expect(find.text('6 por revisar · primero los más antiguos'), findsOneWidget);
    });

    testWidgets('valida la caja del sábado', (tester) async {
      await openTab(tester, 'JIM-01', 'Pendientes', height: 1200);
      await scrollAndTap(tester, find.text('Isaí · cierre del sábado 5 dic'));

      await scrollAndTap(tester, find.text('Validar cierre'));
      await tester.tap(inDialog('Validar'));
      await tester.pumpAndSettle();

      expect(find.text('Cierre validado.'), findsOneWidget);
      expect(find.text('6 por revisar · primero los más antiguos'), findsOneWidget);
    });

    testWidgets('valida una entrega de Sistemas con su fecha real', (tester) async {
      await openTab(tester, 'JIM-01', 'Pendientes', height: 1300);
      await scrollAndTap(
          tester, find.text('Compra en línea probada de principio a fin'));

      expect(find.text('Quedará a tiempo.'), findsOneWidget);
      await scrollAndTap(tester, find.text('Validar'));

      expect(find.text('Entrega validada.'), findsOneWidget);
      expect(find.text('Entregas de Sistemas'), findsOneWidget);
    });

    testWidgets('desde Cumplimiento se llega al indicador de cada persona',
        (tester) async {
      await openTab(tester, 'JIM-01', null, height: 1500);
      await scrollAndTap(tester, find.text('Ver cumplimiento'));
      await scrollAndTap(tester, find.text('Kim'));

      expect(find.text('INDICADORES'), findsOneWidget);
      final first = backendOf(tester).team.weekOf('5').indicators.first.indicator;
      await scrollAndTap(tester, find.text(first.name));

      expect(find.text('Revisar evidencia'), findsOneWidget);
      await tester.tap(backTo('Indicadores'));
      await tester.pumpAndSettle();
      expect(find.text('INDICADORES'), findsOneWidget);
    });
  });

  group('cierre semanal y bono', () {
    testWidgets('Jime resuelve lo que falta y envía el cierre', (tester) async {
      await openTab(tester, 'JIM-01', 'Cierre', height: 1500);
      expect(find.text('Faltan cobros por confirmar'), findsOneWidget);

      reviewEverything(backendOf(tester));
      await reload(tester);
      expect(find.text('Confirma los duplicados'), findsOneWidget);

      await scrollAndTap(tester, check('Duplicados depurados'));
      expect(find.text('Resuelve a Sistemas 1'), findsOneWidget);
      await scrollAndTap(tester, check('Cerrar a Sistemas 1 como no cumple'));
      expect(find.text('Falta un motivo'), findsOneWidget);
      await tester.ensureVisible(field('Motivo para Sistemas 1'));
      await tester.enterText(field('Motivo para Sistemas 1'), pendingReason['6']!);
      await tester.pump();

      await scrollAndTap(tester, find.text('Enviar a Dirección'));
      expect(find.textContaining('Sistemas 1 quedará como «no cumple»'), findsOneWidget);
      await tester.tap(inDialog('Enviar'));
      await tester.pumpAndSettle();

      expect(find.text('Cierre enviado a Dirección.'), findsOneWidget);
      expect(find.text('Enviado a Dirección'), findsOneWidget);
      expect(find.text('Observaciones (opcional)'.toUpperCase()), findsNothing);
    });

    testWidgets('quien deja de estar pendiente ya no se cierra a mano',
        (tester) async {
      await openTab(tester, 'JIM-01', 'Cierre', height: 1500);
      final backend = backendOf(tester);
      reviewEverything(backend);
      await reload(tester);
      await scrollAndTap(tester, check('Duplicados depurados'));
      await scrollAndTap(tester, check('Cerrar a Sistemas 1 como no cumple'));
      await tester.ensureVisible(field('Motivo para Sistemas 1'));
      await tester.enterText(field('Motivo para Sistemas 1'), pendingReason['6']!);
      await tester.pump();

      // Mientras tanto, Sistemas 1 completa sus entregas y Jime las revisa.
      final sis1 = DemoBackend.members.firstWhere((m) => m.id == '6');
      backend.team.submitDeliverable(
        sis1,
        'd-3',
        deliveredOn: DateTime(2026, 11, 30),
        clientUuid: 'e-3',
        url: 'https://example.com/entrega-3',
      );
      for (final id in ['d-2', 'd-3']) {
        backend.control.validateDeliverable(id, DateTime(2026, 12, 2));
      }
      await reload(tester);
      expect(find.text('SIGUEN PENDIENTES'), findsNothing);

      await scrollAndTap(tester, find.text('Enviar a Dirección'));
      await tester.tap(inDialog('Enviar'));
      await tester.pumpAndSettle();

      expect(find.text('Cierre enviado a Dirección.'), findsOneWidget);
    });

    testWidgets('en enero se abre diciembre, que es el que se liquida',
        (tester) async {
      await openTab(tester, 'JIM-01', 'Más', height: 1300, overrides: [
        todayProvider.overrideWithValue(() => DateTime(2027, 1, 5)),
      ]);
      await scrollAndTap(tester, find.text('Comisiones'));

      expect(find.text('DICIEMBRE · MES TERMINADO'), findsOneWidget);
      expect(find.text('Falta definir el %'), findsOneWidget);

      await scrollAndTap(tester, find.text('Enero'));
      expect(find.text('ENERO · EN CURSO'), findsOneWidget);
      await scrollAndTap(tester, find.text('Diciembre'));
      expect(find.text('DICIEMBRE · MES TERMINADO'), findsOneWidget);
    });

    testWidgets('Dirección autoriza el bono', (tester) async {
      await openTab(tester, 'DIR-08', null, height: 1300);
      sendWeek(backendOf(tester));
      await tapTab(tester, 'Autorizar');

      await scrollAndTap(tester, find.text('Bono semana 1–6 dic'));
      expect(find.text('Bs 1.050'), findsOneWidget);
      expect(find.textContaining('Cerrado por Jime'), findsOneWidget);
      await scrollAndTap(tester, find.text('Autorizar pago'));
      await tester.tap(inDialog('Autorizar'));
      await tester.pumpAndSettle();

      expect(find.text('Autorizado.'), findsOneWidget);
      expect(find.text('Bono semana 1–6 dic'), findsNothing);
    });

    testWidgets('con la autorización, Jime marca cada pago', (tester) async {
      await openTab(tester, 'JIM-01', null, height: 1500);
      final backend = backendOf(tester);
      sendWeek(backend);
      final item = backend.control.authorizations().first;
      backend.control.approve(item.type, item.id);
      await tapTab(tester, 'Bonos');
      await reload(tester);

      final ailen = find.descendant(
        of: find.byKey(const ValueKey('bonus-2')),
        matching: find.text('Marcar pagado'),
      );
      await scrollAndTap(tester, ailen);
      await tester.tap(inDialog('Marcar pagado'));
      await tester.pumpAndSettle();

      expect(find.text('Pago de Ailén registrado.'), findsOneWidget);
      expect(ailen, findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('bonus-2')),
          matching: find.textContaining('Pagado'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('las comisiones se envían recién al terminar el mes', (tester) async {
      await openMore(tester, 'JIM-01', 'Comisiones');

      expect(find.text('Se envía desde el 1 ene'), findsOneWidget);
      expect(find.text('Noviembre'), findsNothing,
          reason: 'sin ventas no se muestra el mes anterior');
      expect(find.byKey(const ValueKey('commission-4')), findsOneWidget);
      expect(find.text('Falta definir el %'), findsNothing);
    });
  });

  group('precios', () {
    testWidgets('Jime propone la comisión de un producto', (tester) async {
      await openMore(tester, 'JIM-01', 'Precios autorizados');
      await search(tester, '8107');
      await scrollAndTap(tester, find.text('Tomatodos de Messi'));

      expect(find.text('No hay cambios'), findsOneWidget);
      await tester.ensureVisible(field('Comisión (%)'));
      await tester.enterText(field('Comisión (%)'), '5');
      await tester.pump();
      await scrollAndTap(tester, find.text('Enviar a Dirección'));

      expect(find.text('Enviado a Dirección.'), findsOneWidget);
      expect(find.text('ESPERANDO A DIRECCIÓN'), findsOneWidget);
      expect(find.text('Por definir → 5 %'), findsOneWidget);
    });

    testWidgets('el mayorista por encima del minorista no se envía', (tester) async {
      await openMore(tester, 'JIM-01', 'Precios autorizados');
      await search(tester, '8107');
      await scrollAndTap(tester, find.text('Tomatodos de Messi'));

      await tester.enterText(field('Mayorista (Bs)'), '99');
      await tester.pump();

      expect(find.text('El mayorista no supera al minorista'), findsOneWidget);
    });

    testWidgets('Dirección ve el cambio en «Más» y lo aprueba', (tester) async {
      await openMore(tester, 'DIR-08', 'Precios autorizados');
      final pending = backendOf(tester).control.priceSheet('p-8924');
      await search(tester, pending.itemCode);
      await scrollAndTap(tester, find.text(pending.name));

      expect(find.byType(TextField), findsNothing, reason: 'Dirección no edita');
      await scrollAndTap(tester, find.text('Revisar y autorizar'));
      await scrollAndTap(tester, find.text('Aprobar el cambio'));
      await tester.tap(inDialog('Autorizar'));
      await tester.pumpAndSettle();

      expect(find.text('Autorizado.'), findsOneWidget);
      expect(find.text('No hay nada esperando tu autorización.'), findsOneWidget);
    });
  });

  group('pedidos', () {
    Future<void> openOrder(WidgetTester tester, String text, String customer) async {
      await openMore(tester, 'JIM-01', 'Pedidos');
      await search(tester, text);
      await scrollAndTap(tester, find.text(customer));
    }

    testWidgets('registra una devolución', (tester) async {
      await openOrder(tester, 'rosa', 'Rosa Mamani');

      await scrollAndTap(tester, find.text('Registrar devolución'));
      expect(find.textContaining('Los productos vuelven al stock'), findsOneWidget);
      await tester.enterText(field('Motivo'), 'Llegó golpeado');
      await tester.pump();
      await tester.tap(inDialog('Registrar devolución'));
      await tester.pumpAndSettle();

      expect(find.text('Devolución registrada.'), findsOneWidget);
      expect(find.text('Devuelto'), findsOneWidget);
      expect(find.text('Motivo: Llegó golpeado'), findsOneWidget);
    });

    testWidgets('anula un duplicado eligiendo el original', (tester) async {
      await openOrder(tester, '1036', 'Jorge Peña');

      await scrollAndTap(tester, find.text('Es un duplicado'));
      expect(find.text('¿Cuál es el original?'), findsOneWidget);
      expect(find.text('No hay otro pedido con esa búsqueda.'), findsOneWidget);
      await tester.enterText(field('Buscar el original'), '1037');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Luisa Vargas'));
      await tester.pumpAndSettle();
      await tester.tap(inDialog('Anular'));
      await tester.pumpAndSettle();

      expect(find.text('N-1036 anulado como duplicado.'), findsOneWidget);
      expect(find.text('Anulado porque duplica el pedido N-1037.'), findsOneWidget);
      expect(find.text('Es un duplicado'), findsNothing);
    });
  });

  group('auditoría, accesos y conteos', () {
    testWidgets('en la demo, el Excel avisa que lo arma el backend', (tester) async {
      await openMore(tester, 'JIM-01', 'Auditoría y reportes');
      expect(find.text('Los registros no se pueden editar ni borrar.'), findsOneWidget);

      await scrollAndTap(tester, find.text('Caja de un día'));
      await tester.tap(find.text('ACEPTAR'));
      await tester.pumpAndSettle();

      expect(
        find.text('En la demo no se genera el Excel: lo arma el backend.'),
        findsOneWidget,
      );
    });

    testWidgets('con el backend, el Excel se comparte con su nombre', (tester) async {
      final sharer = FakeSharer();
      ReportsRepository? reports;
      await openTab(tester, 'JIM-01', 'Más', height: 1300, overrides: [
        reportSharerProvider.overrideWithValue(sharer),
        adminRepositoryProvider.overrideWith(
          (ref) => reports ??= ReportsRepository(ref.watch(demoBackendProvider)),
        ),
      ]);
      await scrollAndTap(tester, find.text('Auditoría y reportes'));

      await scrollAndTap(tester, find.text('Semana 1–6 dic'));
      await scrollAndTap(tester, find.text('Comisiones de diciembre'));

      expect(reports!.requested, [
        (ReportType.week, '1'),
        (ReportType.commissions, '2026-12'),
      ]);
      expect(sharer.shared.map((s) => s.$1),
          ['traigo-semana-1.xlsx', 'traigo-comisiones-2026-12.xlsx']);
    });

    testWidgets('Jime pone un PIN nuevo, escrito dos veces', (tester) async {
      await openMore(tester, 'JIM-01', 'Accesos del equipo');
      expect(find.textContaining('JIM-01'), findsNothing);

      await scrollAndTap(
        tester,
        find.descendant(
          of: find.byKey(const ValueKey('account-4')),
          matching: find.text('Nuevo PIN'),
        ),
      );
      await tester.enterText(find.byKey(const ValueKey('field-PIN nuevo (4 dígitos)')), '4821');
      await tester.enterText(find.byKey(const ValueKey('field-Repite el PIN')), '4822');
      await tester.pump();
      expect(find.text('No coinciden.'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('field-Repite el PIN')), '4821');
      await tester.pump();
      await tester.tap(inDialog('Cambiar PIN'));
      await tester.pumpAndSettle();

      expect(find.text('PIN actualizado. Dáselo en persona.'), findsOneWidget);
      expect(backendOf(tester).control.pins['4'], '4821');
    });

    testWidgets('cerrar sesiones pide confirmar', (tester) async {
      await openMore(tester, 'JIM-01', 'Accesos del equipo');

      await scrollAndTap(
        tester,
        find.descendant(
          of: find.byKey(const ValueKey('account-3')),
          matching: find.text('Cerrar sesiones'),
        ),
      );
      await tester.tap(inDialog('Cerrar sesiones'));
      await tester.pumpAndSettle();

      expect(find.text('Sesiones de Isaí cerradas.'), findsOneWidget);
    });

    testWidgets('Jime ve los conteos pero no ajusta', (tester) async {
      await openMore(tester, 'JIM-01', 'Inventario y conteos');
      await scrollAndTap(tester, find.text('Viernes 4 dic'));

      expect(find.text('Conteo'), findsOneWidget);
      expect(find.textContaining('Diferencia −2'), findsOneWidget);
      expect(find.textContaining('Ajustar'), findsNothing);
      await tester.tap(backTo('Conteos'));
      await tester.pumpAndSettle();
      expect(find.text('Inventario y conteos'), findsOneWidget);
    });

    testWidgets('«Más» muestra el respaldo y lo de cada rol', (tester) async {
      await openTab(tester, 'JIM-01', 'Más', height: 1300);

      expect(find.textContaining('Última copia hoy 03:00'), findsOneWidget);
      expect(find.text('1 por validar'), findsOneWidget);
    });

    testWidgets('Dirección no ve lo que es solo de Jime', (tester) async {
      await openTab(tester, 'DIR-08', 'Más', height: 1300);

      for (final row in ['Cumplimiento', 'Precios autorizados', 'Auditoría y reportes']) {
        expect(find.text(row), findsOneWidget, reason: row);
      }
      for (final row in ['Pedidos', 'Accesos del equipo', 'Inventario y conteos']) {
        expect(find.text(row), findsNothing, reason: row);
      }

      await goTo(tester, AppRoutes.moreOrders);
      expect(find.text('Hola, Dirección'), findsOneWidget, reason: 'vuelve al resumen');
    });
  });

  test('cada rol entra solo a lo suyo', () {
    const control = MemberRole.control;
    const management = MemberRole.management;
    for (final route in [
      AppRoutes.moreOrders,
      AppRoutes.moreOrder('1040'),
      AppRoutes.moreAccess,
      AppRoutes.moreCounts,
      AppRoutes.moreDeliverables,
      AppRoutes.moreCommissions,
      AppRoutes.complianceMember('4'),
      AppRoutes.complianceIndicator('4', '4-1'),
      AppRoutes.pendingPayment('1046'),
      AppRoutes.close,
    ]) {
      expect(canOpen(control, route), isTrue, reason: 'Jime $route');
      expect(canOpen(management, route), isFalse, reason: 'Dirección $route');
      expect(canOpen(MemberRole.seller, route), isFalse, reason: 'ventas $route');
    }
    for (final route in [
      AppRoutes.compliance,
      AppRoutes.morePrices,
      AppRoutes.morePrice('p-8107'),
      AppRoutes.moreAudit,
    ]) {
      expect(canOpen(control, route), isTrue, reason: route);
      expect(canOpen(management, route), isTrue, reason: route);
      expect(canOpen(MemberRole.warehouse, route), isFalse, reason: route);
    }
    expect(canOpen(management, AppRoutes.authorization('price_change', 'pc-1')), isTrue);
    expect(canOpen(control, AppRoutes.authorization('price_change', 'pc-1')), isFalse);
    expect(navItemsFor(management).map((i) => i.route), contains(AppRoutes.approve));
  });
}
