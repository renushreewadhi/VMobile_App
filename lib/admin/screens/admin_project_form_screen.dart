import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/errors/api_exception.dart';
import '../../core/theme/glass_theme.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/glass_header.dart';

class AdminProjectFormScreen extends ConsumerStatefulWidget {
  final String? projectId;
  final Map<String, dynamic>? initialData;

  const AdminProjectFormScreen({super.key, this.projectId, this.initialData});

  @override
  ConsumerState<AdminProjectFormScreen> createState() => _AdminProjectFormScreenState();
}

class _AdminProjectFormScreenState extends ConsumerState<AdminProjectFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isSaving = false;

  // Basic Information
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  String? _selectedDepartment;
  String _priority = 'MEDIUM';

  // Timeline & Leadership
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();
  String? _selectedTeamLeadId;
  final TextEditingController _descController = TextEditingController();
  String _status = 'IN_PROGRESS'; // Preserved on edit

  List<Map<String, String>> _departments = [];
  List<Map<String, String>> _teamLeads = [];
  final List<String> _priorities = ['LOW', 'MEDIUM', 'HIGH', 'CRITICAL'];

  bool get _isEdit => widget.projectId != null || widget.initialData != null;

  @override
  void initState() {
    super.initState();
    _loadLookupsAndDetail();
  }

  Future<void> _loadLookupsAndDetail() async {
    setState(() => _isLoading = true);
    final apiClient = ref.read(apiClientProvider);

    try {
      // 1. Fetch departments
      List<Map<String, String>> depts = [];
      try {
        final deptRes = await apiClient.get(ApiEndpoints.departments);
        dynamic rawDepts = deptRes is Map<String, dynamic> && deptRes.containsKey('data') ? deptRes['data'] : deptRes;
        if (rawDepts is List) {
          for (final d in rawDepts) {
            if (d is Map<String, dynamic>) {
              final id = (d['id'] ?? d['_id'])?.toString() ?? '';
              final name = (d['name'] ?? d['departmentName'])?.toString() ?? 'Department';
              if (id.isNotEmpty) depts.add({'id': id, 'name': name});
            }
          }
        }
      } catch (e) {
        debugPrint('[AdminProjectForm] Departments fetch warning: $e');
      }

      // 2. Fetch team leads
      List<Map<String, String>> tls = [];
      try {
        final tlRes = await apiClient.get(ApiEndpoints.teamLeads);
        dynamic rawTls = tlRes is Map<String, dynamic> && tlRes.containsKey('data') ? tlRes['data'] : tlRes;
        if (rawTls is List) {
          for (final item in rawTls) {
            if (item is Map<String, dynamic>) {
              final id = (item['id'] ?? item['employeeId'])?.toString() ?? '';
              final name = (item['fullName'] ?? '${item['firstName'] ?? ''} ${item['lastName'] ?? ''}').toString().trim();
              if (id.isNotEmpty) tls.add({'id': id, 'name': name.isNotEmpty ? name : 'Team Lead'});
            }
          }
        }
      } catch (e) {
        debugPrint('[AdminProjectForm] Team Leads fetch warning: $e');
      }

      if (mounted) {
        setState(() {
          _departments = depts;
          _teamLeads = tls;
        });
      }

      // 3. Populate initial data or load detail
      if (widget.initialData != null) {
        _populateData(widget.initialData!);
      } else if (_isEdit && widget.projectId != null) {
        final res = await apiClient.get(ApiEndpoints.projectDetail(widget.projectId!));
        dynamic rawData = res is Map<String, dynamic> && res.containsKey('data') ? res['data'] : res;
        if (rawData is Map<String, dynamic>) {
          _populateData(rawData);
        }
      }
    } catch (e) {
      if (widget.initialData != null) {
        _populateData(widget.initialData!);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _populateData(Map<String, dynamic> data) {
    _nameController.text = data['name']?.toString() ?? data['projectName']?.toString() ?? '';
    _codeController.text = data['projectCode']?.toString() ?? data['code']?.toString() ?? '';
    _descController.text = data['description']?.toString() ?? '';
    _startDateController.text = data['startDate']?.toString() ?? '';
    _endDateController.text = data['endDate']?.toString() ?? '';
    _status = (data['status']?.toString() ?? 'IN_PROGRESS').toUpperCase();

    final rawPriority = (data['priority']?.toString() ?? 'MEDIUM').toUpperCase();
    if (_priorities.contains(rawPriority)) {
      _priority = rawPriority;
    }

    final deptName = data['departmentName']?.toString() ?? data['department']?.toString();
    if (deptName != null && deptName.isNotEmpty) {
      _selectedDepartment = deptName;
    }

    final tlId = data['teamLeadId']?.toString() ?? data['teamLead']?['id']?.toString();
    if (tlId != null && tlId.isNotEmpty) {
      _selectedTeamLeadId = tlId;
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedDepartment == null || _selectedDepartment!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Department selection is required.'), backgroundColor: Colors.red),
      );
      return;
    }

    final startStr = _startDateController.text.trim();
    final endStr = _endDateController.text.trim();

    if (startStr.isNotEmpty && endStr.isNotEmpty) {
      try {
        final startDate = DateTime.parse(startStr);
        final endDate = DateTime.parse(endStr);
        if (endDate.isBefore(startDate)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Target End Date cannot be earlier than Start Date.'), backgroundColor: Colors.red),
          );
          return;
        }
      } catch (_) {}
    }

    setState(() => _isSaving = true);
    final apiClient = ref.read(apiClientProvider);

    final payload = {
      'name': _nameController.text.trim(),
      'projectCode': _codeController.text.trim().isEmpty ? null : _codeController.text.trim(),
      'departmentName': _selectedDepartment,
      'priority': _priority,
      'startDate': startStr.isEmpty ? null : startStr,
      'endDate': endStr.isEmpty ? null : endStr,
      'teamLeadId': (_selectedTeamLeadId == null || _selectedTeamLeadId!.isEmpty) ? null : _selectedTeamLeadId,
      'description': _descController.text.trim().isEmpty ? null : _descController.text.trim(),
      'status': _status, // Preserved on edit
    };

    try {
      if (_isEdit && widget.projectId != null) {
        await apiClient.put(ApiEndpoints.projectDetail(widget.projectId!), body: payload);
      } else {
        await apiClient.post(ApiEndpoints.projects, body: payload);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isEdit ? 'Project updated successfully' : 'Project created successfully')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        final msg = e is ApiException ? e.message : 'Failed to save project.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;

    if (_isLoading) {
      return GlassScaffold(
        appBar: GlassHeader(title: _isEdit ? 'Edit Project' : 'Create New Project'),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return GlassScaffold(
      appBar: GlassHeader(
        title: _isEdit ? 'Edit Project' : 'Create New Project',
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section 1: Basic Information
              Text('Section 1: Basic Information', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: glass.textPrimary)),
              const SizedBox(height: 14),

              // Project Name
              TextFormField(
                controller: _nameController,
                enabled: !_isSaving,
                decoration: InputDecoration(
                  labelText: 'Project Name *',
                  hintText: 'e.g. HRMS Mobile App v2',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (val) => (val == null || val.trim().isEmpty) ? 'Project name is required' : null,
              ),
              const SizedBox(height: 16),

              // Project Code & Department
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _codeController,
                      enabled: !_isSaving,
                      decoration: InputDecoration(
                        labelText: 'Project Code',
                        hintText: 'e.g. PRJ-2026-101',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _departments.any((d) => d['name'] == _selectedDepartment) ? _selectedDepartment : null,
                      decoration: InputDecoration(
                        labelText: 'Department *',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      items: _departments.map((d) {
                        return DropdownMenuItem<String>(
                          value: d['name']!,
                          child: Text(d['name']!),
                        );
                      }).toList(),
                      onChanged: _isSaving ? null : (val) => setState(() => _selectedDepartment = val),
                      validator: (val) => (val == null || val.isEmpty) ? 'Department is required' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Priority Dropdown
              DropdownButtonFormField<String>(
                initialValue: _priority,
                decoration: InputDecoration(
                  labelText: 'Priority',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: _priorities.map((p) {
                  return DropdownMenuItem<String>(
                    value: p,
                    child: Text(p),
                  );
                }).toList(),
                onChanged: _isSaving ? null : (val) => setState(() => _priority = val ?? 'MEDIUM'),
              ),
              const SizedBox(height: 24),

              // Section 2: Timeline & Leadership
              Text('Section 2: Timeline & Leadership', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: glass.textPrimary)),
              const SizedBox(height: 14),

              // Start & End Dates
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _startDateController,
                      enabled: !_isSaving,
                      decoration: InputDecoration(
                        labelText: 'Start Date (YYYY-MM-DD)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _endDateController,
                      enabled: !_isSaving,
                      decoration: InputDecoration(
                        labelText: 'Target End Date (YYYY-MM-DD)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Assign Team Lead Dropdown
              DropdownButtonFormField<String>(
                initialValue: _selectedTeamLeadId,
                decoration: InputDecoration(
                  labelText: 'Assign Team Lead (Optional)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: [
                  const DropdownMenuItem(value: '', child: Text('-- Unassigned --')),
                  ..._teamLeads.map((tl) {
                    return DropdownMenuItem<String>(
                      value: tl['id']!,
                      child: Text(tl['name']!),
                    );
                  }),
                ],
                onChanged: _isSaving ? null : (val) => setState(() => _selectedTeamLeadId = val),
              ),
              const SizedBox(height: 16),

              // Description & Objectives
              TextFormField(
                controller: _descController,
                enabled: !_isSaving,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Description & Objectives',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 32),

              // Action Buttons Row
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSaving ? null : () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppButton(
                      label: _isEdit ? 'Save Changes' : 'Create Project',
                      isLoading: _isSaving,
                      onPressed: _isSaving ? null : _save,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
