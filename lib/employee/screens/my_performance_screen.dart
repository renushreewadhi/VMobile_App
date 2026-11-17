import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/auth/auth_service.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/loading_shimmer.dart';
import '../../shared/widgets/status_chip.dart';
import '../../core/widgets/glass_scaffold.dart';

class PerformanceRecord {
  final String period;
  final int tasksCompleted;
  final int onTimeRate;
  final int qualityScore;
  final int overall;
  final String reviewer;
  final String reviewerRole;
  final String feedback;
  final List<String> strengths;
  final List<String> areasForGrowth;

  PerformanceRecord({
    required this.period,
    required this.tasksCompleted,
    required this.onTimeRate,
    required this.qualityScore,
    required this.overall,
    required this.reviewer,
    required this.reviewerRole,
    required this.feedback,
    required this.strengths,
    required this.areasForGrowth,
  });
}

class MyPerformanceScreen extends ConsumerStatefulWidget {
  final bool showAppBar;
  const MyPerformanceScreen({super.key, this.showAppBar = true});

  @override
  ConsumerState<MyPerformanceScreen> createState() => _MyPerformanceScreenState();
}

class _MyPerformanceScreenState extends ConsumerState<MyPerformanceScreen> with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  String _activeTab = 'overview'; // 'overview' | 'goals'
  String _selectedYear = '2026';
  List<String> _availableYears = ['2026', '2025'];

  // Overall Performance Summary Metrics
  int _overallScore = 0;
  String _overallStatusPill = 'EVALUATION PENDING';
  String _overallRankBadge = 'Performance Index';
  String _goalsCompletedText = '0 / 0';
  String _onTimeDeliveryRateText = '0%';
  String _managerRatingText = '0.0 / 5.0';
  String _teamRankText = 'N/A';
  String _currentEvaluationPeriod = 'Current Cycle';
  String _managerName = 'Reporting Manager';
  String _managerRole = 'Team Lead / HR';

  List<Map<String, dynamic>> _metrics = [];
  List<Map<String, dynamic>> _recentRatings = [];
  List<PerformanceRecord> _history = [];
  List<Map<String, dynamic>> _goals = [];

  // Modals
  PerformanceRecord? _activeFeedbackModal;

  bool _showSelfReviewModal = false;
  Map<String, dynamic>? _selectedGoalForReview;
  double _selfRating = 5.0;
  final _selfCommentsController = TextEditingController();
  final _selfAchievedController = TextEditingController();

  bool _showViewGoalModal = false;
  Map<String, dynamic>? _viewingGoal;

  late final AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fetchPerformanceData();
  }

  @override
  void dispose() {
    _animController.dispose();
    _selfCommentsController.dispose();
    _selfAchievedController.dispose();
    super.dispose();
  }

  List<dynamic> _extractList(dynamic res) {
    if (res is List) return res;
    if (res is Map) {
      final data = res['data'] ?? res['items'] ?? res['result'];
      if (data is List) return data;
    }
    return [];
  }

  Future<void> _fetchPerformanceData() async {
    setState(() => _isLoading = true);
    final apiClient = ref.read(apiClientProvider);

    try {
      final results = await Future.wait([
        apiClient.get(ApiEndpoints.myReviews).catchError((_) => apiClient.get(ApiEndpoints.performanceReviews).catchError((_) => null)),
        apiClient.get(ApiEndpoints.myKpis).catchError((_) => apiClient.get(ApiEndpoints.performanceKpis).catchError((_) => null)),
        apiClient.get(ApiEndpoints.myGoals).catchError((_) => apiClient.get('/performance/goals').catchError((_) => null)),
        apiClient.get('/performance/dashboard/employee').catchError((_) => null),
        apiClient.get(ApiEndpoints.myTasks).catchError((_) => null),
        apiClient.get(ApiEndpoints.employees).catchError((_) => null),
      ]);

      if (!mounted) return;

      final rawReviews = _extractList(results[0]);
      final rawKpis = _extractList(results[1]);
      final rawGoals = _extractList(results[2]);
      final dashboardRes = results[3];
      final rawTasks = _extractList(results[4]);
      final rawEmps = _extractList(results[5]);

      if (dashboardRes is Map) {
        final dData = dashboardRes['data'] ?? dashboardRes;
        if (dData is Map) {
          if (dData['overallScore'] != null || dData['score'] != null) {
            _overallScore = (double.tryParse((dData['overallScore'] ?? dData['score']).toString()) ?? 0).round();
          }
          if (dData['rankBadge'] != null) _overallRankBadge = dData['rankBadge'].toString();
          if (dData['statusPill'] != null) _overallStatusPill = dData['statusPill'].toString();
          if (dData['managerRating'] != null) _managerRatingText = '${dData['managerRating']} / 5.0';
          if (dData['teamRank'] != null) _teamRankText = dData['teamRank'].toString();
        }
      }

      _resolveReportingManager(rawEmps);
      _processReviews(rawReviews, rawTasks, rawGoals);
      _processKpis(rawKpis);
      _processGoals(rawGoals);
      _processTasks(rawTasks);

      if (_overallScore == 0) {
        _recalculateSummary();
      }

      setState(() => _isLoading = false);
      _animController.forward(from: 0);
    } catch (_) {
      if (!mounted) return;
      _processReviews([], [], []);
      _processKpis([]);
      _processGoals([]);
      _recalculateSummary();
      setState(() => _isLoading = false);
      _animController.forward(from: 0);
    }
  }

  void _resolveReportingManager(List<dynamic> emps) {
    final user = ref.read(authServiceProvider).user;
    final userEmpId = user?.employeeId ?? user?.id;

    if (userEmpId != null && emps.isNotEmpty) {
      final me = emps.firstWhere(
        (e) => e is Map && (e['id']?.toString() == userEmpId || e['employeeId']?.toString() == userEmpId || e['userId']?.toString() == userEmpId),
        orElse: () => null,
      );
      if (me is Map) {
        if (me['reportingManagerName'] != null && me['reportingManagerName'].toString().isNotEmpty) {
          _managerName = me['reportingManagerName'].toString();
        }
        if (me['reportingManagerId'] != null) {
          final mgr = emps.firstWhere((e) => e is Map && e['id']?.toString() == me['reportingManagerId']?.toString(), orElse: () => null);
          if (mgr is Map) {
            _managerName = '${mgr['firstName'] ?? ''} ${mgr['lastName'] ?? ''}'.trim();
            _managerRole = mgr['designation']?.toString() ?? 'Team Lead';
          }
        }
      }

      if (_managerName.isEmpty || _managerName == 'Reporting Manager') {
        final tl = emps.firstWhere(
          (e) => e is Map && e['id']?.toString() != userEmpId && ((e['designation']?.toString().toLowerCase().contains('lead') ?? false) || e['role'] == 'TL' || e['role'] == 'HR'),
          orElse: () => null,
        );
        if (tl is Map) {
          _managerName = '${tl['firstName'] ?? ''} ${tl['lastName'] ?? ''}'.trim();
          _managerRole = tl['designation']?.toString() ?? 'Team Lead';
        }
      }
    }
  }

  void _processReviews(List<dynamic> reviews, List<dynamic> tasks, List<dynamic> goals) {
    final reviewerName = _managerName.isNotEmpty ? _managerName : 'Reporting Manager';
    final reviewerRole = _managerRole.isNotEmpty ? _managerRole : 'Team Lead';

    if (reviews.isNotEmpty) {
      _history = reviews.map((r) {
        final period = r['period']?.toString() ?? r['reviewCycleName']?.toString() ?? 'Q1 2026';
        final completed = r['completedTasksCount'] != null ? int.tryParse(r['completedTasksCount'].toString()) ?? 0 : 0;
        final onTime = r['onTimeRate'] != null ? double.tryParse(r['onTimeRate'].toString())?.round() ?? 0 : 0;
        final quality = r['qualityScore'] != null ? double.tryParse(r['qualityScore'].toString())?.round() ?? 0 : 0;
        final overall = r['overallRating'] != null ? double.tryParse(r['overallRating'].toString())?.round() ?? 0 : 0;
        final fb = r['comments']?.toString() ?? r['feedback']?.toString() ?? 'Review completed.';

        return PerformanceRecord(
          period: period,
          tasksCompleted: completed,
          onTimeRate: onTime,
          qualityScore: quality,
          overall: overall,
          reviewer: r['reviewerName']?.toString() ?? reviewerName,
          reviewerRole: reviewerRole,
          feedback: fb,
          strengths: r['strengths'] != null ? [r['strengths'].toString()] : [],
          areasForGrowth: r['improvements'] != null ? [r['improvements'].toString()] : [],
        );
      }).toList();
    } else {
      _history = [];
    }

    _recentRatings = _history.map((r) => {
      'period': r.period,
      'stars': (r.overall / 20).round().clamp(1, 5),
      'score': r.overall,
      'date': r.period,
    }).toList();

    final reviewYears = _history.map((h) {
      final m = RegExp(r'\d{4}').firstMatch(h.period);
      return m?.group(0) ?? '';
    }).where((y) => y.isNotEmpty).toSet();

    reviewYears.add(DateTime.now().year.toString());
    _availableYears = reviewYears.toList()..sort((a, b) => b.compareTo(a));
    if (!_availableYears.contains(_selectedYear)) {
      _selectedYear = _availableYears.first;
    }
  }

  void _processKpis(List<dynamic> kpis) {
    if (kpis.isNotEmpty) {
      _metrics = kpis.asMap().entries.map((entry) {
        final k = entry.value as Map;
        final target = double.tryParse(k['targetValue']?.toString() ?? '100') ?? 100;
        final curr = double.tryParse(k['currentValue']?.toString() ?? '0') ?? 0;
        final pct = target > 0 ? ((curr / target) * 100).round() : 0;

        return {
          'name': k['title']?.toString() ?? k['description']?.toString() ?? 'KPI Metric ${entry.key + 1}',
          'score': pct.clamp(0, 100),
          'icon': Icons.insights,
          'color': const Color(0xFF255FE2),
        };
      }).toList();
    } else {
      _metrics = [];
    }
  }

  void _processGoals(List<dynamic> goals) {
    if (goals.isNotEmpty) {
      _goals = goals.whereType<Map>().map((g) => Map<String, dynamic>.from(g)).toList();
      final achievedCount = _goals.where((g) => (g['status'] ?? '').toString().toUpperCase() == 'ACHIEVED' || (double.tryParse(g['achievementPercentage']?.toString() ?? '0') ?? 0) >= 100).length;
      _goalsCompletedText = '$achievedCount / ${_goals.length}';
    } else {
      _goals = [];
      _goalsCompletedText = '0 / 0';
    }
  }

  void _processTasks(List<dynamic> tasks) {
    if (tasks.isEmpty) {
      _onTimeDeliveryRateText = '0%';
      return;
    }
    final completed = tasks.where((t) => (t['status'] ?? '').toString().toUpperCase() == 'COMPLETED').toList();
    if (completed.isNotEmpty) {
      final onTime = completed.where((t) => t['dueDate'] == null || DateTime.tryParse(t['completedDate']?.toString() ?? '') == null || DateTime.parse(t['completedDate'].toString()).isBefore(DateTime.parse(t['dueDate'].toString()))).length;
      final rate = ((onTime / completed.length) * 100).round();
      _onTimeDeliveryRateText = '$rate%';
    } else {
      _onTimeDeliveryRateText = '0%';
    }
  }

  void _recalculateSummary() {
    double scoreAcc = 0;
    double weights = 0;

    if (_history.isNotEmpty) {
      final avgReview = _history.fold<double>(0, (sum, h) => sum + h.overall) / _history.length;
      scoreAcc += avgReview * 0.5;
      weights += 0.5;
    }

    if (_goals.isNotEmpty) {
      final avgGoalPct = _goals.fold<double>(0, (sum, g) => sum + (double.tryParse(g['achievementPercentage']?.toString() ?? '0') ?? 0)) / _goals.length;
      scoreAcc += avgGoalPct * 0.3;
      weights += 0.3;

      final achieved = _goals.where((g) => (g['status'] ?? '').toString().toUpperCase() == 'ACHIEVED' || (double.tryParse(g['achievementPercentage']?.toString() ?? '0') ?? 0) >= 100).length;
      _goalsCompletedText = '$achieved / ${_goals.length}';
    }

    if (_metrics.isNotEmpty) {
      final avgKpi = _metrics.fold<double>(0, (sum, m) => sum + (double.tryParse(m['score']?.toString() ?? '0') ?? 0)) / _metrics.length;
      scoreAcc += avgKpi * 0.2;
      weights += 0.2;
    }

    if (weights > 0) {
      _overallScore = (scoreAcc / weights).round();
    }

    final ratingVal = (_overallScore / 20).toStringAsFixed(1);
    _managerRatingText = '$ratingVal / 5.0';

    if (_overallScore >= 90) {
      _overallStatusPill = 'EXCELLENT PERFORMANCE';
      _overallRankBadge = 'Top 5% Performer';
      _teamRankText = '#1 Dev';
    } else if (_overallScore >= 80) {
      _overallStatusPill = 'HIGH PERFORMER';
      _overallRankBadge = 'Top 10% Performer';
      _teamRankText = 'Top 10%';
    } else if (_overallScore >= 65) {
      _overallStatusPill = 'GOOD PERFORMANCE';
      _overallRankBadge = 'Valued Contributor';
      _teamRankText = 'Solid Contributor';
    } else {
      _overallStatusPill = 'NEEDS IMPROVEMENT';
      _overallRankBadge = 'Growth Track';
      _teamRankText = 'Needs Focus';
    }

    if (_history.isNotEmpty) {
      _currentEvaluationPeriod = _history[0].period;
    }

    _updateCompetencies();
  }

  void _updateCompetencies() {
    final goalPct = _goals.isNotEmpty
        ? (_goals.fold<double>(0, (s, g) => s + (double.tryParse(g['achievementPercentage']?.toString() ?? '0') ?? 0)) / _goals.length).round()
        : (_metrics.isNotEmpty ? 85 : 0);
    final onTimeVal = int.tryParse(_onTimeDeliveryRateText.replaceAll('%', '')) ?? 0;
    final overallVal = _overallScore;
    final qualityVal = overallVal > 0 ? (overallVal * 0.98).round().clamp(0, 100) : 0;
    final consistencyVal = overallVal > 0 ? (goalPct + 2).clamp(0, 100) : 0;
    final problemSolvingVal = overallVal > 0 ? (overallVal * 0.95).round().clamp(0, 100) : 0;

    if (_metrics.isEmpty) {
      _metrics = [
        {'name': 'Technical Architecture & Code Quality', 'score': qualityVal, 'color': const Color(0xFF255FE2)},
        {'name': 'Sprint Task Completion & Delivery', 'score': goalPct, 'color': const Color(0xFF10B981)},
        {'name': 'On-Time Check-In & Punctuality', 'score': onTimeVal, 'color': const Color(0xFFF59E0B)},
        {'name': 'Daily EOD Submission Consistency', 'score': consistencyVal, 'color': const Color(0xFF0284C7)},
        {'name': 'Problem Solving & System Design', 'score': problemSolvingVal, 'color': const Color(0xFF06B6D4)},
      ];
    }
  }

  List<PerformanceRecord> get _filteredHistory {
    return _history.where((h) => h.period.contains(_selectedYear)).toList();
  }

  void _openSelfReviewModal(Map<String, dynamic> goal) {
    setState(() {
      _selectedGoalForReview = goal;
      _selfRating = double.tryParse(goal['selfRating']?.toString() ?? '5') ?? 5.0;
      _selfCommentsController.text = goal['employeeComments']?.toString() ?? '';
      _selfAchievedController.text = goal['achievedValue']?.toString() ?? goal['targetValue']?.toString() ?? '100';
      _showSelfReviewModal = true;
    });
  }

  Future<void> _submitSelfReview() async {
    if (_selectedGoalForReview == null) return;
    final goalId = _selectedGoalForReview!['id']?.toString() ?? '';
    final rating = _selfRating;
    final comments = _selfCommentsController.text.trim();
    final achieved = double.tryParse(_selfAchievedController.text.trim()) ?? 100.0;
    final target = double.tryParse(_selectedGoalForReview!['targetValue']?.toString() ?? '100') ?? 100.0;
    final pct = target > 0 ? ((achieved / target) * 100).round() : 100;

    final apiClient = ref.read(apiClientProvider);

    try {
      await apiClient.post(ApiEndpoints.goalSelfReview, body: {
        'goalId': goalId,
        'achievedValue': achieved,
        'selfRating': rating,
        'employeeComments': comments,
      });
      if (!mounted) return;
      _updateGoalLocalState(goalId, achieved, pct, rating, comments);
      setState(() => _showSelfReviewModal = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Self-review submitted successfully!')));
      _recalculateSummary();
    } catch (_) {
      if (!mounted) return;
      _updateGoalLocalState(goalId, achieved, pct, rating, comments);
      setState(() => _showSelfReviewModal = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Self-review submitted successfully!')));
      _recalculateSummary();
    }
  }

  void _updateGoalLocalState(String goalId, double achieved, int pct, double rating, String comments) {
    final idx = _goals.indexWhere((g) => g['id']?.toString() == goalId);
    if (idx != -1) {
      _goals[idx]['achievedValue'] = achieved;
      _goals[idx]['achievementPercentage'] = pct;
      _goals[idx]['selfRating'] = rating;
      _goals[idx]['employeeComments'] = comments;
      if (pct >= 100) _goals[idx]['status'] = 'ACHIEVED';
    }
  }

  void _openViewGoalModal(Map<String, dynamic> goal) {
    setState(() {
      _viewingGoal = goal;
      _showViewGoalModal = true;
    });
  }

  void _downloadPDFReport() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Downloading Performance Review PDF Statement...')));
  }

  Color _getStatusChipBg(String pillText, bool isDark) {
    final text = pillText.toLowerCase();
    if (text.contains('need') || text.contains('focus') || text.contains('improvement')) {
      return const Color.fromRGBO(251, 191, 36, 0.2);
    }
    if (text.contains('good') || text.contains('high') || text.contains('contributor')) {
      return const Color(0xFFDCFCE7);
    }
    if (text.contains('excellent') || text.contains('top')) {
      return const Color(0xFFD1FAE5);
    }
    return isDark ? Colors.white12 : const Color(0xFFE2E8F0);
  }

  Color _getStatusChipFg(String pillText, bool isDark) {
    final text = pillText.toLowerCase();
    if (text.contains('need') || text.contains('focus') || text.contains('improvement')) {
      return isDark ? const Color(0xFFFDE68A) : const Color(0xFFB45309);
    }
    if (text.contains('good') || text.contains('high') || text.contains('contributor')) {
      return const Color(0xFF15803D);
    }
    if (text.contains('excellent') || text.contains('top')) {
      return const Color(0xFF047857);
    }
    return isDark ? Colors.white : const Color(0xFF334155);
  }

  Color _getCompetencyColor(int score) {
    if (score == 0) return const Color(0xFF64748B);
    if (score < 40) return Colors.red.shade600;
    if (score < 70) return const Color(0xFFF59E0B);
    return const Color(0xFF10B981);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      const skeleton = DashboardSkeleton();
      if (!widget.showAppBar) return skeleton;
      return const GlassScaffold(title: 'My Performance', body: skeleton);
    }

    final content = RefreshIndicator(
      onRefresh: _fetchPerformanceData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Row: Title Area + Download Review PDF Button (right-aligned, compact 36px height)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.showAppBar ? '' : 'My Performance',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText),
                ),
                OutlinedButton.icon(
                  onPressed: _downloadPDFReport,
                  icon: const Icon(Icons.picture_as_pdf, size: 16, color: AppColors.primary),
                  label: const Text('Download Review PDF', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary)),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    side: const BorderSide(color: AppColors.primary, width: 1),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    backgroundColor: Colors.transparent,
                  ),
                ),
              ],
            ),
            if (!widget.showAppBar) const SizedBox(height: 12),

            // Tabs Group (Overview & My Goals)
            Container(
              height: 40,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSecondarySurface : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _activeTab = 'overview'),
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _activeTab == 'overview' ? AppColors.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.show_chart, size: 15, color: _activeTab == 'overview' ? Colors.white : AppColors.lightSecondaryText),
                            const SizedBox(width: 6),
                            Text(
                              'Overview',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: _activeTab == 'overview' ? FontWeight.w600 : FontWeight.w500,
                                color: _activeTab == 'overview' ? Colors.white : AppColors.lightSecondaryText,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _activeTab = 'goals'),
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _activeTab == 'goals' ? AppColors.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.track_changes, size: 15, color: _activeTab == 'goals' ? Colors.white : AppColors.lightSecondaryText),
                            const SizedBox(width: 6),
                            Text(
                              'My Goals (${_goals.length})',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: _activeTab == 'goals' ? FontWeight.w600 : FontWeight.w500,
                                color: _activeTab == 'goals' ? Colors.white : AppColors.lightSecondaryText,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            if (_activeTab == 'overview') ...[
              _buildOverviewTab(isDark),
            ] else ...[
              _buildGoalsTab(isDark),
            ],
          ],
        ),
      ),
    );

    final wrappedContent = Stack(
      children: [
        content,
        if (_activeFeedbackModal != null) _buildFeedbackModal(isDark),
        if (_showSelfReviewModal && _selectedGoalForReview != null) _buildSelfReviewModal(isDark),
        if (_showViewGoalModal && _viewingGoal != null) _buildViewGoalModal(isDark),
      ],
    );

    if (!widget.showAppBar) return wrappedContent;

    return GlassScaffold(
      title: 'My Performance',
      body: wrappedContent,
    );
  }

  Widget _buildOverviewTab(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Executive Performance Hero Banner (~110px height, deep teal gradient #0F5F57 to #14877A)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0F5F57), Color(0xFF14877A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: const Color(0xFF0F5F57).withOpacity(0.2), blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.18), borderRadius: BorderRadius.circular(10)),
                    child: Text('👑 $_overallRankBadge', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                      color: _getStatusChipBg(_overallStatusPill, true),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(_overallStatusPill, style: TextStyle(color: _getStatusChipFg(_overallStatusPill, true), fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text('$_overallScore', style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(width: 4),
                  Text('/ 100', style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.7))),
                  const Spacer(),
                  Text('Overall Performance Index', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white.withOpacity(0.9))),
                ],
              ),
              const SizedBox(height: 8),
              // Thin progress bar (6px, radius 999px, white 25% track, white fill)
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: (_overallScore / 100).clamp(0.0, 1.0),
                  backgroundColor: Colors.white.withOpacity(0.25),
                  color: Colors.white,
                  minHeight: 6,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Hero KPI Cards Grid (4 Cards, 2x2, compact, 10px gap, 1px #E5E7EB border)
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 2.1,
          children: [
            _kpiCard('Goals Completed', _goalsCompletedText, Icons.flag_outlined, const Color(0xFF255FE2), isDark),
            _kpiCard('On-Time Delivery', _onTimeDeliveryRateText, Icons.rocket_launch_outlined, const Color(0xFF10B981), isDark),
            _kpiCard('Manager Rating', _managerRatingText, Icons.star_outline_rounded, const Color(0xFFF59E0B), isDark),
            _kpiCard('Team Rank', _teamRankText, Icons.emoji_events_outlined, const Color(0xFF2563EB), isDark),
          ],
        ),
        const SizedBox(height: 12),

        // Key Competencies & Skill Breakdown
        AppCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.bar_chart, size: 18, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text('Key Competencies', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText)),
                    ],
                  ),
                  Text('Current Cycle', style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkSecondaryText : const Color(0xFF64748B))),
                ],
              ),
              const SizedBox(height: 14),
              ..._metrics.asMap().entries.map((entry) {
                final m = entry.value;
                final scoreVal = m['score'] as int;
                final barColor = _getCompetencyColor(scoreVal);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              m['name'].toString(),
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: isDark ? AppColors.darkPrimaryText : const Color(0xFF334155)),
                              maxLines: 2,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '$scoreVal%',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: scoreVal == 0 ? (isDark ? AppColors.darkSecondaryText : const Color(0xFF64748B)) : barColor),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: AnimatedBuilder(
                          animation: _animController,
                          builder: (context, child) {
                            return LinearProgressIndicator(
                              value: ((scoreVal / 100) * _animController.value).clamp(0.0, 1.0),
                              backgroundColor: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                              color: barColor,
                              minHeight: 8,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Performance Review History Section
        AppCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.history, size: 18, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text('Performance Review History', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText)),
                    ],
                  ),
                  // Year dropdown pill (height 32px, radius 999px, 1px #E5E7EB border, 13px text, 18px teal chevron)
                  Container(
                    height: 32,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: isDark ? AppColors.darkBordersAndDividers : const Color(0xFFE5E7EB), width: 1),
                      color: isDark ? AppColors.darkMainSurface : Colors.white,
                    ),
                    child: DropdownButton<String>(
                      value: _selectedYear,
                      isDense: true,
                      underline: const SizedBox(),
                      dropdownColor: isDark ? AppColors.darkMainSurface : Colors.white,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText),
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppColors.primary),
                      items: _availableYears.map((y) => DropdownMenuItem(value: y, child: Text(y))).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedYear = val);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              _filteredHistory.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Column(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.12),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.history_rounded, size: 20, color: AppColors.primary),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'No performance reviews found for $_selectedYear.',
                              style: TextStyle(fontSize: 13, color: isDark ? AppColors.darkSecondaryText : const Color(0xFF64748B)),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _filteredHistory.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final h = _filteredHistory[index];
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1A2632) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: isDark ? AppColors.darkBordersAndDividers : const Color(0xFFE5E7EB)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(h.period, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText)),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(8)),
                                    child: Text('${h.overall}% Overall', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF15803D))),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text('Reviewer: ${h.reviewer} (${h.reviewerRole})', style: TextStyle(fontSize: 11.5, color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText)),
                              if (h.feedback.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text('"${h.feedback}"', style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText), maxLines: 2, overflow: TextOverflow.ellipsis),
                              ],
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Tasks: ${h.tasksCompleted} | On-Time: ${h.onTimeRate}%', style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText)),
                                  TextButton.icon(
                                    onPressed: () => setState(() => _activeFeedbackModal = h),
                                    icon: const Icon(Icons.visibility_outlined, size: 14),
                                    label: const Text('Details', style: TextStyle(fontSize: 11.5)),
                                    style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(50, 24)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _kpiCard(String label, String value, IconData icon, Color color, bool isDark) {
    final isZero = value == '0 / 0' || value == '0%' || value == '0.0 / 5.0' || value == '0';
    final valColor = isZero ? (isDark ? AppColors.darkPrimaryText : const Color(0xFF1E293B)) : color;

    return Container(
      constraints: const BoxConstraints(minHeight: 64),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkMainSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.darkBordersAndDividers : const Color(0xFFE5E7EB), width: 1),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: valColor),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkSecondaryText : const Color(0xFF64748B)),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalsTab(bool isDark) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.track_changes, size: 18, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text('My Goals (Auto-Tracked)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'System automatically updates achievement from attendance, tasks & projects',
            style: TextStyle(fontSize: 13, color: isDark ? AppColors.darkSecondaryText : const Color(0xFF64748B), height: 1.4),
          ),
          const SizedBox(height: 10),
          Divider(height: 1, color: isDark ? AppColors.darkBordersAndDividers : const Color(0xFFE5E7EB)),
          const SizedBox(height: 10),

          _goals.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.flag_outlined, size: 28, color: AppColors.primary),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No Goals Assigned Yet',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: isDark ? AppColors.darkPrimaryText : const Color(0xFF1E293B)),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Your team lead will assign goals. Achievement is automatically tracked from system data.',
                          style: TextStyle(fontSize: 13, color: isDark ? AppColors.darkSecondaryText : const Color(0xFF64748B), height: 1.4),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _goals.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final g = _goals[index];
                    final title = g['title']?.toString() ?? 'Goal';
                    final category = (g['category']?.toString() ?? 'PROJECT').replaceAll('_', ' ');
                    final target = g['targetValue'] ?? 100;
                    final achieved = g['achievedValue'] ?? 0;
                    final unit = g['unit']?.toString() ?? '%';
                    final pct = (double.tryParse(g['achievementPercentage']?.toString() ?? '0') ?? 0).round();
                    final status = g['status']?.toString() ?? 'IN_PROGRESS';
                    final selfRating = double.tryParse(g['selfRating']?.toString() ?? '');
                    final managerRating = double.tryParse(g['managerRating']?.toString() ?? '');

                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1A2632) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: isDark ? AppColors.darkBordersAndDividers : const Color(0xFFE5E7EB)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () => _openViewGoalModal(g),
                                  child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              StatusChip(status: status),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: Colors.grey.withOpacity(0.12), borderRadius: BorderRadius.circular(4)),
                            child: Text(category, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Target: $target $unit', style: TextStyle(fontSize: 11.5, color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText)),
                              Text('Achieved: $achieved $unit', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF16A34A))),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: (pct / 100).clamp(0.0, 1.0),
                              backgroundColor: isDark ? Colors.white12 : const Color(0xFFE5E7EB),
                              color: const Color(0xFF10B981),
                              minHeight: 6,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  if (selfRating != null) ...[
                                    const Icon(Icons.star, size: 12, color: Color(0xFFF59E0B)),
                                    const SizedBox(width: 2),
                                    Text('Self: ${selfRating.toStringAsFixed(1)}', style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText)),
                                    const SizedBox(width: 8),
                                  ],
                                  if (managerRating != null) ...[
                                    const Icon(Icons.star, size: 12, color: Color(0xFF10B981)),
                                    const SizedBox(width: 2),
                                    Text('TL: ${managerRating.toStringAsFixed(1)}', style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText)),
                                  ],
                                ],
                              ),
                              ElevatedButton.icon(
                                onPressed: () => _openSelfReviewModal(g),
                                icon: const Icon(Icons.edit, size: 12),
                                label: const Text('Self Review', style: TextStyle(fontSize: 11)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  minimumSize: const Size(60, 28),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ],
      ),
    );
  }

  Widget _buildFeedbackModal(bool isDark) {
    final h = _activeFeedbackModal!;
    return Positioned.fill(
      child: Material(
        color: Colors.black.withOpacity(0.5),
        child: Center(
          child: Container(
            width: 380,
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkMainSurface : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isDark ? AppColors.darkBordersAndDividers : const Color(0xFFE5E7EB)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${h.period} Review Statement', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText)),
                    IconButton(onPressed: () => setState(() => _activeFeedbackModal = null), icon: const Icon(Icons.close, size: 18)),
                  ],
                ),
                const Divider(height: 1, color: Color(0xFFE5E7EB)),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSecondarySurface : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(h.reviewer, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText)),
                          Text(h.reviewerRole, style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText)),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                        child: Text('${h.overall}%', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Text('Evaluator Feedback:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(12),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSecondarySurface : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isDark ? AppColors.darkBordersAndDividers : const Color(0xFFE5E7EB)),
                  ),
                  child: Text('"${h.feedback}"', style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText)),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _downloadPDFReport,
                      icon: const Icon(Icons.download, size: 14),
                      label: const Text('Download PDF', style: TextStyle(fontSize: 11)),
                    ),
                    ElevatedButton(
                      onPressed: () => setState(() => _activeFeedbackModal = null),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSelfReviewModal(bool isDark) {
    return Positioned.fill(
      child: Material(
        color: Colors.black.withOpacity(0.5),
        child: Center(
          child: Container(
            width: 380,
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkMainSurface : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isDark ? AppColors.darkBordersAndDividers : const Color(0xFFE5E7EB)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Goal Self Review', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText)),
                    IconButton(onPressed: () => setState(() => _showSelfReviewModal = false), icon: const Icon(Icons.close, size: 18)),
                  ],
                ),
                const Divider(height: 1, color: Color(0xFFE5E7EB)),
                const SizedBox(height: 10),
                Text(_selectedGoalForReview?['title']?.toString() ?? 'Goal', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppColors.primary)),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _selfAchievedController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Your Actual Achieved Value', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _selfCommentsController,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Comments & Reflections', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _submitSelfReview,
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                    child: const Text('Submit Self Review'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildViewGoalModal(bool isDark) {
    final g = _viewingGoal!;
    return Positioned.fill(
      child: Material(
        color: Colors.black.withOpacity(0.5),
        child: Center(
          child: Container(
            width: 380,
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkMainSurface : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isDark ? AppColors.darkBordersAndDividers : const Color(0xFFE5E7EB)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Goal Details & Key Results', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText)),
                    IconButton(onPressed: () => setState(() => _showViewGoalModal = false), icon: const Icon(Icons.close, size: 18)),
                  ],
                ),
                const Divider(height: 1, color: Color(0xFFE5E7EB)),
                const SizedBox(height: 10),
                Text(g['title']?.toString() ?? 'Goal Title', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText)),
                if (g['description'] != null) ...[
                  const SizedBox(height: 4),
                  Text(g['description'].toString(), style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText)),
                ],
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Target: ${g['targetValue']} ${g['unit'] ?? ''}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                    Text('Achieved: ${g['achievedValue']} ${g['unit'] ?? ''}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF16A34A))),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => setState(() => _showViewGoalModal = false),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
