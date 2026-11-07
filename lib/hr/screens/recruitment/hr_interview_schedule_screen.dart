import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/widgets/glass_header.dart';
import '../../../core/widgets/glass_scaffold.dart';

class HrInterviewScheduleScreen extends ConsumerStatefulWidget {
  final String? initialCandidateId;
  final String? initialCandidateName;

  const HrInterviewScheduleScreen({super.key, this.initialCandidateId, this.initialCandidateName});

  @override
  ConsumerState<HrInterviewScheduleScreen> createState() => _HrInterviewScheduleScreenState();
}

class _HrInterviewScheduleScreenState extends ConsumerState<HrInterviewScheduleScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _timeController = TextEditingController(text: '10:00');
  final TextEditingController _durationController = TextEditingController(text: '60');
  final TextEditingController _linkController = TextEditingController();

  String _candidateId = '';
  String _jobId = '';
  String _interviewerId = '';
  String _round = 'SCREENING';
  String _interviewType = 'ONLINE';

  List<dynamic> _candidates = [];
  List<dynamic> _jobs = [];
  List<dynamic> _employees = [];

  bool _isLoading = true;
  String? _errorMessage;
  bool _isSaving = false;

  int _requestId = 0;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _candidateId = widget.initialCandidateId ?? '';
    _dateController.text = DateTime.now().add(const Duration(days: 1)).toIso8601String().substring(0, 10);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _checkUserAndLoad();
    });
  }

  @override
  void dispose() {
    _dateController.dispose();
    _timeController.dispose();
    _durationController.dispose();
    _linkController.dispose();
    super.dispose();
  }

  void _checkUserAndLoad() {
    final authState = ref.read(authServiceProvider);
    final user = authState.user;
    if (user == null || !authState.isAuthenticated) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'No authenticated user found.';
      });
      return;
    }

    if (_currentUserId != user.id) {
      _currentUserId = user.id;
    }
    _loadDropdowns();
  }

  Future<void> _loadDropdowns() async {
    final currentReq = ++_requestId;
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final apiClient = ref.read(apiClientProvider);
    try {
      final candRes = await apiClient.get('/recruitment/candidates');
      final jobRes = await apiClient.get('/recruitment/jobs');
      final empRes = await apiClient.get(ApiEndpoints.employees).catchError((_) => apiClient.get('/employees/all'));

      if (!mounted || currentReq != _requestId) return;

      List<dynamic> candidates = candRes is List ? candRes : (candRes is Map ? (candRes['items'] ?? candRes['data'] ?? []) : []);
      List<dynamic> jobs = jobRes is List ? jobRes : (jobRes is Map ? (jobRes['items'] ?? jobRes['data'] ?? []) : []);
      List<dynamic> employees = empRes is List ? empRes : (empRes is Map ? (empRes['items'] ?? empRes['data'] ?? []) : []);

      // Verify initial candidate ID exists in loaded list
      if (_candidateId.isNotEmpty) {
        final exists = candidates.any((c) => (c['id']?.toString() ?? '') == _candidateId);
        if (!exists) _candidateId = '';
      }

      setState(() {
        _candidates = candidates;
        _jobs = jobs;
        _employees = employees;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted || currentReq != _requestId) return;
      setState(() {
        _errorMessage = 'Failed to load scheduling requirements: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() {
        _dateController.text = picked.toIso8601String().substring(0, 10);
      });
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      final hour = picked.hour.toString().padLeft(2, '0');
      final minute = picked.minute.toString().padLeft(2, '0');
      setState(() {
        _timeController.text = '$hour:$minute';
      });
    }
  }

  Future<void> _scheduleInterview() async {
    if (!_formKey.currentState!.validate() || _isSaving) return;
    if (_candidateId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a candidate.'), backgroundColor: Colors.red));
      return;
    }

    final scheduledAtStr = '${_dateController.text.trim()}T${_timeController.text.trim()}:00';
    final parsedDate = DateTime.tryParse(scheduledAtStr);
    if (parsedDate == null || parsedDate.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Interview scheduled date and time must be in the future.'), backgroundColor: Colors.red));
      return;
    }

    final selectedCandidate = _candidates.firstWhere((c) => (c['id']?.toString() ?? '') == _candidateId, orElse: () => null);
    final candidateName = selectedCandidate != null ? ('${selectedCandidate['firstName'] ?? ''} ${selectedCandidate['lastName'] ?? ''}'.trim().isNotEmpty ? '${selectedCandidate['firstName']} ${selectedCandidate['lastName']}' : (selectedCandidate['name'] ?? widget.initialCandidateName ?? 'Candidate')) : (widget.initialCandidateName ?? 'Candidate');

    final selectedJob = _jobs.firstWhere((j) => (j['id']?.toString() ?? '') == _jobId, orElse: () => null);
    final jobTitle = selectedJob != null ? (selectedJob['title'] ?? '') : '';

    final selectedEmp = _employees.firstWhere((e) => (e['id']?.toString() ?? e['employeeId']?.toString() ?? '') == _interviewerId, orElse: () => null);
    final interviewerName = selectedEmp != null ? ('${selectedEmp['firstName'] ?? ''} ${selectedEmp['lastName'] ?? ''}'.trim().isNotEmpty ? '${selectedEmp['firstName']} ${selectedEmp['lastName']}' : (selectedEmp['name'] ?? 'Interviewer')) : '';

    setState(() => _isSaving = true);
    final apiClient = ref.read(apiClientProvider);

    final payload = {
      'candidateId': _candidateId,
      'candidateName': candidateName,
      if (_jobId.isNotEmpty) 'jobId': _jobId,
      if (jobTitle.isNotEmpty) 'jobTitle': jobTitle,
      if (_interviewerId.isNotEmpty) 'interviewerId': _interviewerId,
      if (interviewerName.isNotEmpty) 'interviewerName': interviewerName,
      'scheduledAt': parsedDate.toIso8601String(),
      'round': _round,
      'interviewType': _interviewType,
      'status': 'SCHEDULED',
      'durationMinutes': int.tryParse(_durationController.text.trim()) ?? 60,
      if (_linkController.text.trim().isNotEmpty) 'meetingLink': _linkController.text.trim(),
    };

    try {
      await apiClient.post('/recruitment/interviews', body: payload);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Interview scheduled successfully')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to schedule interview: $e'), backgroundColor: Colors.red));
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

    if (_isLoading) {
      return GlassScaffold(
        appBar: const GlassHeader(title: 'Schedule Interview'),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return GlassScaffold(
        appBar: const GlassHeader(title: 'Schedule Interview'),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline_rounded, size: 54, color: Colors.red),
                const SizedBox(height: 16),
                const Text('Failed to Load Requirements', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(_errorMessage!, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                const SizedBox(height: 24),
                ElevatedButton.icon(onPressed: _loadDropdowns, icon: const Icon(Icons.refresh), label: const Text('Retry')),
              ],
            ),
          ),
        ),
      );
    }

    return GlassScaffold(
      appBar: const GlassHeader(title: 'Schedule Interview'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                value: _candidateId.isEmpty ? null : _candidateId,
                decoration: const InputDecoration(labelText: 'Candidate *', border: OutlineInputBorder()),
                items: [
                  const DropdownMenuItem<String>(value: '', child: Text('Select Candidate *')),
                  ..._candidates.map((c) {
                    final name = '${c['firstName'] ?? ''} ${c['lastName'] ?? ''}'.trim();
                    return DropdownMenuItem<String>(
                      value: c['id']?.toString(),
                      child: Text(name.isNotEmpty ? name : (c['name']?.toString() ?? 'Candidate')),
                    );
                  }),
                ],
                onChanged: (val) => setState(() => _candidateId = val ?? ''),
                validator: (val) => val == null || val.isEmpty ? 'Candidate is required' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _jobId.isEmpty ? null : _jobId,
                decoration: const InputDecoration(labelText: 'Job Opening', border: OutlineInputBorder()),
                items: [
                  const DropdownMenuItem<String>(value: '', child: Text('Unassigned / None')),
                  ..._jobs.map((j) => DropdownMenuItem<String>(
                        value: j['id']?.toString(),
                        child: Text(j['title']?.toString() ?? 'Job Opening'),
                      )),
                ],
                onChanged: (val) => setState(() => _jobId = val ?? ''),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _interviewerId.isEmpty ? null : _interviewerId,
                decoration: const InputDecoration(labelText: 'Interviewer', border: OutlineInputBorder()),
                items: [
                  const DropdownMenuItem<String>(value: '', child: Text('Unassigned / None')),
                  ..._employees.map((e) {
                    final name = '${e['firstName'] ?? ''} ${e['lastName'] ?? ''}'.trim();
                    return DropdownMenuItem<String>(
                      value: e['id']?.toString() ?? e['employeeId']?.toString(),
                      child: Text(name.isNotEmpty ? name : (e['name']?.toString() ?? 'Interviewer')),
                    );
                  }),
                ],
                onChanged: (val) => setState(() => _interviewerId = val ?? ''),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _dateController,
                      decoration: InputDecoration(
                        labelText: 'Date *',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(icon: const Icon(Icons.calendar_today), onPressed: _pickDate),
                      ),
                      readOnly: true,
                      onTap: _pickDate,
                      validator: (val) => val == null || val.isEmpty ? 'Date is required' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _timeController,
                      decoration: InputDecoration(
                        labelText: 'Time (HH:mm) *',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(icon: const Icon(Icons.access_time), onPressed: _pickTime),
                      ),
                      readOnly: true,
                      onTap: _pickTime,
                      validator: (val) => val == null || val.isEmpty ? 'Time is required' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _round,
                decoration: const InputDecoration(labelText: 'Interview Round *', border: OutlineInputBorder()),
                items: ['SCREENING', 'TECHNICAL', 'HR', 'FINAL'].map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                onChanged: (val) => setState(() => _round = val ?? 'SCREENING'),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _interviewType,
                decoration: const InputDecoration(labelText: 'Interview Type *', border: OutlineInputBorder()),
                items: ['ONLINE', 'OFFLINE', 'PHONE'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: (val) => setState(() => _interviewType = val ?? 'ONLINE'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _durationController,
                decoration: const InputDecoration(labelText: 'Duration (Minutes) *', border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Duration is required';
                  final d = int.tryParse(val.trim());
                  if (d == null || d <= 0) return 'Duration must be a positive integer';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _linkController,
                decoration: const InputDecoration(labelText: 'Meeting Link / Venue', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                  onPressed: _isSaving ? null : _scheduleInterview,
                  child: Text(_isSaving ? 'Scheduling...' : 'Schedule Interview'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
