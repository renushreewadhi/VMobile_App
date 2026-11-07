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

/// Strongly typed Employee Model for Org Allocation
class OrgEmployeeModel {
  String id;
  String employeeId;
  String firstName;
  String lastName;
  String email;
  String? departmentId;
  String? department;
  String? teamId;
  String? teamName;
  String? designationId;
  String? designation;
  String employmentStatus;
  String? avatar;

  OrgEmployeeModel({
    required this.id,
    required this.employeeId,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.departmentId,
    this.department,
    this.teamId,
    this.teamName,
    this.designationId,
    this.designation,
    required this.employmentStatus,
    this.avatar,
  });

  String get fullName => '$firstName $lastName'.trim();

  factory OrgEmployeeModel.fromJson(Map<String, dynamic> json) {
    return OrgEmployeeModel(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      employeeId: json['employeeId']?.toString() ?? json['code']?.toString() ?? 'EMP-000',
      firstName: json['firstName']?.toString() ?? '',
      lastName: json['lastName']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      departmentId: json['departmentId']?.toString(),
      department: json['department']?.toString() ?? json['departmentName']?.toString(),
      teamId: json['teamId']?.toString(),
      teamName: json['teamName']?.toString() ?? json['team']?.toString(),
      designationId: json['designationId']?.toString(),
      designation: json['designation']?.toString() ?? json['designationTitle']?.toString(),
      employmentStatus: json['employmentStatus']?.toString() ?? json['status']?.toString() ?? 'Active',
      avatar: json['avatar']?.toString(),
    );
  }
}

class OrgColumnModel {
  final String id;
  final String name;
  final IconData icon;
  final Color color;
  final List<OrgEmployeeModel> employees;

  OrgColumnModel({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.employees,
  });
}

class AdminOrgAllocationScreen extends ConsumerStatefulWidget {
  const AdminOrgAllocationScreen({super.key});

  @override
  ConsumerState<AdminOrgAllocationScreen> createState() => _AdminOrgAllocationScreenState();
}

