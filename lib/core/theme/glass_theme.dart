import 'package:flutter/material.dart';

@immutable
class GlassTheme extends ThemeExtension<GlassTheme> {
  final List<Color> backgroundGradientColors;
  final List<Color> blobColors;
  final List<double> blobOpacities;
  final List<double> blobBlurs;

  // Glass card tokens
  final Color cardFill;
  final Color cardBorder;
  final double cardBlur;
  final List<BoxShadow> cardShadow;
  final double cardRadius;

  // Glass header tokens
  final Color headerFill;
  final Color headerBorder;
  final double headerBlur;
  final double headerRadius;

  // Glass search tokens
  final Color searchFill;
  final Color searchBorder;
  final double searchBlur;
  final double searchRadius;
  final Color searchPlaceholder;

  // Glass bottom nav tokens
  final Color navFill;
  final Color navBorder;
  final double navBlur;
  final List<BoxShadow> navShadow;
  final double navRadius;

  // Text & UI tokens
  final Color textPrimary;
  final Color textSecondary;
  final Color chevronColor;
  final Color badgeFill;
  final Color badgeText;
  final Color activeTabFill;
  final Color activeTabContent;
  final Color inactiveTab;
  final Color headerIconTileFill;
  final Color headerIconColor;
  final List<Color> avatarGradient;
  final Color avatarRing;

  // Module gradients (6 modules)
  final List<List<Color>> moduleGradients;

  // Semantic status colors
  final Color success;
  final Color warning;
  final Color error;
  final Color info;
  final Color pending;

  const GlassTheme({
    required this.backgroundGradientColors,
    required this.blobColors,
    required this.blobOpacities,
    required this.blobBlurs,
    required this.cardFill,
    required this.cardBorder,
    required this.cardBlur,
    required this.cardShadow,
    required this.cardRadius,
    required this.headerFill,
    required this.headerBorder,
    required this.headerBlur,
    required this.headerRadius,
    required this.searchFill,
    required this.searchBorder,
    required this.searchBlur,
    required this.searchRadius,
    required this.searchPlaceholder,
    required this.navFill,
    required this.navBorder,
    required this.navBlur,
    required this.navShadow,
    required this.navRadius,
    required this.textPrimary,
    required this.textSecondary,
    required this.chevronColor,
    required this.badgeFill,
    required this.badgeText,
    required this.activeTabFill,
    required this.activeTabContent,
    required this.inactiveTab,
    required this.headerIconTileFill,
    required this.headerIconColor,
    required this.avatarGradient,
    required this.avatarRing,
    required this.moduleGradients,
    required this.success,
    required this.warning,
    required this.error,
    required this.info,
    required this.pending,
  });

