import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_text.dart';

export 'app_colors.dart';
export 'app_text.dart';

abstract final class AppTheme {
  static ThemeData light() {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.violet,
      onPrimary: AppColors.bg,
      secondary: AppColors.cyan,
      onSecondary: AppColors.ink,
      error: AppColors.alert,
      onError: AppColors.bg,
      surface: AppColors.bg,
      onSurface: AppColors.ink,
      outline: AppColors.ink,
      outlineVariant: AppColors.rule,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.bg,
      fontFamily: AppFonts.body,
      splashFactory: InkRipple.splashFactory,
    );

    const underline = UnderlineInputBorder(
      borderRadius: BorderRadius.zero,
      borderSide: BorderSide(color: AppColors.ink, width: 3),
    );

    return base.copyWith(
      textTheme: base.textTheme.copyWith(
        headlineMedium: AppText.display(30, height: 1.1),
        titleLarge: AppText.display(24, height: 1.15),
        bodyLarge: AppText.body(16, FontWeight.w400),
        bodyMedium: AppText.body(15, FontWeight.w400),
        bodySmall: AppText.body(13, FontWeight.w400, color: AppColors.muted),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.rule, thickness: 2, space: 2),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.violet),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: AppColors.violet,
        selectionColor: AppColors.rule,
        selectionHandleColor: AppColors.violet,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.alt,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: underline,
        enabledBorder: underline,
        disabledBorder: underline,
        focusedBorder: underline.copyWith(
          borderSide: const BorderSide(color: AppColors.violet, width: 3),
        ),
        hintStyle: AppText.mono(20, color: AppColors.muted),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        shape: BeveledRectangleBorder(
          borderRadius: BorderRadius.only(topRight: Radius.circular(18)),
          side: BorderSide(color: AppColors.ink, width: 3),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.ink,
        contentTextStyle: AppText.body(14.5, FontWeight.w600, color: AppColors.bg),
        behavior: SnackBarBehavior.fixed,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        shape: const BeveledRectangleBorder(
          borderRadius: BorderRadius.only(topRight: Radius.circular(14)),
          side: BorderSide(color: AppColors.ink, width: 3),
        ),
        titleTextStyle: AppText.display(22),
        contentTextStyle: AppText.body(15, FontWeight.w400),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.ink,
          minimumSize: const Size(64, 44),
          textStyle: AppText.body(15, FontWeight.w600),
        ),
      ),
    );
  }
}
