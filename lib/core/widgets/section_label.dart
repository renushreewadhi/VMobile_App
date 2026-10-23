import 'package:flutter/material.dart';
import '../theme/glass_theme.dart';

class SectionLabel extends StatelessWidget {
  final String text;
  final EdgeInsetsGeometry? padding;

  const SectionLabel(this.text, {super.key, this.padding});

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;

    return Padding(
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: glass.textSecondary,
          letterSpacing: 1.4,
        ),
      ),
    );
  }
}
