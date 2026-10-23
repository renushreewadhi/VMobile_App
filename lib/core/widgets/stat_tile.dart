import 'package:flutter/material.dart';
import '../theme/glass_theme.dart';
import 'glass_card.dart';

class StatTile extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final List<Color> iconGradient;
  final String? subtitle;
  final VoidCallback? onTap;

  const StatTile({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.iconGradient,
    this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;

    return GlassCard(
      blur: false,
      radius: glass.cardRadius,
      fillColor: glass.cardFill,
      borderColor: glass.cardBorder,
      shadow: glass.cardShadow,
      padding: const EdgeInsets.all(16),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: glass.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: iconGradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: Colors.white, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              color: glass.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: TextStyle(
                color: glass.textSecondary,
                fontSize: 11,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}
