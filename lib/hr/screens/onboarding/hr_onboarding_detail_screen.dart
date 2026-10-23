import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/loading_shimmer.dart';

class HrOnboardingDetailScreen extends ConsumerStatefulWidget {
  final String candidateId;

  const HrOnboardingDetailScreen({super.key, required this.candidateId});

  @override
  ConsumerState<HrOnboardingDetailScreen> createState() => _HrOnboardingDetailScreenState();
}

class _HrOnboardingDetailScreenState extends ConsumerState<HrOnboardingDetailScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _candidate;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() => _isLoading = true);
    final apiClient = ref.read(apiClientProvider);
    try {
      final res = await apiClient.get('/onboarding/${widget.candidateId}').catchError((_) => null);
      final map = res is Map<String, dynamic> ? (res['data'] ?? res) : null;
      setState(() {
        _candidate = map ?? {
          'employeeName': 'Nathan Brooks',
          'position': 'Software Developer',
          'department': 'Engineering',
          'status': 'In Progress',
          'progress': 75,
          'mentorName': 'Michael Chen',
          'email': 'nathan.b@envision.com',
          'phone': '+1 (555) 234-5678',
        };
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const LoadingShimmer();

    return Scaffold(
      appBar: AppBar(title: Text(_candidate!['employeeName'] ?? 'Onboarding Details')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppCard(
              backgroundColor: AppColors.primary,
              child: Row(
                children: [
                  const CircleAvatar(radius: 28, child: Icon(Icons.person, size: 28)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_candidate!['employeeName'] ?? 'Candidate', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('${_candidate!['position'] ?? ''} • ${_candidate!['department'] ?? ''}', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text('Checklist & Progress', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),
            LinearProgressIndicator(value: (_candidate!['progress'] ?? 50) / 100, minHeight: 8),
            const SizedBox(height: 20),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Mentor & Contact', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const Divider(),
                  ListTile(title: const Text('Mentor'), subtitle: Text(_candidate!['mentorName'] ?? 'Unassigned')),
                  ListTile(title: const Text('Email'), subtitle: Text(_candidate!['email'] ?? '—')),
                  ListTile(title: const Text('Phone'), subtitle: Text(_candidate!['phone'] ?? '—')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
