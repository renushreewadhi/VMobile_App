import 'package:flutter/material.dart';
import '../../../admin/screens/admin_branches_screen.dart';

/// HR Branches Screen delegating to [AdminBranchesScreen] for full feature parity.
class HrBranchesScreen extends StatelessWidget {
  const HrBranchesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AdminBranchesScreen();
  }
}
