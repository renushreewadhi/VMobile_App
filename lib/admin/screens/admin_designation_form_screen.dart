import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';

class AdminDesignationFormScreen extends ConsumerStatefulWidget {
  final String? designationId;
  final Map<String, dynamic>? initialData;

  const AdminDesignationFormScreen({super.key, this.designationId, this.initialData});

  @override
  ConsumerState<AdminDesignationFormScreen> createState() => _AdminDesignationFormScreenState();
}

class _AdminDesignationFormScreenState extends ConsumerState<AdminDesignationFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isSaving = false;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _levelController = TextEditingController(text: 'Senior');
  final TextEditingController _minSalaryController = TextEditingController(text: '1200000');
  final TextEditingController _maxSalaryController = TextEditingController(text: '1800000');

  String _department = 'Engineering';
  String _status = 'Active';

  final List<String> _departments = ['Engineering', 'Human Resources', 'Sales', 'Finance', 'Marketing', 'Operations'];

  bool get _isEdit => widget.designationId != null || widget.initialData != null;

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      _populateData(widget.initialData!);
    } else if (_isEdit && widget.designationId != null) {
      _loadDetail();
    }
  }

  void _populateData(Map<String, dynamic> data) {
    _titleController.text = data['title'] ?? '';
    _levelController.text = data['level'] ?? 'Senior';
    _department = data['departmentName'] ?? data['department'] ?? 'Engineering';
    _minSalaryController.text = '${data['minSalary'] ?? 1200000}';
    _maxSalaryController.text = '${data['maxSalary'] ?? 1800000}';
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
      final res = await ref.read(apiClientProvider).get('/departments/designations');
      if (res is List) {
        final d = res.firstWhere((item) => item['id'] == widget.designationId, orElse: () => null);
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
      'title': _titleController.text.trim(),
      'level': _levelController.text.trim(),
      'departmentName': _department,
      'minSalary': double.tryParse(_minSalaryController.text) ?? 1200000,
      'maxSalary': double.tryParse(_maxSalaryController.text) ?? 1800000,
      'status': _status
    };

    try {
      if (_isEdit && widget.designationId != null) {
        await apiClient.put('/departments/designations/${widget.designationId}', data: payload);
      } else {
        await apiClient.post('/departments/designations', data: payload);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isEdit ? 'Designation updated successfully' : 'Designation created successfully')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save designation: $e')));
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
        title: Text(_isEdit ? 'Edit Designation' : 'Add New Designation'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Designation Information', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
              const SizedBox(height: 12),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Designation Title *', border: OutlineInputBorder()),
                validator: (val) => (val == null || val.trim().isEmpty) ? 'Title is required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _levelController,
                decoration: const InputDecoration(labelText: 'Level (e.g. Senior, Lead, Manager) *', border: OutlineInputBorder()),
                validator: (val) => (val == null || val.trim().isEmpty) ? 'Level is required' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _departments.contains(_department) ? _department : _departments[0],
                decoration: const InputDecoration(labelText: 'Department', border: OutlineInputBorder()),
                items: _departments.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                onChanged: (val) => setState(() => _department = val ?? 'Engineering'),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _minSalaryController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Min Salary', border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _maxSalaryController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Max Salary', border: OutlineInputBorder()),
                    ),
                  ),
                ],
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
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _save,
                  icon: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Icon(Icons.check),
                  label: Text(_isSaving ? 'Saving...' : (_isEdit ? 'Save Changes' : 'Create Designation'), style: const TextStyle(fontSize: 16)),
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
