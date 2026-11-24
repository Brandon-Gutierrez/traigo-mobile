import 'package:flutter/painting.dart';

import 'app_colors.dart';

/// Familias de fuente declaradas en pubspec.yaml.
abstract final class AppFonts {
  static const body = 'Archivo';
  static const mono = 'SpaceMono';
}

/// Estilos de texto del diseño.
///
/// Archivo es una fuente **variable**: además de `fontWeight` se indica el eje
/// `wght` con `fontVariations`, así el peso es el pedido en cualquier
/// plataforma y Flutter no fabrica una negrita falsa encima.
abstract final class AppText {
  static TextStyle body(
    double size,
    FontWeight weight, {
    Color color = AppColors.text,
    double? height,
    double? letterSpacing,
    TextDecoration? decoration,
  }) {
    return TextStyle(
      fontFamily: AppFonts.body,
      fontSize: size,
      fontWeight: weight,
      fontVariations: [FontVariation.weight(weight.value.toDouble())],
      color: color,
      height: height,
      letterSpacing: letterSpacing,
      decoration: decoration,
    );
  }

  /// Para montos: cifras del mismo ancho, así las columnas no «bailan».
  static TextStyle money(
    double size,
    FontWeight weight, {
    Color color = AppColors.text,
    double? height,
  }) {
    return body(size, weight, color: color, height: height)
        .copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
  }

  /// Etiqueta pequeña en mayúsculas («GANASTE HOY»). Nunca menor a 12.
  static TextStyle label({Color color = AppColors.muted}) =>
      body(12, FontWeight.w700, color: color, letterSpacing: 0.6);

  /// Códigos y datos técnicos (TR-0151). Space Mono es estática.
  static TextStyle mono(
    double size, {
    FontWeight weight = FontWeight.w400,
    Color color = AppColors.text,
  }) {
    return TextStyle(
      fontFamily: AppFonts.mono,
      fontSize: size,
      fontWeight: weight,
      color: color,
    );
  }
}

extension WeightedTextStyle on TextStyle {
  /// Cambia el peso manteniendo coherente el eje `wght` de Archivo.
  TextStyle weighted(FontWeight weight) => copyWith(
        fontWeight: weight,
        fontVariations: [FontVariation.weight(weight.value.toDouble())],
      );
}
