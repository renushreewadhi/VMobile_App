import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';

class AdminEmployeeFormScreen extends ConsumerStatefulWidget {
  final String? employeeId;
  final Map<String, dynamic>? initialData;

  const AdminEmployeeFormScreen({super.key, this.employeeId, this.initialData});

  @override
  ConsumerState<AdminEmployeeFormScreen> createState() => _AdminEmployeeFormScreenState();
}

class _AdminEmployeeFormScreenState extends ConsumerState<AdminEmployeeFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isSaving = false;
  int _currentStep = 1;

  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _salaryController = TextEditingController(text: '120000');
  final TextEditingController _allowancesController = TextEditingController(text: '15000');

  String _gender = 'Male';
  String _department = 'Engineering';
  String _employmentType = 'Full-Time';

  final List<String> _departments = ['Engineering', 'Human Resources', 'Sales', 'Finance', 'Marketing', 'Operations'];
  final List<String> _employmentTypes = ['Full-Time', 'Part-Time', 'Contract', 'Internship'];

  bool get _isEdit => widget.employeeId != null || widget.initialData != null;

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      _populateData(widget.initialData!);
    } else if (_isEdit && widget.employeeId != null) {
      _loadEmployeeDetail();
    }
  }

  void _populateData(Map<String, dynamic> data) {
    _firstNameController.text = data['firstName'] ?? '';
    _lastNameController.text = data['lastName'] ?? '';
    _emailController.text = data['email'] ?? '';
    _phoneController.text = data['phone'] ?? '';
    _addressController.text = data['address'] ?? '';
    _cityController.text = data['city'] ?? '';
    _salaryController.text = '${data['salary'] ?? data['basicSalary'] ?? 120000}';
    _allowancesController.text = '${data['allowances'] ?? 15000}';
    _gender = data['gender'] ?? 'Male';
    _department = data['department'] ?? 'Engineering';
    _employmentType = data['employmentType'] ?? 'Full-Time';
  }

  Future<void> _loadEmployeeDetail() async {
    setState(() => _isLoading = true);
    try {
      final res = await ref.read(apiClientProvider).get('/management/employees/${widget.employeeId}');
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
      'department': _department,
      'employmentType': _employmentType,
      'salary': double.tryParse(_salaryController.text) ?? 120000,
      'allowances': double.tryParse(_allowancesController.text) ?? 15000,
    };

    try {
      if (_isEdit && widget.employeeId != null) {
        await apiClient.put('/management/employees/${widget.employeeId}', data: payload);
      } else {
        await apiClient.post('/management/employees', data: payload);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isEdit ? 'Employee updated successfully' : 'Employee created successfully')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save employee: $e')));
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
        title: Text(_isEdit ? 'Edit Employee Record' : 'Add New Employee'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Stepper Header
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildStepIndicator(1, 'Personal'),
                  const SizedBox(width: 8),
                  _buildStepIndicator(2, 'Contact & Job'),
                ],
              ),
              const Divider(height: 32),

              if (_currentStep == 1) ...[
                const Text('Personal Information', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _firstNameController,
                        decoration: const InputDecoration(labelText: 'First Name *', border: OutlineInputBorder()),
                        validator: (val) => (val == null || val.trim().isEmpty) ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _lastNameController,
                        decoration: const InputDecoration(labelText: 'Last Name *', border: OutlineInputBorder()),
                        validator: (val) => (val == null || val.trim().isEmpty) ? 'Required' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _gender,
                  decoration: const InputDecoration(labelText: 'Gender', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'Male', child: Text('Male')),
                    DropdownMenuItem(value: 'Female', child: Text('Female')),
                    DropdownMenuItem(value: 'Other', child: Text('Other')),
                  ],
                  onChanged: (val) => setState(() => _gender = val ?? 'Male'),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () => setState(() => _currentStep = 2),
                    child: const Text('Next: Contact & Job Info'),
                  ),
                ),
              ] else ...[
                const Text('Contact & Job Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email Address *', border: OutlineInputBorder()),
                  validator: (val) => (val == null || !val.contains('@')) ? 'Valid email required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Phone Number *', border: OutlineInputBorder()),
                  validator: (val) => (val == null || val.trim().length < 10) ? 'Valid phone required' : null,
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
                  value: _employmentTypes.contains(_employmentType) ? _employmentType : _employmentTypes[0],
                  decoration: const InputDecoration(labelText: 'Employment Type', border: OutlineInputBorder()),
                  items: _employmentTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                  onChanged: (val) => setState(() => _employmentType = val ?? 'Full-Time'),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _salaryController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Basic Salary', border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _allowancesController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Allowances', border: OutlineInputBorder()),
                      ),
                    ),
                  ],
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
                        child: Text(_isSaving ? 'Saving...' : (_isEdit ? 'Save Changes' : 'Create Employee')),
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

  Widget _buildStepIndicator(int step, String label) {
    final isActive = _currentStep == step;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isActive ? AppColors.primary : Colors.grey[200],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text('$step. $label', style: TextStyle(color: isActive ? Colors.white : Colors.grey[800], fontWeight: FontWeight.bold)),
    );
  }
}
