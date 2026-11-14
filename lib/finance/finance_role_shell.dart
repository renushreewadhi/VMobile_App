import 'package:flutter/material.dart';

import '../shared/layouts/app_shell.dart';
import 'screens/finance_approvals_screen.dart';
import 'screens/finance_dashboard_screen.dart';
import 'screens/finance_more_screen.dart';
import 'screens/finance_payroll_screen.dart';
import 'screens/finance_reimbursements_screen.dart';

class FinanceRoleShell extends StatefulWidget {
  const FinanceRoleShell({super.key});

  @override
  State<FinanceRoleShell> createState() => _FinanceRoleShellState();
}

class _FinanceRoleShellState extends State<FinanceRoleShell> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
      FinanceDashboardScreen(onNavigateTab: (idx) => setState(() => _currentIndex = idx)),
      const FinancePayrollScreen(),
      const FinanceReimbursementsScreen(),
      const FinanceApprovalsScreen(),
      const FinanceMoreScreen(),
    ];

    final titles = [
      '',
      'Payroll Management',
      'Reimbursements',
      'Finance Approvals',
      'More Services',
    ];

    return AppShell(
      title: titles[_currentIndex],
      selectedIndex: _currentIndex,
      onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
      destinations: const [
        NavigationDestination(icon: Icon(Icons.home_rounded), label: 'Home'),
        NavigationDestination(icon: Icon(Icons.attach_money_rounded), label: 'Payroll'),
        NavigationDestination(icon: Icon(Icons.receipt_long_rounded), label: 'Expenses'),
        NavigationDestination(icon: Icon(Icons.verified_user_rounded), label: 'Approvals'),
        NavigationDestination(icon: Icon(Icons.grid_view_rounded), label: 'More'),
      ],
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
    );
  }
}
