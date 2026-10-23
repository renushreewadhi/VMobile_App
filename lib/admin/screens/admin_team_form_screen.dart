import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';

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

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _projectsController = TextEditingController(text: '0');

  String _status = 'Active';
  String? _departmentId;
  String? _teamLeadId;

  List<dynamic> _departments = [];
  List<dynamic> _employees = [];

  bool get _isEdit => widget.teamId != null || widget.initialData != null;

  @override
  void initState() {
    super.initState();
    _loadDropdowns();
    if (widget.initialData != null) {
      _populateData(widget.initialData!);
    } else if (_isEdit && widget.teamId != null) {
      _loadTeamDetail();
    }
  }

  void _populateData(Map<String, dynamic> data) {
    _nameController.text = data['name'] ?? '';
    _descriptionController.text = data['description'] ?? '';
    _projectsController.text = '${data['activeProjectsCount'] ?? 0}';
    final allowedStatuses = ['Active', 'Inactive'];
    final rawStatus = data['status'] ?? 'Active';
    _status = allowedStatuses.firstWhere(
      (s) => s.toLowerCase() == rawStatus.toString().toLowerCase(),
      orElse: () => 'Active',
    );
    _departmentId = data['departmentId'];
    _teamLeadId = data['teamLeadId'];
  }

  Future<void> _loadDropdowns() async {
    final apiClient = ref.read(apiClientProvider);
    try {
      final deptRes = await apiClient.get('/management/departments').catchError((_) => null);
      final empRes = await apiClient.get('/management/employees').catchError((_) => null);

      setState(() {
        _departments = deptRes is List ? deptRes : (deptRes is Map ? (deptRes['items'] ?? deptRes['data'] ?? []) : []);
        _employees = empRes is List ? empRes : (empRes is Map ? (empRes['items'] ?? empRes['data'] ?? []) : []);
      });
    } catch (_) {}
  }

  Future<void> _loadTeamDetail() async {
    setState(() => _isLoading = true);
    try {
      final res = await ref.read(apiClientProvider).get('/departments/teams/${widget.teamId}');
      if (res is Map<String, dynamic>) {
        _populateData(res);
      }
    } catch (_) {
      if (widget.initialData != null) {
        _populateData(widget.initialData!);
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveTeam() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final apiClient = ref.read(apiClientProvider);

    final selectedDept = _departments.firstWhere((d) => d['id'] == _departmentId, orElse: () => null);
    final selectedLead = _employees.firstWhere((e) => e['id'] == _teamLeadId, orElse: () => null);

    final payload = {
      'name': _nameController.text.trim(),
      'departmentId': _departmentId,
      'departmentName': selectedDept != null ? selectedDept['name'] : null,
      'teamLeadId': _teamLeadId,
      'teamLeadName': selectedLead != null ? ('${selectedLead['firstName'] ?? ''} ${selectedLead['lastName'] ?? ''}'.trim().isNotEmpty ? '${selectedLead['firstName']} ${selectedLead['lastName']}' : selectedLead['fullName']) : null,
      'description': _descriptionController.text.trim(),
      'status': _status,
      'activeProjectsCount': int.tryParse(_projectsController.text) ?? 0,
    };

    try {
      if (_isEdit && widget.teamId != null) {
        await apiClient.put('/departments/teams/${widget.teamId}', data: payload);
      } else {
        await apiClient.post('/departments/teams', data: payload);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isEdit ? 'Team updated successfully' : 'Team created successfully')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save team: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit Team' : 'Create Team'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Team Information', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Team Name *', border: OutlineInputBorder()),
                validator: (val) => (val == null || val.trim().isEmpty) ? 'Team name is required' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _departmentId,
                decoration: const InputDecoration(labelText: 'Department', border: OutlineInputBorder()),
                items: _departments.map<DropdownMenuItem<String>>((d) {
                  return DropdownMenuItem<String>(
                    value: d['id']?.toString(),
                    child: Text(d['name'] ?? 'Department'),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _departmentId = val),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _teamLeadId,
                decoration: const InputDecoration(labelText: 'Team Lead', border: OutlineInputBorder()),
                items: _employees.map<DropdownMenuItem<String>>((e) {
                  final name = '${e['firstName'] ?? ''} ${e['lastName'] ?? ''}'.trim().isNotEmpty ? '${e['firstName']} ${e['lastName']}' : (e['fullName'] ?? e['name'] ?? 'Employee');
                  return DropdownMenuItem<String>(
                    value: e['id']?.toString(),
                    child: Text(name),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _teamLeadId = val),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _status,
                decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'Active', child: Text('Active')),
                  DropdownMenuItem(value: 'Inactive', child: Text('Inactive')),
                ],
                onChanged: (val) => setState(() => _status = val ?? 'Active'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _projectsController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Active Projects Count', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Description / Notes', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveTeam,
                  icon: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Icon(Icons.check),
                  label: Text(_isSaving ? 'Saving...' : (_isEdit ? 'Save Changes' : 'Create Team'), style: const TextStyle(fontSize: 16)),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
