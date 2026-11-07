import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/glass_theme.dart';
import '../../core/widgets/glass_header.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/glass_search_bar.dart';
import '../../core/widgets/module_card.dart';
import '../../core/widgets/section_label.dart';
import '../../employee/screens/daily_work_update_screen.dart';
import '../../employee/screens/my_assets_screen.dart';
import '../../employee/screens/my_benefits_screen.dart';
import '../../employee/screens/my_expenses_screen.dart';
import '../../employee/screens/my_salary_screen.dart';
import '../../employee/screens/my_payslips_screen.dart';
import '../../employee/screens/my_settings_screen.dart';
import '../../employee/screens/notifications_screen.dart';
import '../../employee/screens/training_screens.dart';
import '../../employee/screens/wfh_apply_screen.dart';
import '../../team-lead/screens/tl_benefits_screen.dart';
import '../../helpdesk/screens/helpdesk_chatbot_screen.dart';
import '../../helpdesk/screens/helpdesk_dashboard_screen.dart';
import '../../helpdesk/screens/helpdesk_knowledge_base_screen.dart';
import '../../helpdesk/screens/helpdesk_tickets_screen.dart';
import '../../resources/screens/holidays_screen.dart';
import 'admin_announcements_screen.dart';
import 'admin_benefits_management_screen.dart';
import 'admin_attendance_screen.dart';
import 'admin_audit_logs_screen.dart';
import 'admin_benefit_invoices_screen.dart';
import 'admin_branches_screen.dart';
import 'admin_company_settings_screen.dart';
import 'admin_departments_screen.dart';
import 'admin_designations_screen.dart';
import 'admin_documents_screen.dart';
import 'admin_email_sms_config_screen.dart';
import 'admin_employee_management_screen.dart';
import 'admin_employees_screen.dart';
import 'admin_expenses_screen.dart';
import 'admin_expense_invoices_screen.dart';
import 'admin_hr_management_screen.dart';
import 'admin_leave_management_screen.dart';
import 'admin_notification_settings_screen.dart';
import 'admin_onboarding_screen.dart';
import 'admin_payroll_screen.dart';
import 'admin_payroll_reports_screen.dart';
import 'admin_performance_screen.dart';
import 'admin_projects_screen.dart';
import 'admin_recruitment_screen.dart';
import 'admin_reporting_hierarchy_screen.dart';
import 'admin_reports_screen.dart';
import 'admin_roles_permissions_screen.dart';
import 'admin_salary_config_screen.dart';
import 'admin_shift_management_screen.dart';
import 'admin_teams_screen.dart';
import 'admin_tl_management_screen.dart';
import 'admin_training_screen.dart';
import 'admin_training_form_screen.dart';
import '../../hr/screens/training/hr_categories_screen.dart';
import '../../hr/screens/training/hr_assign_training_screen.dart';
import '../../hr/screens/training/hr_certificates_screen.dart';
import '../../hr/screens/training/hr_training_reports_screen.dart';
import 'system_settings_screen.dart';
import 'user_management_screen.dart';

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

class AdminMoreScreen extends ConsumerStatefulWidget {
  const AdminMoreScreen({super.key});

  @override
  ConsumerState<AdminMoreScreen> createState() => _AdminMoreScreenState();
}

