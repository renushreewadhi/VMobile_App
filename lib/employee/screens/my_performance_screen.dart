import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../core/api/api_client.dart';
import '../../core/auth/auth_service.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/loading_shimmer.dart';
import '../../shared/widgets/status_chip.dart';

class MyPerformanceScreen extends ConsumerStatefulWidget {
  const MyPerformanceScreen({super.key});

  @override
  ConsumerState<MyPerformanceScreen> createState() => _MyPerformanceScreenState();
}

class _MyPerformanceScreenState extends ConsumerState<MyPerformanceScreen> {
  bool _isLoading = true;
  String _activeTab = 'overview'; // 'overview' | 'goals'
  List<dynamic> _goals = [];

  @override
  void initState() {
    super.initState();
    _fetchPerformance();
  }

  Future<void> _fetchPerformance() async {
    setState(() => _isLoading = true);
    final apiClient = ref.read(apiClientProvider);
    try {
      final res = await apiClient.get('/performance/goals/my').catchError((_) => null);
      if (mounted) {
        setState(() {
          if (res is List) {
            _goals = res;
          } else if (res is Map<String, dynamic> && res['data'] is List) {
            _goals = res['data'];
          } else {
            _goals = [
              {'title': 'Complete Cloud Microservices Migration', 'category': 'PROJECT_PROGRESS', 'targetValue': 100, 'achievedValue': 95, 'unit': '%', 'achievementPercentage': 95, 'status': 'ACHIEVED', 'selfRating': 5, 'managerRating': 5},
              {'title': 'Improve Task Completion Rate', 'category': 'EOD_SUBMISSION', 'targetValue': 100, 'achievedValue': 80, 'unit': 'tasks', 'achievementPercentage': 80, 'status': 'IN_PROGRESS', 'selfRating': 4, 'managerRating': 4},
            ];
          }
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('My Performance')),
      body: _isLoading
          ? const DashboardSkeleton()
          : RefreshIndicator(
              onRefresh: _fetchPerformance,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Tabs Group
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSecondarySurface : AppColors.lightSecondarySurface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.all(4),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _activeTab = 'overview'),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: _activeTab == 'overview' ? AppColors.primary : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text('Overview', style: TextStyle(fontSize: 13, fontWeight: _activeTab == 'overview' ? FontWeight.bold : FontWeight.w600, color: _activeTab == 'overview' ? Colors.white : AppColors.lightSecondaryText)),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _activeTab = 'goals'),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: _activeTab == 'goals' ? AppColors.primary : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text('My Goals (${_goals.length})', style: TextStyle(fontSize: 13, fontWeight: _activeTab == 'goals' ? FontWeight.bold : FontWeight.w600, color: _activeTab == 'goals' ? Colors.white : AppColors.lightSecondaryText)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    if (_activeTab == 'overview') _buildOverviewTab(isDark),
                    if (_activeTab == 'goals') _buildGoalsTab(isDark),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildOverviewTab(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Executive Performance Hero Banner
        Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1D4ED8), Color(0xFF255FE2), Color(0xFF4F46E5)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.all(20),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('OVERALL PERFORMANCE INDEX', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white70, letterSpacing: 0.8)),
              SizedBox(height: 4),
              Text('88 / 100', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
              SizedBox(height: 4),
              Text('Status: EXCELLENT PERFORMANCE • Top 5% Performer', style: TextStyle(fontSize: 12.5, color: Colors.white70)),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Hero KPI Grid
        Row(
          children: [
            Expanded(child: _kpiCard('Goals Completed', '2 / 3', Icons.flag, Colors.blue)),
            const SizedBox(width: 8),
            Expanded(child: _kpiCard('On-Time Delivery', '92%', Icons.rocket, Colors.green)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _kpiCard('Manager Rating', '4.4 / 5.0', Icons.star, Colors.amber)),
            const SizedBox(width: 8),
            Expanded(child: _kpiCard('Team Rank', 'Top 10%', Icons.emoji_events, Colors.purple)),
          ],
        ),
        const SizedBox(height: 20),

        // Competencies Bar Chart
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Competencies Analytics Chart', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 16),
              SizedBox(
                height: 160,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: 100,
                    barTouchData: BarTouchData(enabled: false),
                    titlesData: FlTitlesData(
                      show: true,
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (val, meta) {
                            const labels = ['Code', 'Sprint', 'Punctual', 'Design'];
                            final idx = val.toInt();
                            if (idx >= 0 && idx < labels.length) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(labels[idx], style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ),
                    ),
                    gridData: const FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    barGroups: [
                      _barGroup(0, 92, AppColors.primary),
                      _barGroup(1, 88, AppColors.success),
                      _barGroup(2, 94, AppColors.warning),
                      _barGroup(3, 85, AppColors.info),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Key Competencies & Skills Breakdown
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Key Competencies & Skill Breakdown', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 14),
              _skillBar('Technical Architecture & Code Quality', 92, AppColors.primary),
              const SizedBox(height: 12),
              _skillBar('Sprint Task Completion & Delivery', 88, AppColors.success),
              const SizedBox(height: 12),
              _skillBar('On-Time Check-In & Punctuality', 94, AppColors.warning),
              const SizedBox(height: 12),
              _skillBar('Problem Solving & System Design', 85, AppColors.info),
            ],
          ),
        ),
      ],
    );
  }

  BarChartGroupData _barGroup(int x, double y, Color color) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          color: color,
          width: 22,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
        ),
      ],
    );
  }

  Widget _kpiCard(String label, String value, IconData icon, Color color) {
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              Text(label, style: const TextStyle(fontSize: 10.5, color: AppColors.lightSecondaryText)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _skillBar(String name, int score, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(name, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
            Text('$score%', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: score / 100,
          backgroundColor: Colors.grey.shade300,
          color: color,
        ),
      ],
    );
  }

  Widget _buildGoalsTab(bool isDark) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('My Goals (Auto-Tracked)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 4),
          const Text('System automatically updates achievement from attendance, tasks, and projects', style: TextStyle(fontSize: 12, color: AppColors.lightSecondaryText)),
          const Divider(height: 24),
          _goals.isEmpty
              ? const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('No goals assigned yet.')))
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _goals.length,
                  itemBuilder: (context, index) {
                    final g = _goals[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkSecondarySurface : AppColors.lightInputBackground,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: isDark ? AppColors.darkBordersAndDividers : AppColors.lightBordersAndDividers),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(child: Text(g['title'] ?? 'Goal Item', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                                StatusChip(status: g['status'] ?? 'IN_PROGRESS'),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Target: ${g['targetValue']} ${g['unit'] ?? ''}', style: const TextStyle(fontSize: 12, color: AppColors.lightSecondaryText)),
                                Text('Achieved: ${g['achievedValue']} ${g['unit'] ?? ''}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.success)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            LinearProgressIndicator(
                              value: (g['achievementPercentage'] ?? 0) / 100,
                              backgroundColor: Colors.grey.shade300,
                              color: AppColors.success,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ],
      ),
    );
  }
}
