import 'package:flutter/material.dart';

import '../shared/layouts/app_shell.dart';
import 'screens/it_access_screen.dart';
import 'screens/it_asset_requests_screen.dart';
import 'screens/it_assets_screen.dart';
import 'screens/it_dashboard_screen.dart';
import 'screens/it_employee_accounts_screen.dart';
import 'screens/it_more_screen.dart';
import 'screens/it_offboarding_screen.dart';
import 'screens/it_onboarding_screen.dart';
import 'screens/it_reports_screen.dart';
import 'screens/it_security_screen.dart';
import 'screens/it_software_screen.dart';
import 'screens/it_tickets_screen.dart';

class ItRoleShell extends StatefulWidget {
  const ItRoleShell({super.key});

  @override
  State<ItRoleShell> createState() => _ItRoleShellState();
}

class _ItRoleShellState extends State<ItRoleShell> {
  int _currentIndex = 0;

  void _handleNavigateTab(int idx) {
    if (idx < 4) {
      setState(() => _currentIndex = idx);
    } else if (idx == 4) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const ItAccessScreen(showAppBar: true)));
    } else {
      Widget targetScreen;
      switch (idx) {
        case 5:
          targetScreen = const ItTicketsScreen(showAppBar: true);
          break;
        case 6:
          targetScreen = const ItOnboardingScreen(showAppBar: true);
          break;
        case 7:
          targetScreen = const ItOffboardingScreen(showAppBar: true);
          break;
        case 8:
          targetScreen = const ItEmployeeAccountsScreen(showAppBar: true);
          break;
        case 9:
          targetScreen = const ItSecurityScreen(showAppBar: true);
          break;
        case 10:
          targetScreen = const ItReportsScreen(showAppBar: true);
          break;
        default:
          targetScreen = const ItMoreScreen();
      }
      Navigator.push(context, MaterialPageRoute(builder: (_) => targetScreen));
    }
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      ItDashboardScreen(onNavigateTab: _handleNavigateTab),
      const ItAssetsScreen(showAppBar: false),
      const ItAssetRequestsScreen(showAppBar: false),
      const ItSoftwareScreen(showAppBar: false),
      const ItMoreScreen(showAppBar: false),
    ];

    final titles = [
      '',
      'Asset Inventory',
      'Asset Requests',
      'Software Licenses',
      'More Services',
    ];

    return AppShell(
      title: titles[_currentIndex],
      selectedIndex: _currentIndex,
      onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
      destinations: const [
        NavigationDestination(icon: Icon(Icons.home_rounded), label: 'Home'),
        NavigationDestination(icon: Icon(Icons.laptop_mac_rounded), label: 'Assets'),
        NavigationDestination(icon: Icon(Icons.assignment_rounded), label: 'Requests'),
        NavigationDestination(icon: Icon(Icons.apps_rounded), label: 'Software'),
        NavigationDestination(icon: Icon(Icons.grid_view_rounded), label: 'More'),
      ],
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
    );
  }
}
