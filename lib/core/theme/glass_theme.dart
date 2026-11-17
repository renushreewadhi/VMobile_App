import 'dart:ui' as ui;
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

  // Semantic status colors & high-contrast onStatus text/tints
  final Color success;
  final Color warning;
  final Color error;
  final Color info;
  final Color pending;

  final Color successTint;
  final Color successText;
  final Color warningTint;
  final Color warningText;
  final Color errorTint;
  final Color errorText;
  final Color infoTint;
  final Color infoText;
  final Color pendingTint;
  final Color pendingText;

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
    required this.successTint,
    required this.successText,
    required this.warningTint,
    required this.warningText,
    required this.errorTint,
    required this.errorText,
    required this.infoTint,
    required this.infoText,
    required this.pendingTint,
    required this.pendingText,
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
    Color? successTint,
    Color? successText,
    Color? warningTint,
    Color? warningText,
    Color? errorTint,
    Color? errorText,
    Color? infoTint,
    Color? infoText,
    Color? pendingTint,
    Color? pendingText,
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
      successTint: successTint ?? this.successTint,
      successText: successText ?? this.successText,
      warningTint: warningTint ?? this.warningTint,
      warningText: warningText ?? this.warningText,
      errorTint: errorTint ?? this.errorTint,
      errorText: errorText ?? this.errorText,
      infoTint: infoTint ?? this.infoTint,
      infoText: infoText ?? this.infoText,
      pendingTint: pendingTint ?? this.pendingTint,
      pendingText: pendingText ?? this.pendingText,
    );
  }

  @override
  GlassTheme lerp(ThemeExtension<GlassTheme>? other, double t) {
    if (other is! GlassTheme) return this;
    return GlassTheme(
      backgroundGradientColors: [
        Color.lerp(backgroundGradientColors[0], other.backgroundGradientColors[0], t)!,
        Color.lerp(backgroundGradientColors[1], other.backgroundGradientColors[1], t)!,
        Color.lerp(backgroundGradientColors[2], other.backgroundGradientColors[2], t)!,
      ],
      blobColors: [
        Color.lerp(blobColors[0], other.blobColors[0], t)!,
        Color.lerp(blobColors[1], other.blobColors[1], t)!,
        Color.lerp(blobColors[2], other.blobColors[2], t)!,
      ],
      blobOpacities: [
        ui.lerpDouble(blobOpacities[0], other.blobOpacities[0], t)!,
        ui.lerpDouble(blobOpacities[1], other.blobOpacities[1], t)!,
        ui.lerpDouble(blobOpacities[2], other.blobOpacities[2], t)!,
      ],
      blobBlurs: [
        ui.lerpDouble(blobBlurs[0], other.blobBlurs[0], t)!,
        ui.lerpDouble(blobBlurs[1], other.blobBlurs[1], t)!,
        ui.lerpDouble(blobBlurs[2], other.blobBlurs[2], t)!,
      ],
      cardFill: Color.lerp(cardFill, other.cardFill, t)!,
      cardBorder: Color.lerp(cardBorder, other.cardBorder, t)!,
      cardBlur: ui.lerpDouble(cardBlur, other.cardBlur, t)!,
      cardShadow: other.cardShadow,
      cardRadius: ui.lerpDouble(cardRadius, other.cardRadius, t)!,
      headerFill: Color.lerp(headerFill, other.headerFill, t)!,
      headerBorder: Color.lerp(headerBorder, other.headerBorder, t)!,
      headerBlur: ui.lerpDouble(headerBlur, other.headerBlur, t)!,
      headerRadius: ui.lerpDouble(headerRadius, other.headerRadius, t)!,
      searchFill: Color.lerp(searchFill, other.searchFill, t)!,
      searchBorder: Color.lerp(searchBorder, other.searchBorder, t)!,
      searchBlur: ui.lerpDouble(searchBlur, other.searchBlur, t)!,
      searchRadius: ui.lerpDouble(searchRadius, other.searchRadius, t)!,
      searchPlaceholder: Color.lerp(searchPlaceholder, other.searchPlaceholder, t)!,
      navFill: Color.lerp(navFill, other.navFill, t)!,
      navBorder: Color.lerp(navBorder, other.navBorder, t)!,
      navBlur: ui.lerpDouble(navBlur, other.navBlur, t)!,
      navShadow: other.navShadow,
      navRadius: ui.lerpDouble(navRadius, other.navRadius, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      chevronColor: Color.lerp(chevronColor, other.chevronColor, t)!,
      badgeFill: Color.lerp(badgeFill, other.badgeFill, t)!,
      badgeText: Color.lerp(badgeText, other.badgeText, t)!,
      activeTabFill: Color.lerp(activeTabFill, other.activeTabFill, t)!,
      activeTabContent: Color.lerp(activeTabContent, other.activeTabContent, t)!,
      inactiveTab: Color.lerp(inactiveTab, other.inactiveTab, t)!,
      headerIconTileFill: Color.lerp(headerIconTileFill, other.headerIconTileFill, t)!,
      headerIconColor: Color.lerp(headerIconColor, other.headerIconColor, t)!,
      avatarGradient: [
        Color.lerp(avatarGradient[0], other.avatarGradient[0], t)!,
        Color.lerp(avatarGradient[1], other.avatarGradient[1], t)!,
      ],
      avatarRing: Color.lerp(avatarRing, other.avatarRing, t)!,
      moduleGradients: moduleGradients,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      error: Color.lerp(error, other.error, t)!,
      info: Color.lerp(info, other.info, t)!,
      pending: Color.lerp(pending, other.pending, t)!,
      successTint: Color.lerp(successTint, other.successTint, t)!,
      successText: Color.lerp(successText, other.successText, t)!,
      warningTint: Color.lerp(warningTint, other.warningTint, t)!,
      warningText: Color.lerp(warningText, other.warningText, t)!,
      errorTint: Color.lerp(errorTint, other.errorTint, t)!,
      errorText: Color.lerp(errorText, other.errorText, t)!,
      infoTint: Color.lerp(infoTint, other.infoTint, t)!,
      infoText: Color.lerp(infoText, other.infoText, t)!,
      pendingTint: Color.lerp(pendingTint, other.pendingTint, t)!,
      pendingText: Color.lerp(pendingText, other.pendingText, t)!,
    );
  }

  static final light = GlassTheme(
    backgroundGradientColors: const [
      Color(0xFFE9FBF8),
      Color(0xFFEEF2FB),
      Color(0xFFFDF3EA),
    ],
    blobColors: const [
      Color(0xFF5FD6C3),
      Color(0xFFA99CF0),
      Color(0xFFFFC9A0),
    ],
    blobOpacities: const [0.55, 0.5, 0.6],
    blobBlurs: const [55, 60, 60],
    cardFill: Color(0xECFFFFFF),
    cardBorder: Color(0xD9FFFFFF),
    cardBlur: 18,
    cardShadow: const [
      BoxShadow(color: Color.fromRGBO(15, 107, 102, 0.08), blurRadius: 24, offset: Offset(0, 8)),
    ],
    cardRadius: 22,
    headerFill: Color(0xCCFFFFFF),
    headerBorder: Color(0xD9FFFFFF),
    headerBlur: 20,
    headerRadius: 24,
    searchFill: Color(0xECFFFFFF),
    searchBorder: Color(0xD9FFFFFF),
    searchBlur: 20,
    searchRadius: 22,
    searchPlaceholder: Color(0xFF475569),
    navFill: Color(0xE6FFFFFF),
    navBorder: Color(0xE6FFFFFF),
    navBlur: 24,
    navShadow: const [
      BoxShadow(color: Color.fromRGBO(15, 107, 102, 0.12), blurRadius: 32, offset: Offset(0, 12)),
    ],
    navRadius: 28,
    textPrimary: Color(0xFF0F172A),
    textSecondary: Color(0xFF475569),
    chevronColor: Color(0xFF475569),
    badgeFill: Color(0xF0FFFFFF),
    badgeText: Color(0xFF1E293B),
    activeTabFill: Color.fromRGBO(45, 190, 170, 0.28),
    activeTabContent: Color(0xFF0F5F58),
    inactiveTab: Color(0xFF475569),
    headerIconTileFill: Color.fromRGBO(45, 190, 170, 0.22),
    headerIconColor: Color(0xFF0F766E),
    avatarGradient: [Color(0xFF14B8A6), Color(0xFF0F766E)],
    avatarRing: Colors.transparent,
    moduleGradients: const [
      [Color(0xFF34D399), Color(0xFF059669)],
      [Color(0xFFFB923C), Color(0xFFEA580C)],
      [Color(0xFFF472B6), Color(0xFFDB2777)],
      [Color(0xFF818CF8), Color(0xFF4F46E5)],
      [Color(0xFF38BDF8), Color(0xFF0284C7)],
      [Color(0xFF2DD4BF), Color(0xFF0D9488)],
    ],
    success: Color(0xFF10B981),
    warning: Color(0xFFF59E0B),
    error: Color(0xFFEF4444),
    info: Color(0xFF38BDF8),
    pending: Color(0xFF6366F1),
    successTint: Color(0x2610B981),
    successText: Color(0xFF047857),
    warningTint: Color(0x26F59E0B),
    warningText: Color(0xFF92400E),
    errorTint: Color(0x26EF4444),
    errorText: Color(0xFFB91C1C),
    infoTint: Color(0x2638BDF8),
    infoText: Color(0xFF0369A1),
    pendingTint: Color(0x266366F1),
    pendingText: Color(0xFF4338CA),
  );

  static final dark = GlassTheme(
    backgroundGradientColors: const [
      Color(0xFF0F172A), // Deep slate background
      Color(0xFF132238),
      Color(0xFF1B2A42),
    ],
    blobColors: const [
      Color(0xFF0F9D8A),
      Color(0xFF4F46E5),
      Color(0xFFC2570C),
    ],
    blobOpacities: const [0.33, 0.33, 0.3], // Reduced green & blue glow intensity by ~40%
    blobBlurs: const [65, 70, 70],
    cardFill: Color(0xFF1E293B), // Slightly lighter surface than bg
    cardBorder: Color(0x19FFFFFF), // 1px border at ~10% white
    cardBlur: 18,
    cardShadow: const [
      BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.2), blurRadius: 24, offset: Offset(0, 8)),
    ],
    cardRadius: 22,
    headerFill: Color(0xFF1E293B),
    headerBorder: Color(0x19FFFFFF),
    headerBlur: 20,
    headerRadius: 24,
    searchFill: Color(0xFF1E293B),
    searchBorder: Color(0x19FFFFFF),
    searchBlur: 20,
    searchRadius: 22,
    searchPlaceholder: Color(0xFFA3AFBD),
    navFill: Color(0xFF1E293B),
    navBorder: Color(0x19FFFFFF),
    navBlur: 24,
    navShadow: const [
      BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.3), blurRadius: 32, offset: Offset(0, 12)),
    ],
    navRadius: 28,
    textPrimary: Color(0xFFF8FAFC),
    textSecondary: Color(0xFF94A3B8),
    chevronColor: Color(0xFF94A3B8),
    badgeFill: Color(0x24FFFFFF),
    badgeText: Color(0xFFE2E8F0),
    activeTabFill: Color.fromRGBO(45, 212, 191, 0.18),
    activeTabContent: Color(0xFF5EEAD4),
    inactiveTab: Color(0xFFAAB4C0),
    headerIconTileFill: Color.fromRGBO(45, 212, 191, 0.16),
    headerIconColor: Color(0xFF5EEAD4),
    avatarGradient: [Color(0xFF14B8A6), Color(0xFF0F766E)],
    avatarRing: Color.fromRGBO(94, 234, 212, 0.35),
    moduleGradients: const [
      [Color(0xFF34D399), Color(0xFF059669)],
      [Color(0xFFFB923C), Color(0xFFEA580C)],
      [Color(0xFFF472B6), Color(0xFFDB2777)],
      [Color(0xFF818CF8), Color(0xFF4F46E5)],
      [Color(0xFF38BDF8), Color(0xFF0284C7)],
      [Color(0xFF2DD4BF), Color(0xFF0D9488)],
    ],
    success: Color(0xFF10B981),
    warning: Color(0xFFF59E0B),
    error: Color(0xFFEF4444),
    info: Color(0xFF38BDF8),
    pending: Color(0xFF818CF8),
    successTint: Color(0x3310B981),
    successText: Color(0xFF34D399),
    warningTint: Color(0x33F59E0B),
    warningText: Color(0xFFFBBF24),
    errorTint: Color(0x33EF4444),
    errorText: Color(0xFFFCA5A5),
    infoTint: Color(0x3338BDF8),
    infoText: Color(0xFF7DD3FC),
    pendingTint: Color(0x33818CF8),
    pendingText: Color(0xFFA5B4FC),
  );
}

extension GlassContext on BuildContext {
  GlassTheme get glass => Theme.of(this).extension<GlassTheme>() ?? GlassTheme.light;
}
