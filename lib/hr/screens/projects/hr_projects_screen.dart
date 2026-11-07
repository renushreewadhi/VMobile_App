import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/glass_header.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../core/widgets/glass_search_bar.dart';
import '../../../shared/widgets/app_card.dart';
import 'hr_project_form_screen.dart';
import 'hr_project_members_screen.dart';

class HrProjectsScreen extends ConsumerStatefulWidget {
  final bool showAppBar;
  const HrProjectsScreen({super.key, this.showAppBar = true});

  @override
  ConsumerState<HrProjectsScreen> createState() => _HrProjectsScreenState();
}

class _HrProjectsScreenState extends ConsumerState<HrProjectsScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  String? _tlErrorMessage;
  bool _isLoadingTls = false;
  List<dynamic> _projects = [];
  List<dynamic> _teamLeads = [];
  String _searchTerm = '';

  // Assign TL Modal state
  bool _showAssignTlModal = false;
  Map<String, dynamic>? _assignTargetProject;
  String _selectedTeamLeadId = '';
  bool _isAssigningTl = false;
  
  // Deleting state tracking
  final Set<String> _deletingProjectIds = {};

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

    _loadProjects();
    _loadTeamLeads();
  }

  void _resetState() {
    setState(() {
      _projects = [];
      _teamLeads = [];
      _errorMessage = null;
      _tlErrorMessage = null;
      _isLoading = true;
      _showAssignTlModal = false;
      _assignTargetProject = null;
      _selectedTeamLeadId = '';
      _isAssigningTl = false;
      _deletingProjectIds.clear();
    });
  }

  Future<void> _loadProjects() async {
    final currentReq = ++_requestId;
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final apiClient = ref.read(apiClientProvider);
    try {
      final res = await apiClient.get('/projects');
      if (!mounted || currentReq != _requestId) return;

      List<dynamic> projects = [];
      if (res is List) {
        projects = res;
      } else if (res is Map<String, dynamic>) {
        projects = res['items'] ?? res['data'] ?? [];
      }

      setState(() {
        _projects = projects;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted || currentReq != _requestId) return;
      setState(() {
        _errorMessage = 'Failed to load projects: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadTeamLeads() async {
    final currentReq = _requestId;
    if (!mounted) return;
    setState(() {
      _isLoadingTls = true;
      _tlErrorMessage = null;
    });

    final apiClient = ref.read(apiClientProvider);
    try {
      final tlRes = await apiClient.get('/projects/team-leads');
      if (!mounted || currentReq != _requestId) return;

      List<dynamic> teamLeads = [];
      if (tlRes is List) {
        teamLeads = tlRes;
      } else if (tlRes is Map<String, dynamic>) {
        teamLeads = tlRes['items'] ?? tlRes['data'] ?? [];
      }

      setState(() {
        _teamLeads = teamLeads;
        _isLoadingTls = false;
        _tlErrorMessage = null;
      });
    } catch (e) {
      if (!mounted || currentReq != _requestId) return;
      setState(() {
        _tlErrorMessage = 'Failed to load team leads: $e';
        _isLoadingTls = false;
      });
    }
  }

  Future<void> _saveAssignTeamLead() async {
    if (_assignTargetProject == null || _isAssigningTl) return;
    final projectId = _assignTargetProject!['id']?.toString() ?? '';
    if (projectId.isEmpty) return;

    setState(() => _isAssigningTl = true);
    final apiClient = ref.read(apiClientProvider);

    try {
      await apiClient.post('/projects/$projectId/assign-team-lead', body: {
        'teamLeadId': _selectedTeamLeadId.isEmpty ? null : _selectedTeamLeadId,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Team Lead assignment updated successfully')));
        setState(() {
          _showAssignTlModal = false;
          _assignTargetProject = null;
          _isAssigningTl = false;
        });
        _loadProjects();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isAssigningTl = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to assign team lead: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _deleteProject(String projectId, String projectName) async {
    if (_deletingProjectIds.contains(projectId)) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: Text('Are you sure you want to delete project "$projectName"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _deletingProjectIds.add(projectId));
    final apiClient = ref.read(apiClientProvider);

    try {
      await apiClient.delete('/projects/$projectId');
      if (mounted) {
        setState(() => _deletingProjectIds.remove(projectId));
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Project deleted successfully')));
        _loadProjects();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _deletingProjectIds.remove(projectId));
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete project: $e'), backgroundColor: Colors.red));
      }
    }
  }

  int get _inProgressCount => _projects.where((p) => (p['status'] ?? '').toString().toUpperCase() == 'IN_PROGRESS').length;
  int get _highPriorityCount => _projects.where((p) => ['HIGH', 'CRITICAL'].contains((p['priority'] ?? '').toString().toUpperCase())).length;
  int get _assignedTlCount => _projects.where((p) => p['teamLeadId'] != null || p['teamLeadName'] != null).length;

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
      return GlassScaffold(title: 'Projects Management', body: skeleton);
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
              const Text('Unable to Load Projects', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(_errorMessage!, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
              const SizedBox(height: 24),
              ElevatedButton.icon(onPressed: _loadProjects, icon: const Icon(Icons.refresh), label: const Text('Retry')),
            ],
          ),
        ),
      );
      if (!widget.showAppBar) return Material(color: Colors.transparent, child: errBody);
      return GlassScaffold(title: 'Projects Management', body: errBody);
    }

    final filtered = _projects.where((p) {
      final map = p is Map<String, dynamic> ? p : {};
      final name = (map['name'] ?? '').toString().toLowerCase();
      final code = (map['projectCode'] ?? '').toString().toLowerCase();
      final dept = (map['departmentName'] ?? map['department'] ?? '').toString().toLowerCase();
      final tl = (map['teamLeadName'] ?? '').toString().toLowerCase();

      return _searchTerm.isEmpty ||
          name.contains(_searchTerm.toLowerCase()) ||
          code.contains(_searchTerm.toLowerCase()) ||
          dept.contains(_searchTerm.toLowerCase()) ||
          tl.contains(_searchTerm.toLowerCase());
    }).toList();

    final cardBg = Theme.of(context).cardColor;
    final primaryColor = Theme.of(context).primaryColor;

    final bodyContent = Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // KPI Metric Cards
              Row(
                children: [
                  Expanded(child: _buildMetricCard('Total Projects', '${_projects.length}', 'Active portfolios', Colors.blue, Icons.folder, cardBg)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildMetricCard('In Progress', '$_inProgressCount', 'Active execution', Colors.orange, Icons.hourglass_top, cardBg)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _buildMetricCard('High Priority', '$_highPriorityCount', 'Urgent scope', Colors.red, Icons.priority_high, cardBg)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildMetricCard('Assigned TLs', '$_assignedTlCount', 'Leadership assigned', Colors.green, Icons.supervisor_account, cardBg)),
                ],
              ),
              const SizedBox(height: 16),

              if (_tlErrorMessage != null)
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.orange.shade200)),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber, size: 18, color: Colors.orange),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_tlErrorMessage!, style: TextStyle(fontSize: 12, color: Colors.orange.shade800))),
                      TextButton(onPressed: _loadTeamLeads, child: const Text('Retry TLs', style: TextStyle(fontSize: 11))),
                    ],
                  ),
                ),

              // Search & Header
              Row(
                children: [
                  Expanded(
                    child: GlassSearchBar(
                      placeholder: 'Search projects by name, code, department, TL...',
                      onChanged: (val) => setState(() => _searchTerm = val),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white, visualDensity: VisualDensity.compact),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('New Project'),
                    onPressed: () async {
                      await Navigator.push(context, MaterialPageRoute(builder: (_) => const HrProjectFormScreen()));
                      _loadProjects();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Projects List
              filtered.isEmpty
                  ? const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('No projects found.')))
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final p = filtered[index] as Map<String, dynamic>;
                        final id = p['id']?.toString() ?? '';
                        final name = p['name'] ?? '—';
                        final code = p['projectCode'] ?? '—';
                        final dept = p['departmentName'] ?? p['department'] ?? '—';
                        final tl = p['teamLeadName'] ?? 'Unassigned';
                        final membersCount = p['memberCount'] ?? 0;
                        final priority = p['priority'] ?? 'MEDIUM';
                        final status = p['status'] ?? 'IN_PROGRESS';
                        final isDeleting = _deletingProjectIds.contains(id);

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 1,
                          color: cardBg,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                                    Chip(
                                      label: Text(status, style: const TextStyle(fontSize: 10, color: Colors.white)),
                                      backgroundColor: status == 'COMPLETED' ? Colors.green : Colors.blue,
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  ],
                                ),
                                Text('$code • $dept • Priority: $priority', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                                const SizedBox(height: 4),
                                Text('Team Lead: $tl • Members: $membersCount', style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12)),
                                const Divider(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    OutlinedButton.icon(
                                      icon: const Icon(Icons.supervisor_account, size: 14),
                                      label: const Text('Assign TL', style: TextStyle(fontSize: 12)),
                                      style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                                      onPressed: _isLoadingTls ? null : () => setState(() {
                                        _assignTargetProject = p;
                                        _selectedTeamLeadId = p['teamLeadId']?.toString() ?? '';
                                        _showAssignTlModal = true;
                                      }),
                                    ),
                                    const SizedBox(width: 8),
                                    OutlinedButton.icon(
                                      icon: const Icon(Icons.group, size: 14),
                                      label: const Text('Members', style: TextStyle(fontSize: 12)),
                                      style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                                      onPressed: () async {
                                        await Navigator.push(context, MaterialPageRoute(builder: (_) => HrProjectMembersScreen(projectId: id)));
                                        _loadProjects();
                                      },
                                    ),
                                    const SizedBox(width: 8),
                                    OutlinedButton.icon(
                                      icon: const Icon(Icons.edit, size: 14),
                                      label: const Text('Edit', style: TextStyle(fontSize: 12)),
                                      style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                                      onPressed: () async {
                                        await Navigator.push(context, MaterialPageRoute(builder: (_) => HrProjectFormScreen(projectId: id, initialData: p)));
                                        _loadProjects();
                                      },
                                    ),
                                    const SizedBox(width: 8),
                                    isDeleting
                                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                                        : IconButton(
                                            icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                                            tooltip: 'Delete Project',
                                            onPressed: () => _deleteProject(id, name),
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

        // Assign TL Modal
        if (_showAssignTlModal && _assignTargetProject != null)
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
                  constraints: const BoxConstraints(maxWidth: 450),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Assign Team Lead — ${_assignTargetProject!['name']}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          if (!_isAssigningTl)
                            IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _showAssignTlModal = false)),
                        ],
                      ),
                      const Divider(),
                      const Text('Select Team Lead for this project:'),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _selectedTeamLeadId.isEmpty ? null : _selectedTeamLeadId,
                        hint: const Text('Select Team Lead'),
                        decoration: const InputDecoration(border: OutlineInputBorder()),
                        items: [
                          const DropdownMenuItem(value: '', child: Text('Unassigned / None')),
                          ..._teamLeads.map((tl) => DropdownMenuItem<String>(
                                value: tl['id']?.toString(),
                                child: Text(tl['name']?.toString() ?? tl['fullName'] ?? 'Team Lead'),
                              )),
                        ],
                        onChanged: _isAssigningTl ? null : (val) => setState(() => _selectedTeamLeadId = val ?? ''),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(onPressed: _isAssigningTl ? null : () => setState(() => _showAssignTlModal = false), child: const Text('Cancel')),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white),
                            onPressed: _isAssigningTl ? null : _saveAssignTeamLead,
                            child: Text(_isAssigningTl ? 'Saving...' : 'Save Assignment'),
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
        title: 'Projects Management',
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadProjectsAndTeamLeads),
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
