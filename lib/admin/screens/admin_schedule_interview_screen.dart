import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/errors/api_exception.dart';
import '../../core/theme/glass_theme.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/glass_header.dart';

class AdminScheduleInterviewScreen extends ConsumerStatefulWidget {
  final String? candidateId;

  const AdminScheduleInterviewScreen({super.key, this.candidateId});

  @override
  ConsumerState<AdminScheduleInterviewScreen> createState() => _AdminScheduleInterviewScreenState();
}

class _AdminScheduleInterviewScreenState extends ConsumerState<AdminScheduleInterviewScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isSubmitting = false;

  String? _selectedCandidateId;
  String? _selectedJobId;
  String? _selectedInterviewerId;

  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _timeController = TextEditingController(text: '10:00 AM');
  final TextEditingController _linkLocationController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  String _interviewType = 'Technical';
  String _interviewRound = 'Round 1';
  String _interviewMode = 'Online';
  bool _sendInvite = true;

  List<Map<String, String>> _candidates = [];
  List<Map<String, String>> _jobs = [];
  List<Map<String, String>> _interviewers = [];

  final List<String> _interviewTypes = ['Technical', 'HR', 'Managerial', 'Behavioral', 'Coding Assessment'];
  final List<String> _interviewRounds = ['Round 1', 'Round 2', 'Final Round'];
  final List<String> _interviewModes = ['Online', 'In Office'];

  @override
  void initState() {
    super.initState();
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    _dateController.text = DateFormat('yyyy-MM-dd').format(tomorrow);
    if (widget.candidateId != null) {
      _selectedCandidateId = widget.candidateId;
    }
    _loadLookups();
  }

  Future<void> _loadLookups() async {
    setState(() => _isLoading = true);
    final apiClient = ref.read(apiClientProvider);

    try {
      // 1. Fetch Candidates
      List<Map<String, String>> cList = [];
      try {
        final candRes = await apiClient.get(ApiEndpoints.candidates);
        dynamic rawCand = candRes is Map<String, dynamic> && candRes.containsKey('data') ? candRes['data'] : candRes;
        if (rawCand is List) {
          for (final c in rawCand) {
            if (c is Map<String, dynamic>) {
              final id = (c['id'] ?? c['_id'])?.toString() ?? '';
              final name = (c['fullName'] ?? '${c['firstName'] ?? ''} ${c['lastName'] ?? ''}').toString().trim();
              if (id.isNotEmpty) cList.add({'id': id, 'name': name.isNotEmpty ? name : 'Candidate'});
            }
          }
        }
      } catch (_) {}

      // 2. Fetch Jobs
      List<Map<String, String>> jList = [];
      try {
        final jobRes = await apiClient.get(ApiEndpoints.jobs);
        dynamic rawJobs = jobRes is Map<String, dynamic> && jobRes.containsKey('data') ? jobRes['data'] : jobRes;
        if (rawJobs is List) {
          for (final j in rawJobs) {
            if (j is Map<String, dynamic>) {
              final id = (j['id'] ?? j['_id'])?.toString() ?? '';
              final title = (j['title'] ?? j['jobTitle'])?.toString() ?? 'Job Opening';
              if (id.isNotEmpty) jList.add({'id': id, 'title': title});
            }
          }
        }
      } catch (_) {}

      // 3. Fetch Interviewers (Employees)
      List<Map<String, String>> empList = [];
      try {
        final empRes = await apiClient.get(ApiEndpoints.employees);
        dynamic rawEmps = empRes is Map<String, dynamic> && empRes.containsKey('data') ? empRes['data'] : empRes;
        if (rawEmps is List) {
          for (final e in rawEmps) {
            if (e is Map<String, dynamic>) {
              final id = (e['id'] ?? e['employeeId'])?.toString() ?? '';
              final name = (e['fullName'] ?? '${e['firstName'] ?? ''} ${e['lastName'] ?? ''}').toString().trim();
              if (id.isNotEmpty) empList.add({'id': id, 'name': name.isNotEmpty ? name : 'Interviewer'});
            }
          }
        }
      } catch (_) {}

      if (mounted) {
        setState(() {
          _candidates = cList;
          _jobs = jList;
          _interviewers = empList;
          if (cList.isNotEmpty && _selectedCandidateId == null) _selectedCandidateId = cList[0]['id'];
          if (jList.isNotEmpty) _selectedJobId = jList[0]['id'];
          if (empList.isNotEmpty) _selectedInterviewerId = empList[0]['id'];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submitSchedule() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedCandidateId == null || _selectedCandidateId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a candidate.'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final apiClient = ref.read(apiClientProvider);

    final payload = {
      'candidateId': _selectedCandidateId,
      'jobId': _selectedJobId,
      'interviewerId': _selectedInterviewerId,
      'scheduledAt': '${_dateController.text.trim()}T${_timeController.text.trim()}',
      'round': _interviewRound,
      'interviewType': _interviewType,
      'interviewMode': _interviewMode == 'In Office' ? 'OFFLINE' : 'ONLINE',
      'meetingLink': _linkLocationController.text.trim().isEmpty ? null : _linkLocationController.text.trim(),
      'notes': _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      'sendInvite': _sendInvite,
    };

    try {
      await apiClient.post(ApiEndpoints.interviews, body: payload);

      // Attempt status update separately
      bool statusUpdated = true;
      try {
        await apiClient.put(ApiEndpoints.candidateDetail(_selectedCandidateId!), body: {
          'status': 'INTERVIEW_SCHEDULED',
        });
      } catch (_) {
        statusUpdated = false;
      }

      if (mounted) {
        if (statusUpdated) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Interview scheduled successfully!')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Interview scheduled, but candidate status update failed.'), backgroundColor: Colors.orange),
          );
        }
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        final msg = e is ApiException ? e.message : 'Failed to schedule interview. Please check details and try again.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;

    if (_isLoading) {
      return GlassScaffold(
        appBar: GlassHeader(title: 'Schedule Interview'),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return GlassScaffold(
      appBar: GlassHeader(
        title: 'Schedule Interview',
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Interview Scheduling Form', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: glass.textPrimary)),
              const SizedBox(height: 16),

              // Candidate Select
              DropdownButtonFormField<String>(
                initialValue: _selectedCandidateId,
                decoration: InputDecoration(
                  labelText: 'Select Candidate *',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: _candidates.map((c) {
                  return DropdownMenuItem<String>(
                    value: c['id']!,
                    child: Text(c['name']!),
                  );
                }).toList(),
                onChanged: _isSubmitting ? null : (val) => setState(() => _selectedCandidateId = val),
                validator: (val) => (val == null || val.isEmpty) ? 'Candidate is required' : null,
              ),
              const SizedBox(height: 16),

              // Job Position Select
              DropdownButtonFormField<String>(
                initialValue: _selectedJobId,
                decoration: InputDecoration(
                  labelText: 'Job Position',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: _jobs.map((j) {
                  return DropdownMenuItem<String>(
                    value: j['id']!,
                    child: Text(j['title']!),
                  );
                }).toList(),
                onChanged: _isSubmitting ? null : (val) => setState(() => _selectedJobId = val),
              ),
              const SizedBox(height: 16),

              // Type & Round
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _interviewType,
                      decoration: InputDecoration(
                        labelText: 'Interview Type *',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      items: _interviewTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                      onChanged: _isSubmitting ? null : (val) => setState(() => _interviewType = val ?? 'Technical'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _interviewRound,
                      decoration: InputDecoration(
                        labelText: 'Interview Round *',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      items: _interviewRounds.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                      onChanged: _isSubmitting ? null : (val) => setState(() => _interviewRound = val ?? 'Round 1'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Date & Time
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _dateController,
                      enabled: !_isSubmitting,
                      decoration: InputDecoration(
                        labelText: 'Date (YYYY-MM-DD) *',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (val) => (val == null || val.trim().isEmpty) ? 'Date is required' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _timeController,
                      enabled: !_isSubmitting,
                      decoration: InputDecoration(
                        labelText: 'Time (e.g. 10:00 AM) *',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (val) => (val == null || val.trim().isEmpty) ? 'Time is required' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Interviewer & Mode
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedInterviewerId,
                      decoration: InputDecoration(
                        labelText: 'Interviewer',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      items: _interviewers.map((emp) {
                        return DropdownMenuItem<String>(
                          value: emp['id']!,
                          child: Text(emp['name']!),
                        );
                      }).toList(),
                      onChanged: _isSubmitting ? null : (val) => setState(() => _selectedInterviewerId = val),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _interviewMode,
                      decoration: InputDecoration(
                        labelText: 'Interview Mode',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      items: _interviewModes.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                      onChanged: _isSubmitting ? null : (val) => setState(() => _interviewMode = val ?? 'Online'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Meeting Link / Location
              TextFormField(
                controller: _linkLocationController,
                enabled: !_isSubmitting,
                decoration: InputDecoration(
                  labelText: _interviewMode == 'Online' ? 'Meeting Link (Google Meet / Zoom)' : 'Office Location / Room',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),

              // Instructions / Notes
              TextFormField(
                controller: _notesController,
                enabled: !_isSubmitting,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Interview Instructions / Notes',
                  hintText: 'Enter instructions for candidate or interviewer...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),

              // Send Invitation Checkbox
              CheckboxListTile(
                title: const Text('Send invitation to candidate (Email notification with meeting details)', style: TextStyle(fontSize: 12)),
                value: _sendInvite,
                activeColor: const Color(0xFF0F6B66),
                onChanged: _isSubmitting ? null : (val) => setState(() => _sendInvite = val ?? true),
              ),
              const SizedBox(height: 24),

              // Footer Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppButton(
                      label: 'Schedule Interview',
                      isLoading: _isSubmitting,
                      onPressed: _isSubmitting ? null : _submitSchedule,
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
