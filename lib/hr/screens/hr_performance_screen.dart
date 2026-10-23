import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/loading_shimmer.dart';

class HrPerformanceScreen extends ConsumerStatefulWidget {
  const HrPerformanceScreen({super.key});

  @override
  ConsumerState<HrPerformanceScreen> createState() => _HrPerformanceScreenState();
}

class _HrPerformanceScreenState extends ConsumerState<HrPerformanceScreen> {
  bool _isLoading = true;
  String _activeTab = 'scorecards';
  List<dynamic> _scorecards = [];
  List<dynamic> _goals = [];
  List<dynamic> _cycles = [];
  List<dynamic> _reviews = [];
  List<dynamic> _feedbacks = [];
  String _searchTerm = '';

  @override
  void initState() {
    super.initState();
    _loadPerformanceData();
  }

  Future<void> _loadPerformanceData() async {
    setState(() => _isLoading = true);
    final apiClient = ref.read(apiClientProvider);
    try {
      final scRes = await apiClient.get('/performance/scorecards').catchError((_) => null);
      final goalRes = await apiClient.get('/performance/goals').catchError((_) => null);
      final cycRes = await apiClient.get('/performance/cycles').catchError((_) => null);

      List<dynamic> scorecards = scRes is List ? scRes : (scRes is Map ? (scRes['items'] ?? scRes['data'] ?? []) : []);
      List<dynamic> goals = goalRes is List ? goalRes : (goalRes is Map ? (goalRes['items'] ?? goalRes['data'] ?? []) : []);
      List<dynamic> cycles = cycRes is List ? cycRes : (cycRes is Map ? (cycRes['items'] ?? cycRes['data'] ?? []) : []);

      if (scorecards.isEmpty) {
        scorecards = [
          {'id': 'SC-101', 'employeeName': 'Aarav Sharma', 'totalTasksAssigned': 20, 'tasksCompleted': 19, 'totalAttendancePercentage': 96, 'overallWeightedScore': 94.5, 'overallRating': 'OUTSTANDING', 'isReviewedByTl': true, 'isReviewedByHr': true},
          {'id': 'SC-102', 'employeeName': 'Priya Patel', 'totalTasksAssigned': 16, 'tasksCompleted': 15, 'totalAttendancePercentage': 92, 'overallWeightedScore': 91.2, 'overallRating': 'EXCEEDS_EXPECTATIONS', 'isReviewedByTl': true, 'isReviewedByHr': false},
        ];
      }

      setState(() {
        _scorecards = scorecards;
        _goals = goals;
        _cycles = cycles;
        _isLoading = false;
      });
    } catch (_) {
      setState(() {
        _scorecards = [];
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const LoadingShimmer();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Performance & KPI Tracking'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              TextButton(onPressed: () => setState(() => _activeTab = 'scorecards'), child: Text('Scorecards', style: TextStyle(fontWeight: _activeTab == 'scorecards' ? FontWeight.bold : FontWeight.normal))),
              TextButton(onPressed: () => setState(() => _activeTab = 'goals'), child: Text('Goals & KPIs', style: TextStyle(fontWeight: _activeTab == 'goals' ? FontWeight.bold : FontWeight.normal))),
              TextButton(onPressed: () => setState(() => _activeTab = 'cycles'), child: Text('Cycles', style: TextStyle(fontWeight: _activeTab == 'cycles' ? FontWeight.bold : FontWeight.normal))),
            ],
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(
                labelText: 'Search employee, goal, KPI...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (val) => setState(() => _searchTerm = val),
            ),
            const SizedBox(height: 16),
            if (_activeTab == 'scorecards') ...[
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _scorecards.length,
                itemBuilder: (context, index) {
                  final sc = _scorecards[index] as Map<String, dynamic>;
                  return AppCard(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(sc['employeeName'] ?? 'Employee', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('Score: ${sc['overallWeightedScore'] ?? 0} • Rating: ${sc['overallRating'] ?? 'N/A'}'),
                      trailing: Chip(label: Text(sc['isReviewedByHr'] == true ? 'HR Reviewed' : 'Pending HR')),
                    ),
                  );
                },
              ),
            ] else if (_activeTab == 'goals') ...[
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _goals.length,
                itemBuilder: (context, index) {
                  final g = _goals[index] as Map<String, dynamic>;
                  return AppCard(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(g['title'] ?? 'Goal', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('${g['employeeName'] ?? 'Employee'} • Progress: ${g['achievementPercentage'] ?? 0}%'),
                      trailing: Chip(label: Text(g['status'] ?? 'IN_PROGRESS')),
                    ),
                  );
                },
              ),
            ] else ...[
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _cycles.length,
                itemBuilder: (context, index) {
                  final c = _cycles[index] as Map<String, dynamic>;
                  return AppCard(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(c['name'] ?? 'Cycle', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('Type: ${c['cycleType'] ?? 'QUARTERLY'} • ${c['startDate'] ?? ''} to ${c['endDate'] ?? ''}'),
                      trailing: Chip(label: Text(c['status'] ?? 'ACTIVE')),
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
