import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../theme/theme_provider.dart';
import 'glass_header.dart';
import 'glass_search_bar.dart';
import 'section_label.dart';
import 'module_card.dart';
import 'glass_bottom_tab_bar.dart';
import 'glass_scaffold.dart';

class GlassComponentPreviewScreen extends ConsumerStatefulWidget {
  const GlassComponentPreviewScreen({super.key});

  @override
  ConsumerState<GlassComponentPreviewScreen> createState() => _GlassComponentPreviewScreenState();
}

class _GlassComponentPreviewScreenState extends ConsumerState<GlassComponentPreviewScreen> {
  int _currentIndex = 4; // More tab active
  final TextEditingController _searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeProvider);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      home: GlassScaffold(
        appBar: const GlassHeader(
          title: "More Modules",
          userInitial: "E",
        ),
        body: ListView(
          padding: const EdgeInsets.only(top: 8, bottom: 20),
          children: [
            GlassSearchBar(
              controller: _searchController,
              placeholder: "Search modules...",
              onChanged: (val) {
                setState(() {});
              },
            ),
            const SectionLabel("ALL MODULES"),
            ModuleCard(
              icon: Icons.calendar_today_rounded,
              gradientColors: const [Color(0xFF34D399), Color(0xFF059669)],
              title: "Attendance & Time",
              subtitle: "Attendance, Check In/Out, Timesheet",
              count: 4,
              onPress: () {},
            ),
            ModuleCard(
              icon: Icons.work_outline_rounded,
              gradientColors: const [Color(0xFFFB923C), Color(0xFFEA580C)],
              title: "My Work",
              subtitle: "Tasks, Projects, Updates, Reports",
              count: 4,
              onPress: () {},
            ),
            ModuleCard(
              icon: Icons.card_giftcard_rounded,
              gradientColors: const [Color(0xFFF472B6), Color(0xFFDB2777)],
              title: "Leave & Benefits",
              subtitle: "Leave, Benefits, Invoices",
              count: 3,
              onPress: () {},
            ),
            ModuleCard(
              icon: Icons.account_balance_wallet_outlined,
              gradientColors: const [Color(0xFF818CF8), Color(0xFF4F46E5)],
              title: "Finance",
              subtitle: "Payslips, Salary, Expenses",
              count: 4,
              onPress: () {},
            ),
            ModuleCard(
              icon: Icons.headset_mic_outlined,
              gradientColors: const [Color(0xFF38BDF8), Color(0xFF0284C7)],
              title: "Support & IT",
              subtitle: "Helpdesk, Tickets, Assets",
              count: 7,
              onPress: () {},
            ),
            ModuleCard(
              icon: Icons.menu_book_rounded,
              gradientColors: const [Color(0xFF2DD4BF), Color(0xFF0D9488)],
              title: "Company & Learning",
              subtitle: "Policies, Courses, Directory",
              count: 5,
              onPress: () {},
            ),
          ],
        ),
        tabs: [
          GlassTab(
            icon: Icons.home_rounded,
            label: "Home",
            isSelected: _currentIndex == 0,
            onTap: () => setState(() => _currentIndex = 0),
          ),
          GlassTab(
            icon: Icons.access_time_rounded,
            label: "Attendance",
            isSelected: _currentIndex == 1,
            onTap: () => setState(() => _currentIndex = 1),
          ),
          GlassTab(
            icon: Icons.calendar_month_rounded,
            label: "My Leave",
            isSelected: _currentIndex == 2,
            onTap: () => setState(() => _currentIndex = 2),
          ),
          GlassTab(
            icon: Icons.notifications_rounded,
            label: "Alerts",
            badgeCount: 3,
            isSelected: _currentIndex == 3,
            onTap: () => setState(() => _currentIndex = 3),
          ),
          GlassTab(
            icon: Icons.grid_view_rounded,
            label: "More",
            isSelected: _currentIndex == 4,
            onTap: () => setState(() => _currentIndex = 4),
          ),
        ],
      ),
    );
  }
}
