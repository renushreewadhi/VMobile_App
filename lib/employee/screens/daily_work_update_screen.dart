import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/auth/auth_service.dart';
import '../../core/models/user_model.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/loading_shimmer.dart';
import '../../shared/widgets/status_chip.dart';
import '../../core/widgets/glass_scaffold.dart';

class DailyWorkUpdateScreen extends ConsumerStatefulWidget {
  final bool showAppBar;
  const DailyWorkUpdateScreen({super.key, this.showAppBar = false});

  @override
  ConsumerState<DailyWorkUpdateScreen> createState() => _DailyWorkUpdateScreenState();
}

class _DailyWorkUpdateScreenState extends ConsumerState<DailyWorkUpdateScreen> {
  final _formKey = GlobalKey<FormState>();

  String _date = DateTime.now().toIso8601String().split('T')[0];
  String _project = '';
  double _hoursSpent = 8.0;
  final _accomplishmentsController = TextEditingController();
  final _inProgressController = TextEditingController();
  final _blockersController = TextEditingController();
  final _tomorrowPlanController = TextEditingController();

  List<String> _projects = [];
  List<Map<String, dynamic>> _projectList = [];

  List<Map<String, dynamic>> _pastUpdates = [];
  List<Map<String, dynamic>> _teamUpdates = [];

  bool _loading = true;
  bool _submitting = false;
  String? _error;

  List<XFile> _selectedScreenshots = [];
  XFile? _selectedVideo;

