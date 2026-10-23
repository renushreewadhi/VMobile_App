import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';

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
  final TextEditingController _departmentController = TextEditingController(text: 'Engineering');
  final TextEditingController _dateController = TextEditingController(text: '2025-02-15');
  final TextEditingController _salaryController = TextEditingController(text: '1200000');

  String _employmentType = 'Full Time';
  String _employeeType = 'Probation';

  bool get _isEdit => widget.candidateId != null || widget.initialData != null;

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      _populateData(widget.initialData!);
    } else if (_isEdit && widget.candidateId != null) {
      _loadDetail();
    }
  }

  void _populateData(Map<String, dynamic> data) {
    _nameController.text = data['employeeName'] ?? data['name'] ?? '';
    _positionController.text = data['jobPosition'] ?? data['position'] ?? '';
    _departmentController.text = data['departmentName'] ?? data['department'] ?? 'Engineering';
    _dateController.text = data['startDate'] ?? '2025-02-15';
    if (data['offer'] != null) {
      _salaryController.text = '${data['offer']['salaryCtc'] ?? 1200000}';
    }
  }

  Future<void> _loadDetail() async {
    setState(() => _isLoading = true);
    try {
      final res = await ref.read(apiClientProvider).get('/onboarding/${widget.candidateId}');
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final apiClient = ref.read(apiClientProvider);

    final payload = {
      'employeeName': _nameController.text.trim(),
      'jobPosition': _positionController.text.trim(),
      'departmentName': _departmentController.text.trim(),
      'startDate': _dateController.text.trim(),
      'employmentType': _employmentType,
      'employeeType': _employeeType,
      'offer': {
        'salaryCtc': _salaryController.text.trim(),
        'probationMonths': 3,
        'noticePeriodDays': 30,
        'offerAccepted': true,
        'offerLetterProvided': true
      }
    };

    try {
      if (_isEdit && widget.candidateId != null) {
        await apiClient.put('/onboarding/${widget.candidateId}', data: payload);
      } else {
        await apiClient.post('/onboarding', data: payload);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isEdit ? 'Onboarding updated successfully' : 'Onboarding candidate added successfully')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save onboarding: $e')));
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
        title: Text(_isEdit ? 'Edit Onboarding' : 'Add New Candidate Onboarding'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Candidate & Offer Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Candidate Name *', border: OutlineInputBorder()),
                validator: (val) => (val == null || val.trim().isEmpty) ? 'Name is required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _positionController,
                decoration: const InputDecoration(labelText: 'Job Position *', border: OutlineInputBorder()),
                validator: (val) => (val == null || val.trim().isEmpty) ? 'Position is required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _departmentController,
                decoration: const InputDecoration(labelText: 'Department', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _dateController,
                decoration: const InputDecoration(labelText: 'Joining Date (YYYY-MM-DD)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _salaryController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Salary CTC', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _save,
                  icon: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Icon(Icons.check),
                  label: Text(_isSaving ? 'Saving...' : (_isEdit ? 'Save Changes' : 'Create Onboarding'), style: const TextStyle(fontSize: 16)),
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
