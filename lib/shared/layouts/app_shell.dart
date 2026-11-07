import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/glass_header.dart';
import '../../core/widgets/glass_bottom_tab_bar.dart';

class AppShell extends ConsumerStatefulWidget {
  final Widget body;
  final String title;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<NavigationDestination> destinations;

  const AppShell({
    super.key,
    required this.body,
    required this.title,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
  });

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  @override
  Widget build(BuildContext context) {
    final glassTabs = widget.destinations.asMap().entries.map((entry) {
      final idx = entry.key;
      final dest = entry.value;

      IconData iconData = Icons.circle_outlined;
      if (dest.icon is Icon) {
        iconData = (dest.icon as Icon).icon ?? Icons.circle_outlined;
      }

      return GlassTab(
        icon: iconData,
        label: dest.label,
        isSelected: widget.selectedIndex == idx,
        onTap: () => widget.onDestinationSelected(idx),
      );
    }).toList();

    return GlassScaffold(
      appBar: GlassHeader(title: widget.title), // Fixed brand header
      showBottomBar: true,
      body: widget.body,
      tabs: glassTabs.isNotEmpty ? glassTabs : null,
    );
  }
}
