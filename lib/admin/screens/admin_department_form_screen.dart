import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';

class AdminDepartmentFormScreen extends ConsumerStatefulWidget {
  final String? deptId;
  final Map<String, dynamic>? initialData;

  const AdminDepartmentFormScreen({super.key, this.deptId, this.initialData});

  @override
  ConsumerState<AdminDepartmentFormScreen> createState() => _AdminDepartmentFormScreenState();
}

class _AdminDepartmentFormScreenState extends ConsumerState<AdminDepartmentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isSaving = false;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _descController = TextEditingController();

  String _status = 'Active';

  bool get _isEdit => widget.deptId != null || widget.initialData != null;

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      _populateData(widget.initialData!);
    } else if (_isEdit && widget.deptId != null) {
      _loadDetail();
    }
  }

  void _populateData(Map<String, dynamic> data) {
    _nameController.text = data['name'] ?? '';
    _codeController.text = data['code'] ?? '';
    _descController.text = data['description'] ?? '';
    final allowedStatuses = ['Active', 'Inactive'];
    final rawStatus = data['status'] ?? 'Active';
    _status = allowedStatuses.firstWhere(
      (s) => s.toLowerCase() == rawStatus.toString().toLowerCase(),
      orElse: () => 'Active',
    );
  }

  Future<void> _loadDetail() async {
    setState(() => _isLoading = true);
    try {
      final res = await ref.read(apiClientProvider).get('/departments');
      if (res is List) {
        final d = res.firstWhere((item) => item['id'] == widget.deptId, orElse: () => null);
        if (d != null) _populateData(d);
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
      'code': _codeController.text.trim(),
      'description': _descController.text.trim(),
      'status': _status
    };

    try {
      if (_isEdit && widget.deptId != null) {
        await apiClient.put('/departments/${widget.deptId}', data: payload);
      } else {
        await apiClient.post('/departments', data: payload);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isEdit ? 'Department updated successfully' : 'Department created successfully')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save department: $e')));
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
        title: Text(_isEdit ? 'Edit Department' : 'Add New Department'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Department Information', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Department Name *', border: OutlineInputBorder()),
                validator: (val) => (val == null || val.trim().isEmpty) ? 'Name is required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _codeController,
                decoration: const InputDecoration(labelText: 'Department Code *', border: OutlineInputBorder()),
                validator: (val) => (val == null || val.trim().isEmpty) ? 'Code is required' : null,
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
                  label: Text(_isSaving ? 'Saving...' : (_isEdit ? 'Save Changes' : 'Create Department'), style: const TextStyle(fontSize: 16)),
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
