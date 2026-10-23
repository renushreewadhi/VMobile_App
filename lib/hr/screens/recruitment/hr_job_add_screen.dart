import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';

class HrJobAddScreen extends ConsumerStatefulWidget {
  const HrJobAddScreen({super.key});

  @override
  ConsumerState<HrJobAddScreen> createState() => _HrJobAddScreenState();
}

class _HrJobAddScreenState extends ConsumerState<HrJobAddScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _salaryController = TextEditingController(text: '₹12,00,000 - ₹18,00,000 / yr');
  String _department = 'Engineering';
  bool _isSaving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _salaryController.dispose();
    super.dispose();
  }

  Future<void> _saveJob() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    final apiClient = ref.read(apiClientProvider);

    final payload = {
      'title': _titleController.text.trim(),
      'departmentName': _department,
      'salaryRange': _salaryController.text.trim(),
      'employmentType': 'Full-time',
      'status': 'OPEN',
      'visibility': 'PUBLIC',
    };

    try {
      await apiClient.post('/recruitment/jobs', body: payload);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Job opening published successfully')));
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to publish job: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Post New Job Opening')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Job Title *', border: OutlineInputBorder()),
                validator: (val) => val == null || val.isEmpty ? 'Job title is required' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _department,
                decoration: const InputDecoration(labelText: 'Department', border: OutlineInputBorder()),
                items: ['Engineering', 'Design', 'Marketing', 'Sales', 'Finance'].map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                onChanged: (val) => setState(() => _department = val ?? 'Engineering'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _salaryController,
                decoration: const InputDecoration(labelText: 'Salary Range', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveJob,
                  child: Text(_isSaving ? 'Publishing...' : 'Publish Job Opening'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
