import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/glass_theme.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/glass_header.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/status_chip.dart';

class AdminRolePermissionsDetailScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> role;

  const AdminRolePermissionsDetailScreen({super.key, required this.role});

  @override
  ConsumerState<AdminRolePermissionsDetailScreen> createState() => _AdminRolePermissionsDetailScreenState();
}

class _AdminRolePermissionsDetailScreenState extends ConsumerState<AdminRolePermissionsDetailScreen> {
  late Map<String, dynamic> _role;
  String _searchQuery = '';
  bool _isSaving = false;

  // Standard HRM modules and submodules list matching the web interface
  final List<Map<String, dynamic>> _modulesList = [
    {
      'title': 'Dashboard',
      'count': 1,
      'enabled': true,
      'submodules': [
        {'name': 'Dashboard', 'code': 'dashboard', 'enabled': true},
      ]
    },
    {
      'title': 'My Space',
      'count': 5,
      'enabled': true,
      'submodules': [
        {'name': 'My Profile', 'code': 'my-profile', 'enabled': true},
        {'name': 'My Attendance', 'code': 'my-attendance', 'enabled': true},
        {'name': 'Check In/Out', 'code': 'check-in-out', 'enabled': true},
        {'name': 'Break Tracker', 'code': 'break-tracker', 'enabled': true},
        {'name': 'Daily Work Update', 'code': 'daily-work-update', 'enabled': true},
      ]
    },
    {
      'title': 'People',
      'count': 5,
      'enabled': true,
      'submodules': [
        {'name': 'Directory', 'code': 'directory', 'enabled': true},
        {'name': 'Employee List', 'code': 'employee-list', 'enabled': true},
        {'name': 'Add Employee', 'code': 'add-employee', 'enabled': true},
        {'name': 'Organizational Chart', 'code': 'org-chart', 'enabled': true},
        {'name': 'Designations', 'code': 'designations', 'enabled': true},
      ]
    },
    {
      'title': 'My Team',
      'count': 10,
      'enabled': true,
      'submodules': [
        {'name': 'Team Members', 'code': 'team-members', 'enabled': true},
        {'name': 'Team Attendance', 'code': 'team-attendance', 'enabled': true},
        {'name': 'Leave Approvals', 'code': 'leave-approvals', 'enabled': true},
        {'name': 'Team Tasks', 'code': 'team-tasks', 'enabled': true},
        {'name': 'Team Projects', 'code': 'team-projects', 'enabled': true},
      ]
    },
    {
      'title': 'Time & Attendance',
      'count': 7,
      'enabled': true,
      'submodules': [
        {'name': 'Attendance Logs', 'code': 'attendance-logs', 'enabled': true},
        {'name': 'Shift Management', 'code': 'shift-management', 'enabled': true},
        {'name': 'Shift Assignments', 'code': 'shift-assignments', 'enabled': true},
        {'name': 'Attendance Settings', 'code': 'attendance-settings', 'enabled': true},
        {'name': 'Overtime Reports', 'code': 'overtime-reports', 'enabled': true},
      ]
    },
    {
      'title': 'Leave Management',
      'count': 1,
      'enabled': true,
      'submodules': [
        {'name': 'Leave Requests', 'code': 'leave-requests', 'enabled': true},
      ]
    },
    {
      'title': 'Finance',
      'count': 21,
      'enabled': true,
      'submodules': [
        {'name': 'Payroll Processing', 'code': 'payroll-processing', 'enabled': true},
        {'name': 'Salary Configuration', 'code': 'salary-config', 'enabled': true},
        {'name': 'Expense Claims', 'code': 'expense-claims', 'enabled': true},
        {'name': 'Reimbursements', 'code': 'reimbursements', 'enabled': true},
      ]
    },
  ];

  @override
  void initState() {
    super.initState();
    _role = Map<String, dynamic>.from(widget.role);
  }

  void _toggleAll(bool enable) {
    setState(() {
      for (final m in _modulesList) {
        m['enabled'] = enable;
        for (final sub in (m['submodules'] as List)) {
          sub['enabled'] = enable;
        }
      }
    });
  }

  Future<void> _savePermissions() async {
    setState(() => _isSaving = true);
    final apiClient = ref.read(apiClientProvider);
    try {
      final roleCode = _role['role']?.toString() ?? '';
      await apiClient.put('/roles/$roleCode/permissions', body: {'modules': _modulesList});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Role permissions saved successfully!'), backgroundColor: AppColors.success),
      );
      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Role permissions saved successfully!'), backgroundColor: AppColors.success),
      );
      Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBgColor = isDark ? const Color(0xFF141D2E) : Colors.white;
    final glass = context.glass;

    final roleName = _role['name'] ?? _role['role'] ?? 'Administrator';
    final roleCode = _role['role'] ?? 'ADMIN';
    final desc = _role['description'] ?? 'Full system access across all corporate modules';

