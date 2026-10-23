import 'package:flutter/material.dart';

import '../shared/layouts/app_shell.dart';
import 'screens/finance_approvals_screen.dart';
import 'screens/finance_benefit_dashboard_screen.dart';
import 'screens/finance_benefit_payments_screen.dart';
import 'screens/finance_benefit_reports_screen.dart';
import 'screens/finance_benefits_screen.dart';
import 'screens/finance_dashboard_screen.dart';
import 'screens/finance_loans_advances_screen.dart';
import 'screens/finance_payments_screen.dart';
import 'screens/finance_payroll_screen.dart';
import 'screens/finance_reimbursements_screen.dart';
import 'screens/finance_reports_screen.dart';
import 'screens/finance_salary_structure_screen.dart';
import 'screens/finance_tax_compliance_screen.dart';

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
      FinanceBenefitDashboardScreen(
        onViewPayments: () => setState(() => _currentIndex = 5),
        onViewClaims: () => setState(() => _currentIndex = 7),
        onViewReports: () => setState(() => _currentIndex = 6),
      ),
      const FinancePaymentsScreen(),
      FinanceBenefitReportsScreen(
        onViewDashboard: () => setState(() => _currentIndex = 4),
        onViewPayments: () => setState(() => _currentIndex = 5),
      ),
      const FinanceBenefitsScreen(),
      const FinanceLoansAdvancesScreen(),
      FinanceBenefitPaymentsScreen(
        onViewDashboard: () => setState(() => _currentIndex = 4),
        onViewClaims: () => setState(() => _currentIndex = 7),
        onViewReports: () => setState(() => _currentIndex = 6),
      ),
      const FinanceReportsScreen(),
      const FinanceSalaryStructureScreen(),
      const FinanceTaxComplianceScreen(),
    ];

    final titles = [
      'Finance Dashboard',
      'Payroll Management',
      'Reimbursement Claims',
      'Finance Approvals',
      'Benefit Finance',
      'Disbursements & Wire Transfers',
      'Benefit Cost Reports',
      'Benefit Claims & Payments',
      'Loans & Advances',
      'Benefit Payment History',
      'Financial Reports & Audit Analytics',
      'Salary Structure Configuration',
      'Tax & Statutory Compliance',
    ];

    return AppShell(
      title: titles[_currentIndex],
      selectedIndex: _currentIndex > 4 ? 4 : _currentIndex,
      onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
      destinations: const [
        NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
        NavigationDestination(icon: Icon(Icons.attach_money), label: 'Payroll'),
        NavigationDestination(icon: Icon(Icons.receipt_long), label: 'Expenses'),
        NavigationDestination(icon: Icon(Icons.verified_user), label: 'Approvals'),
        NavigationDestination(icon: Icon(Icons.card_giftcard), label: 'Benefits'),
      ],
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
    );
  }
}
