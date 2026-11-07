import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/errors/api_exception.dart';
import '../../core/theme/glass_theme.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/glass_header.dart';

class AdminOnboardingFormScreen extends ConsumerStatefulWidget {
  final String? candidateId;
  final Map<String, dynamic>? initialData;

  const AdminOnboardingFormScreen({super.key, this.candidateId, this.initialData});

  @override
  ConsumerState<AdminOnboardingFormScreen> createState() => _AdminOnboardingFormScreenState();
}

class _AdminOnboardingFormScreenState extends ConsumerState<AdminOnboardingFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isSaving = false;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _positionController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _departmentController = TextEditingController(text: 'Engineering');
  final TextEditingController _designationController = TextEditingController(text: 'Software Engineer');
  final TextEditingController _branchController = TextEditingController(text: 'Main Office');
  final TextEditingController _managerController = TextEditingController();
  final TextEditingController _mentorController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _salaryController = TextEditingController(text: '1200000');
  final TextEditingController _probationController = TextEditingController(text: '3');
  final TextEditingController _noticeController = TextEditingController(text: '30');
  final TextEditingController _locationController = TextEditingController(text: 'Headquarters');

  String _employmentType = 'Full-Time';
  String _employeeType = 'Probation';
  final bool _offerLetterProvided = true;
  final bool _offerAccepted = true;

  bool get _isEdit => widget.candidateId != null || widget.initialData != null;

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      _populateData(widget.initialData!);
    } else if (_isEdit && widget.candidateId != null) {
      _loadDetail();
    } else {
      _dateController.text = DateTime.now().toIso8601String().substring(0, 10);
    }
  }

  void _populateData(Map<String, dynamic> data) {
    _nameController.text = data['employeeName']?.toString() ?? data['name']?.toString() ?? '';
    _positionController.text = data['jobPosition']?.toString() ?? data['position']?.toString() ?? '';
    _codeController.text = data['jobReferenceCode']?.toString() ?? data['code']?.toString() ?? '';
    _departmentController.text = data['departmentName']?.toString() ?? data['department']?.toString() ?? 'Engineering';
    _designationController.text = data['designation']?.toString() ?? '';
    _branchController.text = data['branch']?.toString() ?? 'Main Office';
    _managerController.text = data['reportingManager']?.toString() ?? '';
    _mentorController.text = data['mentorName']?.toString() ?? data['mentor']?.toString() ?? '';
    _dateController.text = data['startDate']?.toString() ?? DateTime.now().toIso8601String().substring(0, 10);
    _locationController.text = data['workLocation']?.toString() ?? 'Headquarters';

    if (data['offer'] is Map<String, dynamic>) {
      final offer = data['offer'] as Map<String, dynamic>;
      _salaryController.text = offer['salaryCtc']?.toString() ?? '1200000';
      _probationController.text = offer['probationMonths']?.toString() ?? '3';
      _noticeController.text = offer['noticePeriodDays']?.toString() ?? '30';
    }

    _employmentType = data['employmentType']?.toString() ?? 'Full-Time';
    _employeeType = data['employeeType']?.toString() ?? 'Probation';
  }

  Future<void> _loadDetail() async {
    setState(() => _isLoading = true);
    try {
      final res = await ref.read(apiClientProvider).get(ApiEndpoints.onboardingDetail(widget.candidateId!));
      dynamic rawData = res is Map<String, dynamic> && res.containsKey('data') ? res['data'] : res;
      if (rawData is Map<String, dynamic>) {
        _populateData(rawData);
      }
    } catch (_) {
      if (widget.initialData != null) {
        _populateData(widget.initialData!);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final apiClient = ref.read(apiClientProvider);

    final payload = {
      'employeeName': _nameController.text.trim(),
      'jobPosition': _positionController.text.trim(),
      'jobReferenceCode': _codeController.text.trim().isEmpty ? null : _codeController.text.trim(),
      'departmentName': _departmentController.text.trim(),
      'designation': _designationController.text.trim().isEmpty ? null : _designationController.text.trim(),
      'branch': _branchController.text.trim().isEmpty ? null : _branchController.text.trim(),
      'reportingManager': _managerController.text.trim().isEmpty ? null : _managerController.text.trim(),
      'mentorName': _mentorController.text.trim().isEmpty ? null : _mentorController.text.trim(),
      'startDate': _dateController.text.trim(),
      'employmentType': _employmentType,
      'employeeType': _employeeType,
      'workLocation': _locationController.text.trim(),
      'offer': {
        'salaryCtc': double.tryParse(_salaryController.text.trim()) ?? 1200000.0,
        'probationMonths': int.tryParse(_probationController.text.trim()) ?? 3,
        'noticePeriodDays': int.tryParse(_noticeController.text.trim()) ?? 30,
        'offerLetterProvided': _offerLetterProvided,
        'offerAccepted': _offerAccepted,
      }
    };

    try {
      if (_isEdit && widget.candidateId != null) {
        await apiClient.put(ApiEndpoints.onboardingDetail(widget.candidateId!), body: payload);
      } else {
        await apiClient.post(ApiEndpoints.onboarding, body: payload);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isEdit ? 'Onboarding record updated successfully' : 'Onboarding candidate created successfully')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        final msg = e is ApiException ? e.message : 'Failed to save onboarding record.';
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
    final glass = context.glass;

    if (_isLoading) {
      return GlassScaffold(
        appBar: GlassHeader(title: _isEdit ? 'Edit Onboarding' : 'New Onboarding Candidate'),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return GlassScaffold(
      appBar: GlassHeader(
        title: _isEdit ? 'Edit Onboarding' : 'New Onboarding Candidate',
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Candidate & Offer Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: glass.textPrimary)),
              const SizedBox(height: 16),

              // Candidate Name
              TextFormField(
                controller: _nameController,
                enabled: !_isSaving,
                decoration: InputDecoration(labelText: 'Candidate Name *', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                validator: (val) => (val == null || val.trim().isEmpty) ? 'Name is required' : null,
              ),
              const SizedBox(height: 16),

              // Job Position
              TextFormField(
                controller: _positionController,
                enabled: !_isSaving,
                decoration: InputDecoration(labelText: 'Job Position / Role *', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                validator: (val) => (val == null || val.trim().isEmpty) ? 'Position is required' : null,
              ),
              const SizedBox(height: 16),

              // Department & Designation
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _departmentController,
                      enabled: !_isSaving,
                      decoration: InputDecoration(labelText: 'Department *', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                      validator: (val) => (val == null || val.trim().isEmpty) ? 'Department is required' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _designationController,
                      enabled: !_isSaving,
                      decoration: InputDecoration(labelText: 'Designation', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Employment Type Dropdown
              DropdownButtonFormField<String>(
                initialValue: _employmentType,
                decoration: InputDecoration(labelText: 'Employment Type', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                items: const [
                  DropdownMenuItem(value: 'Full-Time', child: Text('Full-Time')),
                  DropdownMenuItem(value: 'Part-Time', child: Text('Part-Time')),
                  DropdownMenuItem(value: 'Contract', child: Text('Contract')),
                ],
                onChanged: _isSaving ? null : (val) => setState(() => _employmentType = val ?? 'Full-Time'),
              ),
              const SizedBox(height: 16),

              // Employee Type Dropdown
              DropdownButtonFormField<String>(
                initialValue: _employeeType,
                decoration: InputDecoration(labelText: 'Employee Type', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                items: const [
                  DropdownMenuItem(value: 'Probation', child: Text('Probation')),
                  DropdownMenuItem(value: 'Permanent', child: Text('Permanent')),
                  DropdownMenuItem(value: 'Intern', child: Text('Intern')),
                ],
                onChanged: _isSaving ? null : (val) => setState(() => _employeeType = val ?? 'Probation'),
              ),
              const SizedBox(height: 16),

              // Joining Date & Location
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _dateController,
                      enabled: !_isSaving,
                      decoration: InputDecoration(labelText: 'Joining Date (YYYY-MM-DD)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _locationController,
                      enabled: !_isSaving,
                      decoration: InputDecoration(labelText: 'Work Location', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Salary CTC
              TextFormField(
                controller: _salaryController,
                enabled: !_isSaving,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: 'Offer Salary / CTC (₹)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
              ),
              const SizedBox(height: 32),

              // Submit Button
              AppButton(
                label: _isEdit ? 'Save Changes' : 'Create Onboarding',
                isLoading: _isSaving,
                onPressed: _isSaving ? null : _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
