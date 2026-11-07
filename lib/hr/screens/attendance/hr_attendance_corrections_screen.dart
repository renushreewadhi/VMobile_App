import 'package:flutter/material.dart';
import '../../../admin/screens/admin_attendance_screen.dart';

/// HR Attendance Corrections Screen delegating to [AdminAttendanceScreen].
class HrAttendanceCorrectionsScreen extends StatelessWidget {
  final bool showAppBar;
  const HrAttendanceCorrectionsScreen({super.key, this.showAppBar = true});

  @override
  Widget build(BuildContext context) {
    return AdminAttendanceScreen(
      showAppBar: showAppBar,
      initialModule: 'corrections',
    );
  }
}
