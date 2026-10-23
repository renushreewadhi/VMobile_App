import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';

class HrOnboardingAddScreen extends ConsumerStatefulWidget {
  const HrOnboardingAddScreen({super.key});

  @override
  ConsumerState<HrOnboardingAddScreen> createState() => _HrOnboardingAddScreenState();
}

class _HrOnboardingAddScreenState extends ConsumerState<HrOnboardingAddScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _positionController = TextEditingController();
  final TextEditingController _mentorController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  String _department = 'Engineering';
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _positionController.dispose();
    _mentorController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _saveOnboarding() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    final apiClient = ref.read(apiClientProvider);

    final payload = {
      'employeeName': _nameController.text.trim(),
      'position': _positionController.text.trim(),
      'department': _department,
      'mentorName': _mentorController.text.trim(),
      'email': _emailController.text.trim(),
      'status': 'In Progress',
      'progress': 25,
    };

    try {
      await apiClient.post('/onboarding', body: payload);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Onboarding candidate added')));
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to add candidate: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Onboarding Candidate')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Employee Name *', border: OutlineInputBorder()),
                validator: (val) => val == null || val.isEmpty ? 'Name is required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _positionController,
                decoration: const InputDecoration(labelText: 'Position *', border: OutlineInputBorder()),
                validator: (val) => val == null || val.isEmpty ? 'Position is required' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _department,
                decoration: const InputDecoration(labelText: 'Department', border: OutlineInputBorder()),
                items: ['Engineering', 'Marketing', 'Sales', 'Design', 'Finance', 'Human Resources'].map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                onChanged: (val) => setState(() => _department = val ?? 'Engineering'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _mentorController,
                decoration: const InputDecoration(labelText: 'Mentor Name', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveOnboarding,
                  child: Text(_isSaving ? 'Saving...' : 'Add Onboarding Candidate'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
