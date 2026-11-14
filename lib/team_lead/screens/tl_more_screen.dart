import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/glass_theme.dart';
import '../../core/widgets/glass_header.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/glass_search_bar.dart';
import '../../core/widgets/module_card.dart';
import '../../core/widgets/section_label.dart';
import '../../employee/screens/announcements_screen.dart';
import '../../employee/screens/apply_leave_screen.dart';
import '../../employee/screens/break_tracker_screen.dart';
import '../../employee/screens/daily_work_update_screen.dart';
import '../../employee/screens/holidays_screen.dart';
import '../../employee/screens/my_assets_screen.dart';
import '../../employee/screens/my_attendance_screen.dart';
import '../../employee/screens/my_benefits_screen.dart';
import '../../employee/screens/my_documents_screen.dart';
import '../../employee/screens/my_expenses_screen.dart';
import '../../employee/screens/my_leave_screen.dart';
import '../../employee/screens/my_payslips_screen.dart';
import '../../employee/screens/my_profile_screen.dart';
import '../../employee/screens/my_projects_screen.dart';
import '../../employee/screens/my_salary_screen.dart';
import '../../employee/screens/my_settings_screen.dart';
import '../../employee/screens/notifications_screen.dart';
import '../../employee/screens/punch_in_out_screen.dart';
import '../../employee/screens/training_screens.dart';
import '../../employee/screens/wfh_apply_screen.dart';
import '../../helpdesk/screens/helpdesk_chatbot_screen.dart';
import '../../helpdesk/screens/helpdesk_dashboard_screen.dart';
import '../../helpdesk/screens/helpdesk_knowledge_base_screen.dart';
import '../../helpdesk/screens/helpdesk_tickets_screen.dart';
import '../../it/screens/it_asset_requests_screen.dart';
import '../../it/screens/it_offboarding_screen.dart';
import '../../it/screens/it_onboarding_screen.dart';
import '../../it/screens/it_tickets_screen.dart';
import 'tl_add_task_screen.dart';
import 'tl_announcements_screen.dart';
import 'tl_assign_goal_screen.dart';
import 'tl_assign_training_screen.dart';
import 'tl_attendance_screen.dart';
import 'tl_benefits_screen.dart';
import 'tl_eod_updates_screen.dart';
import 'tl_expenses_screen.dart';
import 'tl_kpi_screen.dart';
import 'tl_meetings_screen.dart';
import 'tl_performance_screen.dart';
import 'tl_projects_screen.dart';
import 'tl_reports_screen.dart';
import 'tl_tasks_screen.dart';
import 'tl_team_assets_screen.dart';
import 'tl_team_payroll_screen.dart';
import 'tl_team_training_screen.dart';

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

class TlMoreScreen extends ConsumerStatefulWidget {
  final bool showAppBar;
  const TlMoreScreen({super.key, this.showAppBar = false});

  @override
  ConsumerState<TlMoreScreen> createState() => _TlMoreScreenState();
}

