import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/glass_theme.dart';
import '../../core/widgets/glass_header.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/glass_search_bar.dart';
import '../../core/widgets/module_card.dart';
import '../../core/widgets/section_label.dart';
import '../../employee/screens/announcements_screen.dart';
import '../../employee/screens/break_tracker_screen.dart';
import '../../employee/screens/daily_work_update_screen.dart';
import '../../employee/screens/holidays_screen.dart';
import '../../employee/screens/apply_leave_screen.dart';
import '../../employee/screens/my_assets_screen.dart';
import '../../employee/screens/my_attendance_screen.dart';
import '../../employee/screens/my_benefits_screen.dart';
import '../../employee/screens/my_documents_screen.dart';
import '../../employee/screens/my_expense_invoices_screen.dart';
import '../../employee/screens/my_expenses_screen.dart';
import '../../employee/screens/my_leave_screen.dart';
import '../../employee/screens/my_payslips_screen.dart';
import '../../employee/screens/my_profile_screen.dart';
import '../../employee/screens/my_salary_screen.dart';
import '../../employee/screens/my_settings_screen.dart';
import '../../employee/screens/punch_in_out_screen.dart';
import '../../employee/screens/wfh_apply_screen.dart';
import '../../helpdesk/screens/helpdesk_chatbot_screen.dart';
import '../../helpdesk/screens/helpdesk_dashboard_screen.dart';
import '../../helpdesk/screens/helpdesk_knowledge_base_screen.dart';
import '../../helpdesk/screens/helpdesk_tickets_screen.dart';
import '../../it/screens/it_asset_requests_screen.dart';
import '../../it/screens/it_security_screen.dart';
import '../../admin/screens/admin_performance_screen.dart';
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
      title: 'My Space',
      description: 'My Profile, Attendance, Check In/Out, Break Tracker & Daily Updates',
      icon: Icons.space_dashboard_rounded,
      colors: [const Color(0xFF3B82F6), const Color(0xFF1D4ED8)],
      submodules: [
        SubModuleItem(
          name: 'My Profile',
          description: 'View and edit your personal profile and details',
          icon: Icons.person_rounded,
          colors: [const Color(0xFF3B82F6), const Color(0xFF1D4ED8)],
          screen: const MyProfileScreen(showAppBar: true),
        ),
        SubModuleItem(
          name: 'My Attendance',
          description: 'Personal attendance records and logs',
          icon: Icons.calendar_today_rounded,
          colors: [const Color(0xFF3B82F6), const Color(0xFF1D4ED8)],
          screen: const MyAttendanceScreen(showAppBar: true),
        ),
        SubModuleItem(
          name: 'Check In/Out',
          description: 'Check in, check out, live status tracking',
          icon: Icons.touch_app_rounded,
          colors: [const Color(0xFF3B82F6), const Color(0xFF1D4ED8)],
          screen: const PunchInOutScreen(),
        ),
        SubModuleItem(
          name: 'Break Tracker',
          description: 'Manage your break time and history',
          icon: Icons.free_breakfast_rounded,
          colors: [const Color(0xFF3B82F6), const Color(0xFF1D4ED8)],
          screen: const BreakTrackerScreen(showAppBar: true),
        ),
        SubModuleItem(
          name: 'Daily Work Update',
          description: 'Submit and view daily task and progress updates',
          icon: Icons.edit_note_rounded,
          colors: [const Color(0xFF3B82F6), const Color(0xFF1D4ED8)],
          screen: const DailyWorkUpdateScreen(showAppBar: true),
        ),
      ],
    ),
    ParentModuleItem(
      title: 'Time & Attendance',
      description: 'Work from home requests and status',
      icon: Icons.access_time_filled_rounded,
      colors: [const Color(0xFF06B6D4), const Color(0xFF0891B2)],
      submodules: [
        SubModuleItem(
          name: 'WFH Apply',
          description: 'Work from home requests and status',
          icon: Icons.home_work_rounded,
          colors: [const Color(0xFF06B6D4), const Color(0xFF0891B2)],
          screen: const WfhApplyScreen(),
        ),
      ],
    ),
    ParentModuleItem(
      title: 'Leave Management',
      description: 'Leave requests, applications and balances',
      icon: Icons.event_note_rounded,
      colors: [const Color(0xFFEC4899), const Color(0xFFBE185D)],
      submodules: [
        SubModuleItem(
          name: 'My Leave',
          description: 'View your leave balance and applications',
          icon: Icons.event_available_rounded,
          colors: [const Color(0xFFEC4899), const Color(0xFFBE185D)],
          screen: const MyLeaveScreen(showAppBar: true),
        ),
        SubModuleItem(
          name: 'Apply Leave',
          description: 'Submit new leave applications',
          icon: Icons.event_note_rounded,
          colors: [const Color(0xFFEC4899), const Color(0xFFBE185D)],
          screen: const ApplyLeaveScreen(),
        ),
      ],
    ),
    ParentModuleItem(
      title: 'Finance & Payroll Operations',
      description: 'Payroll runs, employee salaries, structures, packages, components & reports',
      icon: Icons.account_balance_wallet_rounded,
      colors: [const Color(0xFF6366F1), const Color(0xFF4338CA)],
      submodules: [
        SubModuleItem(
          name: 'Payroll',
          description: 'Process employee payroll and salary runs',
          icon: Icons.payments_rounded,
          colors: [const Color(0xFF6366F1), const Color(0xFF4338CA)],
          screen: const FinancePayrollScreen(showAppBar: true),
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
          screen: const FinanceReimbursementsScreen(showAppBar: true),
        ),
        SubModuleItem(
          name: 'Loans & Advances',
          description: 'Manage employee loan applications & recovery',
          icon: Icons.price_change_rounded,
          colors: [const Color(0xFF6366F1), const Color(0xFF4338CA)],
          screen: const FinanceLoansAdvancesScreen(showAppBar: true),
        ),
        SubModuleItem(
          name: 'Employee Benefits',
          description: 'Employee benefit plans and claims oversight',
          icon: Icons.card_giftcard_rounded,
          colors: [const Color(0xFF6366F1), const Color(0xFF4338CA)],
          screen: const FinanceBenefitsScreen(showAppBar: true),
        ),
        SubModuleItem(
          name: 'Tax & Compliance',
          description: 'Tax deductions and statutory compliance',
          icon: Icons.gavel_rounded,
          colors: [const Color(0xFF6366F1), const Color(0xFF4338CA)],
          screen: const FinanceTaxComplianceScreen(showAppBar: true),
        ),
        SubModuleItem(
          name: 'Payroll Inputs',
          description: 'Variable pay, overtime, and monthly deductions',
          icon: Icons.playlist_add_check_rounded,
          colors: [const Color(0xFF6366F1), const Color(0xFF4338CA)],
          screen: const FinancePayrollScreen(showAppBar: true),
        ),
        SubModuleItem(
          name: 'Payments',
          description: 'Disbursements and bank transfer orders',
          icon: Icons.send_rounded,
          colors: [const Color(0xFF6366F1), const Color(0xFF4338CA)],
          screen: const FinancePaymentsScreen(showAppBar: true),
        ),
        SubModuleItem(
          name: 'Finance Approvals',
          description: 'Review pending financial approval workflows',
          icon: Icons.how_to_reg_rounded,
          colors: [const Color(0xFF6366F1), const Color(0xFF4338CA)],
          screen: const FinanceApprovalsScreen(showAppBar: true),
        ),
        SubModuleItem(
          name: 'Finance Reports',
          description: 'Comprehensive financial reports & analytics',
          icon: Icons.bar_chart_rounded,
          colors: [const Color(0xFF6366F1), const Color(0xFF4338CA)],
          screen: const FinanceReportsScreen(showAppBar: true),
        ),
        SubModuleItem(
          name: 'Benefit Dashboard',
          description: 'Overview of company benefit metrics',
          icon: Icons.dashboard_rounded,
          colors: [const Color(0xFF6366F1), const Color(0xFF4338CA)],
          screen: const FinanceBenefitDashboardScreen(showAppBar: true),
        ),
        SubModuleItem(
          name: 'Benefit Claims',
          description: 'Review employee benefit claim requests',
          icon: Icons.receipt_rounded,
          colors: [const Color(0xFF6366F1), const Color(0xFF4338CA)],
          screen: const FinanceBenefitsScreen(showAppBar: true),
        ),
        SubModuleItem(
          name: 'Benefit Payments',
          description: 'Disburse verified benefit claims',
          icon: Icons.credit_card_rounded,
          colors: [const Color(0xFF6366F1), const Color(0xFF4338CA)],
          screen: const FinanceBenefitPaymentsScreen(showAppBar: true),
        ),
        SubModuleItem(
          name: 'Benefit Reports',
          description: 'Analytics and reports on benefit costs',
          icon: Icons.pie_chart_rounded,
          colors: [const Color(0xFF6366F1), const Color(0xFF4338CA)],
          screen: const FinanceBenefitReportsScreen(showAppBar: true),
        ),
        SubModuleItem(
          name: 'Employee Salaries',
          description: 'Manage individual employee salaries',
          icon: Icons.badge_rounded,
          colors: [const Color(0xFF6366F1), const Color(0xFF4338CA)],
          screen: const FinanceEmployeeSalariesScreen(showAppBar: true),
        ),
        SubModuleItem(
          name: 'Salary Revisions',
          description: 'Salary increments and revision history',
          icon: Icons.published_with_changes_rounded,
          colors: [const Color(0xFF6366F1), const Color(0xFF4338CA)],
          screen: const FinanceSalaryRevisionsScreen(showAppBar: true),
        ),
        SubModuleItem(
          name: 'Payroll Inputs',
          description: 'Payroll variables and manual adjustments',
          icon: Icons.tune_rounded,
          colors: [const Color(0xFF6366F1), const Color(0xFF4338CA)],
          screen: const FinancePayrollScreen(showAppBar: true),
        ),
        SubModuleItem(
          name: 'Salary Components',
          description: 'Earnings, allowances, and deductions',
          icon: Icons.list_alt_rounded,
          colors: [const Color(0xFF6366F1), const Color(0xFF4338CA)],
          screen: const FinanceSalaryComponentsScreen(showAppBar: true),
        ),
        SubModuleItem(
          name: 'Pay Cycles',
          description: 'Configure pay cycle schedules',
          icon: Icons.date_range_rounded,
          colors: [const Color(0xFF6366F1), const Color(0xFF4338CA)],
          screen: const FinancePayCyclesScreen(showAppBar: true),
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
      title: 'My Payroll',
      description: 'Personal payslips and salary breakdown',
      icon: Icons.wallet_rounded,
      colors: [const Color(0xFF8B5CF6), const Color(0xFF6D28D9)],
      submodules: [
        SubModuleItem(
          name: 'My Payslips',
          description: 'View and download your monthly payslips',
          icon: Icons.receipt_long_rounded,
          colors: [const Color(0xFF8B5CF6), const Color(0xFF6D28D9)],
          screen: const MyPayslipsScreen(showAppBar: true),
        ),
        SubModuleItem(
          name: 'My Salary',
          description: 'View your salary breakdown and details',
          icon: Icons.account_balance_wallet_rounded,
          colors: [const Color(0xFF8B5CF6), const Color(0xFF6D28D9)],
          screen: const MySalaryScreen(showAppBar: true),
        ),
      ],
    ),
    ParentModuleItem(
      title: 'Performance & Growth',
      description: 'Performance reviews, goals, and appraisals',
      icon: Icons.trending_up_rounded,
      colors: [const Color(0xFFF59E0B), const Color(0xFFD97706)],
      submodules: [
        SubModuleItem(
          name: 'Performance',
          description: 'Employee performance reviews and feedback',
          icon: Icons.star_rounded,
          colors: [const Color(0xFFF59E0B), const Color(0xFFD97706)],
          screen: const AdminPerformanceScreen(),
        ),
      ],
    ),
    ParentModuleItem(
      title: 'Resources',
      description: 'Company holiday calendar and announcements',
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
      title: 'My Resources',
      description: 'Personal documents and files',
      icon: Icons.folder_shared_rounded,
      colors: [const Color(0xFF0284C7), const Color(0xFF0369A1)],
      submodules: [
        SubModuleItem(
          name: 'My Documents',
          description: 'View and manage your personal documents',
          icon: Icons.description_rounded,
          colors: [const Color(0xFF0284C7), const Color(0xFF0369A1)],
          screen: const MyDocumentsScreen(showAppBar: true),
        ),
      ],
    ),
    ParentModuleItem(
      title: 'My Assets',
      description: 'Company assigned assets and equipment',
      icon: Icons.devices_rounded,
      colors: [const Color(0xFF0284C7), const Color(0xFF0369A1)],
      submodules: [
        SubModuleItem(
          name: 'My Assets',
          description: 'View and track your assigned company assets',
          icon: Icons.laptop_mac_rounded,
          colors: [const Color(0xFF0284C7), const Color(0xFF0369A1)],
          screen: const MyAssetsScreen(showAppBar: true),
        ),
      ],
    ),
    ParentModuleItem(
      title: 'Reports',
      description: 'Financial reports, audit ledgers, payroll summaries & statements',
      icon: Icons.bar_chart_rounded,
      colors: [const Color(0xFF0EA5E9), const Color(0xFF0369A1)],
      submodules: [
        SubModuleItem(
          name: 'Reports',
          description: 'Financial reports and audit analytics',
          icon: Icons.bar_chart_rounded,
          colors: [const Color(0xFF0EA5E9), const Color(0xFF0369A1)],
          screen: const FinanceReportsScreen(showAppBar: true),
        ),
      ],
    ),
    ParentModuleItem(
      title: 'IT Operations',
      description: 'Asset requests, software licenses, security and IT audits',
      icon: Icons.computer_rounded,
      colors: [const Color(0xFF3B82F6), const Color(0xFF1E40AF)],
      submodules: [
        SubModuleItem(
          name: 'Asset Requests',
          description: 'Request and track hardware or software assets',
          icon: Icons.assignment_rounded,
          colors: [const Color(0xFF3B82F6), const Color(0xFF1E40AF)],
          screen: const ItAssetRequestsScreen(showAppBar: true),
        ),
        SubModuleItem(
          name: 'Security & Audit',
          description: 'IT security policies, compliance and audit logs',
          icon: Icons.security_rounded,
          colors: [const Color(0xFF3B82F6), const Color(0xFF1E40AF)],
          screen: const ItSecurityScreen(showAppBar: true),
        ),
      ],
    ),
    ParentModuleItem(
      title: 'Employee Benefits',
      description: 'Employee benefit plans and enrollment',
      icon: Icons.card_giftcard_rounded,
      colors: [const Color(0xFFEC4899), const Color(0xFFBE185D)],
      submodules: [
        SubModuleItem(
          name: 'My Benefits',
          description: 'View and manage your employee benefits',
          icon: Icons.favorite_rounded,
          colors: [const Color(0xFFEC4899), const Color(0xFFBE185D)],
          screen: const MyBenefitsScreen(showAppBar: true),
        ),
      ],
    ),
    ParentModuleItem(
      title: 'HR Helpdesk',
      description: 'Chat with AI assistant for queries',
      icon: Icons.headset_mic_rounded,
      colors: [const Color(0xFF0EA5E9), const Color(0xFF0369A1)],
      submodules: [
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
      title: 'Settings & Governance',
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
