/// De dónde salen los datos de la app.
enum DataMode {
  /// Datos de prueba en memoria. No necesita backend.
  demo,

  /// API real de Laravel (ver docs/api-contract.md).
  live,
}

/// Configuración que se decide al compilar con `--dart-define`.
///
/// Demo (por defecto):
///   flutter run
/// Contra el backend:
///   flutter run --dart-define=API_MODE=live --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1
///
/// `10.0.2.2` es el localhost de tu PC visto desde el emulador de Android.
/// En un celular físico usa la IP de tu PC en la red local.
class AppConfig {
  const AppConfig({
    required this.mode,
    required this.baseUrl,
    this.demoLatency = const Duration(milliseconds: 350),
  });

  factory AppConfig.fromEnvironment() {
    const mode = String.fromEnvironment('API_MODE', defaultValue: 'demo');
    const baseUrl = String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://10.0.2.2:8000/api/v1',
    );
    return AppConfig(
      mode: mode == 'live' ? DataMode.live : DataMode.demo,
      baseUrl: baseUrl,
    );
  }

  final DataMode mode;

  /// Incluye el prefijo de versión, sin barra final. Ej: https://api.traigo.bo/api/v1
  final String baseUrl;

  /// Espera artificial en modo demo para ver los estados de carga.
  final Duration demoLatency;

  bool get isDemo => mode == DataMode.demo;
}
