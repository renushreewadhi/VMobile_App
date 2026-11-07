import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/widgets/glass_header.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../core/widgets/glass_search_bar.dart';
import '../../../shared/widgets/app_card.dart';
import 'hr_team_detail_screen.dart';
import 'hr_team_form_screen.dart';

class HrTeamsScreen extends ConsumerStatefulWidget {
  final bool showAppBar;
  const HrTeamsScreen({super.key, this.showAppBar = true});

  @override
  ConsumerState<HrTeamsScreen> createState() => _HrTeamsScreenState();
}

class _HrTeamsScreenState extends ConsumerState<HrTeamsScreen> {
  bool _isLoading = true;
  String? _errorMessage;

  List<dynamic> _teams = [];
  List<dynamic> _departments = [];
  List<dynamic> _employees = [];

  String _searchTerm = '';
  String _departmentFilter = 'All Departments';

  // Assign Modal state
  bool _showAssignModal = false;
  Map<String, dynamic>? _selectedTeamForAssign;
  String _assignSearchTerm = '';
  final Set<String> _selectedEmployeeIdsForAssign = {};
  bool _isAssigning = false;

  int _requestId = 0;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _checkUserAndLoad();
    });
  }

  void _checkUserAndLoad() {
    final authState = ref.read(authServiceProvider);
    final user = authState.user;
    if (user == null || !authState.isAuthenticated) {
      if (!mounted) return;
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

    _loadData();
  }

  void _resetState() {
    setState(() {
      _teams = [];
      _departments = [];
      _employees = [];
      _searchTerm = '';
      _departmentFilter = 'All Departments';
      _errorMessage = null;
      _isLoading = true;
      _showAssignModal = false;
      _selectedTeamForAssign = null;
      _selectedEmployeeIdsForAssign.clear();
      _isAssigning = false;
    });
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
      final teamsRes = await apiClient.get(ApiEndpoints.teams);
      if (!mounted || currentReq != _requestId) return;

      final deptsRes = await apiClient.get(ApiEndpoints.departments).catchError((_) => []);
      if (!mounted || currentReq != _requestId) return;

      final empsRes = await apiClient.get(ApiEndpoints.employees).catchError((_) => apiClient.get('/employees/all').catchError((_) => []));
      if (!mounted || currentReq != _requestId) return;

      List<dynamic> teams = teamsRes is List ? teamsRes : (teamsRes is Map ? (teamsRes['items'] ?? teamsRes['data'] ?? []) : []);
      List<dynamic> depts = deptsRes is List ? deptsRes : (deptsRes is Map ? (deptsRes['items'] ?? deptsRes['data'] ?? []) : []);
      List<dynamic> emps = empsRes is List ? empsRes : (empsRes is Map ? (empsRes['items'] ?? empsRes['data'] ?? []) : []);

      setState(() {
        _teams = teams;
        _departments = depts;
        _employees = emps;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted || currentReq != _requestId) return;
      setState(() {
        _errorMessage = 'Failed to load teams management data: $e';
        _isLoading = false;
      });
    }
  }

  bool _isTeamActive(dynamic status) {
    if (status == null) return true;
    final s = status.toString().toUpperCase();
    return s == 'ACTIVE';
  }

  int get _activeTeamsCount => _teams.where((t) => _isTeamActive(t['status'])).length;
  int get _inactiveTeamsCount => _teams.where((t) => !_isTeamActive(t['status'])).length;
  int get _totalMembersCount => _teams.fold<int>(0, (sum, t) => sum + (int.tryParse(t['memberCount']?.toString() ?? '0') ?? 0));

  List<dynamic> get _filteredTeams {
    return _teams.where((team) {
      final map = team is Map<String, dynamic> ? team : {};
      final name = (map['name'] ?? '').toString().toLowerCase();
      final dept = (map['departmentName'] ?? map['department'] ?? '').toString().toLowerCase();
      final lead = (map['teamLeadName'] ?? '').toString().toLowerCase();
      final query = _searchTerm.trim().toLowerCase();

      final matchesSearch = query.isEmpty || name.contains(query) || dept.contains(query) || lead.contains(query);
      final matchesDept = _departmentFilter == 'All Departments' || dept == _departmentFilter.toLowerCase() || map['departmentId'] == _departmentFilter;

      return matchesSearch && matchesDept;
    }).toList();
  }

  List<dynamic> get _assignFilteredEmployees {
    if (_assignSearchTerm.trim().isEmpty) return _employees;
    final term = _assignSearchTerm.trim().toLowerCase();
    return _employees.where((e) {
      final firstName = (e['firstName'] ?? '').toString().toLowerCase();
      final lastName = (e['lastName'] ?? '').toString().toLowerCase();
      final fullName = '$firstName $lastName'.trim().isNotEmpty ? '$firstName $lastName' : (e['fullName'] ?? e['name'] ?? '').toString().toLowerCase();
      final dept = (e['department'] ?? '').toString().toLowerCase();
      final desig = (e['designation'] ?? '').toString().toLowerCase();
      final role = (e['role'] ?? '').toString().toLowerCase();
      final email = (e['email'] ?? '').toString().toLowerCase();

      return fullName.contains(term) || dept.contains(term) || desig.contains(term) || role.contains(term) || email.contains(term);
    }).toList();
  }

  void _openAssignModal(Map<String, dynamic> team) {
    setState(() {
      _selectedTeamForAssign = team;
      _assignSearchTerm = '';
      _selectedEmployeeIdsForAssign.clear();

      final tId = (team['id'] ?? '').toString().toLowerCase();
      final tName = (team['name'] ?? '').toString().toLowerCase();

      for (var e in _employees) {
        if (e is Map<String, dynamic>) {
          final empTeamId = (e['teamId'] ?? e['team']?['id'] ?? '').toString().toLowerCase();
          final empTeamName = (e['teamName'] ?? e['team']?['name'] ?? e['team'] ?? '').toString().toLowerCase();
          
          if (tId.isNotEmpty && empTeamId == tId) {
            final eId = e['id']?.toString() ?? e['employeeId']?.toString() ?? '';
            if (eId.isNotEmpty) _selectedEmployeeIdsForAssign.add(eId);
          } else if (empTeamId.isEmpty && tName.isNotEmpty && empTeamName == tName) {
            final eId = e['id']?.toString() ?? e['employeeId']?.toString() ?? '';
            if (eId.isNotEmpty) _selectedEmployeeIdsForAssign.add(eId);
          }
        }
      }

      _showAssignModal = true;
    });
  }

  Future<void> _saveAssignedEmployees() async {
    if (_selectedTeamForAssign == null || _isAssigning) return;
    final teamId = _selectedTeamForAssign!['id']?.toString() ?? '';
    final teamName = _selectedTeamForAssign!['name']?.toString() ?? 'Team';

    if (teamId.isEmpty) return;

    setState(() => _isAssigning = true);
    final apiClient = ref.read(apiClientProvider);

    try {
      await apiClient.post(ApiEndpoints.teamAssignEmployees(teamId), body: {
        'employeeIds': _selectedEmployeeIdsForAssign.toList(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Employees assigned to "$teamName" successfully')));
        setState(() {
          _showAssignModal = false;
          _isAssigning = false;
        });
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isAssigning = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to assign employees: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _deactivateTeam(Map<String, dynamic> team) async {
    final teamId = team['id']?.toString() ?? '';
    final teamName = team['name']?.toString() ?? 'Team';

    if (teamId.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Deactivate "$teamName"?'),
        content: const Text('This will change team status to Inactive.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final apiClient = ref.read(apiClientProvider);
    try {
      await apiClient.delete(ApiEndpoints.teamDetail(teamId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Team deactivated successfully')));
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to deactivate team: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authServiceProvider, (previous, next) {
      if (next.user?.id != _currentUserId) {
        _checkUserAndLoad();
      }
    });

    if (_isLoading) {
      final skeleton = const Center(child: CircularProgressIndicator());
      if (!widget.showAppBar) return Material(color: Colors.transparent, child: skeleton);
      return GlassScaffold(title: 'Teams Management', body: skeleton);
    }

    if (_errorMessage != null) {
      final errBody = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, size: 54, color: Colors.red),
              const SizedBox(height: 16),
              const Text('Unable to Load Teams', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(_errorMessage!, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
              const SizedBox(height: 24),
              ElevatedButton.icon(onPressed: _loadData, icon: const Icon(Icons.refresh), label: const Text('Retry')),
            ],
          ),
        ),
      );
      if (!widget.showAppBar) return Material(color: Colors.transparent, child: errBody);
      return GlassScaffold(title: 'Teams Management', body: errBody);
    }

    final filtered = _filteredTeams;
    final cardBg = Theme.of(context).cardColor;
    final primaryColor = Theme.of(context).primaryColor;

    final bodyContent = Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // KPI Cards
              Row(
                children: [
                  Expanded(child: _buildMetricCard('Total Teams', '${_teams.length}', 'Active organizational units', Colors.blue, Icons.groups, cardBg)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildMetricCard('Active Teams', '$_activeTeamsCount', 'Currently operational', Colors.green, Icons.check_circle, cardBg)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _buildMetricCard('Inactive Teams', '$_inactiveTeamsCount', 'Deactivated teams', Colors.orange, Icons.pause_circle, cardBg)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildMetricCard('Total Members', '$_totalMembersCount', 'Assigned employees', Colors.purple, Icons.people, cardBg)),
                ],
              ),
              const SizedBox(height: 16),

              // Search & Department Filter Bar
              Row(
                children: [
                  Expanded(
                    child: GlassSearchBar(
                      placeholder: 'Search team, department or lead...',
                      onChanged: (val) => setState(() => _searchTerm = val),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white, visualDensity: VisualDensity.compact),
                    icon: const Icon(Icons.group_add, size: 16),
                    label: const Text('New Team'),
                    onPressed: () async {
                      await Navigator.push(context, MaterialPageRoute(builder: (_) => const HrTeamFormScreen()));
                      _loadData();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(10)),
                child: DropdownButton<String>(
                  value: _departmentFilter,
                  underline: const SizedBox.shrink(),
                  isExpanded: true,
                  items: [
                    const DropdownMenuItem(value: 'All Departments', child: Text('All Departments', style: TextStyle(fontSize: 12))),
                    ..._departments.map((d) => DropdownMenuItem(
                          value: d['name']?.toString() ?? 'Department',
                          child: Text(d['name']?.toString() ?? 'Department', style: const TextStyle(fontSize: 12)),
                        )),
                  ],
                  onChanged: (val) => setState(() => _departmentFilter = val ?? 'All Departments'),
                ),
              ),
              const SizedBox(height: 16),

              // Teams List Cards
              filtered.isEmpty
                  ? const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('No teams found.')))
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final t = filtered[index] as Map<String, dynamic>;
                        final id = t['id']?.toString() ?? '';
                        final name = t['name'] ?? 'Team';
                        final dept = t['departmentName'] ?? t['department'] ?? 'General';
                        final lead = t['teamLeadName'] ?? 'Unassigned';
                        final memberCount = t['memberCount'] ?? 0;
                        final projectsCount = t['activeProjectsCount'] ?? 0;
                        final isActive = _isTeamActive(t['status']);

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 1,
                          color: cardBg,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () async {
                              await Navigator.push(context, MaterialPageRoute(builder: (_) => HrTeamDetailScreen(teamId: id)));
                              _loadData();
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: primaryColor.withAlpha(30),
                                        child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'T', style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                            Text('$dept • Lead: $lead', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                                          ],
                                        ),
                                      ),
                                      Chip(
                                        label: Text(isActive ? 'Active' : 'Inactive', style: const TextStyle(fontSize: 10, color: Colors.white)),
                                        backgroundColor: isActive ? Colors.green : Colors.grey,
                                        visualDensity: VisualDensity.compact,
                                      ),
                                    ],
                                  ),
                                  if (t['description'] != null && t['description'].toString().isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text(t['description'].toString(), style: TextStyle(fontSize: 12, color: Colors.grey[700]), maxLines: 2, overflow: TextOverflow.ellipsis),
                                  ],
                                  const SizedBox(height: 8),
                                  Text('Members: $memberCount • Active Projects: $projectsCount', style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12)),
                                  const Divider(height: 16),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      OutlinedButton.icon(
                                        icon: const Icon(Icons.visibility, size: 14),
                                        label: const Text('View Details', style: TextStyle(fontSize: 12)),
                                        style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                                        onPressed: () async {
                                          await Navigator.push(context, MaterialPageRoute(builder: (_) => HrTeamDetailScreen(teamId: id)));
                                          _loadData();
                                        },
                                      ),
                                      const SizedBox(width: 8),
                                      OutlinedButton.icon(
                                        icon: const Icon(Icons.person_add, size: 14),
                                        label: const Text('Assign', style: TextStyle(fontSize: 12)),
                                        style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                                        onPressed: () => _openAssignModal(t),
                                      ),
                                      const SizedBox(width: 8),
                                      OutlinedButton.icon(
                                        icon: const Icon(Icons.edit, size: 14),
                                        label: const Text('Edit', style: TextStyle(fontSize: 12)),
                                        style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                                        onPressed: () async {
                                          await Navigator.push(context, MaterialPageRoute(builder: (_) => HrTeamFormScreen(teamId: id, initialData: t)));
                                          _loadData();
                                        },
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        icon: const Icon(Icons.block, size: 18, color: Colors.red),
                                        tooltip: 'Deactivate Team',
                                        onPressed: () => _deactivateTeam(t),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ],
          ),
        ),

        // Assign Employees Modal
        if (_showAssignModal && _selectedTeamForAssign != null)
          Container(
            color: Colors.black54,
            alignment: Alignment.center,
            padding: const EdgeInsets.all(20),
            child: Material(
              borderRadius: BorderRadius.circular(16),
              color: cardBg,
              child: SizedBox(
                width: double.infinity,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  constraints: const BoxConstraints(maxWidth: 550, maxHeight: 600),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Assign Employees — ${_selectedTeamForAssign!['name']}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          if (!_isAssigning)
                            IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _showAssignModal = false)),
                        ],
                      ),
                      const Divider(),
                      TextField(
                        decoration: const InputDecoration(hintText: 'Search employees by name, dept, designation, role...', prefixIcon: Icon(Icons.search), isDense: true, border: OutlineInputBorder()),
                        onChanged: (val) => setState(() => _assignSearchTerm = val),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: _assignFilteredEmployees.isEmpty
                            ? const Center(child: Text('No employees found.'))
                            : ListView.builder(
                                itemCount: _assignFilteredEmployees.length,
                                itemBuilder: (context, idx) {
                                  final emp = _assignFilteredEmployees[idx] as Map<String, dynamic>;
                                  final empId = emp['id']?.toString() ?? emp['employeeId']?.toString() ?? '';
                                  final firstName = emp['firstName'] ?? '';
                                  final lastName = emp['lastName'] ?? '';
                                  final name = '$firstName $lastName'.trim().isNotEmpty ? '$firstName $lastName' : (emp['fullName'] ?? emp['name'] ?? 'Employee');
                                  final dept = emp['department'] ?? '—';
                                  final desig = emp['designation'] ?? '—';
                                  final role = emp['role'] ?? 'Employee';
                                  final isSelected = _selectedEmployeeIdsForAssign.contains(empId);

                                  return CheckboxListTile(
                                    value: isSelected,
                                    onChanged: _isAssigning ? null : (_) {
                                      setState(() {
                                        if (isSelected) {
                                          _selectedEmployeeIdsForAssign.remove(empId);
                                        } else {
                                          _selectedEmployeeIdsForAssign.add(empId);
                                        }
                                      });
                                    },
                                    title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    subtitle: Text('$dept • $desig ($role)', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                                    dense: true,
                                  );
                                },
                              ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(onPressed: _isAssigning ? null : () => setState(() => _showAssignModal = false), child: const Text('Cancel')),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white),
                            onPressed: _isAssigning ? null : _saveAssignedEmployees,
                            child: Text(_isAssigning ? 'Assigning...' : 'Confirm Assignment (${_selectedEmployeeIdsForAssign.length})'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );

    if (!widget.showAppBar) return Material(color: Colors.transparent, child: bodyContent);

    return GlassScaffold(
      appBar: GlassHeader(
        title: 'Teams Management',
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      body: bodyContent,
    );
  }

  Widget _buildMetricCard(String label, String value, String subtext, Color color, IconData icon, Color cardBg) {
    return AppCard(
      backgroundColor: cardBg,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(color: color.withAlpha(30), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600], fontWeight: FontWeight.bold)),
                  Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
                  Text(subtext, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
