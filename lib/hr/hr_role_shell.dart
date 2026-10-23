import 'package:flutter/material.dart';

import '../shared/layouts/app_shell.dart';
import 'screens/hr_announcements_screen.dart';
import 'screens/hr_dashboard_screen.dart';
import 'screens/employees/hr_employees_screen.dart';
import 'screens/hr_documents_screen.dart';

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
      const HrAnnouncementsScreen(),
      const HrDocumentsScreen(),
    ];

    final titles = [
      'HR Dashboard',
      'Employee Directory',
      'Company Announcements',
      'Document Management',
    ];

    return AppShell(
      title: titles[_currentIndex],
      selectedIndex: _currentIndex,
      onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
      destinations: const [
        NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
        NavigationDestination(icon: Icon(Icons.people), label: 'Directory'),
        NavigationDestination(icon: Icon(Icons.campaign), label: 'Announcements'),
        NavigationDestination(icon: Icon(Icons.folder), label: 'Documents'),
      ],
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
    );
  }
}
