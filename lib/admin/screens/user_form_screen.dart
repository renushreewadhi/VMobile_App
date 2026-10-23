import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_colors.dart';

class UserFormScreen extends ConsumerStatefulWidget {
  final String? userId;
  final Map<String, dynamic>? initialData;

  const UserFormScreen({super.key, this.userId, this.initialData});

  @override
  ConsumerState<UserFormScreen> createState() => _UserFormScreenState();
}

class _UserFormScreenState extends ConsumerState<UserFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isSaving = false;

  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  String _role = 'Employee';
  String _department = 'Engineering';
  String _mfa = 'Yes';
  String _status = 'ACTIVE';

  final List<String> _roles = ['Super Admin', 'HR Admin', 'Team Lead', 'Employee'];
  final List<String> _departments = ['Engineering', 'Human Resources', 'Sales', 'Finance', 'Marketing', 'Operations'];

  bool get _isEdit => widget.userId != null || widget.initialData != null;

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      _populateData(widget.initialData!);
    } else if (_isEdit && widget.userId != null) {
      _loadUserDetail();
    }
  }

  void _populateData(Map<String, dynamic> data) {
    _usernameController.text = data['username'] ?? '';
    _nameController.text = data['name'] ?? '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'.trim();
    _emailController.text = data['email'] ?? '';
    _phoneController.text = data['phone'] ?? '';
    _role = data['role'] ?? 'Employee';
    _department = data['department'] ?? 'Engineering';
    _mfa = data['mfa'] ?? 'Yes';
    final allowedStatuses = ['ACTIVE', 'INACTIVE'];
    final rawStatus = data['status'] ?? (data['isActive'] == false ? 'INACTIVE' : 'ACTIVE');
    _status = allowedStatuses.firstWhere(
      (s) => s.toLowerCase() == rawStatus.toString().toLowerCase(),
      orElse: () => 'ACTIVE',
    );
  }

  Future<void> _loadUserDetail() async {
    setState(() => _isLoading = true);
    try {
      final res = await ref.read(apiClientProvider).get('/users/${widget.userId}');
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

  String _roleCode(String label) {
    switch (label) {
      case 'Super Admin': return 'ADMIN';
      case 'HR Admin': return 'HR';
      case 'Team Lead': return 'TL';
      default: return 'EMPLOYEE';
    }
  }

  Future<void> _saveUser() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final apiClient = ref.read(apiClientProvider);

    final nameParts = _nameController.text.trim().split(' ');
    final firstName = nameParts.isNotEmpty ? nameParts[0] : '';
    final lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';

    final payload = {
      'username': _usernameController.text.trim(),
      'firstName': firstName,
      'lastName': lastName,
      'email': _emailController.text.trim().isNotEmpty ? _emailController.text.trim() : '${_usernameController.text.trim().toLowerCase()}@hrm.com',
      'role': _roleCode(_role),
      'department': _department,
      'phone': _phoneController.text.trim(),
      'isActive': _status == 'ACTIVE',
      'password': 'User@123'
    };

    try {
      if (_isEdit && widget.userId != null) {
        await apiClient.put('/users/${widget.userId}', data: payload);
      } else {
        await apiClient.post('/users', data: payload);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isEdit ? 'User updated successfully' : 'User created successfully')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save user: $e')));
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
        title: Text(_isEdit ? 'Edit User Account' : 'Create User Account'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('User Account Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
              const SizedBox(height: 12),
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(labelText: 'Username *', border: OutlineInputBorder()),
                validator: (val) => (val == null || val.trim().isEmpty) ? 'Username is required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Full Name *', border: OutlineInputBorder()),
                validator: (val) => (val == null || val.trim().isEmpty) ? 'Full name is required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email Address', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone Number', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _roles.contains(_role) ? _role : 'Employee',
                decoration: const InputDecoration(labelText: 'Role', border: OutlineInputBorder()),
                items: _roles.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                onChanged: (val) => setState(() => _role = val ?? 'Employee'),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _departments.contains(_department) ? _department : 'Engineering',
                decoration: const InputDecoration(labelText: 'Department', border: OutlineInputBorder()),
                items: _departments.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                onChanged: (val) => setState(() => _department = val ?? 'Engineering'),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _status,
                decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'ACTIVE', child: Text('Active')),
                  DropdownMenuItem(value: 'INACTIVE', child: Text('Inactive')),
                ],
                onChanged: (val) => setState(() => _status = val ?? 'ACTIVE'),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveUser,
                  icon: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Icon(Icons.check),
                  label: Text(_isSaving ? 'Saving...' : (_isEdit ? 'Save Changes' : 'Create User'), style: const TextStyle(fontSize: 16)),
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
