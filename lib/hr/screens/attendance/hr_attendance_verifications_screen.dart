import 'package:flutter/material.dart';
import '../../../admin/screens/admin_attendance_screen.dart';

/// HR Attendance Verifications Screen delegating to [AdminAttendanceScreen].
class HrAttendanceVerificationsScreen extends StatelessWidget {
  final bool showAppBar;
  const HrAttendanceVerificationsScreen({super.key, this.showAppBar = true});

  @override
  Widget build(BuildContext context) {
    return AdminAttendanceScreen(
      showAppBar: showAppBar,
      initialModule: 'verifications',
    );
  }
}
