import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../admin/screens/admin_attendance_screen.dart';
import '../../admin/screens/admin_branches_screen.dart';
import '../../admin/screens/admin_company_settings_screen.dart';
import '../../admin/screens/admin_designations_screen.dart';
import '../../admin/screens/admin_email_sms_config_screen.dart';
import '../../admin/screens/admin_employee_management_screen.dart';
import '../../admin/screens/admin_hr_management_screen.dart';
import '../../admin/screens/admin_notification_settings_screen.dart';
import '../../admin/screens/admin_reporting_hierarchy_screen.dart';
import '../../admin/screens/admin_tl_management_screen.dart';
import '../../admin/screens/admin_training_form_screen.dart';
import '../../core/theme/glass_theme.dart';
import '../../core/widgets/glass_header.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/glass_search_bar.dart';
import '../../core/widgets/module_card.dart';
import '../../core/widgets/section_label.dart';
import '../../employee/screens/break_tracker_screen.dart';
import '../../employee/screens/daily_work_update_screen.dart';
import '../../employee/screens/holidays_screen.dart';
import '../../employee/screens/my_attendance_screen.dart';
import '../../employee/screens/my_settings_screen.dart';
import '../../employee/screens/punch_in_out_screen.dart';
import '../../finance/screens/finance_employee_salaries_screen.dart';
import '../../finance/screens/finance_payroll_inputs_screen.dart';
import '../../finance/screens/finance_payroll_reports_screen.dart';
import '../../finance/screens/finance_salary_revisions_screen.dart';
import '../../finance/screens/finance_salary_structure_screen.dart';
import '../../it/screens/it_offboarding_screen.dart';
import '../../it/screens/it_onboarding_screen.dart';
import 'attendance/hr_attendance_corrections_screen.dart';
import 'attendance/hr_attendance_rule_form_screen.dart';
import 'attendance/hr_attendance_rules_screen.dart';
import 'attendance/hr_attendance_screen.dart';
import 'attendance/hr_attendance_summary_screen.dart';
import 'branches/hr_branches_screen.dart';
import 'departments/hr_departments_screen.dart';
import 'designations/hr_designations_screen.dart';
import 'employees/hr_employees_screen.dart';
import 'hr_announcements_screen.dart';
import 'hr_benefit_invoices_screen.dart';
import 'hr_documents_screen.dart';
import 'hr_leave_management_screen.dart';
import 'hr_payroll_reports_screen.dart';
import 'hr_payroll_screen.dart';
import 'hr_salary_packages_screen.dart';
import 'hr_salary_screen.dart';
import 'hr_salary_structures_screen.dart';
import 'hr_performance_screen.dart';
import 'hr_profile_screen.dart';
import 'hr_reports_screen.dart';
import 'onboarding/hr_onboarding_screen.dart';
import 'recruitment/hr_recruitment_screen.dart';
import 'shifts/hr_shift_screen.dart';
import 'training/hr_training_dashboard_screen.dart';
import 'training/hr_training_screen.dart';
import 'training/hr_categories_screen.dart';
import 'training/hr_assign_training_screen.dart';
import 'training/hr_certificates_screen.dart';
import 'training/hr_training_reports_screen.dart';

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

class HrMoreScreen extends ConsumerStatefulWidget {
  final bool showAppBar;
  const HrMoreScreen({super.key, this.showAppBar = false});

  @override
  ConsumerState<HrMoreScreen> createState() => _HrMoreScreenState();
}

