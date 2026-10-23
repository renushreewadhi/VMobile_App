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
import 'break_tracker_screen.dart';
import 'daily_work_update_screen.dart';
import '../../helpdesk/screens/helpdesk_dashboard_screen.dart';
import '../../helpdesk/screens/helpdesk_tickets_screen.dart';
import '../../helpdesk/screens/helpdesk_knowledge_base_screen.dart';
import '../../helpdesk/screens/helpdesk_chatbot_screen.dart';
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
      title: 'Attendance & Time',
      description: 'Attendance, Check In/Out, Timesheet',
      icon: Icons.calendar_today_rounded,
      colors: [const Color(0xFF34D399), const Color(0xFF059669)],
      submodules: [
        SubModuleItem(
          name: 'Attendance',
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
      title: 'My Work',
      description: 'Tasks, Projects, Updates, Reports',
      icon: Icons.work_outline_rounded,
      colors: [const Color(0xFFFB923C), const Color(0xFFEA580C)],
      submodules: [
        SubModuleItem(
          name: 'My Tasks',
          description: 'Tasks, Projects, Updates, Reports',
          icon: Icons.work_outline_rounded,
          colors: [const Color(0xFFFB923C), const Color(0xFFEA580C)],
          screen: const MyTasksScreen(),
        ),
        SubModuleItem(
          name: 'Work Update',
          description: 'Daily work updates and reporting',
          icon: Icons.rate_review_rounded,
          colors: [const Color(0xFFFB923C), const Color(0xFFEA580C)],
          screen: const DailyWorkUpdateScreen(showAppBar: true),
        ),
        SubModuleItem(
          name: 'My Projects',
          description: 'Project details and progress tracking',
          icon: Icons.folder_special_rounded,
          colors: [const Color(0xFFFB923C), const Color(0xFFEA580C)],
          screen: const MyProjectsScreen(),
        ),
        SubModuleItem(
          name: 'Performance',
          description: 'View your performance reviews and goals',
          icon: Icons.trending_up_rounded,
          colors: [const Color(0xFFFB923C), const Color(0xFFEA580C)],
          screen: const MyPerformanceScreen(),
        ),
      ],
    ),
    ParentModuleItem(
      title: 'Leave & Benefits',
      description: 'Leave, Benefits, Invoices',
      icon: Icons.card_giftcard_rounded,
      colors: [const Color(0xFFF472B6), const Color(0xFFDB2777)],
      submodules: [
        SubModuleItem(
          name: 'My Leave',
          description: 'Leave, Benefits, Invoices',
          icon: Icons.card_giftcard_rounded,
          colors: [const Color(0xFFF472B6), const Color(0xFFDB2777)],
          screen: const MyLeaveScreen(showAppBar: true),
        ),
        SubModuleItem(
          name: 'My Benefits',
          description: 'View your benefit plans and claims',
          icon: Icons.favorite_rounded,
          colors: [const Color(0xFFF472B6), const Color(0xFFDB2777)],
          screen: const MyBenefitsScreen(showAppBar: true),
        ),
        SubModuleItem(
          name: 'Benefit Invoices',
          description: 'View benefit invoices and receipts',
          icon: Icons.receipt_rounded,
          colors: [const Color(0xFFF472B6), const Color(0xFFDB2777)],
          screen: const MyBenefitInvoicesScreen(showAppBar: true),
        ),
      ],
    ),
    ParentModuleItem(
      title: 'Finance',
      description: 'Payslips, Salary, Expenses',
      icon: Icons.account_balance_wallet_outlined,
      colors: [const Color(0xFF818CF8), const Color(0xFF4F46E5)],
      submodules: [
        SubModuleItem(
          name: 'My Payslips',
          description: 'Payslips, Salary, Expenses',
          icon: Icons.account_balance_wallet_outlined,
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
        SubModuleItem(
          name: 'My Expenses',
          description: 'Expense claims and tracking',
          icon: Icons.receipt_long_rounded,
          colors: [const Color(0xFF818CF8), const Color(0xFF4F46E5)],
          screen: const MyExpensesScreen(),
        ),
        SubModuleItem(
          name: 'Expense Invoices',
          description: 'Submitted expense invoice documents',
          icon: Icons.insert_drive_file_rounded,
          colors: [const Color(0xFF818CF8), const Color(0xFF4F46E5)],
          screen: const MyExpenseInvoicesScreen(),
        ),
      ],
    ),
    ParentModuleItem(
      title: 'Support & IT',
      description: 'Helpdesk, Tickets, Assets',
      icon: Icons.headset_mic_outlined,
      colors: [const Color(0xFF38BDF8), const Color(0xFF0284C7)],
      submodules: [
        SubModuleItem(
          name: 'Helpdesk',
          description: 'Helpdesk, Tickets, Assets',
          icon: Icons.headset_mic_outlined,
          colors: [const Color(0xFF38BDF8), const Color(0xFF0284C7)],
          screen: const HelpdeskDashboardScreen(showAppBar: true),
        ),
        SubModuleItem(
          name: 'Support Tickets',
          description: 'Track and raise support tickets',
          icon: Icons.confirmation_number_rounded,
          colors: [const Color(0xFF38BDF8), const Color(0xFF0284C7)],
          screen: const HelpdeskTicketsScreen(showAppBar: true),
        ),
        SubModuleItem(
          name: 'Knowledge Base',
          description: 'FAQs, articles, and guides',
          icon: Icons.menu_book_rounded,
          colors: [const Color(0xFF38BDF8), const Color(0xFF0284C7)],
          screen: const HelpdeskKnowledgeBaseScreen(showAppBar: true),
        ),
        SubModuleItem(
          name: 'AI Assistant',
          description: 'Chat with AI assistant for queries',
          icon: Icons.smart_toy_rounded,
          colors: [const Color(0xFF38BDF8), const Color(0xFF0284C7)],
          screen: const HelpdeskChatbotScreen(),
        ),
        SubModuleItem(
          name: 'My Assets',
          description: 'Assigned company hardware and assets',
          icon: Icons.laptop_mac_rounded,
          colors: [const Color(0xFF38BDF8), const Color(0xFF0284C7)],
          screen: const MyAssetsScreen(),
        ),
        SubModuleItem(
          name: 'Asset Requests',
          description: 'Request new hardware or equipment',
          icon: Icons.assignment_turned_in_rounded,
          colors: [const Color(0xFF38BDF8), const Color(0xFF0284C7)],
          screen: const AssetRequestsScreen(),
        ),
        SubModuleItem(
          name: 'IT Tickets',
          description: 'IT support requests and tracking',
          icon: Icons.support_agent_rounded,
          colors: [const Color(0xFF38BDF8), const Color(0xFF0284C7)],
          screen: const ItSupportTicketsScreen(),
        ),
      ],
    ),
    ParentModuleItem(
      title: 'Company & Learning',
      description: 'Policies, Courses, Directory',
      icon: Icons.menu_book_rounded,
      colors: [const Color(0xFF2DD4BF), const Color(0xFF0D9488)],
      submodules: [
        SubModuleItem(
          name: 'Holidays',
          description: 'Policies, Courses, Directory',
          icon: Icons.menu_book_rounded,
          colors: [const Color(0xFF2DD4BF), const Color(0xFF0D9488)],
          screen: const HolidaysScreen(),
        ),
        SubModuleItem(
          name: 'Announcements',
          description: 'Company news and announcements',
          icon: Icons.campaign_rounded,
          colors: [const Color(0xFF2DD4BF), const Color(0xFF0D9488)],
          screen: const AnnouncementsScreen(),
        ),
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
        SubModuleItem(
          name: 'Training Hub',
          description: 'Courses, training, and learning',
          icon: Icons.school_rounded,
          colors: [const Color(0xFF2DD4BF), const Color(0xFF0D9488)],
          screen: const TrainingDashboardScreen(),
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

    return GlassScaffold(
      showBottomBar: widget.showAppBar,
      appBar: widget.showAppBar
          ? GlassHeader(
              title: "More Modules",
              userInitial: "E",
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: context.glass.headerIconTileFill,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Icon(
                    Icons.apartment_rounded,
                    size: 22,
                    color: context.glass.headerIconColor,
                  ),
                ),
              ),
            )
          : null,
      body: ListView(
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
      ),
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