class _TlMoreScreenState extends ConsumerState<TlMoreScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  final List<ParentModuleItem> _parentModules = [
    ParentModuleItem(
      title: 'Time & Attendance',
      description: 'Attendance, Check In/Out, Break Tracker, WFH Apply',
      icon: Icons.calendar_today_rounded,
      colors: [const Color(0xFF34D399), const Color(0xFF059669)],
      submodules: [
        SubModuleItem(
          name: 'My Attendance',
          description: 'Attendance records and logs',
          icon: Icons.calendar_today_rounded,
          colors: [const Color(0xFF34D399), const Color(0xFF059669)],
          screen: const MyAttendanceScreen(showAppBar: true),
        ),
        SubModuleItem(
          name: 'Check In/Out',
          description: 'Check in, check out, live status tracking',
          icon: Icons.touch_app_rounded,
          colors: [const Color(0xFF34D399), const Color(0xFF059669)],
          screen: const PunchInOutScreen(),
        ),
        SubModuleItem(
          name: 'Break Tracker',
          description: 'Manage your break time and history',
          icon: Icons.free_breakfast_rounded,
          colors: [const Color(0xFF34D399), const Color(0xFF059669)],
          screen: const BreakTrackerScreen(showAppBar: true),
        ),
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
      title: 'My Leave',
      description: 'Leave balances and leave applications',
      icon: Icons.event_note_rounded,
      colors: [const Color(0xFFF472B6), const Color(0xFFDB2777)],
      submodules: [
        SubModuleItem(
          name: 'My Leave',
          description: 'View leave summary and history',
          icon: Icons.calendar_month_rounded,
          colors: [const Color(0xFFF472B6), const Color(0xFFDB2777)],
          screen: const MyLeaveScreen(showAppBar: true),
        ),
        SubModuleItem(
          name: 'Apply Leave',
          description: 'Apply for annual, sick, or casual leave',
          icon: Icons.add_circle_outline_rounded,
          colors: [const Color(0xFFF472B6), const Color(0xFFDB2777)],
          screen: const ApplyLeaveScreen(),
        ),
      ],
    ),
    ParentModuleItem(
      title: 'My Payroll',
      description: 'Payslips and salary information',
      icon: Icons.account_balance_wallet_rounded,
      colors: [const Color(0xFF818CF8), const Color(0xFF4F46E5)],
      submodules: [
        SubModuleItem(
          name: 'My Payslips',
          description: 'Download and view salary payslips',
          icon: Icons.receipt_rounded,
          colors: [const Color(0xFF818CF8), const Color(0xFF4F46E5)],
          screen: const MyPayslipsScreen(showAppBar: true),
        ),
        SubModuleItem(
          name: 'My Salary',
          description: 'Salary structure and breakdown',
          icon: Icons.account_balance_wallet_rounded,
          colors: [const Color(0xFF818CF8), const Color(0xFF4F46E5)],
          screen: const MySalaryScreen(showAppBar: true),
        ),
      ],
    ),
    ParentModuleItem(
      title: 'My Work',
      description: 'Daily work updates and reporting',
      icon: Icons.work_rounded,
      colors: [const Color(0xFFFB923C), const Color(0xFFEA580C)],
      submodules: [
        SubModuleItem(
          name: 'Daily Work Update',
          description: 'Daily work updates and reporting',
          icon: Icons.rate_review_rounded,
          colors: [const Color(0xFFFB923C), const Color(0xFFEA580C)],
          screen: const DailyWorkUpdateScreen(showAppBar: true),
        ),
      ],
    ),
    ParentModuleItem(
      title: 'My Profile',
      description: 'View and update personal profile details',
      icon: Icons.person_rounded,
      colors: [const Color(0xFF3B82F6), const Color(0xFF1D4ED8)],
      submodules: [
        SubModuleItem(
          name: 'My Profile',
          description: 'View and update your profile details',
          icon: Icons.person_rounded,
          colors: [const Color(0xFF3B82F6), const Color(0xFF1D4ED8)],
          screen: const MyProfileScreen(),
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
          screen: const MyDocumentsScreen(),
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
      title: 'My & Team Assets',
      description: 'Assigned hardware, devices and team asset oversight',
      icon: Icons.laptop_mac_rounded,
      colors: [const Color(0xFF38BDF8), const Color(0xFF0284C7)],
      submodules: [
        SubModuleItem(
          name: 'My Assets',
          description: 'Assigned company hardware and assets',
          icon: Icons.laptop_mac_rounded,
          colors: [const Color(0xFF38BDF8), const Color(0xFF0284C7)],
          screen: const MyAssetsScreen(),
        ),
        SubModuleItem(
          name: 'Team Assets',
          description: 'Team hardware & software asset oversight',
          icon: Icons.devices_rounded,
          colors: [const Color(0xFF6366F1), const Color(0xFF4F46E5)],
          screen: const TLTeamAssetsScreen(showAppBar: true),
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
          description: 'Company holidays calendar',
          icon: Icons.calendar_today_rounded,
          colors: [const Color(0xFF14B8A6), const Color(0xFF0F766E)],
          screen: const HolidaysScreen(),
        ),
        SubModuleItem(
          name: 'Announcements',
          description: 'Company news and announcements',
          icon: Icons.campaign_rounded,
          colors: [const Color(0xFF14B8A6), const Color(0xFF0F766E)],
          screen: const TlAnnouncementsScreen(),
        ),
      ],
    ),
    ParentModuleItem(
      title: 'Projects',
      description: 'Project details and EOD updates',
      icon: Icons.folder_rounded,
      colors: [const Color(0xFF0D9488), const Color(0xFF115E59)],
      submodules: [
        SubModuleItem(
          name: 'Projects',
          description: 'Project details and progress tracking',
          icon: Icons.folder_special_rounded,
          colors: [const Color(0xFF0D9488), const Color(0xFF115E59)],
          screen: const MyProjectsScreen(),
        ),
        SubModuleItem(
          name: 'EOD Updates',
          description: 'Daily end of day status updates',
          icon: Icons.assignment_rounded,
          colors: [const Color(0xFF0D9488), const Color(0xFF115E59)],
          screen: const DailyWorkUpdateScreen(showAppBar: true),
        ),
      ],
    ),
    ParentModuleItem(
      title: 'Training',
      description: 'Courses, progress, certifications and history',
      icon: Icons.school_rounded,
      colors: [const Color(0xFFA855F7), const Color(0xFF7E22CE)],
      submodules: [
        SubModuleItem(
          name: 'Dashboard',
          description: 'Training dashboard and overview',
          icon: Icons.dashboard_rounded,
          colors: [const Color(0xFFA855F7), const Color(0xFF7E22CE)],
          screen: const TrainingDashboardScreen(),
        ),
        SubModuleItem(
          name: 'Assign Training',
          description: 'Assign training programs to team members',
          icon: Icons.group_add_rounded,
          colors: [const Color(0xFFA855F7), const Color(0xFF7E22CE)],
          screen: const TlAssignTrainingScreen(),
        ),
        SubModuleItem(
          name: 'Employee Progress',
          description: 'Track team members course completion',
          icon: Icons.trending_up_rounded,
          colors: [const Color(0xFFA855F7), const Color(0xFF7E22CE)],
          screen: const TlTeamTrainingScreen(),
        ),
        SubModuleItem(
          name: 'Training Reports',
          description: 'Training analytics and participation reports',
          icon: Icons.bar_chart_rounded,
          colors: [const Color(0xFFA855F7), const Color(0xFF7E22CE)],
          screen: const TrainingDashboardScreen(),
        ),
        SubModuleItem(
          name: 'My Courses',
          description: 'Enrolled and available training courses',
          icon: Icons.menu_book_rounded,
          colors: [const Color(0xFFA855F7), const Color(0xFF7E22CE)],
          screen: const MyCoursesScreen(),
        ),
        SubModuleItem(
          name: 'In Progress',
          description: 'Training courses currently in progress',
          icon: Icons.hourglass_top_rounded,
          colors: [const Color(0xFFA855F7), const Color(0xFF7E22CE)],
          screen: const TrainingInProgressScreen(),
        ),
        SubModuleItem(
          name: 'Completed',
          description: 'Completed training courses and certifications',
          icon: Icons.task_alt_rounded,
          colors: [const Color(0xFFA855F7), const Color(0xFF7E22CE)],
          screen: const TrainingCompletedScreen(),
        ),
        SubModuleItem(
          name: 'My Certificates',
          description: 'Verified certificates and credentials',
          icon: Icons.workspace_premium_rounded,
          colors: [const Color(0xFFA855F7), const Color(0xFF7E22CE)],
          screen: const MyCertificatesScreen(),
        ),
        SubModuleItem(
          name: 'Training History',
          description: 'History of completed training programs',
          icon: Icons.history_rounded,
          colors: [const Color(0xFFA855F7), const Color(0xFF7E22CE)],
          screen: const TrainingHistoryScreen(),
        ),
      ],
    ),
    ParentModuleItem(
      title: 'IT Operations',
      description: 'Asset requests and IT support tickets',
      icon: Icons.devices_other_rounded,
      colors: [const Color(0xFF06B6D4), const Color(0xFF0891B2)],
      submodules: [
        SubModuleItem(
          name: 'Asset Requests',
          description: 'Request new hardware or equipment',
          icon: Icons.assignment_turned_in_rounded,
          colors: [const Color(0xFF06B6D4), const Color(0xFF0891B2)],
          screen: const ItAssetRequestsScreen(),
        ),
        SubModuleItem(
          name: 'IT Tickets / Support',
          description: 'IT support requests and tracking',
          icon: Icons.support_agent_rounded,
          colors: [const Color(0xFF06B6D4), const Color(0xFF0891B2)],
          screen: const ItTicketsScreen(),
        ),
        SubModuleItem(
          name: 'IT Onboarding',
          description: 'IT provisioning for new hires',
          icon: Icons.person_add_rounded,
          colors: [const Color(0xFF06B6D4), const Color(0xFF0891B2)],
          screen: const ItOnboardingScreen(),
        ),
        SubModuleItem(
          name: 'IT Offboarding',
          description: 'IT de-provisioning and asset collection',
          icon: Icons.person_remove_rounded,
          colors: [const Color(0xFF06B6D4), const Color(0xFF0891B2)],
          screen: const ItOffboardingScreen(),
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
          name: 'Team Benefits',
          description: 'Review team benefit requests and invoices',
          icon: Icons.group_rounded,
          colors: [const Color(0xFFEC4899), const Color(0xFFBE185D)],
          screen: const TlBenefitsScreen(),
        ),
        SubModuleItem(
          name: 'My Benefits',
          description: 'View your benefit plans and claims',
          icon: Icons.favorite_rounded,
          colors: [const Color(0xFFEC4899), const Color(0xFFBE185D)],
          screen: const MyBenefitsScreen(showAppBar: true),
        ),
      ],
    ),
    ParentModuleItem(
      title: 'Expenses Management',
      description: 'Expense claims and team tracking',
      icon: Icons.receipt_long_rounded,
      colors: [const Color(0xFF6366F1), const Color(0xFF4338CA)],
      submodules: [
        SubModuleItem(
          name: 'Team Expenses',
          description: 'Team members expense claims review',
          icon: Icons.group_rounded,
          colors: [const Color(0xFF6366F1), const Color(0xFF4338CA)],
          screen: const TlExpensesScreen(),
        ),
        SubModuleItem(
          name: 'My Expenses',
          description: 'Personal expense claims and tracking',
          icon: Icons.receipt_rounded,
          colors: [const Color(0xFF6366F1), const Color(0xFF4338CA)],
          screen: const MyExpensesScreen(),
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
          description: 'Overview of support tickets and metrics',
          icon: Icons.dashboard_rounded,
          colors: [const Color(0xFF0EA5E9), const Color(0xFF0369A1)],
          screen: const HelpdeskDashboardScreen(showAppBar: true),
        ),
        SubModuleItem(
          name: 'Helpdesk Tickets',
          description: 'Track and manage support tickets',
          icon: Icons.confirmation_number_rounded,
          colors: [const Color(0xFF0EA5E9), const Color(0xFF0369A1)],
          screen: const HelpdeskTicketsScreen(showAppBar: true),
        ),
        SubModuleItem(
          name: 'Knowledge Base',
          description: 'FAQs, articles, and guides',
          icon: Icons.auto_stories_rounded,
          colors: [const Color(0xFF0EA5E9), const Color(0xFF0369A1)],
          screen: const HelpdeskKnowledgeBaseScreen(showAppBar: true),
        ),
        SubModuleItem(
          name: 'AI Assistant',
          description: 'Chat with AI assistant for instant answers',
          icon: Icons.smart_toy_rounded,
          colors: [const Color(0xFF0EA5E9), const Color(0xFF0369A1)],
          screen: const HelpdeskChatbotScreen(),
        ),
      ],
    ),
    ParentModuleItem(
      title: 'Settings',
      description: 'App preferences and account settings',
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
    ParentModuleItem(
      title: 'Team Lead Management & Tools',
      description: 'Team tasks, projects, performance, analytics and inputs',
      icon: Icons.supervisor_account_rounded,
      colors: [const Color(0xFF7C3AED), const Color(0xFF5B21B6)],
      submodules: [
        SubModuleItem(
          name: 'Team Tasks & Deliverables',
          description: 'Manage and review team tasks and deliverables',
          icon: Icons.task_rounded,
          colors: [const Color(0xFF7C3AED), const Color(0xFF5B21B6)],
          screen: const TlTasksScreen(),
        ),
        SubModuleItem(
          name: 'Team Projects',
          description: 'Team projects assignment and progress tracking',
          icon: Icons.folder_rounded,
          colors: [const Color(0xFF7C3AED), const Color(0xFF5B21B6)],
          screen: const TlProjectsScreen(),
        ),
        SubModuleItem(
          name: 'Team Attendance & Approvals',
          description: 'Review and approve team attendance logs',
          icon: Icons.access_time_rounded,
          colors: [const Color(0xFF7C3AED), const Color(0xFF5B21B6)],
          screen: const TlAttendanceScreen(),
        ),
        SubModuleItem(
          name: 'Team Performance & Goals',
          description: 'Team performance reviews and goal setting',
          icon: Icons.trending_up_rounded,
          colors: [const Color(0xFF7C3AED), const Color(0xFF5B21B6)],
          screen: const TlPerformanceScreen(),
        ),
        SubModuleItem(
          name: 'Team Analytics & Reports',
          description: 'Team operational and performance reports',
          icon: Icons.bar_chart_rounded,
          colors: [const Color(0xFF7C3AED), const Color(0xFF5B21B6)],
          screen: const TlReportsScreen(),
        ),
        SubModuleItem(
          name: 'Team Expense Claims',
          description: 'Review and verify team expense claims',
          icon: Icons.receipt_long_rounded,
          colors: [const Color(0xFF7C3AED), const Color(0xFF5B21B6)],
          screen: const TlExpensesScreen(),
        ),
        SubModuleItem(
          name: 'Company Announcements',
          description: 'Publish and view announcements',
          icon: Icons.campaign_rounded,
          colors: [const Color(0xFF7C3AED), const Color(0xFF5B21B6)],
          screen: const TlAnnouncementsScreen(),
        ),
        SubModuleItem(
          name: 'Team Meetings',
          description: 'Schedule and manage team meetings',
          icon: Icons.meeting_room_rounded,
          colors: [const Color(0xFF7C3AED), const Color(0xFF5B21B6)],
          screen: const TlMeetingsScreen(),
        ),
        SubModuleItem(
          name: 'Team KPI Tracking',
          description: 'Track key performance indicators for the team',
          icon: Icons.show_chart_rounded,
          colors: [const Color(0xFF7C3AED), const Color(0xFF5B21B6)],
          screen: const TlKpiScreen(),
        ),
        SubModuleItem(
          name: 'Team Payroll Inputs',
          description: 'Manage variable pay and payroll inputs for team',
          icon: Icons.payments_rounded,
          colors: [const Color(0xFF7C3AED), const Color(0xFF5B21B6)],
          screen: const TlTeamPayrollScreen(),
        ),
        SubModuleItem(
          name: 'Assign Goal to Team',
          description: 'Assign performance goals to team members',
          icon: Icons.flag_rounded,
          colors: [const Color(0xFF7C3AED), const Color(0xFF5B21B6)],
          screen: const TlAssignGoalScreen(),
        ),
        SubModuleItem(
          name: 'Assign New Task',
          description: 'Create and assign new tasks to team members',
          icon: Icons.add_task_rounded,
          colors: [const Color(0xFF7C3AED), const Color(0xFF5B21B6)],
          screen: const TlAddTaskScreen(),
        ),
        SubModuleItem(
          name: 'Assign Training to Team',
          description: 'Assign courses and training modules to team',
          icon: Icons.school_rounded,
          colors: [const Color(0xFF7C3AED), const Color(0xFF5B21B6)],
          screen: const TlAssignTrainingScreen(),
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
          placeholder: "Search team lead modules...",
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
                  const Text('No modules found', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
      title: "Team Lead Modules",
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
        userInitial: "TL",
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
