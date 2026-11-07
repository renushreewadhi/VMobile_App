import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'glass_theme.dart';

class AppTheme {
  static const String fontFamily = 'Plus Jakarta Sans';

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
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error, width: 1.8),
        ),
        labelStyle: const TextStyle(fontFamily: fontFamily, fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF64748B)),
        hintStyle: const TextStyle(fontFamily: fontFamily, fontSize: 13, fontWeight: FontWeight.w400, color: Color(0xFF94A3B8)),
        errorStyle: const TextStyle(fontFamily: fontFamily, fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.error),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 8,
        backgroundColor: Colors.white,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        backgroundColor: Colors.white,
        clipBehavior: Clip.antiAlias,
      ),
      popupMenuTheme: PopupMenuThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: Colors.white,
        elevation: 8,
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
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0x1AFFFFFF),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0x33FFFFFF), width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0x33FFFFFF), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primaryLight, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error, width: 1.8),
        ),
        labelStyle: const TextStyle(fontFamily: fontFamily, fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFFA3AFBD)),
        hintStyle: const TextStyle(fontFamily: fontFamily, fontSize: 13, fontWeight: FontWeight.w400, color: Color(0xFF64748B)),
        errorStyle: const TextStyle(fontFamily: fontFamily, fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.error),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 8,
        backgroundColor: const Color(0xFF1B2A38),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        backgroundColor: Color(0xFF1B2A38),
        clipBehavior: Clip.antiAlias,
      ),
      popupMenuTheme: PopupMenuThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: const Color(0xFF1B2A38),
        elevation: 8,
      ),
    );
  }
}
