import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_text.dart';

export 'app_text.dart' show AppFonts, AppText, WeightedTextStyle;

abstract final class AppTheme {
  static ThemeData light() {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.orange,
      onPrimary: AppColors.ink,
      secondary: AppColors.ink,
      onSecondary: AppColors.card,
      error: AppColors.red,
      onError: AppColors.card,
      surface: AppColors.card,
      onSurface: AppColors.text,
      outline: AppColors.ink,
      outlineVariant: AppColors.line,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.paper,
      fontFamily: AppFonts.body,
      splashFactory: InkRipple.splashFactory,
    );

    return base.copyWith(
      textTheme: _textTheme(base.textTheme),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.paper,
        foregroundColor: AppColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      dividerTheme: const DividerThemeData(color: AppColors.line, thickness: 2, space: 2),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.ink),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: AppColors.ink,
        selectionColor: AppColors.amber,
        selectionHandleColor: AppColors.ink,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: AppColors.card,
        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: AppColors.ink, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: AppColors.ink, width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: AppColors.orange, width: 3),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: AppColors.red, width: 2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: AppColors.red, width: 3),
        ),
        hintStyle: TextStyle(color: AppColors.muted),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.card,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          side: BorderSide(color: AppColors.ink, width: 2),
        ),
        titleTextStyle: AppText.body(20, FontWeight.w800, color: AppColors.ink),
        contentTextStyle: AppText.body(15, FontWeight.w500),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.ink,
        contentTextStyle: AppText.body(14, FontWeight.w600, color: AppColors.card),
        shape: const RoundedRectangleBorder(),
      ),
    );
  }

  /// Escala tipográfica del diseño: títulos de 30, texto de 15 y etiquetas
  /// de 12 en mayúsculas. Nada por debajo de 12.
  static TextTheme _textTheme(TextTheme base) {
    return base.copyWith(
      headlineLarge: AppText.body(46, FontWeight.w800, color: AppColors.ink, height: 1.05),
      headlineMedium: AppText.body(30, FontWeight.w800, color: AppColors.ink, height: 1.05),
      titleLarge: AppText.body(22, FontWeight.w800, color: AppColors.ink),
      titleMedium: AppText.body(18, FontWeight.w800, color: AppColors.ink),
      titleSmall: AppText.body(16, FontWeight.w800),
      bodyLarge: AppText.body(16, FontWeight.w500),
      bodyMedium: AppText.body(15, FontWeight.w500),
      bodySmall: AppText.body(13, FontWeight.w500, color: AppColors.muted),
      labelLarge: AppText.body(19, FontWeight.w800, color: AppColors.ink),
      labelMedium: AppText.body(14, FontWeight.w700),
      labelSmall: AppText.label(),
    );
  }
}
