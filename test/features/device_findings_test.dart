import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traigo/core/demo/demo_backend.dart';
import 'package:traigo/core/providers.dart';
import 'package:traigo/core/storage/last_code_storage.dart';
import 'package:traigo/features/control/domain/payouts.dart';
import 'package:traigo/features/control/presentation/panel_widgets.dart';
import 'package:traigo/features/team/presentation/week_widgets.dart';

import '../support/sales_helpers.dart';
import '../support/test_app.dart';

/// Fallos que se vieron al probar la app en un emulador con el backend real.

/// El cierre como lo da el servidor: sin elegir semana abre la 1 y, después de
/// enviarla, la 2.
class SendableRepository implements PayoutsRepository {
  bool sent = false;

  WeeklyClosing _closing(int number) {
    final demo = DemoBackend().control.weeklyClosing();
    const ok = ClosingCheck(ok: true, detail: 'Todo revisado');
    return WeeklyClosing(
      weekNumber: number,
      currentWeek: 2,
      sendableFrom: DateTime(2026, 11, 1),
      week: demo.week,
      status: WeekClosingStatus.open,
      paymentsReconciled: ok,
      kpiEvidence: ok,
      duplicates: demo.duplicates,
      direction: demo.direction,
      pendingMembers: const [],
    );
  }

  @override
  Future<WeeklyClosing> weeklyClosing({int? weekNumber}) async =>
      _closing(weekNumber ?? (sent ? 2 : 1));

  @override
  Future<WeeklyClosing> sendWeeklyClosing(
    int weekNumber, {
    required bool duplicatesCleared,
    Map<String, String> closePending = const {},
    String? observations,
  }) async {
    sent = true;
    return _closing(weekNumber);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('el nombre de un adjunto no incluye la firma del enlace', () {
    expect(
      attachmentName('https://traigo.bo/storage/comprobantes/ab/evidencia-o0ry.png'
          '?expires=1795699822&signature=dc217f076e81'),
      'evidencia-o0ry.png',
    );
    expect(attachmentName('/data/user/0/cache/scaled_20.png'), 'scaled_20.png');
  });

  Finder firstKey() => find.byKey(const ValueKey('pin-key-1'));

  testWidgets('el teclado del PIN no se mueve al escribir después de un error',
      (tester) async {
    useMobileScreen(tester, height: 1200);
    await tester.pumpWidget(testApp(lastCode: MemoryLastCodeStorage('ALI-04')));
    await tester.pumpAndSettle();
    await tapDigits(tester, '9999');
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();
    final before = tester.getTopLeft(firstKey());

    await tapDigits(tester, '1');
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(firstKey()), before);
  });

  testWidgets('tampoco se mueve el del código de verificación', (tester) async {
    useMobileScreen(tester, height: 1200);
    await tester.pumpWidget(testApp(lastCode: MemoryLastCodeStorage('JIM-01')));
    await tester.pumpAndSettle();
    await tapDigits(tester, '1234');
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();
    await tapDigits(tester, '111111');
    await scrollAndTap(tester, find.text('Verificar'));
    final before = tester.getTopLeft(firstKey());

    await tapDigits(tester, '1');
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(firstKey()), before);
  });

  /// Paso 2 de una venta, a las [hour]:20.
  Future<void> openCustomerStep(WidgetTester tester, {required int hour}) async {
    final day = DemoBackend.today;
    await openTab(tester, 'ALI-04', 'Vender', height: 1500, overrides: [
      nowProvider.overrideWithValue(() => DateTime(day.year, day.month, day.day, hour, 20)),
    ]);
    await scrollAndTap(tester, find.text('Elegir productos'));
    await search(tester, '8107');
    await scrollAndTap(tester, find.text('Tomatodos de Messi'));
    await scrollAndTap(tester, findTextContaining('Continuar'));
  }

  testWidgets('al cerrar el selector de hora no vuelve a abrirse el teclado',
      (tester) async {
    await openCustomerStep(tester, hour: 10);
    await tester.showKeyboard(field('Nombre del cliente'));
    await tester.pump();
    expect(tester.testTextInput.isVisible, isTrue);

    await scrollAndTap(tester, find.text('Elegir hora'));
    await tester.tap(find.text('ACEPTAR'));
    await tester.pumpAndSettle();

    expect(find.text('11:00'), findsOneWidget);
    expect(tester.testTextInput.isVisible, isFalse);
  });

  testWidgets('desde las 23:00, para hoy se proponen las 23:59', (tester) async {
    await openCustomerStep(tester, hour: 23);
    await scrollAndTap(tester, find.text('Hoy'));
    await scrollAndTap(tester, find.text('Elegir hora'));
    await tester.tap(find.text('ACEPTAR'));
    await tester.pumpAndSettle();

    expect(find.text('23:59'), findsOneWidget);
    expect(find.text('Esa hora ya pasó'), findsNothing);
  });

  testWidgets('al enviar un cierre, el siguiente se ve desde arriba', (tester) async {
    await openTab(tester, 'JIM-01', 'Cierre', height: 600, overrides: [
      payoutsRepositoryProvider.overrideWithValue(SendableRepository()),
    ]);
    double offset() => tester
        .state<ScrollableState>(find
            .descendant(of: find.byType(ListView).first, matching: find.byType(Scrollable))
            .first)
        .position
        .pixels;

    final duplicates = find.byWidgetPredicate(
      (w) => w is SquareCheck && w.label == 'Duplicados depurados',
    );
    await scrollUntil(tester, duplicates);
    await tester.tap(duplicates);
    await tester.pumpAndSettle();
    await scrollUntil(tester, find.text('Enviar a Dirección'));
    await tester.tap(find.text('Enviar a Dirección'));
    await tester.pumpAndSettle();
    expect(offset(), greaterThan(0));

    await tester.tap(find.text('Enviar'));
    await tester.pumpAndSettle();

    expect(find.text('Cierre enviado a Dirección.'), findsOneWidget);
    expect(offset(), 0);
    expect(find.text('Cierre de la semana'), findsOneWidget);
  });
}
