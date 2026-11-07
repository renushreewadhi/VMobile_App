import 'package:flutter/material.dart';
import '../../../admin/screens/admin_shift_form_screen.dart';

/// HR Shift Form Screen delegating to [AdminShiftFormScreen].
class HrShiftFormScreen extends StatelessWidget {
  final String? shiftId;
  final Map<String, dynamic>? initialData;

  const HrShiftFormScreen({super.key, this.shiftId, this.initialData});

  @override
  Widget build(BuildContext context) {
    return AdminShiftFormScreen(shiftId: shiftId, initialData: initialData);
  }
}