  @override
  GlassTheme copyWith({
    List<Color>? backgroundGradientColors,
    List<Color>? blobColors,
    List<double>? blobOpacities,
    List<double>? blobBlurs,
    Color? cardFill,
    Color? cardBorder,
    double? cardBlur,
    List<BoxShadow>? cardShadow,
    double? cardRadius,
    Color? headerFill,
    Color? headerBorder,
    double? headerBlur,
    double? headerRadius,
    Color? searchFill,
    Color? searchBorder,
    double? searchBlur,
    double? searchRadius,
    Color? searchPlaceholder,
    Color? navFill,
    Color? navBorder,
    double? navBlur,
    List<BoxShadow>? navShadow,
    double? navRadius,
    Color? textPrimary,
    Color? textSecondary,
    Color? chevronColor,
    Color? badgeFill,
    Color? badgeText,
    Color? activeTabFill,
    Color? activeTabContent,
    Color? inactiveTab,
    Color? headerIconTileFill,
    Color? headerIconColor,
    List<Color>? avatarGradient,
    Color? avatarRing,
    List<List<Color>>? moduleGradients,
    Color? success,
    Color? warning,
    Color? error,
    Color? info,
    Color? pending,
  }) {
    return GlassTheme(
      backgroundGradientColors: backgroundGradientColors ?? this.backgroundGradientColors,
      blobColors: blobColors ?? this.blobColors,
      blobOpacities: blobOpacities ?? this.blobOpacities,
      blobBlurs: blobBlurs ?? this.blobBlurs,
      cardFill: cardFill ?? this.cardFill,
      cardBorder: cardBorder ?? this.cardBorder,
      cardBlur: cardBlur ?? this.cardBlur,
      cardShadow: cardShadow ?? this.cardShadow,
      cardRadius: cardRadius ?? this.cardRadius,
      headerFill: headerFill ?? this.headerFill,
      headerBorder: headerBorder ?? this.headerBorder,
      headerBlur: headerBlur ?? this.headerBlur,
      headerRadius: headerRadius ?? this.headerRadius,
      searchFill: searchFill ?? this.searchFill,
      searchBorder: searchBorder ?? this.searchBorder,
      searchBlur: searchBlur ?? this.searchBlur,
      searchRadius: searchRadius ?? this.searchRadius,
      searchPlaceholder: searchPlaceholder ?? this.searchPlaceholder,
      navFill: navFill ?? this.navFill,
      navBorder: navBorder ?? this.navBorder,
      navBlur: navBlur ?? this.navBlur,
      navShadow: navShadow ?? this.navShadow,
      navRadius: navRadius ?? this.navRadius,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      chevronColor: chevronColor ?? this.chevronColor,
      badgeFill: badgeFill ?? this.badgeFill,
      badgeText: badgeText ?? this.badgeText,
      activeTabFill: activeTabFill ?? this.activeTabFill,
      activeTabContent: activeTabContent ?? this.activeTabContent,
      inactiveTab: inactiveTab ?? this.inactiveTab,
      headerIconTileFill: headerIconTileFill ?? this.headerIconTileFill,
      headerIconColor: headerIconColor ?? this.headerIconColor,
      avatarGradient: avatarGradient ?? this.avatarGradient,
      avatarRing: avatarRing ?? this.avatarRing,
      moduleGradients: moduleGradients ?? this.moduleGradients,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      error: error ?? this.error,
      info: info ?? this.info,
      pending: pending ?? this.pending,
    );
  }

  @override
  GlassTheme lerp(ThemeExtension<GlassTheme>? other, double t) {
    if (other is! GlassTheme) return this;
    return this;
  }

  static final light = GlassTheme(
    backgroundGradientColors: const [
      Color(0xFFE9FBF8),
      Color(0xFFEEF2FB),
      Color(0xFFFDF3EA),
    ],
    blobColors: const [
      Color(0xFF5FD6C3), // teal
      Color(0xFFA99CF0), // lavender
      Color(0xFFFFC9A0), // peach
    ],
    blobOpacities: const [0.55, 0.5, 0.6],
    blobBlurs: const [55, 60, 60],
    cardFill: Color(0x94FFFFFF), // rgba(255,255,255,.58)
    cardBorder: Color(0xD9FFFFFF), // rgba(255,255,255,.85)
    cardBlur: 18,
    cardShadow: const [
      BoxShadow(color: Color.fromRGBO(60, 70, 120, 0.08), blurRadius: 24, offset: Offset(0, 8)),
    ],
    cardRadius: 22,
    headerFill: Color(0x8CFFFFFF), // rgba(255,255,255,.55)
    headerBorder: Color(0xD9FFFFFF),
    headerBlur: 20,
    headerRadius: 24,
    searchFill: Color(0x73FFFFFF), // rgba(255,255,255,.45)
    searchBorder: Color(0xD9FFFFFF),
    searchBlur: 20,
    searchRadius: 22,
    searchPlaceholder: Color(0xFF475569),
    navFill: Color(0xB8FFFFFF), // rgba(255,255,255,.72)
    navBorder: Color(0xE6FFFFFF), // rgba(255,255,255,.9)
    navBlur: 24,
    navShadow: const [
      BoxShadow(color: Color.fromRGBO(60, 70, 120, 0.14), blurRadius: 32, offset: Offset(0, 12)),
    ],
    navRadius: 28,
    textPrimary: Color(0xFF0F172A),
    textSecondary: Color(0xFF475569),
    chevronColor: Color(0xFF475569),
    badgeFill: Color(0xD9FFFFFF), // rgba(255,255,255,.85)
    badgeText: Color(0xFF1E293B),
    activeTabFill: Color.fromRGBO(45, 190, 170, 0.28),
    activeTabContent: Color(0xFF0F5F58),
    inactiveTab: Color(0xFF475569),
    headerIconTileFill: Color.fromRGBO(45, 190, 170, 0.22),
    headerIconColor: Color(0xFF0F766E),
    avatarGradient: [Color(0xFF14B8A6), Color(0xFF0F766E)],
    avatarRing: Colors.transparent,
    moduleGradients: const [
      [Color(0xFF34D399), Color(0xFF059669)], // Attendance & Time
      [Color(0xFFFB923C), Color(0xFFEA580C)], // My Work
      [Color(0xFFF472B6), Color(0xFFDB2777)], // Leave & Benefits
      [Color(0xFF818CF8), Color(0xFF4F46E5)], // Finance
      [Color(0xFF38BDF8), Color(0xFF0284C7)], // Support & IT
      [Color(0xFF2DD4BF), Color(0xFF0D9488)], // Company & Learning
    ],
    success: Color(0xFF10B981),
    warning: Color(0xFFF59E0B),
    error: Color(0xFFEF4444),
    info: Color(0xFF38BDF8),
    pending: Color(0xFF6366F1),
  );

