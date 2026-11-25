import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traigo/core/providers.dart';
import 'package:traigo/core/storage/last_code_storage.dart';

import '../../support/test_app.dart';

Finder get codeField => find.byType(TextField);

void main() {
  testWidgets('sin sesión guardada la app abre en el ingreso', (tester) async {
    useMobileScreen(tester, height: 1200);
    await tester.pumpWidget(testApp());
    await tester.pumpAndSettle();

    expect(find.text('Ingresa a Traigo'), findsOneWidget);
    expect(findTextContaining('Si lo olvidaste, pídeselo a Jime.'), findsOneWidget);
    expect(find.text('CÓDIGO'), findsOneWidget);
    expect(find.text('Escribe tu código'), findsOneWidget);
    expect(findTextContaining('Modo demo · PIN 1234'), findsOneWidget);
  });

  testWidgets('el ingreso cabe en un celular chico sin desbordar', (tester) async {
    useMobileScreen(tester, width: 320, height: 640);
    await tester.pumpWidget(testApp());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('precarga el último código y solo falta el PIN', (tester) async {
    useMobileScreen(tester, height: 1200);
    await tester.pumpWidget(testApp(lastCode: MemoryLastCodeStorage('ALI-04')));
    await tester.pumpAndSettle();

    expect(tester.widget<TextField>(codeField).controller!.text, 'ALI-04');
    expect(find.text('Faltan 4 números'), findsOneWidget);
  });

  testWidgets('el botón dice cuánto falta y se habilita con código y 4 números',
      (tester) async {
    useMobileScreen(tester, height: 1200);
    await tester.pumpWidget(testApp());
    await tester.pumpAndSettle();

    await tester.enterText(codeField, 'ali-04');
    await tester.pump();
    expect(find.text('Faltan 4 números'), findsOneWidget);

    await tapDigits(tester, '123');
    expect(find.text('Falta 1 número'), findsOneWidget);

    await tapDigits(tester, '4');
    expect(find.text('Entrar'), findsOneWidget);
  });

  testWidgets('borrar quita el último número', (tester) async {
    useMobileScreen(tester, height: 1200);
    await tester.pumpWidget(testApp(lastCode: MemoryLastCodeStorage('ALI-04')));
    await tester.pumpAndSettle();

    await tapDigits(tester, '12');
    expect(find.text('Faltan 2 números'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('pin-backspace')));
    await tester.pump();
    expect(find.text('Faltan 3 números'), findsOneWidget);
  });

  testWidgets('un PIN incorrecto muestra el error, limpia el PIN y no entra',
      (tester) async {
    useMobileScreen(tester, height: 1200);
    await tester.pumpWidget(testApp(lastCode: MemoryLastCodeStorage('ALI-04')));
    await tester.pumpAndSettle();

    await tapDigits(tester, '9999');
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();

    expect(find.text('Código o PIN incorrectos.'), findsOneWidget);
    expect(find.text('Faltan 4 números'), findsOneWidget);
    expect(find.text('Ingresa a Traigo'), findsOneWidget);
  });

  testWidgets('código y PIN correctos llevan a Inicio y recuerdan el código',
      (tester) async {
    useMobileScreen(tester, height: 1200);
    final lastCode = MemoryLastCodeStorage();
    await tester.pumpWidget(testApp(lastCode: lastCode));
    await tester.pumpAndSettle();

    await tester.enterText(codeField, 'ali-04');
    await tester.pump();
    await tapDigits(tester, '1234');
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();

    expect(find.text('Hola, Alison'), findsOneWidget);
    expect(find.text('Ingresa a Traigo'), findsNothing);
    expect(await lastCode.read(), 'ALI-04');
    expect(await containerOf(tester).read(tokenStorageProvider).read(), isNotNull);
  });
}
