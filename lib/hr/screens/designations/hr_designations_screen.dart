import 'package:flutter/material.dart';
import '../../../admin/screens/admin_designations_screen.dart';

/// HR Designations Screen delegating to [AdminDesignationsScreen] for full feature parity.
class HrDesignationsScreen extends StatelessWidget {
  const HrDesignationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AdminDesignationsScreen();
  }
}
