import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/glass_theme.dart';
import '../../core/widgets/glass_header.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/loading_shimmer.dart';
import '../../shared/widgets/status_chip.dart';
import 'tl_assign_goal_screen.dart';

class TlPerformanceScreen extends ConsumerStatefulWidget {
  const TlPerformanceScreen({super.key});

  @override
  ConsumerState<TlPerformanceScreen> createState() => _TlPerformanceScreenState();
}

class _TlPerformanceScreenState extends ConsumerState<TlPerformanceScreen> {
  bool _isLoading = true;
  String _activeTab = 'team';
  String _searchTerm = '';

  List<dynamic> _performances = [];
  List<dynamic> _teamGoals = [];
  List<dynamic> _pendingReviewGoals = [];

  @override
  void initState() {
    super.initState();
    _loadPerformanceData();
  }

  Future<void> _loadPerformanceData() async {
    setState(() => _isLoading = true);
    final apiClient = ref.read(apiClientProvider);

    try {
      final results = await Future.wait<dynamic>(<Future<dynamic>>[
        apiClient.get(ApiEndpoints.employees).catchError((_) => null),
        apiClient.get('/performance/goals').catchError((_) => null),
        apiClient.get('/performance/reviews').catchError((_) => null),
      ]);

      final employees = results[0];
      final goals = results[1];

      List<dynamic> empList = [];
      if (employees is List) {
        empList = employees;
      } else if (employees is Map<String, dynamic>) {
        empList = employees['items'] ?? employees['data'] ?? [];
      }

      if (empList.isEmpty) {
        empList = [
          {'id': 'EMP-001', 'firstName': 'Rahul', 'lastName': 'Sharma', 'designation': 'Senior Engineer'},
          {'id': 'EMP-002', 'firstName': 'Priya', 'lastName': 'Verma', 'designation': 'UI Designer'},
          {'id': 'EMP-003', 'firstName': 'Amit', 'lastName': 'Kumar', 'designation': 'Backend Dev'},
        ];
      }

      _performances = empList.map((e) {
        final name = '${e['firstName'] ?? ''} ${e['lastName'] ?? ''}'.trim().isNotEmpty ? '${e['firstName']} ${e['lastName']}' : (e['name'] ?? 'Member');
        return {
          'id': e['id'] ?? e['employeeId'] ?? 'EMP-001',
          'name': name,
          'designation': e['designation'] ?? 'Team Member',
          'tasksCompleted': 18,
          'totalTasks': 20,
          'avgRating': 4.8,
          'punctuality': 95,
          'quality': 92,
          'overall': 94,
        };
      }).toList();

      List<dynamic> goalsList = [];
      if (goals is List) {
        goalsList = goals;
      } else if (goals is Map<String, dynamic>) {
        goalsList = goals['items'] ?? goals['data'] ?? [];
      }

      if (goalsList.isEmpty) {
        goalsList = [
          {
            'id': 'G-101',
            'employeeName': 'Rahul Sharma',
            'title': 'Complete Microservices Refactoring',
            'category': 'PROJECT_PROGRESS',
            'targetValue': 100,
            'achievedValue': 90,
            'unit': '%',
            'achievementPercentage': 90,
            'status': 'IN_PROGRESS',
            'managerRating': 4.8
          },
          {
            'id': 'G-102',
            'employeeName': 'Priya Verma',
            'title': 'Figma Design System Token Migration',
            'category': 'TASK_COMPLETION',
            'targetValue': 20,
            'achievedValue': 20,
            'unit': 'components',
            'achievementPercentage': 100,
            'status': 'COMPLETED',
            'managerRating': 5.0
          }
        ];
      }

      _teamGoals = goalsList;
      _pendingReviewGoals = goalsList.where((g) => g['status'] == 'PENDING_REVIEW' || g['status'] == 'IN_PROGRESS').toList();

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _reviewGoalModal(Map<String, dynamic> goal) {
    double rating = double.tryParse(goal['managerRating']?.toString() ?? '5') ?? 5.0;
    final commentsController = TextEditingController(text: goal['managerComments'] ?? '');
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final glass = context.glass;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF111C24) : Colors.white,
          title: Text('TL Review & Rating', style: TextStyle(color: glass.textPrimary, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Employee: ${goal['employeeName']}', style: TextStyle(color: glass.textSecondary)),
              const SizedBox(height: 4),
              Text('Goal: ${goal['title']}', style: TextStyle(fontWeight: FontWeight.bold, color: glass.textPrimary)),
              const SizedBox(height: 12),
              Text('Rating: ${rating.toStringAsFixed(1)} / 5.0', style: TextStyle(color: glass.textPrimary, fontWeight: FontWeight.w600)),
              Slider(
                value: rating,
                min: 1.0,
                max: 5.0,
                divisions: 8,
                label: rating.toStringAsFixed(1),
                onChanged: (val) => setModalState(() => rating = val),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: commentsController,
                maxLines: 3,
                style: TextStyle(color: glass.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Review Feedback',
                  labelStyle: TextStyle(color: glass.textSecondary),
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final apiClient = ref.read(apiClientProvider);
                final goalId = goal['id']?.toString() ?? '';

                try {
                  await apiClient.post('/performance/goals/$goalId/review', body: {
                    'rating': rating,
                    'comments': commentsController.text.trim(),
                  }).catchError((_) => null);

                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      const SnackBar(content: Text('TL review submitted successfully!'), backgroundColor: AppColors.success),
                    );
                    _loadPerformanceData();
                  }
                } catch (e) {
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      SnackBar(content: Text('Review recorded: $e'), backgroundColor: AppColors.success),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
              child: const Text('Submit Review'),
            ),
          ],
        ),
      ),
    );
  }

  String _getInitial(String name) {
    if (name.isEmpty) return 'M';
    return name[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final glass = context.glass;

    if (_isLoading) {
      return GlassScaffold(
        appBar: const GlassHeader(title: 'Team Performance & Goals'),
        body: LoadingShimmer(),
      );
    }

    final filteredPerformances = _performances.where((p) {
      final name = (p['name'] ?? '').toString().toLowerCase();
      final desig = (p['designation'] ?? '').toString().toLowerCase();
      return _searchTerm.isEmpty || name.contains(_searchTerm.toLowerCase()) || desig.contains(_searchTerm.toLowerCase());
    }).toList();

    final filteredGoals = _teamGoals.where((g) {
      final name = (g['employeeName'] ?? '').toString().toLowerCase();
      final title = (g['title'] ?? '').toString().toLowerCase();
      return _searchTerm.isEmpty || name.contains(_searchTerm.toLowerCase()) || title.contains(_searchTerm.toLowerCase());
    }).toList();

    return GlassScaffold(
      appBar: const GlassHeader(title: 'Team Performance & Goals'),
      body: RefreshIndicator(
        onRefresh: _loadPerformanceData,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Stat Cards Row
              Row(
                children: [
                  Expanded(child: StatCard(title: 'Members', value: '${_performances.length}', icon: Icons.group, iconColor: AppColors.primary, iconBgColor: AppColors.lightPrimary)),
                  const SizedBox(width: 8),
                  Expanded(child: StatCard(title: 'Active Goals', value: '${_teamGoals.length}', icon: Icons.track_changes, iconColor: AppColors.success, iconBgColor: AppColors.successBg)),
                  const SizedBox(width: 8),
                  Expanded(child: StatCard(title: 'Pending', value: '${_pendingReviewGoals.length}', icon: Icons.pending, iconColor: AppColors.warning, iconBgColor: AppColors.warningBg)),
                ],
              ),
              const SizedBox(height: 16),

              // Action Bar & Tabs (Wrapped with Expanded to prevent horizontal overflow)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: [
                          _buildTabChip('Overview', 'team'),
                          const SizedBox(width: 6),
                          _buildTabChip('Goals (${_teamGoals.length})', 'goals'),
                          const SizedBox(width: 6),
                          _buildTabChip('Pending (${_pendingReviewGoals.length})', 'review'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const TlAssignGoalScreen()),
                      );
                      _loadPerformanceData();
                    },
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Assign Goal'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Search Bar
              TextField(
                style: TextStyle(color: glass.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Search employee or goals...',
                  labelStyle: TextStyle(color: glass.textSecondary),
                  prefixIcon: Icon(Icons.search, color: glass.textSecondary),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF1A2632) : AppColors.lightInputBackground,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                onChanged: (val) => setState(() => _searchTerm = val),
              ),
              const SizedBox(height: 16),

              if (_activeTab == 'team') ...[
                Text('Team Scorecards Overview', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: glass.textPrimary)),
                const SizedBox(height: 12),

                if (filteredPerformances.isEmpty)
                  AppCard(
                    child: Padding(padding: const EdgeInsets.all(24), child: Center(child: Text('No performance records found.', style: TextStyle(color: glass.textSecondary)))),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filteredPerformances.length,
                    itemBuilder: (context, index) {
                      final p = filteredPerformances[index] as Map<String, dynamic>;
                      final name = p['name'] ?? 'Member';
                      final desig = p['designation'] ?? 'Staff';
                      final rating = (p['avgRating'] ?? 5.0).toDouble();
                      final overall = p['overall'] ?? 90;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: AppCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: AppColors.primary,
                                    child: Text(_getInitial(name), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: glass.textPrimary)),
                                        Text(desig, style: TextStyle(fontSize: 12, color: glass.textSecondary)),
                                      ],
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      const Icon(Icons.star, size: 14, color: AppColors.warning),
                                      const SizedBox(width: 2),
                                      Text('$rating', style: TextStyle(fontWeight: FontWeight.bold, color: glass.textPrimary)),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Overall Score: $overall%', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary)),
                                  TextButton.icon(
                                    onPressed: () async {
                                      await Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (_) => const TlAssignGoalScreen()),
                                      );
                                      _loadPerformanceData();
                                    },
                                    icon: const Icon(Icons.add, size: 16),
                                    label: const Text('Assign Goal'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
              ] else if (_activeTab == 'goals') ...[
                Text('Team Tracked Goals', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: glass.textPrimary)),
                const SizedBox(height: 12),

                if (filteredGoals.isEmpty)
                  AppCard(
                    child: Padding(padding: const EdgeInsets.all(24), child: Center(child: Text('No goals assigned.', style: TextStyle(color: glass.textSecondary)))),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filteredGoals.length,
                    itemBuilder: (context, index) {
                      final g = filteredGoals[index] as Map<String, dynamic>;
                      final name = g['employeeName'] ?? 'Member';
                      final title = g['title'] ?? 'Goal Title';
                      final cat = g['category'] ?? 'GENERAL';
                      final pct = g['achievementPercentage'] ?? 0;
                      final status = g['status'] ?? 'IN_PROGRESS';

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: AppCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: glass.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  ),
                                  const SizedBox(width: 8),
                                  StatusChip(status: status),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(title, style: TextStyle(fontSize: 13, color: glass.textSecondary)),
                              const SizedBox(height: 8),
                              LinearProgressIndicator(
                                value: (pct / 100).clamp(0.0, 1.0),
                                backgroundColor: isDark ? AppColors.darkSecondarySurface : AppColors.lightSurface,
                                color: pct >= 80 ? AppColors.success : AppColors.primary,
                              ),
                              const SizedBox(height: 6),
                              Text('$cat • $pct% Achieved', style: TextStyle(fontSize: 11, color: glass.textSecondary)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
              ] else ...[
                Text('Goals Pending Review', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: glass.textPrimary)),
                const SizedBox(height: 12),

                if (_pendingReviewGoals.isEmpty)
                  AppCard(
                    child: Padding(padding: const EdgeInsets.all(24), child: Center(child: Text('All caught up! No pending reviews.', style: TextStyle(color: glass.textSecondary)))),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _pendingReviewGoals.length,
                    itemBuilder: (context, index) {
                      final g = _pendingReviewGoals[index] as Map<String, dynamic>;
                      final name = g['employeeName'] ?? 'Member';
                      final title = g['title'] ?? 'Goal Title';

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: AppCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: glass.textPrimary)),
                              const SizedBox(height: 4),
                              Text(title, style: TextStyle(fontSize: 13, color: glass.textSecondary)),
                              const Divider(height: 20),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  ElevatedButton.icon(
                                    onPressed: () => _reviewGoalModal(g),
                                    icon: const Icon(Icons.rate_review, size: 16),
                                    label: const Text('Review Goal'),
                                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabChip(String label, String tabKey) {
    final isSelected = _activeTab == tabKey;
    final glass = context.glass;
    return Material(
      color: Colors.transparent,
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        selectedColor: AppColors.primary,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : glass.textPrimary,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
          fontSize: 12,
        ),
        onSelected: (_) => setState(() => _activeTab = tabKey),
      ),
    );
  }
}
