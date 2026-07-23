import 'package:flutter/material.dart';

abstract final class AppPalette {
  static const ink = Color(0xFF2A1830);
  static const aubergine = Color(0xFF552746);
  static const plum = Color(0xFF7B3F67);
  static const persimmon = Color(0xFFE76543);
  static const saffron = Color(0xFFF3B63F);
  static const blush = Color(0xFFF4D8CF);
  static const ivory = Color(0xFFFAF6EE);
  static const paper = Color(0xFFFFFCF7);
  static const muted = Color(0xFF756A72);
}

ThemeData buildAppTheme(Locale locale) {
  final fontFamily = locale.languageCode == 'bn'
      ? 'NotoSansBengali'
      : 'Manrope';
  final baseTextTheme = ThemeData.light().textTheme.apply(
    fontFamily: fontFamily,
    bodyColor: AppPalette.ink,
    displayColor: AppPalette.ink,
  );
  final textTheme = baseTextTheme.copyWith(
    displayLarge: baseTextTheme.displayLarge?.copyWith(
      fontWeight: FontWeight.w800,
    ),
    displayMedium: baseTextTheme.displayMedium?.copyWith(
      fontWeight: FontWeight.w800,
    ),
    displaySmall: baseTextTheme.displaySmall?.copyWith(
      fontWeight: FontWeight.w800,
    ),
    headlineLarge: baseTextTheme.headlineLarge?.copyWith(
      fontWeight: FontWeight.w800,
    ),
    headlineMedium: baseTextTheme.headlineMedium?.copyWith(
      fontWeight: FontWeight.w800,
    ),
    headlineSmall: baseTextTheme.headlineSmall?.copyWith(
      fontWeight: FontWeight.w800,
    ),
    titleLarge: baseTextTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
    titleMedium: baseTextTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w800,
    ),
    titleSmall: baseTextTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
    bodyLarge: baseTextTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
    bodyMedium: baseTextTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
    bodySmall: baseTextTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
    labelLarge: baseTextTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
    labelMedium: baseTextTheme.labelMedium?.copyWith(
      fontWeight: FontWeight.w700,
    ),
    labelSmall: baseTextTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700),
  );
  final scheme =
      ColorScheme.fromSeed(
        seedColor: AppPalette.aubergine,
        brightness: Brightness.light,
        surface: AppPalette.paper,
      ).copyWith(
        primary: AppPalette.aubergine,
        onPrimary: Colors.white,
        secondary: AppPalette.persimmon,
        onSecondary: Colors.white,
        tertiary: AppPalette.saffron,
        onTertiary: AppPalette.ink,
        surface: AppPalette.paper,
        onSurface: AppPalette.ink,
        outline: AppPalette.plum.withValues(alpha: 0.28),
      );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppPalette.ivory,
    fontFamily: fontFamily,
    fontFamilyFallback: const ['NotoSansBengali', 'Manrope', 'sans-serif'],
    textTheme: textTheme,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppPalette.ivory,
      foregroundColor: AppPalette.ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      titleTextStyle: TextStyle(
        fontFamily: 'Manrope',
        color: AppPalette.ink,
        fontSize: 22,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.4,
      ),
    ),
    cardTheme: CardThemeData(
      color: AppPalette.paper,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: AppPalette.plum.withValues(alpha: 0.14)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppPalette.paper,
      labelStyle: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
      floatingLabelStyle: textTheme.bodyLarge?.copyWith(
        color: AppPalette.aubergine,
        fontWeight: FontWeight.w800,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.outline),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        borderSide: BorderSide(color: AppPalette.persimmon, width: 2),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppPalette.aubergine,
        foregroundColor: Colors.white,
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppPalette.aubergine,
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
        side: BorderSide(color: scheme.outline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppPalette.aubergine,
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
    listTileTheme: ListTileThemeData(
      titleTextStyle: textTheme.bodyLarge?.copyWith(
        fontWeight: FontWeight.w700,
      ),
      subtitleTextStyle: textTheme.bodyMedium?.copyWith(
        color: AppPalette.muted,
        fontWeight: FontWeight.w600,
      ),
    ),
    dialogTheme: DialogThemeData(
      titleTextStyle: textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w800,
      ),
      contentTextStyle: textTheme.bodyMedium?.copyWith(
        fontWeight: FontWeight.w700,
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: AppPalette.ink,
      contentTextStyle: TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w700,
      ),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
