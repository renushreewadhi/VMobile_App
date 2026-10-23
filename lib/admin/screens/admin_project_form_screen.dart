import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';

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

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _codeController = TextEditingController(text: 'PRJ-2026-105');
  final TextEditingController _descController = TextEditingController();

  String _priority = 'MEDIUM';
  String _department = 'Engineering';

  final List<String> _priorities = ['LOW', 'MEDIUM', 'HIGH', 'CRITICAL'];
  final List<String> _departments = ['Engineering', 'Marketing', 'Design', 'Sales', 'Finance', 'IT & Software'];

  bool get _isEdit => widget.projectId != null || widget.initialData != null;

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      _populateData(widget.initialData!);
    } else if (_isEdit && widget.projectId != null) {
      _loadDetail();
    }
  }

  void _populateData(Map<String, dynamic> data) {
    _nameController.text = data['name'] ?? '';
    _codeController.text = data['projectCode'] ?? 'PRJ-2026-105';
    _descController.text = data['description'] ?? '';
    _priority = data['priority'] ?? 'MEDIUM';
    _department = data['departmentName'] ?? data['department'] ?? 'Engineering';
  }

  Future<void> _loadDetail() async {
    setState(() => _isLoading = true);
    try {
      final res = await ref.read(apiClientProvider).get('/projects/${widget.projectId}');
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final apiClient = ref.read(apiClientProvider);

    final payload = {
      'name': _nameController.text.trim(),
      'projectCode': _codeController.text.trim(),
      'description': _descController.text.trim(),
      'departmentName': _department,
      'priority': _priority
    };

    try {
      if (_isEdit && widget.projectId != null) {
        await apiClient.put('/projects/${widget.projectId}', data: payload);
      } else {
        await apiClient.post('/projects', data: payload);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isEdit ? 'Project updated successfully' : 'Project created successfully')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save project: $e')));
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
        title: Text(_isEdit ? 'Edit Project' : 'Create New Project'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Project Information', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Project Name *', border: OutlineInputBorder()),
                validator: (val) => (val == null || val.trim().isEmpty) ? 'Project name is required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _codeController,
                decoration: const InputDecoration(labelText: 'Project Code', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _departments.contains(_department) ? _department : _departments[0],
                decoration: const InputDecoration(labelText: 'Department', border: OutlineInputBorder()),
                items: _departments.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                onChanged: (val) => setState(() => _department = val ?? 'Engineering'),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _priority,
                decoration: const InputDecoration(labelText: 'Priority', border: OutlineInputBorder()),
                items: _priorities.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                onChanged: (val) => setState(() => _priority = val ?? 'MEDIUM'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _save,
                  icon: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Icon(Icons.check),
                  label: Text(_isSaving ? 'Saving...' : (_isEdit ? 'Save Changes' : 'Create Project'), style: const TextStyle(fontSize: 16)),
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
