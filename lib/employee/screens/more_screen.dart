import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/auth/auth_service.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_card.dart';
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

  final List<ParentModuleItem> _parentModules = [
    ParentModuleItem(
      title: 'Attendance & Time',
      description: 'Attendance, Check In/Out, Break Tracker, WFH Apply',
      icon: Icons.calendar_month_rounded,
      colors: [const Color(0xFF10B981), const Color(0xFF059669)],
      submodules: [
        SubModuleItem(
          name: 'Attendance',
          description: 'View and manage attendance records and logs.',
          icon: Icons.calendar_month_rounded,
          colors: [const Color(0xFF10B981), const Color(0xFF059669)],
          screen: const MyAttendanceScreen(showAppBar: true),
        ),
        SubModuleItem(
          name: 'Check In/Out',
          description: 'Check in, check out, live status tracking.',
          icon: Icons.touch_app_rounded,
          colors: [const Color(0xFF2563EB), const Color(0xFF1D4ED8)],
          screen: const PunchInOutScreen(),
        ),
        SubModuleItem(
          name: 'Break Tracker',
          description: 'Manage your break time and history.',
          icon: Icons.free_breakfast_rounded,
          colors: [const Color(0xFFF59E0B), const Color(0xFFD97706)],
          screen: const BreakTrackerScreen(showAppBar: true),
        ),
        SubModuleItem(
          name: 'WFH Apply',
          description: 'Work from home requests and status.',
          icon: Icons.home_work_rounded,
          colors: [const Color(0xFF8B5CF6), const Color(0xFF6D28D9)],
          screen: const WfhApplyScreen(),
        ),
      ],
    ),
    ParentModuleItem(
      title: 'My Work',
      description: 'Tasks, Projects, Updates, Performance',
      icon: Icons.work_rounded,
      colors: [const Color(0xFFF97316), const Color(0xFFEA580C)],
      submodules: [
        SubModuleItem(
          name: 'My Tasks',
          description: 'View and manage your tasks and to-dos.',
          icon: Icons.task_alt_rounded,
          colors: [const Color(0xFFF97316), const Color(0xFFEA580C)],
          screen: const MyTasksScreen(),
        ),
        SubModuleItem(
          name: 'Work Update',
          description: 'Daily work updates and reporting.',
          icon: Icons.rate_review_rounded,
          colors: [const Color(0xFF14B8A6), const Color(0xFF0D9488)],
          screen: const DailyWorkUpdateScreen(showAppBar: true),
        ),
        SubModuleItem(
          name: 'My Projects',
          description: 'Project details and progress tracking.',
          icon: Icons.folder_special_rounded,
          colors: [const Color(0xFF06B6D4), const Color(0xFF0891B2)],
          screen: const MyProjectsScreen(),
        ),
        SubModuleItem(
          name: 'Performance',
          description: 'View your performance reviews and goals.',
          icon: Icons.trending_up_rounded,
          colors: [const Color(0xFFEF4444), const Color(0xFFDC2626)],
          screen: const MyPerformanceScreen(),
        ),
      ],
    ),
    ParentModuleItem(
      title: 'Leave & Benefits',
      description: 'Leave, Benefits, Invoices...',
      icon: Icons.card_giftcard_rounded,
      colors: [const Color(0xFFEC4899), const Color(0xFFBE185D)],
      submodules: [
        SubModuleItem(
          name: 'My Leave',
          description: 'Leave requests and history.',
          icon: Icons.time_to_leave_rounded,
          colors: [const Color(0xFFEC4899), const Color(0xFFBE185D)],
          screen: const MyLeaveScreen(showAppBar: true),
        ),
        SubModuleItem(
          name: 'My Benefits',
          description: 'View your benefit plans and claims.',
          icon: Icons.favorite_rounded,
          colors: [const Color(0xFFF43F5E), const Color(0xFFE11D48)],
          screen: const MyBenefitsScreen(showAppBar: true),
        ),
        SubModuleItem(
          name: 'Benefit Invoices',
          description: 'View benefit invoices and receipts.',
          icon: Icons.receipt_rounded,
          colors: [const Color(0xFFFB7185), const Color(0xFFE11D48)],
          screen: const MyBenefitInvoicesScreen(showAppBar: true),
        ),
      ],
    ),
    ParentModuleItem(
      title: 'Finance',
      description: 'Payslips, Salary, Expenses...',
      icon: Icons.payments_rounded,
      colors: [const Color(0xFF6366F1), const Color(0xFF4338CA)],
      submodules: [
        SubModuleItem(
          name: 'My Payslips',
          description: 'View and download salary payslips.',
          icon: Icons.payments_rounded,
          colors: [const Color(0xFF6366F1), const Color(0xFF4338CA)],
          screen: const MyPayslipsScreen(showAppBar: true),
        ),
        SubModuleItem(
          name: 'My Salary',
          description: 'Salary structure and breakdown.',
          icon: Icons.account_balance_wallet_rounded,
          colors: [const Color(0xFF10B981), const Color(0xFF047857)],
          screen: const MySalaryScreen(),
        ),
        SubModuleItem(
          name: 'My Expenses',
          description: 'Expense claims and tracking.',
          icon: Icons.receipt_long_rounded,
          colors: [const Color(0xFF0284C7), const Color(0xFF0369A1)],
          screen: const MyExpensesScreen(),
        ),
        SubModuleItem(
          name: 'Expense Invoices',
          description: 'Submitted expense invoice documents.',
          icon: Icons.insert_drive_file_rounded,
          colors: [const Color(0xFF38BDF8), const Color(0xFF0284C7)],
          screen: const MyExpenseInvoicesScreen(),
        ),
      ],
    ),
    ParentModuleItem(
      title: 'Support & IT',
      description: 'Helpdesk, Tickets, Assets...',
      icon: Icons.headset_mic_rounded,
      colors: [const Color(0xFF0284C7), const Color(0xFF0369A1)],
      submodules: [
        SubModuleItem(
          name: 'Helpdesk',
          description: 'Helpdesk dashboard and support.',
          icon: Icons.headset_mic_rounded,
          colors: [const Color(0xFFEC4899), const Color(0xFFDB2777)],
          screen: const HelpdeskDashboardScreen(showAppBar: true),
        ),
        SubModuleItem(
          name: 'Support Tickets',
          description: 'Track and raise support tickets.',
          icon: Icons.confirmation_number_rounded,
          colors: [const Color(0xFFA855F7), const Color(0xFF9333EA)],
          screen: const HelpdeskTicketsScreen(showAppBar: true),
        ),
        SubModuleItem(
          name: 'Knowledge Base',
          description: 'FAQs, articles, and guides.',
          icon: Icons.menu_book_rounded,
          colors: [const Color(0xFFF59E0B), const Color(0xFFB45309)],
          screen: const HelpdeskKnowledgeBaseScreen(showAppBar: true),
        ),
        SubModuleItem(
          name: 'AI Assistant',
          description: 'Chat with AI assistant for queries.',
          icon: Icons.smart_toy_rounded,
          colors: [const Color(0xFF3B82F6), const Color(0xFF1D4ED8)],
          screen: const HelpdeskChatbotScreen(),
        ),
        SubModuleItem(
          name: 'My Assets',
          description: 'Assigned company hardware and assets.',
          icon: Icons.laptop_mac_rounded,
          colors: [const Color(0xFF475569), const Color(0xFF1E293B)],
          screen: const MyAssetsScreen(),
        ),
        SubModuleItem(
          name: 'Asset Requests',
          description: 'Request new hardware or equipment.',
          icon: Icons.assignment_turned_in_rounded,
          colors: [const Color(0xFF64748B), const Color(0xFF334155)],
          screen: const AssetRequestsScreen(),
        ),
        SubModuleItem(
          name: 'IT Tickets',
          description: 'IT support requests and tracking.',
          icon: Icons.support_agent_rounded,
          colors: [const Color(0xFF0284C7), const Color(0xFF0369A1)],
          screen: const ItSupportTicketsScreen(),
        ),
      ],
    ),
    ParentModuleItem(
      title: 'Company & Learning',
      description: 'Holidays, Documents, Announcements...',
      icon: Icons.business_rounded,
      colors: [const Color(0xFF14B8A6), const Color(0xFF0D9488)],
      submodules: [
        SubModuleItem(
          name: 'Holidays',
          description: 'Company holiday calendar.',
          icon: Icons.celebration_rounded,
          colors: [const Color(0xFF38BDF8), const Color(0xFF0284C7)],
          screen: const HolidaysScreen(),
        ),
        SubModuleItem(
          name: 'Announcements',
          description: 'Company news and announcements.',
          icon: Icons.campaign_rounded,
          colors: [const Color(0xFF8B5CF6), const Color(0xFF7C3AED)],
          screen: const AnnouncementsScreen(),
        ),
        SubModuleItem(
          name: 'My Documents',
          description: 'Company policies and personal documents.',
          icon: Icons.description_rounded,
          colors: [const Color(0xFFFB923C), const Color(0xFFC2410C)],
          screen: const MyDocumentsScreen(),
        ),
        SubModuleItem(
          name: 'Notifications',
          description: 'System alerts and notifications.',
          icon: Icons.notifications_active_rounded,
          colors: [const Color(0xFFFACC15), const Color(0xFFCA8A04)],
          screen: const NotificationsScreen(showAppBar: true),
        ),
        SubModuleItem(
          name: 'Training Hub',
          description: 'Courses, training, and learning.',
          icon: Icons.school_rounded,
          colors: [const Color(0xFF10B981), const Color(0xFF059669)],
          screen: const TrainingDashboardScreen(),
        ),
      ],
    ),
    ParentModuleItem(
      title: 'Settings & Profile',
      description: 'Profile, Settings, Preferences',
      icon: Icons.settings_rounded,
      colors: [const Color(0xFF64748B), const Color(0xFF334155)],
      submodules: [
        SubModuleItem(
          name: 'My Profile',
          description: 'View and edit your profile details.',
          icon: Icons.person_rounded,
          colors: [const Color(0xFF0EA5E9), const Color(0xFF0284C7)],
          screen: const MyProfileScreen(showAppBar: true),
        ),
        SubModuleItem(
          name: 'My Settings',
          description: 'App preferences and account settings.',
          icon: Icons.settings_rounded,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final results = _searchResults;
    final isSearching = _searchQuery.trim().isNotEmpty;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            onChanged: (val) => setState(() => _searchQuery = val),
            decoration: InputDecoration(
              hintText: 'Search modules...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () => setState(() => _searchQuery = ''),
                    )
                  : null,
              filled: true,
              fillColor: isDark ? AppColors.darkSecondarySurface : AppColors.lightInputBackground,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ),
        Expanded(
          child: isSearching
              ? (results.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
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
                              onPressed: () => setState(() => _searchQuery = ''),
                              child: const Text('Clear Search'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: results.length,
                      separatorBuilder: (context, index) => Divider(
                        height: 1,
                        indent: 68,
                        color: isDark ? Colors.white12 : Colors.black12,
                      ),
                      itemBuilder: (context, index) {
                        final item = results[index];
                        final sub = item.submodule;
                        return InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => sub.screen),
                            );
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                            child: Row(
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: sub.colors,
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(sub.icon, color: Colors.white, size: 22),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        sub.name,
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: isDark ? AppColors.darkPrimaryText : Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${item.parentTitle} • ${sub.description}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          color: isDark ? Colors.white60 : Colors.black54,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  Icons.chevron_right,
                                  size: 20,
                                  color: isDark ? Colors.white38 : Colors.black45,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ))
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: _parentModules.length,
                  separatorBuilder: (context, index) => Divider(
                    height: 1,
                    indent: 68,
                    color: isDark ? Colors.white12 : Colors.black12,
                  ),
                  itemBuilder: (context, index) {
                    final parent = _parentModules[index];
                    return InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ParentSubmodulesScreen(parent: parent),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: parent.colors,
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(parent.icon, color: Colors.white, size: 22),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    parent.title,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? AppColors.darkPrimaryText : Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    parent.description,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: isDark ? Colors.white60 : Colors.black54,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${parent.submodules.length}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white70 : Colors.black54,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(
                              Icons.chevron_right,
                              size: 20,
                              color: isDark ? Colors.white38 : Colors.black45,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );

    if (!widget.showAppBar) return Material(color: Colors.transparent, child: content);

    return Scaffold(
      appBar: AppBar(
        title: const Text('More Modules', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
      ),
      body: content,
    );
  }
}

class ParentSubmodulesScreen extends StatefulWidget {
  final ParentModuleItem parent;
  const ParentSubmodulesScreen({super.key, required this.parent});

  @override
  State<ParentSubmodulesScreen> createState() => _ParentSubmodulesScreenState();
}

class _ParentSubmodulesScreenState extends State<ParentSubmodulesScreen> {
  String _subSearchQuery = '';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filteredSubmodules = widget.parent.submodules.where((sub) {
      if (_subSearchQuery.trim().isEmpty) return true;
      final q = _subSearchQuery.trim().toLowerCase();
      return sub.name.toLowerCase().contains(q) || sub.description.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.parent.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              onChanged: (val) => setState(() => _subSearchQuery = val),
              decoration: InputDecoration(
                hintText: 'Search in ${widget.parent.title}...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _subSearchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => setState(() => _subSearchQuery = ''),
                      )
                    : null,
                filled: true,
                fillColor: isDark ? AppColors.darkSecondarySurface : AppColors.lightInputBackground,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          Expanded(
            child: filteredSubmodules.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off_rounded, size: 48, color: Colors.grey),
                          SizedBox(height: 12),
                          Text('No submodules found', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: filteredSubmodules.length,
                    separatorBuilder: (context, index) => Divider(
                      height: 1,
                      indent: 68,
                      color: isDark ? Colors.white12 : Colors.black12,
                    ),
                    itemBuilder: (context, index) {
                      final sub = filteredSubmodules[index];
                      return InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => sub.screen),
                          );
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                          child: Row(
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: sub.colors,
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(sub.icon, color: Colors.white, size: 22),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      sub.name,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? AppColors.darkPrimaryText : Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      sub.description,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        color: isDark ? Colors.white60 : Colors.black54,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                Icons.chevron_right,
                                size: 20,
                                color: isDark ? Colors.white38 : Colors.black45,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
