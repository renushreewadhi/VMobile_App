import 'package:flutter/material.dart';
import '../../../admin/screens/admin_attendance_screen.dart';

/// HR Attendance Screen delegating to [AdminAttendanceScreen] for full multi-tab feature parity.
class HrAttendanceScreen extends StatelessWidget {
  final bool showAppBar;
  const HrAttendanceScreen({super.key, this.showAppBar = true});

  @override
  Widget build(BuildContext context) {
    return AdminAttendanceScreen(
      showAppBar: showAppBar,
      initialModule: 'daily',
    );
  }
}
