import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/auth/auth_service.dart';
import '../../core/errors/api_exception.dart';
import '../../core/models/user_model.dart';
import '../../core/theme/glass_theme.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/glass_header.dart';

/// Strongly typed Performance Review Model
class PerformanceReviewModel {
  final String id;
  final String employeeId;
  final String employeeName;
  final String department;
  final String reviewPeriod;
  final double rating;
  final double goalsMetPct;
  final String reviewer;
  final String status; // COMPLETED, IN_PROGRESS, PENDING, PIP
  final String? comments;

  PerformanceReviewModel({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.department,
    required this.reviewPeriod,
    required this.rating,
    required this.goalsMetPct,
    required this.reviewer,
    required this.status,
    this.comments,
  });

  factory PerformanceReviewModel.fromJson(Map<String, dynamic> json) {
    String empName = json['employeeName']?.toString() ?? '';
    if (empName.isEmpty && json['employee'] is Map<String, dynamic>) {
      final emp = json['employee'] as Map<String, dynamic>;
      empName = '${emp['firstName'] ?? ''} ${emp['lastName'] ?? ''}'.trim();
    }
    if (empName.isEmpty) empName = 'Employee';

    final rawRating = json['overallRating'] ?? json['rating'] ?? 4.0;
    final ratingDouble = rawRating is num ? rawRating.toDouble() : (double.tryParse(rawRating.toString()) ?? 4.0);

    final rawGoals = json['goalsRating'] ?? json['goalsMet'] ?? 85;
    final goalsDouble = rawGoals is num ? rawGoals.toDouble() : (double.tryParse(rawGoals.toString()) ?? 85.0);

    return PerformanceReviewModel(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      employeeId: json['employeeCode']?.toString() ?? json['employeeId']?.toString() ?? 'EMP-000',
      employeeName: empName,
      department: json['departmentName']?.toString() ?? json['department']?.toString() ?? 'General',
      reviewPeriod: json['period']?.toString() ?? json['reviewPeriod']?.toString() ?? 'Q4 2025',
      rating: ratingDouble,
      goalsMetPct: goalsDouble,
      reviewer: json['reviewerName']?.toString() ?? json['reviewer']?.toString() ?? 'Manager',
      status: (json['status']?.toString() ?? 'COMPLETED').toUpperCase(),
      comments: json['comments']?.toString() ?? json['evaluationSummary']?.toString(),
    );
  }
}

/// Strongly typed KPI Target Model
class KpiTargetModel {
  final String id;
  final String title;
  final String department;
  final String target;
  final String currentAchievement;
  final String weight;
  final String status; // ACTIVE, INACTIVE

  KpiTargetModel({
    required this.id,
    required this.title,
    required this.department,
    required this.target,
    required this.currentAchievement,
    required this.weight,
    required this.status,
  });

  factory KpiTargetModel.fromJson(Map<String, dynamic> json) {
    return KpiTargetModel(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      title: json['title']?.toString() ?? json['name']?.toString() ?? 'KPI Target',
      department: json['department']?.toString() ?? json['departmentName']?.toString() ?? 'General',
      target: json['targetValue'] != null ? '${json['targetValue']} ${json['unit'] ?? '%'}' : (json['target']?.toString() ?? '100%'),
      currentAchievement: json['currentValue'] != null ? '${json['currentValue']} ${json['unit'] ?? '%'}' : (json['currentAchievement']?.toString() ?? '0%'),
      weight: json['weight'] != null ? '${json['weight']}%' : '20%',
      status: (json['status']?.toString() ?? 'ACTIVE').toUpperCase(),
    );
  }
}

class AdminPerformanceScreen extends ConsumerStatefulWidget {
  const AdminPerformanceScreen({super.key});

  @override
  ConsumerState<AdminPerformanceScreen> createState() => _AdminPerformanceScreenState();
}

