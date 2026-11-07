import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/auth_service.dart';
import '../../core/widgets/glass_header.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/glass_search_bar.dart';
import '../../shared/widgets/app_card.dart';

class HrPerformanceScreen extends ConsumerStatefulWidget {
  final bool showAppBar;
  const HrPerformanceScreen({super.key, this.showAppBar = true});

  @override
  ConsumerState<HrPerformanceScreen> createState() => _HrPerformanceScreenState();
}

class _HrPerformanceScreenState extends ConsumerState<HrPerformanceScreen> {
  String _activeTab = 'scorecards'; // scorecards, goals, cycles, reviews, feedback

  // Independent loading and error states
  bool _employeesLoading = false;
  String? _employeesError;
  List<dynamic> _employees = [];

  bool _cyclesLoading = false;
  String? _cyclesError;
  List<dynamic> _cycles = [];
  String _selectedCycleId = '';

  bool _scorecardsLoading = false;
  String? _scorecardsError;
  List<dynamic> _scorecards = [];

  bool _goalsLoading = false;
  String? _goalsError;
  List<dynamic> _goals = [];

  bool _reviewsLoading = false;
  String? _reviewsError;
  List<dynamic> _reviews = [];

  bool _feedbackLoading = false;
  String? _feedbackError;
  List<dynamic> _feedback = [];

  String _searchTerm = '';
  String _selectedFeedbackEmployeeId = '';
  String _reviewStatusFilter = 'ALL';

  // HR Review Modal State
  bool _showHrReviewModal = false;
  Map<String, dynamic>? _reviewingScorecard;
  final TextEditingController _hrCommentsController = TextEditingController();
  final TextEditingController _hrRatingController = TextEditingController(text: '5');
  double _hrRating = 5.0;
  bool _isSubmittingReview = false;

  // New KPI Config Modal State
  bool _showKpiModal = false;
  final TextEditingController _kpiTitleController = TextEditingController();
  final TextEditingController _kpiDeptController = TextEditingController();
  final TextEditingController _kpiTargetController = TextEditingController();
  final TextEditingController _kpiUnitController = TextEditingController();
  final TextEditingController _kpiWeightController = TextEditingController();
  bool _isSavingKpi = false;

  // New Cycle Modal State
  bool _showCycleModal = false;
  final TextEditingController _cycleNameController = TextEditingController();
  final TextEditingController _cycleStartController = TextEditingController();
  final TextEditingController _cycleEndController = TextEditingController();
  final TextEditingController _cycleDescController = TextEditingController();
  String _cycleType = 'QUARTERLY';
  bool _isSavingCycle = false;

  // Launch Review Modal State
  bool _showReviewModal = false;
  final TextEditingController _reviewPeriodController = TextEditingController();
  final TextEditingController _reviewDeptController = TextEditingController();
  final TextEditingController _reviewCommentsController = TextEditingController();
  String _reviewStatus = 'IN_PROGRESS';
  bool _isLaunchingReview = false;

  // Action tracking sets
  final Set<String> _deletingFeedbackIds = {};
  final Set<String> _processingCycleIds = {};

