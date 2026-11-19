import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/auth/auth_service.dart';
import '../../core/models/user_model.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_header.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../shared/widgets/status_chip.dart';

class WfhApplyScreen extends ConsumerStatefulWidget {
  final bool? isAdminView;
  const WfhApplyScreen({super.key, this.isAdminView});

  @override
  ConsumerState<WfhApplyScreen> createState() => _WfhApplyScreenState();
}

class _WfhApplyScreenState extends ConsumerState<WfhApplyScreen> {
  late String _activeTab; // 'approvals', 'apply', 'my-requests', 'team-logs'
  bool _isLoading = false;
  bool _isSubmitting = false;
  bool _submitted = false;
  String? _updatingId;
  String? _cancellingId;

  List<dynamic> _allRequests = [];
  String _searchTerm = '';
  String _statusFilter = 'ALL';

  // WFH Application Form State
  String _dateMode = 'single'; // 'single' or 'range'
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  String _reasonCategory = 'Personal / Family';
  final _reasonDetailsController = TextEditingController();
  final _workDeliverablesController = TextEditingController();
  final _contactNotesController = TextEditingController();
  final _companyEmailController = TextEditingController();

  final List<String> _reasonCategories = [
    'Personal / Family',
    'Health / Medical Recovery',
    'Commute / Severe Weather',
    'Deep Work / High-Focus Project',
    'Home Repair / Delivery / Relocation',
    'Other',
  ];

  // Approval/Rejection Dialog Controllers
  final _approvalCommentController = TextEditingController();
  final _rejectionCommentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final authState = ref.read(authServiceProvider);
    final user = authState.user;
    final canReview = widget.isAdminView ??
        (user?.role == UserRole.ADMIN || user?.role == UserRole.HR || user?.role == UserRole.TL);
    _activeTab = canReview ? 'approvals' : 'apply';

    if (user != null) {
      _companyEmailController.text = user.email;
      if (user.phone != null && user.phone!.isNotEmpty) {
        _contactNotesController.text = 'Available on Teams / Phone (${user.phone})';
      } else {
        _contactNotesController.text = 'Available on Teams / Phone during office hours';
      }
    }

