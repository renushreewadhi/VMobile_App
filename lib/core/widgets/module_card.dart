import 'package:flutter/material.dart';
import '../theme/glass_theme.dart';
import 'glass_card.dart';

class ModuleCard extends StatefulWidget {
  final IconData icon;
  final List<Color> gradientColors;
  final String title;
  final String? subtitle;
  final int count;
  final VoidCallback onPress;

  const ModuleCard({
    super.key,
    required this.icon,
    required this.gradientColors,
    required this.title,
    this.subtitle,
    required this.count,
    required this.onPress,
  });

  @override
  State<ModuleCard> createState() => _ModuleCardState();
}

class _ModuleCardState extends State<ModuleCard> with SingleTickerProviderStateMixin {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    final hasSubtitle = widget.subtitle != null && widget.subtitle!.trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.onPress,
        child: AnimatedScale(
          scale: _isPressed ? 0.98 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeInOut,
          child: GlassCard(
            blur: false, // performance rule: no BackdropFilter on list items
            radius: glass.cardRadius,
            fillColor: glass.cardFill,
            borderColor: glass.cardBorder,
            shadow: glass.cardShadow,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Icon tile (46x46, radius 14, gradient)
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: widget.gradientColors,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: widget.gradientColors.last.withOpacity(0.30),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      widget.icon,
                      size: 22,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                // Title (and subtitle if present)
                Expanded(
                  child: hasSubtitle
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.title,
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                color: glass.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.subtitle!,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                                color: glass.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        )
                      : Text(
                          widget.title,
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: glass.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                ),
                const SizedBox(width: 12),
                // Count badge (30px circle)
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: glass.badgeFill,
                  ),
                  child: Center(
                    child: Text(
                      '${widget.count}',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: glass.badgeText,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Chevron
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: glass.chevronColor,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
