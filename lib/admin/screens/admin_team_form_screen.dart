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

class AdminTeamFormScreen extends ConsumerStatefulWidget {
  final String? teamId;
  final Map<String, dynamic>? initialData;

  const AdminTeamFormScreen({super.key, this.teamId, this.initialData});

  @override
  ConsumerState<AdminTeamFormScreen> createState() => _AdminTeamFormScreenState();
}

class _AdminTeamFormScreenState extends ConsumerState<AdminTeamFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _projectsController = TextEditingController(text: '0');

  String _status = 'Active';
  String? _departmentId;
  String? _teamLeadId;

  List<dynamic> _departments = [];
  List<dynamic> _employees = [];

  // Request ID guard
  int _requestId = 0;
  String? _currentUserId;

  bool get _isEdit => widget.teamId != null || widget.initialData != null;

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

    _loadDropdownsAndDetail();
  }

  void _resetState() {
    _nameController.clear();
    _descriptionController.clear();
    _projectsController.text = '0';
    _status = 'Active';
    _departmentId = null;
    _teamLeadId = null;
    _departments = [];
    _employees = [];
  }

  void _populateData(Map<String, dynamic> data) {
    _nameController.text = data['name']?.toString() ?? '';
    _descriptionController.text = data['description']?.toString() ?? '';
    _projectsController.text = '${data['activeProjectsCount'] ?? 0}';
    final allowedStatuses = ['Active', 'Inactive'];
    final rawStatus = data['status'] ?? 'Active';
    _status = allowedStatuses.firstWhere(
      (s) => s.toLowerCase() == rawStatus.toString().toLowerCase(),
      orElse: () => 'Active',
    );
    _departmentId = data['departmentId']?.toString();
    _teamLeadId = data['teamLeadId']?.toString();
  }

  Future<void> _loadDropdownsAndDetail() async {
    final currentReq = ++_requestId;
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final apiClient = ref.read(apiClientProvider);

    try {
      final deptRes = await apiClient.get(ApiEndpoints.departments).catchError((_) => null);
      if (!mounted || currentReq != _requestId) return;

      final empRes = await apiClient.get(ApiEndpoints.employees).catchError((_) => null);
      if (!mounted || currentReq != _requestId) return;

      List<dynamic> depts = deptRes is List ? deptRes : (deptRes is Map ? (deptRes['items'] ?? deptRes['data'] ?? []) : []);
      List<dynamic> emps = empRes is List ? empRes : (empRes is Map ? (empRes['items'] ?? empRes['data'] ?? []) : []);

      if (!mounted || currentReq != _requestId) return;
      setState(() {
        _departments = depts;
        _employees = emps;
      });

      if (widget.initialData != null) {
        _populateData(widget.initialData!);
      } else if (_isEdit && widget.teamId != null) {
        final res = await apiClient.get(ApiEndpoints.teamDetail(widget.teamId!));
        if (!mounted || currentReq != _requestId) return;
        if (res is Map<String, dynamic>) {
          _populateData(res);
        }
      }

      if (!mounted || currentReq != _requestId) return;
      setState(() => _isLoading = false);
    } on ApiException catch (e) {
      if (!mounted || currentReq != _requestId) return;
      if (widget.initialData != null) {
        _populateData(widget.initialData!);
        setState(() => _isLoading = false);
      } else {
        setState(() {
          _errorMessage = e.message;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted || currentReq != _requestId) return;
      if (widget.initialData != null) {
        _populateData(widget.initialData!);
        setState(() => _isLoading = false);
      } else {
        setState(() {
          _errorMessage = 'Failed to load team form data. Please check network connection.';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveTeam() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final currentReq = ++_requestId;
    final apiClient = ref.read(apiClientProvider);

    final selectedDept = _departments.firstWhere((d) => (d['id'] ?? d['_id'])?.toString() == _departmentId, orElse: () => null);
    final selectedLead = _employees.firstWhere((e) => (e['id'] ?? e['employeeId'])?.toString() == _teamLeadId, orElse: () => null);

    final payload = {
      'name': _nameController.text.trim(),
      'departmentId': _departmentId,
      'departmentName': selectedDept != null ? selectedDept['name']?.toString() : null,
      'teamLeadId': _teamLeadId,
      'teamLeadName': selectedLead != null ? ('${selectedLead['firstName'] ?? ''} ${selectedLead['lastName'] ?? ''}'.trim().isNotEmpty ? '${selectedLead['firstName']} ${selectedLead['lastName']}' : selectedLead['fullName']) : null,
      'description': _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
      'status': _status,
      'activeProjectsCount': int.tryParse(_projectsController.text.trim()) ?? 0,
    };

    try {
      if (_isEdit && widget.teamId != null) {
        await apiClient.put(ApiEndpoints.teamDetail(widget.teamId!), body: payload);
      } else {
        await apiClient.post(ApiEndpoints.teams, body: payload);
      }

      if (!mounted || currentReq != _requestId) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isEdit ? 'Team updated successfully' : 'Team created successfully')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted || currentReq != _requestId) return;
      setState(() => _isSaving = false);
      final msg = e is ApiException ? e.message : 'Failed to save team.';
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

    return GlassScaffold(
      appBar: GlassHeader(
        title: _isEdit ? 'Edit Team' : 'Create Team',
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
                      Text('You do not have administrative permissions to configure teams.', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: glass.textSecondary)),
                    ],
                  ),
                ),
              ),
            )
          : _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null
                  ? SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline_rounded, size: 54, color: Color(0xFFEF4444)),
                            const SizedBox(height: 16),
                            Text(_errorMessage!, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: glass.textSecondary)),
                            const SizedBox(height: 24),
                            AppButton(label: 'Retry', icon: Icons.refresh_rounded, width: 140, onPressed: _loadDropdownsAndDetail),
                          ],
                        ),
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Team Information', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: glass.textPrimary)),
                            const SizedBox(height: 14),

                            // Team Name
                            TextFormField(
                              controller: _nameController,
                              enabled: !_isSaving,
                              maxLength: 50,
                              decoration: InputDecoration(
                                labelText: 'Team Name *',
                                hintText: 'e.g. Alpha Squad',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) return 'Team name is required';
                                if (val.trim().length > 50) return 'Team name cannot exceed 50 characters';
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Department Dropdown
                            DropdownButtonFormField<String>(
                              initialValue: _departments.any((d) => (d['id'] ?? d['_id'])?.toString() == _departmentId) ? _departmentId : null,
                              decoration: InputDecoration(
                                labelText: 'Department',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              items: _departments.map<DropdownMenuItem<String>>((d) {
                                final id = (d['id'] ?? d['_id'])?.toString() ?? '';
                                final name = d['name']?.toString() ?? 'Department';
                                return DropdownMenuItem<String>(
                                  value: id,
                                  child: Text(name),
                                );
                              }).toList(),
                              onChanged: _isSaving ? null : (val) => setState(() => _departmentId = val),
                            ),
                            const SizedBox(height: 16),

                            // Team Lead Dropdown
                            DropdownButtonFormField<String>(
                              initialValue: _employees.any((e) => (e['id'] ?? e['employeeId'])?.toString() == _teamLeadId) ? _teamLeadId : null,
                              decoration: InputDecoration(
                                labelText: 'Team Lead',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              items: _employees.map<DropdownMenuItem<String>>((e) {
                                final id = (e['id'] ?? e['employeeId'])?.toString() ?? '';
                                final name = '${e['firstName'] ?? ''} ${e['lastName'] ?? ''}'.trim().isNotEmpty ? '${e['firstName']} ${e['lastName']}' : (e['fullName'] ?? e['name'] ?? 'Employee');
                                return DropdownMenuItem<String>(
                                  value: id,
                                  child: Text(name),
                                );
                              }).toList(),
                              onChanged: _isSaving ? null : (val) => setState(() => _teamLeadId = val),
                            ),
                            const SizedBox(height: 16),

                            // Status Dropdown
                            DropdownButtonFormField<String>(
                              initialValue: _status,
                              decoration: InputDecoration(
                                labelText: 'Status',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'Active', child: Text('Active')),
                                DropdownMenuItem(value: 'Inactive', child: Text('Inactive')),
                              ],
                              onChanged: _isSaving ? null : (val) => setState(() => _status = val ?? 'Active'),
                            ),
                            const SizedBox(height: 16),

                            // Active Projects Count
                            TextFormField(
                              controller: _projectsController,
                              enabled: !_isSaving,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Active Projects Count',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Description
                            TextFormField(
                              controller: _descriptionController,
                              enabled: !_isSaving,
                              maxLines: 3,
                              decoration: InputDecoration(
                                labelText: 'Description / Notes',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                            const SizedBox(height: 32),

                            AppButton(
                              label: _isEdit ? 'Save Changes' : 'Create Team',
                              isLoading: _isSaving,
                              onPressed: _isSaving ? null : _saveTeam,
                            ),
                          ],
                        ),
                      ),
                    ),
    );
  }
}
