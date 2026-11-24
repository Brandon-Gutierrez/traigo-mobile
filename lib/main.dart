import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
