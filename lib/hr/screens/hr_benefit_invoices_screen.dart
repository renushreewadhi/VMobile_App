import 'package:flutter/material.dart';
import '../../admin/screens/admin_benefits_management_screen.dart';

/// HR Benefits Management Screen delegating to [AdminBenefitsManagementScreen] for full feature parity with Angular.
class HrBenefitInvoicesScreen extends StatelessWidget {
  final bool showAppBar;
  const HrBenefitInvoicesScreen({super.key, this.showAppBar = true});

  @override
  Widget build(BuildContext context) {
    return AdminBenefitsManagementScreen(showAppBar: showAppBar);
  }
}
