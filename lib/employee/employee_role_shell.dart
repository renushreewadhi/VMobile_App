import 'package:flutter/material.dart';
import '../../shared/layouts/app_shell.dart';
import 'screens/employee_dashboard_screen.dart';
import 'screens/more_screen.dart';
import 'screens/my_attendance_screen.dart';
import 'screens/my_leave_screen.dart';
import 'screens/notifications_screen.dart';

class EmployeeRoleShell extends StatefulWidget {
  const EmployeeRoleShell({super.key});

  @override
  State<EmployeeRoleShell> createState() => _EmployeeRoleShellState();
}

class _EmployeeRoleShellState extends State<EmployeeRoleShell> {
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

    final titles = [
      'Etaprise HRMS',
      'Attendance & Time',
      'Leave Management',
      'Notifications',
      'More Modules',
    ];

    return AppShell(
      title: titles[_currentIndex],
      selectedIndex: _currentIndex,
      onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
      destinations: const [
        NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
        NavigationDestination(icon: Icon(Icons.access_time_outlined), selectedIcon: Icon(Icons.access_time), label: 'Attendance'),
        NavigationDestination(icon: Icon(Icons.calendar_today_outlined), selectedIcon: Icon(Icons.calendar_today), label: 'My Leave'),
        NavigationDestination(icon: Icon(Icons.notifications_outlined), selectedIcon: Icon(Icons.notifications), label: 'Notifications'),
        NavigationDestination(icon: Icon(Icons.grid_view_outlined), selectedIcon: Icon(Icons.grid_view), label: 'More'),
      ],
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
    );
  }
}
