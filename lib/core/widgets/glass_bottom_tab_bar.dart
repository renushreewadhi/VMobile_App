import 'package:flutter/material.dart';
import '../theme/glass_theme.dart';
import 'glass_card.dart';

class GlassTab {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isSelected;
  final int? badgeCount;

  const GlassTab({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.isSelected,
    this.badgeCount,
  });
}

class GlassBottomTabBar extends StatelessWidget {
  final List<GlassTab> tabs;

  const GlassBottomTabBar({
    super.key,
    required this.tabs,
  });

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    return Positioned(
      left: 12,
      right: 12,
      bottom: bottomPadding > 0 ? bottomPadding + 8 : 16,
      child: RepaintBoundary(
        child: GlassSurface(
          blur: true,
          radius: glass.navRadius,
          fillColor: glass.navFill,
          borderColor: glass.navBorder,
          shadow: glass.navShadow,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: tabs.map((tab) {
              return Semantics(
                selected: tab.isSelected,
                button: true,
                label: tab.label,
                child: GestureDetector(
                  onTap: tab.onTap,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    padding: EdgeInsets.symmetric(
                      horizontal: tab.isSelected ? 14 : 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: tab.isSelected ? glass.activeTabFill : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Icon(
                              tab.icon,
                              size: 22,
                              color: tab.isSelected ? glass.activeTabContent : glass.inactiveTab,
                            ),
                            if (tab.badgeCount != null && tab.badgeCount! > 0)
                              Positioned(
                                right: -6,
                                top: -4,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: glass.error,
                                    shape: BoxShape.circle,
                                  ),
                                  constraints: const BoxConstraints(
                                    minWidth: 14,
                                    minHeight: 14,
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${tab.badgeCount}',
                                      style: const TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        if (tab.isSelected) ...[
                          const SizedBox(width: 6),
                          Text(
                            tab.label,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: glass.activeTabContent,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
