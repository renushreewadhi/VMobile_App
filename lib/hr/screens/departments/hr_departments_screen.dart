import 'package:flutter/material.dart';
import '../../../admin/screens/admin_departments_screen.dart';

/// HR Departments Screen delegating to [AdminDepartmentsScreen] for full feature parity.
class HrDepartmentsScreen extends StatelessWidget {
  const HrDepartmentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AdminDepartmentsScreen();
  }
}
