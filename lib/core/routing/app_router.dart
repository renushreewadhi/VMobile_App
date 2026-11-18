import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../admin/admin_role_shell.dart';
import '../../auth/login_screen.dart';
import '../../employee/employee_role_shell.dart';
import '../../finance/finance_role_shell.dart';
import '../../helpdesk/helpdesk_role_shell.dart';
import '../../hr/hr_role_shell.dart';
import '../../it/it_role_shell.dart';
import '../../team_lead/team_lead_role_shell.dart';
import '../auth/auth_service.dart';
import '../models/user_model.dart';

class AppRouter extends ConsumerWidget {
  const AppRouter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authServiceProvider);
    if (kDebugMode) {
      debugPrint('[AuthDiag:AppRouter] state -> isInitializing: ${authState.isInitializing}, isLoading: ${authState.isLoading}, isAuthenticated: ${authState.isAuthenticated}, user: ${authState.user?.email}, role: ${authState.user?.role}');
    }

    if (authState.isInitializing) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF0F2E2C) : const Color(0xFFE9FBF8),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Initializing Etaprise HRMS...',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (!authState.isAuthenticated || authState.user == null) {
      return const LoginScreen();
    }

    // OBS-01 Remediation: Prevent unverified cached roles from granting access to privileged screens while offline.
    // If the session is unverified offline (isOfflineSession == true) and holds a privileged role, restrict to standard employee shell.
    if (authState.isOfflineSession) {
      final role = authState.user!.role;
      if (role == UserRole.ADMIN || role == UserRole.HR || role == UserRole.FINANCE || role == UserRole.TL) {
        return const EmployeeRoleShell();
      }
    }

    if (authState.user!.role == UserRole.UNAUTHORIZED) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.block_rounded, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                const Text('Access Denied', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('Your account role is unrecognized or unauthorized.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => ref.read(authServiceProvider.notifier).logout(),
                  child: const Text('Sign Out'),
                ),
              ],
            ),
          ),
        ),
      );
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
      case UserRole.UNAUTHORIZED:
        return const LoginScreen();
    }
  }
}
