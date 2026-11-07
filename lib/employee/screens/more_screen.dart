import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/auth/auth_service.dart';
import '../../core/theme/glass_theme.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/glass_header.dart';
import '../../core/widgets/glass_search_bar.dart';
import '../../core/widgets/section_label.dart';
import '../../core/widgets/module_card.dart';
import '../../core/widgets/glass_bottom_tab_bar.dart';
import 'announcements_screen.dart';
import 'apply_leave_screen.dart';
import 'break_tracker_screen.dart';
import 'daily_work_update_screen.dart';
import '../../resources/screens/holidays_screen.dart';
import 'it_and_finance_screens.dart';
import 'my_assets_screen.dart';
import 'my_attendance_screen.dart';
import 'my_benefit_invoices_screen.dart';
import 'my_benefits_screen.dart';
import 'my_documents_screen.dart';
import 'my_expense_invoices_screen.dart';
import 'my_expenses_screen.dart';
import 'my_leave_screen.dart';
import 'my_payslips_screen.dart';
import 'my_performance_screen.dart';
import 'my_profile_screen.dart';
import 'my_projects_screen.dart';
import 'my_salary_screen.dart';
import 'my_settings_screen.dart';
import 'my_tasks_screen.dart';
import 'notifications_screen.dart';
import 'punch_in_out_screen.dart';
import 'training_screens.dart';
import 'wfh_apply_screen.dart';
import 'employee_dashboard_screen.dart';

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

class MoreScreen extends ConsumerStatefulWidget {
  final bool showAppBar;
  const MoreScreen({super.key, this.showAppBar = false});

  @override
  ConsumerState<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends ConsumerState<MoreScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  final List<ParentModuleItem> _parentModules = [
    ParentModuleItem(
      title: 'My Space',
      description: 'Break Tracker, Daily Updates, WFH',
      icon: Icons.space_dashboard_rounded,
      colors: [const Color(0xFF3B82F6), const Color(0xFF1D4ED8)],
      submodules: [
        SubModuleItem(
          name: 'Break Tracker',
          description: 'Manage your break time and history',
          icon: Icons.free_breakfast_rounded,
          colors: [const Color(0xFF3B82F6), const Color(0xFF1D4ED8)],
          screen: const BreakTrackerScreen(showAppBar: true),
        ),
        SubModuleItem(
          name: 'Daily Work Update',
          description: 'Daily work updates and reporting',
          icon: Icons.rate_review_rounded,
          colors: [const Color(0xFF3B82F6), const Color(0xFF1D4ED8)],
          screen: const DailyWorkUpdateScreen(showAppBar: true),
        ),
        SubModuleItem(
          name: 'WFH Apply',
          description: 'Work from home requests and status',
          icon: Icons.home_work_rounded,
          colors: [const Color(0xFF3B82F6), const Color(0xFF1D4ED8)],
          screen: const WfhApplyScreen(),
        ),
      ],
    ),
    ParentModuleItem(
      title: 'Time & Attendance',
      description: 'Work from home applications & time tracking',
      icon: Icons.access_time_filled_rounded,
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
          screen: const MySalaryScreen(),
        ),
      ],
    ),
    ParentModuleItem(
      title: 'My Work',
      description: 'Tasks, Performance reviews, and Projects',
      icon: Icons.work_rounded,
      colors: [const Color(0xFFFB923C), const Color(0xFFEA580C)],
      submodules: [
        SubModuleItem(
          name: 'My Tasks',
          description: 'Assigned tasks and pending actions',
          icon: Icons.check_box_rounded,
          colors: [const Color(0xFFFB923C), const Color(0xFFEA580C)],
          screen: const MyTasksScreen(),
        ),
        SubModuleItem(
          name: 'My Performance',
          description: 'View performance reviews and goals',
          icon: Icons.trending_up_rounded,
          colors: [const Color(0xFFFB923C), const Color(0xFFEA580C)],
          screen: const MyPerformanceScreen(),
        ),
        SubModuleItem(
          name: 'My Projects',
          description: 'Project details and progress tracking',
          icon: Icons.folder_special_rounded,
          colors: [const Color(0xFFFB923C), const Color(0xFFEA580C)],
          screen: const MyProjectsScreen(),
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
          screen: const AnnouncementsScreen(),
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
      title: 'My Assets',
      description: 'Assigned hardware and devices',
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
      title: 'Employee Benefits',
      description: 'Benefits plans and claims',
      icon: Icons.card_giftcard_rounded,
      colors: [const Color(0xFFEC4899), const Color(0xFFBE185D)],
      submodules: [
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
      description: 'Expense claims and tracking',
      icon: Icons.receipt_long_rounded,
      colors: [const Color(0xFF6366F1), const Color(0xFF4338CA)],
      submodules: [
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
      title: 'Settings',
      description: 'App preferences and settings',
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
    final results = _searchResults;
    final isSearching = _searchQuery.trim().isNotEmpty;

    // Filter parent modules if searching
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
          placeholder: "Search modules...",
          onChanged: (val) => setState(() => _searchQuery = val),
          onClear: () => setState(() => _searchQuery = ''),
        ),
        const SectionLabel("ALL MODULES"),
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
      title: "More Modules",
      showBottomBar: true,
      body: content,
      tabs: [
        GlassTab(
          icon: Icons.home_rounded,
          label: "Home",
          isSelected: false,
          onTap: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => EmployeeDashboardScreen(onNavigateTab: (_) {})),
            );
          },
        ),
        GlassTab(
          icon: Icons.access_time_rounded,
          label: "Attendance",
          isSelected: false,
          onTap: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const MyAttendanceScreen(showAppBar: true)),
            );
          },
        ),
        GlassTab(
          icon: Icons.calendar_month_rounded,
          label: "My Leave",
          isSelected: false,
          onTap: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const MyLeaveScreen(showAppBar: true)),
            );
          },
        ),
        GlassTab(
          icon: Icons.notifications_rounded,
          label: "Alerts",
          badgeCount: 3,
          isSelected: false,
          onTap: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const NotificationsScreen(showAppBar: true)),
            );
          },
        ),
        GlassTab(
          icon: Icons.grid_view_rounded,
          label: "More",
          isSelected: true,
          onTap: () {},
        ),
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
        userInitial: "E",
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
