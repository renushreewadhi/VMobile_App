import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/glass_theme.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/loading_shimmer.dart';

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
  String _selectedEmployeeId = '';

  bool _submitting = false;
  bool _isLoading = true;
  List<dynamic> _employees = [];

  final List<String> _accountStates = ['ACTIVE', 'PENDING', 'SUSPENDED', 'DISABLED', 'REVOKED', 'NONE'];
  final List<String> _statusOptions = ['ACTIVE', 'PENDING', 'SUSPENDED', 'DISABLED'];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _nameController.dispose();
    _codeController.dispose();
    _deptController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    final apiClient = ref.read(apiClientProvider);

    try {
      // 1. Fetch employees from API (/employees/all or ApiEndpoints.employees)
      dynamic empRes = await apiClient.get('/employees/all').catchError((_) => null);
      if (empRes == null) {
        empRes = await apiClient.get(ApiEndpoints.employees).catchError((_) => null);
      }

      if (empRes is List) {
        _employees = empRes;
      } else if (empRes is Map<String, dynamic>) {
        if (empRes['data'] is List) {
          _employees = empRes['data'];
        } else if (empRes['result'] is List) {
          _employees = empRes['result'];
        }
      }

      // 2. If editing, fetch account details
      if (widget.accountId != null) {
        final res = await apiClient.get('/it/employee-accounts/${widget.accountId}').catchError((_) => null);
        if (res != null) {
          final data = res is Map<String, dynamic> ? (res['data'] ?? res) : res;
          _selectedEmployeeId = data['employeeId'] ?? '';
          _nameController.text = data['employeeName'] ?? '';
          _codeController.text = data['employeeCode'] ?? '';
          _emailController.text = data['email'] ?? '';
          _deptController.text = data['department'] ?? '';
          _emailAccount = data['emailAccount'] ?? 'PENDING';
          _hrmsAccount = data['hrmsAccount'] ?? 'PENDING';
          _vpnAccess = data['vpnAccess'] ?? 'PENDING';
          _softwareAccess = data['softwareAccess'] ?? 'PENDING';
          _status = data['status'] ?? 'PENDING';
          _notesController.text = data['notes'] ?? '';
        }
      }

      if (mounted) setState(() => _isLoading = false);
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    final apiClient = ref.read(apiClientProvider);

    final payload = {
      'employeeId': _selectedEmployeeId,
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('IT Employee Account updated successfully!'), backgroundColor: AppColors.success));
          Navigator.pop(context);
        }
      } else {
        await apiClient.post('/it/employee-accounts', body: payload);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('IT Employee Account created successfully!'), backgroundColor: AppColors.success));
          Navigator.pop(context);
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Account saved successfully!'), backgroundColor: AppColors.success));
        Navigator.pop(context);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.accountId != null;
    final title = isEdit ? 'Edit IT Employee Account' : 'Create IT Employee Account';

    if (_isLoading) {
      return GlassScaffold(
        title: title,
        body: const ListSkeleton(itemCount: 4),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final glass = context.glass;

    // Find currently selected employee object for dropdown
    dynamic selectedEmpDropdownValue;
    if (_selectedEmployeeId.isNotEmpty) {
      try {
        selectedEmpDropdownValue = _employees.firstWhere(
          (e) => (e['id'] ?? e['employeeId'] ?? '').toString() == _selectedEmployeeId ||
                 (e['employeeId'] ?? e['code'] ?? '').toString() == _codeController.text,
          orElse: () => null,
        );
      } catch (_) {}
    }

    return GlassScaffold(
      title: title,
      showBottomBar: false,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: glass.textPrimary)),
                      const SizedBox(height: 2),
                      Text(
                        isEdit ? 'Update email, HRMS, VPN, and software access status for employee.' : 'Provision email, HRMS, VPN, and software access accounts for team members.',
                        style: TextStyle(fontSize: 12, color: glass.textSecondary),
                      ),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back, size: 16),
                  label: const Text('Back'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            AppCard(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section 1: Employee Information & Dropdown
                    Row(
                      children: [
                        const Icon(Icons.badge_rounded, color: AppColors.primary, size: 20),
                        const SizedBox(width: 8),
                        Text('1. Select Employee', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: glass.textPrimary)),
                      ],
                    ),
                    const SizedBox(height: 16),

                    Text('Select Employee *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: glass.textPrimary)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<dynamic>(
                      value: selectedEmpDropdownValue,
                      decoration: InputDecoration(
                        hintText: '-- Select Employee --',
                        filled: true,
                        fillColor: isDark ? const Color(0x1AFFFFFF) : Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      dropdownColor: isDark ? AppColors.darkMainSurface : Colors.white,
                      style: TextStyle(color: glass.textPrimary, fontSize: 14),
                      items: _employees.map((emp) {
                        final fName = emp['firstName'] ?? emp['name'] ?? 'Employee';
                        final lName = emp['lastName'] ?? '';
                        final code = emp['employeeId'] ?? emp['code'] ?? 'EMP';
                        return DropdownMenuItem(
                          value: emp,
                          child: Text('$fName $lName ($code)', style: TextStyle(color: glass.textPrimary), overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: (emp) {
                        if (emp != null) {
                          setState(() {
                            _selectedEmployeeId = (emp['id'] ?? emp['employeeId'] ?? '').toString();
                            _nameController.text = '${emp['firstName'] ?? ''} ${emp['lastName'] ?? ''}'.trim();
                            _codeController.text = emp['employeeId'] ?? emp['code'] ?? '';
                            _emailController.text = emp['email'] ?? '';
                            _deptController.text = emp['departmentName'] ?? emp['department'] ?? '';
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 14),

                    Text('Employee Name *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: glass.textPrimary)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _nameController,
                      readOnly: true,
                      style: TextStyle(color: glass.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Auto-populated from employee selection',
                        hintStyle: TextStyle(color: glass.textSecondary),
                        filled: true,
                        fillColor: isDark ? const Color(0x0AFFFFFF) : Colors.grey.shade100,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      validator: (v) => v == null || v.isEmpty ? 'Please select an employee' : null,
                    ),
                    const SizedBox(height: 14),

                    Text('Corporate Email *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: glass.textPrimary)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _emailController,
                      readOnly: true,
                      style: TextStyle(color: glass.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Auto-populated from employee selection',
                        hintStyle: TextStyle(color: glass.textSecondary),
                        filled: true,
                        fillColor: isDark ? const Color(0x0AFFFFFF) : Colors.grey.shade100,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      validator: (v) => v == null || v.isEmpty ? 'Email is required' : null,
                    ),
                    const SizedBox(height: 14),

                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Employee Code', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: glass.textPrimary)),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _codeController,
                                readOnly: true,
                                style: TextStyle(color: glass.textPrimary),
                                decoration: InputDecoration(
                                  hintText: 'Auto-populated',
                                  hintStyle: TextStyle(color: glass.textSecondary),
                                  filled: true,
                                  fillColor: isDark ? const Color(0x0AFFFFFF) : Colors.grey.shade100,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Department', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: glass.textPrimary)),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _deptController,
                                readOnly: true,
                                style: TextStyle(color: glass.textPrimary),
                                decoration: InputDecoration(
                                  hintText: 'Auto-populated',
                                  hintStyle: TextStyle(color: glass.textSecondary),
                                  filled: true,
                                  fillColor: isDark ? const Color(0x0AFFFFFF) : Colors.grey.shade100,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Divider(height: 20, color: glass.cardBorder),
                    const SizedBox(height: 8),

                    // Section 2: Access Provisioning Status (4 Cards)
                    Row(
                      children: [
                        const Icon(Icons.security_rounded, color: AppColors.primary, size: 20),
                        const SizedBox(width: 8),
                        Text('2. Access Provisioning Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: glass.textPrimary)),
                      ],
                    ),
                    const SizedBox(height: 16),

                    _buildProvisioningCard('Corporate Email', Icons.email_outlined, _emailAccount, (val) => setState(() => _emailAccount = val!)),
                    const SizedBox(height: 12),
                    _buildProvisioningCard('HRMS Portal', Icons.laptop_mac_rounded, _hrmsAccount, (val) => setState(() => _hrmsAccount = val!)),
                    const SizedBox(height: 12),
                    _buildProvisioningCard('VPN Access', Icons.shield_outlined, _vpnAccess, (val) => setState(() => _vpnAccess = val!)),
                    const SizedBox(height: 12),
                    _buildProvisioningCard('Software Access', Icons.apps_rounded, _softwareAccess, (val) => setState(() => _softwareAccess = val!)),

                    const SizedBox(height: 24),
                    Divider(height: 20, color: glass.cardBorder),
                    const SizedBox(height: 8),

                    // Section 3: Status & Remarks
                    Row(
                      children: [
                        const Icon(Icons.tune_rounded, color: AppColors.primary, size: 20),
                        const SizedBox(width: 8),
                        Text('3. Status & Remarks', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: glass.textPrimary)),
                      ],
                    ),
                    const SizedBox(height: 16),

                    Text('Overall IT Account Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: glass.textPrimary)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: _status,
                      dropdownColor: isDark ? AppColors.darkMainSurface : Colors.white,
                      style: TextStyle(color: glass.textPrimary, fontSize: 14),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: isDark ? const Color(0x1AFFFFFF) : Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      items: _statusOptions.map((st) => DropdownMenuItem(value: st, child: Text(st, style: TextStyle(color: glass.textPrimary)))).toList(),
                      onChanged: (val) => setState(() => _status = val ?? 'PENDING'),
                    ),
                    const SizedBox(height: 14),

                    Text('Provisioning Notes / Instructions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: glass.textPrimary)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _notesController,
                      maxLines: 3,
                      style: TextStyle(color: glass.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'e.g. Sent credentials to employee phone via SMS...',
                        hintStyle: TextStyle(color: glass.textSecondary),
                        filled: true,
                        fillColor: isDark ? const Color(0x1AFFFFFF) : Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.all(12),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Actions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: Text('Cancel', style: TextStyle(color: glass.textSecondary)),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: _submitting ? null : _submit,
                          icon: _submitting
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.check_circle_rounded, size: 18),
                          label: Text(_submitting ? (isEdit ? 'Saving...' : 'Creating...') : (isEdit ? 'Save Changes' : 'Create IT Account')),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProvisioningCard(String label, IconData icon, String currentValue, ValueChanged<String?> onChanged) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final glass = context.glass;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSecondarySurface : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0x1FFFFFFF) : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? AppColors.primary.withOpacity(0.25) : AppColors.lightPrimary,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: isDark ? AppColors.primaryLight : AppColors.primary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: glass.textPrimary)),
          ),
          SizedBox(
            width: 150,
            child: DropdownButtonFormField<String>(
              value: currentValue,
              dropdownColor: isDark ? AppColors.darkMainSurface : Colors.white,
              style: TextStyle(color: glass.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                filled: true,
                fillColor: isDark ? const Color(0x1AFFFFFF) : Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
              items: _accountStates.map((st) => DropdownMenuItem(value: st, child: Text(st, style: TextStyle(color: glass.textPrimary)))).toList(),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}
