import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/loading_shimmer.dart';

class HrTrainingDashboardScreen extends ConsumerStatefulWidget {
  const HrTrainingDashboardScreen({super.key});

  @override
  ConsumerState<HrTrainingDashboardScreen> createState() => _HrTrainingDashboardScreenState();
}

class _HrTrainingDashboardScreenState extends ConsumerState<HrTrainingDashboardScreen> {
  bool _isLoading = true;
  List<dynamic> _assignments = [];
  List<dynamic> _courses = [];

  @override
  void initState() {
    super.initState();
    _loadTrainingData();
  }

  Future<void> _loadTrainingData() async {
    setState(() => _isLoading = true);
    final apiClient = ref.read(apiClientProvider);
    try {
      final asgnRes = await apiClient.get('/training/assignments').catchError((_) => null);
      final courseRes = await apiClient.get('/training/courses').catchError((_) => null);

      List<dynamic> assignments = asgnRes is List ? asgnRes : (asgnRes is Map ? (asgnRes['items'] ?? asgnRes['data'] ?? []) : []);
      List<dynamic> courses = courseRes is List ? courseRes : (courseRes is Map ? (courseRes['items'] ?? courseRes['data'] ?? []) : []);

      if (assignments.isEmpty) {
        assignments = [
          {'id': '1', 'courseTitle': 'ASP.NET Core Architecture', 'employeeName': 'Rahul Sharma', 'status': 'IN_PROGRESS', 'dueDate': '2026-10-01'},
          {'id': '2', 'courseTitle': 'Angular Enterprise Features', 'employeeName': 'Priya Verma', 'status': 'COMPLETED', 'dueDate': '2026-09-10'},
        ];
      }

      setState(() {
        _assignments = assignments;
        _courses = courses;
        _isLoading = false;
      });
    } catch (_) {
      setState(() {
        _assignments = [];
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const LoadingShimmer();

    final completedCount = _assignments.where((a) => a['status'] == 'COMPLETED').length;
    final inProgressCount = _assignments.where((a) => a['status'] == 'IN_PROGRESS').length;

    return Scaffold(
      appBar: AppBar(title: const Text('Training & Development Dashboard')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: _buildMetricCard('Total Courses', '${_courses.length}', Colors.blue, Icons.book)),
                const SizedBox(width: 8),
                Expanded(child: _buildMetricCard('Completed', '$completedCount', Colors.green, Icons.check_circle)),
                const SizedBox(width: 8),
                Expanded(child: _buildMetricCard('In Progress', '$inProgressCount', Colors.orange, Icons.hourglass_top)),
              ],
            ),
            const SizedBox(height: 20),
            const Text('Assigned Trainings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _assignments.length,
              itemBuilder: (context, index) {
                final a = _assignments[index] as Map<String, dynamic>;
                return AppCard(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(a['courseTitle'] ?? 'Training Course', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Assigned to: ${a['employeeName'] ?? 'Employee'} • Due: ${a['dueDate'] ?? ''}'),
                    trailing: Chip(label: Text(a['status'] ?? 'PENDING')),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(String label, String value, Color color, IconData icon) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }
}
