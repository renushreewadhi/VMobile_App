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

class AdminProjectMembersScreen extends ConsumerStatefulWidget {
  final String projectId;

  const AdminProjectMembersScreen({super.key, required this.projectId});

  @override
  ConsumerState<AdminProjectMembersScreen> createState() => _AdminProjectMembersScreenState();
}

class _AdminProjectMembersScreenState extends ConsumerState<AdminProjectMembersScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic> _project = {};
  List<dynamic> _members = [];
  List<dynamic> _candidates = [];

  String _candidateSearch = '';
  String _memberSearch = '';
  final Set<String> _selectedCandidateIds = {};
  bool _isAssigning = false;

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
    _requestId++; // Immediately invalidate pending requests
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

    _loadProjectMembersAndCandidates();
  }

  void _resetState() {
    _project = {};
    _members = [];
    _candidates = [];
    _selectedCandidateIds.clear();
    _candidateSearch = '';
    _memberSearch = '';
    _isAssigning = false;
  }

  Future<void> _loadProjectMembersAndCandidates() async {
    final currentReq = ++_requestId;
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final apiClient = ref.read(apiClientProvider);

    try {
      final projRes = await apiClient.get(ApiEndpoints.projectDetail(widget.projectId)).catchError((_) => null);
      if (!mounted || currentReq != _requestId) return;

      final memRes = await apiClient.get(ApiEndpoints.projectMembers(widget.projectId)).catchError((_) => null);
      if (!mounted || currentReq != _requestId) return;

      final candRes = await apiClient.get(ApiEndpoints.managementEmployees).catchError((_) => apiClient.get('${ApiEndpoints.employeesAll}?limit=500').catchError((_) => apiClient.get(ApiEndpoints.employees).catchError((_) => null)));
      if (!mounted || currentReq != _requestId) return;

      dynamic rawProj = projRes is Map<String, dynamic> && projRes.containsKey('data') ? projRes['data'] : projRes;
      dynamic rawMem = memRes is Map<String, dynamic> && memRes.containsKey('data') ? memRes['data'] : memRes;
      dynamic rawCand = candRes is Map<String, dynamic> && candRes.containsKey('data') ? candRes['data'] : candRes;

      Map<String, dynamic> proj = rawProj is Map<String, dynamic> ? rawProj : {'name': 'Project'};
      List<dynamic> memList = rawMem is List ? rawMem : [];
      List<dynamic> allEmps = rawCand is List ? rawCand : [];

      // Filter candidates: active, not already assigned to project
      final memIds = memList.map((m) => (m['id'] ?? m['employeeId'])?.toString()).toSet();
      final eligibleCandList = allEmps.where((e) {
        if (e is! Map<String, dynamic>) return false;
        final id = (e['id'] ?? e['employeeId'])?.toString();
        return id != null && !memIds.contains(id);
      }).toList();

      if (!mounted || currentReq != _requestId) return;
      setState(() {
        _project = proj;
        _members = memList;
        _candidates = eligibleCandList;
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
        _errorMessage = 'Failed to load project members. Please check network connection.';
        _isLoading = false;
      });
    }
  }

  List<dynamic> get _filteredCandidates {
    if (_candidateSearch.trim().isEmpty) return _candidates;
    final q = _candidateSearch.toLowerCase().trim();
    return _candidates.where((c) {
      final name = (c['fullName'] ?? '${c['firstName'] ?? ''} ${c['lastName'] ?? ''}').toString().toLowerCase();
      final code = (c['employeeCode'] ?? c['employeeId'] ?? '').toString().toLowerCase();
      final dept = (c['department'] ?? '').toString().toLowerCase();
      final desig = (c['designation'] ?? '').toString().toLowerCase();
      final team = (c['teamName'] ?? '').toString().toLowerCase();
      return name.contains(q) || code.contains(q) || dept.contains(q) || desig.contains(q) || team.contains(q);
    }).toList();
  }

  List<dynamic> get _filteredMembers {
    if (_memberSearch.trim().isEmpty) return _members;
    final q = _memberSearch.toLowerCase().trim();
    return _members.where((m) {
      final name = (m['employeeName'] ?? m['fullName'] ?? m['name'] ?? '').toString().toLowerCase();
      final desig = (m['designation'] ?? '').toString().toLowerCase();
      final team = (m['teamName'] ?? '').toString().toLowerCase();
      return name.contains(q) || desig.contains(q) || team.contains(q);
    }).toList();
  }

  bool get _isAllVisibleCandidatesSelected {
    final list = _filteredCandidates;
    if (list.isEmpty) return false;
    return list.every((c) => _selectedCandidateIds.contains((c['id'] ?? c['employeeId'])?.toString()));
  }

  void _toggleSelectAllCandidates(bool? val) {
    setState(() {
      final list = _filteredCandidates;
      if (val == true) {
        for (final c in list) {
          final id = (c['id'] ?? c['employeeId'])?.toString();
          if (id != null) _selectedCandidateIds.add(id);
        }
      } else {
        for (final c in list) {
          final id = (c['id'] ?? c['employeeId'])?.toString();
          if (id != null) _selectedCandidateIds.remove(id);
        }
      }
    });
  }

  Future<void> _assignSelectedMembers() async {
    if (_selectedCandidateIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one candidate.'), backgroundColor: Colors.red),
      );
      return;
    }

    if (_isAssigning) return;
    setState(() => _isAssigning = true);

    final currentReq = ++_requestId;
    final apiClient = ref.read(apiClientProvider);

    try {
      await apiClient.post(ApiEndpoints.projectMembers(widget.projectId), body: {
        'memberIds': _selectedCandidateIds.toList(),
      });

      if (!mounted || currentReq != _requestId) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Assigned ${_selectedCandidateIds.length} member(s) to project')),
      );
      _selectedCandidateIds.clear();
      _isAssigning = false;
      _loadProjectMembersAndCandidates();
    } catch (e) {
      if (!mounted || currentReq != _requestId) return;
      setState(() => _isAssigning = false);
      final msg = e is ApiException ? e.message : 'Failed to assign project members.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _removeMember(Map<String, dynamic> member) async {
    final memberId = (member['employeeId'] ?? member['id'])?.toString();
    final memberName = member['employeeName'] ?? member['fullName'] ?? member['name'] ?? 'Member';

    if (memberId == null || memberId.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove "$memberName" from project?'),
        content: const Text('This will revoke project access for this team member.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final currentReq = ++_requestId;
    final apiClient = ref.read(apiClientProvider);

    try {
      await apiClient.delete(ApiEndpoints.projectMemberDelete(widget.projectId, memberId));
      if (!mounted || currentReq != _requestId) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Member removed from project')),
      );
      _loadProjectMembersAndCandidates();
    } catch (e) {
      if (!mounted || currentReq != _requestId) return;
      final msg = e is ApiException ? e.message : 'Failed to remove member.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red),
      );
    }
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

    final projectName = _project['name']?.toString() ?? _project['projectName']?.toString() ?? 'Project';

    return GlassScaffold(
      appBar: GlassHeader(
        title: 'Project Members: $projectName',
        actions: [
          if (isAuthorized)
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Refresh',
              onPressed: _loadProjectMembersAndCandidates,
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
                      Text('You do not have administrative permissions to view project members.', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: glass.textSecondary)),
                    ],
                  ),
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadProjectMembersAndCandidates,
              child: _buildMainContent(glass, cardBgColor, projectName),
            ),
    );
  }

  Widget _buildMainContent(GlassTheme glass, Color cardBgColor, String projectName) {
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
              Text('Unable to Load Project Members', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: glass.textPrimary)),
              const SizedBox(height: 8),
              Text(_errorMessage!, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: glass.textSecondary)),
              const SizedBox(height: 24),
              AppButton(label: 'Retry', icon: Icons.refresh_rounded, width: 140, onPressed: _loadProjectMembersAndCandidates),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Project Overview Banner Card
          AppCard(
            backgroundColor: cardBgColor,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(projectName, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: glass.textPrimary)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: const Color(0xFF0F6B66).withAlpha(30), borderRadius: BorderRadius.circular(10)),
                      child: Text(_project['status']?.toString().toUpperCase() ?? 'IN_PROGRESS', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F6B66))),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text('Code: ${_project['projectCode'] ?? _project['code'] ?? 'PRJ'} • Dept: ${_project['departmentName'] ?? _project['department'] ?? 'General'}', style: TextStyle(fontSize: 12, color: glass.textSecondary)),
                Text('Team Lead: ${_project['teamLeadName'] ?? 'Unassigned'} • Total Members: ${_members.length}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: glass.textPrimary)),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Two Panels (Candidates & Assigned Members) - Responsive Layout
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 700) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildCandidatesPanel(glass, cardBgColor)),
                    const SizedBox(width: 16),
                    Expanded(child: _buildAssignedMembersPanel(glass, cardBgColor)),
                  ],
                );
              } else {
                return Column(
                  children: [
                    _buildCandidatesPanel(glass, cardBgColor),
                    const SizedBox(height: 16),
                    _buildAssignedMembersPanel(glass, cardBgColor),
                  ],
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCandidatesPanel(GlassTheme glass, Color cardBgColor) {
    final filtered = _filteredCandidates;

    return AppCard(
      backgroundColor: cardBgColor,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Available Candidates (${filtered.length})', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: glass.textPrimary)),
              if (filtered.isNotEmpty)
                Row(
                  children: [
                    Checkbox(
                      value: _isAllVisibleCandidatesSelected,
                      onChanged: _toggleSelectAllCandidates,
                    ),
                    const Text('Select All', style: TextStyle(fontSize: 11)),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            decoration: InputDecoration(
              hintText: 'Search candidates...',
              hintStyle: TextStyle(color: glass.textSecondary, fontSize: 12),
              prefixIcon: Icon(Icons.search_rounded, color: glass.textSecondary, size: 18),
              filled: true,
              fillColor: Colors.grey.withAlpha(20),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            ),
            style: TextStyle(color: glass.textPrimary, fontSize: 12),
            onChanged: (val) => setState(() => _candidateSearch = val),
          ),
          const SizedBox(height: 12),
          if (filtered.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 32),
              alignment: Alignment.center,
              child: Text('No eligible candidates found.', style: TextStyle(fontSize: 13, color: glass.textSecondary)),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final cand = filtered[index];
                final id = (cand['id'] ?? cand['employeeId'])?.toString() ?? '';
                final name = cand['fullName'] ?? '${cand['firstName'] ?? ''} ${cand['lastName'] ?? ''}'.trim();
                final desig = cand['designation'] ?? 'Staff';
                final isSelected = _selectedCandidateIds.contains(id);

                return CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: isSelected,
                  title: Text(name.isNotEmpty ? name : 'Employee', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: glass.textPrimary)),
                  subtitle: Text('${cand['employeeCode'] ?? cand['employeeId'] ?? 'EMP'} • $desig', style: TextStyle(fontSize: 11, color: glass.textSecondary)),
                  onChanged: (val) {
                    setState(() {
                      if (val == true) {
                        _selectedCandidateIds.add(id);
                      } else {
                        _selectedCandidateIds.remove(id);
                      }
                    });
                  },
                );
              },
            ),
          const SizedBox(height: 14),
          AppButton(
            label: _isAssigning ? 'Assigning...' : 'Assign Selected (${_selectedCandidateIds.length})',
            isLoading: _isAssigning,
            onPressed: _selectedCandidateIds.isEmpty || _isAssigning ? null : _assignSelectedMembers,
          ),
        ],
      ),
    );
  }

  Widget _buildAssignedMembersPanel(GlassTheme glass, Color cardBgColor) {
    final filtered = _filteredMembers;

    return AppCard(
      backgroundColor: cardBgColor,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Assigned Members (${filtered.length})', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: glass.textPrimary)),
          const SizedBox(height: 10),
          TextField(
            decoration: InputDecoration(
              hintText: 'Search members...',
              hintStyle: TextStyle(color: glass.textSecondary, fontSize: 12),
              prefixIcon: Icon(Icons.search_rounded, color: glass.textSecondary, size: 18),
              filled: true,
              fillColor: Colors.grey.withAlpha(20),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            ),
            style: TextStyle(color: glass.textPrimary, fontSize: 12),
            onChanged: (val) => setState(() => _memberSearch = val),
          ),
          const SizedBox(height: 12),
          if (filtered.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 32),
              alignment: Alignment.center,
              child: Text('No members assigned yet.', style: TextStyle(fontSize: 13, color: glass.textSecondary)),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final m = filtered[index];
                final name = m['employeeName'] ?? m['fullName'] ?? m['name'] ?? 'Member';
                final desig = m['designation'] ?? 'Staff';

                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    radius: 18,
                    backgroundColor: const Color(0xFF0F6B66).withAlpha(30),
                    child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'M', style: const TextStyle(color: Color(0xFF0F6B66), fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                  title: Text(name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: glass.textPrimary)),
                  subtitle: Text('${m['employeeCode'] ?? m['employeeId'] ?? 'EMP'} • $desig', style: TextStyle(fontSize: 11, color: glass.textSecondary)),
                  trailing: IconButton(
                    icon: const Icon(Icons.remove_circle_outline_rounded, color: Colors.red, size: 20),
                    tooltip: 'Remove Member',
                    onPressed: () => _removeMember(m),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
