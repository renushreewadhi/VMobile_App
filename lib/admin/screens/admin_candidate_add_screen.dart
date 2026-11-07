import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/errors/api_exception.dart';
import '../../core/theme/glass_theme.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/glass_scaffold.dart';

class AdminCandidateAddScreen extends ConsumerStatefulWidget {
  final bool showAppBar;
  const AdminCandidateAddScreen({super.key, this.showAppBar = true});

  @override
  ConsumerState<AdminCandidateAddScreen> createState() => _AdminCandidateAddScreenState();
}

class _AdminCandidateAddScreenState extends ConsumerState<AdminCandidateAddScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isSaving = false;

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
    _loadJobPositions();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _experienceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadJobPositions() async {
    setState(() => _isLoading = true);
    final apiClient = ref.read(apiClientProvider);

    try {
      final res = await apiClient.get(ApiEndpoints.jobs);
      dynamic rawData = res is Map<String, dynamic> && res.containsKey('data') ? res['data'] : res;
      List<String> positions = [];

      if (rawData is List) {
        for (final item in rawData) {
          if (item is Map<String, dynamic>) {
            final title = item['title']?.toString();
            if (title != null && title.trim().isNotEmpty && !positions.contains(title)) {
              positions.add(title);
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          _jobPositions = positions;
          if (positions.isNotEmpty) _selectedJobTitle = positions[0];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveCandidate() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedJobTitle == null || _selectedJobTitle!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an applied position.'), backgroundColor: Colors.red),
      );
      return;
    }

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
      await apiClient.post(ApiEndpoints.candidates, body: payload);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Candidate added successfully!')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        final msg = e is ApiException ? e.message : 'Failed to add candidate. Please verify details and try again.';
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
      const loadingBody = Center(child: CircularProgressIndicator());
      if (!widget.showAppBar) return Material(color: Colors.transparent, child: loadingBody);
      return const GlassScaffold(title: 'Add New Candidate', body: loadingBody);
    }

    final bodyContent = SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Candidate Profile Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: glass.textPrimary)),
            const SizedBox(height: 16),

            // First & Last Name
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _firstNameController,
                    enabled: !_isSaving,
                    decoration: InputDecoration(
                      labelText: 'First Name *',
                      hintText: 'e.g. Aarav',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (val) => (val == null || val.trim().isEmpty) ? 'First name is required' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _lastNameController,
                    enabled: !_isSaving,
                    decoration: InputDecoration(
                      labelText: 'Last Name',
                      hintText: 'e.g. Sharma',
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
                    enabled: !_isSaving,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'Email Address *',
                      hintText: 'aarav@example.com',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return 'Email is required';
                      if (!val.contains('@')) return 'Enter a valid email';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _phoneController,
                    enabled: !_isSaving,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'Phone Number',
                      hintText: '+91 98765 43210',
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
                labelText: 'Applied Position *',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              items: _jobPositions.map((pos) {
                return DropdownMenuItem<String>(
                  value: pos,
                  child: Text(pos),
                );
              }).toList(),
              onChanged: _isSaving ? null : (val) => setState(() => _selectedJobTitle = val),
            ),
            const SizedBox(height: 16),

            // Experience & Initial Status
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _experienceController,
                    enabled: !_isSaving,
                    decoration: InputDecoration(
                      labelText: 'Years of Experience',
                      hintText: 'e.g. 4.5 years',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _status,
                    decoration: InputDecoration(
                      labelText: 'Initial Status',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'NEW', child: Text('New')),
                      DropdownMenuItem(value: 'SHORTLISTED', child: Text('Shortlisted')),
                      DropdownMenuItem(value: 'INTERVIEW_SCHEDULED', child: Text('Interview Scheduled')),
                    ],
                    onChanged: _isSaving ? null : (val) => setState(() => _status = val ?? 'NEW'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Summary / Cover Note
            TextFormField(
              controller: _notesController,
              enabled: !_isSaving,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Candidate Summary / Cover Note',
                hintText: 'Enter key candidate skills, interview notes, or recommendations...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 32),

            // Action Buttons Row
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSaving ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppButton(
                    label: 'Save Candidate',
                    isLoading: _isSaving,
                    onPressed: _isSaving ? null : _saveCandidate,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (!widget.showAppBar) return Material(color: Colors.transparent, child: bodyContent);

    return GlassScaffold(
      title: 'Add New Candidate',
      body: bodyContent,
    );
  }
}
