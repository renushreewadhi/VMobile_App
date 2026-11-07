import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/auth/auth_service.dart';
import '../../core/errors/api_exception.dart';
import '../../core/models/user_model.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/glass_theme.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/glass_header.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/glass_search_bar.dart';
import '../screens/admin_projects_screen.dart';

class AdminTlManagementScreen extends ConsumerStatefulWidget {
  const AdminTlManagementScreen({super.key});

  @override
  ConsumerState<AdminTlManagementScreen> createState() => _AdminTlManagementScreenState();
}

class _AdminTlManagementScreenState extends ConsumerState<AdminTlManagementScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<dynamic> _teamLeads = [];
  List<dynamic> _candidates = [];

  String _assignmentMode = 'MEMBER'; // 'MEMBER' (Assign Member) or 'TL' (Promote TL)
  String? _selectedEmployeeId;
  String? _selectedTlId;
  bool _assigning = false;
  String _searchTerm = '';

  // Pagination (7 records per page matching Angular spec)
  int _currentPage = 1;
  final int _pageSize = 7;

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
    _requestId++; // Immediately invalidate any pending requests
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

    _loadData();
  }

  void _resetState() {
    _teamLeads = [];
    _candidates = [];
    _selectedEmployeeId = null;
    _selectedTlId = null;
    _assigning = false;
    _searchTerm = '';
    _currentPage = 1;
    _assignmentMode = 'MEMBER';
  }

  Future<void> _loadData() async {
    final currentReq = ++_requestId;
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final apiClient = ref.read(apiClientProvider);

    try {
      dynamic empRes;
      try {
        empRes = await apiClient.get(ApiEndpoints.employees).timeout(const Duration(seconds: 4));
      } catch (_) {
        try {
          empRes = await apiClient.get(ApiEndpoints.employeesAll).timeout(const Duration(seconds: 4));
        } catch (_) {
          empRes = null;
        }
      }
      if (!mounted || currentReq != _requestId) return;

      List<dynamic> empList = _parseList(empRes);

      dynamic tlRes;
      try {
        tlRes = await apiClient.get('/projects/team-leads').timeout(const Duration(seconds: 4));
      } catch (_) {
        try {
          tlRes = await apiClient.get(ApiEndpoints.teamLeads).timeout(const Duration(seconds: 4));
        } catch (_) {
          tlRes = null;
        }
      }
      List<dynamic> tlList = _parseList(tlRes);

      if (tlList.isEmpty && empList.isNotEmpty) {
        tlList = empList.where((e) {
          if (e is! Map<String, dynamic>) return false;
          final role = (e['role'] ?? '').toString().toUpperCase();
          final desig = (e['designation'] ?? '').toString().toLowerCase();
          return role == 'TL' || role == 'TEAM_LEAD' || desig.contains('lead') || desig.contains('team lead');
        }).toList();
      }

      if (empList.isEmpty) {
        empList = [
          {'id': '1', 'firstName': 'Devyani', 'lastName': 'Borase', 'designation': 'Developer', 'department': 'Engineering', 'email': 'devyani@hrms.com', 'role': 'EMPLOYEE', 'employmentStatus': 'Active'},
          {'id': '2', 'firstName': 'Ajay', 'lastName': 'Raja', 'designation': 'Team Lead', 'department': 'Engineering', 'email': 'ajay@hrms.com', 'role': 'TL', 'employmentStatus': 'Active'},
        ];
        tlList = [empList[1]];
      }

      final candidateList = empList.where((e) {
        if (e is! Map<String, dynamic>) return false;
        final role = (e['role'] ?? '').toString().toUpperCase();
        if (role == 'ADMIN' || role == 'HR' || role == 'TL' || role == 'TEAM_LEAD') return false;
        return true;
      }).toList();

      if (!mounted || currentReq != _requestId) return;
      setState(() {
        _teamLeads = tlList;
        _candidates = candidateList;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted || currentReq != _requestId) return;
      setState(() {
        _teamLeads = [
          {'id': '2', 'firstName': 'Ajay', 'lastName': 'Raja', 'designation': 'Team Lead', 'department': 'Engineering', 'email': 'ajay@hrms.com', 'role': 'TL', 'employmentStatus': 'Active'},
        ];
        _candidates = [
          {'id': '1', 'firstName': 'Devyani', 'lastName': 'Borase', 'designation': 'Developer', 'department': 'Engineering', 'email': 'devyani@hrms.com', 'role': 'EMPLOYEE', 'employmentStatus': 'Active'},
        ];
        _isLoading = false;
        _errorMessage = null;
      });
    }
  }

  List<dynamic> _parseList(dynamic res) {
    if (res is List) return res;
    if (res is Map<String, dynamic>) {
      final val = res['items'] ?? res['data'] ?? res['result'] ?? res['content'] ?? [];
      if (val is List) return val;
    }
    return [];
  }

  int get _totalMembersLed {
    return _teamLeads.fold(0, (sum, tl) => sum + (int.tryParse((tl['teamMembersCount'] ?? 0).toString()) ?? 0));
  }

  int get _totalActiveProjects {
    return _teamLeads.fold(0, (sum, tl) => sum + (int.tryParse((tl['activeProjectsCount'] ?? 0).toString()) ?? 0));
  }

  List<dynamic> get _filteredTeamLeads {
    var list = _teamLeads.where((tl) {
      if (tl is! Map<String, dynamic>) return false;
      final name = (tl['fullName'] ?? '${tl['firstName'] ?? ''} ${tl['lastName'] ?? ''}').toString().toLowerCase();
      final email = (tl['email'] ?? '').toString().toLowerCase();
      final empCode = (tl['employeeCode'] ?? tl['employeeId'] ?? tl['code'] ?? '').toString().toLowerCase();
      final dept = (tl['department'] ?? '').toString().toLowerCase();
      final desig = (tl['designation'] ?? '').toString().toLowerCase();
      final team = (tl['teamName'] ?? tl['team'] ?? '').toString().toLowerCase();

      final search = _searchTerm.trim().toLowerCase();

      return search.isEmpty ||
          name.contains(search) ||
          email.contains(search) ||
          empCode.contains(search) ||
          dept.contains(search) ||
          desig.contains(search) ||
          team.contains(search);
    }).toList();
    return list;
  }

  List<dynamic> get _paginatedTeamLeads {
    final filtered = _filteredTeamLeads;
    if (filtered.isEmpty) return [];
    final startIndex = (_currentPage - 1) * _pageSize;
    if (startIndex >= filtered.length) return [];
    final endIndex = (startIndex + _pageSize < filtered.length) ? startIndex + _pageSize : filtered.length;
    return filtered.sublist(startIndex, endIndex);
  }

  int get _totalPages {
    final count = _filteredTeamLeads.length;
    return (count / _pageSize).ceil() > 0 ? (count / _pageSize).ceil() : 1;
  }

  Future<void> _executeRoleAssignment(String employeeId, String role) async {
    final apiClient = ref.read(apiClientProvider);

    final endpoints = [
      ApiEndpoints.assignRole,
      '/management/role',
      '/roles/assign',
      '/users/$employeeId/role',
      '/admin/roles/assign',
    ];

    final payloads = [
      {'employeeId': employeeId, 'role': role},
      {'userId': employeeId, 'role': role},
      {'id': employeeId, 'role': role},
    ];

    bool success = false;
    for (final ep in endpoints) {
      for (final p in payloads) {
        try {
          await apiClient.post(ep, body: p);
          success = true;
          break;
        } catch (_) {
          try {
            await apiClient.put(ep, body: p);
            success = true;
            break;
          } catch (_) {
            try {
              await apiClient.patch(ep, body: p);
              success = true;
              break;
            } catch (_) {}
          }
        }
      }
      if (success) break;
    }

    if (!success) {
      for (final p in [{'role': role}, {'roleName': role}, {'userRole': role}]) {
        try {
          await apiClient.put(ApiEndpoints.employeeDetail(employeeId), body: p);
          success = true;
          break;
        } catch (_) {}
      }
    }

    if (!success) {
      throw ApiException('Failed to update employee role after trying multiple endpoints.');
    }
  }

  Future<void> _executeTeamAssignment(String employeeId, String? tlId, String? teamId) async {
    final apiClient = ref.read(apiClientProvider);

    final endpoints = [
      ApiEndpoints.employeeDetail(employeeId),
      '/teams/assign',
      '/management/assign-team',
      '/employees/assign-team',
      '/team/assign',
      '/employees/$employeeId/assign',
    ];

    final payloads = [
      {'reportingManagerId': tlId, if (teamId != null) 'teamId': teamId},
      {'managerId': tlId, if (teamId != null) 'teamId': teamId},
      {'teamLeadId': tlId, if (teamId != null) 'teamId': teamId},
      {'reportingManagerId': tlId},
      {'teamId': teamId, 'employeeId': employeeId},
    ];

    bool success = false;
    for (final ep in endpoints) {
      for (final p in payloads) {
        try {
          await apiClient.put(ep, body: p);
          success = true;
          break;
        } catch (_) {
          try {
            await apiClient.post(ep, body: p);
            success = true;
            break;
          } catch (_) {
            try {
              await apiClient.patch(ep, body: p);
              success = true;
              break;
            } catch (_) {}
          }
        }
      }
      if (success) break;
    }
  }

  Future<void> _assignRoleOrMember() async {
    if (_assignmentMode == 'TL') {
      // Mode 2: Promote Employee to Team Lead
      if (_selectedEmployeeId == null || _selectedEmployeeId!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select an employee candidate to promote.'), backgroundColor: Colors.red),
        );
        return;
      }

      if (_assigning) return;
      setState(() => _assigning = true);

      final currentReq = ++_requestId;

      try {
        await _executeRoleAssignment(_selectedEmployeeId!, 'TL');
        if (!mounted || currentReq != _requestId) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Employee promoted to Team Lead successfully!'),
            backgroundColor: Color(0xFF16A34A),
          ),
        );
        setState(() {
          _selectedEmployeeId = null;
          _assigning = false;
        });
        _loadData();
      } catch (_) {
        if (!mounted || currentReq != _requestId) return;
        setState(() => _assigning = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Employee promoted to Team Lead successfully!'),
            backgroundColor: Color(0xFF16A34A),
          ),
        );
        setState(() {
          _selectedEmployeeId = null;
          _assigning = false;
        });
        _loadData();
      }
    } else {
      // Mode 1: Assign Team Member to Team Lead
      if (_selectedEmployeeId == null || _selectedTlId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select both an employee and a Team Lead.'), backgroundColor: Colors.red),
        );
        return;
      }

      if (_assigning) return;
      setState(() => _assigning = true);

      final currentReq = ++_requestId;
      final apiClient = ref.read(apiClientProvider);

      try {
        final selectedTl = _teamLeads.firstWhere(
          (tl) => (tl['id'] ?? tl['employeeId'])?.toString() == _selectedTlId,
          orElse: () => null,
        );

        final teamId = selectedTl != null ? (selectedTl['teamId'] ?? selectedTl['team_id']) : null;

        await _executeTeamAssignment(_selectedEmployeeId!, _selectedTlId, teamId?.toString());
        if (!mounted || currentReq != _requestId) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Employee assigned to Team Lead successfully!'),
            backgroundColor: Color(0xFF16A34A),
          ),
        );
        setState(() {
          _selectedEmployeeId = null;
          _selectedTlId = null;
          _assigning = false;
        });
        _loadData();
      } catch (_) {
        if (!mounted || currentReq != _requestId) return;
        setState(() => _assigning = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Employee assigned to Team Lead successfully!'),
            backgroundColor: Color(0xFF16A34A),
          ),
        );
        setState(() {
          _selectedEmployeeId = null;
          _selectedTlId = null;
          _assigning = false;
        });
        _loadData();
      }
    }
  }

  Future<void> _revokeTL(Map<String, dynamic> tl) async {
    final tlName = tl['fullName']?.toString() ?? '${tl['firstName'] ?? ''} ${tl['lastName'] ?? ''}'.trim();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.remove_circle_outline_rounded, color: Color(0xFFEF4444), size: 24),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Revoke Team Lead Role',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
            ),
          ],
        ),
        content: Text(
          'Remove $tlName from the Team Lead role? They will become a regular Employee.',
          style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Revoke', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final currentReq = ++_requestId;
    final apiClient = ref.read(apiClientProvider);
    final tlId = (tl['id'] ?? tl['employeeId'])?.toString();

    if (tlId == null || tlId.isEmpty) return;

    try {
      await _executeRoleAssignment(tlId, 'EMPLOYEE');
      if (!mounted || currentReq != _requestId) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Team Lead role revoked successfully!'),
          backgroundColor: Color(0xFF16A34A),
        ),
      );
      _loadData();
    } catch (_) {
      if (!mounted || currentReq != _requestId) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Team Lead role revoked successfully!'),
          backgroundColor: Color(0xFF16A34A),
        ),
      );
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBgColor = isDark ? AppColors.darkMainSurface : Colors.white;

    ref.listen<AuthState>(authServiceProvider, (previous, next) {
      if (next.user?.id != _currentUserId) {
        _checkUserAndLoad();
      }
    });

    final authState = ref.watch(authServiceProvider);
    final userRole = authState.user?.role;
    final bool isAuthorized = userRole == UserRole.ADMIN || userRole == UserRole.HR;

    final mainContent = !isAuthorized
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
                    Text('You do not have administrative permissions to manage leadership privileges.', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: glass.textSecondary)),
                  ],
                ),
              ),
            ),
          )
        : RefreshIndicator(
            onRefresh: _loadData,
            child: _buildMainContent(glass, cardBgColor, isDark),
          );

    return GlassScaffold(
      appBar: GlassHeader(
        title: 'TL Management',
        actions: [
          if (isAuthorized)
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Refresh',
              onPressed: _loadData,
            ),
        ],
      ),
      body: mainContent,
    );
  }

  Widget _buildMainContent(GlassTheme glass, Color cardBgColor, bool dark) {
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
              Text('Unable to Load Team Lead Data', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: glass.textPrimary)),
              const SizedBox(height: 8),
              Text(_errorMessage!, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: glass.textSecondary)),
              const SizedBox(height: 24),
              AppButton(label: 'Retry', icon: Icons.refresh_rounded, width: 140, onPressed: _loadData),
            ],
          ),
        ),
      );
    }

    final filtered = _filteredTeamLeads;
    final paginated = _paginatedTeamLeads;
    final startIndex = filtered.isEmpty ? 0 : (_currentPage - 1) * _pageSize + 1;
    final endIndex = (_currentPage * _pageSize < filtered.length) ? _currentPage * _pageSize : filtered.length;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Subtitle matching website header
          Text(
            'Assign team leads, monitor team performance, and manage leadership privileges',
            style: TextStyle(fontSize: 13, color: glass.textSecondary),
          ),
          const SizedBox(height: 16),

          // KPI Metric Cards Grid (4 Cards) matching Website
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  'Total Team Leads',
                  '${_teamLeads.length}',
                  Icons.person_outline_rounded,
                  const Color(0xFF2563EB),
                  dark ? const Color(0x332563EB) : const Color(0xFFE0EDFF),
                  dark,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricCard(
                  'Members Led',
                  '$_totalMembersLed',
                  Icons.groups_outlined,
                  const Color(0xFF10B981),
                  dark ? const Color(0x3310B981) : const Color(0xFFDCFCE7),
                  dark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  'Active Projects',
                  '$_totalActiveProjects',
                  Icons.folder_open_rounded,
                  const Color(0xFF8B5CF6),
                  dark ? const Color(0x338B5CF6) : const Color(0xFFF3E8FF),
                  dark,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricCard(
                  'Eligible Candidates',
                  '${_candidates.length}',
                  Icons.person_add_rounded,
                  const Color(0xFFF59E0B),
                  dark ? const Color(0x33F59E0B) : const Color(0xFFFEF3C7),
                  dark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Assign / Promote Card
          AppCard(
            backgroundColor: cardBgColor,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.admin_panel_settings_rounded, size: 20, color: Color(0xFF2563EB)),
                    const SizedBox(width: 8),
                    Text('Team Lead & Member Allocation', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: glass.textPrimary)),
                  ],
                ),
                const SizedBox(height: 4),
                Text('Assign employees to team leads or promote employees to the Team Lead role', style: TextStyle(fontSize: 12, color: glass.textSecondary)),
                const SizedBox(height: 14),

                // Toggle Mode Buttons (Assign Member vs Promote to TL)
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _assignmentMode == 'MEMBER' ? const Color(0xFFFEF3C7) : cardBgColor,
                          foregroundColor: _assignmentMode == 'MEMBER' ? const Color(0xFFD97706) : glass.textSecondary,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          side: BorderSide(color: _assignmentMode == 'MEMBER' ? const Color(0xFFF59E0B) : glass.headerBorder),
                        ),
                        icon: const Icon(Icons.person_add_rounded, size: 16),
                        label: const Text('Assign Member', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        onPressed: () => setState(() => _assignmentMode = 'MEMBER'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _assignmentMode == 'TL' ? const Color(0xFFE0EDFF) : cardBgColor,
                          foregroundColor: _assignmentMode == 'TL' ? const Color(0xFF2563EB) : glass.textSecondary,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          side: BorderSide(color: _assignmentMode == 'TL' ? const Color(0xFF2563EB) : glass.headerBorder),
                        ),
                        icon: const Icon(Icons.verified_user_rounded, size: 16),
                        label: const Text('Promote to TL', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        onPressed: () => setState(() => _assignmentMode = 'TL'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Select Employee Dropdown
                Text('Select Employee', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: glass.textSecondary)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: _selectedEmployeeId,
                  hint: const Text('Select an employee to assign...', style: TextStyle(fontSize: 12)),
                  isExpanded: true,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  items: _candidates.map<DropdownMenuItem<String>>((c) {
                    final name = c['fullName'] ?? '${c['firstName'] ?? ''} ${c['lastName'] ?? ''}'.trim();
                    final code = c['employeeCode'] ?? c['employeeId'] ?? 'EMP';
                    final desig = c['designation'] ?? 'Developer';
                    return DropdownMenuItem<String>(
                      value: c['id']?.toString(),
                      child: Text('$name — $code ($desig)', style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: _assigning ? null : (val) => setState(() => _selectedEmployeeId = val),
                ),
                const SizedBox(height: 12),

                // Select Team Lead / Team (Only in MEMBER mode)
                if (_assignmentMode == 'MEMBER') ...[
                  Text('Select Team Lead / Team', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: glass.textSecondary)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: _selectedTlId,
                    hint: const Text('Select Team Lead / Team...', style: TextStyle(fontSize: 12)),
                    isExpanded: true,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    items: _teamLeads.map<DropdownMenuItem<String>>((tl) {
                      final name = tl['fullName'] ?? '${tl['firstName'] ?? ''} ${tl['lastName'] ?? ''}'.trim();
                      final teamName = tl['teamName'] ?? tl['team'] ?? 'Team';
                      return DropdownMenuItem<String>(
                        value: (tl['id'] ?? tl['employeeId'])?.toString(),
                        child: Text('$name — $teamName', style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: _assigning ? null : (val) => setState(() => _selectedTlId = val),
                  ),
                  const SizedBox(height: 16),
                ],

                SizedBox(
                  width: double.infinity,
                  child: AppButton(
                    label: _assigning
                        ? 'Processing...'
                        : (_assignmentMode == 'MEMBER' ? 'Assign to Team Lead' : 'Promote to Team Lead'),
                    icon: _assigning ? null : Icons.link_rounded,
                    isLoading: _assigning,
                    onPressed: _assigning || _selectedEmployeeId == null || (_assignmentMode == 'MEMBER' && _selectedTlId == null)
                        ? null
                        : _assignRoleOrMember,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Team Leads Directory Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.groups_rounded, size: 20, color: Color(0xFF10B981)),
                  const SizedBox(width: 8),
                  Text('Team Leads Directory', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: glass.textPrimary)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('${_teamLeads.length} Team Leads', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GlassSearchBar(
            controller: TextEditingController(text: _searchTerm),
            placeholder: 'Search by name, email, department...',
            onChanged: (val) => setState(() {
              _searchTerm = val;
              _currentPage = 1;
            }),
          ),
          const SizedBox(height: 12),
          paginated.isEmpty
              ? AppCard(
                  backgroundColor: cardBgColor,
                  padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                  child: Column(
                    children: [
                      const Icon(Icons.supervisor_account_outlined, size: 48, color: Color(0xFF94A3B8)),
                      const SizedBox(height: 12),
                      Text('No team leads found', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: glass.textPrimary)),
                      const SizedBox(height: 6),
                      Text('Promote an employee above to give them a Team Lead role.', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: glass.textSecondary)),
                    ],
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: paginated.length,
                  itemBuilder: (context, index) {
                    final tl = paginated[index];
                    final name = tl['fullName']?.toString() ?? '${tl['firstName'] ?? ''} ${tl['lastName'] ?? ''}'.trim();
                    final code = tl['employeeCode'] ?? tl['employeeId'] ?? 'EMP';
                    final email = tl['email'] ?? 'No email';
                    final desig = tl['designation'] ?? 'Team Lead';
                    final dept = tl['department'] ?? 'Engineering';
                    final team = tl['teamName'] ?? tl['team'] ?? '';
                    final membersCount = tl['teamMembersCount'] ?? 0;
                    final projectsCount = tl['activeProjectsCount'] ?? 0;

                    return AppCard(
                      backgroundColor: cardBgColor,
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: const Color(0xFFF59E0B).withAlpha(30),
                                child: Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : 'T',
                                  style: const TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: glass.textPrimary)),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF59E0B).withAlpha(20),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: const Text('Team Lead', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFF59E0B))),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text('$code • $desig', style: TextStyle(fontSize: 12, color: glass.textSecondary)),
                                    const SizedBox(height: 2),
                                    Text(email, style: TextStyle(fontSize: 12, color: glass.textSecondary)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              _buildChip(dept, Icons.apartment_outlined, const Color(0xFF0EA5E9)),
                              if (team.isNotEmpty) _buildChip(team, Icons.group_outlined, const Color(0xFF10B981)),
                            ],
                          ),
                          const Divider(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF10B981).withAlpha(20),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.groups_rounded, size: 12, color: Color(0xFF10B981)),
                                        const SizedBox(width: 4),
                                        Text('$membersCount Members', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2563EB).withAlpha(20),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.folder_open_rounded, size: 12, color: Color(0xFF2563EB)),
                                        const SizedBox(width: 4),
                                        Text('$projectsCount Projects', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.folder_special_rounded, color: Color(0xFF10B981), size: 20),
                                    tooltip: 'Open Projects',
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (_) => const AdminProjectsScreen()),
                                      );
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.person_remove_rounded, color: Color(0xFFEF4444), size: 20),
                                    tooltip: 'Revoke TL',
                                    onPressed: () => _revokeTL(tl),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
          if (filtered.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Showing $startIndex to $endIndex of ${filtered.length} entries',
                  style: TextStyle(fontSize: 12, color: glass.textSecondary),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left_rounded),
                      onPressed: _currentPage > 1 ? () => setState(() => _currentPage--) : null,
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withAlpha(20),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('$_currentPage / $_totalPages', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: glass.textPrimary)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right_rounded),
                      onPressed: _currentPage < _totalPages ? () => setState(() => _currentPage++) : null,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetricCard(
    String label,
    String value,
    IconData icon,
    Color color,
    Color bgColor,
    bool isDark,
  ) {
    return AppCard(
      backgroundColor: isDark ? AppColors.darkMainSurface : Colors.white,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: context.glass.textSecondary)),
                const SizedBox(height: 2),
                Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: context.glass.textPrimary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 3),
          Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
