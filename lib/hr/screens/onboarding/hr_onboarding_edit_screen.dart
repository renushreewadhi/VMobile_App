import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/widgets/glass_header.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../shared/widgets/loading_shimmer.dart';

class HrOnboardingEditScreen extends ConsumerStatefulWidget {
  final String candidateId;
  const HrOnboardingEditScreen({super.key, required this.candidateId});

  @override
  ConsumerState<HrOnboardingEditScreen> createState() => _HrOnboardingEditScreenState();
}

class _HrOnboardingEditScreenState extends ConsumerState<HrOnboardingEditScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _positionController = TextEditingController();
  final TextEditingController _mentorController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  String _department = 'Engineering';
  String _status = 'In Progress';

  @override
  void initState() {
    super.initState();
    _loadCandidate();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _positionController.dispose();
    _mentorController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _dateController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadCandidate() async {
    setState(() => _isLoading = true);
    final apiClient = ref.read(apiClientProvider);
    try {
      final res = await apiClient.get('/onboarding/${widget.candidateId}');
      final map = res is Map<String, dynamic> ? (res['data'] ?? res) : null;

      if (map != null && mounted) {
        _nameController.text = map['employeeName'] ?? map['name'] ?? '';
        _positionController.text = map['position'] ?? '';
        _department = map['department'] ?? 'Engineering';
        _dateController.text = map['startDate'] != null ? map['startDate'].toString().substring(0, 10) : DateTime.now().toIso8601String().substring(0, 10);
        _mentorController.text = map['mentorName'] ?? map['mentor'] ?? '';
        _emailController.text = map['email'] ?? '';
        _phoneController.text = map['phone'] ?? '';
        _status = map['status'] ?? 'In Progress';
        _notesController.text = map['notes'] ?? '';
      }
      setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load candidate details: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(_dateController.text) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() {
        _dateController.text = picked.toIso8601String().substring(0, 10);
      });
    }
  }

  Future<void> _updateCandidate() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    final apiClient = ref.read(apiClientProvider);

    final payload = {
      'employeeName': _nameController.text.trim(),
      'position': _positionController.text.trim(),
      'department': _department,
      'startDate': _dateController.text.trim(),
      'mentorName': _mentorController.text.trim(),
      'email': _emailController.text.trim(),
      'phone': _phoneController.text.trim(),
      'status': _status,
      'notes': _notesController.text.trim(),
    };

    try {
      await apiClient.put('/onboarding/${widget.candidateId}', body: payload).catchError((_) {
        return apiClient.post('/onboarding/${widget.candidateId}', body: payload);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Onboarding candidate updated successfully')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update candidate: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return GlassScaffold(appBar: GlassHeader(title: 'Edit Onboarding Candidate'), body: const LoadingShimmer());
    }

    return GlassScaffold(
      appBar: GlassHeader(title: 'Edit Onboarding Candidate'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Employee Full Name *', border: OutlineInputBorder()),
                validator: (val) => val == null || val.trim().isEmpty ? 'Employee name is required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _positionController,
                decoration: const InputDecoration(labelText: 'Position / Role *', border: OutlineInputBorder()),
                validator: (val) => val == null || val.trim().isEmpty ? 'Position is required' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _department,
                decoration: const InputDecoration(labelText: 'Department *', border: OutlineInputBorder()),
                items: ['Engineering', 'Marketing', 'Sales', 'Design', 'Finance', 'Human Resources']
                    .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                    .toList(),
                onChanged: (val) => setState(() => _department = val ?? 'Engineering'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _dateController,
                decoration: InputDecoration(
                  labelText: 'Joining Date *',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(icon: const Icon(Icons.calendar_today), onPressed: _pickDate),
                ),
                readOnly: true,
                onTap: _pickDate,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email Address', border: OutlineInputBorder()),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'Phone Number', border: OutlineInputBorder()),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _mentorController,
                decoration: const InputDecoration(labelText: 'Assigned Mentor', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _status,
                decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
                items: ['In Progress', 'Completed', 'Upcoming']
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (val) => setState(() => _status = val ?? 'In Progress'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(labelText: 'Orientation & Initial Notes', border: OutlineInputBorder()),
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                  onPressed: _isSaving ? null : _updateCandidate,
                  child: Text(_isSaving ? 'Updating...' : 'Save Changes'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
