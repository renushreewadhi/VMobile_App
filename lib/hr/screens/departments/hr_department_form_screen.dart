import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';

class HrDepartmentFormScreen extends ConsumerStatefulWidget {
  final String? deptId;
  final Map<String, dynamic>? initialData;

  const HrDepartmentFormScreen({super.key, this.deptId, this.initialData});

  @override
  ConsumerState<HrDepartmentFormScreen> createState() => _HrDepartmentFormScreenState();
}

class _HrDepartmentFormScreenState extends ConsumerState<HrDepartmentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _codeController;
  late TextEditingController _descController;
  String _status = 'Active';
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final d = widget.initialData ?? {};
    _nameController = TextEditingController(text: d['name'] ?? '');
    _codeController = TextEditingController(text: d['code'] ?? '');
    _descController = TextEditingController(text: d['description'] ?? '');
    final allowedStatuses = ['Active', 'Inactive'];
    final rawStatus = d['status'] ?? 'Active';
    _status = allowedStatuses.firstWhere(
      (s) => s.toLowerCase() == rawStatus.toString().toLowerCase(),
      orElse: () => 'Active',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _onNameChanged(String val) {
    if (widget.deptId != null) return;
    if (val.trim().isNotEmpty && _codeController.text.isEmpty) {
      // Auto generate code
      final words = val.trim().split(RegExp(r'\s+'));
      final code = words.length == 1 ? words[0].substring(0, words[0].length >= 3 ? 3 : words[0].length).toUpperCase() : words.map((w) => w[0]).join('').toUpperCase();
      _codeController.text = code;
    }
  }

  Future<void> _saveDepartment() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    final apiClient = ref.read(apiClientProvider);

    final payload = {
      'name': _nameController.text.trim(),
      'code': _codeController.text.trim().toUpperCase(),
      'description': _descController.text.trim(),
      'status': _status,
    };

    try {
      if (widget.deptId != null) {
        await apiClient.put('/departments/${widget.deptId}', body: payload);
      } else {
        await apiClient.post('/departments', body: payload);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Department saved successfully')));
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save department: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.deptId != null;
    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'Edit Department' : 'Create Department')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Department Name *', border: OutlineInputBorder()),
                onChanged: _onNameChanged,
                validator: (val) => val == null || val.isEmpty ? 'Department name is required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _codeController,
                decoration: const InputDecoration(labelText: 'Department Code *', border: OutlineInputBorder()),
                validator: (val) => val == null || val.isEmpty ? 'Department code is required' : null,
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
                controller: _descController,
                decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveDepartment,
                  child: Text(_isSaving ? 'Saving...' : (isEdit ? 'Update Department' : 'Create Department')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
