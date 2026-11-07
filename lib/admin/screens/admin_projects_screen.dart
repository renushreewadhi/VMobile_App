import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/auth/auth_service.dart';
import '../../core/errors/api_exception.dart';
import '../../core/models/user_model.dart';
import '../../core/theme/glass_theme.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/glass_header.dart';
import 'admin_project_form_screen.dart';
import 'admin_project_members_screen.dart';

/// Strongly typed Project Model
class ProjectModel {
  final String id;
  final String name;
  final String projectCode;
  final String departmentName;
  final String? description;
  final String? teamLeadId;
  final String? teamLeadName;
  final int memberCount;
  final String status; // IN_PROGRESS, COMPLETED, ON_HOLD
  final String priority; // LOW, MEDIUM, HIGH, CRITICAL
  final String? startDate;
  final String? endDate;
  final int reportsCount;

  ProjectModel({
    required this.id,
    required this.name,
    required this.projectCode,
    required this.departmentName,
    this.description,
    this.teamLeadId,
    this.teamLeadName,
    required this.memberCount,
    required this.status,
    required this.priority,
    this.startDate,
    this.endDate,
    required this.reportsCount,
  });

  factory ProjectModel.fromJson(Map<String, dynamic> json) {
    String tlName = json['teamLeadName']?.toString() ?? '';
    if (tlName.isEmpty && json['teamLead'] is Map<String, dynamic>) {
      final tl = json['teamLead'] as Map<String, dynamic>;
      tlName = '${tl['firstName'] ?? ''} ${tl['lastName'] ?? ''}'.trim();
    }

    final countRaw = json['memberCount'] ?? json['membersCount'] ?? 0;
    final countInt = countRaw is int ? countRaw : (int.tryParse(countRaw.toString()) ?? 0);

    final repRaw = json['reportsCount'] ?? json['reports'] ?? 0;
    final repInt = repRaw is int ? repRaw : (int.tryParse(repRaw.toString()) ?? 0);

    return ProjectModel(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      name: json['name']?.toString() ?? json['projectName']?.toString() ?? 'Project',
      projectCode: json['projectCode']?.toString() ?? json['code']?.toString() ?? 'PRJ-000',
      departmentName: json['departmentName']?.toString() ?? json['department']?.toString() ?? 'General',
      description: json['description']?.toString(),
      teamLeadId: json['teamLeadId']?.toString() ?? json['teamLead']?['id']?.toString(),
      teamLeadName: tlName.isNotEmpty ? tlName : null,
      memberCount: countInt,
      status: (json['status']?.toString() ?? 'IN_PROGRESS').toUpperCase(),
      priority: (json['priority']?.toString() ?? 'MEDIUM').toUpperCase(),
      startDate: json['startDate']?.toString(),
      endDate: json['endDate']?.toString(),
      reportsCount: repInt,
    );
  }
}

class AdminProjectsScreen extends ConsumerStatefulWidget {
  const AdminProjectsScreen({super.key});

  @override
  ConsumerState<AdminProjectsScreen> createState() => _AdminProjectsScreenState();
}

