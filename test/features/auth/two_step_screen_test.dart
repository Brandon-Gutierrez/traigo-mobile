import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traigo/core/providers.dart';
import 'package:traigo/core/storage/last_code_storage.dart';
import 'package:traigo/core/storage/token_storage.dart';

import '../../support/test_app.dart';

/// Ingreso de Jime y Dirección, con un reloj que la prueba adelanta a mano.
void main() {
  late DateTime now;
  late MemoryTokenStorage tokens;
  late MemoryLastCodeStorage lastCode;

  setUp(() {
    now = DateTime(2026, 12, 6, 18);
    tokens = MemoryTokenStorage();
    lastCode = MemoryLastCodeStorage('JIM-01');
  });

  /// Pasa el primer paso con código y PIN.
  Future<void> openSecondStep(WidgetTester tester, {double height = 1200}) async {
    useMobileScreen(tester, height: height);
    await tester.pumpWidget(testApp(
      tokens: tokens,
      lastCode: lastCode,
      overrides: [clockProvider.overrideWithValue(() => now)],
    ));
    await tester.pumpAndSettle();
    await tapDigits(tester, '1234');
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();
  }

  /// Adelanta el reloj y deja que la cuenta regresiva se redibuje.
  Future<void> advance(WidgetTester tester, Duration time) async {
    now = now.add(time);
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('Jime pasa por el segundo paso y todavía no tiene sesión', (tester) async {
    await openSecondStep(tester);

    expect(find.text('Verificación en dos pasos'), findsOneWidget);
    expect(findTextContaining('Vence en 05:00.'), findsOneWidget);
    expect(find.text('Reenviar el código en 00:45'), findsOneWidget);
    expect(find.text('Faltan 6 números'), findsOneWidget);
    expect(await tokens.read(), isNull);
  });

  testWidgets('un código equivocado muestra el error y deja escribirlo otra vez',
      (tester) async {
    await openSecondStep(tester);

    await tapDigits(tester, '111111');
    await scrollAndTap(tester, find.text('Verificar'));

    expect(find.text('El código no es correcto.'), findsOneWidget);
    expect(find.text('Faltan 6 números'), findsOneWidget);
    expect(await tokens.read(), isNull);
  });

  testWidgets('el código correcto abre el Resumen de Jime', (tester) async {
    await openSecondStep(tester);

    await tapDigits(tester, '123456');
    await scrollAndTap(tester, find.text('Verificar'));

    expect(find.text('Hola, Jime'), findsOneWidget);
    expect(find.text('CONTROL · JIM-01'), findsOneWidget);
    expect(await tokens.read(), isNotNull);
    expect(await lastCode.read(), 'JIM-01');
  });

  testWidgets('después de la espera se puede pedir otro código', (tester) async {
    await openSecondStep(tester);

    await advance(tester, const Duration(seconds: 46));
    expect(find.textContaining('Reenviar el código en'), findsNothing);

    await scrollAndTap(tester, find.text('Reenviar código'));
    expect(find.text('Reenviar el código en 00:45'), findsOneWidget);
    expect(findTextContaining('Vence en 05:00.'), findsOneWidget);
  });

  testWidgets('un código vencido avisa y no entra', (tester) async {
    await openSecondStep(tester);

    await advance(tester, const Duration(minutes: 6));
    expect(findTextContaining('El código venció: pide uno nuevo.'), findsOneWidget);

    await tapDigits(tester, '123456');
    await scrollAndTap(tester, find.text('Verificar'));
    expect(find.text('El código venció. Pide uno nuevo.'), findsOneWidget);
    expect(await tokens.read(), isNull);
  });

  testWidgets('«Volver» regresa al ingreso con el código puesto', (tester) async {
    lastCode = MemoryLastCodeStorage('JIM-01');
    await openSecondStep(tester);

    await scrollAndTap(tester, find.text('Volver'));

    expect(find.text('Ingresa a Traigo'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, 'JIM-01');
  });

  testWidgets('el botón atrás del celular también vuelve al ingreso', (tester) async {
    await openSecondStep(tester);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Ingresa a Traigo'), findsOneWidget);
  });

  testWidgets('los 6 recuadros caben en un celular chico', (tester) async {
    useMobileScreen(tester, width: 320, height: 640);
    await tester.pumpWidget(testApp(lastCode: lastCode));
    await tester.pumpAndSettle();
    for (final digit in '1234'.split('')) {
      await scrollAndTap(tester, find.byKey(ValueKey('pin-key-$digit')));
    }
    await scrollAndTap(tester, find.text('Entrar'));

    expect(find.text('Verificación en dos pasos'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
