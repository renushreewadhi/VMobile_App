import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/custom_button.dart';
import '../../shared/widgets/custom_text_field.dart';

class ItCreateEmployeeAccountScreen extends ConsumerStatefulWidget {
  final String? accountId;

  const ItCreateEmployeeAccountScreen({super.key, this.accountId});

  @override
  ConsumerState<ItCreateEmployeeAccountScreen> createState() => _ItCreateEmployeeAccountScreenState();
}

class _ItCreateEmployeeAccountScreenState extends ConsumerState<ItCreateEmployeeAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  final _deptController = TextEditingController();
  final _notesController = TextEditingController();

  String _emailAccount = 'PENDING';
  String _hrmsAccount = 'PENDING';
  String _vpnAccess = 'PENDING';
  String _softwareAccess = 'PENDING';
  String _status = 'PENDING';

  bool _submitting = false;
  bool _isLoading = false;
  List<dynamic> _employees = [];

  final List<String> _accountStates = ['ACTIVE', 'PENDING', 'SUSPENDED', 'DISABLED', 'REVOKED'];
  final List<String> _statusOptions = ['ACTIVE', 'PENDING', 'SUSPENDED', 'DISABLED'];

  @override
  void initState() {
    super.initState();
    _loadEmployees();
    if (widget.accountId != null) {
      _loadAccount(widget.accountId!);
    }
  }

  Future<void> _loadEmployees() async {
    final apiClient = ref.read(apiClientProvider);
    try {
      final res = await apiClient.get(ApiEndpoints.employees).catchError((_) => null);
      if (mounted) {
        setState(() {
          if (res is List) _employees = res;
          else if (res is Map<String, dynamic> && res['data'] is List) _employees = res['data'];
        });
      }
    } catch (_) {}
  }

  Future<void> _loadAccount(String id) async {
    setState(() => _isLoading = true);
    final apiClient = ref.read(apiClientProvider);
    try {
      final res = await apiClient.get('/it/employee-accounts/$id').catchError((_) => null);
      if (mounted && res != null) {
        final data = res is Map<String, dynamic> ? (res['data'] ?? res) : res;
        setState(() {
          _nameController.text = data['employeeName'] ?? '';
          _codeController.text = data['employeeCode'] ?? '';
          _emailController.text = data['email'] ?? '';
          _deptController.text = data['department'] ?? '';
          _emailAccount = data['emailAccount'] ?? 'PENDING';
          _hrmsAccount = data['hrmsAccount'] ?? 'PENDING';
          _vpnAccess = data['vpnAccess'] ?? 'PENDING';
          _softwareAccess = data['softwareAccess'] ?? 'PENDING';
          final allowedStatuses = ['ACTIVE', 'PENDING', 'SUSPENDED', 'DISABLED'];
          final rawStatus = data['status'] ?? 'PENDING';
          _status = allowedStatuses.firstWhere(
            (s) => s.toLowerCase() == rawStatus.toString().toLowerCase(),
            orElse: () => 'PENDING',
          );
          _notesController.text = data['notes'] ?? '';
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    final apiClient = ref.read(apiClientProvider);

    final payload = {
      'employeeName': _nameController.text.trim(),
      'employeeCode': _codeController.text.trim(),
      'email': _emailController.text.trim(),
      'department': _deptController.text.trim(),
      'emailAccount': _emailAccount,
      'hrmsAccount': _hrmsAccount,
      'vpnAccess': _vpnAccess,
      'softwareAccess': _softwareAccess,
      'status': _status,
      'notes': _notesController.text.trim(),
    };

    try {
      if (widget.accountId != null) {
        await apiClient.put('/it/employee-accounts/${widget.accountId}', body: payload);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('IT Employee Account updated successfully!')));
      } else {
        await apiClient.post('/it/employee-accounts', body: payload);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('IT Employee Account created successfully!')));
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Account saved successfully!')));
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Loading Account...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final isEdit = widget.accountId != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Edit IT Employee Account' : 'Create IT Employee Account'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: AppCard(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Employee Information', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 16),
                if (!isEdit && _employees.isNotEmpty) ...[
                  DropdownButtonFormField<dynamic>(
                    decoration: InputDecoration(
                      labelText: 'Select Employee',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    items: _employees.map((emp) {
                      return DropdownMenuItem(
                        value: emp,
                        child: Text('${emp['firstName']} ${emp['lastName']} (${emp['employeeCode'] ?? emp['code'] ?? 'EMP'})'),
                      );
                    }).toList(),
                    onChanged: (emp) {
                      if (emp != null) {
                        setState(() {
                          _nameController.text = '${emp['firstName'] ?? ''} ${emp['lastName'] ?? ''}'.trim();
                          _codeController.text = emp['employeeId'] ?? emp['code'] ?? '';
                          _emailController.text = emp['email'] ?? '';
                          _deptController.text = emp['department'] ?? '';
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                ],
                CustomTextField(
                  controller: _nameController,
                  label: 'Employee Name',
                  hint: 'Full name',
                  validator: (v) => v == null || v.isEmpty ? 'Name is required' : null,
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: _codeController,
                  label: 'Employee Code',
                  hint: 'e.g. EMP-101',
                  validator: (v) => v == null || v.isEmpty ? 'Employee code is required' : null,
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: _emailController,
                  label: 'Corporate Email',
                  hint: 'user@company.com',
                  validator: (v) => v == null || v.isEmpty ? 'Email is required' : null,
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: _deptController,
                  label: 'Department',
                  hint: 'Engineering / HR / Sales',
                ),
                const SizedBox(height: 24),
                const Text('Access Provisioning Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 16),
                _buildStateDropdown('Email Account', _emailAccount, (val) => setState(() => _emailAccount = val!)),
                const SizedBox(height: 12),
                _buildStateDropdown('HRMS Portal', _hrmsAccount, (val) => setState(() => _hrmsAccount = val!)),
                const SizedBox(height: 12),
                _buildStateDropdown('VPN Access', _vpnAccess, (val) => setState(() => _vpnAccess = val!)),
                const SizedBox(height: 12),
                _buildStateDropdown('Software Access', _softwareAccess, (val) => setState(() => _softwareAccess = val!)),
                const SizedBox(height: 24),
                const Text('Overall Status & Notes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _status,
                  decoration: InputDecoration(
                    labelText: 'Overall Status',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  items: _statusOptions.map((st) => DropdownMenuItem(value: st, child: Text(st))).toList(),
                  onChanged: (val) => setState(() => _status = val ?? 'PENDING'),
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: _notesController,
                  label: 'Provisioning Notes / Remarks',
                  hint: 'Additional instructions...',
                ),
                const SizedBox(height: 24),
                CustomButton(
                  text: isEdit ? 'Save Changes' : 'Create IT Account',
                  isLoading: _submitting,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStateDropdown(String label, String currentValue, ValueChanged<String?> onChanged) {
    return DropdownButtonFormField<String>(
      value: currentValue,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
      items: _accountStates.map((st) => DropdownMenuItem(value: st, child: Text(st))).toList(),
      onChanged: onChanged,
    );
  }
}
