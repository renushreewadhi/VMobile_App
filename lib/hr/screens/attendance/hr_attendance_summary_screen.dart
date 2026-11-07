import 'package:flutter/material.dart';
import '../../../admin/screens/admin_attendance_screen.dart';

/// HR Attendance Summary Screen delegating to [AdminAttendanceScreen].
class HrAttendanceSummaryScreen extends StatelessWidget {
  final bool showAppBar;
  const HrAttendanceSummaryScreen({super.key, this.showAppBar = true});

  @override
  Widget build(BuildContext context) {
    return AdminAttendanceScreen(
      showAppBar: showAppBar,
      initialModule: 'summary',
    );
  }
}
