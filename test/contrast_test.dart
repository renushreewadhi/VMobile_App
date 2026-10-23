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
  test('GlassTheme Light contrast ratio check >= 4.5:1', () {
    final glass = GlassTheme.light;
    final bg = glass.backgroundGradientColors.first;
    final surface = composite(glass.cardFill, bg);

    final r1 = contrastRatio(glass.textPrimary, surface);
    expect(r1 >= 4.5, true, reason: 'Light textPrimary contrast $r1 is below 4.5:1');

    final r2 = contrastRatio(glass.textSecondary, surface);
    expect(r2 >= 4.5, true, reason: 'Light textSecondary contrast $r2 is below 4.5:1');

    final r7 = contrastRatio(Colors.white, const Color(0xFF0F766E));
    expect(r7 >= 4.5, true, reason: 'White text on primary button gradient contrast $r7 is below 4.5:1');
  });

  test('GlassTheme Dark contrast ratio check >= 4.5:1', () {
    final glass = GlassTheme.dark;
    final bg = glass.backgroundGradientColors.first;
    final surface = composite(glass.cardFill, bg);

    final r1 = contrastRatio(glass.textPrimary, surface);
    expect(r1 >= 4.5, true, reason: 'Dark textPrimary contrast $r1 is below 4.5:1');

    final r2 = contrastRatio(glass.textSecondary, surface);
    expect(r2 >= 4.5, true, reason: 'Dark textSecondary contrast $r2 is below 4.5:1');

    final r7 = contrastRatio(Colors.white, const Color(0xFF0F766E));
    expect(r7 >= 4.5, true, reason: 'White text on primary button gradient contrast $r7 is below 4.5:1');
  });
}