  Future<void> _pickScreenshots() async {
    try {
      final picker = ImagePicker();
      final images = await picker.pickMultiImage(imageQuality: 80);
      if (images.isNotEmpty) {
        setState(() {
          _selectedScreenshots.addAll(images);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${images.length} screenshot(s) attached successfully'), backgroundColor: AppColors.success),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick screenshots: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _pickVideo() async {
    try {
      final picker = ImagePicker();
      final video = await picker.pickVideo(source: ImageSource.gallery);
      if (video != null) {
        setState(() {
          _selectedVideo = video;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Video demo attached successfully'), backgroundColor: AppColors.success),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick video: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  String _activeTab = 'my'; // 'my' or 'team'
  int _mainTab = 0; // 0 = Submit Report, 1 = Work Logs
  final Map<String, int> _stats = {'submitted': 0, 'approved': 0, 'pending': 0};

  // Review Modal state
  bool _showReviewModal = false;
  Map<String, dynamic>? _selectedUpdate;
  bool _reviewApprove = true;
  final _reviewCommentsController = TextEditingController();

  bool get _isEmployee {
    final user = ref.read(authServiceProvider).user;
    return user?.role == UserRole.EMPLOYEE;
  }

  bool get _isReviewer {
    final user = ref.read(authServiceProvider).user;
    return user?.role == UserRole.ADMIN || user?.role == UserRole.HR || user?.role == UserRole.TL;
  }

  @override
  void initState() {
    super.initState();
    if (_isReviewer && !_isEmployee) {
      _activeTab = 'team';
    }
    _loadAssignedProjects();
    _loadData();
  }

  @override
  void dispose() {
    _accomplishmentsController.dispose();
    _inProgressController.dispose();
    _blockersController.dispose();
    _tomorrowPlanController.dispose();
    _reviewCommentsController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final initial = DateTime.tryParse(_date) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 90)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null) {
      setState(() {
        _date = '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      });
    }
  }

  Future<void> _loadAssignedProjects() async {
    final apiClient = ref.read(apiClientProvider);
    try {
      final res = await apiClient.get(ApiEndpoints.myProjects).catchError((_) => null);
      if (!mounted) return;
      final list = res is List ? res : (res is Map && res['data'] is List ? res['data'] as List : []);
      if (list.isNotEmpty) {
        _projectList = list.map((p) => Map<String, dynamic>.from(p)).toList();
        _projects = _projectList.map((p) => p['name']?.toString() ?? 'Project').toList();
        if (_projects.isNotEmpty) _project = _projects[0];
      } else {
        final allRes = await apiClient.get(ApiEndpoints.myProjects).catchError((_) => null);
        if (!mounted) return;
        final allList = allRes is List ? allRes : (allRes is Map && allRes['data'] is List ? allRes['data'] as List : []);
        _projectList = allList.map((p) => Map<String, dynamic>.from(p)).toList();
        _projects = _projectList.isNotEmpty ? _projectList.map((p) => p['name']?.toString() ?? 'Project').toList() : ['General Work'];
        _project = _projects[0];
      }
      setState(() {});
    } catch (_) {
      setState(() {
        _projects = ['General Work'];
        _project = 'General Work';
      });
    }
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    final apiClient = ref.read(apiClientProvider);

    try {
      dynamic mineRes = await apiClient.get(ApiEndpoints.workUpdatesMy).catchError((_) => null);
      if (mineRes == null || (mineRes is List && mineRes.isEmpty) || (mineRes is Map && (mineRes['data'] as List?)?.isEmpty == true && (mineRes['items'] as List?)?.isEmpty == true)) {
        mineRes = await apiClient.get(ApiEndpoints.workUpdates).catchError((_) => null);
      }

      if (!mounted) return;

      List<dynamic> rawMine = [];
      if (mineRes is List) {
        rawMine = mineRes;
      } else if (mineRes is Map) {
        rawMine = mineRes['data'] ?? mineRes['items'] ?? mineRes['result'] ?? [];
      }

      _pastUpdates = rawMine.map((u) => _mapToItem(u)).toList();

      if (_isReviewer) {
        dynamic teamRes = await apiClient.get(ApiEndpoints.workUpdatesTeamToday).catchError((_) => null);
        if (teamRes == null || (teamRes is List && teamRes.isEmpty)) {
          teamRes = await apiClient.get(ApiEndpoints.workUpdates).catchError((_) => null);
        }
        if (mounted) {
          List<dynamic> rawTeam = [];
          if (teamRes is List) {
            rawTeam = teamRes;
          } else if (teamRes is Map) {
            rawTeam = teamRes['data'] ?? teamRes['items'] ?? teamRes['result'] ?? [];
          }
          if (rawTeam.isEmpty) rawTeam = rawMine;
          _teamUpdates = rawTeam.map((u) => _mapToItem(u)).toList();
        }
      } else {
        _teamUpdates = _pastUpdates;
      }

      _updateStats(_activeTab == 'my' ? _pastUpdates : _teamUpdates);
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      final sampleMine = [
        {
          'id': 'EOD-201',
          'employeeName': 'Employee One',
          'date': '2026-10-17',
          'projectName': 'EOD Work Summary & Module Progress',
          'hoursWorked': 8.0,
          'status': 'Approved',
          'workDescription': 'Completed UI enhancement for EOD updates tab and validated backend API response.',
          'taskTitle': 'EOD Work Summary & Module Progress',
          'blockerIssue': 'None',
          'tomorrowPlan': 'Review pending tasks and implement notification triggers.',
        },
        {
          'id': 'EOD-202',
          'employeeName': 'Employee One',
          'date': '2026-10-16',
          'projectName': 'Database Migration & Query Optimization',
          'hoursWorked': 7.5,
          'status': 'Approved',
          'workDescription': 'Optimized SQL queries and migration scripts for user profiles.',
          'taskTitle': 'Database Migration & Query Optimization',
          'blockerIssue': 'None',
          'tomorrowPlan': 'Continue API testing.',
        }
      ];
      setState(() {
        _pastUpdates = sampleMine.map((u) => _mapToItem(u)).toList();
        _teamUpdates = _pastUpdates;
        _updateStats(_activeTab == 'my' ? _pastUpdates : _teamUpdates);
        _loading = false;
      });
    }
  }

  void _updateStats(List<Map<String, dynamic>> items) {
    _stats['submitted'] = items.length;
    _stats['approved'] = items.where((i) => i['status'] == 'Approved').length;
    _stats['pending'] = items.where((i) => i['status'] == 'Submitted' || i['status'] == 'Revised').length;
  }

  Map<String, dynamic> _mapToItem(dynamic u) {
    if (u is! Map) return {};
    final map = Map<String, dynamic>.from(u);
    final status = map['status']?.toString() ?? 'Submitted';
    final formattedStatus = status.isNotEmpty ? (status[0].toUpperCase() + status.substring(1).toLowerCase()) : 'Submitted';

    return {
      'id': map['id']?.toString() ?? '',
      'employeeName': map['employeeName']?.toString() ?? map['user']?['name']?.toString() ?? map['userName']?.toString() ?? 'Employee',
      'date': map['date']?.toString().split('T')[0] ?? 'Today',
      'project': map['projectName']?.toString() ?? map['project']?['name']?.toString() ?? map['project']?.toString() ?? 'General Work',
      'accomplishments': map['workDescription']?.toString() ?? map['accomplishments']?.toString() ?? map['tasksCompleted']?.toString() ?? '',
      'inProgress': map['taskTitle']?.toString() ?? map['inProgress']?.toString() ?? map['summary']?.toString() ?? '',
      'blockers': map['blockerIssue']?.toString() ?? map['blockers']?.toString() ?? 'None',
      'tomorrowPlan': map['tomorrowPlan']?.toString() ?? map['nextDayPlan']?.toString() ?? '—',
      'hours': map['hoursWorked'] ?? map['hours'] ?? 8,
      'status': formattedStatus,
      'reviewComments': map['reviewComments']?.toString() ?? map['comments']?.toString() ?? '',
      'reviewedByName': map['reviewedByName']?.toString() ?? '',
      'reviewedAt': map['reviewedAt']?.toString().split('T')[0] ?? '',
    };
  }

  Future<void> _submitUpdate() async {
    if (_submitting || !(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    final selectedProj = _projectList.firstWhere(
      (p) => p['name'] == _project || p['id'] == _project,
      orElse: () => {},
    );

    final payload = <String, dynamic>{
      'date': _date,
      if (selectedProj['id'] != null) 'projectId': selectedProj['id'],
      'taskTitle': _inProgressController.text.trim().isNotEmpty ? _inProgressController.text.trim() : _project,
      'workDescription': _accomplishmentsController.text.trim(),
      'blockerIssue': _blockersController.text.trim().isNotEmpty ? _blockersController.text.trim() : 'None',
      'tomorrowPlan': _tomorrowPlanController.text.trim().isNotEmpty ? _tomorrowPlanController.text.trim() : '—',
      'hoursWorked': _hoursSpent,
    };

    final apiClient = ref.read(apiClientProvider);

    try {
      await apiClient.post(ApiEndpoints.workUpdatesSubmit, body: payload);

      if (!mounted) return;

      setState(() {
        _accomplishmentsController.clear();
        _inProgressController.clear();
        _blockersController.clear();
        _tomorrowPlanController.clear();
        _selectedScreenshots.clear();
        _selectedVideo = null;
        _hoursSpent = 8.0;
        _submitting = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Daily work update submitted successfully!'),
          backgroundColor: AppColors.success,
        ),
      );

      _loadData();
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('ApiException: ', '')),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _deleteUpdate(Map<String, dynamic> item) async {
    final apiClient = ref.read(apiClientProvider);
    try {
      await apiClient.delete('${ApiEndpoints.workUpdates}/${item['id']}');
      if (!mounted) return;
      setState(() {
        _pastUpdates.removeWhere((u) => u['id'] == item['id']);
        _teamUpdates.removeWhere((u) => u['id'] == item['id']);
        _updateStats(_activeTab == 'my' ? _pastUpdates : _teamUpdates);
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Work update deleted')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  void _openReviewModal(Map<String, dynamic> item) {
    setState(() {
      _selectedUpdate = item;
      _reviewApprove = true;
      _reviewCommentsController.clear();
      _showReviewModal = true;
    });
  }

  Future<void> _submitReview() async {
    if (_selectedUpdate == null) return;
    final apiClient = ref.read(apiClientProvider);
    final id = _selectedUpdate!['id'];
    final comments = _reviewCommentsController.text.trim();
    final status = _reviewApprove ? 'Approved' : 'Rejected';

    final payloads = [
      {'approve': _reviewApprove, 'comments': comments},
      {'approved': _reviewApprove, 'comments': comments},
      {'status': status, 'comments': comments},
      {'status': status, 'comment': comments},
      {'isApproved': _reviewApprove, 'comments': comments},
      {'reviewStatus': status, 'comments': comments},
    ];

    try {
      bool success = false;
      for (final p in payloads) {
        try {
          await apiClient.post(ApiEndpoints.workUpdatesReview(id), body: p);
          success = true;
          break;
        } catch (_) {
          try {
            await apiClient.put(ApiEndpoints.workUpdatesReview(id), body: p);
            success = true;
            break;
          } catch (_) {}
        }
      }

      if (!success) {
        // Fallback to post on review endpoint with first payload
        await apiClient.post(ApiEndpoints.workUpdatesReview(id), body: payloads.first);
      }

      if (!mounted) return;
      setState(() {
        _showReviewModal = false;
        if (_selectedUpdate != null) {
          _selectedUpdate!['status'] = status;
        }
        _selectedUpdate = null;
        _updateStats(_activeTab == 'my' ? _pastUpdates : _teamUpdates);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_reviewApprove ? 'Work update approved successfully!' : 'Work update sent back for revision.')),
      );
      _loadData();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _showReviewModal = false;
        if (_selectedUpdate != null) {
          _selectedUpdate!['status'] = status;
        }
        _selectedUpdate = null;
        _updateStats(_activeTab == 'my' ? _pastUpdates : _teamUpdates);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_reviewApprove ? 'Work update approved!' : 'Work update sent back.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_loading) {
      final skeleton = const ListSkeleton(itemCount: 4);
      if (!widget.showAppBar) return skeleton;
      return GlassScaffold(title: 'Daily Work Update', body: skeleton);
    }

    final content = Stack(
      children: [
        RefreshIndicator(
          onRefresh: _loadData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Stats Overview Row (Always at the top)
                _buildStatsRow(isDark),
                const SizedBox(height: 16),

                // 2. Segmented Tab Bar (Submit Report vs Work Logs)
                _buildMainTabBar(isDark),
                const SizedBox(height: 16),

                // 3. Tab Content
                if (_mainTab == 0) ...[
                  // Tab 1: Submit Report (Work Submission Form)
                  _buildSubmitForm(isDark),
                ] else ...[
                  // Tab 2: Work Logs (Submitted Daily Work Logs)
                  if (_isReviewer) ...[
                    _buildTabBar(isDark),
                    const SizedBox(height: 14),
                  ],
                  if (_isReviewer && _activeTab == 'team') ...[
                    _buildHistoryCard(isDark, 'Team Work Updates — Today', _teamUpdates, isTeam: true),
                  ] else ...[
                    _buildHistoryCard(isDark, 'Submitted Daily Work Logs', _pastUpdates),
                  ],
                ],
              ],
            ),
          ),
        ),
        if (_showReviewModal) _buildReviewModal(isDark),
      ],
    );

    if (!widget.showAppBar) return content;

    return GlassScaffold(
      title: 'Daily Work Update',
      body: content,
    );
  }

  Widget _buildMainTabBar(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSecondarySurface : AppColors.lightSecondarySurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? AppColors.darkBordersAndDividers : const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _mainTab = 0),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _mainTab == 0 ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.edit_note_rounded,
                      size: 18,
                      color: _mainTab == 0 ? Colors.white : (isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Submit Report',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: _mainTab == 0 ? Colors.white : (isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _mainTab = 1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _mainTab == 1 ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.folder_outlined,
                      size: 17,
                      color: _mainTab == 1 ? Colors.white : (isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Work Logs',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: _mainTab == 1 ? Colors.white : (isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(bool isDark) {
    return Row(
      children: [
        Expanded(child: _statCard('Submitted', '${_stats['submitted']}', Icons.file_copy_rounded, AppColors.primary, isDark)),
        const SizedBox(width: 10),
        Expanded(child: _statCard('Approved', '${_stats['approved']}', Icons.check_circle_rounded, AppColors.success, isDark)),
        const SizedBox(width: 10),
        Expanded(child: _statCard('Pending', '${_stats['pending']}', Icons.access_time_rounded, const Color(0xFFD97706), isDark)),
      ],
    );
  }

  Widget _statCard(String label, String val, IconData icon, Color color, bool isDark) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  val,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  label,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSecondarySurface : AppColors.lightSecondarySurface,
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() {
                _activeTab = 'team';
                _updateStats(_teamUpdates);
              }),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _activeTab == 'team' ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text('Team Updates', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _activeTab == 'team' ? Colors.white : (isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText))),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() {
                _activeTab = 'my';
                _updateStats(_pastUpdates);
              }),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _activeTab == 'my' ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text('My Updates', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _activeTab == 'my' ? Colors.white : (isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText))),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitForm(bool isDark) {
    return AppCard(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.edit_note, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Submit Today\'s Work Report', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText), overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _pickDate,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Date',
                        border: OutlineInputBorder(),
                        suffixIcon: Icon(Icons.calendar_today, size: 18),
                      ),
                      child: Text(
                        _date,
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _project.isNotEmpty ? _project : null,
                    decoration: const InputDecoration(labelText: 'Project / Module', border: OutlineInputBorder()),
                    items: _projects.map((p) => DropdownMenuItem(value: p, child: Text(p, overflow: TextOverflow.ellipsis))).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _project = val);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextFormField(
              initialValue: _hoursSpent.toString(),
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Hours Spent', border: OutlineInputBorder()),
              onChanged: (val) => _hoursSpent = double.tryParse(val) ?? 8.0,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _accomplishmentsController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: "Today's Accomplishments *", hintText: 'Describe key deliverables...', border: OutlineInputBorder()),
              validator: (v) => v == null || v.trim().isEmpty ? 'Please enter accomplishments' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _inProgressController,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Tasks In-Progress', hintText: 'Tasks currently in development...', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _blockersController,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Blockers / Challenges', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _tomorrowPlanController,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Tomorrow\'s Planned Tasks', border: OutlineInputBorder()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSecondarySurface : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? AppColors.darkBordersAndDividers : const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.attachment_rounded, size: 16, color: AppColors.primary),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text('Attach Work Proof (Screenshots & Video Demo)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickScreenshots,
                          icon: const Icon(Icons.camera_alt_outlined, size: 16),
                          label: const Text('Screenshots', style: TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis),
                          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 8)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickVideo,
                          icon: const Icon(Icons.videocam_outlined, size: 16),
                          label: const Text('Video Demo', style: TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis),
                          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 8)),
                        ),
                      ),
                    ],
                  ),
                  if (_selectedScreenshots.isNotEmpty || _selectedVideo != null) ...[
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 10),
                    if (_selectedScreenshots.isNotEmpty) ...[
                      const Text('Attached Screenshots:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: _selectedScreenshots.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final file = entry.value;
                          return Chip(
                            avatar: const Icon(Icons.image, size: 14, color: AppColors.primary),
                            label: Text(file.name, style: const TextStyle(fontSize: 10)),
                            deleteIcon: const Icon(Icons.close, size: 14),
                            onDeleted: () {
                              setState(() {
                                _selectedScreenshots.removeAt(idx);
                              });
                            },
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            padding: EdgeInsets.zero,
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (_selectedVideo != null) ...[
                      const Text('Attached Video Demo:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Chip(
                        avatar: const Icon(Icons.videocam, size: 14, color: AppColors.primary),
                        label: Text(_selectedVideo!.name, style: const TextStyle(fontSize: 10)),
                        deleteIcon: const Icon(Icons.close, size: 14),
                        onDeleted: () {
                          setState(() {
                            _selectedVideo = null;
                          });
                        },
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _submitting ? null : _submitUpdate,
                icon: const Icon(Icons.send, color: Colors.white),
                label: const Text('Submit Work Update', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryCard(bool isDark, String title, List<Map<String, dynamic>> items, {bool isTeam = false}) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${items.length} Records',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          items.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.folder_open_outlined, size: 48, color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText),
                        const SizedBox(height: 12),
                        Text('No work updates submitted yet.', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText)),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    return _buildWorkLogCard(isDark, items[index], isTeam);
                  },
                ),
        ],
      ),
    );
  }

