import 'package:flutter/material.dart';
import '../../admin/screens/admin_dashboard_screen.dart';

/// HR Dashboard Screen delegating to [AdminDashboardScreen] for complete feature parity with Angular.
class HrDashboardScreen extends StatelessWidget {
  final Function(int) onNavigateTab;

  const HrDashboardScreen({super.key, required this.onNavigateTab});

  @override
  Widget build(BuildContext context) {
    return AdminDashboardScreen(onNavigateTab: onNavigateTab);
  }
}
