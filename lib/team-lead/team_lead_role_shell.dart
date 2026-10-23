import 'package:flutter/material.dart';

import '../shared/layouts/app_shell.dart';
import 'screens/my_team_screen.dart';
import 'screens/team_leave_approval_screen.dart';
import 'screens/tl_dashboard_screen.dart';

class TeamLeadRoleShell extends StatefulWidget {
  const TeamLeadRoleShell({super.key});

  @override
  State<TeamLeadRoleShell> createState() => _TeamLeadRoleShellState();
}

class _TeamLeadRoleShellState extends State<TeamLeadRoleShell> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final screens = <Widget>[
      TlDashboardScreen(onNavigateTab: (idx) => setState(() => _currentIndex = idx)),
      const MyTeamScreen(),
      const TeamLeaveApprovalScreen(),
    ];

    final titles = [
      'Team Lead Dashboard',
      'My Team Members',
      'Team Leave Approvals',
    ];

    return AppShell(
      title: titles[_currentIndex],
      selectedIndex: _currentIndex,
      onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
      destinations: const [
        NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
        NavigationDestination(icon: Icon(Icons.people), label: 'My Team'),
        NavigationDestination(icon: Icon(Icons.task_alt), label: 'Approvals'),
      ],
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
    );
  }
}
