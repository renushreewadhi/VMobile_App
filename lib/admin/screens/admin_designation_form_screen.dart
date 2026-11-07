import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/errors/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/glass_theme.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/glass_header.dart';
import '../../core/widgets/glass_scaffold.dart';

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
  final TextEditingController _levelController = TextEditingController();
  final TextEditingController _minSalaryController = TextEditingController();
  final TextEditingController _maxSalaryController = TextEditingController();

  String? _selectedDepartmentId;
  String _status = 'Active';

  List<Map<String, String>> _departments = [];

  bool get _isEdit => widget.designationId != null || widget.initialData != null;

  @override
  void initState() {
    super.initState();
    _loadDepartmentsAndDetail();
  }

  Future<void> _loadDepartmentsAndDetail() async {
    setState(() => _isLoading = true);
    final apiClient = ref.read(apiClientProvider);

    try {
      // 1. Load Departments for Dropdown
      List<Map<String, String>> depts = [];
      try {
        final deptRes = await apiClient.get(ApiEndpoints.departments);
        dynamic rawDepts = deptRes is Map<String, dynamic> && deptRes.containsKey('data') ? deptRes['data'] : deptRes;
        if (rawDepts is List) {
          for (final d in rawDepts) {
            if (d is Map<String, dynamic>) {
              final id = (d['id'] ?? d['_id'])?.toString() ?? '';
              final name = (d['name'] ?? d['departmentName'])?.toString() ?? 'Department';
              if (id.isNotEmpty) depts.add({'id': id, 'name': name});
            }
          }
        }
      } catch (e) {
        debugPrint('[AdminDesignationForm] Departments fetch warning: $e');
      }

      if (mounted) setState(() => _departments = depts);

      // 2. Populate Initial Data or Load Detail
      if (widget.initialData != null) {
        _populateData(widget.initialData!);
      } else if (_isEdit && widget.designationId != null) {
        final res = await apiClient.get(ApiEndpoints.designations);
        dynamic rawData = res is Map<String, dynamic> && res.containsKey('data') ? res['data'] : res;
        if (rawData is List) {
          final des = rawData.firstWhere((item) => (item['id'] ?? item['_id'])?.toString() == widget.designationId, orElse: () => null);
          if (des != null && des is Map<String, dynamic>) {
            _populateData(des);
          }
        }
      }
    } catch (e) {
      if (widget.initialData != null) {
        _populateData(widget.initialData!);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _populateData(Map<String, dynamic> data) {
    _titleController.text = data['title']?.toString() ?? data['name']?.toString() ?? '';
    _levelController.text = data['level']?.toString() ?? data['band']?.toString() ?? '';
    _minSalaryController.text = data['minSalary'] != null ? data['minSalary'].toString() : '';
    _maxSalaryController.text = data['maxSalary'] != null ? data['maxSalary'].toString() : '';

    final deptId = data['departmentId']?.toString();
    if (deptId != null && deptId.isNotEmpty) {
      _selectedDepartmentId = deptId;
    }

    final allowedStatuses = ['Active', 'Inactive'];
    final rawStatus = data['status']?.toString() ?? 'Active';
    _status = allowedStatuses.firstWhere(
      (s) => s.toLowerCase() == rawStatus.toLowerCase(),
      orElse: () => 'Active',
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedDepartmentId == null || _selectedDepartmentId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Department selection is mandatory.'), backgroundColor: Colors.red),
      );
      return;
    }

    final minSal = _minSalaryController.text.trim().isNotEmpty ? double.tryParse(_minSalaryController.text.trim()) : null;
    final maxSal = _maxSalaryController.text.trim().isNotEmpty ? double.tryParse(_maxSalaryController.text.trim()) : null;

    if (minSal != null && minSal < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Minimum salary cannot be negative.'), backgroundColor: Colors.red),
      );
      return;
    }

    if (maxSal != null && maxSal < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum salary cannot be negative.'), backgroundColor: Colors.red),
      );
      return;
    }

    if (minSal != null && maxSal != null && maxSal < minSal) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum salary cannot be lower than minimum salary.'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isSaving = true);
    final apiClient = ref.read(apiClientProvider);

    final payload = {
      'title': _titleController.text.trim(),
      'level': _levelController.text.trim(),
      'departmentId': _selectedDepartmentId,
      'minSalary': minSal,
      'maxSalary': maxSal,
      'status': _status,
    };

    try {
      if (_isEdit && widget.designationId != null) {
        await apiClient.put('${ApiEndpoints.designations}/${widget.designationId}', body: payload);
      } else {
        await apiClient.post(ApiEndpoints.designations, body: payload);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isEdit ? 'Designation updated successfully' : 'Designation created successfully')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        final msg = e is ApiException ? e.message : 'Failed to save designation.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return GlassScaffold(
      appBar: GlassHeader(
        title: _isEdit ? 'Edit Designation' : 'Add New Designation',
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Hero Header Banner
                    _buildHeroHeaderBanner(),
                    const SizedBox(height: 18),

                    // Main Form Card Container
                    Container(
                      decoration: BoxDecoration(
                        color: dark ? AppColors.darkMainSurface : Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: dark ? AppColors.darkBordersAndDividers : const Color(0xFFF1F5F9)),
                        boxShadow: const [BoxShadow(color: Color.fromRGBO(15, 23, 42, 0.03), blurRadius: 16, offset: Offset(0, 4))],
                      ),
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Card Section Header
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(color: const Color(0xFFE0EDFF), borderRadius: BorderRadius.circular(10)),
                                    child: const Icon(Icons.work_outline_rounded, color: Color(0xFF2563EB), size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: const [
                                      Text('Designation Hierarchy Information', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                      Text('Enter job details and compensation bounds', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                                    ],
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(20)),
                                child: Row(
                                  children: const [
                                    Icon(Icons.info_outline, size: 12, color: Color(0xFF2563EB)),
                                    SizedBox(width: 4),
                                    Text('Fields marked * required', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Divider(height: 1, color: Color(0xFFF1F5F9)),
                          const SizedBox(height: 20),

                          // Designation Title *
                          _buildInputField(
                            'Designation Title *',
                            _titleController,
                            Icons.badge_outlined,
                            'e.g. Senior Software Engineer',
                            validator: (val) => (val == null || val.trim().isEmpty) ? 'Title is required' : null,
                          ),
                          const SizedBox(height: 16),

                          // Level / Band *
                          _buildInputField(
                            'Level / Band *',
                            _levelController,
                            Icons.military_tech_outlined,
                            'e.g. Level 2 - Senior / L3',
                            validator: (val) => (val == null || val.trim().isEmpty) ? 'Level is required' : null,
                          ),
                          const SizedBox(height: 16),

                          // Department *
                          _buildDepartmentDropdown('Department *'),
                          const SizedBox(height: 16),

                          // Salary Range Row
                          Row(
                            children: [
                              Expanded(
                                child: _buildInputField(
                                  'Minimum Salary (₹)',
                                  _minSalaryController,
                                  Icons.currency_rupee_rounded,
                                  'e.g. 45000',
                                  isNumber: true,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildInputField(
                                  'Maximum Salary (₹)',
                                  _maxSalaryController,
                                  Icons.currency_rupee_rounded,
                                  'e.g. 95000',
                                  isNumber: true,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Status Dropdown
                          _buildStatusDropdown('Status'),
                          const SizedBox(height: 28),

                          // Footer Action Buttons Bar
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              TextButton(
                                onPressed: _isSaving ? null : () => Navigator.pop(context),
                                child: const Text('Cancel', style: TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
                              ),
                              ElevatedButton.icon(
                                onPressed: _isSaving ? null : _save,
                                icon: _isSaving
                                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                    : const Icon(Icons.check_rounded, size: 18),
                                label: Text(_isEdit ? 'Update Designation' : 'Create Designation'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2563EB),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  elevation: 0,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildHeroHeaderBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF2FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E7FF)),
        boxShadow: const [BoxShadow(color: Color.fromRGBO(99, 102, 241, 0.05), blurRadius: 20, offset: Offset(0, 4))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0EDFF),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'DESIGNATION PORTAL',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF2563EB), letterSpacing: 0.5),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _isEdit ? 'Edit Designation Details' : 'Add New Designation',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF0F172A), letterSpacing: -0.5),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Define job title, organizational hierarchy level, department mapping, and salary bands.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: const [BoxShadow(color: Color.fromRGBO(37, 99, 235, 0.06), blurRadius: 10, offset: Offset(0, 2))],
            ),
            child: Column(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(color: const Color(0xFFE0EDFF), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.badge_outlined, color: Color(0xFF2563EB), size: 20),
                ),
                const SizedBox(height: 6),
                const Text('Structure & Hierarchy', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                const SizedBox(height: 2),
                Container(width: 32, height: 3, decoration: BoxDecoration(color: const Color(0xFF2563EB), borderRadius: BorderRadius.circular(2))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField(String label, TextEditingController controller, IconData icon, String hint, {bool isNumber = false, FormFieldValidator<String>? validator}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Icon(icon, size: 18, color: const Color(0xFF64748B)),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: controller,
                  enabled: !_isSaving,
                  keyboardType: isNumber ? TextInputType.number : TextInputType.text,
                  style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A), fontWeight: FontWeight.w500),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                    border: InputBorder.none,
                  ),
                  validator: validator,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDepartmentDropdown(String label) {
    final currentSelected = _departments.any((d) => d['id'] == _selectedDepartmentId) ? _selectedDepartmentId : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              const Icon(Icons.account_tree_outlined, size: 18, color: Color(0xFF64748B)),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButtonFormField<String>(
                    value: currentSelected,
                    isExpanded: true,
                    style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A), fontWeight: FontWeight.w500),
                    decoration: const InputDecoration(
                      hintText: 'Select department',
                      hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                      border: InputBorder.none,
                    ),
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B)),
                    items: _departments.map((d) {
                      return DropdownMenuItem<String>(
                        value: d['id']!,
                        child: Text(d['name']!),
                      );
                    }).toList(),
                    onChanged: _isSaving ? null : (val) => setState(() => _selectedDepartmentId = val),
                    validator: (val) => (val == null || val.isEmpty) ? 'Department selection is required' : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusDropdown(String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              const Icon(Icons.toggle_on_outlined, size: 18, color: Color(0xFF64748B)),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _status,
                    isExpanded: true,
                    style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A), fontWeight: FontWeight.w500),
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B)),
                    items: const [
                      DropdownMenuItem(value: 'Active', child: Text('Active')),
                      DropdownMenuItem(value: 'Inactive', child: Text('Inactive')),
                    ],
                    onChanged: _isSaving ? null : (val) => setState(() => _status = val ?? 'Active'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
