import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/widgets/glass_header.dart';
import '../../../core/widgets/glass_scaffold.dart';

class HrProjectFormScreen extends ConsumerStatefulWidget {
  final String? projectId;
  final Map<String, dynamic>? initialData;

  const HrProjectFormScreen({super.key, this.projectId, this.initialData});

  @override
  ConsumerState<HrProjectFormScreen> createState() => _HrProjectFormScreenState();
}

class _HrProjectFormScreenState extends ConsumerState<HrProjectFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _codeController;
  late TextEditingController _descController;
  late TextEditingController _startDateController;
  late TextEditingController _endDateController;

  String _priority = 'MEDIUM';
  String _departmentId = '';
  String _teamLeadId = '';
  String _status = 'IN_PROGRESS';
  
  List<dynamic> _departments = [];
  List<dynamic> _teamLeads = [];
  bool _isLoadingData = true;
  String? _dropdownErrorMessage;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final d = widget.initialData ?? {};
    _nameController = TextEditingController(text: d['name'] ?? '');
    _codeController = TextEditingController(text: d['projectCode'] ?? '');
    _descController = TextEditingController(text: d['description'] ?? '');
    _startDateController = TextEditingController(text: d['startDate'] != null ? d['startDate'].toString().substring(0, 10) : (widget.projectId == null ? DateTime.now().toIso8601String().substring(0, 10) : ''));
    _endDateController = TextEditingController(text: d['endDate'] != null ? d['endDate'].toString().substring(0, 10) : '');
    _priority = d['priority'] ?? 'MEDIUM';
    _departmentId = d['departmentId']?.toString() ?? '';
    _teamLeadId = d['teamLeadId']?.toString() ?? '';
    _status = d['status'] ?? 'IN_PROGRESS';

    _loadData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _descController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoadingData = true;
      _dropdownErrorMessage = null;
    });

    final apiClient = ref.read(apiClientProvider);
    try {
      // If editing and status is missing, fetch project details first
      if (widget.projectId != null && _status.isEmpty) {
        final projRes = await apiClient.get('/projects/${widget.projectId}');
        final projData = projRes is Map<String, dynamic> ? (projRes['data'] ?? projRes) : null;
        if (projData != null) {
          _status = projData['status'] ?? 'IN_PROGRESS';
          if (_departmentId.isEmpty) _departmentId = projData['departmentId']?.toString() ?? '';
          if (_teamLeadId.isEmpty) _teamLeadId = projData['teamLeadId']?.toString() ?? '';
        }
      }

      final deptRes = await apiClient.get(ApiEndpoints.departments);
      final tlRes = await apiClient.get('/projects/team-leads').catchError((_) => []);

      List<dynamic> depts = deptRes is List ? deptRes : (deptRes is Map ? (deptRes['items'] ?? deptRes['data'] ?? []) : []);
      List<dynamic> tls = tlRes is List ? tlRes : (tlRes is Map ? (tlRes['items'] ?? tlRes['data'] ?? []) : []);

      if (mounted) {
        setState(() {
          _departments = depts;
          _teamLeads = tls;
          _isLoadingData = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _dropdownErrorMessage = 'Failed to load form requirements: $e';
          _isLoadingData = false;
        });
      }
    }
  }

  Future<void> _pickDate(TextEditingController controller) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(controller.text) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() {
        controller.text = picked.toIso8601String().substring(0, 10);
      });
    }
  }

  Future<void> _saveProject() async {
    if (!_formKey.currentState!.validate()) return;
    if (_departmentId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a department.'), backgroundColor: Colors.red));
      return;
    }

    if (widget.projectId != null && _status.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot establish existing project status for update.'), backgroundColor: Colors.red));
      return;
    }

    if (_startDateController.text.isNotEmpty && _endDateController.text.isNotEmpty) {
      final start = DateTime.tryParse(_startDateController.text);
      final end = DateTime.tryParse(_endDateController.text);
      if (start != null && end != null && end.isBefore(start)) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('End date cannot precede start date.'), backgroundColor: Colors.red));
        return;
      }
    }

    setState(() => _isSaving = true);
    final apiClient = ref.read(apiClientProvider);

    final Map<String, dynamic> payload = {
      'name': _nameController.text.trim(),
      if (widget.projectId == null && _codeController.text.trim().isNotEmpty) 'projectCode': _codeController.text.trim(),
      if (_descController.text.trim().isNotEmpty) 'description': _descController.text.trim(),
      'departmentId': _departmentId,
      if (_teamLeadId.isNotEmpty) 'teamLeadId': _teamLeadId,
      'priority': _priority,
      if (_startDateController.text.isNotEmpty) 'startDate': _startDateController.text.trim(),
      if (_endDateController.text.isNotEmpty) 'endDate': _endDateController.text.trim(),
    };

    if (widget.projectId != null) {
      payload['status'] = _status;
    }

    try {
      if (widget.projectId != null) {
        await apiClient.put('/projects/${widget.projectId}', body: payload);
      } else {
        await apiClient.post('/projects', body: payload);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Project saved successfully')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save project: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.projectId != null;

    if (_isLoadingData) {
      return GlassScaffold(
        appBar: GlassHeader(title: isEdit ? 'Edit Project' : 'Create Project'),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_dropdownErrorMessage != null) {
      return GlassScaffold(
        appBar: GlassHeader(title: isEdit ? 'Edit Project' : 'Create Project'),
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
                ElevatedButton.icon(onPressed: _loadData, icon: const Icon(Icons.refresh), label: const Text('Retry')),
              ],
            ),
          ),
        ),
      );
    }

    return GlassScaffold(
      appBar: GlassHeader(title: isEdit ? 'Edit Project' : 'Create Project'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Project Name *', border: OutlineInputBorder()),
                validator: (val) => val == null || val.trim().isEmpty ? 'Project name is required' : null,
              ),
              const SizedBox(height: 16),
              if (!isEdit) ...[
                TextFormField(
                  controller: _codeController,
                  decoration: const InputDecoration(labelText: 'Project Code (Optional)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
              ],
              DropdownButtonFormField<String>(
                value: _departmentId.isEmpty ? null : _departmentId,
                decoration: const InputDecoration(labelText: 'Department *', border: OutlineInputBorder()),
                items: _departments.map((d) => DropdownMenuItem<String>(
                  value: d['id']?.toString(),
                  child: Text(d['name']?.toString() ?? d['departmentName'] ?? 'Department'),
                )).toList(),
                onChanged: (val) => setState(() => _departmentId = val ?? ''),
                validator: (val) => val == null || val.isEmpty ? 'Department is required' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _teamLeadId.isEmpty ? null : _teamLeadId,
                decoration: const InputDecoration(labelText: 'Assigned Team Lead', border: OutlineInputBorder()),
                items: [
                  const DropdownMenuItem<String>(value: '', child: Text('Unassigned / None')),
                  ..._teamLeads.map((tl) => DropdownMenuItem<String>(
                        value: tl['id']?.toString(),
                        child: Text(tl['name']?.toString() ?? tl['fullName'] ?? 'Team Lead'),
                      )),
                ],
                onChanged: (val) => setState(() => _teamLeadId = val ?? ''),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _priority,
                decoration: const InputDecoration(labelText: 'Priority *', border: OutlineInputBorder()),
                items: ['LOW', 'MEDIUM', 'HIGH', 'CRITICAL'].map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                onChanged: (val) => setState(() => _priority = val ?? 'MEDIUM'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _startDateController,
                decoration: InputDecoration(
                  labelText: 'Start Date *',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(icon: const Icon(Icons.calendar_today), onPressed: () => _pickDate(_startDateController)),
                ),
                readOnly: true,
                onTap: () => _pickDate(_startDateController),
                validator: (val) => val == null || val.trim().isEmpty ? 'Start date is required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _endDateController,
                decoration: InputDecoration(
                  labelText: 'End Date',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(icon: const Icon(Icons.calendar_today), onPressed: () => _pickDate(_endDateController)),
                ),
                readOnly: true,
                onTap: () => _pickDate(_endDateController),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descController,
                decoration: const InputDecoration(labelText: 'Description & Objectives', border: OutlineInputBorder()),
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                  onPressed: _isSaving ? null : _saveProject,
                  child: Text(_isSaving ? 'Saving...' : (isEdit ? 'Update Project' : 'Create Project')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
