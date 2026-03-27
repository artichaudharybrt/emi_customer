import 'package:flutter/material.dart';

class AppTheme {
  // FasstPay logo inspired colors
  static const Color navy = Color(0xFF03153A);
  static const Color royalBlue = Color(0xFF0A3D91);
  static const Color electricBlue = Color(0xFF1B63D8);
  static const Color neonGreen = Color(0xFF56D414);
  static const Color accentGreen = neonGreen;
  static const Color cardBlue = Color(0xFF112A5A);
  static const Color textOnDark = Color(0xFFF3F7FF);

  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [navy, royalBlue, electricBlue, neonGreen],
    stops: [0.0, 0.52, 0.84, 1.0],
  );

  static ThemeData logoTheme() {
    const colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: electricBlue,
      onPrimary: Colors.white,
      secondary: neonGreen,
      onSecondary: Color(0xFF031004),
      error: Color(0xFFE45757),
      onError: Colors.white,
      surface: cardBlue,
      onSurface: textOnDark,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: navy,
      appBarTheme: const AppBarTheme(
        backgroundColor: navy,
        foregroundColor: textOnDark,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: cardBlue,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: electricBlue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textOnDark,
          side: const BorderSide(color: electricBlue),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: navy,
        indicatorColor: electricBlue.withOpacity(0.2),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: navy,
        indicatorColor: electricBlue.withOpacity(0.2),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: cardBlue,
        contentTextStyle: TextStyle(color: textOnDark),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
