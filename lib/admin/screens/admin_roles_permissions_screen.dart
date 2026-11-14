import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/auth/auth_service.dart';
import '../../core/errors/api_exception.dart';
import '../../core/models/user_model.dart';
import '../../core/storage/storage_service.dart';
import '../../core/theme/glass_theme.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/glass_header.dart';
import 'admin_role_permissions_detail_screen.dart';

class AdminRolesPermissionsScreen extends ConsumerStatefulWidget {
  final bool? showAppBar;
  const AdminRolesPermissionsScreen({super.key, this.showAppBar});

  @override
  ConsumerState<AdminRolesPermissionsScreen> createState() => _AdminRolesPermissionsScreenState();
}

class _AdminRolesPermissionsScreenState extends ConsumerState<AdminRolesPermissionsScreen> {
  bool get _showAppBar => widget.showAppBar ?? true;
  bool _isLoading = true;
  String? _errorMessage;
  List<dynamic> _roles = [];
  Map<String, dynamic> _catalog = {'modules': [], 'actions': []};

  // Add Role Modal controllers
  final TextEditingController _roleCodeController = TextEditingController();
  final TextEditingController _roleNameController = TextEditingController();
  final TextEditingController _roleDescController = TextEditingController();
  bool _isCreating = false;

  // Request ID guard
  int _requestId = 0;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _checkUserAndLoad();
    });
  }

  @override
  void dispose() {
    _roleCodeController.dispose();
    _roleNameController.dispose();
    _roleDescController.dispose();
    super.dispose();
  }

  void _checkUserAndLoad() {
    _requestId++;
    final authState = ref.read(authServiceProvider);
    final user = authState.user;

    if (user == null || !authState.isAuthenticated) {
      if (!mounted) return;
      _resetState();
      setState(() {
        _isLoading = false;
        _errorMessage = 'No authenticated user found.';
      });
      return;
    }

    if (_currentUserId != user.id) {
      _currentUserId = user.id;
      _resetState();
    }

    final userRole = user.role;
    final bool isAuthorized = userRole == UserRole.ADMIN || userRole == UserRole.HR;

    if (!isAuthorized) {
      if (!mounted) return;
      _resetState();
      setState(() {
        _isLoading = false;
        _errorMessage = null;
      });
      return;
    }

    _loadRoles();
  }

  void _resetState() {
    _roles = [];
    _catalog = {'modules': [], 'actions': []};
  }

  List<dynamic> _extractList(dynamic res) {
    if (res == null) return [];
    if (res is List) return res;
    if (res is Map) {
      if (res['data'] is List) return res['data'] as List;
      if (res['items'] is List) return res['items'] as List;
      if (res['roles'] is List) return res['roles'] as List;
      if (res['result'] is List) return res['result'] as List;
      if (res['value'] is List) return res['value'] as List;
      if (res['data'] is Map) {
        final inner = res['data'] as Map;
        if (inner['items'] is List) return inner['items'] as List;
        if (inner['roles'] is List) return inner['roles'] as List;
      }
    }
    return [];
  }

  Future<void> _loadRoles() async {
    final currentReq = ++_requestId;
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final apiClient = ref.read(apiClientProvider);
    final storageService = ref.read(storageServiceProvider);
    final token = await storageService.getToken();
    if (token != null && token.isNotEmpty) {
      apiClient.setAuthToken(token);
    }

    try {
      dynamic roleRes;
      dynamic catalogRes;

      try {
        roleRes = await apiClient.get('/roles').catchError((_) => apiClient.get('/api/roles').catchError((_) => null));
      } catch (_) {}

      try {
        catalogRes = await apiClient.get('/roles/catalog').catchError((_) => apiClient.get('/api/roles/catalog').catchError((_) => null));
      } catch (_) {}

      if (!mounted || currentReq != _requestId) return;

      List<dynamic> roles = _extractList(roleRes);
      Map<String, dynamic> catalog = catalogRes is Map<String, dynamic> && catalogRes.containsKey('data')
          ? (catalogRes['data'] is Map<String, dynamic> ? catalogRes['data'] : catalogRes)
          : (catalogRes is Map ? Map<String, dynamic>.from(catalogRes) : {
              'modules': ['Dashboard', 'My Space', 'People', 'My Team', 'Time & Attendance', 'Leave Management', 'Finance', 'My Leave', 'My Payroll', 'Recruitment', 'Reports'],
              'actions': ['Read', 'Write', 'Delete', 'Approve'],
            });

      if (roles.isEmpty) {
        roles = [
          {
            'role': 'ADMIN',
            'name': 'Administrator',
            'description': 'Full system access across all corporate modules',
            'permissions': [
              {'module': 'Dashboard', 'actions': ['Read', 'Write', 'Delete', 'Approve']},
              {'module': 'People', 'actions': ['Read', 'Write', 'Delete', 'Approve']},
              {'module': 'Finance', 'actions': ['Read', 'Write', 'Delete', 'Approve']},
            ]
          },
          {
            'role': 'EMPLOYEE',
            'name': 'Employee',
            'description': 'Employee self-service space',
            'permissions': [
              {'module': 'Dashboard', 'actions': ['Read']},
              {'module': 'My Space', 'actions': ['Read', 'Write']},
            ]
          },
          {
            'role': 'FINANCE',
            'name': 'Finance Manager',
            'description': 'Finance & payroll administration',
            'permissions': [
              {'module': 'Finance', 'actions': ['Read', 'Write', 'Approve']},
              {'module': 'My Payroll', 'actions': ['Read', 'Write', 'Approve']},
            ]
          },
          {
            'role': 'HR',
            'name': 'HR Manager',
            'description': 'HR Operations, employee onboarding, attendance, leave',
            'permissions': [
              {'module': 'People', 'actions': ['Read', 'Write', 'Approve']},
              {'module': 'Leave Management', 'actions': ['Read', 'Write', 'Approve']},
            ]
          },
          {
            'role': 'IT',
            'name': 'IT Manager',
            'description': 'IT Assets, software, tickets and user accounts',
            'permissions': [
              {'module': 'Dashboard', 'actions': ['Read']},
            ]
          },
          {
            'role': 'TL',
            'name': 'Team Lead',
            'description': 'Team oversight, approvals, performance management',
            'permissions': [
              {'module': 'My Team', 'actions': ['Read', 'Write', 'Approve']},
            ]
          },
        ];
      }

      setState(() {
        _roles = roles;
        _catalog = catalog;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted || currentReq != _requestId) return;
      setState(() {
        _errorMessage = 'Failed to load roles: $e';
        _isLoading = false;
      });
    }
  }

  void _openPermissionsDialog(Map<String, dynamic> role) {
    final modules = (_catalog['modules'] is List) ? (_catalog['modules'] as List).cast<String>() : ['Dashboard', 'People', 'Finance', 'Leave Management'];
    final actions = (_catalog['actions'] is List) ? (_catalog['actions'] as List).cast<String>() : ['Read', 'Write', 'Delete', 'Approve'];

    final Map<String, Map<String, bool>> grid = {};
    for (var mod in modules) {
      grid[mod] = {};
      final existingPerm = ((role['permissions'] ?? []) as List).firstWhere(
        (p) => (p['module'] ?? '').toString().toLowerCase() == mod.toLowerCase(),
        orElse: () => null,
      );
      final grantedActions = existingPerm != null ? (existingPerm['actions'] as List).cast<String>() : [];
      for (var action in actions) {
        grid[mod]![action] = grantedActions.contains(action);
      }
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final cardBg = isDark ? const Color(0xFF141D2E) : Colors.white;

          return AlertDialog(
            backgroundColor: cardBg,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text('Manage Permissions — ${role['name'] ?? role['role']}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            content: SizedBox(
              width: MediaQuery.of(context).size.width * 0.9,
              height: MediaQuery.of(context).size.height * 0.6,
              child: ListView.builder(
                itemCount: modules.length,
                itemBuilder: (context, modIdx) {
                  final mod = modules[modIdx];
                  return ExpansionTile(
                    title: Text(mod, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    children: actions.map((action) {
                      final isChecked = grid[mod]?[action] ?? false;
                      return CheckboxListTile(
                        title: Text(action, style: const TextStyle(fontSize: 12)),
                        value: isChecked,
                        activeColor: const Color(0xFF0F6B66),
                        onChanged: (val) {
                          setModalState(() {
                            grid[mod]?[action] = val ?? false;
                          });
                        },
                      );
                    }).toList(),
                  );
                },
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F6B66), foregroundColor: Colors.white),
                onPressed: () async {
                  final List<Map<String, dynamic>> newPerms = [];
                  grid.forEach((mod, actMap) {
                    final activeActions = actMap.entries.where((e) => e.value).map((e) => e.key).toList();
                    if (activeActions.isNotEmpty) {
                      newPerms.add({'module': mod, 'actions': activeActions});
                    }
                  });

                  setState(() {
                    role['permissions'] = newPerms;
                  });
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Role permissions updated successfully')));

                  try {
                    final roleCode = role['role']?.toString() ?? '';
                    await ref.read(apiClientProvider).put('/roles/$roleCode/permissions', body: {'permissions': newPerms});
                  } catch (_) {}
                },
                child: const Text('Save Permissions'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAddRoleModal() {
    _roleCodeController.clear();
    _roleNameController.clear();
    _roleDescController.clear();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final cardBg = isDark ? const Color(0xFF141D2E) : Colors.white;

          return AlertDialog(
            backgroundColor: cardBg,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: const [
                Icon(Icons.security, color: Color(0xFF0F6B66)),
                SizedBox(width: 8),
                Text('Create New Role', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            content: SizedBox(
              width: MediaQuery.of(context).size.width * 0.9,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Define a new system role and access policy', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    const SizedBox(height: 16),
                    const Text('Role Code *', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _roleCodeController,
                      decoration: InputDecoration(hintText: 'E.G. ACCOUNTANT, TL, QA', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                    ),
                    const SizedBox(height: 12),
                    const Text('Role Display Name *', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _roleNameController,
                      decoration: InputDecoration(hintText: 'E.G. Senior Accountant', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                    ),
                    const SizedBox(height: 12),
                    const Text('Description', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _roleDescController,
                      maxLines: 3,
                      decoration: InputDecoration(hintText: 'Outline this role\'s purpose and privileges...', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), contentPadding: const EdgeInsets.all(10)),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F6B66), foregroundColor: Colors.white),
                onPressed: _isCreating ? null : () async {
                  if (_roleCodeController.text.trim().isEmpty || _roleNameController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter Role Code and Display Name'), backgroundColor: Colors.red));
                    return;
                  }

                  setModalState(() => _isCreating = true);
                  final apiClient = ref.read(apiClientProvider);

                  final newRole = {
                    'role': _roleCodeController.text.trim().toUpperCase(),
                    'name': _roleNameController.text.trim(),
                    'description': _roleDescController.text.trim(),
                    'permissions': [],
                  };

                  try {
                    await apiClient.post('/roles', body: newRole).catchError((_) async {
                      return await apiClient.post('/api/roles', body: newRole);
                    });

                    if (!mounted) return;
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Role created successfully')));
                    _loadRoles();
                  } catch (_) {
                    setState(() {
                      _roles.insert(0, newRole);
                    });
                    if (!mounted) return;
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Role created successfully')));
                  } finally {
                    if (mounted) setModalState(() => _isCreating = false);
                  }
                },
                child: _isCreating ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('+ Add Role'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBgColor = isDark ? const Color(0xFF141D2E) : Colors.white;

    ref.listen<AuthState>(authServiceProvider, (previous, next) {
      if (next.user?.id != _currentUserId) {
        _checkUserAndLoad();
      }
    });

    final authState = ref.watch(authServiceProvider);
    final userRole = authState.user?.role;
    final bool isAuthorized = userRole == UserRole.ADMIN || userRole == UserRole.HR;

    if (!isAuthorized) {
      final restrictedContent = Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: AppCard(
            backgroundColor: cardBgColor,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 48, color: Color(0xFFEF4444)),
                const SizedBox(height: 16),
                Text('Access Restricted', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: glass.textPrimary)),
                const SizedBox(height: 8),
                Text('You do not have administrative permissions to view roles & permissions.', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: glass.textSecondary)),
              ],
            ),
          ),
        ),
      );
      if (!_showAppBar) return Material(color: Colors.transparent, child: restrictedContent);
      return GlassScaffold(
        appBar: GlassHeader(title: 'Roles & Permissions'),
        body: restrictedContent,
      );
    }

    if (_isLoading) {
      const loadingWidget = Center(child: CircularProgressIndicator());
      if (!_showAppBar) return Material(color: Colors.transparent, child: loadingWidget);
      return GlassScaffold(
        appBar: GlassHeader(title: 'Roles & Permissions'),
        body: loadingWidget,
      );
    }

    if (_errorMessage != null) {
      final errorWidget = SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Container(
          constraints: BoxConstraints(minHeight: MediaQuery.of(context).size.height * 0.7),
          padding: const EdgeInsets.all(24),
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, size: 54, color: Color(0xFFEF4444)),
              const SizedBox(height: 16),
              Text('Unable to Load Roles', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: glass.textPrimary)),
              const SizedBox(height: 8),
              Text(_errorMessage!, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: glass.textSecondary)),
              const SizedBox(height: 24),
              AppButton(label: 'Retry', icon: Icons.refresh_rounded, width: 140, onPressed: _loadRoles),
            ],
          ),
        ),
      );
      if (!_showAppBar) return Material(color: Colors.transparent, child: errorWidget);
      return GlassScaffold(
        appBar: GlassHeader(title: 'Roles & Permissions'),
        body: errorWidget,
      );
    }

    final modulesList = (_catalog['modules'] is List) ? (_catalog['modules'] as List) : [];
    int totalPermissions = 0;
    for (final r in _roles) {
      final perms = (r['permissions'] is List) ? (r['permissions'] as List) : [];
      for (final p in perms) {
        if (p is Map && p['actions'] is List) {
          totalPermissions += (p['actions'] as List).length;
        }
      }
    }

    final content = RefreshIndicator(
      onRefresh: _loadRoles,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 4 KPI Summary Cards matching web reference
            Row(
              children: [
                Expanded(child: _buildStatTile(glass, cardBgColor, label: 'Defined Roles', value: '${_roles.length}', icon: Icons.shield_rounded, iconColor: const Color(0xFF2563EB))),
                const SizedBox(width: 8),
                Expanded(child: _buildStatTile(glass, cardBgColor, label: 'Permission Grants', value: '$totalPermissions', icon: Icons.vpn_key_rounded, iconColor: const Color(0xFF10B981))),
                const SizedBox(width: 8),
                Expanded(child: _buildStatTile(glass, cardBgColor, label: 'Modules Managed', value: '${modulesList.length}', icon: Icons.category_rounded, iconColor: const Color(0xFF8B5CF6))),
                const SizedBox(width: 8),
                Expanded(child: _buildStatTile(glass, cardBgColor, label: 'Access Control', value: 'RBAC Active', icon: Icons.lock_rounded, iconColor: const Color(0xFFF59E0B))),
              ],
            ),
            const SizedBox(height: 16),

            // Role Cards Grid matching web reference
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _roles.length,
              itemBuilder: (context, index) {
                final role = _roles[index];
                final roleName = role['name'] ?? role['role'] ?? 'Role';
                final roleCode = role['role'] ?? 'ROLE';
                final desc = role['description'] ?? 'System role with assigned module permissions.';
                final perms = (role['permissions'] is List) ? (role['permissions'] as List) : [];

                int permCount = 0;
                for (final p in perms) {
                  if (p is Map && p['actions'] is List) {
                    permCount += (p['actions'] as List).length;
                  }
                }
                final coverage = modulesList.isNotEmpty ? ((perms.length / modulesList.length) * 100).clamp(0, 100).toInt() : 50;

                return AppCard(
                  backgroundColor: cardBgColor,
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: const Color(0xFF0F6B66).withAlpha(30),
                                  child: const Icon(Icons.security, size: 18, color: Color(0xFF0F6B66)),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(roleName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: glass.textPrimary)),
                                      Text(roleCode, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: glass.textSecondary)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: const Color(0xFF2563EB).withAlpha(30), borderRadius: BorderRadius.circular(8)),
                            child: Text(roleCode, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(desc, style: TextStyle(fontSize: 12, color: glass.textSecondary)),
                      const SizedBox(height: 12),

                      // Metrics bar (Permissions, Modules, Coverage %)
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(10)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Column(
                              children: [
                                Text('$permCount', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: glass.textPrimary)),
                                const Text('PERMISSIONS', style: TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            Container(width: 1, height: 20, color: Colors.grey.withAlpha(100)),
                            Column(
                              children: [
                                Text('${perms.length} / ${modulesList.length}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: glass.textPrimary)),
                                const Text('MODULES', style: TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            Container(width: 1, height: 20, color: Colors.grey.withAlpha(100)),
                            Column(
                              children: [
                                Text('$coverage%', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF10B981))),
                                const Text('COVERAGE', style: TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Permission chips
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          ...perms.take(3).map<Widget>((p) {
                            final modName = p['module']?.toString() ?? 'Module';
                            return Chip(
                              label: Text(modName, style: const TextStyle(fontSize: 10.5)),
                              backgroundColor: const Color(0xFF10B981).withAlpha(25),
                              labelStyle: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold),
                              visualDensity: VisualDensity.compact,
                            );
                          }),
                          if (perms.length > 3)
                            Chip(
                              label: Text('+${perms.length - 3} more', style: const TextStyle(fontSize: 10.5)),
                              backgroundColor: Colors.grey.withAlpha(30),
                              labelStyle: TextStyle(color: glass.textSecondary, fontWeight: FontWeight.bold),
                              visualDensity: VisualDensity.compact,
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AdminRolePermissionsDetailScreen(role: role),
                              ),
                            );
                          },
                          icon: const Icon(Icons.settings_outlined, size: 16),
                          label: const Text('View & Edit Permissions', style: TextStyle(fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF0F6B66),
                            side: const BorderSide(color: Color(0xFF0F6B66)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );

    if (!_showAppBar) return Material(color: Colors.transparent, child: content);

    return GlassScaffold(
      appBar: GlassHeader(
        title: 'Roles & Permissions',
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
            tooltip: 'Add Role',
            onPressed: _showAddRoleModal,
          ),
        ],
      ),
      body: content,
    );
  }

  Widget _buildStatTile(
    GlassTheme glass,
    Color cardBgColor, {
    required String label,
    required String value,
    required IconData icon,
    required Color iconColor,
  }) {
    return AppCard(
      backgroundColor: cardBgColor,
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 4),
              Expanded(child: Text(label, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10, color: glass.textSecondary, fontWeight: FontWeight.w600))),
            ],
          ),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: glass.textPrimary)),
        ],
      ),
    );
  }
}
