import 'package:flutter/material.dart';

import '../shared/layouts/app_shell.dart';
import 'screens/admin_dashboard_screen.dart';
import 'screens/user_management_screen.dart';
import 'screens/admin_company_settings_screen.dart';
import 'screens/admin_more_screen.dart';

class AdminRoleShell extends StatefulWidget {
  const AdminRoleShell({super.key});

  @override
  State<AdminRoleShell> createState() => _AdminRoleShellState();
}

class _AdminRoleShellState extends State<AdminRoleShell> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
      AdminDashboardScreen(showAppBar: false, onNavigateTab: (idx) => setState(() => _currentIndex = idx)),
      const UserManagementScreen(showAppBar: false),
      const AdminCompanySettingsScreen(showAppBar: false),
      const AdminMoreScreen(),
    ];

    final titles = [
      '',
      'User Management',
      'Company Settings',
      'More Services',
    ];

    return AppShell(
      title: titles[_currentIndex],
      selectedIndex: _currentIndex,
      onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
      destinations: const [
        NavigationDestination(icon: Icon(Icons.home_rounded), label: 'Home'),
        NavigationDestination(icon: Icon(Icons.people_rounded), label: 'Users'),
        NavigationDestination(icon: Icon(Icons.settings_rounded), label: 'Settings'),
        NavigationDestination(icon: Icon(Icons.grid_view_rounded), label: 'More'),
      ],
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
    );
  }
}
