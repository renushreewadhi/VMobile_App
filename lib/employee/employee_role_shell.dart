import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/apply_leave_screen.dart';
import 'screens/employee_dashboard_screen.dart';
import 'screens/more_screen.dart';
import 'screens/my_attendance_screen.dart';
import 'screens/my_leave_screen.dart';
import 'screens/punch_in_out_screen.dart';
import 'screens/wfh_apply_screen.dart';
import '../core/theme/app_colors.dart';
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
      EmployeeDashboardScreen(onNavigateTab: (tabIndex) {
        if (tabIndex == 2) {
          setState(() => _currentIndex = 3); // My Leave
        } else if (tabIndex == 3) {
          setState(() => _currentIndex = 4); // More / Tasks
        } else {
          setState(() => _currentIndex = tabIndex);
        }
      }),
      const MyAttendanceScreen(showAppBar: false),
      const SizedBox.shrink(), // Placeholder for center + action
      const MyLeaveScreen(showAppBar: false),
      const MoreScreen(showAppBar: false),
    ];

    final titles = [
      '',
      'My Attendance',
      '',
      'My Leave',
      'More Services',
    ];

    return PopScope(
      canPop: _currentIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_currentIndex != 0) {
          setState(() => _currentIndex = 0);
        }
      },
      child: GlassScaffold(
        appBar: GlassHeader(title: titles[_currentIndex]),
        showBottomBar: true,
        body: IndexedStack(
          index: _currentIndex == 2 ? 0 : _currentIndex.clamp(0, screens.length - 1),
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
            icon: Icons.add_rounded,
            label: "",
            isAction: true,
            isSelected: false,
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const PunchInOutScreen()));
            },
          ),
          GlassTab(
            icon: Icons.calendar_month_rounded,
            label: "My Leave",
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
