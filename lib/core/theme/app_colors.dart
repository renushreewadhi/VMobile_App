import 'package:flutter/material.dart';

class AppColors {
  // Primary brand colors
  static const Color primary = Color(0xFF0F6B66);
  static const Color primaryDark = Color(0xFF0A4F4B);
  static const Color primaryLight = Color(0xFF1FA8A0);
  static const Color darkPrimary = Color(0xFF193F91);
  static const Color lightPrimary = Color(0xFFE8EFFF);
  static const Color accentTeal = Color(0xFF14B8A6);
  static const Color lightAccent = Color(0xFFD9F7F2);

  // Accents
  static const Color accentCyan = Color(0xFF22D3D0);
  static const Color accentOrange = Color(0xFFF28C28);

  // Light theme backgrounds & text
  static const Color lightAppBackground = Color(0xFFF3F7F7);
  static const Color lightMainSurface = Color(0xFFFFFFFF);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCardBackground = Color(0xFFFFFFFF);
  static const Color lightBackgroundTint = Color(0xFFE8F3F2);
  static const Color accentBlue = Color(0xFF3478F6);
  static const Color lightSecondarySurface = Color(0xFFEEF2F8);
  
  static const Color lightPrimaryText = Color(0xFF0F2A29);
  static const Color lightSecondaryText = Color(0xFF5B7170);
  static const Color lightTextPrimary = Color(0xFF0F2A29);
  static const Color lightTextSecondary = Color(0xFF5B7170);
  
  static const Color lightMutedText = Color(0xFF98A2B3);
  static const Color lightBordersAndDividers = Color(0xFFDCE8E7);
  static const Color lightInputBackground = Color(0xFFFFFFFF);
  static const Color lightBorderSubtle = Color(0xFFDCE8E7);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // Dark theme backgrounds & text
  static const Color darkAppBackground = Color(0xFF0F2E2C);
  static const Color darkMainSurface = Color(0xFF1B2A38);
  static const Color darkCardBackground = Color(0xFF1B2A38);
  static const Color darkSecondarySurface = Color(0xFF1F3244);
  
  static const Color darkPrimaryText = Color(0xFFEAF6F5);
  static const Color darkSecondaryText = Color(0xFFA5B4C8);
  static const Color darkTextPrimary = Color(0xFFEAF6F5);
  static const Color darkTextSecondary = Color(0xFF9DB8B6);
  
  static const Color darkMutedText = Color(0xFF7C8AA2);
  static const Color darkBordersAndDividers = Color(0x1FFFFFFF);
  static const Color darkInputBackground = Color(0x14FFFFFF);
  static const Color darkBackgroundTint = Color(0xFF0B3B38);
  static const Color darkBorderSubtle = Color(0x1FFFFFFF);

  // Semantic colors
  static const Color success = Color(0xFF16A36A);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color danger = Color(0xFFEF4444);
  static const Color info = Color(0xFF0EA5E9);
  static const Color onlineDot = Color(0xFF22C55E);

  // Soft semantic backgrounds
  static const Color successBg = Color(0xFFE6F7ED);
  static const Color warningBg = Color(0xFFFEF3C7);
  static const Color errorBg = Color(0xFFFEE2E2);
  static const Color dangerBg = Color(0xFFFEE2E2);
  static const Color infoBg = Color(0xFFE0F2FE);
}

@immutable
class AppColorsExtension extends ThemeExtension<AppColorsExtension> {
  final Color appBackground;
  final Color cardBackground;
  final Color backgroundTint;
  final Color inputBackground;
  final Color textPrimary;
  final Color textSecondary;
  final Color textOnPrimary;
  final Color borderSubtle;
  final Color primary;
  final Color primaryDark;
  final Color primaryLight;
  final Color accentCyan;
  final Color accentOrange;
  final Color success;
  final Color warning;
  final Color danger;
  final Color info;
  final Color onlineDot;

  const AppColorsExtension({
    required this.appBackground,
    required this.cardBackground,
    required this.backgroundTint,
    required this.inputBackground,
    required this.textPrimary,
    required this.textSecondary,
    required this.textOnPrimary,
    required this.borderSubtle,
    required this.primary,
    required this.primaryDark,
    required this.primaryLight,
    required this.accentCyan,
    required this.accentOrange,
    required this.success,
    required this.warning,
    required this.danger,
    required this.info,
    required this.onlineDot,
  });