  int _requestId = 0;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _checkUserAndLoad();
    });
  }

  @override
  void dispose() {
    _hrCommentsController.dispose();
    _hrRatingController.dispose();
    _kpiTitleController.dispose();
    _kpiDeptController.dispose();
    _kpiTargetController.dispose();
    _kpiUnitController.dispose();
    _kpiWeightController.dispose();
    _cycleNameController.dispose();
    _cycleStartController.dispose();
    _cycleEndController.dispose();
    _cycleDescController.dispose();
    _reviewPeriodController.dispose();
    _reviewDeptController.dispose();
    _reviewCommentsController.dispose();
    super.dispose();
  }

  Future<void> _checkUserAndLoad() async {
    final currentReq = ++_requestId;
    final authState = ref.read(authServiceProvider);
    final user = authState.user;
    if (user == null || !authState.isAuthenticated) {
      if (!mounted) return;
      _resetState();
      setState(() {
        _errorMessage = 'No authenticated user found.';
      });
      return;
    }

    if (_currentUserId != user.id) {
      _currentUserId = user.id;
      _resetState();
    }

    final storageService = ref.read(storageServiceProvider);
    final token = await storageService.getToken();
    if (token != null && token.isNotEmpty) {
      ref.read(apiClientProvider).setAuthToken(token);
    }

    _loadAllResources(currentReq);
  }

  void _resetState() {
    _requestId++;
    _scorecards = [];
    _goals = [];
    _cycles = [];
    _reviews = [];
    _feedback = [];
    _employees = [];
    _searchTerm = '';
    _selectedCycleId = '';
    _selectedFeedbackEmployeeId = '';
    _reviewStatusFilter = 'ALL';
    _showHrReviewModal = false;
    _reviewingScorecard = null;
    _showKpiModal = false;
    _showCycleModal = false;
    _showReviewModal = false;

    _employeesLoading = false;
    _employeesError = null;
    _cyclesLoading = false;
    _cyclesError = null;
    _scorecardsLoading = false;
    _scorecardsError = null;
    _goalsLoading = false;
    _goalsError = null;
    _reviewsLoading = false;
    _reviewsError = null;
    _feedbackLoading = false;
    _feedbackError = null;
  }

  void _loadAllResources(int currentReq) {
    _loadEmployees(currentReq);
    _loadCycles(currentReq);
    _loadReviews(currentReq);
    _loadFeedback(currentReq);
  }

  Future<void> _loadEmployees(int currentReq) async {
    if (!mounted || currentReq != _requestId) return;
    setState(() {
      _employeesLoading = true;
      _employeesError = null;
    });

    final apiClient = ref.read(apiClientProvider);
    try {
      final empRes = await apiClient.get('/management/employees');
      if (!mounted || currentReq != _requestId) return;
      final list = empRes is List ? empRes : (empRes is Map ? (empRes['items'] ?? empRes['data'] ?? []) : []);
      setState(() {
        _employees = list is List ? list : [];
        _employeesLoading = false;
      });
    } catch (e) {
      if (!mounted || currentReq != _requestId) return;
      setState(() {
        _employeesError = e.toString();
        _employeesLoading = false;
      });
    }
  }

  Future<void> _loadCycles(int currentReq) async {
    if (!mounted || currentReq != _requestId) return;
    setState(() {
      _cyclesLoading = true;
      _cyclesError = null;
    });

    final apiClient = ref.read(apiClientProvider);
    try {
      final cycRes = await apiClient.get('/performance/cycles');
      if (!mounted || currentReq != _requestId) return;
      final list = cycRes is List ? cycRes : (cycRes is Map ? (cycRes['items'] ?? cycRes['data'] ?? []) : []);
      final cyclesList = list is List ? list : [];

      if (_selectedCycleId.isEmpty && cyclesList.isNotEmpty) {
        final active = cyclesList.firstWhere(
          (c) => (c['status'] ?? '').toString().toUpperCase() == 'ACTIVE',
          orElse: () => null,
        );
        if (active != null) {
          _selectedCycleId = active['id']?.toString() ?? active['_id']?.toString() ?? '';
        } else {
          _selectedCycleId = '';
        }
      }

      setState(() {
        _cycles = cyclesList;
        _cyclesLoading = false;
      });

      if (_selectedCycleId.isNotEmpty) {
        _loadScorecardsAndGoals(currentReq);
      } else {
        setState(() {
          _scorecards = [];
          _goals = [];
          _scorecardsLoading = false;
          _goalsLoading = false;
        });
      }
    } catch (e) {
      if (!mounted || currentReq != _requestId) return;
      setState(() {
        _cyclesError = e.toString();
        _cyclesLoading = false;
      });
    }
  }

  Future<void> _loadScorecardsAndGoals(int currentReq) async {
    if (_selectedCycleId.isEmpty) return;
    final apiClient = ref.read(apiClientProvider);

    // Scorecards
    if (mounted && currentReq == _requestId) {
      setState(() {
        _scorecardsLoading = true;
        _scorecardsError = null;
      });
    }
    try {
      final scRes = await apiClient.get('/performance/scorecards/$_selectedCycleId');
      if (!mounted || currentReq != _requestId) return;
      final scList = scRes is List ? scRes : (scRes is Map ? (scRes['items'] ?? scRes['data'] ?? []) : []);
      setState(() {
        _scorecards = scList is List ? scList : [];
        _scorecardsLoading = false;
      });
    } catch (e) {
      if (!mounted || currentReq != _requestId) return;
      setState(() {
        _scorecardsError = e.toString();
        _scorecardsLoading = false;
      });
    }

    // Goals scoped by cycle
    if (mounted && currentReq == _requestId) {
      setState(() {
        _goalsLoading = true;
        _goalsError = null;
      });
    }
    try {
      final goalRes = await apiClient.get('/performance/goals/cycle/$_selectedCycleId');
      if (!mounted || currentReq != _requestId) return;
      final goalList = goalRes is List ? goalRes : (goalRes is Map ? (goalRes['items'] ?? goalRes['data'] ?? []) : []);
      setState(() {
        _goals = goalList is List ? goalList : [];
        _goalsLoading = false;
      });
    } catch (e) {
      if (!mounted || currentReq != _requestId) return;
      setState(() {
        _goalsError = e.toString();
        _goalsLoading = false;
      });
    }
  }

  Future<void> _loadReviews(int currentReq) async {
    if (!mounted || currentReq != _requestId) return;
    setState(() {
      _reviewsLoading = true;
      _reviewsError = null;
    });

    final apiClient = ref.read(apiClientProvider);
    try {
      final revRes = await apiClient.get('/performance/reviews');
      if (!mounted || currentReq != _requestId) return;
      final list = revRes is List ? revRes : (revRes is Map ? (revRes['items'] ?? revRes['data'] ?? []) : []);
      setState(() {
        _reviews = list is List ? list : [];
        _reviewsLoading = false;
      });
    } catch (e) {
      if (!mounted || currentReq != _requestId) return;
      setState(() {
        _reviewsError = e.toString();
        _reviewsLoading = false;
      });
    }
  }

  Future<void> _loadFeedback(int currentReq) async {
    if (!mounted || currentReq != _requestId) return;
    setState(() {
      _feedbackLoading = true;
      _feedbackError = null;
    });

    final apiClient = ref.read(apiClientProvider);
    try {
      final fbUrl = _selectedFeedbackEmployeeId.isNotEmpty 
          ? '/performance/feedback?employeeId=$_selectedFeedbackEmployeeId' 
          : '/performance/feedback';
      final fbRes = await apiClient.get(fbUrl);
      if (!mounted || currentReq != _requestId) return;
      final list = fbRes is List ? fbRes : (fbRes is Map ? (fbRes['items'] ?? fbRes['data'] ?? []) : []);
      setState(() {
        _feedback = list is List ? list : [];
        _feedbackLoading = false;
      });
    } catch (e) {
      if (!mounted || currentReq != _requestId) return;
      setState(() {
        _feedbackError = e.toString();
        _feedbackLoading = false;
      });
    }
  }

  String _formatDate(dynamic dateVal) {
    if (dateVal == null) return '—';
    final str = dateVal.toString().trim();
    if (str.isEmpty) return '—';
    if (str.length >= 10) {
      return str.substring(0, 10);
    }
    return str;
  }

  Future<void> _autoCalculateAll() async {
    if (_selectedCycleId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select an active performance cycle first.'), backgroundColor: Colors.orange));
      return;
    }

    final activeCycle = _cycles.cast<Map<String, dynamic>>().firstWhere(
      (c) => (c['id']?.toString() ?? c['_id']?.toString()) == _selectedCycleId,
      orElse: () => {},
    );
    final status = (activeCycle['status'] ?? '').toString().toUpperCase();
    if (status != 'ACTIVE') {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Cannot auto-calculate for non-active cycle (Status: ${status.isNotEmpty ? status : 'None'}). Select an ACTIVE cycle.'), backgroundColor: Colors.red));
      return;
    }

    setState(() => _scorecardsLoading = true);
    final apiClient = ref.read(apiClientProvider);

    try {
      await apiClient.post('/performance/calculate-all/$_selectedCycleId', body: {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Auto-calculated all scorecards successfully')));
        _loadScorecardsAndGoals(_requestId);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _scorecardsLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to auto-calculate scorecards: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _submitHrReview() async {
    if (_reviewingScorecard == null) return;
    final scId = _reviewingScorecard!['id']?.toString() ?? _reviewingScorecard!['_id']?.toString() ?? '';
    if (scId.isEmpty) return;

    final rating = double.tryParse(_hrRatingController.text.trim()) ?? 5.0;
    if (rating < 1 || rating > 5) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('HR rating must be between 1 and 5.'), backgroundColor: Colors.red));
      return;
    }

    setState(() => _isSubmittingReview = true);
    final apiClient = ref.read(apiClientProvider);

    try {
      await apiClient.put('/performance/scorecard/$scId/hr-review', body: {
        'comments': _hrCommentsController.text.trim(),
        'rating': rating,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('HR review submitted successfully')));
        setState(() {
          _showHrReviewModal = false;
          _reviewingScorecard = null;
          _isSubmittingReview = false;
          _hrCommentsController.clear();
        });
        _loadScorecardsAndGoals(_requestId);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmittingReview = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to submit HR review: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _createKpi() async {
    final title = _kpiTitleController.text.trim();
    final targetStr = _kpiTargetController.text.trim();
    final weightStr = _kpiWeightController.text.trim();
    final dept = _kpiDeptController.text.trim();
    final unit = _kpiUnitController.text.trim();

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('KPI title is required.'), backgroundColor: Colors.red));
      return;
    }
    final targetVal = double.tryParse(targetStr);
    if (targetVal == null || targetVal <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a valid target value greater than 0.'), backgroundColor: Colors.red));
      return;
    }
    final weightVal = int.tryParse(weightStr);
    if (weightVal == null || weightVal < 0 || weightVal > 100) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a valid weightage between 0 and 100.'), backgroundColor: Colors.red));
      return;
    }

    setState(() => _isSavingKpi = true);
    final apiClient = ref.read(apiClientProvider);

    try {
      await apiClient.post('/performance/kpi-configs', body: {
        'title': title,
        if (dept.isNotEmpty) 'department': dept,
        'targetValue': targetVal,
        if (unit.isNotEmpty) 'unit': unit,
        'weight': weightVal,
        'status': 'ACTIVE',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Department KPI config created successfully')));
        setState(() {
          _showKpiModal = false;
          _isSavingKpi = false;
          _kpiTitleController.clear();
          _kpiTargetController.clear();
          _kpiWeightController.clear();
          _kpiUnitController.clear();
        });
        if (_selectedCycleId.isNotEmpty) {
          _loadScorecardsAndGoals(_requestId);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSavingKpi = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to create KPI config: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _createCycle() async {
    final name = _cycleNameController.text.trim();
    final start = _cycleStartController.text.trim();
    final end = _cycleEndController.text.trim();
    final desc = _cycleDescController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cycle name is required.'), backgroundColor: Colors.red));
      return;
    }
    if (start.isEmpty || end.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Both start and end dates are required.'), backgroundColor: Colors.red));
      return;
    }

    try {
      final dtStart = DateTime.parse(start);
      final dtEnd = DateTime.parse(end);
      if (dtEnd.isBefore(dtStart)) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('End date must not precede start date.'), backgroundColor: Colors.red));
        return;
      }
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid date format. Use YYYY-MM-DD.'), backgroundColor: Colors.red));
      return;
    }

    setState(() => _isSavingCycle = true);
    final apiClient = ref.read(apiClientProvider);

    try {
      await apiClient.post('/performance/cycles', body: {
        'name': name,
        'cycleType': _cycleType,
        'startDate': start,
        'endDate': end,
        if (desc.isNotEmpty) 'description': desc,
        'status': 'DRAFT',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Performance cycle created successfully')));
        setState(() {
          _showCycleModal = false;
          _isSavingCycle = false;
          _cycleNameController.clear();
          _cycleStartController.clear();
          _cycleEndController.clear();
          _cycleDescController.clear();
        });
        _loadCycles(_requestId);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSavingCycle = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to create cycle: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _activateCycle(String id, String currentStatus) async {
    if (currentStatus.toUpperCase() != 'DRAFT') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Only DRAFT cycles can be activated.'), backgroundColor: Colors.orange));
      return;
    }
    if (_processingCycleIds.contains(id)) return;

    setState(() => _processingCycleIds.add(id));
    final apiClient = ref.read(apiClientProvider);
    try {
      await apiClient.put('/performance/cycles/$id/activate', body: {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Performance cycle activated')));
        _loadCycles(_requestId);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to activate cycle: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) {
        setState(() => _processingCycleIds.remove(id));
      }
    }
  }

  Future<void> _completeCycle(String id, String currentStatus) async {
    if (currentStatus.toUpperCase() != 'ACTIVE') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Only ACTIVE cycles can be completed.'), backgroundColor: Colors.orange));
      return;
    }
    if (_processingCycleIds.contains(id)) return;

    setState(() => _processingCycleIds.add(id));
    final apiClient = ref.read(apiClientProvider);
    try {
      await apiClient.put('/performance/cycles/$id/complete', body: {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Performance cycle completed')));
        _loadCycles(_requestId);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to complete cycle: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) {
        setState(() => _processingCycleIds.remove(id));
      }
    }
  }

  Future<void> _launchReviewCycle() async {
    final period = _reviewPeriodController.text.trim();
    if (period.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Review period is required.'), backgroundColor: Colors.red));
      return;
    }

    setState(() => _isLaunchingReview = true);
    final apiClient = ref.read(apiClientProvider);

    try {
      await apiClient.post('/performance/reviews', body: {
        'period': period,
        if (_reviewDeptController.text.trim().isNotEmpty) 'department': _reviewDeptController.text.trim(),
        if (_reviewCommentsController.text.trim().isNotEmpty) 'comments': _reviewCommentsController.text.trim(),
        'status': _reviewStatus,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Review cycle launched successfully')));
        setState(() {
          _showReviewModal = false;
          _isLaunchingReview = false;
          _reviewPeriodController.clear();
          _reviewDeptController.clear();
          _reviewCommentsController.clear();
        });
        _loadReviews(_requestId);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLaunchingReview = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to launch review cycle: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _deleteFeedback(String id) async {
    if (_deletingFeedbackIds.contains(id)) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: const Text('Are you sure you want to delete this 360 feedback record? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _deletingFeedbackIds.add(id));
    final apiClient = ref.read(apiClientProvider);
    try {
      await apiClient.delete('/performance/feedback/$id');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Feedback deleted successfully')));
        _loadFeedback(_requestId);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete feedback: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) {
        setState(() => _deletingFeedbackIds.remove(id));
      }
    }
  }

  Future<void> _pickDate(TextEditingController controller) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      controller.text = picked.toIso8601String().substring(0, 10);
    }
  }

  List<dynamic> get _filteredScorecards {
    if (_searchTerm.trim().isEmpty) return _scorecards;
    return _scorecards.where((s) {
      final name = (s['employeeName'] ?? s['name'] ?? '').toString().toLowerCase();
      final id = (s['employeeId'] ?? s['employeeCode'] ?? '').toString().toLowerCase();
      return name.contains(_searchTerm.toLowerCase()) || id.contains(_searchTerm.toLowerCase());
    }).toList();
  }

  List<dynamic> get _filteredGoals {
    if (_searchTerm.trim().isEmpty) return _goals;
    return _goals.where((g) {
      final title = (g['title'] ?? '').toString().toLowerCase();
      final name = (g['employeeName'] ?? '').toString().toLowerCase();
      final cat = (g['category'] ?? '').toString().toLowerCase();
      return title.contains(_searchTerm.toLowerCase()) || name.contains(_searchTerm.toLowerCase()) || cat.contains(_searchTerm.toLowerCase());
    }).toList();
  }

  List<dynamic> get _filteredCycles {
    if (_searchTerm.trim().isEmpty) return _cycles;
    return _cycles.where((c) {
      final name = (c['name'] ?? '').toString().toLowerCase();
      final type = (c['cycleType'] ?? '').toString().toLowerCase();
      final status = (c['status'] ?? '').toString().toLowerCase();
      return name.contains(_searchTerm.toLowerCase()) || type.contains(_searchTerm.toLowerCase()) || status.contains(_searchTerm.toLowerCase());
    }).toList();
  }

  List<dynamic> get _filteredReviews {
    var list = _reviews;
    if (_reviewStatusFilter != 'ALL') {
      list = list.where((r) => (r['status'] ?? '').toString().toUpperCase() == _reviewStatusFilter).toList();
    }
    if (_searchTerm.trim().isEmpty) return list;
    return list.where((r) {
      final name = (r['employeeName'] ?? r['name'] ?? '').toString().toLowerCase();
      final id = (r['employeeId'] ?? r['employeeCode'] ?? '').toString().toLowerCase();
      final dept = (r['department'] ?? '').toString().toLowerCase();
      return name.contains(_searchTerm.toLowerCase()) || id.contains(_searchTerm.toLowerCase()) || dept.contains(_searchTerm.toLowerCase());
    }).toList();
  }

  List<dynamic> get _filteredFeedback {
    if (_searchTerm.trim().isEmpty) return _feedback;
    return _feedback.where((f) {
      final target = (f['targetEmployeeName'] ?? f['employeeName'] ?? '').toString().toLowerCase();
      final reviewer = (f['reviewerName'] ?? '').toString().toLowerCase();
      final comments = (f['comments'] ?? '').toString().toLowerCase();
      final cat = (f['category'] ?? '').toString().toLowerCase();
      return target.contains(_searchTerm.toLowerCase()) || reviewer.contains(_searchTerm.toLowerCase()) || comments.contains(_searchTerm.toLowerCase()) || cat.contains(_searchTerm.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authServiceProvider, (previous, next) {
      if (next.user?.id != _currentUserId) {
        _checkUserAndLoad();
      }
    });

    final cardBg = Theme.of(context).cardColor;
    final primaryColor = Theme.of(context).primaryColor;

    final totalScorecards = _scorecards.length;
    final totalGoals = _goals.length;
    final totalCycles = _cycles.length;
    final needsImprovementCount = _scorecards.where((s) => (s['overallRating'] ?? '').toString().toUpperCase() == 'NEEDS_IMPROVEMENT').length;

    final activeCycle = _cycles.isNotEmpty ? _cycles.cast<Map<String, dynamic>>().firstWhere((c) => (c['status'] ?? '').toString().toUpperCase() == 'ACTIVE', orElse: () => {}) : {};
    final activeCycleId = activeCycle['id']?.toString() ?? activeCycle['_id']?.toString() ?? '';
    final isActiveCycleSelected = activeCycleId.isNotEmpty && activeCycleId == _selectedCycleId;

    final bodyContent = Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 4 Metric Cards
              Row(
                children: [
                  Expanded(child: _buildMetricCard('Scorecards', '$totalScorecards', 'Auto-calculated', Colors.blue, Icons.assessment, cardBg)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildMetricCard('Tracked Goals', '$totalGoals', 'KPI metrics', Colors.green, Icons.track_changes, cardBg)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _buildMetricCard('Cycles', '$totalCycles', 'Active & past', Colors.purple, Icons.loop, cardBg)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildMetricCard('Needs Improvement', '$needsImprovementCount', 'Action required', Colors.red, Icons.warning_amber, cardBg)),
                ],
              ),
              const SizedBox(height: 16),

              // Action Toolbar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_activeTab == 'scorecards')
                    ElevatedButton.icon(
                      icon: const Icon(Icons.calculate, size: 16),
                      label: const Text('Auto-Calculate All', style: TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(backgroundColor: isActiveCycleSelected ? primaryColor : Colors.grey, foregroundColor: Colors.white, visualDensity: VisualDensity.compact),
                      onPressed: isActiveCycleSelected ? _autoCalculateAll : null,
                    )
                  else if (_activeTab == 'goals')
                    ElevatedButton.icon(
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('New KPI Config', style: TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white, visualDensity: VisualDensity.compact),
                      onPressed: () => setState(() => _showKpiModal = true),
                    )
                  else if (_activeTab == 'cycles')
                    ElevatedButton.icon(
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('New Cycle', style: TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white, visualDensity: VisualDensity.compact),
                      onPressed: () => setState(() => _showCycleModal = true),
                    )
                  else if (_activeTab == 'reviews')
                    ElevatedButton.icon(
                      icon: const Icon(Icons.play_circle_fill, size: 16),
                      label: const Text('Launch Review Cycle', style: TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white, visualDensity: VisualDensity.compact),
                      onPressed: () => setState(() => _showReviewModal = true),
                    )
                  else
                    const SizedBox.shrink(),

                  // Cycle Selector Dropdown
                  if (_cyclesError != null)
                    Text('Cycles error', style: TextStyle(fontSize: 11, color: Colors.red))
                  else if (_cyclesLoading)
                    const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  else if (_cycles.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(10)),
                      child: DropdownButton<String>(
                        value: _selectedCycleId.isEmpty ? null : _selectedCycleId,
                        hint: const Text('Select Cycle', style: TextStyle(fontSize: 12)),
                        underline: const SizedBox.shrink(),
                        items: _cycles.map((c) {
                          final cid = c['id']?.toString() ?? c['_id']?.toString() ?? '';
                          final cname = c['name']?.toString() ?? 'Cycle';
                          final cstatus = c['status']?.toString() ?? 'DRAFT';
                          return DropdownMenuItem<String>(
                            value: cid,
                            child: Text('$cname ($cstatus)', style: const TextStyle(fontSize: 12)),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() => _selectedCycleId = val ?? '');
                          if (_selectedCycleId.isNotEmpty) {
                            _loadScorecardsAndGoals(_requestId);
                          }
                        },
                      ),
                    ),
                ],
              ),
              if (_cycles.isEmpty && !_cyclesLoading)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('No active performance cycle found. Please create and activate a cycle.', style: TextStyle(fontSize: 11, color: Colors.orange[800], fontStyle: FontStyle.italic)),
                )
              else if (!isActiveCycleSelected && _activeTab == 'scorecards')
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('Note: Auto-Calculate requires selecting an ACTIVE cycle.', style: TextStyle(fontSize: 11, color: Colors.orange[800], fontStyle: FontStyle.italic)),
                ),
              const SizedBox(height: 16),

              // 5 Performance Tabs
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildTabButton('scorecards', 'Auto Scorecards', Icons.assessment),
                    const SizedBox(width: 8),
                    _buildTabButton('goals', 'Goals & KPIs', Icons.track_changes),
                    const SizedBox(width: 8),
                    _buildTabButton('cycles', 'Cycles', Icons.loop),
                    const SizedBox(width: 8),
                    _buildTabButton('reviews', 'Reviews', Icons.rate_review),
                    const SizedBox(width: 8),
                    _buildTabButton('feedback', '360 Feedback', Icons.feedback),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Search & Filter Bar
              Row(
                children: [
                  Expanded(
                    child: GlassSearchBar(
                      placeholder: 'Search performance records...',
                      onChanged: (val) => setState(() => _searchTerm = val),
                    ),
                  ),
                  if (_activeTab == 'reviews') ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(10)),
                      child: DropdownButton<String>(
                        value: _reviewStatusFilter,
                        underline: const SizedBox.shrink(),
                        items: const [
                          DropdownMenuItem(value: 'ALL', child: Text('All Status', style: TextStyle(fontSize: 11))),
                          DropdownMenuItem(value: 'COMPLETED', child: Text('Completed', style: TextStyle(fontSize: 11))),
                          DropdownMenuItem(value: 'IN_PROGRESS', child: Text('In Progress', style: TextStyle(fontSize: 11))),
                          DropdownMenuItem(value: 'PENDING', child: Text('Pending', style: TextStyle(fontSize: 11))),
                        ],
                        onChanged: (val) => setState(() => _reviewStatusFilter = val ?? 'ALL'),
                      ),
                    ),
                  ],
                  if (_activeTab == 'feedback') ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(10)),
                      child: DropdownButton<String>(
                        value: _selectedFeedbackEmployeeId.isEmpty ? null : _selectedFeedbackEmployeeId,
                        hint: const Text('All Employees', style: TextStyle(fontSize: 11)),
                        underline: const SizedBox.shrink(),
                        items: [
                          const DropdownMenuItem(value: '', child: Text('All Employees', style: TextStyle(fontSize: 11))),
                          ..._employees.map((e) {
                            final empId = e['employeeId']?.toString() ?? e['id']?.toString() ?? e['_id']?.toString() ?? '';
                            final name = '${e['firstName'] ?? ''} ${e['lastName'] ?? ''}'.trim();
                            return DropdownMenuItem<String>(
                              value: empId,
                              child: Text(name.isNotEmpty ? name : empId, style: const TextStyle(fontSize: 11)),
                            );
                          }),
                        ],
                        onChanged: (val) {
                          setState(() => _selectedFeedbackEmployeeId = val ?? '');
                          _loadFeedback(_requestId);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.refresh, size: 20),
                      tooltip: 'Refresh Feedback',
                      onPressed: () => _loadFeedback(_requestId),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),

              // Tab 1: Auto Scorecards
              if (_activeTab == 'scorecards') ...[
                if (_scorecardsLoading)
                  const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))
                else if (_scorecardsError != null)
                  _buildErrorState(_scorecardsError!, () => _loadScorecardsAndGoals(_requestId))
                else if (_filteredScorecards.isEmpty)
                  const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('No scorecards found for this cycle.')))
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _filteredScorecards.length,
                    itemBuilder: (context, index) {
                      final sc = _filteredScorecards[index] as Map<String, dynamic>;
                      final name = sc['employeeName'] ?? sc['name'] ?? '—';
                      final code = sc['employeeId'] ?? sc['employeeCode'] ?? '—';
                      final score = sc['overallWeightedScore'] ?? sc['score'] ?? '—';
                      final rating = sc['overallRating'] ?? '—';
                      final isHrReviewed = sc['isReviewedByHr'] == true || (sc['hrRating'] != null);
                      final isTlReviewed = sc['isReviewedByTl'] == true || (sc['tlRating'] != null);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 1,
                        color: cardBg,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('$name ($code)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  Chip(
                                    label: Text(isHrReviewed ? 'HR Reviewed' : 'Pending HR', style: const TextStyle(fontSize: 10, color: Colors.white)),
                                    backgroundColor: isHrReviewed ? Colors.green : Colors.orange,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text('Overall Score: $score • Rating: $rating', style: TextStyle(fontSize: 12, color: Colors.grey[700], fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              Text('Attendance: ${sc['totalAttendancePercentage'] ?? '—'}% • Check-in: ${sc['onTimeCheckInPercentage'] ?? '—'}%', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                              Text('Tasks: ${sc['tasksCompleted'] ?? '—'}/${sc['totalTasksAssigned'] ?? '—'} (${sc['taskCompletionPercentage'] ?? '—'}%)', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                              Text('EOD: ${sc['eodSubmissionPercentage'] ?? '—'}% • Project Progress: ${sc['projectProgressScore'] ?? '—'}', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                              const SizedBox(height: 4),
                              Text('TL Status: ${isTlReviewed ? 'Reviewed' : 'Pending'} (Rating: ${sc['tlRating'] ?? '—'}) ${sc['tlComments'] != null ? '• "${sc['tlComments']}"' : ''}', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                              Text('HR Status: ${isHrReviewed ? 'Reviewed' : 'Pending'} (Rating: ${sc['hrRating'] ?? '—'}) ${sc['hrComments'] != null ? '• "${sc['hrComments']}"' : ''}', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                              const Divider(height: 16),
                              Align(
                                alignment: Alignment.centerRight,
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.rate_review, size: 14),
                                  label: Text(isHrReviewed ? 'Edit HR Review' : 'HR Review', style: const TextStyle(fontSize: 12)),
                                  style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white, visualDensity: VisualDensity.compact),
                                  onPressed: () => setState(() {
                                    _reviewingScorecard = sc;
                                    _hrCommentsController.text = sc['hrComments']?.toString() ?? '';
                                    _hrRatingController.text = (sc['hrRating'] ?? 5.0).toString();
                                    _hrRating = double.tryParse(_hrRatingController.text) ?? 5.0;
                                    _showHrReviewModal = true;
                                  }),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
              ]

              // Tab 2: Goals & KPIs
              else if (_activeTab == 'goals') ...[
                if (_goalsLoading)
                  const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))
                else if (_goalsError != null)
                  _buildErrorState(_goalsError!, () => _loadScorecardsAndGoals(_requestId))
                else if (_filteredGoals.isEmpty)
                  const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('No goals or KPIs found for this cycle.')))
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _filteredGoals.length,
                    itemBuilder: (context, index) {
                      final g = _filteredGoals[index] as Map<String, dynamic>;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 1,
                        color: cardBg,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(child: Text(g['title'] ?? '—', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                                  Chip(label: Text(g['status'] ?? '—'), visualDensity: VisualDensity.compact),
                                ],
                              ),
                              Text('Employee: ${g['employeeName'] ?? '—'} • Category: ${g['category'] ?? '—'}', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                              if (g['description'] != null) Text('${g['description']}', style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                              const SizedBox(height: 4),
                              Text('Target: ${g['targetValue'] ?? '—'} ${g['unit'] ?? ''} • Achieved: ${g['achievedValue'] ?? '—'} (${g['achievementPercentage'] ?? '—'}%)', style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                              Text('Weightage: ${g['weightage'] ?? '—'}% • Manager Rating: ${g['managerRating'] ?? '—'}', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
              ]

              // Tab 3: Cycles
              else if (_activeTab == 'cycles') ...[
                if (_cyclesLoading)
                  const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))
                else if (_cyclesError != null)
                  _buildErrorState(_cyclesError!, () => _loadCycles(_requestId))
                else if (_filteredCycles.isEmpty)
                  const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('No performance cycles found.')))
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _filteredCycles.length,
                    itemBuilder: (context, index) {
                      final c = _filteredCycles[index] as Map<String, dynamic>;
                      final id = c['id']?.toString() ?? c['_id']?.toString() ?? '';
                      final status = (c['status'] ?? 'DRAFT').toString().toUpperCase();
                      final isProcessing = _processingCycleIds.contains(id);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 1,
                        color: cardBg,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(c['name'] ?? '—', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  Chip(label: Text(status), visualDensity: VisualDensity.compact),
                                ],
                              ),
                              Text('Type: ${c['cycleType'] ?? '—'} • ${_formatDate(c['startDate'])} to ${_formatDate(c['endDate'])}', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                              if (c['description'] != null) Text('${c['description']}', style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                              const Divider(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  if (isProcessing)
                                    const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                  else ...[
                                    if (status == 'DRAFT')
                                      OutlinedButton.icon(
                                        icon: const Icon(Icons.play_arrow, size: 14, color: Colors.green),
                                        label: const Text('Activate', style: TextStyle(fontSize: 12, color: Colors.green)),
                                        style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                                        onPressed: () => _activateCycle(id, status),
                                      ),
                                    if (status == 'ACTIVE')
                                      OutlinedButton.icon(
                                        icon: const Icon(Icons.check_circle, size: 14, color: Colors.blue),
                                        label: const Text('Complete', style: TextStyle(fontSize: 12, color: Colors.blue)),
                                        style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                                        onPressed: () => _completeCycle(id, status),
                                      ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
              ]

              // Tab 4: Reviews
              else if (_activeTab == 'reviews') ...[
                if (_reviewsLoading)
                  const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))
                else if (_reviewsError != null)
                  _buildErrorState(_reviewsError!, () => _loadReviews(_requestId))
                else if (_filteredReviews.isEmpty)
                  const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('No performance reviews found.')))
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _filteredReviews.length,
                    itemBuilder: (context, index) {
                      final rev = _filteredReviews[index] as Map<String, dynamic>;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 1,
                        color: cardBg,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(rev['employeeName'] ?? rev['name'] ?? '—', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  Chip(label: Text(rev['status'] ?? '—'), visualDensity: VisualDensity.compact),
                                ],
                              ),
                              Text('${rev['employeeId'] ?? rev['employeeCode'] ?? '—'} • Department: ${rev['department'] ?? '—'}', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                              const SizedBox(height: 4),
                              Text('Period: ${rev['reviewPeriod'] ?? rev['period'] ?? '—'} • Rating: ${rev['overallRating'] ?? rev['rating'] ?? '—'}', style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                              Text('Reviewer: ${rev['reviewerName'] ?? rev['reviewer'] ?? '—'}', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
              ]

              // Tab 5: 360 Feedback
              else if (_activeTab == 'feedback') ...[
                if (_feedbackLoading)
                  const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))
                else if (_feedbackError != null)
                  _buildErrorState(_feedbackError!, () => _loadFeedback(_requestId))
                else if (_filteredFeedback.isEmpty)
                  const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('No 360 feedback records found.')))
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _filteredFeedback.length,
                    itemBuilder: (context, index) {
                      final fb = _filteredFeedback[index] as Map<String, dynamic>;
                      final id = fb['id']?.toString() ?? fb['_id']?.toString() ?? '';
                      final isDeleting = _deletingFeedbackIds.contains(id);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 1,
                        color: cardBg,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Target: ${fb['targetEmployeeName'] ?? fb['employeeName'] ?? '—'}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  if (isDeleting)
                                    const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                  else
                                    IconButton(
                                      icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                                      onPressed: () => _deleteFeedback(id),
                                    ),
                                ],
                              ),
                              Text('Reviewer: ${fb['reviewerName'] ?? '—'} • Category: ${fb['category'] ?? '—'} • Period: ${fb['reviewPeriod'] ?? '—'}', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                              const SizedBox(height: 4),
                              Text('Rating: ${fb['rating'] ?? '—'}/5', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              Text('Comments: "${fb['comments'] ?? ''}"', style: TextStyle(fontSize: 12, color: Colors.grey[700], fontStyle: FontStyle.italic)),
                              Text('Created: ${_formatDate(fb['createdAt'])}', style: TextStyle(fontSize: 10, color: Colors.grey[500])),
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

        // HR Review Modal
        if (_showHrReviewModal)
          Container(
            color: Colors.black54,
            alignment: Alignment.center,
            padding: const EdgeInsets.all(20),
            child: Material(
              borderRadius: BorderRadius.circular(16),
              color: cardBg,
              child: SizedBox(
                width: double.infinity,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  constraints: const BoxConstraints(maxWidth: 450),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('HR Final Review', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _showHrReviewModal = false)),
                        ],
                      ),
                      const Divider(),
                      Text('Employee: ${_reviewingScorecard?['employeeName'] ?? _reviewingScorecard?['name'] ?? '—'}'),
                      Text('Overall Score: ${_reviewingScorecard?['overallWeightedScore'] ?? _reviewingScorecard?['score'] ?? '—'}'),
                      const SizedBox(height: 12),
                      TextField(
                        decoration: const InputDecoration(labelText: 'HR Rating (1 - 5) *', border: OutlineInputBorder()),
                        keyboardType: TextInputType.number,
                        controller: _hrRatingController,
                        onChanged: (val) => _hrRating = double.tryParse(val) ?? 5.0,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _hrCommentsController,
                        decoration: const InputDecoration(labelText: 'HR Comments & Remarks', border: OutlineInputBorder()),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(onPressed: () => setState(() => _showHrReviewModal = false), child: const Text('Cancel')),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white),
                            onPressed: _isSubmittingReview ? null : _submitHrReview,
                            child: Text(_isSubmittingReview ? 'Submitting...' : 'Submit HR Review'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

        // New KPI Config Modal
        if (_showKpiModal)
          Container(
            color: Colors.black54,
            alignment: Alignment.center,
            padding: const EdgeInsets.all(20),
            child: Material(
              borderRadius: BorderRadius.circular(16),
              color: cardBg,
              child: SizedBox(
                width: double.infinity,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  constraints: const BoxConstraints(maxWidth: 450),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Create Department KPI Config', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _showKpiModal = false)),
                        ],
                      ),
                      const Divider(),
                      TextField(
                        controller: _kpiTitleController,
                        decoration: const InputDecoration(labelText: 'KPI Title *', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _kpiDeptController,
                        decoration: const InputDecoration(labelText: 'Department (e.g. Engineering)', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _kpiTargetController,
                        decoration: const InputDecoration(labelText: 'Target Value * (e.g. 100)', border: OutlineInputBorder()),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _kpiUnitController,
                        decoration: const InputDecoration(labelText: 'Unit (e.g. %, count)', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _kpiWeightController,
                        decoration: const InputDecoration(labelText: 'Weightage (e.g. 20)', border: OutlineInputBorder()),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(onPressed: () => setState(() => _showKpiModal = false), child: const Text('Cancel')),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white),
                            onPressed: _isSavingKpi ? null : _createKpi,
                            child: Text(_isSavingKpi ? 'Saving...' : 'Save KPI Config'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

        // New Cycle Modal
        if (_showCycleModal)
          Container(
            color: Colors.black54,
            alignment: Alignment.center,
            padding: const EdgeInsets.all(20),
            child: Material(
              borderRadius: BorderRadius.circular(16),
              color: cardBg,
              child: SizedBox(
                width: double.infinity,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  constraints: const BoxConstraints(maxWidth: 450),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Create Performance Cycle', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _showCycleModal = false)),
                        ],
                      ),
                      const Divider(),
                      TextField(
                        controller: _cycleNameController,
                        decoration: const InputDecoration(labelText: 'Cycle Name *', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _cycleType,
                        decoration: const InputDecoration(labelText: 'Cycle Type', border: OutlineInputBorder()),
                        items: ['MONTHLY', 'QUARTERLY', 'HALF_YEARLY', 'ANNUAL']
                            .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                            .toList(),
                        onChanged: (val) => setState(() => _cycleType = val ?? 'QUARTERLY'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _cycleStartController,
                        decoration: InputDecoration(
                          labelText: 'Start Date (YYYY-MM-DD) *',
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(icon: const Icon(Icons.calendar_today), onPressed: () => _pickDate(_cycleStartController)),
                        ),
                        readOnly: true,
                        onTap: () => _pickDate(_cycleStartController),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _cycleEndController,
                        decoration: InputDecoration(
                          labelText: 'End Date (YYYY-MM-DD) *',
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(icon: const Icon(Icons.calendar_today), onPressed: () => _pickDate(_cycleEndController)),
                        ),
                        readOnly: true,
                        onTap: () => _pickDate(_cycleEndController),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _cycleDescController,
                        decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(onPressed: () => setState(() => _showCycleModal = false), child: const Text('Cancel')),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white),
                            onPressed: _isSavingCycle ? null : _createCycle,
                            child: Text(_isSavingCycle ? 'Creating...' : 'Create Cycle'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

        // Launch Review Modal
        if (_showReviewModal)
          Container(
            color: Colors.black54,
            alignment: Alignment.center,
            padding: const EdgeInsets.all(20),
            child: Material(
              borderRadius: BorderRadius.circular(16),
              color: cardBg,
              child: SizedBox(
                width: double.infinity,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  constraints: const BoxConstraints(maxWidth: 450),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Launch Review Cycle', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _showReviewModal = false)),
                        ],
                      ),
                      const Divider(),
                      TextField(
                        controller: _reviewPeriodController,
                        decoration: const InputDecoration(labelText: 'Review Period Title * (e.g. Q1 2026)', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _reviewDeptController,
                        decoration: const InputDecoration(labelText: 'Department (Optional)', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _reviewCommentsController,
                        decoration: const InputDecoration(labelText: 'Comments / Objectives', border: OutlineInputBorder()),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(onPressed: () => setState(() => _showReviewModal = false), child: const Text('Cancel')),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white),
                            onPressed: _isLaunchingReview ? null : _launchReviewCycle,
                            child: Text(_isLaunchingReview ? 'Launching...' : 'Launch Review'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );

    if (!widget.showAppBar) return Material(color: Colors.transparent, child: bodyContent);

    return GlassScaffold(
      appBar: GlassHeader(title: 'Performance & KPI Tracking'),
      body: bodyContent,
    );
  }

  Widget _buildErrorState(String errorMsg, VoidCallback onRetry) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, size: 42, color: Colors.red),
            const SizedBox(height: 12),
            const Text('Failed to load resource', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(errorMsg, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
            const SizedBox(height: 16),
            ElevatedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh, size: 16), label: const Text('Retry')),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(String label, String value, String subtext, Color color, IconData icon, Color cardBg) {
    return AppCard(
      backgroundColor: cardBg,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(color: color.withAlpha(30), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600], fontWeight: FontWeight.bold)),
                  Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
                  Text(subtext, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(String tabKey, String label, IconData icon) {
    final isActive = _activeTab == tabKey;
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: isActive ? Theme.of(context).primaryColor : Colors.grey[100],
        foregroundColor: isActive ? Colors.white : Colors.grey[800],
        elevation: 0,
        visualDensity: VisualDensity.compact,
      ),
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      onPressed: () => setState(() => _activeTab = tabKey),
    );
  }
}

extension on _HrPerformanceScreenState {
  set _errorMessage(String value) {}
}

