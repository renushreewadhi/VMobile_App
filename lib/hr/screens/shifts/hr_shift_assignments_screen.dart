import 'package:flutter/material.dart';
import '../../../admin/screens/admin_shift_assignments_screen.dart';

/// HR Shift Assignments Screen delegating to [AdminShiftAssignmentsScreen].
class HrShiftAssignmentsScreen extends StatelessWidget {
  final List<dynamic>? initialAssignments;
  final List<dynamic>? initialEmployees;
  final List<dynamic>? initialShifts;

  const HrShiftAssignmentsScreen({
    super.key,
    this.initialAssignments,
    this.initialEmployees,
    this.initialShifts,
  });

  @override
  Widget build(BuildContext context) {
    return AdminShiftAssignmentsScreen(
      initialAssignments: initialAssignments,
      initialEmployees: initialEmployees,
      initialShifts: initialShifts,
    );
  }
}
