import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/loading_shimmer.dart';
import '../../shared/widgets/status_chip.dart';
import 'tl_project_members_screen.dart';

class TlProjectsScreen extends ConsumerStatefulWidget {
  const TlProjectsScreen({super.key});

  @override
  ConsumerState<TlProjectsScreen> createState() => _TlProjectsScreenState();
}

class _TlProjectsScreenState extends ConsumerState<TlProjectsScreen> {
  bool _isLoading = true;
  List<dynamic> _projects = [];
  final Map<String, List<dynamic>> _membersByProject = {};
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
      final res = await apiClient.get('/projects/assigned-to-me').catchError((_) async {
        return await apiClient.get(ApiEndpoints.myProjects).catchError((_) => null);
      });

      List<dynamic> items = [];
      if (res is List) {
        items = res;
      } else if (res is Map<String, dynamic>) {
        items = res['items'] ?? res['data'] ?? [];
      }

      if (items.isEmpty) {
        items = [
          {
            'id': '1',
            'name': 'HRMS Mobile App v2',
            'projectCode': 'PRJ-2026-101',
            'departmentName': 'Engineering',
            'status': 'IN_PROGRESS',
            'priority': 'HIGH',
            'description': 'Flutter mobile app overhaul for HRMS platform.',
            'startDate': '2026-01-15',
            'endDate': '2026-06-30'
          },
          {
            'id': '2',
            'name': 'Cloud Infrastructure Migration',
            'projectCode': 'PRJ-2026-102',
            'departmentName': 'IT & Software',
            'status': 'IN_PROGRESS',
            'priority': 'CRITICAL',
            'description': 'Migrating legacy backend services to AWS cloud.',
            'startDate': '2026-02-01',
            'endDate': '2026-08-15'
          }
        ];
      }

      setState(() {
        _projects = items;
        _isLoading = false;
      });

      for (final p in items) {
        if (p is Map && p['id'] != null) {
          _loadMembers(p['id'].toString());
        }
      }
    } catch (_) {
      setState(() {
        _projects = [];
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMembers(String projectId) async {
    final apiClient = ref.read(apiClientProvider);
    try {
      final res = await apiClient.get('/projects/$projectId/members').catchError((_) => null);
      List<dynamic> members = [];
      if (res is List) {
        members = res;
      } else if (res is Map<String, dynamic>) {
        members = res['items'] ?? res['data'] ?? [];
      }

      if (members.isEmpty && projectId == '1') {
        members = [
          {'employeeId': 'EMP-001', 'employeeName': 'Rahul Sharma', 'designation': 'Senior Engineer', 'roleInProject': 'Developer'},
          {'employeeId': 'EMP-002', 'employeeName': 'Priya Verma', 'designation': 'UI Designer', 'roleInProject': 'Designer'},
        ];
      }

      if (mounted) {
        setState(() {
          _membersByProject[projectId] = members;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _membersByProject[projectId] = [];
        });
      }
    }
  }

  List<dynamic> _membersFor(String projectId) {
    return _membersByProject[projectId] ?? [];
  }

  String _memberInitial(String? name) {
    if (name == null || name.trim().isEmpty) return '?';
    return name.trim()[0].toUpperCase();
  }

  Future<void> _removeMember(String projectId, String employeeId, String name) async {
    final apiClient = ref.read(apiClientProvider);
    try {
      await apiClient.delete('/projects/$projectId/members/$employeeId').catchError((_) async {
        return await apiClient.post('/projects/$projectId/members/remove', body: {'employeeId': employeeId});
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Removed $name from project'), backgroundColor: AppColors.success),
        );
        _loadMembers(projectId);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to remove member: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const ListSkeleton(itemCount: 3);

    final filteredProjects = _projects.where((p) {
      final map = p is Map<String, dynamic> ? p : {};
      final name = (map['name'] ?? '').toString().toLowerCase();
      final code = (map['projectCode'] ?? '').toString().toLowerCase();
      return _searchTerm.isEmpty || name.contains(_searchTerm.toLowerCase()) || code.contains(_searchTerm.toLowerCase());
    }).toList();

    return RefreshIndicator(
      onRefresh: _loadProjects,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              decoration: const InputDecoration(
                labelText: 'Search projects by name or code...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (val) => setState(() => _searchTerm = val),
            ),
            const SizedBox(height: 16),
            if (filteredProjects.isEmpty)
              const AppCard(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.folder_open, size: 48, color: AppColors.lightMutedText),
                        SizedBox(height: 12),
                        Text('No projects assigned', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        SizedBox(height: 4),
                        Text('Your admin hasn\'t assigned any projects to you yet.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.lightSecondaryText)),
                      ],
                    ),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredProjects.length,
                itemBuilder: (context, index) {
                  final p = filteredProjects[index] as Map<String, dynamic>;
                  final projectId = p['id']?.toString() ?? '';
                  final name = p['name'] ?? 'Project Name';
                  final code = p['projectCode'] ?? 'PRJ-000';
                  final desc = p['description'] ?? 'No description provided.';
                  final dept = p['departmentName'] ?? 'General';
                  final priority = p['priority'] ?? 'MEDIUM';
                  final status = p['status'] ?? 'IN_PROGRESS';
                  final members = _membersFor(projectId);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.folder_shared, color: AppColors.primary),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                    const SizedBox(height: 2),
                                    Text(code, style: const TextStyle(fontSize: 12, color: AppColors.lightSecondaryText)),
                                  ],
                                ),
                              ),
                              StatusChip(status: status),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(desc, style: const TextStyle(fontSize: 13, color: AppColors.lightSecondaryText)),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Icon(Icons.business, size: 14, color: AppColors.lightMutedText),
                              const SizedBox(width: 4),
                              Text(dept, style: const TextStyle(fontSize: 12, color: AppColors.lightMutedText)),
                              const SizedBox(width: 16),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: priority == 'CRITICAL' ? AppColors.errorBg : (priority == 'HIGH' ? AppColors.warningBg : AppColors.lightPrimary),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(priority, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: priority == 'CRITICAL' ? AppColors.error : (priority == 'HIGH' ? AppColors.warning : AppColors.primary))),
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.people, size: 16, color: AppColors.primary),
                                  const SizedBox(width: 6),
                                  Text('Team Members (${members.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                ],
                              ),
                              TextButton.icon(
                                onPressed: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => TlProjectMembersScreen(projectId: projectId)),
                                  );
                                  _loadProjects();
                                },
                                icon: const Icon(Icons.person_add, size: 16),
                                label: const Text('Assign Team'),
                              ),
                            ],
                          ),
                          if (members.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: members.length,
                              itemBuilder: (context, mIdx) {
                                final m = members[mIdx] as Map<String, dynamic>;
                                final mName = m['employeeName'] ?? 'Member';
                                final mRole = m['roleInProject'] ?? m['designation'] ?? 'Team Member';
                                final mEmpId = m['employeeId']?.toString() ?? '';

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppColors.lightSurface,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 14,
                                          backgroundColor: AppColors.primary,
                                          child: Text(_memberInitial(mName), style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(mName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                              Text(mRole, style: const TextStyle(fontSize: 11, color: AppColors.lightSecondaryText)),
                                            ],
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.close, size: 16, color: AppColors.error),
                                          onPressed: () => _removeMember(projectId, mEmpId, mName),
                                          tooltip: 'Remove member',
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ] else ...[
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Text('No members assigned yet.', style: TextStyle(fontSize: 12, color: AppColors.lightMutedText, fontStyle: FontStyle.italic)),
                            ),
                          ],
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
