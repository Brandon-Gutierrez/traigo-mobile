import 'dart:ui';

/// Colores del diseño «Feria y live» para la app de vendedores.
///
/// Salen del logo (azul y naranja). Regla del diseño: el naranja solo se usa
/// como fondo de acción, nunca como color de texto (no tiene contraste sobre
/// el papel); para dinero y estados se usan el verde y el rojo oscuros.
abstract final class AppColors {
  static const paper = Color(0xFFF5EFE0);
  static const card = Color(0xFFFFFCF3);
  static const kraft = Color(0xFFD8B684);
  static const ink = Color(0xFF0B1F5E);
  static const text = Color(0xFF101A3D);
  static const muted = Color(0xFF5B6385);
  static const line = Color(0xFFDCD3BC);

  static const orange = Color(0xFFFF7A18);
  static const amber = Color(0xFFFFC22E);
  static const blue = Color(0xFF1553D4);

  /// Dinero ganado y estados correctos.
  static const green = Color(0xFF14704A);
  static const greenSoft = Color(0xFFDDF4EA);

  /// Errores, precios bajo el mínimo y stock crítico.
  static const red = Color(0xFFC42B20);
  static const redSoft = Color(0xFFFBE0DC);

  /// Pendiente o por confirmar.
  static const warn = Color(0xFF8A4A00);
  static const warnSoft = Color(0xFFFFF1CC);

  static const blueSoft = Color(0xFFDCE8FF);

  /// Fondo apagado de botones deshabilitados.
  static const disabled = Color(0xFFE7DFC9);
}
