import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';

class HrCandidateAddScreen extends ConsumerStatefulWidget {
  const HrCandidateAddScreen({super.key});

  @override
  ConsumerState<HrCandidateAddScreen> createState() => _HrCandidateAddScreenState();
}

class _HrCandidateAddScreenState extends ConsumerState<HrCandidateAddScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  String _jobTitle = 'Senior Full Stack Developer';
  bool _isSaving = false;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _saveCandidate() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    final apiClient = ref.read(apiClientProvider);

    final payload = {
      'firstName': _firstNameController.text.trim(),
      'lastName': _lastNameController.text.trim(),
      'email': _emailController.text.trim(),
      'phone': _phoneController.text.trim(),
      'jobTitle': _jobTitle,
      'status': 'NEW',
    };

    try {
      await apiClient.post('/recruitment/candidates', body: payload);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Candidate added successfully')));
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
      appBar: AppBar(title: const Text('Add Candidate')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _firstNameController,
                decoration: const InputDecoration(labelText: 'First Name *', border: OutlineInputBorder()),
                validator: (val) => val == null || val.isEmpty ? 'First name is required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _lastNameController,
                decoration: const InputDecoration(labelText: 'Last Name *', border: OutlineInputBorder()),
                validator: (val) => val == null || val.isEmpty ? 'Last name is required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email *', border: OutlineInputBorder()),
                validator: (val) => val == null || !val.contains('@') ? 'Valid email is required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'Phone', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _jobTitle,
                decoration: const InputDecoration(labelText: 'Position', border: OutlineInputBorder()),
                items: ['Senior Full Stack Developer', 'UI/UX Product Designer', 'DevOps & Cloud Engineer', 'Marketing Manager'].map((j) => DropdownMenuItem(value: j, child: Text(j))).toList(),
                onChanged: (val) => setState(() => _jobTitle = val ?? 'Senior Full Stack Developer'),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveCandidate,
                  child: Text(_isSaving ? 'Saving...' : 'Add Candidate'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
