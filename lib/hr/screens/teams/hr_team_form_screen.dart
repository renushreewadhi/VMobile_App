import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/widgets/glass_header.dart';
import '../../../core/widgets/glass_scaffold.dart';

class HrTeamFormScreen extends ConsumerStatefulWidget {
  final String? teamId;
  final Map<String, dynamic>? initialData;

  const HrTeamFormScreen({super.key, this.teamId, this.initialData});

  @override
  ConsumerState<HrTeamFormScreen> createState() => _HrTeamFormScreenState();
}

class _HrTeamFormScreenState extends ConsumerState<HrTeamFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descController;
  late TextEditingController _projectsCountController;

  String _status = 'Active';
  String _departmentId = '';
  String _teamLeadId = '';

  List<dynamic> _departments = [];
  List<dynamic> _teamLeads = [];
  bool _isLoadingDropdowns = true;
  String? _dropdownErrorMessage;
  bool _isSaving = false;

  int _requestId = 0;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    final d = widget.initialData ?? {};
    _nameController = TextEditingController(text: d['name'] ?? '');
    _descController = TextEditingController(text: d['description'] ?? '');
    _projectsCountController = TextEditingController(text: (d['activeProjectsCount'] ?? 0).toString());

    final rawStatus = (d['status'] ?? 'Active').toString().toUpperCase();
    _status = rawStatus == 'INACTIVE' ? 'Inactive' : 'Active';
    _departmentId = d['departmentId']?.toString() ?? '';
    _teamLeadId = d['teamLeadId']?.toString() ?? '';

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _checkUserAndLoad();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _projectsCountController.dispose();
    super.dispose();
  }

  void _checkUserAndLoad() {
    final authState = ref.read(authServiceProvider);
    final user = authState.user;
    if (user == null || !authState.isAuthenticated) return;
    if (_currentUserId != user.id) {
      _currentUserId = user.id;
    }
    _loadDropdownsAndTeam();
  }

  Future<void> _loadDropdownsAndTeam() async {
    final currentReq = ++_requestId;
    if (!mounted) return;
    setState(() {
      _isLoadingDropdowns = true;
      _dropdownErrorMessage = null;
    });

    final apiClient = ref.read(apiClientProvider);

    try {
      if (widget.teamId != null && widget.initialData == null) {
        final teamRes = await apiClient.get(ApiEndpoints.teamDetail(widget.teamId!));
        final teamData = teamRes is Map<String, dynamic> ? (teamRes['data'] ?? teamRes) : null;
        if (teamData != null && mounted) {
          _nameController.text = teamData['name'] ?? '';
          _descController.text = teamData['description'] ?? '';
          _projectsCountController.text = (teamData['activeProjectsCount'] ?? 0).toString();
          _departmentId = teamData['departmentId']?.toString() ?? '';
          _teamLeadId = teamData['teamLeadId']?.toString() ?? '';
          final rawStatus = (teamData['status'] ?? 'Active').toString().toUpperCase();
          _status = rawStatus == 'INACTIVE' ? 'Inactive' : 'Active';
        }
      }

      final deptRes = await apiClient.get(ApiEndpoints.departments);
      final empRes = await apiClient.get(ApiEndpoints.employees).catchError((_) => apiClient.get('/employees/all').catchError((_) => []));
      final tlRes = await apiClient.get(ApiEndpoints.teamLeads).catchError((_) => []);

      if (!mounted || currentReq != _requestId) return;

      List<dynamic> depts = deptRes is List ? deptRes : (deptRes is Map ? (deptRes['items'] ?? deptRes['data'] ?? []) : []);
      List<dynamic> emps = empRes is List ? empRes : (empRes is Map ? (empRes['items'] ?? empRes['data'] ?? []) : []);
      List<dynamic> tls = tlRes is List ? tlRes : (tlRes is Map ? (tlRes['items'] ?? tlRes['data'] ?? []) : []);

      // Filter eligible Team Leads strictly
      final filteredTLs = emps.where((e) {
        if (e is Map<String, dynamic>) {
          final r = (e['role'] ?? '').toString().toUpperCase();
          final d = (e['designation'] ?? '').toString().trim().toLowerCase();
          return r == 'TL' || r == 'TEAM_LEAD' || r == 'TEAMLEAD' || d == 'team lead' || d == 'tl';
        }
        return false;
      }).toList();

      final Map<String, dynamic> tlMap = {};
      for (var e in filteredTLs) {
        final id = e['id']?.toString() ?? e['employeeId']?.toString() ?? '';
        if (id.isNotEmpty) tlMap[id] = e;
      }
      for (var t in tls) {
        if (t is Map<String, dynamic>) {
          final id = t['id']?.toString() ?? t['employeeId']?.toString() ?? '';
          if (id.isNotEmpty && !tlMap.containsKey(id)) {
            tlMap[id] = t;
          }
        }
      }

      setState(() {
        _departments = depts;
        _teamLeads = tlMap.values.toList();

        // Reconcile selections to avoid dropdown assertion errors
        if (_departmentId.isNotEmpty) {
          final exists = _departments.any((d) => (d['id']?.toString() ?? '') == _departmentId);
          if (!exists) _departmentId = '';
        }
        if (_teamLeadId.isNotEmpty) {
          final exists = _teamLeads.any((tl) => (tl['id']?.toString() ?? tl['employeeId']?.toString() ?? '') == _teamLeadId);
          if (!exists) _teamLeadId = '';
        }

        _isLoadingDropdowns = false;
      });
    } catch (e) {
      if (!mounted || currentReq != _requestId) return;
      setState(() {
        _dropdownErrorMessage = 'Failed to load form requirements: $e';
        _isLoadingDropdowns = false;
      });
    }
  }

  Future<void> _saveTeam() async {
    if (!_formKey.currentState!.validate() || _isSaving) return;

    final projectsCount = int.tryParse(_projectsCountController.text.trim());
    if (projectsCount == null || projectsCount < 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Active projects count must be a valid non-negative integer.'), backgroundColor: Colors.red));
      return;
    }

    setState(() => _isSaving = true);
    final apiClient = ref.read(apiClientProvider);

    final selectedDept = _departments.firstWhere((d) => (d['id']?.toString() ?? '') == _departmentId, orElse: () => null);
    final selectedLead = _teamLeads.firstWhere((e) => (e['id']?.toString() ?? e['employeeId']?.toString() ?? '') == _teamLeadId, orElse: () => null);

    final String? leadName = selectedLead != null
        ? ('${selectedLead['firstName'] ?? ''} ${selectedLead['lastName'] ?? ''}'.trim().isNotEmpty
            ? '${selectedLead['firstName']} ${selectedLead['lastName']}'
            : (selectedLead['fullName'] ?? selectedLead['name'] ?? ''))
        : null;

    final payload = {
      'name': _nameController.text.trim(),
      if (_departmentId.isNotEmpty) 'departmentId': _departmentId,
      if (selectedDept != null) 'departmentName': selectedDept['name'] ?? selectedDept['departmentName'] ?? '',
      if (_teamLeadId.isNotEmpty) 'teamLeadId': _teamLeadId,
      if (leadName != null && leadName.isNotEmpty) 'teamLeadName': leadName,
      if (_descController.text.trim().isNotEmpty) 'description': _descController.text.trim(),
      'status': _status,
      'activeProjectsCount': projectsCount,
    };

    try {
      if (widget.teamId != null) {
        await apiClient.put(ApiEndpoints.teamDetail(widget.teamId!), body: payload);
      } else {
        await apiClient.post(ApiEndpoints.teams, body: payload);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(widget.teamId != null ? 'Team updated successfully' : 'Team created successfully')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save team: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.teamId != null;

    if (_isLoadingDropdowns) {
      return GlassScaffold(
        appBar: GlassHeader(title: isEdit ? 'Edit Team' : 'Create Team'),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_dropdownErrorMessage != null) {
      return GlassScaffold(
        appBar: GlassHeader(title: isEdit ? 'Edit Team' : 'Create Team'),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline_rounded, size: 54, color: Colors.red),
                const SizedBox(height: 16),
                const Text('Failed to Load Requirements', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(_dropdownErrorMessage!, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                const SizedBox(height: 24),
                ElevatedButton.icon(onPressed: _loadDropdownsAndTeam, icon: const Icon(Icons.refresh), label: const Text('Retry')),
              ],
            ),
          ),
        ),
      );
    }

    return GlassScaffold(
      appBar: GlassHeader(title: isEdit ? 'Edit Team' : 'Create Team'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Team Name *', border: OutlineInputBorder()),
                validator: (val) => val == null || val.trim().isEmpty ? 'Team name is required' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _departmentId.isEmpty ? null : _departmentId,
                decoration: const InputDecoration(labelText: 'Department', border: OutlineInputBorder()),
                items: [
                  const DropdownMenuItem<String>(value: '', child: Text('Unassigned / General')),
                  ..._departments.map((d) => DropdownMenuItem<String>(
                        value: d['id']?.toString(),
                        child: Text(d['name']?.toString() ?? d['departmentName'] ?? 'Department'),
                      )),
                ],
                onChanged: (val) => setState(() => _departmentId = val ?? ''),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _teamLeadId.isEmpty ? null : _teamLeadId,
                decoration: const InputDecoration(labelText: 'Assigned Team Lead', border: OutlineInputBorder()),
                items: [
                  const DropdownMenuItem<String>(value: '', child: Text('Unassigned / None')),
                  ..._teamLeads.map((tl) {
                    final firstName = tl['firstName'] ?? '';
                    final lastName = tl['lastName'] ?? '';
                    final name = '$firstName $lastName'.trim().isNotEmpty ? '$firstName $lastName' : (tl['fullName'] ?? tl['name'] ?? 'Team Lead');
                    return DropdownMenuItem<String>(
                      value: tl['id']?.toString() ?? tl['employeeId']?.toString(),
                      child: Text(name),
                    );
                  }),
                ],
                onChanged: (val) => setState(() => _teamLeadId = val ?? ''),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _status,
                decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
                items: ['Active', 'Inactive'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                onChanged: (val) => setState(() => _status = val ?? 'Active'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _projectsCountController,
                decoration: const InputDecoration(labelText: 'Active Projects Count', border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return null;
                  final num = int.tryParse(val.trim());
                  if (num == null || num < 0) return 'Projects count must be 0 or greater';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descController,
                decoration: const InputDecoration(labelText: 'Team Description', border: OutlineInputBorder()),
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                  onPressed: _isSaving ? null : _saveTeam,
                  child: Text(_isSaving ? 'Saving...' : (isEdit ? 'Update Team' : 'Create Team')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
