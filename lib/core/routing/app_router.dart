import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../admin/admin_role_shell.dart';
import '../../auth/login_screen.dart';
import '../../employee/employee_role_shell.dart';
import '../../finance/finance_role_shell.dart';
import '../../helpdesk/helpdesk_role_shell.dart';
import '../../hr/hr_role_shell.dart';
import '../../it/it_role_shell.dart';
import '../../team-lead/team_lead_role_shell.dart';
import '../auth/auth_service.dart';
import '../models/user_model.dart';

class AppRouter extends ConsumerWidget {
  const AppRouter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authServiceProvider);

    if (authState.isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Initializing Etaprise HRMS...'),
            ],
          ),
        ),
      );
    }

    if (!authState.isAuthenticated || authState.user == null) {
      return const LoginScreen();
    }

    switch (authState.user!.role) {
      case UserRole.ADMIN:
        return const AdminRoleShell();
      case UserRole.HR:
        return const HrRoleShell();
      case UserRole.TL:
        return const TeamLeadRoleShell();
      case UserRole.IT:
        return const ItRoleShell();
      case UserRole.FINANCE:
        return const FinanceRoleShell();
      case UserRole.HELPDESK:
        return const HelpdeskRoleShell();
      case UserRole.EMPLOYEE:
        return const EmployeeRoleShell();
    }
  }
}