  static final dark = GlassTheme(
    backgroundGradientColors: const [
      Color(0xFF070F12),
      Color(0xFF070F12),
      Color(0xFF070F12),
    ],
    blobColors: const [
      Color(0xFF0F9D8A), // teal
      Color(0xFF4F46E5), // indigo
      Color(0xFFC2570C), // burnt orange
    ],
    blobOpacities: const [0.55, 0.55, 0.5],
    blobBlurs: const [65, 70, 70],
    cardFill: Color(0x12FFFFFF), // rgba(255,255,255,.07)
    cardBorder: Color(0x21FFFFFF), // rgba(255,255,255,.13)
    cardBlur: 18,
    cardShadow: const [
      BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.25), blurRadius: 24, offset: Offset(0, 8)),
    ],
    cardRadius: 22,
    headerFill: Color(0x12FFFFFF),
    headerBorder: Color(0x24FFFFFF), // rgba(255,255,255,.14)
    headerBlur: 20,
    headerRadius: 24,
    searchFill: Color(0x0FFFFFFF), // rgba(255,255,255,.06)
    searchBorder: Color(0x1FFFFFFF), // rgba(255,255,255,.12)
    searchBlur: 20,
    searchRadius: 22,
    searchPlaceholder: Color(0xFFA3AFBD),
    navFill: Color(0xB8121A1E), // rgba(18,26,30,.72)
    navBorder: Color(0x24FFFFFF), // rgba(255,255,255,.14)
    navBlur: 24,
    navShadow: const [
      BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.45), blurRadius: 32, offset: Offset(0, 12)),
    ],
    navRadius: 28,
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFFA3AFBD),
    chevronColor: Color(0xFFA3AFBD),
    badgeFill: Color(0x24FFFFFF), // rgba(255,255,255,.14)
    badgeText: Color(0xFFE2E8F0),
    activeTabFill: Color.fromRGBO(45, 212, 191, 0.18),
    activeTabContent: Color(0xFF5EEAD4),
    inactiveTab: Color(0xFFAAB4C0),
    headerIconTileFill: Color.fromRGBO(45, 212, 191, 0.16),
    headerIconColor: Color(0xFF5EEAD4),
    avatarGradient: [Color(0xFF14B8A6), Color(0xFF0F766E)],
    avatarRing: Color.fromRGBO(94, 234, 212, 0.35),
    moduleGradients: const [
      [Color(0xFF34D399), Color(0xFF059669)], // Attendance & Time
      [Color(0xFFFB923C), Color(0xFFEA580C)], // My Work
      [Color(0xFFF472B6), Color(0xFFDB2777)], // Leave & Benefits
      [Color(0xFF818CF8), Color(0xFF4F46E5)], // Finance
      [Color(0xFF38BDF8), Color(0xFF0284C7)], // Support & IT
      [Color(0xFF2DD4BF), Color(0xFF0D9488)], // Company & Learning
    ],
    success: Color(0xFF10B981),
    warning: Color(0xFFF59E0B),
    error: Color(0xFFEF4444),
    info: Color(0xFF38BDF8),
    pending: Color(0xFF818CF8),
  );
}

extension GlassContext on BuildContext {
  GlassTheme get glass => Theme.of(this).extension<GlassTheme>() ?? GlassTheme.light;
}
