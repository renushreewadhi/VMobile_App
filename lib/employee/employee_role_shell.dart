import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/employee_dashboard_screen.dart';
import 'screens/more_screen.dart';
import 'screens/my_attendance_screen.dart';
import 'screens/my_leave_screen.dart';
import 'screens/notifications_screen.dart';
import '../core/widgets/glass_scaffold.dart';
import '../core/widgets/glass_header.dart';
import '../core/widgets/glass_bottom_tab_bar.dart';

class EmployeeRoleShell extends ConsumerStatefulWidget {
  const EmployeeRoleShell({super.key});

  @override
  ConsumerState<EmployeeRoleShell> createState() => _EmployeeRoleShellState();
}

class _EmployeeRoleShellState extends ConsumerState<EmployeeRoleShell> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
      EmployeeDashboardScreen(onNavigateTab: (index) => setState(() => _currentIndex = index)),
      const MyAttendanceScreen(showAppBar: false),
      const MyLeaveScreen(showAppBar: false),
      const NotificationsScreen(showAppBar: false),
      const MoreScreen(showAppBar: false),
    ];

    return GlassScaffold(
      appBar: const GlassHeader(), // Fixed brand header matching reference screenshot
      showBottomBar: true,
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
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
          label: "Notifications",
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
    );
  }
}