class _AdminOrgAllocationScreenState extends ConsumerState<AdminOrgAllocationScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  String _currentMode = 'DEPARTMENT'; // 'DEPARTMENT', 'TEAM', 'DESIGNATION'

  List<OrgEmployeeModel> _allEmployees = [];
  List<Map<String, dynamic>> _departments = [];
  List<Map<String, dynamic>> _teams = [];
  List<Map<String, dynamic>> _designations = [];

  String _searchTerm = '';
  String _selectedFilterDepartment = '';
  String _selectedFilterStatus = 'Active';

  final Set<String> _processingEmployeeIds = {}; // Concurrent update prevention

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

    _loadAllData();
  }

  void _resetState() {
    _allEmployees = [];
    _departments = [];
    _teams = [];
    _designations = [];
    _searchTerm = '';
    _selectedFilterDepartment = '';
    _selectedFilterStatus = 'Active';
    _currentMode = 'DEPARTMENT';
    _processingEmployeeIds.clear();
  }

  Future<void> _loadAllData() async {
    final currentReq = ++_requestId;
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final apiClient = ref.read(apiClientProvider);

    try {
      final empRes = await apiClient.get(ApiEndpoints.employeesAll).catchError((_) => apiClient.get(ApiEndpoints.employees));
      if (!mounted || currentReq != _requestId) return;

      final deptRes = await apiClient.get(ApiEndpoints.departments).catchError((_) => []);
      if (!mounted || currentReq != _requestId) return;

      final teamRes = await apiClient.get(ApiEndpoints.teams).catchError((_) => []);
      if (!mounted || currentReq != _requestId) return;

      final desigRes = await apiClient.get(ApiEndpoints.designations).catchError((_) => []);
      if (!mounted || currentReq != _requestId) return;

      List<OrgEmployeeModel> emps = [];
      dynamic rawEmps = empRes is Map<String, dynamic> && empRes.containsKey('data') ? empRes['data'] : empRes;
      if (rawEmps is List) {
        for (final e in rawEmps) {
          if (e is Map<String, dynamic>) {
            try {
              emps.add(OrgEmployeeModel.fromJson(e));
            } catch (_) {}
          }
        }
      }

      List<Map<String, dynamic>> depts = [];
      dynamic rawDepts = deptRes is Map<String, dynamic> && deptRes.containsKey('data') ? deptRes['data'] : deptRes;
      if (rawDepts is List) {
        for (final d in rawDepts) {
          if (d is Map<String, dynamic>) {
            depts.add({
              'id': (d['id'] ?? d['_id'])?.toString() ?? '',
              'name': (d['name'] ?? d['departmentName'])?.toString() ?? 'Department',
            });
          }
        }
      }

      List<Map<String, dynamic>> teams = [];
      dynamic rawTeams = teamRes is Map<String, dynamic> && teamRes.containsKey('data') ? teamRes['data'] : teamRes;
      if (rawTeams is List) {
        for (final t in rawTeams) {
          if (t is Map<String, dynamic>) {
            teams.add({
              'id': (t['id'] ?? t['_id'])?.toString() ?? '',
              'name': (t['name'] ?? t['teamName'])?.toString() ?? 'Team',
            });
          }
        }
      }

      List<Map<String, dynamic>> desigs = [];
      dynamic rawDesigs = desigRes is Map<String, dynamic> && desigRes.containsKey('data') ? desigRes['data'] : desigRes;
      if (rawDesigs is List) {
        for (final des in rawDesigs) {
          if (des is Map<String, dynamic>) {
            desigs.add({
              'id': (des['id'] ?? des['_id'])?.toString() ?? '',
              'title': (des['title'] ?? des['name'])?.toString() ?? 'Designation',
            });
          }
        }
      }

      if (!mounted || currentReq != _requestId) return;
      setState(() {
        _allEmployees = emps;
        _departments = depts;
        _teams = teams;
        _designations = desigs;
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
        _errorMessage = 'Failed to load organization allocation data. Please check network connection.';
        _isLoading = false;
      });
    }
  }

  bool _filterEmployee(OrgEmployeeModel emp) {
    if (_selectedFilterStatus.isNotEmpty) {
      final status = emp.employmentStatus.toLowerCase();
      if (status != _selectedFilterStatus.toLowerCase()) return false;
    }

    if (_selectedFilterDepartment.isNotEmpty) {
      if (emp.departmentId != _selectedFilterDepartment && emp.department?.toLowerCase() != _selectedFilterDepartment.toLowerCase()) {
        return false;
      }
    }

    if (_searchTerm.trim().isNotEmpty) {
      final q = _searchTerm.toLowerCase().trim();
      final fullName = emp.fullName.toLowerCase();
      final code = emp.employeeId.toLowerCase();
      final email = emp.email.toLowerCase();
      final dept = (emp.department ?? '').toLowerCase();
      final desig = (emp.designation ?? '').toLowerCase();
      final team = (emp.teamName ?? '').toLowerCase();
      return fullName.contains(q) || code.contains(q) || email.contains(q) || dept.contains(q) || desig.contains(q) || team.contains(q);
    }

    return true;
  }

  List<OrgColumnModel> get _columns {
    final filteredEmps = _allEmployees.where((emp) => _filterEmployee(emp)).toList();

    if (_currentMode == 'DEPARTMENT') {
      final cols = _departments.map((d) {
        final dId = d['id'] as String;
        final dName = d['name'] as String;
        return OrgColumnModel(
          id: dId,
          name: dName,
          icon: Icons.corporate_fare_rounded,
          color: Colors.blue,
          employees: filteredEmps.where((e) => e.departmentId == dId || (!e.departmentId && e.department?.toLowerCase() == dName.toLowerCase())).toList(),
        );
      }).toList();

      final unassigned = filteredEmps.where((e) {
        if (e.departmentId == null && e.department == null) return true;
        return !_departments.any((d) => d['id'] == e.departmentId || d['name'].toString().toLowerCase() == (e.department ?? '').toLowerCase());
      }).toList();

      if (unassigned.isNotEmpty) {
        cols.add(OrgColumnModel(
          id: 'unassigned',
          name: 'Unassigned Department',
          icon: Icons.help_outline_rounded,
          color: Colors.grey,
          employees: unassigned,
        ));
      }
      return cols;
    } else if (_currentMode == 'TEAM') {
      final cols = _teams.map((t) {
        final tId = t['id'] as String;
        final tName = t['name'] as String;
        return OrgColumnModel(
          id: tId,
          name: tName,
          icon: Icons.groups_rounded,
          color: Colors.green,
          employees: filteredEmps.where((e) => e.teamId == tId || (!e.teamId && e.teamName?.toLowerCase() == tName.toLowerCase())).toList(),
        );
      }).toList();

      final unassigned = filteredEmps.where((e) {
        if (e.teamId == null && e.teamName == null) return true;
        return !_teams.any((t) => t['id'] == e.teamId || t['name'].toString().toLowerCase() == (e.teamName ?? '').toLowerCase());
      }).toList();

      cols.add(OrgColumnModel(
        id: 'unassigned',
        name: 'No Team Assigned',
        icon: Icons.person_off_outlined,
        color: Colors.grey,
        employees: unassigned,
      ));
      return cols;
    } else {
      // DESIGNATION
      final cols = _designations.map((des) {
        final desId = des['id'] as String;
        final desTitle = des['title'] as String;
        return OrgColumnModel(
          id: desId,
          name: desTitle,
          icon: Icons.badge_outlined,
          color: Colors.purple,
          employees: filteredEmps.where((e) => e.designationId == desId || (!e.designationId && e.designation?.toLowerCase() == desTitle.toLowerCase())).toList(),
        );
      }).toList();

      final unassigned = filteredEmps.where((e) {
        if (e.designationId == null && e.designation == null) return true;
        return !_designations.any((des) => des['id'] == e.designationId || des['title'].toString().toLowerCase() == (e.designation ?? '').toLowerCase());
      }).toList();

      if (unassigned.isNotEmpty) {
        cols.add(OrgColumnModel(
          id: 'unassigned',
          name: 'Unassigned Designation',
          icon: Icons.help_outline_rounded,
          color: Colors.grey,
          employees: unassigned,
        ));
      }
      return cols;
    }
  }

  Future<void> _reassignEmployee(OrgEmployeeModel emp, String targetColId) async {
    if (_processingEmployeeIds.contains(emp.id)) return;
    _processingEmployeeIds.add(emp.id);

    final isUnassigned = targetColId == 'unassigned';
    final payload = <String, dynamic>{};
    final previousState = {
      'departmentId': emp.departmentId,
      'department': emp.department,
      'teamId': emp.teamId,
      'teamName': emp.teamName,
      'designationId': emp.designationId,
      'designation': emp.designation,
    };

    String fieldName = '';
    String targetName = '';

    if (_currentMode == 'DEPARTMENT') {
      fieldName = 'Department';
      final match = _departments.firstWhere((d) => d['id'] == targetColId, orElse: () => {'name': 'Unassigned'});
      targetName = match['name'] as String;
      payload['departmentId'] = isUnassigned ? null : targetColId;
      emp.departmentId = isUnassigned ? null : targetColId;
      emp.department = isUnassigned ? 'Unassigned' : targetName;
    } else if (_currentMode == 'TEAM') {
      fieldName = 'Team';
      final match = _teams.firstWhere((t) => t['id'] == targetColId, orElse: () => {'name': 'No Team'});
      targetName = match['name'] as String;
      payload['teamId'] = isUnassigned ? null : targetColId;
      emp.teamId = isUnassigned ? null : targetColId;
      emp.teamName = isUnassigned ? 'No Team' : targetName;
    } else if (_currentMode == 'DESIGNATION') {
      fieldName = 'Designation';
      final match = _designations.firstWhere((d) => d['id'] == targetColId, orElse: () => {'title': 'Unassigned'});
      targetName = match['title'] as String;
      payload['designationId'] = isUnassigned ? null : targetColId;
      emp.designationId = isUnassigned ? null : targetColId;
      emp.designation = isUnassigned ? 'Unassigned' : targetName;
    }

    setState(() {}); // Optimistic UI update

    final currentReq = ++_requestId;
    final apiClient = ref.read(apiClientProvider);

    try {
      await apiClient.put(ApiEndpoints.employeeDetail(emp.id), body: payload);
      if (!mounted || currentReq != _requestId) {
        _processingEmployeeIds.remove(emp.id);
        return;
      }

      _processingEmployeeIds.remove(emp.id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Updated $fieldName for ${emp.fullName} to "$targetName".')),
      );
    } catch (e) {
      if (!mounted || currentReq != _requestId) {
        _processingEmployeeIds.remove(emp.id);
        return;
      }
      // Rollback
      setState(() {
        emp.departmentId = previousState['departmentId'] as String?;
        emp.department = previousState['department'] as String?;
        emp.teamId = previousState['teamId'] as String?;
        emp.teamName = previousState['teamName'] as String?;
        emp.designationId = previousState['designationId'] as String?;
        emp.designation = previousState['designation'] as String?;
      });
      _processingEmployeeIds.remove(emp.id);

      final msg = e is ApiException ? e.message : 'Failed to reassign $fieldName. Changes rolled back.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red),
      );
    }
  }

  void _openQuickEdit(OrgEmployeeModel emp) {
    String deptId = emp.departmentId ?? '';
    String teamId = emp.teamId ?? '';
    String desigId = emp.designationId ?? '';
    bool isSavingModal = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.edit_note_rounded, color: Color(0xFF0F6B66)),
              const SizedBox(width: 8),
              Text('Reassign ${emp.fullName}'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Employee ID: ${emp.employeeId}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: deptId.isEmpty ? null : deptId,
                  decoration: const InputDecoration(labelText: 'Department', border: OutlineInputBorder()),
                  items: [
                    const DropdownMenuItem(value: '', child: Text('-- No Department --')),
                    ..._departments.map((d) => DropdownMenuItem(value: d['id'].toString(), child: Text(d['name'].toString()))),
                  ],
                  onChanged: isSavingModal ? null : (val) => setModalState(() => deptId = val ?? ''),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: teamId.isEmpty ? null : teamId,
                  decoration: const InputDecoration(labelText: 'Team', border: OutlineInputBorder()),
                  items: [
                    const DropdownMenuItem(value: '', child: Text('-- No Team --')),
                    ..._teams.map((t) => DropdownMenuItem(value: t['id'].toString(), child: Text(t['name'].toString()))),
                  ],
                  onChanged: isSavingModal ? null : (val) => setModalState(() => teamId = val ?? ''),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: desigId.isEmpty ? null : desigId,
                  decoration: const InputDecoration(labelText: 'Designation', border: OutlineInputBorder()),
                  items: [
                    const DropdownMenuItem(value: '', child: Text('-- No Designation --')),
                    ..._designations.map((des) => DropdownMenuItem(value: des['id'].toString(), child: Text(des['title'].toString()))),
                  ],
                  onChanged: isSavingModal ? null : (val) => setModalState(() => desigId = val ?? ''),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSavingModal ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isSavingModal
                  ? null
                  : () async {
                      setModalState(() => isSavingModal = true);
                      final currentReq = ++_requestId;
                      final apiClient = ref.read(apiClientProvider);

                      final payload = {
                        'departmentId': deptId.isEmpty ? null : deptId,
                        'teamId': teamId.isEmpty ? null : teamId,
                        'designationId': desigId.isEmpty ? null : desigId,
                      };

                      try {
                        await apiClient.put(ApiEndpoints.employeeDetail(emp.id), body: payload);
                        if (!mounted || currentReq != _requestId) return;

                        setState(() {
                          emp.departmentId = deptId.isEmpty ? null : deptId;
                          emp.department = _departments.firstWhere((d) => d['id'] == deptId, orElse: () => {'name': 'Unassigned'})['name'];
                          emp.teamId = teamId.isEmpty ? null : teamId;
                          emp.teamName = _teams.firstWhere((t) => t['id'] == teamId, orElse: () => {'name': 'No Team'})['name'];
                          emp.designationId = desigId.isEmpty ? null : desigId;
                          emp.designation = _designations.firstWhere((d) => d['id'] == desigId, orElse: () => {'title': 'Unassigned'})['title'];
                        });

                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Successfully updated assignments for ${emp.fullName}!')),
                        );
                      } catch (e) {
                        if (!mounted || currentReq != _requestId) return;
                        setModalState(() => isSavingModal = false);
                        final msg = e is ApiException ? e.message : 'Failed to update employee assignments.';
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(msg), backgroundColor: Colors.red),
                        );
                      }
                    },
              child: isSavingModal
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Apply Changes'),
            ),
          ],
        ),
      ),
    );
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
        title: 'Org Allocation & Reassignment',
        actions: [
          if (isAuthorized)
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Refresh Board',
              onPressed: _loadAllData,
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
                      Text('You do not have administrative permissions to view organization allocation boards.', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: glass.textSecondary)),
                    ],
                  ),
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadAllData,
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
              Text('Unable to Load Org Allocation Board', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: glass.textPrimary)),
              const SizedBox(height: 8),
              Text(_errorMessage!, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: glass.textSecondary)),
              const SizedBox(height: 24),
              AppButton(label: 'Retry', icon: Icons.refresh_rounded, width: 140, onPressed: _loadAllData),
            ],
          ),
        ),
      );
    }

    final columns = _columns;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // KPI Metric Summary Cards Row (4 Cards)
          Row(
            children: [
              Expanded(child: _buildStatTile(glass, cardBgColor, label: 'Total', value: '${_allEmployees.length}', icon: Icons.groups_rounded, iconColor: const Color(0xFF2563EB))),
              const SizedBox(width: 8),
              Expanded(child: _buildStatTile(glass, cardBgColor, label: 'Departments', value: '${_departments.length}', icon: Icons.corporate_fare_rounded, iconColor: const Color(0xFF10B981))),
              const SizedBox(width: 8),
              Expanded(child: _buildStatTile(glass, cardBgColor, label: 'Teams', value: '${_teams.length}', icon: Icons.group_outlined, iconColor: const Color(0xFF8B5CF6))),
              const SizedBox(width: 8),
              Expanded(child: _buildStatTile(glass, cardBgColor, label: 'Designations', value: '${_designations.length}', icon: Icons.badge_outlined, iconColor: const Color(0xFFF59E0B))),
            ],
          ),
          const SizedBox(height: 16),

          // Mode Selection Tabs (By Department, By Team, By Designation)
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: _currentMode == 'DEPARTMENT' ? const Color(0xFF0F6B66) : Colors.transparent,
                    foregroundColor: _currentMode == 'DEPARTMENT' ? Colors.white : glass.textPrimary,
                    side: BorderSide(color: _currentMode == 'DEPARTMENT' ? const Color(0xFF0F6B66) : glass.cardBorder),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => setState(() => _currentMode = 'DEPARTMENT'),
                  child: const Text('By Department', style: TextStyle(fontSize: 12)),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: _currentMode == 'TEAM' ? const Color(0xFF0F6B66) : Colors.transparent,
                    foregroundColor: _currentMode == 'TEAM' ? Colors.white : glass.textPrimary,
                    side: BorderSide(color: _currentMode == 'TEAM' ? const Color(0xFF0F6B66) : glass.cardBorder),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => setState(() => _currentMode = 'TEAM'),
                  child: const Text('By Team', style: TextStyle(fontSize: 12)),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: _currentMode == 'DESIGNATION' ? const Color(0xFF0F6B66) : Colors.transparent,
                    foregroundColor: _currentMode == 'DESIGNATION' ? Colors.white : glass.textPrimary,
                    side: BorderSide(color: _currentMode == 'DESIGNATION' ? const Color(0xFF0F6B66) : glass.cardBorder),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => setState(() => _currentMode = 'DESIGNATION'),
                  child: const Text('By Designation', style: TextStyle(fontSize: 12)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Search and Filters Bar
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search employee name, code, email...',
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
              ),
              const SizedBox(width: 10),
              DropdownButton<String>(
                value: _selectedFilterStatus.isEmpty ? null : _selectedFilterStatus,
                hint: const Text('Status', style: TextStyle(fontSize: 12)),
                underline: const SizedBox.shrink(),
                items: const [
                  DropdownMenuItem(value: '', child: Text('All Statuses', style: TextStyle(fontSize: 12))),
                  DropdownMenuItem(value: 'Active', child: Text('Active', style: TextStyle(fontSize: 12))),
                  DropdownMenuItem(value: 'Inactive', child: Text('Inactive', style: TextStyle(fontSize: 12))),
                ],
                onChanged: (val) => setState(() => _selectedFilterStatus = val ?? ''),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Kanban Columns (Drag Targets)
          if (columns.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 48),
              alignment: Alignment.center,
              child: Text('No allocation columns available.', style: TextStyle(color: glass.textSecondary)),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: columns.length,
              itemBuilder: (context, index) {
                final col = columns[index];
                return DragTarget<OrgEmployeeModel>(
                  onAcceptWithDetails: (details) {
                    _reassignEmployee(details.data, col.id);
                  },
                  builder: (context, candidateData, rejectedData) {
                    final isHovered = candidateData.isNotEmpty;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: cardBgColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isHovered ? const Color(0xFF0F6B66) : glass.cardBorder, width: isHovered ? 2 : 1),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Column Header
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isHovered ? const Color(0xFF0F6B66).withAlpha(20) : Colors.grey.withAlpha(10),
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(col.icon, size: 18, color: const Color(0xFF0F6B66)),
                                    const SizedBox(width: 8),
                                    Text(col.name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: glass.textPrimary)),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(color: const Color(0xFF0F6B66).withAlpha(30), borderRadius: BorderRadius.circular(10)),
                                  child: Text('${col.employees.length}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F6B66))),
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1),

                          // Employees List in Column
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: col.employees.isEmpty
                                ? Container(
                                    padding: const EdgeInsets.symmetric(vertical: 24),
                                    alignment: Alignment.center,
                                    child: Text('Drop employees here to allocate', style: TextStyle(fontSize: 12, color: glass.textSecondary)),
                                  )
                                : ListView.builder(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: col.employees.length,
                                    itemBuilder: (ctx, empIdx) {
                                      final emp = col.employees[empIdx];
                                      return LongPressDraggable<OrgEmployeeModel>(
                                        data: emp,
                                        feedback: Material(
                                          color: Colors.transparent,
                                          child: Container(
                                            width: 280,
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: cardBgColor,
                                              borderRadius: BorderRadius.circular(12),
                                              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))],
                                            ),
                                            child: Text(emp.fullName, style: TextStyle(fontWeight: FontWeight.bold, color: glass.textPrimary)),
                                          ),
                                        ),
                                        child: AppCard(
                                          backgroundColor: isDark ? const Color(0xFF1B2838) : Colors.grey.shade50,
                                          margin: const EdgeInsets.only(bottom: 8),
                                          padding: const EdgeInsets.all(10),
                                          child: Row(
                                            children: [
                                              CircleAvatar(
                                                radius: 16,
                                                backgroundColor: const Color(0xFF0F6B66).withAlpha(30),
                                                child: Text(emp.fullName.isNotEmpty ? emp.fullName[0].toUpperCase() : 'E', style: const TextStyle(color: Color(0xFF0F6B66), fontWeight: FontWeight.bold, fontSize: 12)),
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(emp.fullName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: glass.textPrimary)),
                                                    Text('${emp.employeeId} • ${emp.department ?? 'General'}', style: TextStyle(fontSize: 11, color: glass.textSecondary)),
                                                  ],
                                                ),
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.edit_outlined, size: 16),
                                                tooltip: 'Quick Edit',
                                                onPressed: () => _openQuickEdit(emp),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),
                    );
                  },
                );
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
}
