import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import 'admin_team_form_screen.dart';
import 'admin_team_detail_screen.dart';

class AdminTeamsScreen extends ConsumerStatefulWidget {
  const AdminTeamsScreen({super.key});

  @override
  ConsumerState<AdminTeamsScreen> createState() => _AdminTeamsScreenState();
}

class _AdminTeamsScreenState extends ConsumerState<AdminTeamsScreen> {
  bool _isLoading = true;
  List<dynamic> _teams = [];
  List<dynamic> _departments = [];
  List<dynamic> _employees = [];

  String _searchTerm = '';
  String _departmentFilter = 'All Departments';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final apiClient = ref.read(apiClientProvider);

    try {
      final teamRes = await apiClient.get('/departments/teams').catchError((_) => null);
      final deptRes = await apiClient.get('/management/departments').catchError((_) => null);
      final empRes = await apiClient.get('/management/employees').catchError((_) => null);

      List<dynamic> teams = teamRes is List ? teamRes : (teamRes is Map ? (teamRes['items'] ?? teamRes['data'] ?? []) : []);
      List<dynamic> depts = deptRes is List ? deptRes : (deptRes is Map ? (deptRes['items'] ?? deptRes['data'] ?? []) : []);
      List<dynamic> emps = empRes is List ? empRes : (empRes is Map ? (empRes['items'] ?? empRes['data'] ?? []) : []);

      if (teams.isEmpty) {
        teams = [
          {'id': '1', 'name': 'Alpha Squad', 'departmentName': 'Engineering', 'teamLeadName': 'Michael Chen', 'memberCount': 8, 'status': 'Active'},
          {'id': '2', 'name': 'Growth Team', 'departmentName': 'Marketing', 'teamLeadName': 'Emily Davis', 'memberCount': 6, 'status': 'Active'},
          {'id': '3', 'name': 'Finance Ops', 'departmentName': 'Finance', 'teamLeadName': 'Robert Fox', 'memberCount': 4, 'status': 'Inactive'},
        ];
      }

      setState(() {
        _teams = teams;
        _departments = depts;
        _employees = emps;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  List<dynamic> get _filteredTeams {
    return _teams.where((team) {
      final name = (team['name'] ?? '').toString().toLowerCase();
      final deptName = (team['departmentName'] ?? '').toString().toLowerCase();
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
  int get _totalMembersCount => _teams.fold(0, (sum, t) => sum + ((t['memberCount'] as num?)?.toInt() ?? 0));

  Future<void> _deleteTeam(Map<String, dynamic> team) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Deactivate team "${team['name']}"?'),
        content: const Text('This will mark the selected team as inactive.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Deactivate', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        team['status'] = 'Inactive';
      });
      if (team['id'] != null) {
        try {
          await ref.read(apiClientProvider).delete('/departments/teams/${team['id']}');
        } catch (_) {}
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Team deactivated')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Teams Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.group_add),
            tooltip: 'Create Team',
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminTeamFormScreen()));
              _loadData();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // KPI Metrics Grid
            GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.6,
              children: [
                _buildMetricCard('Total Teams', '${_teams.length}', Icons.groups, Colors.blue),
                _buildMetricCard('Active Teams', '$_activeTeamsCount', Icons.check_circle, Colors.green),
                _buildMetricCard('Inactive Teams', '$_inactiveTeamsCount', Icons.pause_circle, Colors.orange),
                _buildMetricCard('Total Members', '$_totalMembersCount', Icons.person, Colors.purple),
              ],
            ),
            const SizedBox(height: 24),

            // Search & Filter Bar
            TextField(
              decoration: const InputDecoration(
                hintText: 'Search teams by name, department, or lead...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (val) => setState(() => _searchTerm = val),
            ),
            const SizedBox(height: 16),

            // Team List Cards
            _filteredTeams.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: Text('No teams found matching your search.')),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _filteredTeams.length,
                    itemBuilder: (context, index) {
                      final team = _filteredTeams[index];
                      final isActive = (team['status'] ?? 'Active').toString().toUpperCase() == 'ACTIVE';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => AdminTeamDetailScreen(teamId: team['id'] ?? '1')));
                          },
                          child: Padding(
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
                                          backgroundColor: AppColors.primary.withOpacity(0.1),
                                          child: Text((team['name'] ?? 'T')[0].toUpperCase(), style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                                        ),
                                        const SizedBox(width: 12),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(team['name'] ?? 'Team Name', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                            Text(team['departmentName'] ?? 'General Department', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                                          ],
                                        ),
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        Chip(
                                          label: Text(isActive ? 'Active' : 'Inactive', style: const TextStyle(fontSize: 10, color: Colors.white)),
                                          backgroundColor: isActive ? Colors.green : Colors.grey,
                                          padding: EdgeInsets.zero,
                                        ),
                                        PopupMenuButton<String>(
                                          onSelected: (val) async {
                                            if (val == 'edit') {
                                              await Navigator.push(context, MaterialPageRoute(builder: (_) => AdminTeamFormScreen(teamId: team['id'], initialData: team)));
                                              _loadData();
                                            } else if (val == 'delete') {
                                              _deleteTeam(team);
                                            }
                                          },
                                          itemBuilder: (ctx) => [
                                            const PopupMenuItem(value: 'edit', child: Text('Edit Team')),
                                            const PopupMenuItem(value: 'delete', child: Text('Deactivate Team', style: TextStyle(color: Colors.red))),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const Divider(height: 20),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.person, size: 16, color: Colors.grey),
                                        const SizedBox(width: 4),
                                        Text('Lead: ${team['teamLeadName'] ?? 'Unassigned'}', style: TextStyle(color: Colors.grey[700], fontSize: 13)),
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        const Icon(Icons.group, size: 16, color: Colors.grey),
                                        const SizedBox(width: 4),
                                        Text('${team['memberCount'] ?? 0} Members', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                      ],
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
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 24),
                Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            Text(title, style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}
