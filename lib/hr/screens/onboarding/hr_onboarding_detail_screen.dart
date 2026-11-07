import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/glass_header.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/loading_shimmer.dart';
import 'hr_onboarding_edit_screen.dart';

class HrOnboardingDetailScreen extends ConsumerStatefulWidget {
  final String candidateId;
  const HrOnboardingDetailScreen({super.key, required this.candidateId});

  @override
  ConsumerState<HrOnboardingDetailScreen> createState() => _HrOnboardingDetailScreenState();
}

class _HrOnboardingDetailScreenState extends ConsumerState<HrOnboardingDetailScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _candidate;
  final TextEditingController _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadDetail() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final apiClient = ref.read(apiClientProvider);
    try {
      final res = await apiClient.get('/onboarding/${widget.candidateId}');
      if (!mounted) return;

      final map = res is Map<String, dynamic> ? (res['data'] ?? res) : null;
      setState(() {
        _candidate = map;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to load candidate details: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _addNote() async {
    final text = _noteController.text.trim();
    if (text.isEmpty || _candidate == null) return;

    final apiClient = ref.read(apiClientProvider);
    final notes = List<dynamic>.from(_candidate!['notes'] ?? []);
    notes.insert(0, {'author': 'HR Manager', 'time': 'Just now', 'text': text});

    try {
      await apiClient.put('/onboarding/${widget.candidateId}', body: {..._candidate!, 'notes': notes}).catchError((_) {
        return apiClient.post('/onboarding/${widget.candidateId}', body: {..._candidate!, 'notes': notes});
      });
      if (mounted) {
        setState(() {
          _candidate!['notes'] = notes;
          _noteController.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Note added successfully')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to add note: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return GlassScaffold(appBar: GlassHeader(title: 'Onboarding Details'), body: const LoadingShimmer());
    }

    if (_errorMessage != null || _candidate == null) {
      return GlassScaffold(
        appBar: GlassHeader(title: 'Onboarding Details'),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 12),
                Text(_errorMessage ?? 'Candidate not found.', textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton(onPressed: _loadDetail, child: const Text('Retry')),
              ],
            ),
          ),
        ),
      );
    }

    final name = _candidate!['employeeName'] ?? _candidate!['name'] ?? 'Candidate';
    final position = _candidate!['position'] ?? 'Role';
    final dept = _candidate!['department'] ?? 'General';
    final status = _candidate!['status'] ?? 'In Progress';
    final progress = double.tryParse(_candidate!['progress']?.toString() ?? '0') ?? 0.0;
    final mentor = _candidate!['mentorName'] ?? _candidate!['mentor'] ?? 'Unassigned';
    final email = _candidate!['email'] ?? '—';
    final phone = _candidate!['phone'] ?? '—';
    final joinDate = _candidate!['startDate'] != null ? _candidate!['startDate'].toString().substring(0, 10) : '—';
    final documents = (_candidate!['documents'] as List?) ?? [
      {'name': 'ID Proof & Passport', 'verified': true},
      {'name': 'Signed Offer Letter', 'verified': true},
      {'name': 'Tax Form W-4', 'verified': false},
      {'name': 'Bank Details Form', 'verified': false},
    ];
    final notes = (_candidate!['notes'] as List?) ?? [];
    final tasks = (_candidate!['tasks'] as List?) ?? [
      {'label': 'Account setup', 'done': true},
      {'label': 'IT equipment issued', 'done': true},
      {'label': 'HR orientation', 'done': false},
      {'label': 'Team introduction', 'done': false},
    ];

    return GlassScaffold(
      appBar: GlassHeader(
        title: name,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => HrOnboardingEditScreen(candidateId: widget.candidateId)));
              _loadDetail();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Card
            AppCard(
              backgroundColor: AppColors.primary,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white,
                    child: Text(name.isNotEmpty ? name[0] : 'C', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primary)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('$position • $dept', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                        const SizedBox(height: 4),
                        Text('Joining: $joinDate', style: const TextStyle(color: Colors.white60, fontSize: 12)),
                      ],
                    ),
                  ),
                  Chip(
                    label: Text(status, style: const TextStyle(fontSize: 10, color: Colors.white)),
                    backgroundColor: status.toLowerCase().contains('complete') ? Colors.green : Colors.orange,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Progress Bar
            const Text('Onboarding Progress', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(value: progress / 100, minHeight: 10, backgroundColor: Colors.grey[200], valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary)),
                  ),
                ),
                const SizedBox(width: 12),
                Text('${progress.toStringAsFixed(0)}%', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            const SizedBox(height: 20),

            // Mentor & Contact Info
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Mentor & Contact', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const Divider(),
                  ListTile(dense: true, title: const Text('Mentor'), subtitle: Text(mentor), leading: const Icon(Icons.supervisor_account, size: 20)),
                  ListTile(dense: true, title: const Text('Email'), subtitle: Text(email), leading: const Icon(Icons.email, size: 20)),
                  ListTile(dense: true, title: const Text('Phone'), subtitle: Text(phone), leading: const Icon(Icons.phone, size: 20)),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Checklist Tasks
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Onboarding Checklist', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const Divider(),
                  ...tasks.map((t) => CheckboxListTile(
                        dense: true,
                        title: Text(t['label'] ?? 'Task'),
                        value: t['done'] ?? false,
                        onChanged: (val) {
                          setState(() {
                            t['done'] = val ?? false;
                            final doneCount = tasks.where((task) => task['done'] == true).length;
                            _candidate!['progress'] = tasks.isNotEmpty ? ((doneCount / tasks.length) * 100).round() : 0;
                          });
                        },
                      )),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Required Documents
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Required Documents', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const Divider(),
                  ...documents.map((doc) => ListTile(
                        dense: true,
                        title: Text(doc['name'] ?? 'Document'),
                        trailing: Chip(
                          label: Text(doc['verified'] == true ? 'Verified' : 'Pending', style: const TextStyle(fontSize: 10, color: Colors.white)),
                          backgroundColor: doc['verified'] == true ? Colors.green : Colors.orange,
                          visualDensity: VisualDensity.compact,
                        ),
                      )),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // HR & Mentor Notes
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('HR & Mentor Notes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const Divider(),
                  ...notes.map((n) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(n['author'] ?? 'HR', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                Text(n['time'] ?? 'Recent', style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(n['text'] ?? '', style: TextStyle(fontSize: 13, color: Colors.grey[700])),
                            const Divider(height: 12),
                          ],
                        ),
                      )),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _noteController,
                          decoration: const InputDecoration(hintText: 'Add orientation or initial note...', border: OutlineInputBorder(), isDense: true),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _addNote,
                        child: const Text('Add'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
