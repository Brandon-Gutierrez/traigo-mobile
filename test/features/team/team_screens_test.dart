import 'package:flutter_test/flutter_test.dart';
import 'package:traigo/app/router.dart';
import 'package:traigo/core/demo/demo_backend.dart';
import 'package:traigo/core/demo/demo_repositories.dart';
import 'package:traigo/core/media/photo_picker.dart';
import 'package:traigo/core/network/api_exception.dart';
import 'package:traigo/core/providers.dart';
import 'package:traigo/features/team/domain/bonus.dart';
import 'package:traigo/features/team/domain/my_week.dart';
import 'package:traigo/features/team/domain/team_week.dart';

import '../../support/sales_helpers.dart';
import '../../support/team_helpers.dart';
import '../../support/test_app.dart';

void main() {
  late FakePhotoPicker picker;

  setUp(() {
    picker = FakePhotoPicker(
      file: const UploadFile(path: '/no/existe/informe.jpg', filename: 'informe.jpg'),
    );
  });

  Future<void> open(WidgetTester tester, String code, String tab) => openTab(
        tester,
        code,
        tab,
        height: 2200,
        overrides: [photoPickerProvider.overrideWithValue(picker)],
      );

  /// En la fila del indicador [name], toca [action].
  Future<void> tapIn(WidgetTester tester, String name, String action) async {
    await scrollAndTap(
      tester,
      find.descendant(of: indicatorBlock(name), matching: find.text(action)),
    );
  }

  testWidgets('«Mi semana»: puntaje, indicadores y su evidencia', (tester) async {
    await open(tester, 'ALI-04', 'Mi semana');

    expect(find.text('1–6 DIC · METAS AL 90 % (PRIMERA SEMANA)'), findsOneWidget);
    expect(find.text('83 %'), findsOneWidget);
    expect(find.text('Cumple'), findsOneWidget);
    expect(find.text('25 / 27'), findsOneWidget);
    expect(find.text('peso 40 %'), findsOneWidget);
    expect(find.text('1 foto · En revisión'), findsOneWidget);
    expect(find.text('Validada por Jime'), findsNWidgets(3));
    expect(find.text('‹ Semana anterior'), findsNothing);
    expect(find.text('ENTREGAS TÉCNICAS'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('los porcentajes se muestran con su signo', (tester) async {
    await open(tester, 'ISA-03', 'Mi semana');

    expect(find.text('98 / 98 %'), findsOneWidget);
    expect(find.text('9 / 11'), findsOneWidget);
  });

  testWidgets('Kim sube un enlace donde faltaba evidencia', (tester) async {
    await open(tester, 'KIM-05', 'Mi semana');

    await tapIn(tester, 'Nuevas cuentas mayoristas con pago', 'Subir evidencia');
    expect(find.text('Primer pedido pagado de un cliente nuevo'), findsOneWidget);
    expect(find.text('META 1'), findsOneWidget);
    expect(find.text('LO QUE ENVIASTE'), findsNothing);
    expect(find.text('Elige una foto'), findsOneWidget);

    await scrollAndTap(tester, find.text('Enlace'));
    expect(find.text('Escribe el enlace'), findsOneWidget);
    await tester.enterText(field('Enlace'), 'no es un enlace');
    await tester.pumpAndSettle();
    expect(find.text('Revisa el enlace'), findsOneWidget);

    await tester.enterText(field('Enlace'), 'drive.google.com/cuenta-nueva');
    await tester.pumpAndSettle();
    await scrollAndTap(tester, find.text('Enviar a Jime'));

    expect(find.text('Evidencia enviada. Jime la va a revisar.'), findsOneWidget);
    expect(find.text('TU PUNTAJE'), findsOneWidget, reason: 'vuelve a Mi semana');
    expect(find.text('1 enlace · En revisión'), findsOneWidget);
    expect(find.text('Sin evidencia'), findsNothing);
  });

  testWidgets('Alison agrega una foto a la evidencia en revisión', (tester) async {
    await open(tester, 'ALI-04', 'Mi semana');

    await tapIn(tester, 'Registro semanal de ventas', 'Ver evidencia');
    expect(find.text('registro-ventas-1-6dic.jpg'), findsOneWidget);
    expect(find.text('«Incluye las 4 ventas cobradas.»'), findsOneWidget);

    await scrollAndTap(tester, find.text('Elegir de la galería'));
    expect(picker.sources, [PhotoSource.gallery]);
    expect(find.text('informe.jpg'), findsOneWidget);
    await scrollAndTap(tester, find.text('Enviar a Jime'));

    expect(find.text('2 fotos · En revisión'), findsOneWidget);
  });

  testWidgets('quien vende puede adjuntar un pedido propio', (tester) async {
    await open(tester, 'ALI-04', 'Mi semana');
    await tapIn(tester, 'Registro semanal de ventas', 'Ver evidencia');

    await scrollAndTap(tester, find.text('Pedido'));
    await scrollAndTap(tester, find.text('Elegir pedido'));
    expect(find.text('Elige el pedido'), findsOneWidget);
    expect(find.text('N-1038'), findsNothing, reason: 'está cancelado');
    await tester.tap(find.text('N-1045'));
    await tester.pumpAndSettle();
    expect(find.text('N-1045 · Valeria Paz'), findsOneWidget);
    await scrollAndTap(tester, find.text('Enviar a Jime'));

    expect(find.text('2 evidencias · En revisión'), findsOneWidget);
  });

  testWidgets('lo validado solo se mira', (tester) async {
    await open(tester, 'ALI-04', 'Mi semana');

    await tapIn(tester, 'Pedidos propios efectivamente pagados', 'Ver evidencia');

    expect(find.text('Pedido N-1040'), findsOneWidget);
    expect(find.text('Jime ya validó este indicador: no hace falta agregar más.'),
        findsOneWidget);
    expect(find.text('Subir evidencia'), findsNothing);
    expect(find.text('¿QUÉ ADJUNTAS?'), findsNothing);
  });

  testWidgets('«Evidencia» muestra solo lo no validado, primero lo observado',
      (tester) async {
    await open(tester, 'AIL-02', 'Evidencia');

    expect(find.text('Videos cortos publicados'), findsNothing);
    expect(find.text('3 enlaces · En revisión'), findsOneWidget);
    expect(find.text('ENTREGAS TÉCNICAS'), findsNothing);
    final observed = tester.getTopLeft(find.text('Artes o fichas comerciales terminados'));
    final lives = tester.getTopLeft(find.text('LIVES realizados'));
    expect(observed.dy, lessThan(lives.dy));

    await tester.tap(find.text('Artes o fichas comerciales terminados'));
    await tester.pumpAndSettle();
    expect(find.text('Jime: Una de las fichas no tiene el precio autorizado.'),
        findsOneWidget);
    expect(find.text('Pedido'), findsNothing, reason: 'Ailén no vende');

    await tester.tap(backTo('Evidencia'));
    await tester.pumpAndSettle();
    expect(find.text('LO QUE JIME TODAVÍA NO VALIDA · 1–6 DIC'), findsOneWidget);
  });

  testWidgets('Sistemas 1 envía una entrega con la fecha real que elige', (tester) async {
    await open(tester, 'SIS-06', 'Evidencia');

    expect(find.text('Compra en línea probada de principio a fin'), findsOneWidget);
    expect(find.text('Tienda web publicada, navegable y con catálogo'), findsNothing);
    await scrollAndTap(tester, find.text('Pedidos web integrados al control de Jime'));

    expect(find.text('PRUEBA DE ACEPTACIÓN'), findsOneWidget);
    expect(find.text('06/12/2026'), findsOneWidget);
    expect(find.text('Con esta fecha queda fuera de plazo: vencía el 30/11.'),
        findsOneWidget);

    // Terminó el 29: elige esa fecha en el calendario.
    await scrollAndTap(tester, find.text('06/12/2026'));
    await tester.tap(find.byTooltip('Mes anterior'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('29'));
    await tester.tap(find.text('ACEPTAR'));
    await tester.pumpAndSettle();
    expect(find.text('29/11/2026'), findsOneWidget);
    expect(find.text('Jime comprueba la fecha al validar.'), findsOneWidget);

    await scrollAndTap(tester, find.text('Enlace'));
    await tester.enterText(field('Enlace'), 'https://traigo.example/pedidos');
    await tester.pumpAndSettle();
    await scrollAndTap(tester, find.text('Enviar a Jime'));

    expect(find.text('Entrega enviada. Jime la va a revisar.'), findsOneWidget);
    expect(find.text('En revisión'), findsNWidgets(2));
  });

  testWidgets('una entrega validada solo se mira', (tester) async {
    await open(tester, 'SIS-06', 'Mi semana');

    expect(find.text('SISTEMAS 1 · 1–6 DIC · METAS AL 90 % (PRIMERA SEMANA)'),
        findsOneWidget);
    expect(find.textContaining('tus 4 entregas validadas a tiempo'), findsOneWidget);
    await scrollAndTap(tester, find.text('Seguridad del checkout y permisos de consulta'));

    expect(find.text('Jime ya la validó: llegó a tiempo.'), findsOneWidget);
    expect(find.text('Fecha de entrega: 29/11'), findsOneWidget);
    expect(find.text('FECHA REAL DE ENTREGA'), findsNothing);
  });

  testWidgets('con todo validado, «Evidencia» lo dice', (tester) async {
    await open(tester, 'SIS-07', 'Evidencia');

    expect(find.text('Toda tu evidencia está validada.'), findsOneWidget);
  });

  testWidgets('«Equipo»: lo cobrado, mi parte por escalón y las semanas', (tester) async {
    await open(tester, 'ALI-04', 'Equipo');

    expect(find.text('Bs 41.600'), findsOneWidget);
    expect(findTextContaining('de Bs 40.000 · 104 %'), findsOneWidget);
    expect(find.text('TU 20 %'), findsOneWidget);
    expect(find.text('36.000'), findsOneWidget);
    expect(find.text('150'), findsOneWidget);
    expect(find.textContaining('Ya cumples, vas en 83 %.'), findsOneWidget);
    expect(find.text('11–14 ene'), findsOneWidget);
    expect(find.text('ACTUAL'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('si la semana ya se cerró, no deja subir y dice el motivo', (tester) async {
    final repo = StubTeamRepository((week) => closedWeek(week, 'Faltó el informe.'));
    await openTab(tester, 'KIM-05', 'Mi semana',
        height: 2200, overrides: [teamRepositoryProvider.overrideWithValue(repo)]);

    expect(find.text('Jime cerró tu semana: no cumple. Motivo: Faltó el informe.'),
        findsOneWidget);
    expect(find.text('Subir evidencia'), findsNothing);
    expect(find.text('Corregir'), findsNothing);
  });

  testWidgets('desde la semana 2 se puede revisar la anterior', (tester) async {
    final repo = StubTeamRepository((week) => week, code: 'ALI-04', currentNumber: 2);
    await openTab(tester, 'ALI-04', 'Mi semana',
        height: 2200, overrides: [teamRepositoryProvider.overrideWithValue(repo)]);

    await scrollAndTap(tester, find.text('‹ Semana anterior'));
    expect(repo.requested.last, 1);
    expect(find.text('‹ Semana anterior'), findsNothing);

    await tapIn(tester, 'Registro semanal de ventas', 'Ver evidencia');
    final router = containerOf(tester).read(routerProvider);
    expect(router.routerDelegate.currentConfiguration.uri.toString(),
        '/week/indicator/4-4?week=1');

    await tester.tap(backTo('Mi semana'));
    await tester.pumpAndSettle();
    await scrollAndTap(tester, find.text('Volver a la semana actual'));
    expect(repo.requested.last, isNull);
  });

  testWidgets('sin conexión se reintenta con la misma clave; si cambia, con otra',
      (tester) async {
    final repo = StubTeamRepository((week) => week)
      ..failures.addAll(const [NetworkException(), NetworkException()]);
    await openTab(tester, 'KIM-05', 'Mi semana',
        height: 2200, overrides: [teamRepositoryProvider.overrideWithValue(repo)]);
    await tapIn(tester, 'Nuevas cuentas mayoristas con pago', 'Subir evidencia');
    await scrollAndTap(tester, find.text('Enlace'));
    await tester.enterText(field('Enlace'), 'https://example.com/a');
    await tester.pumpAndSettle();

    await scrollAndTap(tester, find.text('Enviar a Jime'));
    expect(find.textContaining('no se enviará dos veces'), findsOneWidget);
    await scrollAndTap(tester, find.text('Enviar a Jime'));
    expect(repo.keys[1], repo.keys[0]);

    await tester.enterText(field('Enlace'), 'https://example.com/b');
    await tester.pumpAndSettle();
    await scrollAndTap(tester, find.text('Enviar a Jime'));
    expect(repo.keys[2], isNot(repo.keys[0]));
    expect(find.text('Evidencia enviada. Jime la va a revisar.'), findsOneWidget);
  });

  testWidgets('cada rol entra al detalle solo por sus pestañas', (tester) async {
    await openTab(tester, 'ALI-04', null);
    final router = containerOf(tester).read(routerProvider);

    // Alison no tiene la pestaña «Evidencia»; sí su detalle desde Mi semana.
    router.go(AppRoutes.indicator(AppRoutes.evidence, '4-4'));
    await tester.pumpAndSettle();
    expect(router.routerDelegate.currentConfiguration.uri.path, AppRoutes.home);

    router.go(AppRoutes.indicator(AppRoutes.week, '4-4'));
    await tester.pumpAndSettle();
    expect(find.text('LO QUE ENVIASTE'), findsOneWidget);
  });
}

/// La demo de la primera semana, cambiada para probar lo que la demo no tiene.
class StubTeamRepository implements TeamRepository {
  StubTeamRepository(this.change, {String code = 'KIM-05', this.currentNumber = 1}) {
    _backend.login(code, '1234');
  }

  final MyWeek Function(MyWeek week) change;
  final int currentNumber;

  /// Las semanas que pidió la app, y las claves de cada envío.
  final List<int?> requested = [];
  final List<String> keys = [];

  /// Errores que responden los primeros envíos.
  final List<ApiException> failures = [];

  final DemoBackend _backend = DemoBackend();
  late final DemoTeamRepository _demo = DemoTeamRepository(_backend, Duration.zero);

  @override
  Future<MyWeek> myWeek({int? weekNumber}) async {
    requested.add(weekNumber);
    final week = await _demo.myWeek();
    return change(renumbered(week, weekNumber ?? currentNumber));
  }

  @override
  Future<TeamWeek> teamWeek() => _demo.teamWeek();

  @override
  Future<Evidence> submitEvidence(String resultId, NewEvidence evidence) async {
    keys.add(evidence.clientUuid);
    if (failures.isNotEmpty) throw failures.removeAt(0);
    return _demo.submitEvidence(resultId, evidence);
  }

  @override
  Future<Deliverable> submitDeliverable(
    String id, {
    required DateTime deliveredOn,
    required String clientUuid,
    UploadFile? file,
    String? url,
  }) =>
      _demo.submitDeliverable(id,
          deliveredOn: deliveredOn, clientUuid: clientUuid, file: file, url: url);
}

MyWeek renumbered(MyWeek week, int number) => MyWeek(
      week: week.week,
      weekNumber: number,
      countTargetFactor: number == 1 ? week.countTargetFactor : 1,
      scorePercent: week.scorePercent,
      partialScorePercent: week.partialScorePercent,
      minimumPercent: week.minimumPercent,
      compliance: week.compliance,
      indicators: week.indicators,
      deliverables: week.deliverables,
      acceptsEvidence: week.acceptsEvidence,
    );

MyWeek closedWeek(MyWeek week, String reason) => MyWeek(
      week: week.week,
      weekNumber: week.weekNumber,
      countTargetFactor: week.countTargetFactor,
      scorePercent: week.scorePercent,
      partialScorePercent: week.partialScorePercent,
      minimumPercent: week.minimumPercent,
      compliance: Compliance.fails,
      indicators: week.indicators,
      deliverables: week.deliverables,
      acceptsEvidence: false,
      closedReason: reason,
    );
