import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';

class HrEmployeeFormScreen extends ConsumerStatefulWidget {
  final String? employeeId;
  final Map<String, dynamic>? initialData;

  const HrEmployeeFormScreen({super.key, this.employeeId, this.initialData});

  @override
  ConsumerState<HrEmployeeFormScreen> createState() => _HrEmployeeFormScreenState();
}

class _HrEmployeeFormScreenState extends ConsumerState<HrEmployeeFormScreen> {
  final _formKey = GlobalKey<FormState>();
  int _currentStep = 1;

  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  late TextEditingController _cityController;
  late TextEditingController _salaryController;
  String _gender = 'Male';
  String _employmentType = 'Full-Time';
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final d = widget.initialData ?? {};
    _firstNameController = TextEditingController(text: d['firstName'] ?? '');
    _lastNameController = TextEditingController(text: d['lastName'] ?? '');
    _emailController = TextEditingController(text: d['email'] ?? '');
    _phoneController = TextEditingController(text: d['phone'] ?? '');
    _addressController = TextEditingController(text: d['address'] ?? '');
    _cityController = TextEditingController(text: d['city'] ?? '');
    _salaryController = TextEditingController(text: (d['salary'] ?? d['basicSalary'] ?? 120000).toString());
    _gender = d['gender'] ?? 'Male';
    _employmentType = d['employmentType'] ?? 'Full-Time';
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _salaryController.dispose();
    super.dispose();
  }

  Future<void> _saveEmployee() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    final apiClient = ref.read(apiClientProvider);

    final payload = {
      'firstName': _firstNameController.text.trim(),
      'lastName': _lastNameController.text.trim(),
      'email': _emailController.text.trim(),
      'phone': _phoneController.text.trim(),
      'gender': _gender,
      'address': _addressController.text.trim(),
      'city': _cityController.text.trim(),
      'employmentType': _employmentType,
      'salary': double.tryParse(_salaryController.text) ?? 120000,
    };

    try {
      if (widget.employeeId != null) {
        await apiClient.put('/management/employees/${widget.employeeId}', body: payload);
      } else {
        await apiClient.post('/management/employees', body: payload);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Employee saved successfully')));
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save employee: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.employeeId != null;
    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'Edit Employee' : 'Add Employee')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Step indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Step $_currentStep of 2', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                ],
              ),
              const SizedBox(height: 16),
              if (_currentStep == 1) ...[
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
                  decoration: const InputDecoration(labelText: 'Email Address *', border: OutlineInputBorder()),
                  validator: (val) => val == null || !val.contains('@') ? 'Valid email is required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(labelText: 'Phone Number *', border: OutlineInputBorder()),
                  validator: (val) => val == null || val.length < 10 ? 'Valid phone number required' : null,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => setState(() => _currentStep = 2),
                    child: const Text('Next Step'),
                  ),
                ),
              ] else ...[
                TextFormField(
                  controller: _addressController,
                  decoration: const InputDecoration(labelText: 'Address', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _cityController,
                  decoration: const InputDecoration(labelText: 'City', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _salaryController,
                  decoration: const InputDecoration(labelText: 'Basic Salary', border: OutlineInputBorder()),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => setState(() => _currentStep = 1),
                        child: const Text('Back'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveEmployee,
                        child: Text(_isSaving ? 'Saving...' : (isEdit ? 'Update Employee' : 'Create Employee')),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
