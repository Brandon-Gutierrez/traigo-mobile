import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:traigo/app/app.dart';
import 'package:traigo/core/config/app_config.dart';
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

/// Token de una sesión de demo ya iniciada.
MemoryTokenStorage signedInTokens() => MemoryTokenStorage(DemoAuthRepository.demoToken);

/// Pantalla de celular (390 × [height] puntos). Un desbordamiento de
/// contenido hace fallar la prueba, así que sirve para vigilar el diseño.
void useMobileScreen(WidgetTester tester, {double height = 844}) {
  tester.view.physicalSize = Size(390 * 3, height * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

/// Busca un texto que contenga [fragment] ignorando si los espacios son
/// normales o fijos (la app usa espacios fijos para no partir los montos).
Finder findTextContaining(String fragment) => find.byWidgetPredicate(
      (widget) =>
          widget is Text &&
          (widget.data ?? '').replaceAll(' ', ' ').contains(fragment),
    );

ProviderContainer containerOf(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(TraigoApp)));
