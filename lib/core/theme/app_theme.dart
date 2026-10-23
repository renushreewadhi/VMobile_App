import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'glass_theme.dart';

class AppTheme {
  static const String fontFamily = 'PlusJakartaSans';

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: fontFamily,
      primaryColor: AppColors.primary,
      scaffoldBackgroundColor: AppColors.lightAppBackground,
      extensions: [
        AppColorsExtension.light,
        GlassTheme.light,
      ],
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        onPrimary: Colors.white,
        primaryContainer: AppColors.lightBackgroundTint,
        onPrimaryContainer: AppColors.primaryDark,
        secondary: AppColors.accentTeal,
        onSecondary: Colors.white,
        surface: AppColors.lightMainSurface,
        onSurface: AppColors.lightPrimaryText,
        surfaceContainerHighest: AppColors.lightSecondarySurface,
        error: AppColors.error,
        onError: Colors.white,
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(fontFamily: fontFamily, fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF0F172A), letterSpacing: -0.3),
        headlineMedium: TextStyle(fontFamily: fontFamily, fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A), letterSpacing: -0.3),
        titleLarge: TextStyle(fontFamily: fontFamily, fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
        titleMedium: TextStyle(fontFamily: fontFamily, fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
        bodyLarge: TextStyle(fontFamily: fontFamily, fontSize: 15, fontWeight: FontWeight.w500, color: Color(0xFF0F172A)),
        bodyMedium: TextStyle(fontFamily: fontFamily, fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF475569)),
        bodySmall: TextStyle(fontFamily: fontFamily, fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF475569), letterSpacing: 1.4),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(fontFamily: fontFamily, fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF0F172A), letterSpacing: -0.3),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: fontFamily,
      primaryColor: AppColors.primaryLight,
      scaffoldBackgroundColor: AppColors.darkAppBackground,
      extensions: [
        AppColorsExtension.dark,
        GlassTheme.dark,
      ],
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primaryLight,
        onPrimary: Colors.white,
        primaryContainer: AppColors.darkBackgroundTint,
        onPrimaryContainer: AppColors.darkPrimaryText,
        secondary: AppColors.accentTeal,
        onSecondary: Colors.white,
        surface: AppColors.darkMainSurface,
        onSurface: AppColors.darkPrimaryText,
        surfaceContainerHighest: AppColors.darkSecondarySurface,
        error: AppColors.error,
        onError: Colors.white,
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(fontFamily: fontFamily, fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.3),
        headlineMedium: TextStyle(fontFamily: fontFamily, fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.3),
        titleLarge: TextStyle(fontFamily: fontFamily, fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
        titleMedium: TextStyle(fontFamily: fontFamily, fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
        bodyLarge: TextStyle(fontFamily: fontFamily, fontSize: 15, fontWeight: FontWeight.w500, color: Colors.white),
        bodyMedium: TextStyle(fontFamily: fontFamily, fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFFA3AFBD)),
        bodySmall: TextStyle(fontFamily: fontFamily, fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFA3AFBD), letterSpacing: 1.4),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(fontFamily: fontFamily, fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.3),
      ),
    );
  }
}
