import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traigo/core/demo/demo_backend.dart';
import 'package:traigo/core/network/api_exception.dart';
import 'package:traigo/core/providers.dart';
import 'package:traigo/features/home/domain/home.dart';
import 'package:traigo/features/team/domain/bonus.dart';

import '../../support/test_app.dart';

/// Devuelve un Inicio fijo.
class FixedHomeRepository implements HomeRepository {
  FixedHomeRepository(this.home);

  final TeamHome home;

  @override
  Future<TeamHome> load() async => home;
}

/// El Inicio de Sistemas 1 después de que Jime cerró su semana.
TeamHome closedByControl(String reason) {
  final home = (DemoBackend()..login('SIS-06', '1234')).home();
  return TeamHome(
    week: home.week,
    collected: home.collected,
    fundShareRate: home.fundShareRate,
    kpi: MyKpi(
      scorePercent: home.kpi.scorePercent,
      minimumPercent: home.kpi.minimumPercent,
      compliance: Compliance.fails,
      indicators: home.kpi.indicators,
      deliverables: home.kpi.deliverables,
      closedReason: reason,
    ),
  );
}

/// Puede fallar la primera vez (sin internet) y después responde con los datos
/// del servidor de prueba. Cuenta cuántas veces se le pidió el Inicio.
class CountingHomeRepository implements HomeRepository {
  CountingHomeRepository({this.failFirst = false});

  final DemoBackend _backend = DemoBackend()..login('ALI-04', '1234');
  final bool failFirst;
  int calls = 0;

  @override
  Future<TeamHome> load() async {
    calls++;
    if (failFirst && calls == 1) throw const NetworkException();
    return _backend.home();
  }
}

