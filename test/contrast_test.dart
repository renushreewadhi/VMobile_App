import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:etaprise_hrms/core/theme/glass_theme.dart';
import 'dart:math';

double _linearize(double colorChannel) {
  return colorChannel <= 0.03928
      ? colorChannel / 12.92
      : pow((colorChannel + 0.055) / 1.055, 2.4).toDouble();
}

double _luminance(Color c) {
  final r = _linearize(c.r);
  final g = _linearize(c.g);
  final b = _linearize(c.b);
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

double contrastRatio(Color c1, Color c2) {
  final l1 = _luminance(c1);
  final l2 = _luminance(c2);
  final lighter = max(l1, l2);
  final darker = min(l1, l2);
  return (lighter + 0.05) / (darker + 0.05);
}

Color composite(Color fg, Color bg) {
  final alpha = fg.a;
  final r = fg.r * alpha + bg.r * (1 - alpha);
  final g = fg.g * alpha + bg.g * (1 - alpha);
  final b = fg.b * alpha + bg.b * (1 - alpha);
  return Color.fromRGBO((r * 255).round(), (g * 255).round(), (b * 255).round(), 1.0);
}

void main() {
  test('GlassTheme Light contrast ratio check >= 4.5:1 for all pairs', () {
    final glass = GlassTheme.light;
    final bg = glass.backgroundGradientColors.first;
    final cardSurface = composite(glass.cardFill, bg);
    final headerSurface = composite(glass.headerFill, bg);

    final r1 = contrastRatio(glass.textPrimary, cardSurface);
    print('Light Primary Text on Card: ${r1.toStringAsFixed(2)}:1');
    expect(r1 >= 4.5, true);

    final r2 = contrastRatio(glass.textSecondary, cardSurface);
    print('Light Secondary Text on Card: ${r2.toStringAsFixed(2)}:1');
    expect(r2 >= 4.5, true);

    final r3 = contrastRatio(glass.textPrimary, headerSurface);
    print('Light Header Title on Header: ${r3.toStringAsFixed(2)}:1');
    expect(r3 >= 4.5, true);

    final s1 = contrastRatio(glass.successText, composite(glass.successTint, cardSurface));
    print('Light Success Text on Tint: ${s1.toStringAsFixed(2)}:1');
    expect(s1 >= 4.5, true);

    final s2 = contrastRatio(glass.warningText, composite(glass.warningTint, cardSurface));
    print('Light Warning Text on Tint: ${s2.toStringAsFixed(2)}:1');
    expect(s2 >= 4.5, true);

    final s3 = contrastRatio(glass.errorText, composite(glass.errorTint, cardSurface));
    print('Light Error Text on Tint: ${s3.toStringAsFixed(2)}:1');
    expect(s3 >= 4.5, true);

    final s4 = contrastRatio(glass.infoText, composite(glass.infoTint, cardSurface));
    print('Light Info Text on Tint: ${s4.toStringAsFixed(2)}:1');
    expect(s4 >= 4.5, true);

    final s5 = contrastRatio(glass.pendingText, composite(glass.pendingTint, cardSurface));
    print('Light Pending Text on Tint: ${s5.toStringAsFixed(2)}:1');
    expect(s5 >= 4.5, true);

    final navSurface = composite(glass.navFill, bg);
    final tabActiveSurface = composite(glass.activeTabFill, navSurface);
    final rTab = contrastRatio(glass.activeTabContent, tabActiveSurface);
    print('Light Active Tab Content: ${rTab.toStringAsFixed(2)}:1');
    expect(rTab >= 4.5, true);

    final rTabIn = contrastRatio(glass.inactiveTab, navSurface);
    print('Light Inactive Tab Content: ${rTabIn.toStringAsFixed(2)}:1');
    expect(rTabIn >= 4.5, true);

    final rDest = contrastRatio(Colors.white, const Color(0xFFDC2626));
    print('Light Text on Destructive Button: ${rDest.toStringAsFixed(2)}:1');
    expect(rDest >= 4.5, true);
  });

  test('GlassTheme Dark contrast ratio check >= 4.5:1 for all pairs', () {
    final glass = GlassTheme.dark;
    final bg = glass.backgroundGradientColors.first;
    final cardSurface = composite(glass.cardFill, bg);
    final headerSurface = composite(glass.headerFill, bg);

    final r1 = contrastRatio(glass.textPrimary, cardSurface);
    print('Dark Primary Text on Card: ${r1.toStringAsFixed(2)}:1');
    expect(r1 >= 4.5, true);

    final r2 = contrastRatio(glass.textSecondary, cardSurface);
    print('Dark Secondary Text on Card: ${r2.toStringAsFixed(2)}:1');
    expect(r2 >= 4.5, true);

    final r3 = contrastRatio(glass.textPrimary, headerSurface);
    print('Dark Header Title on Header: ${r3.toStringAsFixed(2)}:1');
    expect(r3 >= 4.5, true);

    final s1 = contrastRatio(glass.successText, composite(glass.successTint, cardSurface));
    print('Dark Success Text on Tint: ${s1.toStringAsFixed(2)}:1');
    expect(s1 >= 4.5, true);

    final s2 = contrastRatio(glass.warningText, composite(glass.warningTint, cardSurface));
    print('Dark Warning Text on Tint: ${s2.toStringAsFixed(2)}:1');
    expect(s2 >= 4.5, true);

    final s3 = contrastRatio(glass.errorText, composite(glass.errorTint, cardSurface));
    print('Dark Error Text on Tint: ${s3.toStringAsFixed(2)}:1');
    expect(s3 >= 4.5, true);

    final s4 = contrastRatio(glass.infoText, composite(glass.infoTint, cardSurface));
    print('Dark Info Text on Tint: ${s4.toStringAsFixed(2)}:1');
    expect(s4 >= 4.5, true);

    final s5 = contrastRatio(glass.pendingText, composite(glass.pendingTint, cardSurface));
    print('Dark Pending Text on Tint: ${s5.toStringAsFixed(2)}:1');
    expect(s5 >= 4.5, true);

    final navSurface = composite(glass.navFill, bg);
    final tabActiveSurface = composite(glass.activeTabFill, navSurface);
    final rTab = contrastRatio(glass.activeTabContent, tabActiveSurface);
    print('Dark Active Tab Content: ${rTab.toStringAsFixed(2)}:1');
    expect(rTab >= 4.5, true);

    final rTabIn = contrastRatio(glass.inactiveTab, navSurface);
    print('Dark Inactive Tab Content: ${rTabIn.toStringAsFixed(2)}:1');
    expect(rTabIn >= 4.5, true);

    final rDest = contrastRatio(Colors.white, const Color(0xFFDC2626));
    print('Dark Text on Destructive Button: ${rDest.toStringAsFixed(2)}:1');
    expect(rDest >= 4.5, true);
  });
}
