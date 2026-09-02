import 'package:flutter/material.dart';

class AppTheme {
  // Dark Theme (existing green theme)
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF022C22),
      brightness: Brightness.dark,
      surface: const Color(0xFF022C22),
    ),
    scaffoldBackgroundColor: const Color(0xFF022C22),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    drawerTheme: const DrawerThemeData(backgroundColor: Color(0xFF00120B)),
    cardColor: const Color(0xFF002117),
    dividerColor: const Color(0xFF003D2D),
  );

  // Light Theme (new)
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF00695C),
      brightness: Brightness.light,
      surface: Colors.white,
    ),
    scaffoldBackgroundColor: const Color(0xFFF5F5F5),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: Color(0xFF022C22),
      elevation: 0,
    ),
    drawerTheme: const DrawerThemeData(backgroundColor: Colors.white),
    cardColor: Colors.white,
    dividerColor: const Color(0xFFE0E0E0),
  );
}

// Helper untuk mendapatkan warna sesuai tema
class AppColors {
  static Color getSurfaceContainerLow(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF002117)
        : Colors.white;
  }

  static Color getSurfaceVariant(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF003D2D)
        : const Color(0xFFE8F5E9);
  }

  static Color getGoldLeaf(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFFBBF24)
        : const Color(0xFFB8860B);
  }

  static Color getPrimaryText(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF8BD6B6)
        : const Color(0xFF00695C);
  }

  static Color getOnSurfaceVariant(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFBEC9C2)
        : const Color(0xFF616161);
  }

  static Color getTextPrimary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? Colors.white
        : const Color(0xFF212121);
  }
}
