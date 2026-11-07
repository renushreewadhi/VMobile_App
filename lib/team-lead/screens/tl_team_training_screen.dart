import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/glass_theme.dart';
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

  final int _totalCourses = 12;
  final int _inProgress = 8;
  final int _completed = 5;
  final int _pending = 4;
  final int _overdue = 2;
  final int _completionRate = 62;
  String _selectedMonth = 'Current Month';

  List<dynamic> _recentTrainings = [];
  List<dynamic> _memberProgressList = [];
  List<dynamic> _categories = [];

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
          {'title': 'App Development', 'course': 'Flutter Mobile Masterclass', 'assignedDate': '01 Sep 2026', 'dueDate': '30 Sep 2026', 'status': 'IN_PROGRESS'},
          {'title': 'Backend Development', 'course': '.NET Core Web API Architecture', 'assignedDate': '05 Sep 2026', 'dueDate': '05 Oct 2026', 'status': 'IN_PROGRESS'},
          {'title': 'DevOps & Cloud', 'course': 'AWS Cloud DevOps Fundamentals', 'assignedDate': '10 Aug 2026', 'dueDate': '10 Sep 2026', 'status': 'COMPLETED'},
          {'title': 'Figma & UI/UX Design', 'course': 'UI/UX Design Systems in Figma', 'assignedDate': '15 Aug 2026', 'dueDate': '15 Sep 2026', 'status': 'COMPLETED'},
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

      _categories = [
        {'name': 'App Development', 'count': 1},
        {'name': 'Backend Development', 'count': 1},
        {'name': 'DevOps & Cloud', 'count': 1},
        {'name': 'Figma & UI/UX Design', 'count': 1},
        {'name': 'GIS Team', 'count': 1},
        {'name': 'Linux & Infrastructure', 'count': 1},
        {'name': 'Security & Compliance', 'count': 1},
        {'name': 'Web Development', 'count': 1},
      ];

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
    final glass = context.glass;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) return const ListSkeleton(itemCount: 4);

    return RefreshIndicator(
      onRefresh: _loadTrainingData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header & Month Filter Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Training Dashboard', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: glass.textPrimary)),
                    const SizedBox(height: 2),
                    Text("Monitor your team's learning progress and assign trainings.", style: TextStyle(fontSize: 12, color: glass.textSecondary)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    border: Border.all(color: isDark ? AppColors.darkBordersAndDividers : AppColors.lightBordersAndDividers),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButton<String>(
                    value: _selectedMonth,
                    underline: const SizedBox.shrink(),
                    isDense: true,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: glass.textPrimary),
                    items: const [
                      DropdownMenuItem(value: 'Current Month', child: Text('Current Month')),
                      DropdownMenuItem(value: 'Last Month', child: Text('Last Month')),
                      DropdownMenuItem(value: 'Last Quarter', child: Text('Last Quarter')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedMonth = val);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 5 KPI Row (Total Courses, In Progress, Completed, Pending, Overdue)
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1.4,
              children: [
                _kpiCard('TOTAL COURSES', '$_totalCourses', 'Assigned to Team', Icons.book, AppColors.primary, isDark),
                _kpiCard('IN PROGRESS', '$_inProgress', 'Team Members', Icons.hourglass_top, AppColors.primary, isDark),
                _kpiCard('COMPLETED', '$_completed', 'Team Members', Icons.check_circle, AppColors.success, isDark),
                _kpiCard('PENDING', '$_pending', 'Team Members', Icons.schedule, AppColors.warning, isDark),
                _kpiCard('OVERDUE', '$_overdue', 'Team Members', Icons.error, AppColors.error, isDark),
              ],
            ),
            const SizedBox(height: 16),

            // Analytics Row (Completion Rate, Status Breakdown, Top Categories)
            LayoutBuilder(
              builder: (context, constraints) {
                return Column(
                  children: [
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Training Completion Rate', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          const SizedBox(height: 16),
                          Center(
                            child: SizedBox(
                              height: 120,
                              width: 120,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  CircularProgressIndicator(
                                    value: _completionRate / 100,
                                    strokeWidth: 12,
                                    backgroundColor: Colors.grey.shade200,
                                    color: AppColors.success,
                                  ),
                                  Text('$_completionRate%', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _legendItem('Completed', Colors.green, '5'),
                              _legendItem('In Progress', Colors.orange, '8'),
                              _legendItem('Not Started', Colors.grey, '3'),
                              _legendItem('Overdue', Colors.red, '2'),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Center(child: Text('Overall Team Completion', style: TextStyle(fontSize: 11, color: AppColors.lightSecondaryText))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Top Training Categories', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          const SizedBox(height: 12),
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _categories.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 6),
                            itemBuilder: (context, index) {
                              final cat = _categories[index];
                              return Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(width: 8, height: 8, decoration: BoxDecoration(color: Colors.primaries[index % Colors.primaries.length], shape: BoxShape.circle)),
                                      const SizedBox(width: 8),
                                      Text(cat['name'], style: const TextStyle(fontSize: 12)),
                                    ],
                                  ),
                                  Text('${cat['count']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),

            // Recent Assigned Trainings
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Recent Assigned Trainings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: glass.textPrimary)),
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
                          decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.school, color: AppColors.primary),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(t['course'] ?? 'Course', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: glass.textPrimary)),
                              const SizedBox(height: 2),
                              Text('Assigned: ${t['assignedDate']} • Due: ${t['dueDate']}', style: TextStyle(fontSize: 11, color: glass.textSecondary)),
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
                Text('Team Members Progress', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: glass.textPrimary)),
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
                final progress = ((m['progress'] ?? 0) as num).toInt();

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
                                  Text(m['name'] ?? 'Member', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: glass.textPrimary)),
                                  Text('Assigned: ${m['assigned']} • Completed: ${m['completed']}', style: TextStyle(fontSize: 12, color: glass.textSecondary)),
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
            const SizedBox(height: 20),

            // Bottom Banner Card
            AppCard(
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.track_changes, color: AppColors.primary, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Empower Your Team with Knowledge', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        const SizedBox(height: 2),
                        const Text('Assign relevant courses, track progress and help your team grow.', style: TextStyle(fontSize: 11.5, color: AppColors.lightSecondaryText)),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () async {
                      await Navigator.push(context, MaterialPageRoute(builder: (_) => const TlAssignTrainingScreen()));
                      _loadTrainingData();
                    },
                    icon: const Icon(Icons.send, size: 14),
                    label: const Text('Assign Training', style: TextStyle(fontSize: 11.5)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kpiCard(String label, String value, String sub, IconData icon, Color color, bool isDark) {
    return AppCard(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Expanded(child: Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color), overflow: TextOverflow.ellipsis)),
            ],
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText), overflow: TextOverflow.ellipsis),
          Text(sub, style: TextStyle(fontSize: 9, color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText), overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _legendItem(String label, Color color, String count) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text('$label ($count)', style: const TextStyle(fontSize: 10, color: AppColors.lightSecondaryText)),
      ],
    );
  }
}
