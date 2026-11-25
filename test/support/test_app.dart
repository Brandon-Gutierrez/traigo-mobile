import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:traigo/app/app.dart';
import 'package:traigo/core/config/app_config.dart';
import 'package:traigo/core/demo/demo_backend.dart';
import 'package:traigo/core/demo/demo_repositories.dart';
import 'package:traigo/core/providers.dart';
import 'package:traigo/core/storage/last_code_storage.dart';
import 'package:traigo/core/storage/token_storage.dart';

/// La app completa en modo demo, sin espera artificial y con almacenamiento
/// en memoria (los plugins del sistema no existen en las pruebas).
Widget testApp({
  MemoryTokenStorage? tokens,
  MemoryLastCodeStorage? lastCode,
  Duration latency = Duration.zero,
  List<Override> overrides = const [],
}) {
  return ProviderScope(
    retry: (retryCount, error) => null,
    overrides: [
      appConfigProvider.overrideWithValue(
        AppConfig(mode: DataMode.demo, baseUrl: '', demoLatency: latency),
      ),
      tokenStorageProvider.overrideWithValue(tokens ?? MemoryTokenStorage()),
      lastCodeStorageProvider.overrideWithValue(lastCode ?? MemoryLastCodeStorage()),
      ...overrides,
    ],
    child: const TraigoApp(),
  );
}

/// Token de una sesión de demo ya iniciada con el integrante [code].
MemoryTokenStorage signedInTokens([String code = 'ALI-04']) => MemoryTokenStorage(
      DemoAuthRepository.tokenFor(DemoBackend.members.firstWhere((m) => m.code == code).id),
    );

/// Pantalla de celular ([width] × [height] puntos). Un desbordamiento de
/// contenido hace fallar la prueba, así que sirve para vigilar el diseño.
void useMobileScreen(WidgetTester tester, {double width = 390, double height = 844}) {
  tester.view.physicalSize = Size(width * 3, height * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

/// Busca un texto que contenga [fragment] ignorando si los espacios son
/// normales o fijos (la app usa espacios fijos para no partir los montos).
Finder findTextContaining(String fragment) => find.byWidgetPredicate(
      (widget) =>
          widget is Text &&
          (widget.data ?? '').replaceAll(String.fromCharCode(0xA0), ' ').contains(fragment),
    );

ProviderContainer containerOf(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(TraigoApp)));

/// Escribe en el teclado numérico de la app.
Future<void> tapDigits(WidgetTester tester, String digits) async {
  for (final digit in digits.split('')) {
    await tester.tap(find.byKey(ValueKey('pin-key-$digit')));
    await tester.pump();
  }
}

/// Toca [finder] aunque esté más abajo en una pantalla con desplazamiento.
Future<void> scrollAndTap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Desplaza la pantalla hasta que [finder] se pueda tocar.
Future<void> scrollUntil(WidgetTester tester, Finder finder, {bool up = false}) async {
  await tester.scrollUntilVisible(
    finder,
    up ? -150 : 150,
    scrollable: find.descendant(
      of: find.byType(ListView).first,
      matching: find.byType(Scrollable),
    ).first,
  );
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}