class _HrMoreScreenState extends ConsumerState<HrMoreScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  final List<ParentModuleItem> _parentModules = [
    ParentModuleItem(
      title: 'My Space',
      description: 'Attendance, Daily Updates, Break Tracker',
      icon: Icons.space_dashboard_rounded,
      colors: [const Color(0xFF3B82F6), const Color(0xFF1D4ED8)],
      submodules: [
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
      ],
    ),
    ParentModuleItem(
      title: 'People',
      description: 'Employees, Departments, Designations, Branches',
      icon: Icons.people_alt_rounded,
      colors: [const Color(0xFF10B981), const Color(0xFF047857)],
      submodules: [
        SubModuleItem(
          name: 'Employees',
          description: 'View employee directory and records',
          icon: Icons.badge_rounded,
          colors: [const Color(0xFF10B981), const Color(0xFF047857)],
          screen: const HrEmployeesScreen(),
        ),
        SubModuleItem(
          name: 'Departments',
          description: 'Organization departments and teams',
          icon: Icons.business_rounded,
          colors: [const Color(0xFF10B981), const Color(0xFF047857)],
          screen: const HrDepartmentsScreen(),
        ),
        SubModuleItem(
          name: 'Designations',
          description: 'Job titles and role designations',
          icon: Icons.assignment_ind_rounded,
          colors: [const Color(0xFF10B981), const Color(0xFF047857)],
          screen: const HrDesignationsScreen(),
        ),
        SubModuleItem(
          name: 'Branches Management',
          description: 'Company branch office locations',
          icon: Icons.location_city_rounded,
          colors: [const Color(0xFF10B981), const Color(0xFF047857)],
          screen: const HrBranchesScreen(),
        ),
      ],
    ),

    ParentModuleItem(
      title: 'Time & Attendance',
      description: 'Attendance, Shifts, Corrections, Rules, Settings',
      icon: Icons.access_time_filled_rounded,
      colors: [const Color(0xFF06B6D4), const Color(0xFF0E7490)],
      submodules: [
        SubModuleItem(
          name: 'Attendance',
          description: 'Monitor and manage employee attendance',
          icon: Icons.calendar_month_rounded,
          colors: [const Color(0xFF06B6D4), const Color(0xFF0E7490)],
          screen: const HrAttendanceScreen(),
        ),
        SubModuleItem(
          name: 'Shifts',
          description: 'Shift scheduling and assignment',
          icon: Icons.work_history_rounded,
          colors: [const Color(0xFF06B6D4), const Color(0xFF0E7490)],
          screen: const HrShiftScreen(),
        ),
        SubModuleItem(
          name: 'Attendance Corrections',
          description: 'Review and approve attendance adjustments',
          icon: Icons.edit_calendar_rounded,
          colors: [const Color(0xFF06B6D4), const Color(0xFF0E7490)],
          screen: const HrAttendanceCorrectionsScreen(),
        ),
        SubModuleItem(
          name: 'Attendance Reports',
          description: 'Attendance summary and analytics',
          icon: Icons.summarize_rounded,
          colors: [const Color(0xFF06B6D4), const Color(0xFF0E7490)],
          screen: const HrAttendanceSummaryScreen(),
        ),
        SubModuleItem(
          name: 'Attendance Rules',
          description: 'Configure overtime, grace period, and rules',
          icon: Icons.tune_rounded,
          colors: [const Color(0xFF06B6D4), const Color(0xFF0E7490)],
          screen: const HrAttendanceRulesScreen(),
        ),
        SubModuleItem(
          name: 'Attendance Settings',
          description: 'Attendance policy configuration',
          icon: Icons.settings_applications_rounded,
          colors: [const Color(0xFF06B6D4), const Color(0xFF0E7490)],
          screen: const AdminAttendanceScreen(initialModule: 'settings'),
        ),
      ],
    ),
    ParentModuleItem(
      title: 'Leave Management',
      description: 'Leave requests and approvals',
      icon: Icons.event_note_rounded,
      colors: [const Color(0xFFF472B6), const Color(0xFFBE185D)],
      submodules: [
        SubModuleItem(
          name: 'Leave',
          description: 'Leave management center and approvals',
          icon: Icons.event_note_rounded,
          colors: [const Color(0xFFF472B6), const Color(0xFFBE185D)],
          screen: const HrLeaveManagementScreen(),
        ),
      ],
    ),
    ParentModuleItem(
      title: 'Finance',
      description: 'Payroll, Salary Structures, Reports, Revisions, Inputs, Packages',
      icon: Icons.account_balance_wallet_rounded,
      colors: [const Color(0xFF6366F1), const Color(0xFF4338CA)],
      submodules: [
        SubModuleItem(
          name: 'Payroll',
          description: 'Process employee payroll and compensation',
          icon: Icons.payments_rounded,
          colors: [const Color(0xFF6366F1), const Color(0xFF4338CA)],
          screen: const HrPayrollScreen(),
        ),
        SubModuleItem(
          name: 'Salary Structures',
          description: 'Manage salary structure templates & pay grades',
          icon: Icons.calculate_rounded,
          colors: [const Color(0xFF6366F1), const Color(0xFF4338CA)],
          screen: const HrSalaryStructuresScreen(),
        ),
        SubModuleItem(
          name: 'Payroll Reports',
          description: 'Payroll analytics and compensation reports',
          icon: Icons.assessment_rounded,
          colors: [const Color(0xFF6366F1), const Color(0xFF4338CA)],
          screen: const HrPayrollReportsScreen(),
        ),
        SubModuleItem(
          name: 'Employee Salaries',
          description: 'Employee salary directory & structure details',
          icon: Icons.badge_rounded,
          colors: [const Color(0xFF6366F1), const Color(0xFF4338CA)],
          screen: const HrSalaryScreen(activeTab: 'salaries'),
        ),
        SubModuleItem(
          name: 'Salary Revisions',
          description: 'Salary revision requests and approval workflow',
          icon: Icons.published_with_changes_rounded,
          colors: [const Color(0xFF6366F1), const Color(0xFF4338CA)],
          screen: const HrSalaryScreen(activeTab: 'revisions'),
        ),
        SubModuleItem(
          name: 'Payroll Inputs',
          description: 'Verify overtime, bonuses & attendance inputs',
          icon: Icons.playlist_add_check_rounded,
          colors: [const Color(0xFF6366F1), const Color(0xFF4338CA)],
          screen: const HrSalaryScreen(activeTab: 'inputs'),
        ),
        SubModuleItem(
          name: 'Salary Packages',
          description: 'Annual tax slabs & standard package templates',
          icon: Icons.layers_rounded,
          colors: [const Color(0xFF6366F1), const Color(0xFF4338CA)],
          screen: const HrSalaryPackagesScreen(),
        ),
      ],
    ),
    ParentModuleItem(
      title: 'Recruitment',
      description: 'Job Openings and Candidate Onboarding',
      icon: Icons.person_search_rounded,
      colors: [const Color(0xFFF59E0B), const Color(0xFFB45309)],
      submodules: [
        SubModuleItem(
          name: 'Job Openings',
          description: 'Job postings and candidate recruitment',
          icon: Icons.work_outline_rounded,
          colors: [const Color(0xFFF59E0B), const Color(0xFFB45309)],
          screen: const HrRecruitmentScreen(),
        ),
        SubModuleItem(
          name: 'Onboarding',
          description: 'Employee onboarding workflows',
          icon: Icons.person_add_alt_1_rounded,
          colors: [const Color(0xFFF59E0B), const Color(0xFFB45309)],
          screen: const HrOnboardingScreen(),
        ),
      ],
    ),
    ParentModuleItem(
      title: 'Performance & Growth',
      description: 'Performance appraisals and training programs',
      icon: Icons.trending_up_rounded,
      colors: [const Color(0xFFEC4899), const Color(0xFF9D174D)],
      submodules: [
        SubModuleItem(
          name: 'Performance',
          description: 'Employee performance reviews and goals',
          icon: Icons.star_rounded,
          colors: [const Color(0xFFEC4899), const Color(0xFF9D174D)],
          screen: const HrPerformanceScreen(),
        ),
      ],
    ),
    ParentModuleItem(
      title: 'Resources',
      description: 'Company documents, holidays, and announcements',
      icon: Icons.folder_open_rounded,
      colors: [const Color(0xFF14B8A6), const Color(0xFF0F766E)],
      submodules: [
        SubModuleItem(
          name: 'Documents',
          description: 'Company policy documents and forms',
          icon: Icons.description_rounded,
          colors: [const Color(0xFF14B8A6), const Color(0xFF0F766E)],
          screen: const HrDocumentsScreen(),
        ),
        SubModuleItem(
          name: 'Holidays',
          description: 'Company holiday calendar',
          icon: Icons.calendar_today_rounded,
          colors: [const Color(0xFF14B8A6), const Color(0xFF0F766E)],
          screen: const HolidaysScreen(),
        ),
        SubModuleItem(
          name: 'Announcements',
          description: 'Publish company announcements',
          icon: Icons.campaign_rounded,
          colors: [const Color(0xFF14B8A6), const Color(0xFF0F766E)],
          screen: const HrAnnouncementsScreen(),
        ),
      ],
    ),
    ParentModuleItem(
      title: 'Reports',
      description: 'HR Reports and Organizational Analytics',
      icon: Icons.analytics_rounded,
      colors: [const Color(0xFF0EA5E9), const Color(0xFF0369A1)],
      submodules: [
        SubModuleItem(
          name: 'HR Reports',
          description: 'Comprehensive HR reports and analytics',
          icon: Icons.insert_chart_rounded,
          colors: [const Color(0xFF0EA5E9), const Color(0xFF0369A1)],
          screen: const HrReportsScreen(),
        ),
      ],
    ),
    ParentModuleItem(
      title: 'Administration',
      description: 'Company Settings, Email/SMS, Notifications',
      icon: Icons.admin_panel_settings_rounded,
      colors: [const Color(0xFF64748B), const Color(0xFF334155)],
      submodules: [
        SubModuleItem(
          name: 'Company Settings',
          description: 'Company profile and general settings',
          icon: Icons.domain_rounded,
          colors: [const Color(0xFF64748B), const Color(0xFF334155)],
          screen: const AdminCompanySettingsScreen(),
        ),
        SubModuleItem(
          name: 'Email/SMS Configuration',
          description: 'Email and SMS gateway settings',
          icon: Icons.mark_email_read_rounded,
          colors: [const Color(0xFF64748B), const Color(0xFF334155)],
          screen: const AdminEmailSmsConfigScreen(),
        ),
        SubModuleItem(
          name: 'Notification Settings',
          description: 'System notification triggers and rules',
          icon: Icons.notifications_active_rounded,
          colors: [const Color(0xFF64748B), const Color(0xFF334155)],
          screen: const AdminNotificationSettingsScreen(),
        ),
      ],
    ),
    ParentModuleItem(
      title: 'Management',
      description: 'Employee, TL, and HR Management',
      icon: Icons.manage_accounts_rounded,
      colors: [const Color(0xFF3B82F6), const Color(0xFF1E3A8A)],
      submodules: [
        SubModuleItem(
          name: 'Employee Management',
          description: 'Manage employee access and roles',
          icon: Icons.groups_3_rounded,
          colors: [const Color(0xFF3B82F6), const Color(0xFF1E3A8A)],
          screen: const AdminEmployeeManagementScreen(),
        ),
        SubModuleItem(
          name: 'TL Management',
          description: 'Team Lead assignment and management',
          icon: Icons.supervisor_account_rounded,
          colors: [const Color(0xFF3B82F6), const Color(0xFF1E3A8A)],
          screen: const AdminTlManagementScreen(),
        ),
        SubModuleItem(
          name: 'HR Management',
          description: 'HR manager roles and permissions',
          icon: Icons.admin_panel_settings_rounded,
          colors: [const Color(0xFF3B82F6), const Color(0xFF1E3A8A)],
          screen: const AdminHrManagementScreen(),
        ),
      ],
    ),
    ParentModuleItem(
      title: 'Organization',
      description: 'Reporting hierarchy and organization tree',
      icon: Icons.account_tree_rounded,
      colors: [const Color(0xFF8B5CF6), const Color(0xFF4C1D95)],
      submodules: [
        SubModuleItem(
          name: 'Reporting Hierarchy',
          description: 'View and manage reporting relationships',
          icon: Icons.schema_rounded,
          colors: [const Color(0xFF8B5CF6), const Color(0xFF4C1D95)],
          screen: const AdminReportingHierarchyScreen(),
        ),
      ],
    ),
    ParentModuleItem(
      title: 'Training',
      description: 'Dashboard, Courses, Categories, Lectures, Progress',
      icon: Icons.school_rounded,
      colors: [const Color(0xFFA855F7), const Color(0xFF6B21A8)],
      submodules: [
        SubModuleItem(
          name: 'Dashboard',
          description: 'Training metrics and analytics overview',
          icon: Icons.dashboard_rounded,
          colors: [const Color(0xFFA855F7), const Color(0xFF6B21A8)],
          screen: const HrTrainingDashboardScreen(),
        ),
        SubModuleItem(
          name: 'Courses',
          description: 'Training courses directory',
          icon: Icons.menu_book_rounded,
          colors: [const Color(0xFFA855F7), const Color(0xFF6B21A8)],
          screen: const HrTrainingScreen(),
        ),
        SubModuleItem(
          name: 'Categories',
          description: 'Course categories and tags',
          icon: Icons.category_rounded,
          colors: [const Color(0xFFA855F7), const Color(0xFF6B21A8)],
          screen: const HrCategoriesScreen(),
        ),
        SubModuleItem(
          name: 'Assign Training',
          description: 'Assign training programs to employees',
          icon: Icons.assignment_turned_in_rounded,
          colors: [const Color(0xFFA855F7), const Color(0xFF6B21A8)],
          screen: const HrAssignTrainingScreen(),
        ),
        SubModuleItem(
          name: 'Employee Progress',
          description: 'Track employee course completion',
          icon: Icons.donut_large_rounded,
          colors: [const Color(0xFFA855F7), const Color(0xFF6B21A8)],
          screen: const HrTrainingReportsScreen(),
        ),
        SubModuleItem(
          name: 'Training Reports',
          description: 'Training participation and completion reports',
          icon: Icons.bar_chart_rounded,
          colors: [const Color(0xFFA855F7), const Color(0xFF6B21A8)],
          screen: const HrTrainingReportsScreen(),
        ),
      ],
    ),
    ParentModuleItem(
      title: 'IT Operations',
      description: 'IT Onboarding and IT Offboarding',
      icon: Icons.devices_other_rounded,
      colors: [const Color(0xFF0284C7), const Color(0xFF0369A1)],
      submodules: [
        SubModuleItem(
          name: 'IT Onboarding',
          description: 'Setup hardware and accounts for new hires',
          icon: Icons.person_add_rounded,
          colors: [const Color(0xFF0284C7), const Color(0xFF0369A1)],
          screen: const ItOnboardingScreen(),
        ),
        SubModuleItem(
          name: 'IT Offboarding',
          description: 'Revoke access and collect assets',
          icon: Icons.person_remove_rounded,
          colors: [const Color(0xFF0284C7), const Color(0xFF0369A1)],
          screen: const ItOffboardingScreen(),
        ),
      ],
    ),
    ParentModuleItem(
      title: 'Employee Benefits',
      description: 'Employee benefit plans and claims',
      icon: Icons.card_giftcard_rounded,
      colors: [const Color(0xFFE11D48), const Color(0xFF9F1239)],
      submodules: [
        SubModuleItem(
          name: 'Benefits',
          description: 'Manage company employee benefits, coverage, enrollments & claims',
          icon: Icons.card_giftcard_rounded,
          colors: [const Color(0xFFE11D48), const Color(0xFF9F1239)],
          screen: const HrBenefitInvoicesScreen(),
        ),
      ],
    ),
    ParentModuleItem(
      title: 'Settings',
      description: 'Account preferences and settings',
      icon: Icons.settings_rounded,
      colors: [const Color(0xFF475569), const Color(0xFF1E293B)],
      submodules: [
        SubModuleItem(
          name: 'My Settings',
          description: 'App preferences and account settings',
          icon: Icons.manage_accounts_rounded,
          colors: [const Color(0xFF475569), const Color(0xFF1E293B)],
          screen: const MySettingsScreen(),
        ),
      ],
    ),
  ];

  List<SearchResultItem> get _searchResults {
    if (_searchQuery.trim().isEmpty) return [];
    final q = _searchQuery.trim().toLowerCase();
    final list = <SearchResultItem>[];
    for (final parent in _parentModules) {
      for (final sub in parent.submodules) {
        if (sub.name.toLowerCase().contains(q) || sub.description.toLowerCase().contains(q) || parent.title.toLowerCase().contains(q)) {
          list.add(SearchResultItem(parentTitle: parent.title, submodule: sub));
        }
      }
    }
    return list;
  }

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
          placeholder: "Search HR modules...",
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
                  const Text('No HR modules found', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
      title: "HR Modules",
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
        userInitial: "HR",
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
