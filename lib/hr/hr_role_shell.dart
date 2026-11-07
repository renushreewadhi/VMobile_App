import 'package:flutter/material.dart';

import '../shared/layouts/app_shell.dart';
import 'screens/employees/hr_employees_screen.dart';
import 'screens/hr_announcements_screen.dart';
import 'screens/hr_dashboard_screen.dart';
import 'screens/hr_documents_screen.dart';
import 'screens/hr_more_screen.dart';

class HrRoleShell extends StatefulWidget {
  const HrRoleShell({super.key});

  @override
  State<HrRoleShell> createState() => _HrRoleShellState();
}

class _HrRoleShellState extends State<HrRoleShell> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
      HrDashboardScreen(onNavigateTab: (idx) => setState(() => _currentIndex = idx)),
      const HrEmployeesScreen(showAppBar: false),
      const HrAnnouncementsScreen(showAppBar: false),
      const HrDocumentsScreen(showAppBar: false),
      const HrMoreScreen(),
    ];

    final titles = [
      'HR Dashboard',
      'Employee Directory',
      'Company Announcements',
      'Document Management',
      'More Services',
    ];

    return AppShell(
      title: titles[_currentIndex],
      selectedIndex: _currentIndex,
      onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
      destinations: const [
        NavigationDestination(icon: Icon(Icons.home_rounded), label: 'Home'),
        NavigationDestination(icon: Icon(Icons.people_rounded), label: 'Directory'),
        NavigationDestination(icon: Icon(Icons.campaign_rounded), label: 'Announcements'),
        NavigationDestination(icon: Icon(Icons.folder_rounded), label: 'Documents'),
        NavigationDestination(icon: Icon(Icons.grid_view_rounded), label: 'More'),
      ],
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
    );
  }
}
