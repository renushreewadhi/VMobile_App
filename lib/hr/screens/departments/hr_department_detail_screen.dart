import 'package:flutter/material.dart';
import '../../../admin/screens/admin_department_detail_screen.dart';

/// HR Department Detail Screen delegating to [AdminDepartmentDetailScreen].
class HrDepartmentDetailScreen extends StatelessWidget {
  final String deptId;

  const HrDepartmentDetailScreen({super.key, required this.deptId});

  @override
  Widget build(BuildContext context) {
    return AdminDepartmentDetailScreen(deptId: deptId);
  }
}
