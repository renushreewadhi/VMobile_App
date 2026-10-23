# Glass Migration Status Audit

| Path | Role | Uses AppBackground / GlassScaffold | Uses Legacy Material Widgets | Hard-coded Colors Count |
| :--- | :--- | :--- | :--- | :--- |
| `lib/employee/screens/more_screen.dart` | Employee | Yes | No (delegated to Glass/AppCard) | 0 |
| `lib/employee/employee_role_shell.dart` | Employee | Yes | No | 0 |
| `lib/shared/layouts/app_shell.dart` | Shared Shell | Yes | No | 0 |
| `lib/admin/admin_role_shell.dart` | Admin | Yes (via AppShell) | No | 0 |
| `lib/finance/finance_role_shell.dart` | Finance | Yes (via AppShell) | No | 0 |
| `lib/hr/hr_role_shell.dart` | HR | Yes (via AppShell) | No | 0 |
| `lib/helpdesk/helpdesk_role_shell.dart` | Helpdesk | Yes (via AppShell) | No | 0 |
| `lib/it/it_role_shell.dart` | IT | Yes (via AppShell) | No | 0 |
| `lib/team-lead/team_lead_role_shell.dart` | Team Lead | Yes (via AppShell) | No | 0 |
| `lib/auth/login_screen.dart` | Auth | Yes | No | 0 |
| `lib/employee/screens/my_settings_screen.dart` | Employee | Yes | No | 0 |
| `lib/core/widgets/app_card.dart` | Core UI | Yes | No | 0 |
| `lib/core/widgets/app_button.dart` | Core UI | Yes | No | 0 |
| `lib/shared/widgets/app_card.dart` | Shared UI | Yes | No | 0 |
| `lib/shared/widgets/custom_button.dart` | Shared UI | Yes | No | 0 |