class _AdminMoreScreenState extends ConsumerState<AdminMoreScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  final List<ParentModuleItem> _parentModules = [
    ParentModuleItem(
      title: 'My Space',
      description: 'Work From Home (WFH) requests and personal tools',
      icon: Icons.person_outline_rounded,
      colors: [const Color(0xFF34D399), const Color(0xFF059669)],
      submodules: [
        SubModuleItem(
          name: 'WFH Apply',
          description: 'Work from home requests and status',
          icon: Icons.home_work_rounded,
          colors: [const Color(0xFF34D399), const Color(0xFF059669)],
          screen: const WfhApplyScreen(),
        ),
      ],
    ),
    ParentModuleItem(
      title: 'People',
      description: 'Employees, Departments, Designations, Branches, Teams',
      icon: Icons.people_rounded,
      colors: [const Color(0xFFFB923C), const Color(0xFFEA580C)],
      submodules: [
        SubModuleItem(
          name: 'Employees',
          description: 'Manage employee profiles and details',
          icon: Icons.supervisor_account,
          colors: [const Color(0xFFFB923C), const Color(0xFFEA580C)],
          screen: const AdminEmployeesScreen(),
        ),
        SubModuleItem(
          name: 'Departments',
          description: 'Manage company departments',
          icon: Icons.apartment,
          colors: [const Color(0xFFFB923C), const Color(0xFFEA580C)],
          screen: const AdminDepartmentsScreen(),
        ),
        SubModuleItem(
          name: 'Designations',
          description: 'Manage job designations and roles',
          icon: Icons.badge,
          colors: [const Color(0xFFFB923C), const Color(0xFFEA580C)],
          screen: const AdminDesignationsScreen(),
        ),
        SubModuleItem(
          name: 'Branches',
          description: 'Manage company branches and locations',
          icon: Icons.business,
          colors: [const Color(0xFFFB923C), const Color(0xFFEA580C)],
          screen: const AdminBranchesScreen(),
        ),
        SubModuleItem(
          name: 'Teams',
          description: 'Manage team structures and members',
          icon: Icons.group,
          colors: [const Color(0xFFFB923C), const Color(0xFFEA580C)],
          screen: const AdminTeamsScreen(),
        ),
      ],
    ),

    ParentModuleItem(
      title: 'Time & Attendance',
      description: 'Attendance, Shifts, Corrections, Reports, Rules, Settings',
      icon: Icons.access_time_filled_rounded,
      colors: [const Color(0xFF06B6D4), const Color(0xFF0891B2)],
      submodules: [
        SubModuleItem(
          name: 'Attendance',
          description: 'Employee attendance logs and records',
          icon: Icons.calendar_today,
          colors: [const Color(0xFF06B6D4), const Color(0xFF0891B2)],
          screen: const AdminAttendanceScreen(),
        ),
        SubModuleItem(
          name: 'Shifts',
          description: 'Shift management and scheduling',
          icon: Icons.work_history,
          colors: [const Color(0xFF06B6D4), const Color(0xFF0891B2)],
          screen: const AdminShiftManagementScreen(),
        ),
        SubModuleItem(
          name: 'Attendance Corrections',
          description: 'Punch correction and regularization requests',
          icon: Icons.edit_calendar,
          colors: [const Color(0xFF06B6D4), const Color(0xFF0891B2)],
          screen: const AdminAttendanceScreen(initialModule: 'corrections'),
        ),
        SubModuleItem(
          name: 'Attendance Reports',
          description: 'Attendance analytics and reports',
          icon: Icons.bar_chart,
          colors: [const Color(0xFF06B6D4), const Color(0xFF0891B2)],
          screen: const AdminReportsScreen(),
        ),
        SubModuleItem(
          name: 'Attendance Rules',
          description: 'Attendance policies and rules',
          icon: Icons.rule,
          colors: [const Color(0xFF06B6D4), const Color(0xFF0891B2)],
          screen: const AdminAttendanceScreen(initialModule: 'rules'),
        ),
        SubModuleItem(
          name: 'Attendance Settings',
          description: 'System attendance and shift settings',
          icon: Icons.settings_applications,
          colors: [const Color(0xFF06B6D4), const Color(0xFF0891B2)],
          screen: const SystemSettingsScreen(),
        ),
      ],
    ),
    ParentModuleItem(
      title: 'Leave Management',
      description: 'Leave requests, approvals, and balances',
      icon: Icons.event_note_rounded,
      colors: [const Color(0xFFEC4899), const Color(0xFFBE185D)],
      submodules: [
        SubModuleItem(
          name: 'Leave',
          description: 'Employee leave applications and management',
          icon: Icons.event_note,
          colors: [const Color(0xFFEC4899), const Color(0xFFBE185D)],
          screen: const AdminLeaveManagementScreen(),
        ),
      ],
    ),
    ParentModuleItem(
      title: 'Finance',
      description: 'Payroll, Salary Structures, Payroll Reports, and Salary Packages',
      icon: Icons.account_balance_wallet_rounded,
      colors: [const Color(0xFF10B981), const Color(0xFF047857)],
      submodules: [
        SubModuleItem(
          name: 'Payroll',
          description: 'Payroll runs and salary distribution',
          icon: Icons.payments,
          colors: [const Color(0xFF10B981), const Color(0xFF047857)],
          screen: const AdminPayrollScreen(),
        ),
        SubModuleItem(
          name: 'Salary Structures',
          description: 'Configure salary structures and templates',
          icon: Icons.calculate,
          colors: [const Color(0xFF10B981), const Color(0xFF047857)],
          screen: const AdminSalaryConfigScreen(),
        ),
        SubModuleItem(
          name: 'Payroll Reports',
          description: 'Payroll analytics and financial reports',
          icon: Icons.receipt_long,
          colors: [const Color(0xFF10B981), const Color(0xFF047857)],
          screen: const AdminPayrollReportsScreen(),
        ),
        SubModuleItem(
          name: 'Salary Packages',
          description: 'Manage salary packages and components',
          icon: Icons.layers,
          colors: [const Color(0xFF10B981), const Color(0xFF047857)],
          screen: const AdminSalaryConfigScreen(),
        ),
      ],
    ),
    ParentModuleItem(
      title: 'My Payroll',
      description: 'Personal payslips and salary breakdown',
      icon: Icons.account_balance_wallet_rounded,
      colors: [const Color(0xFF6366F1), const Color(0xFF4338CA)],
      submodules: [
        SubModuleItem(
          name: 'My Payslips',
          description: 'View and download your monthly payslips',
          icon: Icons.receipt_long,
          colors: [const Color(0xFF6366F1), const Color(0xFF4338CA)],
          screen: const MyPayslipsScreen(showAppBar: true),
        ),
        SubModuleItem(
          name: 'My Salary',
          description: 'View your salary breakdown and details',
          icon: Icons.account_balance_wallet,
          colors: [const Color(0xFF6366F1), const Color(0xFF4338CA)],
          screen: const MySalaryScreen(showAppBar: true),
        ),
      ],
    ),
    ParentModuleItem(
      title: 'Recruitment',
      description: 'Job Openings, Candidate Pipeline, and Onboarding',
      icon: Icons.person_add_rounded,
      colors: [const Color(0xFF3B82F6), const Color(0xFF1D4ED8)],
      submodules: [
        SubModuleItem(
          name: 'Job Openings',
          description: 'Manage job vacancies, postings, and candidates',
          icon: Icons.work,
          colors: [const Color(0xFF3B82F6), const Color(0xFF1D4ED8)],
          screen: const AdminRecruitmentScreen(),
        ),
        SubModuleItem(
          name: 'Onboarding',
          description: 'Manage new hire onboarding and documentation',
          icon: Icons.person_add,
          colors: [const Color(0xFF3B82F6), const Color(0xFF1D4ED8)],
          screen: const AdminOnboardingScreen(),
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
          icon: Icons.star,
          colors: [const Color(0xFFF59E0B), const Color(0xFFD97706)],
          screen: const AdminPerformanceScreen(),
        ),
      ],
    ),
    ParentModuleItem(
      title: 'My Work',
      description: 'Projects, tasks, and work tracking',
      icon: Icons.work_outline_rounded,
      colors: [const Color(0xFF8B5CF6), const Color(0xFF6D28D9)],
      submodules: [
        SubModuleItem(
          name: 'My Projects',
          description: 'View and manage assigned projects',
          icon: Icons.folder_special,
          colors: [const Color(0xFF8B5CF6), const Color(0xFF6D28D9)],
          screen: const AdminProjectsScreen(),
        ),
      ],
    ),
    ParentModuleItem(
      title: 'Resources',
      description: 'Documents, holidays, and announcements',
      icon: Icons.folder_rounded,
      colors: [const Color(0xFF14B8A6), const Color(0xFF0D9488)],
      submodules: [
        SubModuleItem(
          name: 'Documents',
          description: 'Company policies and shared documents',
          icon: Icons.description,
          colors: [const Color(0xFF14B8A6), const Color(0xFF0D9488)],
          screen: const AdminDocumentsScreen(),
        ),
        SubModuleItem(
          name: 'Holidays',
          description: 'Company holiday calendar and list',
          icon: Icons.calendar_month,
          colors: [const Color(0xFF14B8A6), const Color(0xFF0D9488)],
          screen: const HolidaysScreen(),
        ),
        SubModuleItem(
          name: 'Announcements',
          description: 'Company news and announcements',
          icon: Icons.campaign,
          colors: [const Color(0xFF14B8A6), const Color(0xFF0D9488)],
          screen: const AdminAnnouncementsScreen(),
        ),
      ],
    ),
    ParentModuleItem(
      title: 'My Resources',
      description: 'Personal documents and notifications',
      icon: Icons.folder_shared_rounded,
      colors: [const Color(0xFF2DD4BF), const Color(0xFF0D9488)],
      submodules: [
        SubModuleItem(
          name: 'My Documents',
          description: 'Company policies and personal documents',
          icon: Icons.description_rounded,
          colors: [const Color(0xFF2DD4BF), const Color(0xFF0D9488)],
          screen: const AdminDocumentsScreen(),
        ),
        SubModuleItem(
          name: 'Notifications',
          description: 'System alerts and notifications',
          icon: Icons.notifications_active_rounded,
          colors: [const Color(0xFF2DD4BF), const Color(0xFF0D9488)],
          screen: const NotificationsScreen(showAppBar: true),
        ),
      ],
    ),
    ParentModuleItem(
      title: 'Reports',
      description: 'Analytics, HR reports, and audit logs',
      icon: Icons.bar_chart_rounded,
      colors: [const Color(0xFF0EA5E9), const Color(0xFF0284C7)],
      submodules: [
        SubModuleItem(
          name: 'Reports',
          description: 'Comprehensive administrative reports',
          icon: Icons.bar_chart,
          colors: [const Color(0xFF0EA5E9), const Color(0xFF0284C7)],
          screen: const AdminReportsScreen(),
        ),
      ],
    ),
    ParentModuleItem(
      title: 'My Assets',
      description: 'Assigned hardware, equipment, and asset requests',
      icon: Icons.laptop_mac_rounded,
      colors: [const Color(0xFF38BDF8), const Color(0xFF0284C7)],
      submodules: [
        SubModuleItem(
          name: 'My Assets',
          description: 'View assigned assets and equipment',
          icon: Icons.laptop_mac,
          colors: [const Color(0xFF38BDF8), const Color(0xFF0284C7)],
          screen: const MyAssetsScreen(),
        ),
      ],
    ),
    ParentModuleItem(
      title: 'Administration',
      description: 'System configuration, users, permissions, and settings',
      icon: Icons.admin_panel_settings_rounded,
      colors: [const Color(0xFF475569), const Color(0xFF1E293B)],
      submodules: [
        SubModuleItem(
          name: 'User Management',
          description: 'Manage users and system access',
          icon: Icons.people,
          colors: [const Color(0xFF475569), const Color(0xFF1E293B)],
          screen: const UserManagementScreen(showAppBar: true),
        ),
        SubModuleItem(
          name: 'Roles & Permissions',
          description: 'Manage access control and user roles',
          icon: Icons.security,
          colors: [const Color(0xFF475569), const Color(0xFF1E293B)],
          screen: const AdminRolesPermissionsScreen(),
        ),
        SubModuleItem(
          name: 'Audit Logs',
          description: 'System activity and security audit logs',
          icon: Icons.history,
          colors: [const Color(0xFF475569), const Color(0xFF1E293B)],
          screen: const AdminAuditLogsScreen(),
        ),
        SubModuleItem(
          name: 'System Settings',
          description: 'Configure core system preferences',
          icon: Icons.settings,
          colors: [const Color(0xFF475569), const Color(0xFF1E293B)],
          screen: const SystemSettingsScreen(),
        ),
        SubModuleItem(
          name: 'Company Settings',
          description: 'General company profile and branch configurations',
          icon: Icons.business,
          colors: [const Color(0xFF475569), const Color(0xFF1E293B)],
          screen: const AdminCompanySettingsScreen(),
        ),
        SubModuleItem(
          name: 'Email/SMS Configuration',
          description: 'Notification gateway and server settings',
          icon: Icons.email,
          colors: [const Color(0xFF475569), const Color(0xFF1E293B)],
          screen: const AdminEmailSmsConfigScreen(),
        ),
        SubModuleItem(
          name: 'Notification Settings',
          description: 'Configure alert and notification preferences',
          icon: Icons.notifications,
          colors: [const Color(0xFF475569), const Color(0xFF1E293B)],
          screen: const AdminNotificationSettingsScreen(),
        ),
        SubModuleItem(
          name: 'Pending Users',
          description: 'Review and approve pending user registrations',
          icon: Icons.person_add_disabled,
          colors: [const Color(0xFF475569), const Color(0xFF1E293B)],
          screen: const UserManagementScreen(showAppBar: true),
        ),
      ],
    ),
    ParentModuleItem(
      title: 'Projects',
      description: 'Project management and EOD updates',
      icon: Icons.group_work_rounded,
      colors: [const Color(0xFF0D9488), const Color(0xFF115E59)],
      submodules: [
        SubModuleItem(
          name: 'Projects',
          description: 'Manage company projects and teams',
          icon: Icons.workspaces,
          colors: [const Color(0xFF0D9488), const Color(0xFF115E59)],
          screen: const AdminProjectsScreen(),
        ),
        SubModuleItem(
          name: 'EOD Updates',
          description: 'Review end-of-day work updates',
          icon: Icons.assignment,
          colors: [const Color(0xFF0D9488), const Color(0xFF115E59)],
          screen: const DailyWorkUpdateScreen(showAppBar: true),
        ),
      ],
    ),
    ParentModuleItem(
      title: 'Management',
      description: 'Employee, TL, and HR management',
      icon: Icons.manage_accounts_rounded,
      colors: [const Color(0xFF7C3AED), const Color(0xFF5B21B6)],
      submodules: [
        SubModuleItem(
          name: 'Employee Management',
          description: 'Manage employee accounts and records',
          icon: Icons.supervised_user_circle,
          colors: [const Color(0xFF7C3AED), const Color(0xFF5B21B6)],
          screen: const AdminEmployeeManagementScreen(),
        ),
        SubModuleItem(
          name: 'TL Management',
          description: 'Manage team leads and leadership mapping',
          icon: Icons.supervisor_account,
          colors: [const Color(0xFF7C3AED), const Color(0xFF5B21B6)],
          screen: const AdminTlManagementScreen(),
        ),
        SubModuleItem(
          name: 'HR Management',
          description: 'Manage HR personnel and assignments',
          icon: Icons.admin_panel_settings,
          colors: [const Color(0xFF7C3AED), const Color(0xFF5B21B6)],
          screen: const AdminHrManagementScreen(),
        ),
      ],
    ),
    ParentModuleItem(
      title: 'Organization',
      description: 'Reporting hierarchy and organizational structure',
      icon: Icons.account_tree_rounded,
      colors: [const Color(0xFF0284C7), const Color(0xFF0369A1)],
      submodules: [
        SubModuleItem(
          name: 'Reporting Hierarchy',
          description: 'View and configure reporting lines',
          icon: Icons.account_tree,
          colors: [const Color(0xFF0284C7), const Color(0xFF0369A1)],
          screen: const AdminReportingHierarchyScreen(),
        ),
      ],
    ),
    ParentModuleItem(
      title: 'Training',
      description: 'Courses, lectures, progress, and certifications',
      icon: Icons.school_rounded,
      colors: [const Color(0xFF8B5CF6), const Color(0xFF6D28D9)],
      submodules: [
        SubModuleItem(
          name: 'Dashboard',
          description: 'Training dashboard and metrics',
          icon: Icons.dashboard,
          colors: [const Color(0xFF8B5CF6), const Color(0xFF6D28D9)],
          screen: const AdminTrainingScreen(),
        ),
        SubModuleItem(
          name: 'Courses',
          description: 'Manage training courses',
          icon: Icons.menu_book,
          colors: [const Color(0xFF8B5CF6), const Color(0xFF6D28D9)],
          screen: const AdminTrainingScreen(),
        ),
        SubModuleItem(
          name: 'Categories',
          description: 'Manage training categories',
          icon: Icons.folder,
          colors: [const Color(0xFF8B5CF6), const Color(0xFF6D28D9)],
          screen: const HrCategoriesScreen(),
        ),
        SubModuleItem(
          name: 'Add Course',
          description: 'Create a new training course',
          icon: Icons.add_circle_outline,
          colors: [const Color(0xFF8B5CF6), const Color(0xFF6D28D9)],
          screen: const AdminTrainingFormScreen(),
        ),
        SubModuleItem(
          name: 'Assign Training',
          description: 'Assign courses to employees or teams',
          icon: Icons.assignment_ind,
          colors: [const Color(0xFF8B5CF6), const Color(0xFF6D28D9)],
          screen: const HrAssignTrainingScreen(),
        ),
        SubModuleItem(
          name: 'Employee Progress',
          description: 'Track employee learning progress',
          icon: Icons.trending_up,
          colors: [const Color(0xFF8B5CF6), const Color(0xFF6D28D9)],
          screen: const HrTrainingReportsScreen(),
        ),
        SubModuleItem(
          name: 'Training Reports',
          description: 'Training analytics and reports',
          icon: Icons.bar_chart,
          colors: [const Color(0xFF8B5CF6), const Color(0xFF6D28D9)],
          screen: const HrTrainingReportsScreen(),
        ),
        SubModuleItem(
          name: 'My Courses',
          description: 'Enrolled courses and learning status',
          icon: Icons.library_books,
          colors: [const Color(0xFF8B5CF6), const Color(0xFF6D28D9)],
          screen: const MyCoursesScreen(),
        ),
        SubModuleItem(
          name: 'In Progress',
          description: 'Ongoing training courses',
          icon: Icons.hourglass_top,
          colors: [const Color(0xFF8B5CF6), const Color(0xFF6D28D9)],
          screen: const TrainingInProgressScreen(),
        ),
        SubModuleItem(
          name: 'Completed',
          description: 'Finished training courses',
          icon: Icons.check_circle,
          colors: [const Color(0xFF8B5CF6), const Color(0xFF6D28D9)],
          screen: const TrainingCompletedScreen(),
        ),
        SubModuleItem(
          name: 'My Certificates',
          description: 'Earned training certificates',
          icon: Icons.card_membership,
          colors: [const Color(0xFF8B5CF6), const Color(0xFF6D28D9)],
          screen: const MyCertificatesScreen(),
        ),
        SubModuleItem(
          name: 'Training History',
          description: 'Past training records and history',
          icon: Icons.history,
          colors: [const Color(0xFF8B5CF6), const Color(0xFF6D28D9)],
          screen: const TrainingHistoryScreen(),
        ),
      ],
    ),
    ParentModuleItem(
      title: 'IT Operations',
      description: 'IT assets, requests, licenses, and access management',
      icon: Icons.computer_rounded,
      colors: [const Color(0xFF0284C7), const Color(0xFF0369A1)],
      submodules: [
        SubModuleItem(
          name: 'IT Assets',
          description: 'Manage company IT hardware and equipment',
          icon: Icons.laptop,
          colors: [const Color(0xFF0284C7), const Color(0xFF0369A1)],
          screen: const MyAssetsScreen(),
        ),
        SubModuleItem(
          name: 'Asset Requests',
          description: 'Review and process IT asset requests',
          icon: Icons.assignment,
          colors: [const Color(0xFF0284C7), const Color(0xFF0369A1)],
          screen: const MyAssetsScreen(),
        ),
        SubModuleItem(
          name: 'Asset Assignment',
          description: 'Assign hardware assets to employees',
          icon: Icons.swap_horiz,
          colors: [const Color(0xFF0284C7), const Color(0xFF0369A1)],
          screen: const MyAssetsScreen(),
        ),
        SubModuleItem(
          name: 'Software & Licenses',
          description: 'Manage software licenses and distribution',
          icon: Icons.apps,
          colors: [const Color(0xFF0284C7), const Color(0xFF0369A1)],
          screen: const MyAssetsScreen(),
        ),
        SubModuleItem(
          name: 'Employee Accounts',
          description: 'Manage employee system accounts',
          icon: Icons.people,
          colors: [const Color(0xFF0284C7), const Color(0xFF0369A1)],
          screen: const UserManagementScreen(showAppBar: true),
        ),
        SubModuleItem(
          name: 'Access Management',
          description: 'Manage access controls and permissions',
          icon: Icons.vpn_key,
          colors: [const Color(0xFF0284C7), const Color(0xFF0369A1)],
          screen: const AdminRolesPermissionsScreen(),
        ),
        SubModuleItem(
          name: 'IT Tickets / Support',
          description: 'Manage IT support tickets and requests',
          icon: Icons.support_agent,
          colors: [const Color(0xFF0284C7), const Color(0xFF0369A1)],
          screen: const HelpdeskTicketsScreen(showAppBar: true),
        ),
        SubModuleItem(
          name: 'IT Onboarding',
          description: 'IT provisioning for new hires',
          icon: Icons.person_add,
          colors: [const Color(0xFF0284C7), const Color(0xFF0369A1)],
          screen: const AdminOnboardingScreen(),
        ),
        SubModuleItem(
          name: 'IT Offboarding',
          description: 'IT de-provisioning and asset retrieval',
          icon: Icons.person_remove,
          colors: [const Color(0xFF0284C7), const Color(0xFF0369A1)],
          screen: const AdminOnboardingScreen(),
        ),
        SubModuleItem(
          name: 'Security & Audit',
          description: 'IT security logs and audits',
          icon: Icons.security,
          colors: [const Color(0xFF0284C7), const Color(0xFF0369A1)],
          screen: const AdminAuditLogsScreen(),
        ),
        SubModuleItem(
          name: 'IT Reports',
          description: 'IT operations analytics and reports',
          icon: Icons.bar_chart,
          colors: [const Color(0xFF0284C7), const Color(0xFF0369A1)],
          screen: const AdminReportsScreen(),
        ),
      ],
    ),
    ParentModuleItem(
      title: 'Employee Benefits',
      description: 'Benefits plans and team benefit claims',
      icon: Icons.card_giftcard_rounded,
      colors: [const Color(0xFFEC4899), const Color(0xFFBE185D)],
      submodules: [
        SubModuleItem(
          name: 'Benefits',
          description: 'Manage employee benefit plans and claims',
          icon: Icons.card_giftcard,
          colors: [const Color(0xFFEC4899), const Color(0xFFBE185D)],
          screen: const AdminBenefitsManagementScreen(showAppBar: true),
        ),
        SubModuleItem(
          name: 'Team Benefits',
          description: 'Review team benefit requests and invoices',
          icon: Icons.group,
          colors: [const Color(0xFFEC4899), const Color(0xFFBE185D)],
          screen: const TlBenefitsScreen(showAppBar: true),
        ),
        SubModuleItem(
          name: 'My Benefits',
          description: 'View your personal benefit enrollments and claims',
          icon: Icons.favorite,
          colors: [const Color(0xFFEC4899), const Color(0xFFBE185D)],
          screen: const MyBenefitsScreen(showAppBar: true),
        ),
      ],
    ),
    ParentModuleItem(
      title: 'Expenses Management',
      description: 'Expense claims, team expenses, and approvals',
      icon: Icons.receipt_long_rounded,
      colors: [const Color(0xFF10B981), const Color(0xFF047857)],
      submodules: [
        SubModuleItem(
          name: 'Expenses',
          description: 'Manage company expense claims and policies',
          icon: Icons.receipt,
          colors: [const Color(0xFF10B981), const Color(0xFF047857)],
          screen: const AdminExpensesScreen(),
        ),
        SubModuleItem(
          name: 'Team Expenses',
          description: 'Review and approve team expense claims',
          icon: Icons.group,
          colors: [const Color(0xFF10B981), const Color(0xFF047857)],
          screen: const AdminExpenseInvoicesScreen(),
        ),
        SubModuleItem(
          name: 'My Expenses',
          description: 'Submit and track personal expense claims',
          icon: Icons.account_balance_wallet,
          colors: [const Color(0xFF10B981), const Color(0xFF047857)],
          screen: const MyExpensesScreen(),
        ),
      ],
    ),
    ParentModuleItem(
      title: 'HR Helpdesk',
      description: 'Helpdesk dashboard, tickets, knowledge base, and AI assistant',
      icon: Icons.headset_mic_rounded,
      colors: [const Color(0xFF3B82F6), const Color(0xFF1D4ED8)],
      submodules: [
        SubModuleItem(
          name: 'Helpdesk Dashboard',
          description: 'Overview of HR support tickets and metrics',
          icon: Icons.dashboard,
          colors: [const Color(0xFF3B82F6), const Color(0xFF1D4ED8)],
          screen: const HelpdeskDashboardScreen(showAppBar: true),
        ),
        SubModuleItem(
          name: 'Helpdesk Tickets',
          description: 'Manage and resolve support tickets',
          icon: Icons.confirmation_number,
          colors: [const Color(0xFF3B82F6), const Color(0xFF1D4ED8)],
          screen: const HelpdeskTicketsScreen(showAppBar: true),
        ),
        SubModuleItem(
          name: 'Knowledge Base',
          description: 'FAQs, articles, and HR guides',
          icon: Icons.menu_book,
          colors: [const Color(0xFF3B82F6), const Color(0xFF1D4ED8)],
          screen: const HelpdeskKnowledgeBaseScreen(showAppBar: true),
        ),
        SubModuleItem(
          name: 'AI Assistant',
          description: 'Chat with AI assistant for queries',
          icon: Icons.smart_toy,
          colors: [const Color(0xFF3B82F6), const Color(0xFF1D4ED8)],
          screen: const HelpdeskChatbotScreen(),
        ),
      ],
    ),
    ParentModuleItem(
      title: 'Settings',
      description: 'Personal application and account settings',
      icon: Icons.settings_rounded,
      colors: [const Color(0xFF64748B), const Color(0xFF334155)],
      submodules: [
        SubModuleItem(
          name: 'My Settings',
          description: 'Manage personal app settings and preferences',
          icon: Icons.manage_accounts,
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

    return ListView(
      padding: const EdgeInsets.only(top: 4, bottom: 20),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GlassSearchBar(
            controller: _searchController,
            placeholder: "Search admin modules...",
            onChanged: (val) => setState(() => _searchQuery = val),
            onClear: () => setState(() => _searchQuery = ''),
          ),
        ),
        const SectionLabel("ADMIN MODULES"),
        if (isSearching && filteredParents.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.search_off_rounded, size: 48, color: Colors.grey),
                  const SizedBox(height: 12),
                  const Text('No Admin modules found', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
        showBackButton: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        children: [
          SectionLabel(parent.title.toUpperCase()),
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
