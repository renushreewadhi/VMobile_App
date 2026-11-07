import 'package:flutter/material.dart';
import '../../../admin/screens/admin_department_form_screen.dart';

/// HR Department Form Screen delegating to [AdminDepartmentFormScreen].
class HrDepartmentFormScreen extends StatelessWidget {
  final String? deptId;
  final Map<String, dynamic>? initialData;

  const HrDepartmentFormScreen({super.key, this.deptId, this.initialData});

  @override
  Widget build(BuildContext context) {
    return AdminDepartmentFormScreen(deptId: deptId, initialData: initialData);
  }
}
