import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/widgets/glass_header.dart';
import '../../../core/widgets/glass_scaffold.dart';

class HrCandidateAddScreen extends ConsumerStatefulWidget {
  final String? initialJobId;
  final String? initialJobTitle;

  const HrCandidateAddScreen({super.key, this.initialJobId, this.initialJobTitle});

  @override
  ConsumerState<HrCandidateAddScreen> createState() => _HrCandidateAddScreenState();
}

class _HrCandidateAddScreenState extends ConsumerState<HrCandidateAddScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  String _status = 'NEW';
  String _jobId = '';
  List<dynamic> _jobs = [];
  bool _isLoadingJobs = true;
  String? _jobsErrorMessage;
  bool _isSaving = false;

  int _requestId = 0;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _jobId = widget.initialJobId ?? '';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _checkUserAndLoad();
    });
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _checkUserAndLoad() {
    final authState = ref.read(authServiceProvider);
    final user = authState.user;
    if (user == null || !authState.isAuthenticated) return;
    if (_currentUserId != user.id) {
      _currentUserId = user.id;
    }
    _loadJobs();
  }

  Future<void> _loadJobs() async {
    final currentReq = ++_requestId;
    if (!mounted) return;
    setState(() {
      _isLoadingJobs = true;
      _jobsErrorMessage = null;
    });

    final apiClient = ref.read(apiClientProvider);
    try {
      final res = await apiClient.get('/recruitment/jobs');
      if (!mounted || currentReq != _requestId) return;

      List<dynamic> jobs = [];
      if (res is List) {
        jobs = res;
      } else if (res is Map<String, dynamic>) {
        jobs = res['items'] ?? res['data'] ?? [];
      }

      setState(() {
        _jobs = jobs;
        _isLoadingJobs = false;
        _jobsErrorMessage = null;
      });
    } catch (e) {
      if (!mounted || currentReq != _requestId) return;
      setState(() {
        _jobsErrorMessage = 'Failed to load job openings: $e';
        _isLoadingJobs = false;
      });
    }
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  Future<void> _saveCandidate() async {
    if (!_formKey.currentState!.validate() || _isSaving) return;
    setState(() => _isSaving = true);
    final apiClient = ref.read(apiClientProvider);

    final selectedJob = _jobs.firstWhere((j) => (j['id']?.toString() ?? '') == _jobId, orElse: () => null);
    final jobTitle = selectedJob != null ? (selectedJob['title'] ?? widget.initialJobTitle ?? '') : (widget.initialJobTitle ?? '');

    final payload = {
      'firstName': _firstNameController.text.trim(),
      if (_lastNameController.text.trim().isNotEmpty) 'lastName': _lastNameController.text.trim(),
      'email': _emailController.text.trim(),
      if (_phoneController.text.trim().isNotEmpty) 'phone': _phoneController.text.trim(),
      if (_jobId.isNotEmpty) 'jobId': _jobId,
      if (jobTitle.isNotEmpty) 'jobTitle': jobTitle,
      'status': _status,
      if (_notesController.text.trim().isNotEmpty) 'notes': _notesController.text.trim(),
      'source': 'HR Portal',
    };

    try {
      await apiClient.post('/recruitment/candidates', body: payload);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Candidate added successfully')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to add candidate: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authServiceProvider, (previous, next) {
      if (next.user?.id != _currentUserId) {
        _checkUserAndLoad();
      }
    });

    if (_isLoadingJobs) {
      return GlassScaffold(
        appBar: const GlassHeader(title: 'Add Candidate'),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_jobsErrorMessage != null) {
      return GlassScaffold(
        appBar: const GlassHeader(title: 'Add Candidate'),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline_rounded, size: 54, color: Colors.red),
                const SizedBox(height: 16),
                const Text('Failed to Load Jobs', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(_jobsErrorMessage!, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                const SizedBox(height: 24),
                ElevatedButton.icon(onPressed: _loadJobs, icon: const Icon(Icons.refresh), label: const Text('Retry')),
              ],
            ),
          ),
        ),
      );
    }

    return GlassScaffold(
      appBar: const GlassHeader(title: 'Add Candidate'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _firstNameController,
                decoration: const InputDecoration(labelText: 'First Name *', border: OutlineInputBorder()),
                validator: (val) => val == null || val.trim().isEmpty ? 'First name is required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _lastNameController,
                decoration: const InputDecoration(labelText: 'Last Name (Optional)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email *', border: OutlineInputBorder()),
                keyboardType: TextInputType.emailAddress,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Email is required';
                  if (!_isValidEmail(val.trim())) return 'Enter a valid email address';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'Phone', border: OutlineInputBorder()),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _jobId.isEmpty ? null : _jobId,
                decoration: const InputDecoration(labelText: 'Applied Position / Job Opening', border: OutlineInputBorder()),
                items: [
                  const DropdownMenuItem<String>(value: '', child: Text('Unassigned / General Application')),
                  ..._jobs.map((j) => DropdownMenuItem<String>(
                        value: j['id']?.toString(),
                        child: Text(j['title']?.toString() ?? 'Job Opening'),
                      )),
                ],
                onChanged: (val) => setState(() => _jobId = val ?? ''),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _status,
                decoration: const InputDecoration(labelText: 'Initial Status *', border: OutlineInputBorder()),
                items: ['NEW', 'SCREENING', 'INTERVIEW_SCHEDULED', 'INTERVIEWED', 'OFFERED', 'HIRED', 'REJECTED']
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (val) => setState(() => _status = val ?? 'NEW'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(labelText: 'Candidate Summary / Cover Note', border: OutlineInputBorder()),
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                  onPressed: _isSaving ? null : _saveCandidate,
                  child: Text(_isSaving ? 'Saving...' : 'Add Candidate'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
