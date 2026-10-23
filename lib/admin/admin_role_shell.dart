import 'package:flutter/material.dart';

import '../shared/layouts/app_shell.dart';
import 'screens/admin_dashboard_screen.dart';
import 'screens/system_settings_screen.dart';
import 'screens/user_management_screen.dart';

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
      AdminDashboardScreen(onNavigateTab: (idx) => setState(() => _currentIndex = idx)),
      const UserManagementScreen(showAppBar: false),
      const SystemSettingsScreen(),
    ];

    final titles = [
      'Admin Dashboard',
      'User Management',
      'System Settings',
    ];

    return AppShell(
      title: titles[_currentIndex],
      selectedIndex: _currentIndex,
      onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
      destinations: const [
        NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
        NavigationDestination(icon: Icon(Icons.people), label: 'Users'),
        NavigationDestination(icon: Icon(Icons.settings), label: 'Settings'),
      ],
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
    );
  }
}
