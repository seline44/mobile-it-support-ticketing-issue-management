import 'package:flutter/material.dart';

class AppTheme {
  static const Color charcoal = Color(0xFF252B30);
  static const Color background = Color(0xFFF4F6F5);
  static const Color surfaceWhite = Color(0xFFFFFFFF);
  static const Color accentTeal = Color(0xFF287C80);
  static const Color warningGold = Color(0xFFD5A64B);

  static const Color mutedText = Color(0xFF626B70);
  static const Color lightBorder = Color(0xFFD9DEDC);
  static const Color darkBackground = Color(0xFF171C20);
  static const Color darkSurface = Color(0xFF252B30);
  static const Color darkBorder = Color(0xFF41494E);
  static const Color darkText = Color(0xFFF4F6F5);
  static const Color darkMutedText = Color(0xFFB8C0C2);

  static ThemeData get lightTheme {
    const colorScheme = ColorScheme.light(
      primary: accentTeal,
      onPrimary: surfaceWhite,
      secondary: accentTeal,
      onSecondary: surfaceWhite,
      tertiary: warningGold,
      onTertiary: surfaceWhite,
      surface: surfaceWhite,
      onSurface: charcoal,
      onSurfaceVariant: mutedText,
      outline: lightBorder,
      outlineVariant: lightBorder,
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Roboto',
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      appBarTheme: const AppBarTheme(
        backgroundColor: charcoal,
        foregroundColor: surfaceWhite,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: surfaceWhite,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: lightBorder),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(backgroundColor: background),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceWhite,
        hintStyle: const TextStyle(color: mutedText),
        labelStyle: const TextStyle(color: mutedText),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 17,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: lightBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: lightBorder, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: charcoal, width: 2),
        ),
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: charcoal, fontFamily: 'Roboto'),
        bodyMedium: TextStyle(color: charcoal, fontFamily: 'Roboto'),
        titleLarge: TextStyle(color: charcoal, fontFamily: 'Roboto'),
        titleMedium: TextStyle(color: charcoal, fontFamily: 'Roboto'),
        titleSmall: TextStyle(color: charcoal, fontFamily: 'Roboto'),
      ),
    );
  }

  static ThemeData get darkTheme {
    const colorScheme = ColorScheme.dark(
      primary: accentTeal,
      onPrimary: surfaceWhite,
      secondary: accentTeal,
      onSecondary: surfaceWhite,
      tertiary: warningGold,
      onTertiary: surfaceWhite,
      surface: darkSurface,
      onSurface: darkText,
      onSurfaceVariant: darkMutedText,
      outline: darkBorder,
      outlineVariant: darkBorder,
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Roboto',
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
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: darkBorder),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: darkSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: darkBackground,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkSurface,
        hintStyle: const TextStyle(color: darkMutedText),
        labelStyle: const TextStyle(color: darkMutedText),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 17,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: accentTeal, width: 2),
        ),
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: darkText, fontFamily: 'Roboto'),
        bodyMedium: TextStyle(color: darkText, fontFamily: 'Roboto'),
        titleLarge: TextStyle(color: darkText, fontFamily: 'Roboto'),
        titleMedium: TextStyle(color: darkText, fontFamily: 'Roboto'),
        titleSmall: TextStyle(color: darkText, fontFamily: 'Roboto'),
      ),
    );
  }
}
