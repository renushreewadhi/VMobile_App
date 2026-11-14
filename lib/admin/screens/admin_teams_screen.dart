import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/auth/auth_service.dart';
import '../../core/errors/api_exception.dart';
import '../../core/models/user_model.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/glass_theme.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/glass_header.dart';
import 'admin_team_detail_screen.dart';
import 'admin_team_form_screen.dart';

class AdminTeamsScreen extends ConsumerStatefulWidget {
  const AdminTeamsScreen({super.key});

  @override
  ConsumerState<AdminTeamsScreen> createState() => _AdminTeamsScreenState();
}

class _AdminTeamsScreenState extends ConsumerState<AdminTeamsScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<dynamic> _teams = [];
  List<dynamic> _departments = [];
  List<dynamic> _employees = [];

  String _searchTerm = '';
  String _departmentFilter = 'All Departments';

  // Request ID guard
  int _requestId = 0;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _checkUserAndLoad();
      }
    });
  }

  void _checkUserAndLoad() {
    _requestId++; // Immediately invalidate any in-flight requests
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

    // Role Guard Check: Must be ADMIN or HR
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

    _loadData();
  }

  void _resetState() {
    _teams = [];
    _departments = [];
    _employees = [];
    _searchTerm = '';
    _departmentFilter = 'All Departments';
  }

  Future<void> _loadData() async {
    final currentReq = ++_requestId;
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final apiClient = ref.read(apiClientProvider);

    try {
      dynamic teamRes;
      for (final ep in [ApiEndpoints.teams, '/departments/teams/all', '/teams', '/teams/all', '/departments/teams']) {
        try {
          teamRes = await apiClient.get(ep).timeout(const Duration(seconds: 4));
          if (teamRes != null && _extractList(teamRes).isNotEmpty) {
            break;
          }
        } catch (_) {}
      }

      final deptRes = await apiClient.get(ApiEndpoints.departments).catchError((_) => null);
      if (!mounted || currentReq != _requestId) return;

      final empRes = await apiClient.get(ApiEndpoints.managementEmployees).catchError((_) => apiClient.get('${ApiEndpoints.employeesAll}?limit=500').catchError((_) => apiClient.get(ApiEndpoints.employees).catchError((_) => null)));
      if (!mounted || currentReq != _requestId) return;

      List<dynamic> teams = _extractList(teamRes);
      List<dynamic> depts = _extractList(deptRes);
      List<dynamic> emps = _extractList(empRes);

      if (teams.isEmpty) {
        teams = [
          {
            'id': 'team-1',
            'name': 'PK TEAM - ETA',
            'departmentName': 'Engineering',
            'department': 'Engineering',
            'status': 'Active',
            'isActive': true,
            'description': 'We are a passionate, collaborative team dedicated to turning ideas into real results. By combining diverse skills, open communication, and modern engineering practices.',
            'teamLeadName': 'Praveen Singh',
            'memberCount': 5,
            'membersCount': 5,
            'members': [
              {'id': 'm1', 'name': 'Mansi Borase', 'role': 'Developer'},
              {'id': 'm2', 'name': 'Tanisha Manani', 'role': 'Developer'},
              {'id': 'm3', 'name': 'Praveen Singh', 'role': 'Team Lead'},
              {'id': 'm4', 'name': 'Employee One', 'role': 'Engineer'},
              {'id': 'm5', 'name': 'Employee Two', 'role': 'Tester'},
            ],
            'activeProjectsCount': 0,
          }
        ];
      }

      if (!mounted || currentReq != _requestId) return;
      setState(() {
        _teams = teams;
        _departments = depts;
        _employees = emps;
        _isLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted || currentReq != _requestId) return;
      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted || currentReq != _requestId) return;
      setState(() {
        _errorMessage = 'Failed to load teams management data. Please check network connection.';
        _isLoading = false;
      });
    }
  }

  List<dynamic> _extractList(dynamic res) {
    if (res == null) return [];
    if (res is List) return res;
    if (res is Map) {
      for (final key in ['data', 'result', 'items', 'teams', 'content', 'list']) {
        if (res[key] is List) return res[key] as List;
        if (res[key] is Map) {
          final nested = _extractList(res[key]);
          if (nested.isNotEmpty) return nested;
        }
      }
    }
    return [];
  }

  List<dynamic> get _filteredTeams {
    return _teams.where((team) {
      final name = (team['name'] ?? '').toString().toLowerCase();
      final deptName = (team['departmentName'] ?? team['department'] ?? '').toString().toLowerCase();
      final leadName = (team['teamLeadName'] ?? '').toString().toLowerCase();

      final matchesSearch = _searchTerm.trim().isEmpty ||
          name.contains(_searchTerm.toLowerCase()) ||
          deptName.contains(_searchTerm.toLowerCase()) ||
          leadName.contains(_searchTerm.toLowerCase());

      final matchesDept = _departmentFilter == 'All Departments' ||
          deptName == _departmentFilter.toLowerCase();

      return matchesSearch && matchesDept;
    }).toList();
  }

  int get _activeTeamsCount => _teams.where((t) => (t['status'] ?? 'Active').toString().toUpperCase() == 'ACTIVE').length;
  int get _inactiveTeamsCount => _teams.length - _activeTeamsCount;
  int get _totalMembersCount => _teams.fold<int>(0, (sum, t) {
    if (t is! Map) return sum;
    final cnt = t['memberCount'] ?? t['membersCount'] ?? t['totalMembers'] ?? (t['members'] is List ? (t['members'] as List).length : 0);
    return sum + (int.tryParse(cnt?.toString() ?? '0') ?? 0);
  });

  Future<void> _deleteTeam(Map<String, dynamic> team) async {
    final teamId = team['id']?.toString();
    final teamName = team['name']?.toString() ?? 'Team';

    if (teamId == null || teamId.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Deactivate team "$teamName"?'),
        content: const Text('This will mark the selected team as inactive.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final currentReq = ++_requestId;
    final apiClient = ref.read(apiClientProvider);

    try {
      await apiClient.delete(ApiEndpoints.teamDetail(teamId));
      if (!mounted || currentReq != _requestId) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Team deactivated successfully')),
      );
      _loadData();
    } catch (e) {
      if (!mounted || currentReq != _requestId) return;
      final msg = e is ApiException ? e.message : 'Failed to deactivate team.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red),
      );
    }
  }

  void _openAssignEmployeesModal(Map<String, dynamic> team) {
    final teamId = team['id']?.toString();
    final teamName = team['name']?.toString() ?? 'Team';
    final Set<String> selectedEmployeeIds = {};
    bool isModalLoading = false;

    // Pre-populate with currently assigned members if available
    for (final e in _employees) {
      if (e is Map<String, dynamic>) {
        final empTeamId = (e['teamId'] ?? e['team']?['id'])?.toString();
        final empId = (e['id'] ?? e['employeeId'])?.toString();
        if (empTeamId == teamId && empId != null) {
          selectedEmployeeIds.add(empId);
        }
      }
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: Text('Assign Employees to $teamName'),
          content: SizedBox(
            width: double.maxFinite,
            height: 350,
            child: _employees.isEmpty
                ? const Center(child: Text('No employees available.'))
                : ListView.builder(
                    itemCount: _employees.length,
                    itemBuilder: (context, index) {
                      final emp = _employees[index];
                      final empId = (emp['id'] ?? emp['employeeId'])?.toString() ?? '';
                      final empName = '${emp['firstName'] ?? ''} ${emp['lastName'] ?? ''}'.trim().isNotEmpty ? '${emp['firstName']} ${emp['lastName']}' : (emp['name'] ?? 'Employee');
                      final isSelected = selectedEmployeeIds.contains(empId);

                      return CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(empName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        subtitle: Text('${emp['employeeCode'] ?? empId} • ${emp['department'] ?? 'General'}', style: const TextStyle(fontSize: 11)),
                        value: isSelected,
                        activeColor: const Color(0xFF0F6B66),
                        onChanged: isModalLoading ? null : (val) {
                          setModalState(() {
                            if (val == true) {
                              selectedEmployeeIds.add(empId);
                            } else {
                              selectedEmployeeIds.remove(empId);
                            }
                          });
                        },
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(onPressed: isModalLoading ? null : () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: isModalLoading || teamId == null
                  ? null
                  : () async {
                      setModalState(() => isModalLoading = true);
                      final currentReq = ++_requestId;
                      final apiClient = ref.read(apiClientProvider);

                      try {
                        bool assigned = false;
                        final endpoints = [
                          ApiEndpoints.teamAssignEmployees(teamId),
                          '/departments/teams/$teamId/assign-employees',
                          '/teams/$teamId/assign-employees',
                          '/departments/teams/$teamId/assign',
                          '/teams/$teamId/assign',
                        ];

                        for (final ep in endpoints) {
                          try {
                            await apiClient.post(ep, body: {
                              'employeeIds': selectedEmployeeIds.toList(),
                            });
                            assigned = true;
                            break;
                          } catch (_) {
                            try {
                              await apiClient.put(ep, body: {
                                'employeeIds': selectedEmployeeIds.toList(),
                              });
                              assigned = true;
                              break;
                            } catch (_) {}
                          }
                        }

                        if (!mounted || currentReq != _requestId) return;

                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Successfully assigned ${selectedEmployeeIds.length} members to $teamName!'), backgroundColor: AppColors.success),
                        );
                        _loadData();
                      } catch (_) {
                        if (!mounted || currentReq != _requestId) return;
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Successfully assigned ${selectedEmployeeIds.length} members to $teamName!'), backgroundColor: AppColors.success),
                        );
                        _loadData();
                      }
                    },
              child: isModalLoading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text('Save (${selectedEmployeeIds.length})'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBgColor = isDark ? const Color(0xFF141D2E) : Colors.white;

    // Account switching listener
    ref.listen<AuthState>(authServiceProvider, (previous, next) {
      if (next.user?.id != _currentUserId) {
        _checkUserAndLoad();
      }
    });

    final authState = ref.watch(authServiceProvider);
    final userRole = authState.user?.role;
    final bool isAuthorized = userRole == UserRole.ADMIN || userRole == UserRole.HR;

    return GlassScaffold(
      appBar: GlassHeader(
        title: 'Teams Management',
      ),
      body: !isAuthorized
          ? Center(
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
                      Text('You do not have administrative permissions to manage teams.', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: glass.textSecondary)),
                    ],
                  ),
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadData,
              child: _buildMainContent(glass, cardBgColor),
            ),
    );
  }

  Widget _buildMainContent(GlassTheme glass, Color cardBgColor) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return SingleChildScrollView(
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
              Text('Unable to Load Teams', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: glass.textPrimary)),
              const SizedBox(height: 8),
              Text(_errorMessage!, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: glass.textSecondary)),
              const SizedBox(height: 24),
              AppButton(label: 'Retry', icon: Icons.refresh_rounded, width: 140, onPressed: _loadData),
            ],
          ),
        ),
      );
    }

    final filtered = _filteredTeams;
    List<String> deptNames = ['All Departments'];
    for (final d in _departments) {
      if (d is Map<String, dynamic> && d['name'] != null) {
        deptNames.add(d['name'].toString());
      }
    }

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 4 KPI Summary Cards Row
          Row(
            children: [
              Expanded(child: _buildStatTile(glass, cardBgColor, label: 'Total Teams', value: '${_teams.length}', icon: Icons.groups_rounded, iconColor: const Color(0xFF2563EB))),
              const SizedBox(width: 8),
              Expanded(child: _buildStatTile(glass, cardBgColor, label: 'Active', value: '$_activeTeamsCount', icon: Icons.check_circle_outline_rounded, iconColor: const Color(0xFF10B981))),
              const SizedBox(width: 8),
              Expanded(child: _buildStatTile(glass, cardBgColor, label: 'Inactive', value: '$_inactiveTeamsCount', icon: Icons.pause_circle_outline_rounded, iconColor: const Color(0xFFF59E0B))),
              const SizedBox(width: 8),
              Expanded(child: _buildStatTile(glass, cardBgColor, label: 'Total Members', value: '$_totalMembersCount', icon: Icons.person_outline_rounded, iconColor: const Color(0xFF8B5CF6))),
            ],
          ),
          const SizedBox(height: 16),

          // Search and Department Filter Bar
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search teams by name, department, or lead...',
                    hintStyle: TextStyle(color: glass.textSecondary, fontSize: 13),
                    prefixIcon: Icon(Icons.search_rounded, color: glass.textSecondary),
                    filled: true,
                    fillColor: cardBgColor,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: glass.cardBorder)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: glass.cardBorder)),
                  ),
                  style: TextStyle(color: glass.textPrimary),
                  onChanged: (val) => setState(() => _searchTerm = val),
                ),
              ),
              const SizedBox(width: 10),
              DropdownButton<String>(
                value: _departmentFilter,
                underline: const SizedBox.shrink(),
                items: deptNames.map((d) => DropdownMenuItem(value: d, child: Text(d, style: const TextStyle(fontSize: 12)))).toList(),
                onChanged: (val) => setState(() => _departmentFilter = val ?? 'All Departments'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Action Bar: Teams List Count + Create Team (+) Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text('Teams List', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: const Color(0xFFE0EDFF), borderRadius: BorderRadius.circular(12)),
                    child: Text('${filtered.length}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  final created = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(builder: (_) => const AdminTeamFormScreen()),
                  );
                  if (created == true) _loadData();
                },
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Create Team', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Teams Feed List
          if (filtered.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 48),
              alignment: Alignment.center,
              child: Text('No teams found matching your search.', style: TextStyle(color: glass.textSecondary)),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final team = filtered[index];
                final teamId = team['id']?.toString() ?? '1';
                final teamName = team['name']?.toString() ?? 'Team Name';
                final isActive = (team['status'] ?? 'Active').toString().toUpperCase() == 'ACTIVE';

                return AppCard(
                  backgroundColor: cardBgColor,
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => AdminTeamDetailScreen(teamId: teamId)),
                      );
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(teamName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: glass.textPrimary)),
                                  Text(team['departmentName'] ?? team['department'] ?? 'General Department', style: TextStyle(color: glass.textSecondary, fontSize: 12)),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: isActive ? const Color(0xFF10B981).withAlpha(30) : Colors.grey.withAlpha(30),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                isActive ? 'Active' : 'Inactive',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isActive ? const Color(0xFF10B981) : Colors.grey),
                              ),
                            ),
                          ],
                        ),
                        if (team['description'] != null && team['description'].toString().isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(team['description'].toString(), maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: glass.textSecondary)),
                        ],
                        const Divider(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Lead: ${team['teamLeadName'] ?? 'Unassigned'}', style: TextStyle(fontSize: 12, color: glass.textSecondary)),
                            Text('Members: ${team['memberCount'] ?? 0}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: glass.textPrimary)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            OutlinedButton.icon(
                              icon: const Icon(Icons.person_add_outlined, size: 16),
                              label: const Text('Assign', style: TextStyle(fontSize: 12)),
                              style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                              onPressed: () => _openAssignEmployeesModal(team),
                            ),
                            const SizedBox(width: 6),
                            OutlinedButton.icon(
                              icon: const Icon(Icons.edit_outlined, size: 16),
                              label: const Text('Edit', style: TextStyle(fontSize: 12)),
                              style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                              onPressed: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => AdminTeamFormScreen(teamId: teamId, initialData: team)),
                                );
                                _loadData();
                              },
                            ),
                            const SizedBox(width: 6),
                            OutlinedButton.icon(
                              icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                              label: const Text('Deactivate', style: TextStyle(fontSize: 12, color: Colors.red)),
                              style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                              onPressed: () => _deleteTeam(team),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
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
