import 'package:flutter/material.dart';

class AppTheme {
  static const Color charcoal = Color(0xFF0F2A33);
  static const Color background = Color(0xFFF4F7F6);
  static const Color surfaceWhite = Color(0xFFFFFFFF);
  static const Color accentTeal = Color(0xFF0A8F86);
  static const Color deepTeal = Color(0xFF06505A);
  static const Color warningGold = Color(0xFFE8A13A);

  static const Color mutedText = Color(0xFF5B7078);
  static const Color lightBorder = Color(0xFFE1E8E6);
  static const Color darkBackground = Color(0xFF08191D);
  static const Color darkSurface = Color(0xFF073C42);
  static const Color darkBorder = Color(0xFF14626B);
  static const Color darkText = Color(0xFFF4F7F6);
  static const Color darkMutedText = Color(0xFF9FB6B9);

  static ThemeData get lightTheme {
    const colorScheme = ColorScheme.light(
      primary: deepTeal,
      secondary: accentTeal,
      tertiary: warningGold,
      error: Color(0xFFE2574C),
      surface: surfaceWhite,
      onSurface: charcoal,
      onSurfaceVariant: mutedText,
      outlineVariant: lightBorder,
      primaryContainer: Color(0xFFE2F3F0),
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: 'PlusJakartaSans',
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        foregroundColor: charcoal,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: surfaceWhite,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: lightBorder, width: 1),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(backgroundColor: background),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceWhite,
        hintStyle: const TextStyle(color: Color(0xFF8DA0A6)),
        labelStyle: const TextStyle(color: mutedText, fontSize: 12.5, fontWeight: FontWeight.w700),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 17,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: lightBorder, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: lightBorder, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: accentTeal, width: 2),
        ),
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: charcoal, fontFamily: 'PlusJakartaSans', fontSize: 14, fontWeight: FontWeight.w400),
        bodyMedium: TextStyle(color: charcoal, fontFamily: 'PlusJakartaSans', fontSize: 14, fontWeight: FontWeight.w400),
        titleLarge: TextStyle(color: charcoal, fontFamily: 'PlusJakartaSans', fontSize: 25, fontWeight: FontWeight.w800, letterSpacing: -0.6),
        titleMedium: TextStyle(color: charcoal, fontFamily: 'PlusJakartaSans', fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: -0.3),
        titleSmall: TextStyle(color: charcoal, fontFamily: 'PlusJakartaSans', fontSize: 15, fontWeight: FontWeight.w700),
      ),
    );
  }

  static ThemeData get darkTheme {
    const colorScheme = ColorScheme.dark(
      primary: accentTeal,
      secondary: accentTeal,
      tertiary: warningGold,
      error: Color(0xFFE2574C),
      surface: darkSurface,
      onSurface: darkText,
      onSurfaceVariant: darkMutedText,
      outlineVariant: darkBorder,
      primaryContainer: Color(0xFF0B525A),
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: 'PlusJakartaSans',
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: darkBackground,
      appBarTheme: const AppBarTheme(
        backgroundColor: darkBackground,
        foregroundColor: darkText,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: darkBorder, width: 1),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: darkSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: darkBackground,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkSurface,
        hintStyle: const TextStyle(color: Color(0xFF8DA0A6)),
        labelStyle: const TextStyle(color: darkMutedText, fontSize: 12.5, fontWeight: FontWeight.w700),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 17,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: darkBorder, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: darkBorder, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: accentTeal, width: 2),
        ),
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: darkText, fontFamily: 'PlusJakartaSans', fontSize: 14, fontWeight: FontWeight.w400),
        bodyMedium: TextStyle(color: darkText, fontFamily: 'PlusJakartaSans', fontSize: 14, fontWeight: FontWeight.w400),
        titleLarge: TextStyle(color: darkText, fontFamily: 'PlusJakartaSans', fontSize: 25, fontWeight: FontWeight.w800, letterSpacing: -0.6),
        titleMedium: TextStyle(color: darkText, fontFamily: 'PlusJakartaSans', fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: -0.3),
        titleSmall: TextStyle(color: darkText, fontFamily: 'PlusJakartaSans', fontSize: 15, fontWeight: FontWeight.w700),
      ),
    );
  }
}
