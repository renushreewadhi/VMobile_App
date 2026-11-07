import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/widgets/glass_header.dart';
import '../../../core/widgets/glass_scaffold.dart';

class HrInterviewEditScreen extends ConsumerStatefulWidget {
  final String interviewId;

  const HrInterviewEditScreen({super.key, required this.interviewId});

  @override
  ConsumerState<HrInterviewEditScreen> createState() => _HrInterviewEditScreenState();
}

class _HrInterviewEditScreenState extends ConsumerState<HrInterviewEditScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = true;
  String? _errorMessage;
  bool _isSaving = false;

  Map<String, dynamic>? _interview;
  final TextEditingController _feedbackController = TextEditingController();
  final TextEditingController _ratingController = TextEditingController();
  final TextEditingController _linkController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _timeController = TextEditingController(text: '10:00');
  final TextEditingController _durationController = TextEditingController(text: '60');

  String _status = 'SCHEDULED';
  String _round = 'SCREENING';
  String _interviewType = 'ONLINE';
  String _interviewerId = '';

  List<dynamic> _employees = [];

  int _requestId = 0;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _checkUserAndLoad();
    });
  }

  @override
  void dispose() {
    _feedbackController.dispose();
    _ratingController.dispose();
    _linkController.dispose();
    _dateController.dispose();
    _timeController.dispose();
    _durationController.dispose();
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
    _loadData();
  }

  Future<void> _loadData() async {
    final currentReq = ++_requestId;
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final apiClient = ref.read(apiClientProvider);
    try {
      final res = await apiClient.get('/recruitment/interviews/${widget.interviewId}');
      final empRes = await apiClient.get(ApiEndpoints.employees).catchError((_) => apiClient.get('/employees/all'));

      if (!mounted || currentReq != _requestId) return;

      final data = res is Map<String, dynamic> ? (res['data'] ?? res) : null;
      List<dynamic> employees = empRes is List ? empRes : (empRes is Map ? (empRes['items'] ?? empRes['data'] ?? []) : []);

      if (data != null) {
        String dateStr = '';
        String timeStr = '10:00';
        if (data['scheduledAt'] != null) {
          try {
            final dt = DateTime.parse(data['scheduledAt'].toString());
            dateStr = dt.toIso8601String().substring(0, 10);
            timeStr = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
          } catch (_) {
            dateStr = data['scheduledAt'].toString().length >= 10 ? data['scheduledAt'].toString().substring(0, 10) : '';
          }
        }

        setState(() {
          _interview = data;
          _feedbackController.text = data['feedback'] ?? '';
          _ratingController.text = data['rating'] != null ? data['rating'].toString() : '';
          _linkController.text = data['meetingLink'] ?? '';
          _status = data['status'] ?? 'SCHEDULED';
          _round = data['round'] ?? 'SCREENING';
          _interviewType = data['interviewType'] ?? 'ONLINE';
          _interviewerId = data['interviewerId']?.toString() ?? '';
          _dateController.text = dateStr;
          _timeController.text = timeStr;
          _durationController.text = (data['durationMinutes'] ?? 60).toString();
          _employees = employees;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Interview record not found.';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted || currentReq != _requestId) return;
      setState(() {
        _errorMessage = 'Failed to load interview details: $e';
        _isLoading = false;
      });
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

  Future<void> _saveInterview() async {
    if (!_formKey.currentState!.validate() || _isSaving) return;

    double? rating;
    if (_ratingController.text.trim().isNotEmpty) {
      rating = double.tryParse(_ratingController.text.trim());
      if (rating == null || rating < 1 || rating > 5) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rating must be between 1 and 5'), backgroundColor: Colors.red));
        return;
      }
    }

    final scheduledAtStr = '${_dateController.text.trim()}T${_timeController.text.trim()}:00';
    final parsedDate = DateTime.tryParse(scheduledAtStr);
    if (parsedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid scheduled date or time'), backgroundColor: Colors.red));
      return;
    }

    setState(() => _isSaving = true);
    final apiClient = ref.read(apiClientProvider);

    final selectedEmp = _employees.firstWhere((e) => (e['id']?.toString() ?? e['employeeId']?.toString() ?? '') == _interviewerId, orElse: () => null);
    final interviewerName = selectedEmp != null ? ('${selectedEmp['firstName'] ?? ''} ${selectedEmp['lastName'] ?? ''}'.trim().isNotEmpty ? '${selectedEmp['firstName']} ${selectedEmp['lastName']}' : (selectedEmp['name'] ?? 'Interviewer')) : '';

    try {
      // 1. Update general interview details
      await apiClient.put('/recruitment/interviews/${widget.interviewId}', body: {
        'round': _round,
        'interviewType': _interviewType,
        'scheduledAt': parsedDate.toIso8601String(),
        'durationMinutes': int.tryParse(_durationController.text.trim()) ?? 60,
        if (_interviewerId.isNotEmpty) 'interviewerId': _interviewerId,
        if (interviewerName.isNotEmpty) 'interviewerName': interviewerName,
        if (_linkController.text.trim().isNotEmpty) 'meetingLink': _linkController.text.trim(),
      });

      // 2. Update status, feedback & rating
      await apiClient.put('/recruitment/interviews/${widget.interviewId}/status', body: {
        'status': _status,
        if (_feedbackController.text.trim().isNotEmpty) 'feedback': _feedbackController.text.trim(),
        if (rating != null) 'rating': rating,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Interview updated successfully')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update interview: $e'), backgroundColor: Colors.red));
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
        appBar: const GlassHeader(title: 'Edit Interview & Feedback'),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null || _interview == null) {
      return GlassScaffold(
        appBar: const GlassHeader(title: 'Edit Interview & Feedback'),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline_rounded, size: 54, color: Colors.red),
                const SizedBox(height: 16),
                const Text('Unable to Load Interview', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(_errorMessage ?? 'Interview not found.', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                const SizedBox(height: 24),
                ElevatedButton.icon(onPressed: _loadData, icon: const Icon(Icons.refresh), label: const Text('Retry')),
              ],
            ),
          ),
        ),
      );
    }

    final i = _interview!;
    final candidateName = i['candidateName'] ?? 'Candidate';
    final jobTitle = i['jobTitle'] ?? 'Position';

    return GlassScaffold(
      appBar: const GlassHeader(title: 'Edit Interview & Feedback'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Candidate: $candidateName', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Text('Position: $jobTitle', style: TextStyle(fontSize: 13, color: Colors.grey[700])),
              const Divider(height: 24),
              DropdownButtonFormField<String>(
                value: _status,
                decoration: const InputDecoration(labelText: 'Interview Status *', border: OutlineInputBorder()),
                items: ['SCHEDULED', 'RESCHEDULED', 'COMPLETED', 'CANCELLED', 'NO_SHOW'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                onChanged: (val) => setState(() => _status = val ?? 'SCHEDULED'),
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
              TextFormField(
                controller: _durationController,
                decoration: const InputDecoration(labelText: 'Duration (Minutes) *', border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Duration is required';
                  final d = int.tryParse(val.trim());
                  if (d == null || d <= 0) return 'Duration must be positive';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _linkController,
                decoration: const InputDecoration(labelText: 'Meeting Link / Venue', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _ratingController,
                decoration: const InputDecoration(labelText: 'Rating (1 - 5, Optional)', border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return null;
                  final r = double.tryParse(val.trim());
                  if (r == null || r < 1 || r > 5) return 'Rating must be between 1 and 5';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _feedbackController,
                decoration: const InputDecoration(labelText: 'Interviewer Feedback & Comments', border: OutlineInputBorder()),
                maxLines: 4,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                  onPressed: _isSaving ? null : _saveInterview,
                  child: Text(_isSaving ? 'Saving...' : 'Update Interview & Feedback'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
