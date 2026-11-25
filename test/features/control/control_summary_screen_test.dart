import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traigo/core/demo/demo_backend.dart';
import 'package:traigo/core/money/money.dart';
import 'package:traigo/core/network/api_exception.dart';
import 'package:traigo/core/providers.dart';
import 'package:traigo/features/auth/domain/auth.dart';
import 'package:traigo/features/control/domain/control_summary.dart';
import 'package:traigo/features/team/domain/bonus.dart';

import '../../support/test_app.dart';

/// Devuelve un resumen fijo; puede fallar la primera vez.
class FakeControlRepository implements ControlRepository {
  FakeControlRepository(this._summary, {this.failFirst = false});

  final ControlSummary _summary;
  final bool failFirst;
  int calls = 0;

  @override
  Future<ControlSummary> summary() async {
    calls++;
    if (failFirst && calls == 1) throw const NetworkException();
    return _summary;
  }
}

/// El resumen de la demo, para variarlo en las pruebas.
ControlSummary demoSummary() {
  final backend = DemoBackend();
  final step = backend.login('JIM-01', '1234') as NeedsSecondStep;
  backend.verifyTwoFactor(step.challenge.id, '123456');
  return backend.controlSummary();
}

MemberResult result(String name, Compliance compliance) => MemberResult(
      id: name,
      name: name,
      scorePercent: 80,
      minimumPercent: 90,
      compliance: compliance,
      fundShareRate: 0.20,
    );

ControlSummary withBonus(List<MemberResult> members, BonusResult bonus) {
  final base = demoSummary();
  return ControlSummary(
    asOf: base.asOf,
    week: base.week,
    collected: base.collected,
    pending: base.pending,
    members: members,
    bonus: bonus,
  );
}

void main() {
  Future<void> openAs(WidgetTester tester, String code) async {
    useMobileScreen(tester, height: 1500);
    await tester.pumpWidget(testApp(tokens: signedInTokens(code)));
    await tester.pumpAndSettle();
  }

  testWidgets('Jime ve la semana, lo pendiente, el equipo y el bono', (tester) async {
    await openAs(tester, 'JIM-01');

    expect(find.text('Hola, Jime'), findsOneWidget);
    expect(find.text('CONTROL · JIM-01'), findsOneWidget);
    expect(find.text('SEMANA 1–6 DIC · DOMINGO 6'), findsOneWidget);
    expect(find.text('104 %'), findsOneWidget);

    expect(find.text('POR REVISAR HOY'), findsOneWidget);
    expect(find.text('Ver pendientes'), findsOneWidget);
    for (final label in [
      'Pagos por confirmar',
      'Evidencias de KPI',
      'Cierres de caja',
      'Entregas de Sistemas',
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }

    expect(find.text('EQUIPO ESTA SEMANA'), findsOneWidget);
    expect(find.text('Cumple'), findsNWidgets(4));
    expect(find.text('No cumple'), findsOneWidget);
    expect(find.text('Pendiente'), findsOneWidget);
    expect(find.text('2 de 4 entregas validadas'), findsOneWidget);

    expect(find.text('A pagar si Dirección autoriza'), findsOneWidget);
    expect(find.text('Bs 1.050'), findsOneWidget);
    expect(
      findTextContaining(
        'Sin pagar Bs 450: Kim no cumplió su KPI y Sistemas 1 tiene validaciones pendientes.',
      ),
      findsOneWidget,
    );
    expect(find.text('Revisar y autorizar'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('«Ver pendientes» abre la bandeja de Jime', (tester) async {
    await openAs(tester, 'JIM-01');

    await tester.tap(find.text('Ver pendientes'));
    await tester.pumpAndSettle();

    expect(find.text('Llega en la fase 5.'), findsOneWidget);
    expect(find.textContaining('primero los más antiguos'), findsOneWidget);
  });

  testWidgets('Dirección no revisa la bandeja pero sí puede ir a autorizar', (tester) async {
    await openAs(tester, 'DIR-08');

    expect(find.text('Hola, Dirección'), findsOneWidget);
    expect(find.text('DIRECCIÓN · DIR-08'), findsOneWidget);
    expect(find.text('POR VALIDAR DE JIME'), findsOneWidget);
    expect(find.text('Ver pendientes'), findsNothing);
    expect(find.text('A pagar si autorizas'), findsOneWidget);

    await scrollAndTap(tester, find.text('Revisar y autorizar'));
    expect(find.text('Autorizar pagos'), findsOneWidget);
  });

  testWidgets('nombra a quienes no cumplen, con «e» antes de Isaí', (tester) async {
    useMobileScreen(tester, height: 1500);
    final summary = withBonus(
      [result('Kim', Compliance.fails), result('Isaí', Compliance.fails)],
      BonusResult(
        level: BonusLevel.complete,
        prize: Money.parse('1500'),
        payable: Money.parse('900'),
        unpaidFailing: Money.parse('600'),
        unpaidPending: Money.zero,
      ),
    );
    await tester.pumpWidget(testApp(
      tokens: signedInTokens('JIM-01'),
      overrides: [controlRepositoryProvider.overrideWithValue(FakeControlRepository(summary))],
    ));
    await tester.pumpAndSettle();

    expect(
      findTextContaining('Sin pagar Bs 600: Kim e Isaí no cumplieron su KPI.'),
      findsOneWidget,
    );
  });

  testWidgets('sin llegar al 90 % lo dice claramente', (tester) async {
    useMobileScreen(tester, height: 1500);
    final summary = withBonus(
      [result('Kim', Compliance.fails)],
      const BonusResult(
        level: BonusLevel.none,
        prize: Money.zero,
        payable: Money.zero,
        unpaidFailing: Money.zero,
        unpaidPending: Money.zero,
      ),
    );
    await tester.pumpWidget(testApp(
      tokens: signedInTokens('JIM-01'),
      overrides: [controlRepositoryProvider.overrideWithValue(FakeControlRepository(summary))],
    ));
    await tester.pumpAndSettle();

    expect(findTextContaining('esta semana aún no hay premio'), findsOneWidget);
  });

  testWidgets('sin internet muestra el error y se recupera al reintentar', (tester) async {
    useMobileScreen(tester);
    final repo = FakeControlRepository(demoSummary(), failFirst: true);
    await tester.pumpWidget(testApp(
      tokens: signedInTokens('JIM-01'),
      overrides: [controlRepositoryProvider.overrideWithValue(repo)],
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('No hay conexión con el servidor'), findsOneWidget);
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    expect(find.text('104 %'), findsOneWidget);
    expect(repo.calls, 2);
  });

  testWidgets('el Resumen cabe en 320 de ancho con letra grande', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    useMobileScreen(tester, width: 320, height: 640);
    await tester.pumpWidget(testApp(tokens: signedInTokens('DIR-08')));
    await tester.pumpAndSettle();

    for (var i = 0; i < 5; i++) {
      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pumpAndSettle();
    }

    expect(tester.takeException(), isNull);
  });
}
