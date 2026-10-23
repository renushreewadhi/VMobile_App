import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';

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
  String _priority = 'MEDIUM';
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final d = widget.initialData ?? {};
    _nameController = TextEditingController(text: d['name'] ?? '');
    _codeController = TextEditingController(text: d['projectCode'] ?? 'PRJ-2026-105');
    _descController = TextEditingController(text: d['description'] ?? '');
    _priority = d['priority'] ?? 'MEDIUM';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _saveProject() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    final apiClient = ref.read(apiClientProvider);

    final payload = {
      'name': _nameController.text.trim(),
      'projectCode': _codeController.text.trim(),
      'description': _descController.text.trim(),
      'priority': _priority,
      'departmentId': 'd1', // default or resolved
    };

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
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save project: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.projectId != null;
    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'Edit Project' : 'Create Project')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Project Name *', border: OutlineInputBorder()),
                validator: (val) => val == null || val.isEmpty ? 'Project name is required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _codeController,
                decoration: const InputDecoration(labelText: 'Project Code *', border: OutlineInputBorder()),
                validator: (val) => val == null || val.isEmpty ? 'Project code is required' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _priority,
                decoration: const InputDecoration(labelText: 'Priority', border: OutlineInputBorder()),
                items: ['LOW', 'MEDIUM', 'HIGH', 'CRITICAL'].map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                onChanged: (val) => setState(() => _priority = val ?? 'MEDIUM'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descController,
                decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
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
