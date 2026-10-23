# IT Module Conversion Plan (Angular to Flutter)

Convert all 12 IT module screens from Angular into the Flutter mobile application, preserving exact functionality, API endpoints, validations, business logic, and UI design patterns.

## User Review Required

- **Navigation**: Integrating all 12 IT screens into `ItRoleShell` using tab navigation, drawer menu, or dashboard quick actions.
- **Export & Reports**: Adapting PDF/Excel report generation and export actions for mobile (using sharing/snackbar or standard download/export handlers).

## Proposed Changes

### IT Module Screens & Shell

#### [MODIFY] [it_role_shell.dart](file:///C:/Users/Dell/Documents/Mobile-Hrms-Git/Ui/lib/it/it_role_shell.dart)
- Update shell to support navigation across all IT module components.

#### [MODIFY] [it_dashboard_screen.dart](file:///C:/Users/Dell/Documents/Mobile-Hrms-Git/Ui/lib/it/screens/it_dashboard_screen.dart)
- Enhance dashboard stats, ticket breakdown, asset breakdown, license summary, heatmaps, and pending requests approval workflow.

#### [MODIFY] [it_assets_screen.dart](file:///C:/Users/Dell/Documents/Mobile-Hrms-Git/Ui/lib/it/screens/it_assets_screen.dart)
- Enhance asset inventory, filters, view tabs, assign modal, repair/retire actions.

#### [MODIFY] [it_tickets_screen.dart](file:///C:/Users/Dell/Documents/Mobile-Hrms-Git/Ui/lib/it/screens/it_tickets_screen.dart)
- Enhance IT support ticket queue, filtering, view/comment modal, reply/resolution dialog, and ticket creation.

#### [NEW] [it_asset_requests_screen.dart](file:///C:/Users/Dell/Documents/Mobile-Hrms-Git/Ui/lib/it/screens/it_asset_requests_screen.dart)
- Asset requests management (view, filter by status/category, approve/reject workflow, new request submission).

#### [NEW] [it_software_screen.dart](file:///C:/Users/Dell/Documents/Mobile-Hrms-Git/Ui/lib/it/screens/it_software_screen.dart)
- Software license management, seats tracking, expiry warnings, create/edit license modal, assign seats, revoke assignments.

#### [NEW] [it_access_screen.dart](file:///C:/Users/Dell/Documents/Mobile-Hrms-Git/Ui/lib/it/screens/it_access_screen.dart)
- System access control rules, role-based permissions, MFA enforcement tracking, create/edit access rule modal, revoke/delete.

#### [NEW] [it_onboarding_screen.dart](file:///C:/Users/Dell/Documents/Mobile-Hrms-Git/Ui/lib/it/screens/it_onboarding_screen.dart)
- IT onboarding checklist (email setup, laptop provisioning, VPN access), status filters, add/edit onboarding task.

#### [NEW] [it_offboarding_screen.dart](file:///C:/Users/Dell/Documents/Mobile-Hrms-Git/Ui/lib/it/screens/it_offboarding_screen.dart)
- IT offboarding checklist (account disabling, asset return, data wiping), revoke all access action, add/edit offboarding record.

#### [NEW] [it_security_screen.dart](file:///C:/Users/Dell/Documents/Mobile-Hrms-Git/Ui/lib/it/screens/it_security_screen.dart)
- Security audit logs, firewall status, failed login alerts, severity filtering, log detail view modal.

#### [NEW] [it_reports_screen.dart](file:///C:/Users/Dell/Documents/Mobile-Hrms-Git/Ui/lib/it/screens/it_reports_screen.dart)
- IT reports dashboard (invoices, licenses, helpdesk SLA, security logs, asset allocation audit), PDF/Excel export actions, custom report generator.

#### [NEW] [it_employee_accounts_screen.dart](file:///C:/Users/Dell/Documents/Mobile-Hrms-Git/Ui/lib/it/screens/it_employee_accounts_screen.dart) & [it_create_employee_account_screen.dart](file:///C:/Users/Dell/Documents/Mobile-Hrms-Git/Ui/lib/it/screens/it_create_employee_account_screen.dart)
- Employee IT accounts ledger (email, HRMS, VPN, software access, account status), search, pagination, create/edit account form.

## Verification Plan

### Automated Tests
- Run `flutter analyze` and `flutter test` to ensure zero compilation errors.

### Manual Verification
- Deploy to device/emulator and verify each screen loads data from backend APIs and handles interactive flows correctly.
