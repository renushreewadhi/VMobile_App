import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/errors/api_exception.dart';
import '../../core/theme/glass_theme.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/glass_header.dart';

class AdminCandidateEditScreen extends ConsumerStatefulWidget {
  final String candidateId;
  final bool initialIsViewOnly;
  final Map<String, dynamic>? initialData;

  const AdminCandidateEditScreen({
    super.key,
    required this.candidateId,
    this.initialIsViewOnly = false,
    this.initialData,
  });

  @override
  ConsumerState<AdminCandidateEditScreen> createState() => _AdminCandidateEditScreenState();
}

class _AdminCandidateEditScreenState extends ConsumerState<AdminCandidateEditScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isSaving = false;
  late bool _isViewOnly;

  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _experienceController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  String? _selectedJobTitle;
  String _status = 'NEW';

  List<String> _jobPositions = [];

  @override
  void initState() {
    super.initState();
    _isViewOnly = widget.initialIsViewOnly;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final apiClient = ref.read(apiClientProvider);

    try {
      // 1. Fetch available job positions
      List<String> positions = [];
      try {
        final jobRes = await apiClient.get(ApiEndpoints.jobs);
        dynamic rawJobs = jobRes is Map<String, dynamic> && jobRes.containsKey('data') ? jobRes['data'] : jobRes;
        if (rawJobs is List) {
          for (final j in rawJobs) {
            if (j is Map<String, dynamic>) {
              final t = j['title']?.toString();
              if (t != null && t.trim().isNotEmpty && !positions.contains(t)) positions.add(t);
            }
          }
        }
      } catch (_) {}

      if (mounted) setState(() => _jobPositions = positions);

      // 2. Populate candidate details
      if (widget.initialData != null) {
        _populateData(widget.initialData!);
      } else {
        final res = await apiClient.get(ApiEndpoints.candidateDetail(widget.candidateId));
        dynamic rawData = res is Map<String, dynamic> && res.containsKey('data') ? res['data'] : res;
        if (rawData is Map<String, dynamic>) {
          _populateData(rawData);
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
    _firstNameController.text = data['firstName']?.toString() ?? '';
    _lastNameController.text = data['lastName']?.toString() ?? '';
    _emailController.text = data['email']?.toString() ?? '';
    _phoneController.text = data['phone']?.toString() ?? '';
    _experienceController.text = data['experience']?.toString() ?? '';
    _notesController.text = data['notes']?.toString() ?? '';

    final job = data['jobTitle']?.toString() ?? data['position']?.toString();
    if (job != null && job.isNotEmpty) {
      _selectedJobTitle = job;
      if (!_jobPositions.contains(job)) {
        _jobPositions.insert(0, job);
      }
    } else if (_jobPositions.isNotEmpty) {
      _selectedJobTitle = _jobPositions[0];
    }

    _status = (data['status']?.toString() ?? 'NEW').toUpperCase();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final apiClient = ref.read(apiClientProvider);

    final payload = {
      'firstName': _firstNameController.text.trim(),
      'lastName': _lastNameController.text.trim(),
      'email': _emailController.text.trim(),
      'phone': _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
      'jobTitle': _selectedJobTitle,
      'experience': _experienceController.text.trim().isEmpty ? null : _experienceController.text.trim(),
      'status': _status,
      'notes': _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
    };

    try {
      await apiClient.put(ApiEndpoints.candidateDetail(widget.candidateId), body: payload);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Candidate details updated successfully!')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        final msg = e is ApiException ? e.message : 'Failed to update candidate profile.';
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
        appBar: GlassHeader(title: _isViewOnly ? 'Candidate Details' : 'Edit Candidate Profile'),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return GlassScaffold(
      appBar: GlassHeader(
        title: _isViewOnly ? 'Candidate Profile Details' : 'Edit Candidate Profile',
        actions: [
          if (_isViewOnly)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Switch to Edit Mode',
              onPressed: () => setState(() => _isViewOnly = false),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isViewOnly ? 'Candidate Information View' : 'Edit Candidate Details',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: glass.textPrimary),
              ),
              const SizedBox(height: 16),

              // First & Last Name
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _firstNameController,
                      enabled: !_isViewOnly && !_isSaving,
                      decoration: InputDecoration(
                        labelText: 'First Name *',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (val) => (val == null || val.trim().isEmpty) ? 'First name is required' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _lastNameController,
                      enabled: !_isViewOnly && !_isSaving,
                      decoration: InputDecoration(
                        labelText: 'Last Name',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Email & Phone
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _emailController,
                      enabled: !_isViewOnly && !_isSaving,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'Email Address *',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (val) => (val == null || !val.contains('@')) ? 'Valid email required' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _phoneController,
                      enabled: !_isViewOnly && !_isSaving,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'Phone Number',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Applied Position Dropdown
              DropdownButtonFormField<String>(
                initialValue: _selectedJobTitle,
                decoration: InputDecoration(
                  labelText: 'Applied Position',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: _jobPositions.map((pos) {
                  return DropdownMenuItem<String>(
                    value: pos,
                    child: Text(pos),
                  );
                }).toList(),
                onChanged: (_isViewOnly || _isSaving) ? null : (val) => setState(() => _selectedJobTitle = val),
              ),
              const SizedBox(height: 16),

              // Experience & Pipeline Status
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _experienceController,
                      enabled: !_isViewOnly && !_isSaving,
                      decoration: InputDecoration(
                        labelText: 'Years of Experience',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _status,
                      decoration: InputDecoration(
                        labelText: 'Pipeline Status',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'NEW', child: Text('New')),
                        DropdownMenuItem(value: 'SHORTLISTED', child: Text('Shortlisted')),
                        DropdownMenuItem(value: 'INTERVIEW_SCHEDULED', child: Text('Interview Scheduled')),
                        DropdownMenuItem(value: 'OFFER_EXTENDED', child: Text('Offer Extended')),
                        DropdownMenuItem(value: 'HIRED', child: Text('Hired')),
                        DropdownMenuItem(value: 'REJECTED', child: Text('Rejected')),
                      ],
                      onChanged: (_isViewOnly || _isSaving) ? null : (val) => setState(() => _status = val ?? 'NEW'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Candidate Notes
              TextFormField(
                controller: _notesController,
                enabled: !_isViewOnly && !_isSaving,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Interview & Evaluation Notes',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 32),

              // Action Footer
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(_isViewOnly ? 'Back to Candidates' : 'Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (_isViewOnly)
                    Expanded(
                      child: AppButton(
                        label: 'Edit Candidate',
                        icon: Icons.edit_outlined,
                        onPressed: () => setState(() => _isViewOnly = false),
                      ),
                    )
                  else
                    Expanded(
                      child: AppButton(
                        label: 'Update Profile',
                        isLoading: _isSaving,
                        onPressed: _isSaving ? null : _save,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