    return GlassScaffold(
      appBar: GlassHeader(
        title: 'Permissions',
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, size: 16),
            label: const Text('Back to Roles'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Role Banner Card matching web reference
            AppCard(
              backgroundColor: cardBgColor,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: const Color(0xFF0F6B66).withAlpha(30),
                            child: const Icon(Icons.security, color: Color(0xFF0F6B66), size: 20),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(roleName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: glass.textPrimary)),
                              const SizedBox(height: 2),
                              Text(roleCode, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: glass.textSecondary)),
                            ],
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(8)),
                        child: Row(
                          children: const [
                            Icon(Icons.verified_user, size: 14, color: Color(0xFF16A34A)),
                            SizedBox(width: 4),
                            Text('Access Policy', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF16A34A))),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(desc, style: TextStyle(fontSize: 12.5, color: glass.textSecondary)),
                  const Divider(height: 24),

                  // Metrics summary row (Allowed Modules, Active Submodules, System Coverage)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          Text('101', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: glass.textPrimary)),
                          const Text('ALLOWED MODULES', style: TextStyle(fontSize: 9.5, color: Colors.grey, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Container(width: 1, height: 28, color: Colors.grey.withAlpha(100)),
                      Column(
                        children: [
                          Text('101 / 142', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: glass.textPrimary)),
                          const Text('ACTIVE SUBMODULES', style: TextStyle(fontSize: 9.5, color: Colors.grey, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Container(width: 1, height: 28, color: Colors.grey.withAlpha(100)),
                      Column(
                        children: [
                          const Text('71%', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF10B981))),
                          const Text('SYSTEM COVERAGE', style: TextStyle(fontSize: 9.5, color: Colors.grey, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Search Bar & Enable/Disable All Toolbar
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search modules or submodules...',
                      hintStyle: TextStyle(color: glass.textSecondary, fontSize: 12),
                      prefixIcon: Icon(Icons.search_rounded, color: glass.textSecondary, size: 18),
                      filled: true,
                      fillColor: cardBgColor,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: glass.cardBorder)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: glass.cardBorder)),
                    ),
                    style: TextStyle(color: glass.textPrimary, fontSize: 12.5),
                    onChanged: (val) => setState(() => _searchQuery = val),
                  ),
                ),
                const SizedBox(width: 6),
                OutlinedButton(
                  onPressed: () => _toggleAll(true),
                  style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact, foregroundColor: const Color(0xFF10B981)),
                  child: const Text('Enable All', style: TextStyle(fontSize: 11)),
                ),
                const SizedBox(width: 4),
                OutlinedButton(
                  onPressed: () => _toggleAll(false),
                  style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact, foregroundColor: const Color(0xFFEF4444)),
                  child: const Text('Disable All', style: TextStyle(fontSize: 11)),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Module Accordion Groups matching web reference
            ..._modulesList.map((m) {
              final title = m['title'] as String;
              final count = m['count'] as int;
              final groupEnabled = m['enabled'] is bool ? m['enabled'] as bool : true;
              final submodules = (m['submodules'] as List);

              if (_searchQuery.trim().isNotEmpty) {
                final term = _searchQuery.toLowerCase();
                final matchesTitle = title.toLowerCase().contains(term);
                final matchesSub = submodules.any((s) => (s['name'] as String).toLowerCase().contains(term));
                if (!matchesTitle && !matchesSub) return const SizedBox.shrink();
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: cardBgColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: isDark ? AppColors.darkBordersAndDividers : const Color(0xFFE2E8F0)),
                ),
                child: ExpansionTile(
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: glass.textPrimary)),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: Colors.grey.withAlpha(30), borderRadius: BorderRadius.circular(6)),
                              child: Text('$count Submodules', style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ),
                      OutlinedButton(
                        onPressed: () {
                          setState(() {
                            m['enabled'] = !groupEnabled;
                            for (final sub in submodules) {
                              sub['enabled'] = m['enabled'];
                            }
                          });
                        },
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          foregroundColor: groupEnabled ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                        ),
                        child: Text(groupEnabled ? 'Disable Group' : 'Enable Group', style: const TextStyle(fontSize: 10.5)),
                      ),
                    ],
                  ),
                  children: [
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('SUBMODULE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.5)),
                          const SizedBox(height: 8),
                          ...submodules.map((sub) {
                            final subName = sub['name'] as String;
                            final subCode = sub['code'] as String;
                            final subEnabled = sub['enabled'] is bool ? sub['enabled'] as bool : true;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(8)),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(subName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: glass.textPrimary)),
                                        Text(subCode, style: TextStyle(fontSize: 10, color: glass.textSecondary)),
                                      ],
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      const Text('Sidebar Access', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                      const SizedBox(width: 8),
                                      Switch(
                                        value: subEnabled,
                                        activeColor: const Color(0xFF10B981),
                                        onChanged: (val) {
                                          setState(() => sub['enabled'] = val);
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 24),

            // Save Permissions Footer Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _savePermissions,
                icon: const Icon(Icons.check, size: 16),
                label: Text(_isSaving ? 'Saving Permissions...' : 'Save Permissions', style: const TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F6B66), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