  @override
  AppColorsExtension copyWith({
    Color? appBackground,
    Color? cardBackground,
    Color? backgroundTint,
    Color? inputBackground,
    Color? textPrimary,
    Color? textSecondary,
    Color? textOnPrimary,
    Color? borderSubtle,
    Color? primary,
    Color? primaryDark,
    Color? primaryLight,
    Color? accentCyan,
    Color? accentOrange,
    Color? success,
    Color? warning,
    Color? danger,
    Color? info,
    Color? onlineDot,
  }) {
    return AppColorsExtension(
      appBackground: appBackground ?? this.appBackground,
      cardBackground: cardBackground ?? this.cardBackground,
      backgroundTint: backgroundTint ?? this.backgroundTint,
      inputBackground: inputBackground ?? this.inputBackground,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textOnPrimary: textOnPrimary ?? this.textOnPrimary,
      borderSubtle: borderSubtle ?? this.borderSubtle,
      primary: primary ?? this.primary,
      primaryDark: primaryDark ?? this.primaryDark,
      primaryLight: primaryLight ?? this.primaryLight,
      accentCyan: accentCyan ?? this.accentCyan,
      accentOrange: accentOrange ?? this.accentOrange,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      info: info ?? this.info,
      onlineDot: onlineDot ?? this.onlineDot,
    );
  }

  @override
  AppColorsExtension lerp(ThemeExtension<AppColorsExtension>? other, double t) {
    if (other is! AppColorsExtension) return this;
    return AppColorsExtension(
      appBackground: Color.lerp(appBackground, other.appBackground, t)!,
      cardBackground: Color.lerp(cardBackground, other.cardBackground, t)!,
      backgroundTint: Color.lerp(backgroundTint, other.backgroundTint, t)!,
      inputBackground: Color.lerp(inputBackground, other.inputBackground, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textOnPrimary: Color.lerp(textOnPrimary, other.textOnPrimary, t)!,
      borderSubtle: Color.lerp(borderSubtle, other.borderSubtle, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      primaryDark: Color.lerp(primaryDark, other.primaryDark, t)!,
      primaryLight: Color.lerp(primaryLight, other.primaryLight, t)!,
      accentCyan: Color.lerp(accentCyan, other.accentCyan, t)!,
      accentOrange: Color.lerp(accentOrange, other.accentOrange, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      info: Color.lerp(info, other.info, t)!,
      onlineDot: Color.lerp(onlineDot, other.onlineDot, t)!,
    );
  }

  static const light = AppColorsExtension(
    appBackground: AppColors.lightAppBackground,
    cardBackground: AppColors.lightCardBackground,
    backgroundTint: AppColors.lightBackgroundTint,
    inputBackground: AppColors.lightInputBackground,
    textPrimary: AppColors.lightTextPrimary,
    textSecondary: AppColors.lightTextSecondary,
    textOnPrimary: AppColors.textOnPrimary,
    borderSubtle: AppColors.lightBorderSubtle,
    primary: AppColors.primary,
    primaryDark: AppColors.primaryDark,
    primaryLight: AppColors.primaryLight,
    accentCyan: AppColors.accentCyan,
    accentOrange: AppColors.accentOrange,
    success: AppColors.success,
    warning: AppColors.warning,
    danger: AppColors.danger,
    info: AppColors.info,
    onlineDot: AppColors.onlineDot,
  );

  static const dark = AppColorsExtension(
    appBackground: AppColors.darkAppBackground,
    cardBackground: AppColors.darkCardBackground,
    backgroundTint: AppColors.darkBackgroundTint,
    inputBackground: AppColors.darkInputBackground,
    textPrimary: AppColors.darkTextPrimary,
    textSecondary: AppColors.darkTextSecondary,
    textOnPrimary: AppColors.textOnPrimary,
    borderSubtle: AppColors.darkBorderSubtle,
    primary: AppColors.primaryLight,
    primaryDark: AppColors.primary,
    primaryLight: Color(0xFF24B8B0),
    accentCyan: AppColors.accentCyan,
    accentOrange: AppColors.accentOrange,
    success: AppColors.success,
    warning: AppColors.warning,
    danger: AppColors.danger,
    info: AppColors.info,
    onlineDot: AppColors.onlineDot,
  );
}

extension AppColorsContext on BuildContext {
  AppColorsExtension get appColors => Theme.of(this).extension<AppColorsExtension>() ?? AppColorsExtension.light;
}

class AppRadius {
  static const double card = 16.0;
  static const double sheet = 28.0;
  static const double button = 14.0;
  static const double chip = 999.0;
  static const double avatar = 999.0;
  static const double iconTile = 14.0;
  static const double input = 12.0;
}

class AppShadows {
  static List<BoxShadow> get cardSoft => const [
        BoxShadow(
          color: Color(0x140F6B66), // ~8% opacity
          blurRadius: 20,
          offset: Offset(0, 6),
        ),
      ];

  static List<BoxShadow> get floating => const [
        BoxShadow(
          color: Color(0x3D0F6B66), // ~24% opacity
          blurRadius: 28,
          offset: Offset(0, 10),
        ),
      ];
}
