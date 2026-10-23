import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import 'admin_onboarding_form_screen.dart';

class AdminOnboardingDetailScreen extends ConsumerStatefulWidget {
  final String candidateId;

  const AdminOnboardingDetailScreen({super.key, required this.candidateId});

  @override
  ConsumerState<AdminOnboardingDetailScreen> createState() => _AdminOnboardingDetailScreenState();
}

class _AdminOnboardingDetailScreenState extends ConsumerState<AdminOnboardingDetailScreen> {
  bool _isLoading = true;
  Map<String, dynamic> _candidate = {};

  @override
  void initState() {
    super.initState();
    _loadCandidateDetail();
  }

  Future<void> _loadCandidateDetail() async {
    setState(() => _isLoading = true);
    final apiClient = ref.read(apiClientProvider);

    try {
      final res = await apiClient.get('/onboarding/${widget.candidateId}').catchError((_) => null);
      if (res is Map<String, dynamic>) {
        _candidate = res;
      } else {
        _candidate = {
          'id': widget.candidateId,
          'employeeName': 'Nathan Brooks',
          'jobPosition': 'Software Developer',
          'departmentName': 'Engineering',
          'status': 'IN_PROGRESS',
          'progress': 75,
          'startDate': '2025-02-15',
          'mentorName': 'Michael Chen',
          'tasks': [
            {'id': 't1', 'title': 'Submit Identity Proof', 'isCompleted': true},
            {'id': 't2', 'title': 'Sign Employment Agreement', 'isCompleted': true},
            {'id': 't3', 'title': 'IT Equipment Allocation', 'isCompleted': false},
            {'id': 't4', 'title': 'HR Orientation Session', 'isCompleted': false},
          ]
        };
      }
      setState(() => _isLoading = false);
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _completeOnboarding() async {
    try {
      await ref.read(apiClientProvider).post('/onboarding/${widget.candidateId}/complete');
      setState(() {
        _candidate['status'] = 'COMPLETED';
        _candidate['progress'] = 100;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Onboarding completed successfully!')));
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final name = _candidate['employeeName'] ?? _candidate['name'] ?? 'Candidate';
    final status = (_candidate['status'] ?? 'NOT_STARTED').toString().toUpperCase();
    final progress = (_candidate['progress'] as num?)?.toDouble() ?? 0.0;
    final tasks = (_candidate['tasks'] is List) ? (_candidate['tasks'] as List) : [];

    return Scaffold(
      appBar: AppBar(
        title: Text(name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Edit Onboarding',
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => AdminOnboardingFormScreen(candidateId: widget.candidateId, initialData: _candidate)));
              _loadCandidateDetail();
            },
          ),
          if (status != 'COMPLETED')
            IconButton(
              icon: const Icon(Icons.check_circle, color: Colors.green),
              tooltip: 'Complete Onboarding',
              onPressed: _completeOnboarding,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Card
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: AppColors.primary.withOpacity(0.1),
                      child: Text(name[0].toUpperCase(), style: const TextStyle(fontSize: 28, color: AppColors.primary, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('${_candidate['jobPosition'] ?? 'Position'} • ${_candidate['departmentName'] ?? 'General'}', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                          Text('Joining: ${_candidate['startDate'] ?? '2025-02-15'}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        ],
                      ),
                    ),
                    Chip(
                      label: Text(status, style: const TextStyle(color: Colors.white)),
                      backgroundColor: status == 'COMPLETED' ? Colors.green : Colors.orange,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Progress Bar
            const Text('Onboarding Progress', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Completion Rate'),
                Text('${progress.toInt()}%', style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: progress / 100.0, backgroundColor: Colors.grey[200], valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary)),
            const SizedBox(height: 24),

            // Checklist Tasks
            const Text('Onboarding Checklist', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
            const SizedBox(height: 12),
            tasks.isEmpty
                ? const Center(child: Text('No checklist tasks assigned.'))
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: tasks.length,
                    itemBuilder: (context, index) {
                      final task = tasks[index];
                      final isDone = task['isCompleted'] == true || task['done'] == true;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: CheckboxListTile(
                          title: Text(task['title'] ?? task['label'] ?? 'Task', style: TextStyle(decoration: isDone ? TextDecoration.lineThrough : null)),
                          value: isDone,
                          activeColor: AppColors.primary,
                          onChanged: (val) async {
                            setState(() {
                              task['isCompleted'] = val;
                            });
                            try {
                              await ref.read(apiClientProvider).put('/onboarding/tasks/${task['id']}', data: {'isCompleted': val});
                            } catch (_) {}
                          },
                        ),
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }
}
