import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/glass_theme.dart';
import '../../core/widgets/glass_header.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/glass_search_bar.dart';
import '../../core/widgets/module_card.dart';
import '../../core/widgets/section_label.dart';
import '../../employee/screens/announcements_screen.dart';
import '../../employee/screens/holidays_screen.dart';
import '../../employee/screens/my_expense_invoices_screen.dart';
import '../../employee/screens/my_expenses_screen.dart';
import '../../employee/screens/my_settings_screen.dart';
import '../../helpdesk/screens/helpdesk_chatbot_screen.dart';
import '../../helpdesk/screens/helpdesk_dashboard_screen.dart';
import '../../helpdesk/screens/helpdesk_knowledge_base_screen.dart';
import '../../helpdesk/screens/helpdesk_tickets_screen.dart';
import 'finance_approvals_screen.dart';
import 'finance_benefit_dashboard_screen.dart';
import 'finance_benefit_payments_screen.dart';
import 'finance_benefit_reports_screen.dart';
import 'finance_benefits_screen.dart';
import 'finance_employee_salaries_screen.dart';
import 'finance_loans_advances_screen.dart';
import 'finance_pay_cycles_screen.dart';
import 'finance_payments_screen.dart';
import 'finance_payroll_inputs_screen.dart';
import 'finance_payroll_reports_screen.dart';
import 'finance_payroll_screen.dart';
import 'finance_reimbursements_screen.dart';
import 'finance_reports_screen.dart';
import 'finance_salary_components_screen.dart';
import 'finance_salary_revisions_screen.dart';
import 'finance_salary_structure_screen.dart';
import 'finance_tax_compliance_screen.dart';

class SubModuleItem {
  final String name;
  final String description;
  final IconData icon;
  final List<Color> colors;
  final Widget screen;

  SubModuleItem({
    required this.name,
    required this.description,
    required this.icon,
    required this.colors,
    required this.screen,
  });
}

class ParentModuleItem {
  final String title;
  final String description;
  final IconData icon;
  final List<Color> colors;
  final List<SubModuleItem> submodules;

  ParentModuleItem({
    required this.title,
    required this.description,
    required this.icon,
    required this.colors,
    required this.submodules,
  });
}

class SearchResultItem {
  final String parentTitle;
  final SubModuleItem submodule;

  SearchResultItem({
    required this.parentTitle,
    required this.submodule,
  });
}

class FinanceMoreScreen extends ConsumerStatefulWidget {
  final bool showAppBar;
  const FinanceMoreScreen({super.key, this.showAppBar = false});

  @override
  ConsumerState<FinanceMoreScreen> createState() => _FinanceMoreScreenState();
}