void main() {
  /// Abre la app ya ingresada. El alto grande hace que la lista construya
  /// también lo que en un celular queda más abajo.
  Future<void> openAs(WidgetTester tester, String code, {double height = 1500}) async {
    useMobileScreen(tester, height: height);
    await tester.pumpWidget(testApp(tokens: signedInTokens(code)));
    await tester.pumpAndSettle();
  }

  testWidgets('Inicio de Alison: bono, KPI, comisión y ventas de hoy', (tester) async {
    await openAs(tester, 'ALI-04');

    expect(find.text('Hola, Alison'), findsOneWidget);
    expect(find.text('VENTAS POR COMISIÓN · ALI-04'), findsOneWidget);

    expect(find.text('BONO DEL EQUIPO · 1–6 DIC'), findsOneWidget);
    expect(find.text('104 %'), findsOneWidget);
    expect(findTextContaining('cobrado Bs 41.600 de Bs 40.000'), findsOneWidget);
    expect(findTextContaining('Faltan Bs 4.400 para el superior (115 %).'), findsOneWidget);
    expect(find.text('+ Registrar venta'), findsOneWidget);

    expect(find.text('TU SEMANA'), findsOneWidget);
    expect(find.text('83 %'), findsOneWidget);
    expect(find.text('80 %'), findsOneWidget);
    expect(find.text('Tu parte con el premio completo'), findsOneWidget);
    expect(find.text('Bs 300'), findsOneWidget);
    expect(find.text('Cumples tu mínimo'), findsOneWidget);

    expect(find.text('ESTE MES'), findsOneWidget);
    expect(find.text('Bs 412,50'), findsOneWidget);
    expect(find.text('Se paga una vez al mes. Fecha de pago: por definir.'), findsOneWidget);

    expect(find.text('VENTAS DE HOY'), findsOneWidget);
    expect(find.text('Tomatodos de Messi × 2'), findsOneWidget);
    expect(find.text('Mariela Quispe · QR'), findsOneWidget);
    expect(find.text('[% por definir]'), findsNWidgets(2));

    expect(find.text('CAJA DE HOY'), findsNothing);
    expect(find.text('EVIDENCIA PENDIENTE'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Kim ve que todavía no llega a su mínimo', (tester) async {
    await openAs(tester, 'KIM-05');

    expect(find.text('85 %'), findsOneWidget);
    expect(find.text('Todavía no llegas a tu mínimo'), findsOneWidget);
    expect(find.text('Bs 595,00'), findsOneWidget);
  });

  testWidgets('Isaí tiene el cierre de caja como acción y no ve comisiones',
      (tester) async {
    await openAs(tester, 'ISA-03');

    expect(find.text('Cierre de caja'), findsOneWidget);
    expect(find.text('CAJA DE HOY'), findsOneWidget);
    expect(find.text('Bs 4.968'), findsOneWidget);
    expect(find.text('Sin enviar a Jime'), findsOneWidget);
    expect(find.text('ESTE MES'), findsNothing);
    expect(find.text('VENTAS DE HOY'), findsNothing);
  });

  testWidgets('Ailén sube evidencia y ve la que está en revisión', (tester) async {
    await openAs(tester, 'AIL-02');

    expect(find.text('Subir evidencia'), findsOneWidget);
    expect(find.text('EVIDENCIA PENDIENTE'), findsOneWidget);
    expect(find.text('LIVES realizados'), findsOneWidget);
    expect(find.text('En revisión'), findsOneWidget);
    expect(find.text('ENTREGAS TÉCNICAS'), findsNothing);
  });

  testWidgets('Sistemas 1 queda pendiente hasta que se validen sus entregas',
      (tester) async {
    await openAs(tester, 'SIS-06');

    expect(find.text('Hola, Sistemas 1'), findsOneWidget);
    expect(find.text('ENTREGAS TÉCNICAS'), findsOneWidget);
    expect(find.text('2 de 4'), findsOneWidget);
    expect(find.text('Pendiente: faltan entregas por validar'), findsOneWidget);
    expect(find.text('Bs 150'), findsOneWidget);
  });

  testWidgets('si Jime cerró su semana, lo dice con el motivo', (tester) async {
    useMobileScreen(tester, height: 1500);
    await tester.pumpWidget(testApp(
      tokens: signedInTokens('SIS-06'),
      overrides: [
        homeRepositoryProvider.overrideWithValue(
          FixedHomeRepository(closedByControl('Solo 2 de 4 entregas validadas.')),
        ),
      ],
    ));
    await tester.pumpAndSettle();

    expect(find.text('Jime cerró tu semana: no cumple'), findsOneWidget);
    expect(find.text('Motivo: Solo 2 de 4 entregas validadas.'), findsOneWidget);
    expect(find.text('Todavía no llegas a tu mínimo'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('con todo validado, Sistemas 2 no tiene pendientes', (tester) async {
    await openAs(tester, 'SIS-07');

    expect(find.text('Tus entregas están completas.'), findsOneWidget);
    expect(find.text('Toda tu evidencia está validada.'), findsOneWidget);
  });

  const actions = {
    'ALI-04': ('+ Registrar venta', 'PASO 1 DE 2 · PRODUCTOS'),
    'ISA-03': ('Cierre de caja', 'Llega en la fase 4.'),
    'AIL-02': ('Subir evidencia', 'LO QUE JIME TODAVÍA NO VALIDA · 1–6 DIC'),
  };
  for (final MapEntry(key: code, value: (action, arrival)) in actions.entries) {
    testWidgets('la acción principal de $code lleva a su pantalla', (tester) async {
      await openAs(tester, code);

      await tester.tap(find.text(action));
      await tester.pumpAndSettle();

      expect(find.text(arrival), findsOneWidget);
    });
  }

  testWidgets('«Ver mi semana» lleva a Mi semana', (tester) async {
    await openAs(tester, 'ALI-04');

    await tester.tap(find.text('Ver mi semana'));
    await tester.pumpAndSettle();

    expect(find.text('TU PUNTAJE'), findsOneWidget);
  });

  testWidgets('una evidencia pendiente del Inicio abre su detalle', (tester) async {
    await openAs(tester, 'AIL-02');

    await tester.tap(find.text('LIVES realizados'));
    await tester.pumpAndSettle();

    expect(find.text('Subir evidencia'), findsOneWidget);
    expect(find.text('LO QUE ENVIASTE'), findsOneWidget);
  });

  testWidgets('sin internet muestra el error y se recupera al reintentar', (tester) async {
    useMobileScreen(tester);
    final repo = CountingHomeRepository(failFirst: true);
    await tester.pumpWidget(testApp(
      tokens: signedInTokens(),
      overrides: [homeRepositoryProvider.overrideWithValue(repo)],
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('No hay conexión con el servidor'), findsOneWidget);
    expect(find.text('104 %'), findsNothing);

    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    expect(find.text('104 %'), findsOneWidget);
    expect(repo.calls, 2);
  });

  testWidgets('deslizar hacia abajo vuelve a pedir los datos', (tester) async {
    useMobileScreen(tester);
    final repo = CountingHomeRepository();
    await tester.pumpWidget(testApp(
      tokens: signedInTokens(),
      overrides: [homeRepositoryProvider.overrideWithValue(repo)],
    ));
    await tester.pumpAndSettle();
    expect(repo.calls, 1);

    await tester.fling(find.byType(ListView), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();

    expect(repo.calls, 2);
  });

  // Ningún Inicio debe desbordar, ni en un celular chico ni con letra grande.
  for (final code in ['AIL-02', 'ISA-03', 'ALI-04', 'KIM-05', 'SIS-06', 'SIS-07']) {
    testWidgets('el Inicio de $code cabe en 320 de ancho con letra grande', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      useMobileScreen(tester, width: 320, height: 640);
      await tester.pumpWidget(testApp(tokens: signedInTokens(code)));
      await tester.pumpAndSettle();

      for (var i = 0; i < 5; i++) {
        await tester.drag(find.byType(ListView), const Offset(0, -400));
        await tester.pumpAndSettle();
      }

      expect(tester.takeException(), isNull);
    });
  }
}
