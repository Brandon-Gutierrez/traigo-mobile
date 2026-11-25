import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  _addFontLicenses();
  runApp(
    ProviderScope(
      // Riverpod 3 reintenta solo las cargas que fallan, y mientras tanto se
      // vería un «cargando» eterno. Aquí el error se muestra enseguida con su
      // botón «Reintentar».
      retry: (retryCount, error) => null,
      child: const TraigoApp(),
    ),
  );
}

/// Las fuentes usan la licencia OFL; se muestran con las demás licencias.
void _addFontLicenses() {
  const licenses = {
    'Oxanium': 'assets/fonts/oxanium/OFL.txt',
    'IBM Plex Sans': 'assets/fonts/ibmplexsans/OFL.txt',
    'IBM Plex Mono': 'assets/fonts/ibmplexmono/OFL.txt',
  };
  LicenseRegistry.addLicense(() async* {
    for (final MapEntry(key: family, value: path) in licenses.entries) {
      yield LicenseEntryWithLineBreaks([family], await rootBundle.loadString(path));
    }
  });
}
