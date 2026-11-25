import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Carga las fuentes de la app antes de las pruebas. Sin esto Flutter usa una
/// fuente de relleno mucho más ancha y las comprobaciones de desborde no se
/// parecen a lo que se ve en el celular.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  const families = {
    'Oxanium': ['oxanium/Oxanium-Variable.ttf'],
    'IBMPlexSans': ['ibmplexsans/IBMPlexSans-Variable.ttf'],
    'IBMPlexMono': [
      'ibmplexmono/IBMPlexMono-Regular.ttf',
      'ibmplexmono/IBMPlexMono-Medium.ttf',
      'ibmplexmono/IBMPlexMono-Bold.ttf',
    ],
  };
  for (final MapEntry(key: family, value: files) in families.entries) {
    final loader = FontLoader(family);
    for (final file in files) {
      loader.addFont(rootBundle.load('assets/fonts/$file'));
    }
    await loader.load();
  }
  await testMain();
}