class _FinanceMoreScreenState extends ConsumerState<FinanceMoreScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  final List<ParentModuleItem> _parentModules = [
    ParentModuleItem(
      title: 'Finance',
      description: 'Payroll, Salaries, Benefits, Tax, Approvals & Financial Operations',
      icon: Icons.account_balance_wallet_rounded,
      colors: [const Color(0xFF6366F1), const Color(0xFF4338CA)],
      submodules: [
        SubModuleItem(
          name: 'Payroll',
          description: 'Process employee payroll and salary runs',
          icon: Icons.payments_rounded,
          colors: [const Color(0xFF6366F1), const Color(0xFF4338CA)],
          screen: const FinancePayrollScreen(),
        ),
        SubModuleItem(
          name: 'Salary Structures',
          description: 'Configure company salary structure templates',
          icon: Icons.calculate_rounded,
          colors: [const Color(0xFF6366F1), const Color(0xFF4338CA)],
          screen: const FinanceSalaryStructureScreen(),
        ),
        SubModuleItem(
          name: 'Payroll Reports',
          description: 'Payroll analytics and statutory summaries',
          icon: Icons.receipt_long_rounded,
          colors: [const Color(0xFF6366F1), const Color(0xFF4338CA)],
          screen: const FinancePayrollReportsScreen(),
        ),
        SubModuleItem(
          name: 'Reimbursements',
          description: 'Review and process employee reimbursements',
          icon: Icons.request_quote_rounded,
          colors: [const Color(0xFF6366F1), const Color(0xFF4338CA)],
          screen: const FinanceReimbursementsScreen(),
        ),
        SubModuleItem(
          name: 'Loans & Advances',
          description: 'Manage employee loan applications & recovery',
          icon: Icons.price_change_rounded,
          colors: [const Color(0xFF6366F1), const Color(0xFF4338CA)],
          screen: const FinanceLoansAdvancesScreen(),
        ),
        SubModuleItem(
          name: 'Employee Benefits',
          description: 'Employee benefit plans and claims oversight',
          icon: Icons.card_giftcard_rounded,
          colors: [const Color(0xFF6366F1), const Color(0xFF4338CA)],
          screen: const FinanceBenefitsScreen(),
        ),
        SubModuleItem(
          name: 'Tax & Compliance',
          description: 'Tax deductions and statutory compliance',
          icon: Icons.gavel_rounded,
          colors: [const Color(0xFF6366F1), const Color(0xFF4338CA)],
          screen: const FinanceTaxComplianceScreen(),
        ),
        SubModuleItem(
          name: 'Payroll Inputs',
          description: 'Variable pay, overtime, and monthly deductions',
          icon: Icons.playlist_add_check_rounded,
          colors: [const Color(0xFF6366F1), const Color(0xFF4338CA)],
          screen: const FinancePayrollInputsScreen(),
        ),
        SubModuleItem(
          name: 'Payments',
          description: 'Disbursements and bank transfer orders',
          icon: Icons.send_rounded,
          colors: [const Color(0xFF6366F1), const Color(0xFF4338CA)],
          screen: const FinancePaymentsScreen(),
        ),
        SubModuleItem(
          name: 'Finance Approvals',
          description: 'Review pending financial approval workflows',
          icon: Icons.how_to_reg_rounded,
          colors: [const Color(0xFF6366F1), const Color(0xFF4338CA)],
          screen: const FinanceApprovalsScreen(),
        ),
        SubModuleItem(
          name: 'Finance Reports',
          description: 'Comprehensive financial reports & analytics',
          icon: Icons.bar_chart_rounded,
          colors: [const Color(0xFF6366F1), const Color(0xFF4338CA)],
          screen: const FinanceReportsScreen(),
        ),
        SubModuleItem(
          name: 'Benefit Dashboard',
          description: 'Overview of company benefit metrics',
          icon: Icons.dashboard_rounded,
          colors: [const Color(0xFF6366F1), const Color(0xFF4338CA)],
          screen: FinanceBenefitDashboardScreen(onViewPayments: () {}, onViewClaims: () {}, onViewReports: () {}),
        ),
        SubModuleItem(
          name: 'Benefit Claims',
          description: 'Review employee benefit claim requests',
          icon: Icons.receipt_rounded,
          colors: [const Color(0xFF6366F1), const Color(0xFF4338CA)],
          screen: const FinanceBenefitsScreen(),
        ),
        SubModuleItem(
          name: 'Benefit Payments',
          description: 'Disburse verified benefit claims',
          icon: Icons.credit_card_rounded,
          colors: [const Color(0xFF6366F1), const Color(0xFF4338CA)],
          screen: FinanceBenefitPaymentsScreen(onViewDashboard: () {}, onViewClaims: () {}, onViewReports: () {}),
        ),
        SubModuleItem(
          name: 'Benefit Reports',
          description: 'Analytics and reports on benefit costs',
          icon: Icons.pie_chart_rounded,
          colors: [const Color(0xFF6366F1), const Color(0xFF4338CA)],
          screen: FinanceBenefitReportsScreen(onViewDashboard: () {}, onViewPayments: () {}),
        ),
        SubModuleItem(
          name: 'Employee Salaries',
          description: 'Manage individual employee salaries',
          icon: Icons.badge_rounded,
          colors: [const Color(0xFF6366F1), const Color(0xFF4338CA)],
          screen: const FinanceEmployeeSalariesScreen(),
        ),
        SubModuleItem(
          name: 'Salary Revisions',
          description: 'Salary increments and revision history',
          icon: Icons.published_with_changes_rounded,
          colors: [const Color(0xFF6366F1), const Color(0xFF4338CA)],
          screen: const FinanceSalaryRevisionsScreen(),
        ),
        SubModuleItem(
          name: 'Payroll Inputs',
          description: 'Payroll variables and manual adjustments',
          icon: Icons.tune_rounded,
          colors: [const Color(0xFF6366F1), const Color(0xFF4338CA)],
          screen: const FinancePayrollInputsScreen(),
        ),
        SubModuleItem(
          name: 'Salary Components',
          description: 'Earnings, allowances, and deductions',
          icon: Icons.list_alt_rounded,
          colors: [const Color(0xFF6366F1), const Color(0xFF4338CA)],
          screen: const FinanceSalaryComponentsScreen(),
        ),
        SubModuleItem(
          name: 'Pay Cycles',
          description: 'Configure pay cycle schedules',
          icon: Icons.date_range_rounded,
          colors: [const Color(0xFF6366F1), const Color(0xFF4338CA)],
          screen: const FinancePayCyclesScreen(),
        ),
      ],
    ),
    ParentModuleItem(
      title: 'Resources',
      description: 'Company holidays and announcements',
      icon: Icons.folder_open_rounded,
      colors: [const Color(0xFF14B8A6), const Color(0xFF0F766E)],
      submodules: [
        SubModuleItem(
          name: 'Holidays',
          description: 'Company holiday calendar',
          icon: Icons.calendar_today_rounded,
          colors: [const Color(0xFF14B8A6), const Color(0xFF0F766E)],
          screen: const HolidaysScreen(),
        ),
        SubModuleItem(
          name: 'Announcements',
          description: 'Company announcements and news',
          icon: Icons.campaign_rounded,
          colors: [const Color(0xFF14B8A6), const Color(0xFF0F766E)],
          screen: const AnnouncementsScreen(),
        ),
      ],
    ),
    ParentModuleItem(
      title: 'Expenses Management',
      description: 'Personal and team expense tracking',
      icon: Icons.receipt_long_rounded,
      colors: [const Color(0xFF10B981), const Color(0xFF047857)],
      submodules: [
        SubModuleItem(
          name: 'Expenses',
          description: 'Submit and manage personal expenses',
          icon: Icons.receipt_rounded,
          colors: [const Color(0xFF10B981), const Color(0xFF047857)],
          screen: const MyExpensesScreen(),
        ),
        SubModuleItem(
          name: 'Team Expenses',
          description: 'Review submitted team expense invoices',
          icon: Icons.group_rounded,
          colors: [const Color(0xFF10B981), const Color(0xFF047857)],
          screen: const MyExpenseInvoicesScreen(),
        ),
      ],
    ),
    ParentModuleItem(
      title: 'HR Helpdesk',
      description: 'Support dashboard, tickets, knowledge base & AI',
      icon: Icons.headset_mic_rounded,
      colors: [const Color(0xFF0EA5E9), const Color(0xFF0369A1)],
      submodules: [
        SubModuleItem(
          name: 'Helpdesk Dashboard',
          description: 'Support tickets overview and metrics',
          icon: Icons.dashboard_rounded,
          colors: [const Color(0xFF0EA5E9), const Color(0xFF0369A1)],
          screen: const HelpdeskDashboardScreen(showAppBar: true),
        ),
        SubModuleItem(
          name: 'Helpdesk Tickets',
          description: 'Manage and resolve support tickets',
          icon: Icons.confirmation_number_rounded,
          colors: [const Color(0xFF0EA5E9), const Color(0xFF0369A1)],
          screen: const HelpdeskTicketsScreen(showAppBar: true),
        ),
        SubModuleItem(
          name: 'Knowledge Base',
          description: 'FAQs, articles, and financial guides',
          icon: Icons.auto_stories_rounded,
          colors: [const Color(0xFF0EA5E9), const Color(0xFF0369A1)],
          screen: const HelpdeskKnowledgeBaseScreen(showAppBar: true),
        ),
        SubModuleItem(
          name: 'AI Assistant',
          description: 'Chat with AI assistant for queries',
          icon: Icons.smart_toy_rounded,
          colors: [const Color(0xFF0EA5E9), const Color(0xFF0369A1)],
          screen: const HelpdeskChatbotScreen(),
        ),
      ],
    ),
    ParentModuleItem(
      title: 'Settings',
      description: 'Personal application preferences and account settings',
      icon: Icons.settings_rounded,
      colors: [const Color(0xFF64748B), const Color(0xFF334155)],
      submodules: [
        SubModuleItem(
          name: 'My Settings',
          description: 'App preferences and account settings',
          icon: Icons.manage_accounts_rounded,
          colors: [const Color(0xFF64748B), const Color(0xFF334155)],
          screen: const MySettingsScreen(),
        ),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isSearching = _searchQuery.trim().isNotEmpty;

    final filteredParents = _parentModules.where((parent) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      if (parent.title.toLowerCase().contains(q) || parent.description.toLowerCase().contains(q)) {
        return true;
      }
      return parent.submodules.any((s) => s.name.toLowerCase().contains(q) || s.description.toLowerCase().contains(q));
    }).toList();

    final content = ListView(
      padding: const EdgeInsets.only(top: 4, bottom: 20),
      children: [
        GlassSearchBar(
          controller: _searchController,
          placeholder: "Search finance modules...",
          onChanged: (val) => setState(() => _searchQuery = val),
          onClear: () => setState(() => _searchQuery = ''),
        ),
        const SectionLabel("FINANCE MODULES"),
        if (isSearching && filteredParents.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.search_off_rounded, size: 48, color: Colors.grey),
                  const SizedBox(height: 12),
                  const Text('No Finance modules found', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text('No results for "$_searchQuery"', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                    child: const Text('Clear Search'),
                  ),
                ],
              ),
            ),
          )
        else
          ...filteredParents.map((parent) {
            return ModuleCard(
              icon: parent.icon,
              gradientColors: parent.colors,
              title: parent.title,
              subtitle: parent.description,
              count: parent.submodules.length,
              onPress: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ParentSubmodulesScreen(parent: parent),
                  ),
                );
              },
            );
          }),
      ],
    );

    if (!widget.showAppBar) {
      return Material(color: Colors.transparent, child: content);
    }

    return GlassScaffold(
      title: "Finance Modules",
      showBottomBar: false,
      body: content,
    );
  }
}

class ParentSubmodulesScreen extends StatelessWidget {
  final ParentModuleItem parent;
  const ParentSubmodulesScreen({super.key, required this.parent});

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      appBar: GlassHeader(
        title: parent.title,
        userInitial: "FIN",
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        children: [
          const SectionLabel("SUBMODULES"),
          ...parent.submodules.map((sub) {
            return ModuleCard(
              icon: sub.icon,
              gradientColors: sub.colors,
              title: sub.name,
              subtitle: sub.description,
              count: 1,
              onPress: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => sub.screen),
                );
              },
            );
          }),
        ],
      ),
    );
  }
}
