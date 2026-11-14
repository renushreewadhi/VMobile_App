import 'package:flutter/material.dart';
import '../theme/glass_theme.dart';
import 'glass_card.dart';

class GlassTab {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isSelected;
  final int? badgeCount;
  final bool isAction;

  const GlassTab({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.isSelected,
    this.badgeCount,
    this.isAction = false,
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
              if (tab.isAction) {
                return GestureDetector(
                  onTap: tab.onTap,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F6B66),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0F6B66).withOpacity(0.4),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
                  ),
                );
              }

              return Semantics(
                selected: tab.isSelected,
                button: true,
                label: tab.label,
                child: Material(
                  color: tab.isSelected ? glass.activeTabFill : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    onTap: tab.onTap,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Icon(
                                tab.icon,
                                size: 20,
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
                          const SizedBox(height: 3),
                          Text(
                            tab.label,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: tab.isSelected ? FontWeight.w800 : FontWeight.w600,
                              color: tab.isSelected ? glass.activeTabContent : glass.inactiveTab,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
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