    _loadData();
  }

  @override
  void dispose() {
    _reasonDetailsController.dispose();
    _workDeliverablesController.dispose();
    _contactNotesController.dispose();
    _companyEmailController.dispose();
    _approvalCommentController.dispose();
    _rejectionCommentController.dispose();
    super.dispose();
  }

  bool get _canReview {
    if (widget.isAdminView != null) return widget.isAdminView!;
    final user = ref.read(authServiceProvider).user;
    return user?.role == UserRole.ADMIN || user?.role == UserRole.HR || user?.role == UserRole.TL;
  }

  bool get _isAdminOrHr {
    final user = ref.read(authServiceProvider).user;
    return user?.role == UserRole.ADMIN || user?.role == UserRole.HR;
  }

  List<dynamic> _extractList(dynamic res) {
    if (res == null) return [];
    if (res is List) return res;
    if (res is Map) {
      if (res['data'] is List) return res['data'] as List;
      if (res['items'] is List) return res['items'] as List;
      if (res['requests'] is List) return res['requests'] as List;
      if (res['result'] is List) return res['result'] as List;
      if (res['data'] is Map && res['data']['items'] is List) {
        return res['data']['items'] as List;
      }
    }
    return [];
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final apiClient = ref.read(apiClientProvider);

    dynamic res;
    final endpoints = [
      ApiEndpoints.wfhRequests,
      '/attendance/wfh-requests',
      '/attendance/wfh',
      ApiEndpoints.attendanceCorrections,
      '/attendance/correction-request',
    ];

    for (final ep in endpoints) {
      try {
        res = await apiClient.get(ep).timeout(const Duration(seconds: 5));
        if (res != null) {
          final list = _extractList(res);
          if (list.isNotEmpty) {
            break;
          }
        }
      } catch (_) {}
    }

    if (!mounted) return;
    final rawList = _extractList(res);
    setState(() {
      _allRequests = rawList;
      _isLoading = false;
    });
  }

  int get _calculatedDays {
    if (_dateMode == 'single') return 1;
    final diff = _endDate.difference(_startDate).inDays;
    return diff < 0 ? 0 : diff + 1;
  }

  Future<void> _selectStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
        if (_dateMode == 'single' || _endDate.isBefore(_startDate)) {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _selectEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate.isBefore(_startDate) ? _startDate : _endDate,
      firstDate: _startDate,
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (picked != null) {
      setState(() {
        _endDate = picked;
      });
    }
  }

  Future<void> _submitApplication() async {
    final reasonDetails = _reasonDetailsController.text.trim();
    if (reasonDetails.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter detailed reason for WFH'), backgroundColor: AppColors.warning),
      );
      return;
    }

    if (_dateMode == 'range' && _endDate.isBefore(_startDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End date cannot be earlier than start date'), backgroundColor: AppColors.warning),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final apiClient = ref.read(apiClientProvider);
    final startDateStr = DateFormat('yyyy-MM-dd').format(_startDate);
    final endDateStr = DateFormat('yyyy-MM-dd').format(_endDate);

    // Build comprehensive reason string containing Category & Deliverables
    final reasonParts = [
      '[WFH] Category: $_reasonCategory',
      'Reason: $reasonDetails',
    ];
    if (_workDeliverablesController.text.trim().isNotEmpty) {
      reasonParts.add('Deliverables: ${_workDeliverablesController.text.trim()}');
    }
    if (_contactNotesController.text.trim().isNotEmpty) {
      reasonParts.add('Contact: ${_contactNotesController.text.trim()}');
    }
    final fullReason = reasonParts.join(' | ');

    try {
      await apiClient.post(ApiEndpoints.wfhApply, body: {
        'type': 'WFH',
        'date': startDateStr,
        'startDate': startDateStr,
        'endDate': endDateStr,
        'totalDays': _calculatedDays,
        'reason': fullReason,
        'contact': _contactNotesController.text.trim(),
        'companyEmail': _companyEmailController.text.trim(),
      }).catchError((_) async {
        return await apiClient.post(ApiEndpoints.attendanceCorrectionRequest, body: {
          'type': 'WFH',
          'date': startDateStr,
          'startDate': startDateStr,
          'endDate': endDateStr,
          'totalDays': _calculatedDays,
          'reason': fullReason,
          'contact': _contactNotesController.text.trim(),
          'companyEmail': _companyEmailController.text.trim(),
        });
      });

      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _submitted = true;
        _activeTab = 'requests'; // Switch to My WFH Requests tab so logs are visible immediately
      });
      await _loadData();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('WFH application submitted successfully!'), backgroundColor: AppColors.success),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      final errorMsg = e.toString().replaceFirst('ApiException: ', '').replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMsg), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _updateWfhStatus(dynamic req, String newStatus, String comment) async {
    final id = req['id']?.toString() ?? req['_id']?.toString() ?? '';
    if (id.isEmpty) return;

    setState(() => _updatingId = id);
    final apiClient = ref.read(apiClientProvider);

    try {
      await apiClient.put(ApiEndpoints.wfhRequestStatus(id), body: {
        'status': newStatus,
        'approverComments': comment,
        'comments': comment,
      }).catchError((_) async {
        return await apiClient.post('/attendance/corrections/$id/status', body: {
          'status': newStatus,
          'comments': comment,
        });
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('WFH request marked as $newStatus'), backgroundColor: AppColors.success),
      );
      _loadData();
    } catch (e) {
      if (!mounted) return;
      final errorMsg = e.toString().replaceFirst('ApiException: ', '').replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMsg), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _updatingId = null);
    }
  }

  Future<void> _cancelRequest(dynamic req) async {
    final id = req['id']?.toString() ?? req['_id']?.toString() ?? '';
    if (id.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Request'),
        content: const Text('Are you sure you want to cancel this WFH request?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes, Cancel', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _cancellingId = id);
    final apiClient = ref.read(apiClientProvider);

    try {
      await apiClient.delete('${ApiEndpoints.wfhRequests}/$id').catchError((_) async {
        return await apiClient.post('${ApiEndpoints.wfhRequests}/$id/cancel', body: {});
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('WFH request cancelled'), backgroundColor: AppColors.success),
      );
      _loadData();
    } catch (e) {
      if (!mounted) return;
      final errorMsg = e.toString().replaceFirst('ApiException: ', '').replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMsg), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _cancellingId = null);
    }
  }

  void _showApproveDialog(dynamic req) {
    _approvalCommentController.text = 'Approved';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(color: Color(0xFFECFDF5), shape: BoxShape.circle),
              child: const Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 22),
            ),
            const SizedBox(width: 10),
            const Text('Approve WFH Request', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Approve remote work for ${req['employeeName'] ?? 'employee'}?',
              style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
            ),
            const SizedBox(height: 12),
            const Text('Approval Note (Optional)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            TextField(
              controller: _approvalCommentController,
              decoration: InputDecoration(
                hintText: 'e.g. Approved. Please ensure attendance check-in.',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.all(10),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669)),
            onPressed: () {
              Navigator.pop(ctx);
              _updateWfhStatus(req, 'Approved', _approvalCommentController.text.trim());
            },
            child: const Text('Confirm Approval', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showRejectDialog(dynamic req) {
    _rejectionCommentController.clear();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(color: Color(0xFFFEF2F2), shape: BoxShape.circle),
              child: const Icon(Icons.cancel_rounded, color: Color(0xFFDC2626), size: 22),
            ),
            const SizedBox(width: 10),
            const Text('Reject WFH Request', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Provide rejection reason for ${req['employeeName'] ?? 'employee'}:',
              style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
            ),
            const SizedBox(height: 12),
            const Text('Rejection Reason *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            TextField(
              controller: _rejectionCommentController,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'e.g. Mandatory in-office workshop on this date...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.all(10),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            onPressed: () {
              final reason = _rejectionCommentController.text.trim();
              if (reason.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter rejection reason'), backgroundColor: AppColors.warning),
                );
                return;
              }
              Navigator.pop(ctx);
              _updateWfhStatus(req, 'Rejected', reason);
            },
            child: const Text('Confirm Rejection', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _resetForm() {
    final user = ref.read(authServiceProvider).user;
    setState(() {
      _dateMode = 'single';
      _startDate = DateTime.now();
      _endDate = DateTime.now();
      _reasonCategory = 'Personal / Family';
      _reasonDetailsController.clear();
      _workDeliverablesController.clear();
      if (user != null && user.phone != null && user.phone!.isNotEmpty) {
        _contactNotesController.text = 'Available on Teams / Phone (${user.phone})';
      } else {
        _contactNotesController.text = 'Available on Teams / Phone during office hours';
      }
      _submitted = false;
    });
  }

  // Helper Stats Calculation
  List<dynamic> get _myRequests {
    final currentUser = ref.read(authServiceProvider).user;
    if (currentUser == null) return _allRequests;
    if (currentUser.role == UserRole.EMPLOYEE) {
      return _allRequests;
    }
    return _allRequests.where((r) {
      final empId = r['employeeId']?.toString() ?? r['userId']?.toString() ?? r['employee']?['id']?.toString() ?? r['user']?['id']?.toString();
      final empMail = r['companyEmail']?.toString() ?? r['email']?.toString() ?? r['employee']?['email']?.toString();
      if (empId == null && empMail == null) return true;
      return (empId != null && empId == currentUser.id) ||
          (empMail != null && empMail.toLowerCase() == currentUser.email.toLowerCase());
    }).toList();
  }

  List<dynamic> get _pendingApprovals {
    return _allRequests.where((r) => (r['status']?.toString() ?? '').toLowerCase() == 'pending').toList();
  }

  int get _usedDaysThisMonth {
    final now = DateTime.now();
    int count = 0;
    for (final r in _myRequests) {
      final st = (r['status']?.toString() ?? '').toLowerCase();
      if (st == 'approved') {
        final dStr = r['startDate']?.toString() ?? r['date']?.toString();
        if (dStr != null) {
          try {
            final dt = DateTime.parse(dStr);
            if (dt.month == now.month && dt.year == now.year) {
              count += (r['totalDays'] as num?)?.toInt() ?? 1;
            }
          } catch (_) {}
        }
      }
    }
    return count;
  }

  int get _wfhTodayCount {
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return _allRequests.where((r) {
      final st = (r['status']?.toString() ?? '').toLowerCase();
      final dStr = r['startDate']?.toString() ?? r['date']?.toString();
      return st == 'approved' && dStr != null && dStr.startsWith(todayStr);
    }).length;
  }

  List<dynamic> get _filteredTeamLogs {
    return _allRequests.where((req) {
      final empName = (req['employeeName']?.toString() ?? req['name']?.toString() ?? '').toLowerCase();
      final empDept = (req['employeeDepartment']?.toString() ?? req['department']?.toString() ?? '').toLowerCase();
      final reason = (req['reason']?.toString() ?? '').toLowerCase();
      final reqStatus = (req['status']?.toString() ?? 'pending').toUpperCase();

      final term = _searchTerm.trim().toLowerCase();
      final matchSearch = term.isEmpty || empName.contains(term) || empDept.contains(term) || reason.contains(term);
      final matchStatus = _statusFilter == 'ALL' || reqStatus == _statusFilter;

      return matchSearch && matchStatus;
    }).toList();
  }

  String _formatDate(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '';
    try {
      final dt = DateTime.parse(raw);
      return DateFormat('MMM d, yyyy').format(dt);
    } catch (_) {
      return raw;
    }
  }

  String _extractCategory(String? reason) {
    if (reason == null) return 'Personal';
    final match = RegExp(r'Category:\s*([^|]+)', caseSensitive: false).firstMatch(reason);
    return match != null ? match.group(1)!.trim() : 'Personal';
  }

  String _extractReasonText(String? reason) {
    if (reason == null) return '';
    final match = RegExp(r'Reason:\s*([^|]+)', caseSensitive: false).firstMatch(reason);
    if (match != null) return match.group(1)!.trim();
    return reason.replaceAll(RegExp(r'\[WFH\]', caseSensitive: false), '').trim();
  }

  String _extractDeliverables(String? reason) {
    if (reason == null) return '';
    final match = RegExp(r'Deliverables:\s*([^|]+)', caseSensitive: false).firstMatch(reason);
    return match != null ? match.group(1)!.trim() : '';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBgColor = isDark ? AppColors.darkMainSurface : Colors.white;
    final titleText = _canReview ? 'Work From Home Management' : 'Work From Home Apply';

    return GlassScaffold(
      appBar: GlassHeader(
        title: titleText,
        actions: [
          IconButton(
            icon: _isLoading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                : const Icon(Icons.refresh_rounded, size: 20),
            tooltip: 'Refresh Requests',
            onPressed: _isLoading ? null : _loadData,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Stat Cards Section
            _buildStatsOverview(isDark),
            const SizedBox(height: 14),

            // Navigation Tabs
            _buildNavigationTabs(isDark),
            const SizedBox(height: 14),

            // Tab Content
            if (_activeTab == 'approvals' && _canReview)
              _buildApprovalsTab(isDark, cardBgColor)
            else if (_activeTab == 'apply')
              _buildApplyTab(isDark, cardBgColor)
            else if (_activeTab == 'my-requests')
              _buildMyRequestsTab(isDark, cardBgColor)
            else if (_activeTab == 'team-logs' && _canReview)
              _buildTeamLogsTab(isDark, cardBgColor)
            else
              _buildApplyTab(isDark, cardBgColor),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsOverview(bool isDark) {
    if (_canReview) {
      return Row(
        children: [
          Expanded(
            child: _buildStatCard(
              label: 'PENDING APPROVALS',
              value: '${_pendingApprovals.length}',
              icon: Icons.access_time_rounded,
              bgColor: const Color(0xFFFEF3C7),
              iconColor: const Color(0xFFD97706),
              activeTextColor: const Color(0xFFD97706),
              isDark: isDark,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildStatCard(
              label: 'WFH TODAY',
              value: '$_wfhTodayCount',
              icon: Icons.house_rounded,
              bgColor: const Color(0xFFE0EDFF),
              iconColor: const Color(0xFF2563EB),
              activeTextColor: const Color(0xFF2563EB),
              isDark: isDark,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildStatCard(
              label: 'TOTAL LOGGED',
              value: '${_allRequests.length}',
              icon: Icons.format_list_bulleted_rounded,
              bgColor: isDark ? AppColors.darkSecondarySurface : const Color(0xFFF1F5F9),
              iconColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF334155),
              activeTextColor: isDark ? AppColors.darkPrimaryText : const Color(0xFF0F172A),
              isDark: isDark,
            ),
          ),
        ],
      );
    }

    // Employee Stats
    final myPending = _myRequests.where((r) => (r['status']?.toString() ?? '').toLowerCase() == 'pending').length;
    final myApproved = _myRequests.where((r) => (r['status']?.toString() ?? '').toLowerCase() == 'approved').length;

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            label: 'DAYS THIS MONTH',
            value: '$_usedDaysThisMonth',
            icon: Icons.calendar_month_rounded,
            bgColor: const Color(0xFFEEF2FF),
            iconColor: const Color(0xFF4F46E5),
            activeTextColor: const Color(0xFF4F46E5),
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatCard(
            label: 'PENDING',
            value: '$myPending',
            icon: Icons.access_time_rounded,
            bgColor: const Color(0xFFFEF3C7),
            iconColor: const Color(0xFFD97706),
            activeTextColor: const Color(0xFFD97706),
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatCard(
            label: 'APPROVED',
            value: '$myApproved',
            icon: Icons.check_circle_outline_rounded,
            bgColor: const Color(0xFFECFDF5),
            iconColor: const Color(0xFF059669),
            activeTextColor: const Color(0xFF059669),
            isDark: isDark,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String label,
    required String value,
    required IconData icon,
    required Color bgColor,
    required Color iconColor,
    required Color activeTextColor,
    required bool isDark,
  }) {
    final intVal = int.tryParse(value) ?? 0;
    final displayTextColor = intVal > 0 ? activeTextColor : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B));

    return Container(
      constraints: const BoxConstraints(minHeight: 72),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkMainSurface : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? AppColors.darkBordersAndDividers : const Color(0xFFE5E7EB)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(6)),
            child: Icon(icon, size: 14, color: iconColor),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: displayTextColor),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: isDark ? AppColors.darkSecondaryText : const Color(0xFF475569),
              height: 1.1,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationTabs(bool isDark) {
    final tabs = <Map<String, dynamic>>[];
    if (_canReview) {
      tabs.add({'key': 'approvals', 'label': 'Approvals', 'badge': _pendingApprovals.length, 'icon': Icons.task_alt_rounded});
    }
    tabs.add({'key': 'apply', 'label': 'Apply WFH', 'icon': Icons.add_circle_outline_rounded});
    tabs.add({'key': 'my-requests', 'label': 'My Requests', 'badge': _myRequests.length, 'icon': Icons.history_rounded});
    if (_canReview) {
      tabs.add({'key': 'team-logs', 'label': 'Team Logs', 'icon': Icons.people_outline_rounded});
    }

    return Container(
      height: 40,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSecondarySurface : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? AppColors.darkBordersAndDividers : const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: tabs.map((t) {
          final key = t['key'] as String;
          final label = t['label'] as String;
          final badge = t['badge'] as int?;
          final icon = t['icon'] as IconData;
          final isActive = _activeTab == key;

          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _activeTab = key),
              child: Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: isActive ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 14, color: isActive ? Colors.white : (isDark ? AppColors.darkSecondaryText : const Color(0xFF475569))),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                          color: isActive ? Colors.white : (isDark ? AppColors.darkPrimaryText : const Color(0xFF334155)),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (badge != null && badge > 0) ...[
                      const SizedBox(width: 3),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: isActive ? Colors.white.withOpacity(0.25) : const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$badge',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isActive ? Colors.white : const Color(0xFFB45309),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // TAB 1: Pending Approvals (Admin/HR/TL)
  Widget _buildApprovalsTab(bool isDark, Color cardBgColor) {
    if (_isLoading) {
      return const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator(color: AppColors.primary)));
    }

    if (_pendingApprovals.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: cardBgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isDark ? AppColors.darkBordersAndDividers : const Color(0xFFE5E7EB)),
        ),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(color: Color(0xFFECFDF5), shape: BoxShape.circle),
              child: const Icon(Icons.check_circle_outline_rounded, size: 32, color: Color(0xFF059669)),
            ),
            const SizedBox(height: 12),
            Text('All Caught Up!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? AppColors.darkPrimaryText : const Color(0xFF0F172A))),
            const SizedBox(height: 4),
            Text('There are no pending Work From Home requests requiring your approval right now.', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: isDark ? AppColors.darkSecondaryText : const Color(0xFF64748B))),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _pendingApprovals.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final req = _pendingApprovals[index];
        final empName = req['employeeName']?.toString() ?? req['name']?.toString() ?? 'Employee';
        final empDept = req['employeeDepartment']?.toString() ?? req['department']?.toString() ?? 'General';
        final empDesig = req['employeeDesignation']?.toString() ?? req['designation']?.toString();
        final startDate = _formatDate(req['startDate']?.toString() ?? req['date']?.toString());
        final endDate = _formatDate(req['endDate']?.toString() ?? req['date']?.toString());
        final totalDays = (req['totalDays'] as num?)?.toInt() ?? 1;
        final rawReason = req['reason']?.toString() ?? '';
        final category = _extractCategory(rawReason);
        final reasonText = _extractReasonText(rawReason);
        final deliverables = _extractDeliverables(rawReason);

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cardBgColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? AppColors.darkBordersAndDividers : const Color(0xFFE5E7EB)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: isDark ? Colors.white12 : const Color(0xFF0F172A),
                          child: Text(
                            empName.isNotEmpty ? empName.substring(0, 1).toUpperCase() : 'E',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(empName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? AppColors.darkPrimaryText : const Color(0xFF0F172A)), overflow: TextOverflow.ellipsis),
                              Text('$empDept${empDesig != null ? " • $empDesig" : ""}', style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkSecondaryText : const Color(0xFF64748B)), overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(6), border: Border.all(color: const Color(0xFFFDE68A))),
                    child: Text('$totalDays Day(s)', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF92400E))),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Divider(height: 1, color: isDark ? AppColors.darkBordersAndDividers : const Color(0xFFE5E7EB)),
              const SizedBox(height: 10),

              // Date Period
              Row(
                children: [
                  Icon(Icons.calendar_today_rounded, size: 14, color: isDark ? AppColors.darkSecondaryText : const Color(0xFF64748B)),
                  const SizedBox(width: 6),
                  Text(
                    startDate == endDate || endDate.isEmpty ? startDate : '$startDate to $endDate',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: isDark ? AppColors.darkPrimaryText : const Color(0xFF0F172A)),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Category & Reason Text
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSecondarySurface : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isDark ? AppColors.darkBordersAndDividers : const Color(0xFFE5E7EB)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(4)),
                      child: Text(category.toUpperCase(), style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: isDark ? AppColors.darkSecondaryText : const Color(0xFF475569))),
                    ),
                    const SizedBox(height: 6),
                    Text(reasonText, style: TextStyle(fontSize: 12.5, color: isDark ? AppColors.darkPrimaryText : const Color(0xFF334155), height: 1.3)),
                    if (deliverables.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.task_alt_rounded, size: 13, color: AppColors.primary),
                          const SizedBox(width: 4),
                          const Text('Deliverables:', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.primary)),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(deliverables, style: TextStyle(fontSize: 11.5, color: isDark ? AppColors.darkSecondaryText : const Color(0xFF475569))),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _updatingId == req['id'] ? null : () => _showRejectDialog(req),
                      icon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFFDC2626)),
                      label: const Text('Reject', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFFDC2626))),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: const Color(0xFFFEF2F2),
                        side: const BorderSide(color: Color(0xFFFECACA)),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _updatingId == req['id'] ? null : () => _showApproveDialog(req),
                      icon: const Icon(Icons.check_rounded, size: 16, color: Colors.white),
                      label: const Text('Approve', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // TAB 2: Apply for WFH
  Widget _buildApplyTab(bool isDark, Color cardBgColor) {
    if (_submitted) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: cardBgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isDark ? AppColors.darkBordersAndDividers : const Color(0xFFE5E7EB)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Column(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: const Color(0xFF10B981).withOpacity(0.2), blurRadius: 10, spreadRadius: 2)],
              ),
              child: const Icon(Icons.check_rounded, size: 32, color: Color(0xFF059669)),
            ),
            const SizedBox(height: 16),
            Text(
              'WFH Request Submitted Successfully!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: isDark ? AppColors.darkPrimaryText : const Color(0xFF0F172A)),
            ),
            const SizedBox(height: 8),
            Text(
              'Your work-from-home request for $_calculatedDays day(s) (${DateFormat('MMM d, yyyy').format(_startDate)}) has been submitted for review.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: isDark ? AppColors.darkSecondaryText : const Color(0xFF64748B), height: 1.4),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _resetForm,
                    icon: const Icon(Icons.add_circle_outline_rounded, size: 16, color: Colors.white),
                    label: const Text('Apply Another', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => setState(() => _activeTab = 'my-requests'),
                    icon: Icon(Icons.history_rounded, size: 16, color: isDark ? AppColors.darkPrimaryText : const Color(0xFF1E293B)),
                    label: Text('My Requests', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isDark ? AppColors.darkPrimaryText : const Color(0xFF1E293B))),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: BorderSide(color: isDark ? AppColors.darkBordersAndDividers : const Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? AppColors.darkBordersAndDividers : const Color(0xFFE5E7EB)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Header Bar with Duration Pill
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.laptop_chromebook_rounded, color: AppColors.primary, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'New Work From Home Application',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: isDark ? AppColors.darkPrimaryText : const Color(0xFF0F172A)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    const Text('* Mandatory fields', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xCCDC2626))),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
                child: Text('$_calculatedDays Day(s)', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Divider(height: 1, color: isDark ? AppColors.darkBordersAndDividers : const Color(0xFFE5E7EB)),
          const SizedBox(height: 14),

          // Duration Mode Pill Toggle (Single Day vs Date Range)
          const Text('Duration Type', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.calendar_today_rounded, size: 14), SizedBox(width: 6), Text('Single Day')]),
                  selected: _dateMode == 'single',
                  onSelected: (_) => setState(() {
                    _dateMode = 'single';
                    _endDate = _startDate;
                  }),
                  selectedColor: AppColors.primary,
                  labelStyle: TextStyle(color: _dateMode == 'single' ? Colors.white : (isDark ? AppColors.darkPrimaryText : const Color(0xFF334155)), fontSize: 13, fontWeight: FontWeight.w600),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  showCheckmark: false,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ChoiceChip(
                  label: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.date_range_rounded, size: 14), SizedBox(width: 6), Text('Date Range')]),
                  selected: _dateMode == 'range',
                  onSelected: (_) => setState(() => _dateMode = 'range'),
                  selectedColor: AppColors.primary,
                  labelStyle: TextStyle(color: _dateMode == 'range' ? Colors.white : (isDark ? AppColors.darkPrimaryText : const Color(0xFF334155)), fontSize: 13, fontWeight: FontWeight.w600),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  showCheckmark: false,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Dates Picker Row
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.calendar_month_rounded, size: 14, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Text(_dateMode == 'single' ? 'Date of WFH' : 'Start Date', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                        const Text(' *', style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 48,
                      child: InkWell(
                        onTap: _selectStartDate,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkMainSurface : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: isDark ? AppColors.darkBordersAndDividers : const Color(0xFFCBD5E1)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(DateFormat('MMM d, yyyy').format(_startDate), style: TextStyle(fontSize: 13, color: isDark ? AppColors.darkPrimaryText : const Color(0xFF0F172A))),
                              const Icon(Icons.event, color: AppColors.primary, size: 18),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_dateMode == 'range') ...[
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.event_available_rounded, size: 14, color: AppColors.primary),
                          SizedBox(width: 4),
                          Text('End Date', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                          Text(' *', style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        height: 48,
                        child: InkWell(
                          onTap: _selectEndDate,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.darkMainSurface : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: isDark ? AppColors.darkBordersAndDividers : const Color(0xFFCBD5E1)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(DateFormat('MMM d, yyyy').format(_endDate), style: TextStyle(fontSize: 13, color: isDark ? AppColors.darkPrimaryText : const Color(0xFF0F172A))),
                                const Icon(Icons.event, color: AppColors.primary, size: 18),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),

          // Reason Category Dropdown
          const Row(
            children: [
              Icon(Icons.category_outlined, size: 14, color: AppColors.primary),
              SizedBox(width: 4),
              Text('Reason Category', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
              Text(' *', style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 48,
            child: DropdownButtonFormField<String>(
              value: _reasonCategory,
              dropdownColor: isDark ? AppColors.darkMainSurface : Colors.white,
              decoration: InputDecoration(
                filled: true,
                fillColor: isDark ? AppColors.darkMainSurface : Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? AppColors.darkBordersAndDividers : const Color(0xFFCBD5E1))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? AppColors.darkBordersAndDividers : const Color(0xFFCBD5E1))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
              ),
              items: _reasonCategories.map((cat) => DropdownMenuItem(value: cat, child: Text(cat, style: const TextStyle(fontSize: 13)))).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _reasonCategory = val);
              },
            ),
          ),
          const SizedBox(height: 14),

          // Detailed Reason Field
          const Row(
            children: [
              Icon(Icons.comment_bank_outlined, size: 14, color: AppColors.primary),
              SizedBox(width: 4),
              Text('Detailed Reason', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
              Text(' *', style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 80),
            child: TextField(
              controller: _reasonDetailsController,
              minLines: 3,
              maxLines: 4,
              style: TextStyle(fontSize: 13.5, color: isDark ? AppColors.darkPrimaryText : const Color(0xFF0F172A), height: 1.35),
              decoration: InputDecoration(
                hintText: 'Explain the reason for working from home...',
                hintStyle: TextStyle(fontSize: 12.5, color: isDark ? AppColors.darkMutedText : const Color(0xFF94A3B8)),
                filled: true,
                fillColor: isDark ? AppColors.darkMainSurface : Colors.white,
                contentPadding: const EdgeInsets.all(12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? AppColors.darkBordersAndDividers : const Color(0xFFCBD5E1))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? AppColors.darkBordersAndDividers : const Color(0xFFCBD5E1))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Planned Deliverables Field
          const Row(
            children: [
              Icon(Icons.task_alt_rounded, size: 14, color: AppColors.primary),
              SizedBox(width: 4),
              Text('Planned Deliverables / Key Tasks', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 70),
            child: TextField(
              controller: _workDeliverablesController,
              minLines: 2,
              maxLines: 3,
              style: TextStyle(fontSize: 13.5, color: isDark ? AppColors.darkPrimaryText : const Color(0xFF0F172A), height: 1.35),
              decoration: InputDecoration(
                hintText: 'e.g. 1. Complete sprint task #402, 2. Attend client demo at 3 PM...',
                hintStyle: TextStyle(fontSize: 12, color: isDark ? AppColors.darkMutedText : const Color(0xFF94A3B8)),
                filled: true,
                fillColor: isDark ? AppColors.darkMainSurface : Colors.white,
                contentPadding: const EdgeInsets.all(12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? AppColors.darkBordersAndDividers : const Color(0xFFCBD5E1))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? AppColors.darkBordersAndDividers : const Color(0xFFCBD5E1))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Contact Notes Field
          const Row(
            children: [
              Icon(Icons.phone_outlined, size: 14, color: AppColors.primary),
              SizedBox(width: 4),
              Text('Availability / Communication Note', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 48,
            child: TextField(
              controller: _contactNotesController,
              style: TextStyle(fontSize: 13.5, color: isDark ? AppColors.darkPrimaryText : const Color(0xFF0F172A)),
              decoration: InputDecoration(
                hintText: 'e.g. Available on Teams and phone 9:30 AM to 6:30 PM',
                hintStyle: TextStyle(fontSize: 12.5, color: isDark ? AppColors.darkMutedText : const Color(0xFF94A3B8)),
                filled: true,
                fillColor: isDark ? AppColors.darkMainSurface : Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? AppColors.darkBordersAndDividers : const Color(0xFFCBD5E1))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? AppColors.darkBordersAndDividers : const Color(0xFFCBD5E1))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Submit Button
          SizedBox(
            height: 50,
            width: double.infinity,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [
                  BoxShadow(
                    color: Color.fromRGBO(13, 110, 100, 0.22),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitApplication,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _isSubmitting
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                          SizedBox(width: 10),
                          Text('Submitting Application...', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                        ],
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.send_rounded, size: 18, color: Colors.white),
                          SizedBox(width: 8),
                          Text('Submit WFH Application', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: Colors.white)),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // TAB 3: My WFH Requests
  Widget _buildMyRequestsTab(bool isDark, Color cardBgColor) {
    if (_isLoading) {
      return const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator(color: AppColors.primary)));
    }

    if (_myRequests.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
        decoration: BoxDecoration(
          color: cardBgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isDark ? AppColors.darkBordersAndDividers : const Color(0xFFE5E7EB)),
        ),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.12), shape: BoxShape.circle),
              child: const Icon(Icons.calendar_month_outlined, size: 32, color: AppColors.primary),
            ),
            const SizedBox(height: 12),
            Text('No WFH Requests Found', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: isDark ? AppColors.darkPrimaryText : const Color(0xFF0F172A))),
            const SizedBox(height: 6),
            Text('You haven\'t applied for any Work From Home days yet.', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: isDark ? AppColors.darkSecondaryText : const Color(0xFF475569))),
            const SizedBox(height: 16),
            SizedBox(
              height: 40,
              child: OutlinedButton.icon(
                onPressed: () => setState(() => _activeTab = 'apply'),
                icon: const Icon(Icons.add_circle_outline_rounded, size: 16, color: AppColors.primary),
                label: const Text('Apply for WFH Now', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.primary)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.primary, width: 1.5),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _myRequests.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final req = _myRequests[index];
        final startDate = _formatDate(req['startDate']?.toString() ?? req['date']?.toString());
        final endDate = _formatDate(req['endDate']?.toString() ?? req['date']?.toString());
        final totalDays = (req['totalDays'] as num?)?.toInt() ?? 1;
        final rawReason = req['reason']?.toString() ?? '';
        final category = _extractCategory(rawReason);
        final reasonText = _extractReasonText(rawReason);
        final deliverables = _extractDeliverables(rawReason);
        final status = req['status']?.toString() ?? 'Pending';
        final isPending = status.toLowerCase() == 'pending';
        final comments = req['approverComments']?.toString() ?? req['comments']?.toString() ?? '';
        final id = req['id']?.toString() ?? req['_id']?.toString() ?? '';

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cardBgColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? AppColors.darkBordersAndDividers : const Color(0xFFE5E7EB)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 2))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.home_work_rounded, color: AppColors.primary, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(startDate == endDate || endDate.isEmpty ? startDate : '$startDate to $endDate', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: isDark ? AppColors.darkPrimaryText : const Color(0xFF0F172A))),
                          Text('$totalDays Day(s)', style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkSecondaryText : const Color(0xFF64748B))),
                        ],
                      ),
                    ],
                  ),
                  StatusChip(status: status),
                ],
              ),
              const SizedBox(height: 10),
              Divider(height: 1, color: isDark ? AppColors.darkBordersAndDividers : const Color(0xFFE5E7EB)),
              const SizedBox(height: 8),

              // Category & Reason Text
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(4)),
                    child: Text(category.toUpperCase(), style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: isDark ? AppColors.darkSecondaryText : const Color(0xFF475569))),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(reasonText, style: TextStyle(fontSize: 12.5, color: isDark ? AppColors.darkPrimaryText : const Color(0xFF334155)), overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),

              if (deliverables.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text('Deliverables: $deliverables', style: TextStyle(fontSize: 11.5, color: isDark ? AppColors.darkSecondaryText : const Color(0xFF64748B)), overflow: TextOverflow.ellipsis),
              ],

              if (comments.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text('Approver Note: "$comments"', style: const TextStyle(fontSize: 11.5, fontStyle: FontStyle.italic, color: Color(0xFF059669))),
              ],

              if (isPending) ...[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    onPressed: _cancellingId == id ? null : () => _cancelRequest(req),
                    icon: _cancellingId == id
                        ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFDC2626)))
                        : const Icon(Icons.close_rounded, size: 14, color: Color(0xFFDC2626)),
                    label: const Text('Cancel Request', style: TextStyle(fontSize: 12, color: Color(0xFFDC2626), fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: const Color(0xFFFEF2F2),
                      side: const BorderSide(color: Color(0xFFFECACA)),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  // TAB 4: Team WFH History (Admin/HR/TL)
  Widget _buildTeamLogsTab(bool isDark, Color cardBgColor) {
    final filtered = _filteredTeamLogs;

    return Column(
      children: [
        // Search & Filter Toolbar
        SizedBox(
          height: 44,
          child: TextField(
            onChanged: (val) => setState(() => _searchTerm = val),
            style: TextStyle(fontSize: 14, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText),
            decoration: InputDecoration(
              hintText: 'Search employee, department, reason...',
              hintStyle: TextStyle(fontSize: 13, color: isDark ? AppColors.darkMutedText : const Color(0xFF94A3B8)),
              prefixIcon: Icon(Icons.search_rounded, size: 18, color: isDark ? AppColors.darkSecondaryText : const Color(0xFF64748B)),
              filled: true,
              fillColor: isDark ? AppColors.darkMainSurface : Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: isDark ? AppColors.darkBordersAndDividers : const Color(0xFFE5E7EB))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: isDark ? AppColors.darkBordersAndDividers : const Color(0xFFE5E7EB))),
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Status Choice Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: ['ALL', 'PENDING', 'APPROVED', 'REJECTED', 'CANCELLED'].map((status) {
              final selected = _statusFilter.toUpperCase() == status;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text(status),
                  selected: selected,
                  onSelected: (_) => setState(() => _statusFilter = status),
                  selectedColor: AppColors.primary,
                  backgroundColor: isDark ? AppColors.darkMainSurface : Colors.white,
                  labelStyle: TextStyle(fontSize: 12, color: selected ? Colors.white : (isDark ? AppColors.darkPrimaryText : const Color(0xFF334155))),
                  shape: StadiumBorder(side: BorderSide(color: selected ? AppColors.primary : (isDark ? AppColors.darkBordersAndDividers : const Color(0xFFE5E7EB)))),
                  showCheckmark: false,
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),

        if (_isLoading)
          const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator(color: AppColors.primary)))
        else if (filtered.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(color: cardBgColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: isDark ? AppColors.darkBordersAndDividers : const Color(0xFFE5E7EB))),
            child: Column(
              children: [
                const Icon(Icons.search_off_rounded, size: 36, color: Color(0xFF94A3B8)),
                const SizedBox(height: 8),
                Text('No Records Found', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? AppColors.darkPrimaryText : const Color(0xFF0F172A))),
                const SizedBox(height: 4),
                Text('No WFH logs match your current search and filter criteria.', style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkSecondaryText : const Color(0xFF64748B))),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filtered.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final req = filtered[index];
              final empName = req['employeeName']?.toString() ?? req['name']?.toString() ?? 'Employee';
              final empDept = req['employeeDepartment']?.toString() ?? req['department']?.toString() ?? 'General';
              final startDate = _formatDate(req['startDate']?.toString() ?? req['date']?.toString());
              final endDate = _formatDate(req['endDate']?.toString() ?? req['date']?.toString());
              final rawReason = req['reason']?.toString() ?? '';
              final category = _extractCategory(rawReason);
              final reasonText = _extractReasonText(rawReason);
              final status = req['status']?.toString() ?? 'Pending';
              final approvedBy = req['approvedBy']?.toString() ?? req['reviewedBy']?.toString();

              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cardBgColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? AppColors.darkBordersAndDividers : const Color(0xFFE5E7EB)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                              child: Text(empName.isNotEmpty ? empName.substring(0, 1).toUpperCase() : 'E', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? AppColors.darkPrimaryText : const Color(0xFF0F172A))),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(empName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? AppColors.darkPrimaryText : const Color(0xFF0F172A))),
                                Text(empDept, style: TextStyle(fontSize: 10.5, color: isDark ? AppColors.darkSecondaryText : const Color(0xFF64748B))),
                              ],
                            ),
                          ],
                        ),
                        StatusChip(status: status),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(startDate == endDate || endDate.isEmpty ? startDate : '$startDate to $endDate', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? AppColors.darkPrimaryText : const Color(0xFF0F172A))),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(4)),
                          child: Text(category.toUpperCase(), style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: isDark ? AppColors.darkSecondaryText : const Color(0xFF475569))),
                        ),
                      ],
                    ),
                    if (reasonText.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text('"$reasonText"', style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: isDark ? AppColors.darkSecondaryText : const Color(0xFF475569))),
                    ],
                    if (approvedBy != null && approvedBy.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text('Reviewed by: $approvedBy', style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkSecondaryText : const Color(0xFF64748B))),
                    ],
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}
