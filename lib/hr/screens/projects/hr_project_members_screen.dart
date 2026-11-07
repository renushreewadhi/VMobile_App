import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/glass_header.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../core/widgets/glass_search_bar.dart';
import '../../../shared/widgets/app_card.dart';

class HrProjectMembersScreen extends ConsumerStatefulWidget {
  final String projectId;

  const HrProjectMembersScreen({super.key, required this.projectId});

  @override
  ConsumerState<HrProjectMembersScreen> createState() => _HrProjectMembersScreenState();
}

class _HrProjectMembersScreenState extends ConsumerState<HrProjectMembersScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  String? _candidateErrorMessage;
  Map<String, dynamic>? _project;
  List<dynamic> _members = [];
  List<dynamic> _candidates = [];

  final Set<String> _selectedCandidateIds = {};
  final Set<String> _deletingMemberIds = {};
  String _candidateSearch = '';
  String _memberSearch = '';
  bool _showAddModal = false;
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

    _loadProjectAndMembers();
    _loadCandidates();
  }

  void _resetState() {
    setState(() {
      _project = null;
      _members = [];
      _candidates = [];
      _errorMessage = null;
      _candidateErrorMessage = null;
      _isLoading = true;
      _selectedCandidateIds.clear();
      _deletingMemberIds.clear();
      _showAddModal = false;
      _isAssigning = false;
    });
  }

  Future<void> _loadProjectAndMembers() async {
    final currentReq = ++_requestId;
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final apiClient = ref.read(apiClientProvider);
    try {
      final projRes = await apiClient.get('/projects/${widget.projectId}');
      final memRes = await apiClient.get('/projects/${widget.projectId}/members');

      if (!mounted || currentReq != _requestId) return;

      setState(() {
        _project = projRes is Map<String, dynamic> ? (projRes['data'] ?? projRes) : null;
        _members = memRes is List ? memRes : (memRes is Map ? (memRes['items'] ?? memRes['data'] ?? []) : []);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted || currentReq != _requestId) return;
      setState(() {
        _errorMessage = 'Failed to load project members: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadCandidates() async {
    final currentReq = _requestId;
    if (!mounted) return;
    setState(() {
      _candidateErrorMessage = null;
    });

    final apiClient = ref.read(apiClientProvider);
    try {
      final candRes = await apiClient.get('/projects/${widget.projectId}/candidates');
      if (!mounted || currentReq != _requestId) return;

      List<dynamic> candidates = [];
      if (candRes is List) {
        candidates = candRes;
      } else if (candRes is Map<String, dynamic>) {
        candidates = candRes['items'] ?? candRes['data'] ?? [];
      }

      setState(() {
        _candidates = candidates;
        _candidateErrorMessage = null;
        // Reconcile selected IDs to ensure they still exist in candidates list
        final validIds = _candidates.map((c) => c['id']?.toString() ?? c['employeeId']?.toString() ?? '').toSet();
        _selectedCandidateIds.retainWhere((id) => validIds.contains(id));
      });
    } catch (e) {
      if (!mounted || currentReq != _requestId) return;
      setState(() {
        _candidateErrorMessage = 'Failed to load available candidates: $e';
      });
    }
  }

  List<dynamic> get _filteredCandidates {
    if (_candidateSearch.trim().isEmpty) return _candidates;
    return _candidates.where((c) {
      final name = (c['name'] ?? c['fullName'] ?? '').toString().toLowerCase();
      final desig = (c['designation'] ?? '').toString().toLowerCase();
      final dept = (c['department'] ?? '').toString().toLowerCase();
      final team = (c['teamName'] ?? c['team'] ?? '').toString().toLowerCase();
      final q = _candidateSearch.trim().toLowerCase();
      return name.contains(q) || desig.contains(q) || dept.contains(q) || team.contains(q);
    }).toList();
  }

  List<dynamic> get _filteredMembers {
    if (_memberSearch.trim().isEmpty) return _members;
    return _members.where((m) {
      final name = (m['employeeName'] ?? m['name'] ?? '').toString().toLowerCase();
      final desig = (m['designation'] ?? '').toString().toLowerCase();
      final team = (m['teamName'] ?? m['team'] ?? '').toString().toLowerCase();
      final q = _memberSearch.trim().toLowerCase();
      return name.contains(q) || desig.contains(q) || team.contains(q);
    }).toList();
  }

  void _toggleSelectAllFiltered() {
    final filtered = _filteredCandidates;
    final filteredIds = filtered.map((c) => c['id']?.toString() ?? c['employeeId']?.toString() ?? '').where((id) => id.isNotEmpty).toSet();

    final allSelected = filteredIds.isNotEmpty && filteredIds.every((id) => _selectedCandidateIds.contains(id));
    setState(() {
      if (allSelected) {
        for (final id in filteredIds) {
          _selectedCandidateIds.remove(id);
        }
      } else {
        for (final id in filteredIds) {
          _selectedCandidateIds.add(id);
        }
      }
    });
  }

  Future<void> _assignSelectedMembers() async {
    final ids = _selectedCandidateIds.toList();
    if (ids.isEmpty || _isAssigning) return;

    setState(() => _isAssigning = true);
    final apiClient = ref.read(apiClientProvider);

    try {
      final res = await apiClient.post('/projects/${widget.projectId}/members', body: {
        'employeeIds': ids,
      });

      List<dynamic> updatedMembers = [];
      if (res is List) {
        updatedMembers = res;
      } else if (res is Map<String, dynamic>) {
        updatedMembers = res['items'] ?? res['data'] ?? [];
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Members assigned successfully')));
        setState(() {
          _members = updatedMembers.isNotEmpty ? updatedMembers : _members;
          _selectedCandidateIds.clear();
          _showAddModal = false;
          _isAssigning = false;
        });
        _loadProjectAndMembers();
        _loadCandidates();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isAssigning = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to assign members: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _removeMember(String employeeId, String name) async {
    if (_deletingMemberIds.contains(employeeId)) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Removal'),
        content: Text('Are you sure you want to remove $name from this project?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remove', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _deletingMemberIds.add(employeeId));
    final apiClient = ref.read(apiClientProvider);

    try {
      final res = await apiClient.delete('/projects/${widget.projectId}/members/$employeeId');
      List<dynamic> updatedMembers = [];
      if (res is List) {
        updatedMembers = res;
      } else if (res is Map<String, dynamic>) {
        updatedMembers = res['items'] ?? res['data'] ?? [];
      }

      if (mounted) {
        setState(() => _deletingMemberIds.remove(employeeId));
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Removed $name from project')));
        setState(() {
          _members = updatedMembers.isNotEmpty ? updatedMembers : _members.where((m) => (m['employeeId']?.toString() ?? '') != employeeId).toList();
        });
        _loadProjectAndMembers();
        _loadCandidates();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _deletingMemberIds.remove(employeeId));
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to remove member: $e'), backgroundColor: Colors.red));
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
      return GlassScaffold(appBar: const GlassHeader(title: 'Project Members'), body: const Center(child: CircularProgressIndicator()));
    }

    if (_errorMessage != null || _project == null) {
      return GlassScaffold(
        appBar: const GlassHeader(title: 'Project Members'),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline_rounded, size: 54, color: Colors.red),
                const SizedBox(height: 16),
                const Text('Unable to Load Project', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(_errorMessage ?? 'Project details could not be retrieved.', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                const SizedBox(height: 24),
                ElevatedButton.icon(onPressed: _loadProjectAndMembers, icon: const Icon(Icons.refresh), label: const Text('Retry')),
              ],
            ),
          ),
        ),
      );
    }

    final p = _project!;
    final pName = p['name'] ?? '—';
    final pCode = p['projectCode'] ?? '—';
    final pStatus = p['status'] ?? 'IN_PROGRESS';
    final pPriority = p['priority'] ?? 'MEDIUM';
    final pDept = p['departmentName'] ?? p['department'] ?? '—';
    final pTl = p['teamLeadName'] ?? 'Unassigned';
    final pStart = p['startDate'] != null ? p['startDate'].toString().substring(0, 10) : '—';

    final cardBg = Theme.of(context).cardColor;
    final primaryColor = Theme.of(context).primaryColor;

    final filteredCandidates = _filteredCandidates;
    final filteredMembers = _filteredMembers;

    return GlassScaffold(
      appBar: GlassHeader(
        title: 'Project Members',
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            tooltip: 'Add Members',
            onPressed: () => setState(() => _showAddModal = true),
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: () {
            _loadProjectAndMembers();
            _loadCandidates();
          }),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Project Overview Card
                Card(
                  elevation: 1,
                  color: cardBg,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(child: Text(pName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                            Chip(
                              label: Text(pStatus, style: const TextStyle(fontSize: 10, color: Colors.white)),
                              backgroundColor: pStatus == 'COMPLETED' ? Colors.green : Colors.blue,
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ),
                        Text('Code: $pCode', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Department: $pDept', style: const TextStyle(fontSize: 12)),
                            Text('Priority: $pPriority', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Team Lead: $pTl', style: const TextStyle(fontSize: 12)),
                            Text('Start Date: $pStart', style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                        const Divider(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Assigned Members (${_members.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.add, size: 14),
                              label: const Text('Add Members', style: TextStyle(fontSize: 12)),
                              style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white, visualDensity: VisualDensity.compact),
                              onPressed: () => setState(() => _showAddModal = true),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Search Members
                GlassSearchBar(
                  placeholder: 'Search assigned members...',
                  onChanged: (val) => setState(() => _memberSearch = val),
                ),
                const SizedBox(height: 12),

                // Members List
                filteredMembers.isEmpty
                    ? const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('No project members found.')))
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filteredMembers.length,
                        itemBuilder: (context, index) {
                          final m = filteredMembers[index] as Map<String, dynamic>;
                          final empId = m['employeeId']?.toString() ?? '';
                          final name = m['employeeName'] ?? m['name'] ?? 'Member';
                          final desig = m['designation'] ?? '—';
                          final team = m['teamName'] ?? m['team'] ?? '';
                          final isRemoving = _deletingMemberIds.contains(empId);

                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            elevation: 1,
                            color: cardBg,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: primaryColor.withAlpha(30),
                                child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'M', style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
                              ),
                              title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                              subtitle: Text('$empId • $desig${team.isNotEmpty ? ' • $team' : ''}', style: TextStyle(fontSize: 11.5, color: Colors.grey[600])),
                              trailing: isRemoving
                                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                                  : IconButton(
                                      icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                                      onPressed: () => _removeMember(empId, name),
                                    ),
                            ),
                          );
                        },
                      ),
              ],
            ),
          ),
        ),

        // Add Members Modal
        if (_showAddModal)
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
                          const Text('Assign Project Members', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          if (!_isAssigning)
                            IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _showAddModal = false)),
                        ],
                      ),
                      const Divider(),
                      if (_candidateErrorMessage != null)
                        Container(
                          padding: const EdgeInsets.all(8),
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, size: 16, color: Colors.red),
                              const SizedBox(width: 6),
                              Expanded(child: Text(_candidateErrorMessage!, style: const TextStyle(fontSize: 11, color: Colors.red))),
                              TextButton(onPressed: _loadCandidates, child: const Text('Retry Candidates', style: TextStyle(fontSize: 11))),
                            ],
                          ),
                        ),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              decoration: const InputDecoration(hintText: 'Search candidates...', prefixIcon: Icon(Icons.search), isDense: true, border: OutlineInputBorder()),
                              onChanged: (val) => setState(() => _candidateSearch = val),
                            ),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: _toggleSelectAllFiltered,
                            child: Text(
                              filteredCandidates.isNotEmpty && filteredCandidates.every((c) => _selectedCandidateIds.contains(c['id']?.toString() ?? c['employeeId']?.toString())) ? 'Deselect All' : 'Select All',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: filteredCandidates.isEmpty
                            ? const Center(child: Text('No available candidates found.'))
                            : ListView.builder(
                                shrinkWrap: true,
                                itemCount: filteredCandidates.length,
                                itemBuilder: (context, index) {
                                  final c = filteredCandidates[index] as Map<String, dynamic>;
                                  final cId = c['id']?.toString() ?? c['employeeId']?.toString() ?? '';
                                  final cName = c['name'] ?? c['fullName'] ?? 'Candidate';
                                  final cDesig = c['designation'] ?? '';
                                  final cDept = c['department'] ?? '';
                                  final isSelected = _selectedCandidateIds.contains(cId);

                                  return CheckboxListTile(
                                    value: isSelected,
                                    onChanged: _isAssigning ? null : (_) {
                                      setState(() {
                                        if (isSelected) {
                                          _selectedCandidateIds.remove(cId);
                                        } else {
                                          _selectedCandidateIds.add(cId);
                                        }
                                      });
                                    },
                                    title: Text(cName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    subtitle: Text('$cDesig${cDept.isNotEmpty ? ' • $cDept' : ''}', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                                    dense: true,
                                  );
                                },
                              ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(onPressed: _isAssigning ? null : () => setState(() => _showAddModal = false), child: const Text('Cancel')),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white),
                            onPressed: _isAssigning ? null : _assignSelectedMembers,
                            child: Text(_isAssigning ? 'Assigning...' : 'Assign Selected (${_selectedCandidateIds.length})'),
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
  }
}