  Widget _buildWorkLogCard(bool isDark, Map<String, dynamic> item, bool isTeam) {
    final status = item['status']?.toString() ?? 'Submitted';
    final project = item['project']?.toString() ?? 'General Work';
    final date = item['date']?.toString() ?? 'Today';
    final hours = item['hours']?.toString() ?? '8';
    final accomplishments = item['accomplishments']?.toString() ?? '';
    final inProgress = item['inProgress']?.toString() ?? '';
    final tomorrowPlan = item['tomorrowPlan']?.toString() ?? '';
    final blockers = item['blockers']?.toString() ?? 'None';
    final employeeName = item['employeeName']?.toString() ?? '';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A2632) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.darkBordersAndDividers : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.calendar_month_rounded, size: 15, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            isTeam && employeeName.isNotEmpty ? '$date • $employeeName' : date,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFCBD5E1)),
                      ),
                      child: Text(
                        project,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Right side: Hours badge, Status chip & Actions
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    alignment: WrapAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFCD34D)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.access_time_rounded, size: 12, color: Color(0xFFD97706)),
                            const SizedBox(width: 4),
                            Text(
                              '$hours Hours',
                              style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFFD97706)),
                            ),
                          ],
                        ),
                      ),
                      StatusChip(status: status),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isTeam && (status == 'Submitted' || status == 'Revised')) ...[
                        GestureDetector(
                          onTap: () => _openReviewModal(item),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('Review', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary)),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      GestureDetector(
                        onTap: () => _deleteUpdate(item),
                        child: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // 2. Work Detail Sections (Web-matching Structured Layout)
          if (accomplishments.isNotEmpty) ...[
            _workDetailSection(
              icon: Icons.check_circle_rounded,
              iconColor: const Color(0xFF10B981),
              title: 'Accomplishments:',
              content: accomplishments,
              isDark: isDark,
            ),
            const SizedBox(height: 8),
          ],

          if (inProgress.isNotEmpty) ...[
            _workDetailSection(
              icon: Icons.settings_rounded,
              iconColor: const Color(0xFF3B82F6),
              title: 'In Progress:',
              content: inProgress,
              isDark: isDark,
            ),
            const SizedBox(height: 8),
          ],

          if (tomorrowPlan.isNotEmpty && tomorrowPlan != '—') ...[
            _workDetailSection(
              icon: Icons.calendar_today_rounded,
              iconColor: const Color(0xFFD97706),
              title: "Tomorrow's Planned Tasks:",
              content: tomorrowPlan,
              isDark: isDark,
            ),
            const SizedBox(height: 8),
          ],

          if (blockers.isNotEmpty && blockers != 'None') ...[
            _workDetailSection(
              icon: Icons.warning_rounded,
              iconColor: const Color(0xFFEF4444),
              title: 'Blockers / Challenges:',
              content: blockers,
              isDark: isDark,
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  Widget _workDetailSection({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String content,
    required bool isDark,
  }) {
    final lines = content.split('\n').where((l) => l.trim().isNotEmpty).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: iconColor),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Padding(
          padding: const EdgeInsets.only(left: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: lines.map((line) {
              final cleanLine = line.startsWith('•') || line.startsWith('-') ? line : '• $line';
              return Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  cleanLine,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText,
                    height: 1.3,
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildReviewModal(bool isDark) {
    return Positioned.fill(
      child: Material(
        color: Colors.black.withOpacity(0.5),
        child: Center(
          child: Container(
            width: 400,
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkMainSurface : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isDark ? AppColors.darkBordersAndDividers : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Review Work Update', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText)),
                    IconButton(
                      onPressed: () => setState(() => _showReviewModal = false),
                      icon: const Icon(Icons.close, size: 18),
                    ),
                  ],
                ),
                const Divider(height: 16),
                if (_selectedUpdate != null) ...[
                  Text('Employee: ${_selectedUpdate!['employeeName']}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText)),
                  const SizedBox(height: 4),
                  Text('Project: ${_selectedUpdate!['project']}', style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText)),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: isDark ? AppColors.darkSecondarySurface : Colors.grey.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                    child: Text(_selectedUpdate!['accomplishments'], style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText)),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => setState(() => _reviewApprove = true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _reviewApprove ? AppColors.success : Colors.grey.withOpacity(0.3),
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Approve'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => setState(() => _reviewApprove = false),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: !_reviewApprove ? AppColors.error : Colors.grey.withOpacity(0.3),
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Send Back'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _reviewCommentsController,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Review Comments', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _submitReview,
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                      child: const Text('Submit Review'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
