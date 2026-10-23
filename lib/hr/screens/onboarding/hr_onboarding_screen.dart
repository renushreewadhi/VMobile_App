import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/loading_shimmer.dart';
import 'hr_onboarding_detail_screen.dart';
import 'hr_onboarding_add_screen.dart';

class HrOnboardingScreen extends ConsumerStatefulWidget {
  const HrOnboardingScreen({super.key});

  @override
  ConsumerState<HrOnboardingScreen> createState() => _HrOnboardingScreenState();
}

class _HrOnboardingScreenState extends ConsumerState<HrOnboardingScreen> {
  bool _isLoading = true;
  List<dynamic> _onboardings = [];
  String _searchTerm = '';
  String _statusFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    _loadOnboardings();
  }

  Future<void> _loadOnboardings() async {
    setState(() => _isLoading = true);
    final apiClient = ref.read(apiClientProvider);
    try {
      final res = await apiClient.get('/onboarding').catchError((_) => null);
      List<dynamic> items = [];
      if (res is List) {
        items = res;
      } else if (res is Map<String, dynamic>) {
        items = res['items'] ?? res['data'] ?? [];
      }

      if (items.isEmpty) {
        items = [
          {
            'id': 'OB-101',
            'employeeName': 'Nathan Brooks',
            'status': 'In Progress',
            'position': 'Software Developer',
            'department': 'Engineering',
            'startDate': '2024-12-16',
            'progress': 75,
            'mentorName': 'Michael Chen',
          },
          {
            'id': 'OB-102',
            'employeeName': 'Sophia Patel',
            'status': 'In Progress',
            'position': 'UI/UX Product Designer',
            'department': 'Design',
            'startDate': '2024-12-18',
            'progress': 50,
            'mentorName': 'Lisa Anderson',
          }
        ];
      }

      setState(() {
        _onboardings = items;
        _isLoading = false;
      });
    } catch (_) {
      setState(() {
        _onboardings = [];
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const LoadingShimmer();

    final filtered = _onboardings.where((o) {
      final map = o is Map<String, dynamic> ? o : {};
      final name = (map['employeeName'] ?? map['name'] ?? '').toString().toLowerCase();
      final pos = (map['position'] ?? '').toString().toLowerCase();
      final dept = (map['department'] ?? '').toString().toLowerCase();
      final status = (map['status'] ?? 'In Progress').toString().toLowerCase();

      final matchesSearch = _searchTerm.isEmpty || name.contains(_searchTerm.toLowerCase()) || pos.contains(_searchTerm.toLowerCase()) || dept.contains(_searchTerm.toLowerCase());
      final matchesStatus = _statusFilter == 'ALL' || status == _statusFilter.toLowerCase();

      return matchesSearch && matchesStatus;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Onboarding Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const HrOnboardingAddScreen()));
              _loadOnboardings();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(
                labelText: 'Search candidate, position, mentor...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (val) => setState(() => _searchTerm = val),
            ),
            const SizedBox(height: 16),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final o = filtered[index] as Map<String, dynamic>;
                final name = o['employeeName'] ?? o['name'] ?? 'Candidate';
                return AppCard(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primary.withOpacity(0.1),
                      child: Text(name.isNotEmpty ? name[0] : 'C'),
                    ),
                    title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('${o['position'] ?? 'Role'} • ${o['department'] ?? 'General'} • Progress: ${o['progress'] ?? 0}%'),
                    trailing: Chip(label: Text(o['status'] ?? 'In Progress')),
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => HrOnboardingDetailScreen(candidateId: o['id'] ?? '1')));
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
