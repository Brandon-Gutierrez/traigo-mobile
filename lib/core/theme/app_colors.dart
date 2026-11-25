import 'dart:ui';

/// Colores del diseño «Ficha técnica» (opción C).
///
/// La paleta se midió en los archivos oficiales de la marca. Reglas de uso:
/// - [violet] actúa y marca el dinero. Sirve como texto sobre blanco (7,1:1).
/// - [cyan] es solo relleno: el bloque del día y la pestaña activa. Sobre blanco
///   no se lee como texto (1,5:1); con tinta encima sí (11,9:1).
/// - [alert] es la única alerta, para lo que bloquea o no cumple.
/// - El degradado vive solo dentro del logo.
abstract final class AppColors {
  static const bg = Color(0xFFFFFFFF);
  static const alt = Color(0xFFF3F1F8);
  static const off = Color(0xFFE6E2F0);
  static const ink = Color(0xFF150A3B);
  static const muted = Color(0xFF5B5478);
  static const rule = Color(0xFFDCD7EA);
  static const dot = Color(0xFFB3AACD);

  static const violet = Color(0xFF5F11FA);
  static const cyan = Color(0xFF0CE8DC);
  static const sky = Color(0xFF0CB5F8);
  static const lilac = Color(0xFFA83FFE);
  static const alert = Color(0xFFD4243B);
}
