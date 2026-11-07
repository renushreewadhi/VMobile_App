import 'package:flutter/material.dart';
import '../../../admin/screens/admin_shift_management_screen.dart';

/// HR Shift Management Screen delegating to [AdminShiftManagementScreen] for full multi-tab feature parity.
class HrShiftScreen extends StatelessWidget {
  final bool showAppBar;
  const HrShiftScreen({super.key, this.showAppBar = true});

  @override
  Widget build(BuildContext context) {
    return AdminShiftManagementScreen(showAppBar: showAppBar);
  }
}
