import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/widgets/glass_header.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../shared/widgets/app_card.dart';
import 'hr_team_form_screen.dart';

class HrTeamDetailScreen extends ConsumerStatefulWidget {
  final String teamId;

  const HrTeamDetailScreen({super.key, required this.teamId});

  @override
  ConsumerState<HrTeamDetailScreen> createState() => _HrTeamDetailScreenState();
}

class _HrTeamDetailScreenState extends ConsumerState<HrTeamDetailScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _team;
  List<dynamic> _teamMembers = [];

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
    }
    _loadTeamDetails();
  }

  Future<void> _loadTeamDetails() async {
    final currentReq = ++_requestId;
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final apiClient = ref.read(apiClientProvider);

    try {
      final teamRes = await apiClient.get(ApiEndpoints.teamDetail(widget.teamId));
      final empRes = await apiClient.get(ApiEndpoints.employees).catchError((_) => apiClient.get('/employees/all'));

      if (!mounted || currentReq != _requestId) return;

      final teamData = teamRes is Map<String, dynamic> ? (teamRes['data'] ?? teamRes) : null;
      List<dynamic> employees = empRes is List ? empRes : (empRes is Map ? (empRes['items'] ?? empRes['data'] ?? []) : []);

      if (teamData != null) {
        final tName = (teamData['name'] ?? '').toString().toLowerCase();
        final targetTeamId = (teamData['id'] ?? '').toString().toLowerCase();

        final members = employees.where((e) {
          if (e is Map<String, dynamic>) {
            final empTeamId = (e['teamId'] ?? e['team']?['id'] ?? '').toString().toLowerCase();
            final empTeamName = (e['teamName'] ?? e['team']?['name'] ?? e['team'] ?? '').toString().toLowerCase();
            
            if (targetTeamId.isNotEmpty && empTeamId == targetTeamId) return true;
            if (empTeamId.isEmpty && tName.isNotEmpty && empTeamName == tName) return true;
          }
          return false;
        }).toList();

        setState(() {
          _team = teamData;
          _teamMembers = members;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Team details not found.';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted || currentReq != _requestId) return;
      setState(() {
        _errorMessage = 'Failed to load team details: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _deactivateTeam() async {
    if (_team == null) return;
    final teamName = _team!['name']?.toString() ?? 'Team';

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
      await apiClient.delete(ApiEndpoints.teamDetail(widget.teamId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Team deactivated successfully')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to deactivate team: $e'), backgroundColor: Colors.red));
      }
    }
  }

  bool _isTeamActive(dynamic status) {
    if (status == null) return true;
    return status.toString().toUpperCase() == 'ACTIVE';
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authServiceProvider, (previous, next) {
      if (next.user?.id != _currentUserId) {
        _checkUserAndLoad();
      }
    });

    if (_isLoading) {
      return GlassScaffold(
        appBar: const GlassHeader(title: 'Team Details'),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null || _team == null) {
      return GlassScaffold(
        appBar: const GlassHeader(title: 'Team Details'),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline_rounded, size: 54, color: Colors.red),
                const SizedBox(height: 16),
                const Text('Unable to Load Team Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(_errorMessage ?? 'Team details not available.', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                const SizedBox(height: 24),
                ElevatedButton.icon(onPressed: _loadTeamDetails, icon: const Icon(Icons.refresh), label: const Text('Retry')),
              ],
            ),
          ),
        ),
      );
    }

    final t = _team!;
    final name = t['name'] ?? '—';
    final dept = t['departmentName'] ?? t['department'] ?? '—';
    final lead = t['teamLeadName'] ?? 'Unassigned';
    final desc = t['description'] ?? '—';
    final isActive = _isTeamActive(t['status']);
    final projectsCount = t['activeProjectsCount'] ?? 0;
    final backendMemberCount = t['memberCount'] ?? 0;

    final cardBg = Theme.of(context).cardColor;
    final primaryColor = Theme.of(context).primaryColor;

    return GlassScaffold(
      appBar: GlassHeader(
        title: name,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => HrTeamFormScreen(teamId: widget.teamId, initialData: _team)),
              );
              _loadTeamDetails();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero Card
            AppCard(
              backgroundColor: cardBg,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: primaryColor.withAlpha(30),
                        child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'T', style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 20)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                            Text('Department: $dept', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
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
                  const SizedBox(height: 12),
                  Text(desc, style: TextStyle(fontSize: 13, color: Colors.grey[700])),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Metrics Summary
            Row(
              children: [
                Expanded(child: _buildMetricCard('Team Members', '${_teamMembers.isNotEmpty ? _teamMembers.length : backendMemberCount}', 'Assigned employees', Colors.blue, Icons.people, cardBg)),
                const SizedBox(width: 8),
                Expanded(child: _buildMetricCard('Active Projects', '$projectsCount', 'In execution', Colors.green, Icons.folder, cardBg)),
              ],
            ),
            const SizedBox(height: 16),

            // Team Lead Summary Card
            AppCard(
              backgroundColor: cardBg,
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: Colors.purple.withAlpha(30),
                  child: const Icon(Icons.supervisor_account, color: Colors.purple),
                ),
                title: const Text('Team Lead', style: TextStyle(fontSize: 12, color: Colors.grey)),
                subtitle: Text(lead, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ),
            const SizedBox(height: 20),

            // Assigned Team Members List
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Assigned Members (${_teamMembers.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            const SizedBox(height: 12),

            _teamMembers.isEmpty
                ? const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('No employees assigned to this team.')))
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _teamMembers.length,
                    itemBuilder: (context, index) {
                      final m = _teamMembers[index] as Map<String, dynamic>;
                      final firstName = m['firstName'] ?? '';
                      final lastName = m['lastName'] ?? '';
                      final mName = '$firstName $lastName'.trim().isNotEmpty ? '$firstName $lastName' : (m['fullName'] ?? m['name'] ?? 'Employee');
                      final empCode = m['employeeId'] ?? m['id'] ?? '';
                      final email = m['email'] ?? '—';
                      final desig = m['designation'] ?? '—';
                      final role = m['role'] ?? 'Employee';
                      
                      final empActive = m['active'] == true || m['isActive'] == true || (m['status']?.toString().toUpperCase() == 'ACTIVE');

                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        elevation: 1,
                        color: cardBg,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: primaryColor.withAlpha(30),
                            child: Text(mName.isNotEmpty ? mName[0].toUpperCase() : 'E', style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
                          ),
                          title: Text(mName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          subtitle: Text('$empCode • $desig ($role)\n$email'),
                          isThreeLine: true,
                          trailing: Chip(
                            label: Text(empActive ? 'Active' : 'Inactive', style: const TextStyle(fontSize: 10, color: Colors.white)),
                            backgroundColor: empActive ? Colors.green : Colors.grey,
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      );
                    },
                  ),
            const SizedBox(height: 24),

            // Quick Actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('Edit Team'),
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => HrTeamFormScreen(teamId: widget.teamId, initialData: _team)),
                      );
                      _loadTeamDetails();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
                    icon: const Icon(Icons.block, size: 16),
                    label: const Text('Deactivate Team'),
                    onPressed: _deactivateTeam,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
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
