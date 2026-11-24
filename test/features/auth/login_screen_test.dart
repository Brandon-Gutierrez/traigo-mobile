import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traigo/core/providers.dart';
import 'package:traigo/core/storage/last_code_storage.dart';

import '../../support/test_app.dart';

Future<void> tapPin(WidgetTester tester, String digits) async {
  for (final digit in digits.split('')) {
    await tester.tap(find.byKey(ValueKey('pin-key-$digit')));
    await tester.pump();
  }
}

Finder get codeField => find.byType(TextField);

void main() {
  testWidgets('sin sesión guardada la app abre en el ingreso', (tester) async {
    useMobileScreen(tester, height: 1200);
    await tester.pumpWidget(testApp());
    await tester.pumpAndSettle();

    expect(find.text('Ingresa a Traigo'), findsOneWidget);
    expect(find.text('CÓDIGO DE VENDEDOR'), findsOneWidget);
    expect(find.text('Escribe tu código'), findsOneWidget);
    expect(find.textContaining('Modo demo'), findsOneWidget);
  });

  testWidgets('el ingreso cabe en un celular sin desbordar', (tester) async {
    useMobileScreen(tester);
    await tester.pumpWidget(testApp());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('precarga el último código y solo falta el PIN', (tester) async {
    useMobileScreen(tester, height: 1200);
    await tester.pumpWidget(testApp(lastCode: MemoryLastCodeStorage('ANA-07')));
    await tester.pumpAndSettle();

    expect(tester.widget<TextField>(codeField).controller!.text, 'ANA-07');
    expect(find.text('Faltan 4 números'), findsOneWidget);
  });

  testWidgets('el botón dice cuánto falta y se habilita con código y 4 números', (tester) async {
    useMobileScreen(tester, height: 1200);
    await tester.pumpWidget(testApp());
    await tester.pumpAndSettle();

    await tester.enterText(codeField, 'ana-07');
    await tester.pump();
    expect(find.text('Faltan 4 números'), findsOneWidget);

    await tapPin(tester, '123');
    expect(find.text('Faltan 1 número'), findsOneWidget);

    await tapPin(tester, '4');
    expect(find.text('Entrar'), findsOneWidget);
  });

  testWidgets('borrar quita el último número', (tester) async {
    useMobileScreen(tester, height: 1200);
    await tester.pumpWidget(testApp(lastCode: MemoryLastCodeStorage('ANA-07')));
    await tester.pumpAndSettle();

    await tapPin(tester, '12');
    expect(find.text('Faltan 2 números'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('pin-backspace')));
    await tester.pump();
    expect(find.text('Faltan 3 números'), findsOneWidget);
  });

  testWidgets('un PIN incorrecto muestra el error, limpia el PIN y no entra', (tester) async {
    useMobileScreen(tester, height: 1200);
    await tester.pumpWidget(testApp(lastCode: MemoryLastCodeStorage('ANA-07')));
    await tester.pumpAndSettle();

    await tapPin(tester, '9999');
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();

    expect(find.text('Código o PIN incorrectos.'), findsOneWidget);
    expect(find.text('Faltan 4 números'), findsOneWidget);
    expect(find.text('Ingresa a Traigo'), findsOneWidget);
  });

  testWidgets('código y PIN correctos llevan a Inicio y recuerdan el código', (tester) async {
    useMobileScreen(tester, height: 1200);
    final lastCode = MemoryLastCodeStorage();
    await tester.pumpWidget(testApp(lastCode: lastCode));
    await tester.pumpAndSettle();

    await tester.enterText(codeField, 'ana-07');
    await tester.pump();
    await tapPin(tester, '1234');
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();

    expect(find.text('Hola, Ana'), findsOneWidget);
    expect(find.text('Ingresa a Traigo'), findsNothing);
    expect(await lastCode.read(), 'ANA-07');
    expect(await containerOf(tester).read(tokenStorageProvider).read(), isNotNull);
  });
}
