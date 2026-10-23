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

void main() {
  test('GlassTheme Light contrast ratio check >= 4.5:1', () {
    final glass = GlassTheme.light;
    final r1 = contrastRatio(glass.textPrimary, Colors.white);
    expect(r1 >= 4.5, true, reason: 'Light textPrimary contrast $r1 is below 4.5:1');

    final r2 = contrastRatio(glass.textSecondary, Colors.white);
    expect(r2 >= 4.5, true, reason: 'Light textSecondary contrast $r2 is below 4.5:1');

    final r3 = contrastRatio(glass.successText, Colors.white);
    expect(r3 >= 4.5, true, reason: 'Light successText contrast $r3 is below 4.5:1');

    final r4 = contrastRatio(glass.warningText, Colors.white);
    expect(r4 >= 4.5, true, reason: 'Light warningText contrast $r4 is below 4.5:1');

    final r5 = contrastRatio(glass.errorText, Colors.white);
    expect(r5 >= 4.5, true, reason: 'Light errorText contrast $r5 is below 4.5:1');
  });

  test('GlassTheme Dark contrast ratio check >= 4.5:1', () {
    final glass = GlassTheme.dark;
    final r1 = contrastRatio(glass.textPrimary, const Color(0xFF070F12));
    expect(r1 >= 4.5, true, reason: 'Dark textPrimary contrast $r1 is below 4.5:1');

    final r2 = contrastRatio(glass.textSecondary, const Color(0xFF070F12));
    expect(r2 >= 4.5, true, reason: 'Dark textSecondary contrast $r2 is below 4.5:1');

    final r3 = contrastRatio(glass.successText, const Color(0xFF070F12));
    expect(r3 >= 4.5, true, reason: 'Dark successText contrast $r3 is below 4.5:1');

    final r4 = contrastRatio(glass.warningText, const Color(0xFF070F12));
    expect(r4 >= 4.5, true, reason: 'Dark successText contrast $r4 is below 4.5:1');

    final r5 = contrastRatio(glass.errorText, const Color(0xFF070F12));
    expect(r5 >= 4.5, true, reason: 'Dark errorText contrast $r5 is below 4.5:1');
  });
}