class _AdminPerformanceScreenState extends ConsumerState<AdminPerformanceScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  String _activeTab = 'reviews'; // 'reviews' or 'kpi'

  List<PerformanceReviewModel> _reviews = [];
  List<KpiTargetModel> _kpis = [];

  String _searchTerm = '';
  String _statusFilter = 'ALL'; // ALL, COMPLETED, IN_PROGRESS, PENDING, PIP

  // Request ID guard
  int _requestId = 0;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _checkUserAndLoad();
      }
    });
  }

  void _checkUserAndLoad() {
    _requestId++; // Immediately invalidate any in-flight requests
    final authState = ref.read(authServiceProvider);
    final user = authState.user;

    if (user == null || !authState.isAuthenticated) {
      if (!mounted) return;
      _resetState();
      setState(() {
        _isLoading = false;
        _errorMessage = 'No authenticated user found.';
      });
      return;
    }

    if (_currentUserId != user.id) {
      _currentUserId = user.id;
      _resetState();
    }

    // Role Guard Check: Must be ADMIN or HR
    final userRole = user.role;
    final bool isAuthorized = userRole == UserRole.ADMIN || userRole == UserRole.HR;

    if (!isAuthorized) {
      if (!mounted) return;
      _resetState();
      setState(() {
        _isLoading = false;
        _errorMessage = null;
      });
      return;
    }

    _loadData();
  }

  void _resetState() {
    _reviews = [];
    _kpis = [];
    _searchTerm = '';
    _statusFilter = 'ALL';
    _activeTab = 'reviews';
  }

  Future<void> _loadData() async {
    final currentReq = ++_requestId;
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final apiClient = ref.read(apiClientProvider);

    try {
      // 1. Fetch Performance Reviews
      final revRes = await apiClient.get(ApiEndpoints.performanceReviews);
      if (!mounted || currentReq != _requestId) return;

      dynamic rawRevs = revRes is Map<String, dynamic> && revRes.containsKey('data') ? revRes['data'] : revRes;
      List<PerformanceReviewModel> revList = [];
      if (rawRevs is List) {
        for (final r in rawRevs) {
          if (r is Map<String, dynamic>) {
            try {
              revList.add(PerformanceReviewModel.fromJson(r));
            } catch (e) {
              debugPrint('[AdminPerformance] Skipped invalid review: $e');
            }
          }
        }
      }

      // 2. Fetch KPIs
      List<KpiTargetModel> kpiList = [];
      try {
        final kpiRes = await apiClient.get(ApiEndpoints.performanceKpis);
        if (!mounted || currentReq != _requestId) return;
        dynamic rawKpis = kpiRes is Map<String, dynamic> && kpiRes.containsKey('data') ? kpiRes['data'] : kpiRes;
        if (rawKpis is List) {
          for (final k in rawKpis) {
            if (k is Map<String, dynamic>) {
              kpiList.add(KpiTargetModel.fromJson(k));
            }
          }
        }
      } catch (e) {
        debugPrint('[AdminPerformance] KPIs fetch warning: $e');
      }

      if (!mounted || currentReq != _requestId) return;
      setState(() {
        _reviews = revList;
        _kpis = kpiList;
        _isLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted || currentReq != _requestId) return;
      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted || currentReq != _requestId) return;
      setState(() {
        _errorMessage = 'Failed to load performance data. Please check network connection.';
        _isLoading = false;
      });
    }
  }

  double get _avgRating {
    if (_reviews.isEmpty) return 0.0;
    final total = _reviews.fold(0.0, (sum, r) => sum + r.rating);
    return total / _reviews.length;
  }

  int get _completedCount => _reviews.where((r) => r.status == 'COMPLETED').length;
  int get _pipCount => _reviews.where((r) => r.status == 'PIP').length;
  int get _activeKpisCount => _kpis.where((k) => k.status == 'ACTIVE').length;

  List<PerformanceReviewModel> get _filteredReviews {
    return _reviews.where((r) {
      final name = r.employeeName.toLowerCase();
      final dept = r.department.toLowerCase();
      final empId = r.employeeId.toLowerCase();

      final matchesSearch = _searchTerm.trim().isEmpty ||
          name.contains(_searchTerm.toLowerCase()) ||
          dept.contains(_searchTerm.toLowerCase()) ||
          empId.contains(_searchTerm.toLowerCase());

      final matchesStatus = _statusFilter == 'ALL' || r.status == _statusFilter;

      return matchesSearch && matchesStatus;
    }).toList();
  }

  List<KpiTargetModel> get _filteredKpis {
    return _kpis.where((k) {
      final title = k.title.toLowerCase();
      final dept = k.department.toLowerCase();
      return _searchTerm.trim().isEmpty ||
          title.contains(_searchTerm.toLowerCase()) ||
          dept.contains(_searchTerm.toLowerCase());
    }).toList();
  }

  void _openReviewCycleModal() {
    final titleController = TextEditingController();
    String period = 'Q1 2025';
    String department = 'Engineering';
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.add_circle_outline, color: Color(0xFF0F6B66)),
              SizedBox(width: 8),
              Text('Launch Review Cycle'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: titleController,
                enabled: !isSaving,
                decoration: const InputDecoration(labelText: 'Cycle Title *', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: period,
                decoration: const InputDecoration(labelText: 'Review Period', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'Q1 2025', child: Text('Q1 2025')),
                  DropdownMenuItem(value: 'Q2 2025', child: Text('Q2 2025')),
                  DropdownMenuItem(value: 'Q3 2025', child: Text('Q3 2025')),
                  DropdownMenuItem(value: 'Q4 2025', child: Text('Q4 2025')),
                  DropdownMenuItem(value: 'Annual 2025', child: Text('Annual 2025')),
                ],
                onChanged: isSaving ? null : (val) => setModalState(() => period = val ?? 'Q1 2025'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: isSaving ? null : () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      if (titleController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Cycle title is required.'), backgroundColor: Colors.red),
                        );
                        return;
                      }

                      setModalState(() => isSaving = true);
                      final currentReq = ++_requestId;
                      final apiClient = ref.read(apiClientProvider);

                      try {
                        await apiClient.post(ApiEndpoints.performanceReviews, body: {
                          'period': period,
                          'comments': titleController.text.trim(),
                          'status': 'PENDING',
                        });

                        if (!mounted || currentReq != _requestId) return;

                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Review cycle launched successfully!')),
                        );
                        _loadData();
                      } catch (e) {
                        if (!mounted || currentReq != _requestId) return;
                        setModalState(() => isSaving = false);
                        final msg = e is ApiException ? e.message : 'Failed to launch review cycle.';
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(msg), backgroundColor: Colors.red),
                        );
                      }
                    },
              child: isSaving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Launch Cycle'),
            ),
          ],
        ),
      ),
    );
  }

  void _openKpiModal() {
    final titleController = TextEditingController();
    String department = 'Engineering';
    final targetController = TextEditingController(text: '100%');
    final weightController = TextEditingController(text: '20');
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.track_changes, color: Color(0xFF0F6B66)),
              SizedBox(width: 8),
              Text('Add KPI Target'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: titleController,
                enabled: !isSaving,
                decoration: const InputDecoration(labelText: 'KPI Title *', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: targetController,
                enabled: !isSaving,
                decoration: const InputDecoration(labelText: 'Target Value', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: weightController,
                enabled: !isSaving,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Weight (%)', border: OutlineInputBorder()),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: isSaving ? null : () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      if (titleController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('KPI title is required.'), backgroundColor: Colors.red),
                        );
                        return;
                      }

                      setModalState(() => isSaving = true);
                      final currentReq = ++_requestId;
                      final apiClient = ref.read(apiClientProvider);

                      try {
                        await apiClient.post(ApiEndpoints.performanceKpis, body: {
                          'title': titleController.text.trim(),
                          'targetValue': 100,
                          'currentValue': 0,
                          'unit': '%',
                          'weight': int.tryParse(weightController.text.trim()) ?? 20,
                          'status': 'ACTIVE',
                        });

                        if (!mounted || currentReq != _requestId) return;

                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('KPI target created successfully!')),
                        );
                        _loadData();
                      } catch (e) {
                        if (!mounted || currentReq != _requestId) return;
                        setModalState(() => isSaving = false);
                        final msg = e is ApiException ? e.message : 'Failed to create KPI target.';
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(msg), backgroundColor: Colors.red),
                        );
                      }
                    },
              child: isSaving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Save KPI'),
            ),
          ],
        ),
      ),
    );
  }

  void _showViewReviewDialog(PerformanceReviewModel review) {
    final glass = context.glass;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.star_outline_rounded, color: Color(0xFF0F6B66)),
            const SizedBox(width: 8),
            Text('Review: ${review.employeeName}'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${review.employeeId} • ${review.department}', style: TextStyle(fontSize: 12, color: glass.textSecondary)),
              Text('Period: ${review.reviewPeriod} • Reviewer: ${review.reviewer}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: glass.textPrimary)),
              const Divider(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Overall Rating:', style: TextStyle(fontSize: 13, color: glass.textSecondary)),
                  Text('${review.rating.toStringAsFixed(1)} / 5.0', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Goals Met:', style: TextStyle(fontSize: 13, color: glass.textSecondary)),
                  Text('${review.goalsMetPct.toInt()}%', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                ],
              ),
              const Divider(height: 16),
              Text('Evaluation Comments:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: glass.textPrimary)),
              const SizedBox(height: 6),
              Text(
                review.comments ?? 'No evaluation comments available.',
                style: TextStyle(fontSize: 12, color: glass.textSecondary),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  void _showEditReviewDialog(PerformanceReviewModel review) {
    final ratingController = TextEditingController(text: review.rating.toString());
    final reviewerController = TextEditingController(text: review.reviewer);
    String status = review.status;
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.edit_note_rounded, color: Color(0xFF0F6B66)),
              const SizedBox(width: 8),
              Text('Edit Review: ${review.employeeName}'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: ratingController,
                enabled: !isSaving,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Overall Rating (1.0 to 5.0)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: status,
                decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'COMPLETED', child: Text('COMPLETED')),
                  DropdownMenuItem(value: 'IN_PROGRESS', child: Text('IN_PROGRESS')),
                  DropdownMenuItem(value: 'PENDING', child: Text('PENDING')),
                  DropdownMenuItem(value: 'PIP', child: Text('PIP')),
                ],
                onChanged: isSaving ? null : (val) => setModalState(() => status = val ?? 'COMPLETED'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: reviewerController,
                enabled: !isSaving,
                decoration: const InputDecoration(labelText: 'Reviewer Name', border: OutlineInputBorder()),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: isSaving ? null : () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      final newRating = double.tryParse(ratingController.text.trim()) ?? review.rating;
                      if (newRating < 1.0 || newRating > 5.0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Rating must be between 1.0 and 5.0.'), backgroundColor: Colors.red),
                        );
                        return;
                      }

                      setModalState(() => isSaving = true);
                      final currentReq = ++_requestId;
                      final apiClient = ref.read(apiClientProvider);

                      try {
                        await apiClient.put(ApiEndpoints.performanceReviewDetail(review.id), body: {
                          'overallRating': newRating,
                          'status': status,
                          'reviewerName': reviewerController.text.trim(),
                        });

                        if (!mounted || currentReq != _requestId) return;

                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Performance review updated successfully!')),
                        );
                        _loadData();
                      } catch (e) {
                        if (!mounted || currentReq != _requestId) return;
                        setModalState(() => isSaving = false);
                        final msg = e is ApiException ? e.message : 'Failed to update review.';
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(msg), backgroundColor: Colors.red),
                        );
                      }
                    },
              child: isSaving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBgColor = isDark ? const Color(0xFF141D2E) : Colors.white;

    // Account switching listener
    ref.listen<AuthState>(authServiceProvider, (previous, next) {
      if (next.user?.id != _currentUserId) {
        _checkUserAndLoad();
      }
    });

    final authState = ref.watch(authServiceProvider);
    final userRole = authState.user?.role;
    final bool isAuthorized = userRole == UserRole.ADMIN || userRole == UserRole.HR;

    return GlassScaffold(
      appBar: GlassHeader(
        title: 'Performance & Goals',
        actions: [
          if (isAuthorized) ...[
            IconButton(
              icon: const Icon(Icons.track_changes),
              tooltip: 'Add KPI Target',
              onPressed: _openKpiModal,
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline_rounded),
              tooltip: 'New Review Cycle',
              onPressed: _openReviewCycleModal,
            ),
          ],
        ],
      ),
      body: !isAuthorized
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: AppCard(
                  backgroundColor: cardBgColor,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.lock_outline, size: 48, color: Color(0xFFEF4444)),
                      const SizedBox(height: 16),
                      Text('Access Restricted', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: glass.textPrimary)),
                      const SizedBox(height: 8),
                      Text('You do not have administrative permissions to view performance metrics.', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: glass.textSecondary)),
                    ],
                  ),
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadData,
              child: _buildMainContent(glass, cardBgColor),
            ),
    );
  }

  Widget _buildMainContent(GlassTheme glass, Color cardBgColor) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Container(
          constraints: BoxConstraints(minHeight: MediaQuery.of(context).size.height * 0.7),
          padding: const EdgeInsets.all(24),
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, size: 54, color: Color(0xFFEF4444)),
              const SizedBox(height: 16),
              Text('Unable to Load Performance Data', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: glass.textPrimary)),
              const SizedBox(height: 8),
              Text(_errorMessage!, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: glass.textSecondary)),
              const SizedBox(height: 24),
              AppButton(label: 'Retry', icon: Icons.refresh_rounded, width: 140, onPressed: _loadData),
            ],
          ),
        ),
      );
    }

    final filteredRevs = _filteredReviews;
    final filteredKpisList = _filteredKpis;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // KPI Metric Summary Cards Row (4 Cards)
          Row(
            children: [
              Expanded(child: _buildStatTile(glass, cardBgColor, label: 'Avg Rating', value: '${_avgRating.toStringAsFixed(1)} / 5', icon: Icons.star_outline_rounded, iconColor: const Color(0xFF2563EB))),
              const SizedBox(width: 8),
              Expanded(child: _buildStatTile(glass, cardBgColor, label: 'Completed', value: '$_completedCount', icon: Icons.check_circle_outline_rounded, iconColor: const Color(0xFF10B981))),
              const SizedBox(width: 8),
              Expanded(child: _buildStatTile(glass, cardBgColor, label: 'Active KPIs', value: '$_activeKpisCount', icon: Icons.track_changes, iconColor: const Color(0xFF8B5CF6))),
              const SizedBox(width: 8),
              Expanded(child: _buildStatTile(glass, cardBgColor, label: 'Active PIP', value: '$_pipCount', icon: Icons.warning_amber_rounded, iconColor: const Color(0xFFEF4444))),
            ],
          ),
          const SizedBox(height: 16),

          // Tabs Row
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: _activeTab == 'reviews' ? const Color(0xFF0F6B66) : Colors.transparent,
                    foregroundColor: _activeTab == 'reviews' ? Colors.white : glass.textPrimary,
                    side: BorderSide(color: _activeTab == 'reviews' ? const Color(0xFF0F6B66) : glass.cardBorder),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => setState(() => _activeTab = 'reviews'),
                  child: Text('Reviews (${_reviews.length})', style: const TextStyle(fontSize: 12)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: _activeTab == 'kpi' ? const Color(0xFF0F6B66) : Colors.transparent,
                    foregroundColor: _activeTab == 'kpi' ? Colors.white : glass.textPrimary,
                    side: BorderSide(color: _activeTab == 'kpi' ? const Color(0xFF0F6B66) : glass.cardBorder),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => setState(() => _activeTab = 'kpi'),
                  child: Text('KPI Targets (${_kpis.length})', style: const TextStyle(fontSize: 12)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Search and Filters Bar
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: _activeTab == 'reviews' ? 'Search reviews by name, dept...' : 'Search KPIs by title, dept...',
                    hintStyle: TextStyle(color: glass.textSecondary, fontSize: 13),
                    prefixIcon: Icon(Icons.search_rounded, color: glass.textSecondary),
                    filled: true,
                    fillColor: cardBgColor,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: glass.cardBorder)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: glass.cardBorder)),
                  ),
                  style: TextStyle(color: glass.textPrimary),
                  onChanged: (val) => setState(() => _searchTerm = val),
                ),
              ),
              if (_activeTab == 'reviews') ...[
                const SizedBox(width: 10),
                DropdownButton<String>(
                  value: _statusFilter,
                  underline: const SizedBox.shrink(),
                  items: const [
                    DropdownMenuItem(value: 'ALL', child: Text('All Status', style: TextStyle(fontSize: 12))),
                    DropdownMenuItem(value: 'COMPLETED', child: Text('Completed', style: TextStyle(fontSize: 12))),
                    DropdownMenuItem(value: 'IN_PROGRESS', child: Text('In Progress', style: TextStyle(fontSize: 12))),
                    DropdownMenuItem(value: 'PENDING', child: Text('Pending', style: TextStyle(fontSize: 12))),
                    DropdownMenuItem(value: 'PIP', child: Text('PIP', style: TextStyle(fontSize: 12))),
                  ],
                  onChanged: (val) => setState(() => _statusFilter = val ?? 'ALL'),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),

          // Content View List
          if (_activeTab == 'reviews') ...[
            if (filteredRevs.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 48),
                alignment: Alignment.center,
                child: Text('No performance reviews found.', style: TextStyle(color: glass.textSecondary)),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredRevs.length,
                itemBuilder: (context, index) {
                  final r = filteredRevs[index];
                  return AppCard(
                    backgroundColor: cardBgColor,
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: const Color(0xFF0F6B66).withAlpha(30),
                          child: Text(r.employeeName.isNotEmpty ? r.employeeName[0].toUpperCase() : 'E', style: const TextStyle(color: Color(0xFF0F6B66), fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(r.employeeName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: glass.textPrimary)),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: r.status == 'COMPLETED' ? const Color(0xFF10B981).withAlpha(30) : (r.status == 'PIP' ? const Color(0xFFEF4444).withAlpha(30) : const Color(0xFFF59E0B).withAlpha(30)),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      r.status,
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: r.status == 'COMPLETED' ? const Color(0xFF10B981) : (r.status == 'PIP' ? const Color(0xFFEF4444) : const Color(0xFFF59E0B))),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text('${r.employeeId} • ${r.department} • Period: ${r.reviewPeriod}', style: TextStyle(fontSize: 12, color: glass.textSecondary)),
                              Text('Rating: ${r.rating.toStringAsFixed(1)} / 5.0 • Goals Met: ${r.goalsMetPct.toInt()}%', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: glass.textPrimary)),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  OutlinedButton.icon(
                                    icon: const Icon(Icons.remove_red_eye_outlined, size: 16),
                                    label: const Text('View', style: TextStyle(fontSize: 12)),
                                    style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                                    onPressed: () => _showViewReviewDialog(r),
                                  ),
                                  const SizedBox(width: 8),
                                  OutlinedButton.icon(
                                    icon: const Icon(Icons.edit_outlined, size: 16),
                                    label: const Text('Edit', style: TextStyle(fontSize: 12)),
                                    style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                                    onPressed: () => _showEditReviewDialog(r),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
          ] else ...[
            if (filteredKpisList.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 48),
                alignment: Alignment.center,
                child: Text('No KPI targets found.', style: TextStyle(color: glass.textSecondary)),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredKpisList.length,
                itemBuilder: (context, index) {
                  final k = filteredKpisList[index];
                  return AppCard(
                    backgroundColor: cardBgColor,
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(k.title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: glass.textPrimary)),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: const Color(0xFF8B5CF6).withAlpha(30), borderRadius: BorderRadius.circular(8)),
                              child: Text('Weight ${k.weight}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF8B5CF6))),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text('Department: ${k.department} • Target: ${k.target} • Progress: ${k.currentAchievement}', style: TextStyle(fontSize: 12, color: glass.textSecondary)),
                      ],
                    ),
                  );
                },
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatTile(
    GlassTheme glass,
    Color cardBgColor, {
    required String label,
    required String value,
    required IconData icon,
    required Color iconColor,
  }) {
    return AppCard(
      backgroundColor: cardBgColor,
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 4),
              Expanded(child: Text(label, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10, color: glass.textSecondary, fontWeight: FontWeight.w600))),
            ],
          ),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: glass.textPrimary)),
        ],
      ),
    );
  }
}
