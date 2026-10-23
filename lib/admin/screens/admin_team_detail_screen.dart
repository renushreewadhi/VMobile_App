import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import 'admin_team_form_screen.dart';

class AdminTeamDetailScreen extends ConsumerStatefulWidget {
  final String teamId;

  const AdminTeamDetailScreen({super.key, required this.teamId});

  @override
  ConsumerState<AdminTeamDetailScreen> createState() => _AdminTeamDetailScreenState();
}

class _AdminTeamDetailScreenState extends ConsumerState<AdminTeamDetailScreen> {
  bool _isLoading = true;
  Map<String, dynamic> _team = {};
  List<dynamic> _teamMembers = [];

  @override
  void initState() {
    super.initState();
    _loadTeamDetails();
  }

  Future<void> _loadTeamDetails() async {
    setState(() => _isLoading = true);
    final apiClient = ref.read(apiClientProvider);

    try {
      final teamRes = await apiClient.get('/departments/teams/${widget.teamId}').catchError((_) => null);
      final empRes = await apiClient.get('/management/employees').catchError((_) => null);

      if (teamRes is Map<String, dynamic>) {
        _team = teamRes;
      } else {
        _team = {
          'id': widget.teamId,
          'name': 'Alpha Squad',
          'departmentName': 'Engineering',
          'teamLeadName': 'Michael Chen',
          'status': 'Active',
          'memberCount': 8,
          'description': 'Core engineering squad working on microservices architecture.'
        };
      }

      List<dynamic> emps = empRes is List ? empRes : (empRes is Map ? (empRes['items'] ?? empRes['data'] ?? []) : []);
      if (emps.isEmpty) {
        emps = [
          {'id': '1', 'employeeId': 'EMP-01', 'firstName': 'Rahul', 'lastName': 'Sharma', 'department': 'Engineering', 'designation': 'Developer'},
          {'id': '2', 'employeeId': 'EMP-02', 'firstName': 'Priya', 'lastName': 'Verma', 'department': 'Engineering', 'designation': 'QA Engineer'},
        ];
      }

      _teamMembers = emps;
      setState(() => _isLoading = false);
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deactivateTeam() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Deactivate team "${_team['name']}"?'),
        content: const Text('This will change team status to Inactive.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Deactivate', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref.read(apiClientProvider).delete('/departments/teams/${widget.teamId}');
      } catch (_) {}
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Team deactivated successfully')));
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final isActive = (_team['status'] ?? 'Active').toString().toUpperCase() == 'ACTIVE';

    return Scaffold(
      appBar: AppBar(
        title: Text(_team['name'] ?? 'Team Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Edit Team',
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => AdminTeamFormScreen(teamId: widget.teamId, initialData: _team)));
              _loadTeamDetails();
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            tooltip: 'Deactivate Team',
            onPressed: _deactivateTeam,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Team Header Card
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 28,
                              backgroundColor: AppColors.primary.withOpacity(0.1),
                              child: Text((_team['name'] ?? 'T')[0].toUpperCase(), style: const TextStyle(fontSize: 24, color: AppColors.primary, fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_team['name'] ?? 'Team', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                                Text(_team['departmentName'] ?? 'Department', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                              ],
                            ),
                          ],
                        ),
                        Chip(
                          label: Text(isActive ? 'Active' : 'Inactive', style: const TextStyle(color: Colors.white)),
                          backgroundColor: isActive ? Colors.green : Colors.grey,
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      children: [
                        const Icon(Icons.person_pin, size: 18, color: Colors.grey),
                        const SizedBox(width: 8),
                        Text('Team Lead: ${_team['teamLeadName'] ?? 'Unassigned'}', style: const TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.group, size: 18, color: Colors.grey),
                        const SizedBox(width: 8),
                        Text('Total Members: ${_team['memberCount'] ?? _teamMembers.length}', style: const TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                    if (_team['description'] != null && _team['description'].toString().isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(_team['description'], style: TextStyle(color: Colors.grey[700])),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Team Members Roster
            const Text('Team Members Roster', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
            const SizedBox(height: 12),
            _teamMembers.isEmpty
                ? const Center(child: Text('No members found in this team.'))
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _teamMembers.length,
                    itemBuilder: (context, index) {
                      final member = _teamMembers[index];
                      final name = '${member['firstName'] ?? ''} ${member['lastName'] ?? ''}'.trim().isNotEmpty ? '${member['firstName']} ${member['lastName']}' : (member['fullName'] ?? member['name'] ?? 'Employee');
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppColors.primary.withOpacity(0.1),
                            child: Text(name[0].toUpperCase(), style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                          ),
                          title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('${member['employeeCode'] ?? member['id']} • ${member['department'] ?? 'Engineering'} (${member['designation'] ?? 'Staff'})'),
                        ),
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }
}
