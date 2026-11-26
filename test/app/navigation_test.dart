import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traigo/app/app_bottom_bar.dart';
import 'package:traigo/app/router.dart';
import 'package:traigo/core/providers.dart';

import '../support/test_app.dart';

/// Barra inferior y acceso a pantallas según el rol.
void main() {
  Future<void> openAs(WidgetTester tester, String code) async {
    useMobileScreen(tester);
    await tester.pumpWidget(testApp(tokens: signedInTokens(code)));
    await tester.pumpAndSettle();
  }

  /// Los nombres de la barra, de izquierda a derecha.
  List<String> barLabels(WidgetTester tester) => tester
      .widget<AppBottomBar>(find.byType(AppBottomBar))
      .items
      .map((item) => item.label)
      .toList();

  List<String> member(String central) =>
      ['Inicio', 'Catálogo', central, 'Equipo', 'Mi semana'];

  final bars = {
    'ALI-04': member('Vender'),
    'KIM-05': member('Vender'),
    'ISA-03': member('Caja'),
    'AIL-02': member('Evidencia'),
    'SIS-06': member('Evidencia'),
    'SIS-07': member('Evidencia'),
    'JIM-01': ['Resumen', 'Pendientes', 'Cierre', 'Bonos', 'Más'],
    'DIR-08': ['Resumen', 'Bonos', 'Autorizar', 'Comisiones', 'Más'],
  };

  for (final MapEntry(key: code, value: labels) in bars.entries) {
    testWidgets('la barra de $code es ${labels.join(', ')}', (tester) async {
      await openAs(tester, code);

      expect(barLabels(tester), labels);
      final items = tester.widget<AppBottomBar>(find.byType(AppBottomBar)).items;
      expect(items.indexWhere((i) => i.central), 2, reason: 'la acción va al centro');
    });

    testWidgets('todas las pestañas de $code abren sin errores', (tester) async {
      await openAs(tester, code);

      for (final label in labels.reversed) {
        await tester.tap(
          find.descendant(of: find.byType(AppBottomBar), matching: find.text(label)),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: label);
      }
    });
  }

  testWidgets('la barra de Jime muestra cuántas cosas hay por revisar', (tester) async {
    await openAs(tester, 'JIM-01');

    expect(find.bySemanticsLabel('Pendientes, 7 por revisar'), findsOneWidget);
    expect(
      find.descendant(of: find.byType(AppBottomBar), matching: find.text('7')),
      findsOneWidget,
    );
  });

  testWidgets('la barra cabe en 320 de ancho con letra grande', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    useMobileScreen(tester, width: 320, height: 700);
    await tester.pumpWidget(testApp(tokens: signedInTokens('DIR-08')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: find.byType(AppBottomBar), matching: find.text('Comisiones')),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  group('acceso por rol', () {
    Future<String> goTo(WidgetTester tester, String route) async {
      final router = containerOf(tester).read(routerProvider);
      router.go(route);
      await tester.pumpAndSettle();
      return router.routerDelegate.currentConfiguration.uri.path;
    }

    testWidgets('quien vende no entra a la caja ni al panel de control', (tester) async {
      await openAs(tester, 'ALI-04');

      expect(await goTo(tester, AppRoutes.cash), AppRoutes.home);
      expect(await goTo(tester, AppRoutes.summary), AppRoutes.home);
      expect(await goTo(tester, AppRoutes.pending), AppRoutes.home);
      expect(await goTo(tester, AppRoutes.sell), AppRoutes.sell);
    });

    testWidgets('Jime no entra a las pantallas del equipo ni a autorizar', (tester) async {
      await openAs(tester, 'JIM-01');

      expect(await goTo(tester, AppRoutes.home), AppRoutes.summary);
      expect(await goTo(tester, AppRoutes.sell), AppRoutes.summary);
      expect(await goTo(tester, AppRoutes.approve), AppRoutes.summary);
      expect(await goTo(tester, AppRoutes.close), AppRoutes.close);
    });

    testWidgets('sin sesión no se entra a ninguna pantalla', (tester) async {
      useMobileScreen(tester);
      await tester.pumpWidget(testApp());
      await tester.pumpAndSettle();

      expect(await goTo(tester, AppRoutes.home), AppRoutes.login);
      expect(await goTo(tester, AppRoutes.verify), AppRoutes.login);
    });
  });

  group('cerrar sesión', () {
    testWidgets('pide confirmación y, si se cancela, la sesión sigue', (tester) async {
      useMobileScreen(tester);
      final tokens = signedInTokens();
      await tester.pumpWidget(testApp(tokens: tokens));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Cerrar sesión'));
      await tester.pumpAndSettle();
      expect(find.text('¿Cerrar sesión?'), findsOneWidget);

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(find.text('Hola, Alison'), findsOneWidget);
      expect(await tokens.read(), isNotNull);
    });

    testWidgets('al entrar otra persona no queda nada de la anterior', (tester) async {
      useMobileScreen(tester, height: 1200);
      final tokens = signedInTokens('ALI-04');
      await tester.pumpWidget(testApp(tokens: tokens));
      await tester.pumpAndSettle();
      expect(find.text('Mariela Quispe · QR'), findsOneWidget);

      await tester.tap(find.byTooltip('Cerrar sesión'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Cerrar sesión'));
      await tester.pumpAndSettle();

      expect(find.text('Ingresa a Traigo'), findsOneWidget);
      expect(await tokens.read(), isNull);

      await tester.enterText(find.byType(TextField), 'ISA-03');
      await tester.pump();
      await tapDigits(tester, '1234');
      await tester.tap(find.text('Entrar'));
      await tester.pumpAndSettle();

      expect(find.text('Hola, Isaí'), findsOneWidget);
      expect(find.text('Mariela Quispe · QR'), findsNothing);
      expect(barLabels(tester), member('Caja'));
    });

    testWidgets('si el servidor da por vencida la sesión, vuelve al ingreso',
        (tester) async {
      await openAs(tester, 'ALI-04');

      containerOf(tester).read(sessionExpiredProvider.notifier).fire();
      await tester.pumpAndSettle();

      expect(find.text('Ingresa a Traigo'), findsOneWidget);
      expect(await containerOf(tester).read(tokenStorageProvider).read(), isNull);
    });
  });
}
