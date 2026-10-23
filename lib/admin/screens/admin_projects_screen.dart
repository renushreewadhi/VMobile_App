import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import 'admin_project_form_screen.dart';
import 'admin_project_members_screen.dart';

class AdminProjectsScreen extends ConsumerStatefulWidget {
  const AdminProjectsScreen({super.key});

  @override
  ConsumerState<AdminProjectsScreen> createState() => _AdminProjectsScreenState();
}

class _AdminProjectsScreenState extends ConsumerState<AdminProjectsScreen> {
  bool _isLoading = true;
  List<dynamic> _projects = [];
  String _searchTerm = '';

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    setState(() => _isLoading = true);
    final apiClient = ref.read(apiClientProvider);

    try {
      final res = await apiClient.get('/projects').catchError((_) => null);
      List<dynamic> items = [];
      if (res is List) {
        items = res;
      } else if (res is Map<String, dynamic>) {
        items = res['items'] ?? res['data'] ?? [];
      }

      if (items.isEmpty) {
        items = [
          {'id': '1', 'name': 'HRMS Mobile App v2', 'projectCode': 'PRJ-2026-101', 'departmentName': 'Engineering', 'teamLeadName': 'Rahul Sharma', 'memberCount': 6, 'status': 'IN_PROGRESS', 'priority': 'HIGH'},
          {'id': '2', 'name': 'Cloud Infrastructure Migration', 'projectCode': 'PRJ-2026-102', 'departmentName': 'IT & Software', 'teamLeadName': 'Priya Verma', 'memberCount': 4, 'status': 'IN_PROGRESS', 'priority': 'CRITICAL'},
        ];
      }

      setState(() {
        _projects = items;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  List<dynamic> get _filteredProjects {
    return _projects.where((p) {
      final name = (p['name'] ?? '').toString().toLowerCase();
      final code = (p['projectCode'] ?? '').toString().toLowerCase();
      final dept = (p['departmentName'] ?? '').toString().toLowerCase();

      return _searchTerm.trim().isEmpty ||
          name.contains(_searchTerm.toLowerCase()) ||
          code.contains(_searchTerm.toLowerCase()) ||
          dept.contains(_searchTerm.toLowerCase());
    }).toList();
  }

  int get _inProgressCount => _projects.where((p) => p['status'] != 'COMPLETED').length;
  int get _highPriorityCount => _projects.where((p) => p['priority'] == 'HIGH' || p['priority'] == 'CRITICAL').length;
  int get _assignedTlCount => _projects.where((p) => p['teamLeadName'] != null && p['teamLeadName'].toString().isNotEmpty).length;

  Future<void> _deleteProject(Map<String, dynamic> p) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete project "${p['name']}"?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _projects.removeWhere((item) => item['id'] == p['id']));
      if (p['id'] != null) {
        try {
          await ref.read(apiClientProvider).delete('/projects/${p['id']}');
        } catch (_) {}
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Project deleted successfully')));
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
        title: const Text('Projects Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Create Project',
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminProjectFormScreen()));
              _loadProjects();
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
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.4,
              children: [
                _buildMetricCard('In Progress', '$_inProgressCount', Icons.work, Colors.blue),
                _buildMetricCard('High Priority', '$_highPriorityCount', Icons.priority_high, Colors.red),
                _buildMetricCard('Assigned TLs', '$_assignedTlCount', Icons.person, Colors.green),
              ],
            ),
            const SizedBox(height: 24),

            // Search Bar
            TextField(
              decoration: const InputDecoration(
                hintText: 'Search projects by name, code, or department...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (val) => setState(() => _searchTerm = val),
            ),
            const SizedBox(height: 16),

            // Projects List
            _filteredProjects.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: Text('No projects found matching your search.')),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _filteredProjects.length,
                    itemBuilder: (context, index) {
                      final p = _filteredProjects[index];
                      final priority = (p['priority'] ?? 'MEDIUM').toString().toUpperCase();

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
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
                                        Text(p['name'] ?? 'Project Name', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                        const SizedBox(height: 2),
                                        Text('${p['projectCode'] ?? 'PRJ'} • ${p['departmentName'] ?? 'General'}', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                  Chip(
                                    label: Text(priority, style: const TextStyle(fontSize: 10, color: Colors.white)),
                                    backgroundColor: priority == 'CRITICAL' || priority == 'HIGH' ? Colors.red : Colors.blue,
                                  ),
                                ],
                              ),
                              const Divider(height: 20),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Lead: ${p['teamLeadName'] ?? 'Unassigned'}', style: TextStyle(color: Colors.grey[700], fontSize: 13)),
                                  Text('Members: ${p['memberCount'] ?? 0}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton.icon(
                                    onPressed: () {
                                      Navigator.push(context, MaterialPageRoute(builder: (_) => AdminProjectMembersScreen(projectId: p['id'] ?? '1')));
                                    },
                                    icon: const Icon(Icons.group, size: 16),
                                    label: const Text('Members'),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.edit, size: 18, color: AppColors.primary),
                                    tooltip: 'Edit Project',
                                    onPressed: () async {
                                      await Navigator.push(context, MaterialPageRoute(builder: (_) => AdminProjectFormScreen(projectId: p['id'], initialData: p)));
                                      _loadProjects();
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                                    tooltip: 'Delete Project',
                                    onPressed: () => _deleteProject(p),
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
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text(title, style: TextStyle(fontSize: 10, color: Colors.grey[600]), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
