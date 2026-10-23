import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';

class HrInterviewScheduleScreen extends ConsumerStatefulWidget {
  const HrInterviewScheduleScreen({super.key});

  @override
  ConsumerState<HrInterviewScheduleScreen> createState() => _HrInterviewScheduleScreenState();
}

class _HrInterviewScheduleScreenState extends ConsumerState<HrInterviewScheduleScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _candidateNameController = TextEditingController(text: 'Aarav Sharma');
  final TextEditingController _jobTitleController = TextEditingController(text: 'Senior Full Stack Developer');
  final TextEditingController _dateTimeController = TextEditingController(text: '2026-09-20 10:00 AM');
  String _round = 'SCREENING';
  bool _isSaving = false;

  @override
  void dispose() {
    _candidateNameController.dispose();
    _jobTitleController.dispose();
    _dateTimeController.dispose();
    super.dispose();
  }

  Future<void> _scheduleInterview() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    final apiClient = ref.read(apiClientProvider);

    final payload = {
      'candidateName': _candidateNameController.text.trim(),
      'jobTitle': _jobTitleController.text.trim(),
      'round': _round,
      'scheduledAt': DateTime.now().add(const Duration(days: 2)).toIso8601String(),
      'status': 'SCHEDULED',
      'interviewType': 'ONLINE',
      'durationMinutes': 60,
    };

    try {
      await apiClient.post('/recruitment/interviews', body: payload);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Interview scheduled successfully')));
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to schedule interview: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Schedule Interview')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _candidateNameController,
                decoration: const InputDecoration(labelText: 'Candidate Name *', border: OutlineInputBorder()),
                validator: (val) => val == null || val.isEmpty ? 'Candidate name is required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _jobTitleController,
                decoration: const InputDecoration(labelText: 'Position *', border: OutlineInputBorder()),
                validator: (val) => val == null || val.isEmpty ? 'Position is required' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _round,
                decoration: const InputDecoration(labelText: 'Interview Round', border: OutlineInputBorder()),
                items: ['SCREENING', 'TECHNICAL', 'HR', 'FINAL'].map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                onChanged: (val) => setState(() => _round = val ?? 'SCREENING'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _dateTimeController,
                decoration: const InputDecoration(labelText: 'Scheduled Date & Time *', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
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
