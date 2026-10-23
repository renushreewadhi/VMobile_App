import 'package:flutter/material.dart';

import '../shared/layouts/app_shell.dart';
import 'screens/it_dashboard_screen.dart';
import 'screens/it_assets_screen.dart';
import 'screens/it_asset_requests_screen.dart';
import 'screens/it_software_screen.dart';
import 'screens/it_access_screen.dart';
import 'screens/it_tickets_screen.dart';
import 'screens/it_onboarding_screen.dart';
import 'screens/it_offboarding_screen.dart';
import 'screens/it_security_screen.dart';
import 'screens/it_reports_screen.dart';
import 'screens/it_employee_accounts_screen.dart';
import 'screens/it_create_employee_account_screen.dart';

class ItRoleShell extends StatefulWidget {
  const ItRoleShell({super.key});

  @override
  State<ItRoleShell> createState() => _ItRoleShellState();
}

class _ItRoleShellState extends State<ItRoleShell> {
  int _currentIndex = 0;
  String? _subRouteArg; // e.g., for edit account ID

  @override
  Widget build(BuildContext context) {
    final screens = [
      ItDashboardScreen(onNavigateTab: (idx) => setState(() => _currentIndex = idx)),
      const ItAssetsScreen(),
      const ItAssetRequestsScreen(),
      const ItSoftwareScreen(),
      const ItAccessScreen(),
      const ItTicketsScreen(),
      const ItOnboardingScreen(),
      const ItOffboardingScreen(),
      const ItSecurityScreen(),
      const ItReportsScreen(),
      const ItEmployeeAccountsScreen(),
      const ItCreateEmployeeAccountScreen(),
    ];

    final titles = [
      'IT Admin Dashboard',
      'Asset Inventory',
      'Asset Requests',
      'Software Licenses',
      'Access Control',
      'IT Support Tickets',
      'IT Onboarding',
      'IT Offboarding',
      'Security Audit Logs',
      'IT Reports & Audits',
      'Employee IT Accounts',
      'Configure IT Account',
    ];

    return AppShell(
      title: titles[_currentIndex > 11 ? 0 : _currentIndex],
      selectedIndex: _currentIndex > 4 ? 0 : _currentIndex,
      onDestinationSelected: (idx) => setState(() {
        _currentIndex = idx;
      }),
      destinations: const [
        NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
        NavigationDestination(icon: Icon(Icons.laptop), label: 'Assets'),
        NavigationDestination(icon: Icon(Icons.assignment), label: 'Requests'),
        NavigationDestination(icon: Icon(Icons.grid_view), label: 'Software'),
        NavigationDestination(icon: Icon(Icons.analytics), label: 'Reports'),
      ],
      body: IndexedStack(
        index: _currentIndex < screens.length ? _currentIndex : 0,
        children: screens,
      ),
    );
  }
}
