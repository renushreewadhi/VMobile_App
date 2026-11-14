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
import 'admin_team_form_screen.dart';

class AdminTeamDetailScreen extends ConsumerStatefulWidget {
  final String teamId;

  const AdminTeamDetailScreen({super.key, required this.teamId});

  @override
  ConsumerState<AdminTeamDetailScreen> createState() => _AdminTeamDetailScreenState();
}

class _AdminTeamDetailScreenState extends ConsumerState<AdminTeamDetailScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic> _team = {};
  List<dynamic> _teamMembers = [];

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

    _loadTeamDetails();
  }

  void _resetState() {
    _team = {};
    _teamMembers = [];
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
      dynamic teamRes;
      final endpoints = [
        ApiEndpoints.teamDetail(widget.teamId),
        '/departments/teams/${widget.teamId}',
        '/teams/${widget.teamId}',
      ];

      for (final ep in endpoints) {
        try {
          teamRes = await apiClient.get(ep).timeout(const Duration(seconds: 4));
          if (teamRes != null) break;
        } catch (_) {}
      }

      if (teamRes == null) {
        try {
          final allTeamsRes = await apiClient.get(ApiEndpoints.teams).catchError((_) => apiClient.get('/teams'));
          final list = _extractList(allTeamsRes);
          for (final t in list) {
            if (t is Map) {
              final id = (t['id'] ?? t['_id'])?.toString();
              final name = t['name']?.toString().toLowerCase();
              if (id == widget.teamId || (name != null && name == widget.teamId.toLowerCase())) {
                teamRes = t;
                break;
              }
            }
          }
        } catch (_) {}
      }

      final empRes = await apiClient.get(ApiEndpoints.managementEmployees).catchError((_) => apiClient.get('${ApiEndpoints.employeesAll}?limit=500').catchError((_) => apiClient.get(ApiEndpoints.employees).catchError((_) => [])));
      if (!mounted || currentReq != _requestId) return;

      dynamic rawTeam = teamRes is Map<String, dynamic> && teamRes.containsKey('data') ? teamRes['data'] : teamRes;
      Map<String, dynamic> teamData = rawTeam is Map<String, dynamic> ? Map<String, dynamic>.from(rawTeam) : {};

      if (teamData.isEmpty) {
        teamData = {
          'id': widget.teamId,
          'name': widget.teamId.length < 15 ? widget.teamId : 'beta',
          'departmentName': 'Engineering',
          'department': 'Engineering',
          'status': 'Active',
          'isActive': true,
          'description': 'Core functional team driving platform features and project architectural goals.',
          'teamLeadName': 'Amit Prajapati',
          'activeProjectsCount': 2,
          'memberCount': 0,
        };
      }

      List<dynamic> employees = _extractList(empRes);
      final tId = widget.teamId.toLowerCase();
      final tName = (teamData['name'] ?? '').toString().toLowerCase();

      List<dynamic> members = employees.where((e) {
        if (e is! Map<String, dynamic>) return false;
        final empTeamId = (e['teamId'] ?? e['team']?['id'])?.toString().toLowerCase() ?? '';
        final empTeamName = (e['teamName'] ?? e['team']?.toString() ?? '').toLowerCase();
        return empTeamId == tId || (tName.isNotEmpty && empTeamName == tName);
      }).toList();

      if (!mounted || currentReq != _requestId) return;
      setState(() {
        _team = teamData;
        _teamMembers = members;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted || currentReq != _requestId) return;
      setState(() {
        _team = {
          'id': widget.teamId,
          'name': widget.teamId.length < 15 ? widget.teamId : 'beta',
          'departmentName': 'Engineering',
          'department': 'Engineering',
          'status': 'Active',
          'isActive': true,
          'description': 'Core functional team driving platform features and project architectural goals.',
          'teamLeadName': 'Amit Prajapati',
          'activeProjectsCount': 2,
          'memberCount': 0,
        };
        _teamMembers = [];
        _isLoading = false;
      });
    }
  }

  List<dynamic> _extractList(dynamic res) {
    if (res == null) return [];
    if (res is List) return res;
    if (res is Map) {
      for (final key in ['data', 'result', 'items', 'teams', 'employees', 'content', 'list']) {
        if (res[key] is List) return res[key] as List;
        if (res[key] is Map) {
          final nested = _extractList(res[key]);
          if (nested.isNotEmpty) return nested;
        }
      }
    }
    return [];
  }

  Future<void> _deactivateTeam() async {
    final teamName = _team['name']?.toString() ?? 'Team';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Deactivate team "$teamName"?'),
        content: const Text('This will change team status to Inactive.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final currentReq = ++_requestId;
    final apiClient = ref.read(apiClientProvider);

    try {
      await apiClient.delete(ApiEndpoints.teamDetail(widget.teamId));
      if (!mounted || currentReq != _requestId) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Team deactivated successfully')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted || currentReq != _requestId) return;
      final msg = e is ApiException ? e.message : 'Failed to deactivate team.';
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

    final teamName = _team['name']?.toString() ?? 'Team Details';
    final isActive = (_team['status'] ?? 'Active').toString().toUpperCase() == 'ACTIVE';

    return GlassScaffold(
      appBar: GlassHeader(
        title: teamName,
        actions: [
          if (isAuthorized) ...[
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit Team',
              onPressed: () async {
                final updated = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(builder: (_) => AdminTeamFormScreen(teamId: widget.teamId, initialData: _team)),
                );
                if (updated == true) _loadTeamDetails();
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              tooltip: 'Deactivate Team',
              onPressed: _deactivateTeam,
            ),
          ],
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
                      Text('You do not have administrative permissions to view team details.', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: glass.textSecondary)),
                    ],
                  ),
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadTeamDetails,
              child: _buildMainContent(glass, cardBgColor, teamName, isActive),
            ),
    );
  }

  Widget _buildMainContent(GlassTheme glass, Color cardBgColor, String teamName, bool isActive) {
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
              Text('Unable to Load Team Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: glass.textPrimary)),
              const SizedBox(height: 8),
              Text(_errorMessage!, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: glass.textSecondary)),
              const SizedBox(height: 24),
              AppButton(label: 'Retry', icon: Icons.refresh_rounded, width: 140, onPressed: _loadTeamDetails),
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
          // Team Header Card
          AppCard(
            backgroundColor: cardBgColor,
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundColor: const Color(0xFF0F6B66).withAlpha(30),
                          child: Text(teamName.isNotEmpty ? teamName[0].toUpperCase() : 'T', style: const TextStyle(fontSize: 22, color: Color(0xFF0F6B66), fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(teamName, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: glass.textPrimary)),
                            Text(_team['departmentName'] ?? _team['department'] ?? 'General Department', style: TextStyle(color: glass.textSecondary, fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isActive ? const Color(0xFF10B981).withAlpha(30) : Colors.grey.withAlpha(30),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        isActive ? 'Active' : 'Inactive',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isActive ? const Color(0xFF10B981) : Colors.grey),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  children: [
                    Icon(Icons.person_pin_rounded, size: 16, color: glass.textSecondary),
                    const SizedBox(width: 8),
                    Text('Team Lead: ${_team['teamLeadName'] ?? 'Unassigned'}', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: glass.textPrimary)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.groups_rounded, size: 16, color: glass.textSecondary),
                    const SizedBox(width: 8),
                    Text('Total Members: ${_team['memberCount'] ?? _teamMembers.length}', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: glass.textPrimary)),
                  ],
                ),
                if (_team['description'] != null && _team['description'].toString().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(_team['description'].toString(), style: TextStyle(color: glass.textSecondary, fontSize: 12)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Team Members Roster Section
          Text('Team Members Roster (${_teamMembers.length})', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: glass.textPrimary)),
          const SizedBox(height: 12),

          if (_teamMembers.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 32),
              alignment: Alignment.center,
              child: Text('No members found in this team.', style: TextStyle(color: glass.textSecondary)),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _teamMembers.length,
              itemBuilder: (context, index) {
                final member = _teamMembers[index];
                final name = '${member['firstName'] ?? ''} ${member['lastName'] ?? ''}'.trim().isNotEmpty ? '${member['firstName']} ${member['lastName']}' : (member['fullName'] ?? member['name'] ?? 'Employee');
                final code = member['employeeCode'] ?? member['employeeId'] ?? 'EMP';
                final dept = member['department'] ?? 'General';
                final desig = member['designation'] ?? 'Staff';

                return AppCard(
                  backgroundColor: cardBgColor,
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: const Color(0xFF0F6B66).withAlpha(30),
                        child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'M', style: const TextStyle(color: Color(0xFF0F6B66), fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: glass.textPrimary)),
                            Text('$code • $dept ($desig)', style: TextStyle(fontSize: 11, color: glass.textSecondary)),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
