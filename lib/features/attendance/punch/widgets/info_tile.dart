import 'package:flutter/material.dart';

import '../../../../core/theme/glass_theme.dart';

class InfoTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;
  final Color? bgColor;
  final bool dark;
  final Color text;
  final Color muted;
  final Color surface;
  final Color border;

  const InfoTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
    this.bgColor,
    required this.dark,
    required this.text,
    required this.muted,
    required this.surface,
    required this.border,
  });

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    final tint = bgColor ?? surface;
    final effectiveBg = dark
        ? surface.withOpacity(0.85)
        : Color.alphaBlend(tint.withOpacity(0.35), glass.cardFill);

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: effectiveBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border.withOpacity(0.8)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(dark ? 0.1 : 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.18),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor, size: 13),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: dark
                          ? const Color(0xFFCBD5E1)
                          : const Color(0xFF334155),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      value,
                      style: TextStyle(
                        color: text,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