class _AdminProjectsScreenState extends ConsumerState<AdminProjectsScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<ProjectModel> _projects = [];
  String _searchTerm = '';

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

    _loadProjects();
  }

  void _resetState() {
    _projects = [];
    _searchTerm = '';
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
      final res = await apiClient.get(ApiEndpoints.projects);
      if (!mounted || currentReq != _requestId) return;

      dynamic rawData = res;
      if (res is Map<String, dynamic> && res.containsKey('data')) {
        rawData = res['data'];
      } else if (res is Map<String, dynamic> && res.containsKey('items')) {
        rawData = res['items'];
      }

      if (rawData is! List) {
        if (!mounted || currentReq != _requestId) return;
        setState(() {
          _errorMessage = 'Invalid response format received from server.';
          _isLoading = false;
        });
        return;
      }

      List<ProjectModel> items = [];
      for (final item in rawData) {
        if (item is Map<String, dynamic>) {
          try {
            items.add(ProjectModel.fromJson(item));
          } catch (e) {
            debugPrint('[AdminProjects] Skipped invalid project item: $e');
          }
        }
      }

      if (!mounted || currentReq != _requestId) return;
      setState(() {
        _projects = items;
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
        _errorMessage = 'Failed to load projects list. Please check network connection.';
        _isLoading = false;
      });
    }
  }

  List<ProjectModel> get _filteredProjects {
    return _projects.where((p) {
      final name = p.name.toLowerCase();
      final code = p.projectCode.toLowerCase();
      final dept = p.departmentName.toLowerCase();

      return _searchTerm.trim().isEmpty ||
          name.contains(_searchTerm.toLowerCase()) ||
          code.contains(_searchTerm.toLowerCase()) ||
          dept.contains(_searchTerm.toLowerCase());
    }).toList();
  }

  int get _totalProjectsCount => _projects.length;
  int get _inProgressCount => _projects.where((p) => p.status != 'COMPLETED').length;
  int get _highPriorityCount => _projects.where((p) => p.priority == 'HIGH' || p.priority == 'CRITICAL').length;
  int get _assignedTlCount => _projects.where((p) => p.teamLeadName != null && p.teamLeadName!.trim().isNotEmpty).length;

  Future<void> _deleteProject(ProjectModel project) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete project "${project.name}"?'),
        content: const Text('This action will permanently delete the project record.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final currentReq = ++_requestId;
    final apiClient = ref.read(apiClientProvider);

    try {
      await apiClient.delete(ApiEndpoints.projectDetail(project.id));
      if (!mounted || currentReq != _requestId) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Project deleted successfully')),
      );
      _loadProjects();
    } catch (e) {
      if (!mounted || currentReq != _requestId) return;
      final msg = e is ApiException ? e.message : 'Failed to delete project.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red),
      );
    }
  }

  void _assignTeamLeadDialog(ProjectModel project) async {
    final apiClient = ref.read(apiClientProvider);
    List<Map<String, String>> teamLeads = [];
    bool isModalLoading = true;
    String? selectedTlId = project.teamLeadId;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          if (isModalLoading) {
            apiClient.get(ApiEndpoints.teamLeads).then((res) {
              List<Map<String, String>> tls = [];
              dynamic rawData = res is Map<String, dynamic> && res.containsKey('data') ? res['data'] : res;
              if (rawData is List) {
                for (final item in rawData) {
                  if (item is Map<String, dynamic>) {
                    final id = (item['id'] ?? item['employeeId'])?.toString() ?? '';
                    final name = (item['fullName'] ?? '${item['firstName'] ?? ''} ${item['lastName'] ?? ''}').toString().trim();
                    if (id.isNotEmpty) tls.add({'id': id, 'name': name.isNotEmpty ? name : 'Team Lead'});
                  }
                }
              }
              if (ctx.mounted) {
                setModalState(() {
                  teamLeads = tls;
                  isModalLoading = false;
                });
              }
            }).catchError((_) {
              if (ctx.mounted) setModalState(() => isModalLoading = false);
            });
          }

          return AlertDialog(
            title: Text('Assign Team Lead: ${project.name}'),
            content: isModalLoading
                ? const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()))
                : DropdownButtonFormField<String>(
                    value: selectedTlId,
                    hint: const Text('Select Team Lead'),
                    items: [
                      const DropdownMenuItem(value: '', child: Text('-- Unassign Team Lead --')),
                      ...teamLeads.map((tl) => DropdownMenuItem(value: tl['id'], child: Text(tl['name']!))),
                    ],
                    onChanged: (val) => setModalState(() => selectedTlId = val),
                  ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: isModalLoading
                    ? null
                    : () async {
                        try {
                          await apiClient.post(ApiEndpoints.projectTeamLead(project.id), body: {
                            'teamLeadId': (selectedTlId == null || selectedTlId!.isEmpty) ? null : selectedTlId,
                          });
                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Team Lead assignment updated successfully')),
                            );
                            _loadProjects();
                          }
                        } catch (e) {
                          if (ctx.mounted) {
                            final msg = e is ApiException ? e.message : 'Failed to assign Team Lead.';
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
                          }
                        }
                      },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _openEditProject(ProjectModel p) async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AdminProjectFormScreen(
          projectId: p.id,
          initialData: {
            'id': p.id,
            'name': p.name,
            'projectCode': p.projectCode,
            'departmentName': p.departmentName,
            'priority': p.priority,
            'description': p.description,
          },
        ),
      ),
    );
    if (updated == true) _loadProjects();
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
        title: 'Projects',
        actions: [
          if (isAuthorized)
            IconButton(
              icon: const Icon(Icons.add_circle_outline_rounded),
              tooltip: 'Add Project',
              onPressed: () async {
                final created = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminProjectFormScreen()),
                );
                if (created == true) _loadProjects();
              },
            ),
        ],
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
                      Text('You do not have administrative permissions to view company projects.', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: glass.textSecondary)),
                    ],
                  ),
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadProjects,
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
              Text('Unable to Load Projects', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: glass.textPrimary)),
              const SizedBox(height: 8),
              Text(_errorMessage!, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: glass.textSecondary)),
              const SizedBox(height: 24),
              AppButton(label: 'Retry', icon: Icons.refresh_rounded, width: 140, onPressed: _loadProjects),
            ],
          ),
        ),
      );
    }

    final filtered = _filteredProjects;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 4 Summary KPI Metric Cards (Matching Angular Spec)
          Row(
            children: [
              Expanded(child: _buildStatTile(glass, cardBgColor, label: 'Total Projects', value: '$_totalProjectsCount', icon: Icons.folder_outlined, iconColor: const Color(0xFF2563EB))),
              const SizedBox(width: 8),
              Expanded(child: _buildStatTile(glass, cardBgColor, label: 'In Progress', value: '$_inProgressCount', icon: Icons.work_outline_rounded, iconColor: const Color(0xFF0284C7))),
              const SizedBox(width: 8),
              Expanded(child: _buildStatTile(glass, cardBgColor, label: 'High Priority', value: '$_highPriorityCount', icon: Icons.priority_high_rounded, iconColor: const Color(0xFFEF4444))),
              const SizedBox(width: 8),
              Expanded(child: _buildStatTile(glass, cardBgColor, label: 'Assigned TLs', value: '$_assignedTlCount', icon: Icons.person_pin_rounded, iconColor: const Color(0xFF10B981))),
            ],
          ),
          const SizedBox(height: 16),

          // Search Input Bar
          TextField(
            decoration: InputDecoration(
              hintText: 'Search projects by name, code, or department...',
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
          const SizedBox(height: 16),

          // Projects List Feed
          if (filtered.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 16),
              alignment: Alignment.center,
              child: Column(
                children: [
                  Icon(Icons.folder_off_outlined, size: 56, color: glass.textSecondary.withAlpha(128)),
                  const SizedBox(height: 16),
                  Text('No Projects Found', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: glass.textPrimary)),
                  const SizedBox(height: 8),
                  Text('There are no project records matching your search query.', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: glass.textSecondary)),
                ],
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final p = filtered[index];
                return _buildProjectCard(glass, cardBgColor, p);
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

  Widget _buildProjectCard(GlassTheme glass, Color cardBgColor, ProjectModel p) {
    final isHigh = p.priority == 'HIGH' || p.priority == 'CRITICAL';

    return AppCard(
      backgroundColor: cardBgColor,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      child: InkWell(
        onTap: () => _openEditProject(p),
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
                      Text(p.name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: glass.textPrimary)),
                      const SizedBox(height: 2),
                      Text('${p.projectCode} • ${p.departmentName}', style: TextStyle(color: glass.textSecondary, fontSize: 12)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isHigh ? const Color(0xFFEF4444).withAlpha(30) : const Color(0xFF2563EB).withAlpha(30),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    p.priority,
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isHigh ? const Color(0xFFEF4444) : const Color(0xFF2563EB)),
                  ),
                ),
              ],
            ),
            if (p.description != null && p.description!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(p.description!, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: glass.textSecondary)),
            ],
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Team Lead: ${p.teamLeadName ?? 'Unassigned'}', style: TextStyle(fontSize: 12, color: glass.textSecondary)),
                Text('Members: ${p.memberCount}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: glass.textPrimary)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {}, // Stop event propagation
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.person_pin_outlined, size: 16),
                    label: const Text('Assign TL', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                    onPressed: () => _assignTeamLeadDialog(p),
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {}, // Stop event propagation
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.groups_outlined, size: 16),
                    label: const Text('Members', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => AdminProjectMembersScreen(projectId: p.id)),
                      );
                      _loadProjects();
                    },
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {}, // Stop event propagation
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Edit', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                    onPressed: () => _openEditProject(p),
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {}, // Stop event propagation
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                    label: const Text('Delete', style: TextStyle(fontSize: 12, color: Colors.red)),
                    style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                    onPressed: () => _deleteProject(p),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
