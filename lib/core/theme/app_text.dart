import 'package:flutter/painting.dart';

import 'app_colors.dart';

/// Familias de fuente declaradas en pubspec.yaml.
abstract final class AppFonts {
  static const display = 'Oxanium';
  static const body = 'IBMPlexSans';
  static const mono = 'IBMPlexMono';
}

/// Estilos de texto del diseño.
///
/// Oxanium e IBM Plex Sans son **variables**: además de `fontWeight` se indica el
/// eje `wght` con `fontVariations`, así el peso es el pedido en cualquier
/// plataforma. IBM Plex Mono es estática (400, 500 y 700).
abstract final class AppText {
  /// Títulos, cifras grandes y botones.
  static TextStyle display(
    double size, {
    FontWeight weight = FontWeight.w700,
    Color color = AppColors.ink,
    double? height,
  }) {
    return TextStyle(
      fontFamily: AppFonts.display,
      fontSize: size,
      fontWeight: weight,
      fontVariations: [FontVariation.weight(weight.value.toDouble())],
      fontFeatures: const [FontFeature.tabularFigures()],
      color: color,
      height: height,
    );
  }

  static TextStyle body(
    double size,
    FontWeight weight, {
    Color color = AppColors.ink,
    double? height,
    TextDecoration? decoration,
  }) {
    return TextStyle(
      fontFamily: AppFonts.body,
      fontSize: size,
      fontWeight: weight,
      fontVariations: [FontVariation.weight(weight.value.toDouble())],
      color: color,
      height: height,
      decoration: decoration,
      decorationColor: color,
    );
  }

  /// Cifras de ficha (montos y datos alineados).
  static TextStyle mono(
    double size, {
    FontWeight weight = FontWeight.w400,
    Color color = AppColors.ink,
    double? letterSpacing,
  }) {
    return TextStyle(
      fontFamily: AppFonts.mono,
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: letterSpacing,
    );
  }

  /// Etiqueta de sección en mayúsculas («BONO DEL EQUIPO»). Nunca menor a 12.
  static TextStyle label({Color color = AppColors.muted}) =>
      mono(12, weight: FontWeight.w700, color: color, letterSpacing: 0.7);
}
