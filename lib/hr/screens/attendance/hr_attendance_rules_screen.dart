import 'package:flutter/material.dart';
import '../../../admin/screens/admin_attendance_screen.dart';

/// HR Attendance Rules Screen delegating to [AdminAttendanceScreen].
class HrAttendanceRulesScreen extends StatelessWidget {
  final bool showAppBar;
  const HrAttendanceRulesScreen({super.key, this.showAppBar = true});

  @override
  Widget build(BuildContext context) {
    return AdminAttendanceScreen(
      showAppBar: showAppBar,
      initialModule: 'rules',
    );
  }
}
