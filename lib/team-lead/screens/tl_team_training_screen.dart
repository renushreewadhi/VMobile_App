import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/loading_shimmer.dart';
import '../../shared/widgets/status_chip.dart';
import 'tl_assign_training_screen.dart';

class TlTeamTrainingScreen extends ConsumerStatefulWidget {
  const TlTeamTrainingScreen({super.key});

  @override
  ConsumerState<TlTeamTrainingScreen> createState() => _TlTeamTrainingScreenState();
}

class _TlTeamTrainingScreenState extends ConsumerState<TlTeamTrainingScreen> {
  bool _isLoading = true;
  String _selectedDateRange = 'Current Month';

  int _totalCourses = 12;
  int _inProgress = 8;
  int _completed = 5;
  int _pending = 4;
  int _overdue = 2;
  int _completionRate = 62;

  List<dynamic> _recentTrainings = [];
  List<dynamic> _memberProgressList = [];

  @override
  void initState() {
    super.initState();
    _loadTrainingData();
  }

  Future<void> _loadTrainingData() async {
    setState(() => _isLoading = true);
    final apiClient = ref.read(apiClientProvider);

    try {
      final res = await apiClient.get('/training/courses').catchError((_) async {
        return await apiClient.get('/courses').catchError((_) => null);
      });

      List<dynamic> courses = [];
      if (res is List) {
        courses = res;
      } else if (res is Map<String, dynamic>) {
        courses = res['items'] ?? res['data'] ?? [];
      }

      if (courses.isEmpty) {
        courses = [
          {'course': 'Flutter Mobile Masterclass', 'assignedDate': '01 Sep 2026', 'dueDate': '30 Sep 2026', 'status': 'IN_PROGRESS'},
          {'course': '.NET Core Web API Architecture', 'assignedDate': '05 Sep 2026', 'dueDate': '05 Oct 2026', 'status': 'IN_PROGRESS'},
          {'course': 'AWS Cloud DevOps Fundamentals', 'assignedDate': '10 Aug 2026', 'dueDate': '10 Sep 2026', 'status': 'COMPLETED'},
          {'course': 'UI/UX Design Systems in Figma', 'assignedDate': '15 Aug 2026', 'dueDate': '15 Sep 2026', 'status': 'COMPLETED'},
        ];
      }

      _recentTrainings = courses.take(5).map((c) {
        return {
          'course': c['title'] ?? c['course'] ?? 'Training Course',
          'assignedDate': c['assignedDate'] ?? '01 Sep 2026',
          'dueDate': c['dueDate'] ?? '30 Sep 2026',
          'status': c['status'] ?? 'IN_PROGRESS',
        };
      }).toList();

      _memberProgressList = [
        {'name': 'Rahul Sharma', 'initials': 'RS', 'assigned': 3, 'completed': 2, 'progress': 80, 'status': 'In Progress'},
        {'name': 'Priya Verma', 'initials': 'PV', 'assigned': 2, 'completed': 2, 'progress': 100, 'status': 'Completed'},
        {'name': 'Amit Kumar', 'initials': 'AK', 'assigned': 4, 'completed': 1, 'progress': 40, 'status': 'In Progress'},
        {'name': 'Neha Singh', 'initials': 'NS', 'assigned': 2, 'completed': 0, 'progress': 0, 'status': 'Not Started'},
      ];

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const ListSkeleton(itemCount: 4);

    return RefreshIndicator(
      onRefresh: _loadTrainingData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header & Action Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('Training Dashboard', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    SizedBox(height: 2),
                    Text("Monitor your team's learning progress", style: TextStyle(fontSize: 12, color: AppColors.lightSecondaryText)),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const TlAssignTrainingScreen()),
                    );
                    _loadTrainingData();
                  },
                  icon: const Icon(Icons.person_add),
                  label: const Text('Assign'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // KPI Row
            Row(
              children: [
                Expanded(child: StatCard(title: 'Total Courses', value: '$_totalCourses', icon: Icons.book, iconColor: AppColors.primary, iconBgColor: AppColors.lightPrimary)),
                const SizedBox(width: 8),
                Expanded(child: StatCard(title: 'In Progress', value: '$_inProgress', icon: Icons.hourglass_top, iconColor: AppColors.primary, iconBgColor: AppColors.lightPrimary)),
                const SizedBox(width: 8),
                Expanded(child: StatCard(title: 'Completed', value: '$_completed', icon: Icons.check_circle, iconColor: AppColors.success, iconBgColor: AppColors.successBg)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: StatCard(title: 'Pending', value: '$_pending', icon: Icons.schedule, iconColor: AppColors.warning, iconBgColor: AppColors.warningBg)),
                const SizedBox(width: 8),
                Expanded(child: StatCard(title: 'Overdue', value: '$_overdue', icon: Icons.error, iconColor: AppColors.error, iconBgColor: AppColors.errorBg)),
                const SizedBox(width: 8),
                Expanded(child: StatCard(title: 'Completion Rate', value: '$_completionRate%', icon: Icons.show_chart, iconColor: AppColors.success, iconBgColor: AppColors.successBg)),
              ],
            ),
            const SizedBox(height: 20),

            // Recent Assigned Trainings
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Recent Assigned Trainings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                TextButton(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const TlAssignTrainingScreen()));
                  },
                  child: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _recentTrainings.length,
              itemBuilder: (context, index) {
                final t = _recentTrainings[index] as Map<String, dynamic>;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: AppCard(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.school, color: AppColors.primary),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(t['course'] ?? 'Course', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              const SizedBox(height: 2),
                              Text('Assigned: ${t['assignedDate']} • Due: ${t['dueDate']}', style: const TextStyle(fontSize: 11, color: AppColors.lightSecondaryText)),
                            ],
                          ),
                        ),
                        StatusChip(status: t['status'] ?? 'IN_PROGRESS'),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),

            // Team Members Progress
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Team Members Progress', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                TextButton(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const TlAssignTrainingScreen()));
                  },
                  child: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _memberProgressList.length,
              itemBuilder: (context, index) {
                final m = _memberProgressList[index] as Map<String, dynamic>;
                final progress = (m['progress'] ?? 0) as int;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: AppColors.primary,
                              child: Text(m['initials'] ?? 'TM', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(m['name'] ?? 'Member', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  Text('Assigned: ${m['assigned']} • Completed: ${m['completed']}', style: const TextStyle(fontSize: 12, color: AppColors.lightSecondaryText)),
                                ],
                              ),
                            ),
                            Text('$progress%', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        LinearProgressIndicator(
                          value: progress / 100,
                          backgroundColor: AppColors.lightSurface,
                          color: progress == 100 ? AppColors.success : AppColors.primary,
                        ),
                      ],
                    ),
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
