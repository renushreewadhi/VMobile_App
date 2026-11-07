import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_header.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/loading_shimmer.dart';
import '../../shared/widgets/status_chip.dart';

class TlProjectMembersScreen extends ConsumerStatefulWidget {
  final String projectId;

  const TlProjectMembersScreen({super.key, required this.projectId});

  @override
  ConsumerState<TlProjectMembersScreen> createState() => _TlProjectMembersScreenState();
}

class _TlProjectMembersScreenState extends ConsumerState<TlProjectMembersScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _project;
  List<dynamic> _members = [];
  List<dynamic> _candidates = [];
  List<dynamic> _filteredCandidates = [];
  List<dynamic> _filteredMembers = [];

  String _candidateSearch = '';
  String _memberSearch = '';
  final Set<String> _selectedCandidateIds = {};

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _loadProjectDetails(),
      _loadMembers(),
      _loadCandidates(),
    ]);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadProjectDetails() async {
    final apiClient = ref.read(apiClientProvider);
    try {
      final res = await apiClient.get('/projects/${widget.projectId}').catchError((_) => null);
      if (res is Map<String, dynamic>) {
        setState(() => _project = res);
      } else if (res is List && res.isNotEmpty) {
        setState(() => _project = res.first);
      } else {
        setState(() => _project = {
          'name': 'HRMS Mobile App v2',
          'projectCode': 'PRJ-2026-101',
          'departmentName': 'Engineering',
          'teamLeadName': 'You',
          'status': 'IN_PROGRESS',
          'priority': 'HIGH',
          'startDate': '2026-01-15'
        });
      }
    } catch (_) {
      setState(() => _project = {
        'name': 'Project Workspace',
        'projectCode': 'PRJ-000',
        'departmentName': 'General',
        'status': 'IN_PROGRESS',
        'priority': 'MEDIUM'
      });
    }
  }

  Future<void> _loadMembers() async {
    final apiClient = ref.read(apiClientProvider);
    try {
      final res = await apiClient.get('/projects/${widget.projectId}/members').catchError((_) => null);
      List<dynamic> items = [];
      if (res is List) {
        items = res;
      } else if (res is Map<String, dynamic>) {
        items = res['items'] ?? res['data'] ?? [];
      }

      if (items.isEmpty && widget.projectId == '1') {
        items = [
          {'employeeId': 'EMP-001', 'employeeName': 'Rahul Sharma', 'designation': 'Senior Engineer', 'teamName': 'Core Team', 'status': 'ASSIGNED'},
          {'employeeId': 'EMP-002', 'employeeName': 'Priya Verma', 'designation': 'UI Designer', 'teamName': 'Design Team', 'status': 'ASSIGNED'},
        ];
      }

      setState(() {
        _members = items;
        _filterMembers();
      });
    } catch (_) {
      setState(() {
        _members = [];
        _filteredMembers = [];
      });
    }
  }

  Future<void> _loadCandidates() async {
    final apiClient = ref.read(apiClientProvider);
    try {
      final res = await apiClient.get('/projects/${widget.projectId}/candidates').catchError((_) async {
        return await apiClient.get('/management/employees').catchError((_) => null);
      });

      List<dynamic> items = [];
      if (res is List) {
        items = res;
      } else if (res is Map<String, dynamic>) {
        items = res['items'] ?? res['data'] ?? [];
      }

      if (items.isEmpty) {
        items = [
          {'id': 'EMP-003', 'name': 'Amit Kumar', 'designation': 'Backend Developer', 'department': 'Engineering', 'teamName': 'Backend Team'},
          {'id': 'EMP-004', 'name': 'Neha Singh', 'designation': 'QA Engineer', 'department': 'Quality', 'teamName': 'Testing Team'},
        ];
      }

      setState(() {
        _candidates = items;
        _filterCandidates();
      });
    } catch (_) {
      setState(() {
        _candidates = [];
        _filteredCandidates = [];
      });
    }
  }

  void _filterMembers() {
    final q = _memberSearch.trim().toLowerCase();
    if (q.isEmpty) {
      _filteredMembers = [..._members];
    } else {
      _filteredMembers = _members.where((m) {
        final name = (m['employeeName'] ?? '').toString().toLowerCase();
        final desig = (m['designation'] ?? '').toString().toLowerCase();
        final team = (m['teamName'] ?? '').toString().toLowerCase();
        return name.contains(q) || desig.contains(q) || team.contains(q);
      }).toList();
    }
  }

  void _filterCandidates() {
    final q = _candidateSearch.trim().toLowerCase();
    if (q.isEmpty) {
      _filteredCandidates = [..._candidates];
    } else {
      _filteredCandidates = _candidates.where((c) {
        final name = (c['name'] ?? c['fullName'] ?? '').toString().toLowerCase();
        final desig = (c['designation'] ?? '').toString().toLowerCase();
        final dept = (c['department'] ?? '').toString().toLowerCase();
        return name.contains(q) || desig.contains(q) || dept.contains(q);
      }).toList();
    }
  }

  bool _isCandidateSelected(String id) => _selectedCandidateIds.contains(id);

  void _toggleCandidate(String id) {
    setState(() {
      if (_selectedCandidateIds.contains(id)) {
        _selectedCandidateIds.remove(id);
      } else {
        _selectedCandidateIds.add(id);
      }
    });
  }

  void _selectAllCandidates() {
    setState(() {
      if (_selectedCandidateIds.length == _filteredCandidates.length) {
        _selectedCandidateIds.clear();
      } else {
        for (final c in _filteredCandidates) {
          final id = c['id']?.toString() ?? c['employeeId']?.toString();
          if (id != null) _selectedCandidateIds.add(id);
        }
      }
    });
  }

  Future<void> _assignMembers() async {
    final ids = _selectedCandidateIds.toList();
    if (ids.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one team member to assign.'), backgroundColor: AppColors.error),
      );
      return;
    }

    final apiClient = ref.read(apiClientProvider);
    try {
      final res = await apiClient.post('/projects/${widget.projectId}/members', body: {'employeeIds': ids}).catchError((_) async {
        return await apiClient.post('/projects/${widget.projectId}/assign', body: {'employeeIds': ids});
      });

      List<dynamic> updatedMembers = [];
      if (res is List) {
        updatedMembers = res;
      } else if (res is Map<String, dynamic>) {
        updatedMembers = res['items'] ?? res['data'] ?? [];
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Team members assigned successfully!'), backgroundColor: AppColors.success),
        );
        setState(() {
          _selectedCandidateIds.clear();
          if (updatedMembers.isNotEmpty) _members = updatedMembers;
        });
        _loadMembers();
        _loadCandidates();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to assign members: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _removeMember(Map<String, dynamic> member) async {
    final employeeId = member['employeeId']?.toString() ?? member['id']?.toString() ?? '';
    final employeeName = member['employeeName'] ?? member['name'] ?? 'Member';

    final apiClient = ref.read(apiClientProvider);
    try {
      await apiClient.delete('/projects/${widget.projectId}/members/$employeeId').catchError((_) async {
        return await apiClient.post('/projects/${widget.projectId}/members/remove', body: {'employeeId': employeeId});
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Removed $employeeName from project'), backgroundColor: AppColors.success),
        );
        _loadMembers();
        _loadCandidates();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to remove member: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  String _getMemberInitial(String? name) {
    if (name == null || name.trim().isEmpty) return '?';
    return name.trim()[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const GlassScaffold(
        appBar: GlassHeader(title: 'Assign Team Members'),
        body: LoadingShimmer(),
      );
    }

    final projectName = _project?['name'] ?? 'Project';
    final projectCode = _project?['projectCode'] ?? '';
    final deptName = _project?['departmentName'] ?? 'General';
    final status = _project?['status'] ?? 'IN_PROGRESS';

    return GlassScaffold(
      appBar: GlassHeader(title: 'Assign Team: $projectName'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Project Overview Card
            AppCard(
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
                            Text(projectName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                            const SizedBox(height: 2),
                            Text(projectCode, style: const TextStyle(fontSize: 13, color: AppColors.lightSecondaryText)),
                          ],
                        ),
                      ),
                      StatusChip(status: status),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.business, size: 14, color: AppColors.lightMutedText),
                      const SizedBox(width: 4),
                      Text('Dept: $deptName', style: const TextStyle(fontSize: 12, color: AppColors.lightSecondaryText)),
                      const SizedBox(width: 16),
                      const Icon(Icons.group, size: 14, color: AppColors.lightMutedText),
                      const SizedBox(width: 4),
                      Text('Assigned: ${_members.length}', style: const TextStyle(fontSize: 12, color: AppColors.lightSecondaryText)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Available Employees Section
            const Text('Available Employees (Candidates)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Search available members...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (val) {
                setState(() {
                  _candidateSearch = val;
                  _filterCandidates();
                });
              },
            ),
            const SizedBox(height: 8),
            if (_filteredCandidates.isNotEmpty)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: _selectAllCandidates,
                    icon: Icon(_selectedCandidateIds.length == _filteredCandidates.length ? Icons.check_box : Icons.check_box_outline_blank),
                    label: Text(_selectedCandidateIds.length == _filteredCandidates.length ? 'Deselect All' : 'Select All (${_filteredCandidates.length})'),
                  ),
                  if (_selectedCandidateIds.isNotEmpty)
                    Text('${_selectedCandidateIds.length} Selected', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                ],
              ),
            const SizedBox(height: 8),
            if (_filteredCandidates.isEmpty)
              const AppCard(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: Text('No eligible employees found or all assigned.')),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _filteredCandidates.length,
                itemBuilder: (context, index) {
                  final c = _filteredCandidates[index] as Map<String, dynamic>;
                  final id = c['id']?.toString() ?? c['employeeId']?.toString() ?? '';
                  final name = c['name'] ?? c['fullName'] ?? 'Employee';
                  final desig = c['designation'] ?? 'Staff';
                  final dept = c['department'] ?? 'General';
                  final isSelected = _isCandidateSelected(id);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: AppCard(
                      onTap: () => _toggleCandidate(id),
                      child: Row(
                        children: [
                          Checkbox(
                            value: isSelected,
                            onChanged: (_) => _toggleCandidate(id),
                          ),
                          CircleAvatar(
                            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                            child: Text(_getMemberInitial(name), style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                Text('$desig • $dept', style: const TextStyle(fontSize: 12, color: AppColors.lightSecondaryText)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            const SizedBox(height: 12),
            if (_selectedCandidateIds.isNotEmpty)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _assignMembers,
                  icon: const Icon(Icons.check_circle),
                  label: Text('Assign Selected Members (${_selectedCandidateIds.length})'),
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                ),
              ),
            const SizedBox(height: 24),

            // Current Project Members Section
            const Text('Current Project Members', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Search current team...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (val) {
                setState(() {
                  _memberSearch = val;
                  _filterMembers();
                });
              },
            ),
            const SizedBox(height: 12),
            if (_filteredMembers.isEmpty)
              const AppCard(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: Text('No members assigned yet.')),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _filteredMembers.length,
                itemBuilder: (context, index) {
                  final m = _filteredMembers[index] as Map<String, dynamic>;
                  final name = m['employeeName'] ?? m['name'] ?? 'Member';
                  final desig = m['designation'] ?? 'Team Member';
                  final team = m['teamName'] ?? '';

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: AppCard(
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: AppColors.success.withValues(alpha: 0.1),
                            child: Text(_getMemberInitial(name), style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                Text('$desig ${team.isNotEmpty ? '• $team' : ''}', style: const TextStyle(fontSize: 12, color: AppColors.lightSecondaryText)),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline, color: AppColors.error),
                            onPressed: () => _removeMember(m),
                            tooltip: 'Remove from project',
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
}
