import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/auth/auth_service.dart';
import '../../core/errors/api_exception.dart';
import '../../core/models/user_model.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/glass_theme.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/glass_header.dart';
import '../../core/widgets/glass_scaffold.dart';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  final Function(int)? onNavigateTab;
  final bool showAppBar;

  const AdminDashboardScreen({super.key, this.onNavigateTab, this.showAppBar = false});

  @override
  ConsumerState<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  final Set<String> _processingLeaveIds = {};

  // Category Tab Selection (0: Overview, 1: Workforce, 2: Operations, 3: Insights & Approvals)
  int _selectedCategoryTab = 0;

  // Global Dashboard Filters
  String _selectedDateFilter = 'This Month';
  String _selectedDeptFilter = 'All Departments';

  // Key KPI Statistics
  Map<String, dynamic> _stats = {
    'totalEmployees': 15,
    'activeEmployees': 15,
    'departments': 7,
    'branches': 4,
    'onLeaveToday': 1,
    'pendingLeaves': 0,
    'openPositions': 2,
    'candidatesInPipeline': 1,
    'hiredThisMonth': 0,
    'monthlyPayrollNet': 0.0,
    'payrollProcessedThisMonth': 0,
  };

  // Department Distribution
  List<Map<String, dynamic>> _deptDistribution = [
    {'name': 'Human Resources', 'count': 2, 'pct': 13, 'color': const Color(0xFF3B82F6)},
    {'name': 'Sales', 'count': 1, 'pct': 7, 'color': const Color(0xFF22C55E)},
    {'name': 'Finance', 'count': 1, 'pct': 7, 'color': const Color(0xFF0284C7)},
    {'name': 'Marketing', 'count': 0, 'pct': 0, 'color': const Color(0xFFF97316)},
    {'name': 'Engineering', 'count': 11, 'pct': 73, 'color': const Color(0xFFEF4444)},
  ];
  int _deptTotalCount = 15;

  // Upcoming Birthdays
  List<Map<String, dynamic>> _upcomingBirthdays = [
    {'name': 'Devyani Borase', 'formattedDate': '16 Nov', 'initials': 'DB', 'avatar': null},
    {'name': 'Amit Prajapati', 'formattedDate': '25 Nov', 'initials': 'AP', 'avatar': null},
  ];

  // Announcements
  List<Map<String, dynamic>> _announcements = [
    {
      'id': '1',
      'title': 'Diwali Celebration',
      'time': '12d ago',
      'type': 'PINNED',
      'icon': 'fas fa-bullhorn',
      'colorClass': 'icon-orange'
    }
  ];

  // Upcoming Meetings
  List<Map<String, dynamic>> _upcomingMeetings = [];

  // Today's Attendance Summary
  Map<String, dynamic> _attendanceStats = {
    'total': 15,
    'present': 0,
    'presentPct': 0,
    'absent': 15,
    'absentPct': 100,
    'wfh': 0,
    'wfhPct': 0,
    'late': 0,
    'latePct': 0,
  };

  // Pending Leave Requests
  List<Map<String, dynamic>> _pendingLeaves = [
    {
      'id': '1',
      'employee': 'Ravi two',
      'leaveType': 'SICK_LEAVE',
      'days': '2 days',
      'dateRange': 'Nov 4 – Nov 5, 2026',
      'initials': 'RT',
      'avatar': null,
    }
  ];

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
    _requestId++;
    final authState = ref.read(authServiceProvider);
    final user = authState.user;

    if (user == null || !authState.isAuthenticated) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'No authenticated user found.';
      });
      return;
    }

    if (_currentUserId != user.id) {
      _currentUserId = user.id;
    }

    final userRole = user.role;
    final bool isAuthorized = userRole == UserRole.ADMIN || userRole == UserRole.HR;

    if (!isAuthorized) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = null;
      });
      return;
    }

    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    final currentReq = ++_requestId;
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final apiClient = ref.read(apiClientProvider);

    try {
      // 1. Fetch Stats
      try {
        final statsRes = await apiClient.get(ApiEndpoints.reportsDashboardStats).timeout(const Duration(seconds: 4));
        if (!mounted || currentReq != _requestId) return;
        dynamic rawStats = statsRes is Map<String, dynamic> && statsRes.containsKey('data') ? statsRes['data'] : statsRes;
        if (rawStats is Map<String, dynamic>) {
          if (rawStats['totalEmployees'] != null) _stats['totalEmployees'] = rawStats['totalEmployees'];
          if (rawStats['activeEmployees'] != null) _stats['activeEmployees'] = rawStats['activeEmployees'];
          if (rawStats['departments'] != null) _stats['departments'] = rawStats['departments'];
          if (rawStats['branches'] != null || rawStats['teams'] != null) {
            _stats['branches'] = (rawStats['branches'] ?? 0) + (rawStats['teams'] ?? 0);
          }
          if (rawStats['onLeaveToday'] != null) _stats['onLeaveToday'] = rawStats['onLeaveToday'];
          if (rawStats['pendingLeaves'] != null) _stats['pendingLeaves'] = rawStats['pendingLeaves'];
          if (rawStats['openPositions'] != null) _stats['openPositions'] = rawStats['openPositions'];
          if (rawStats['candidatesInPipeline'] != null) _stats['candidatesInPipeline'] = rawStats['candidatesInPipeline'];
          if (rawStats['hiredThisMonth'] != null) _stats['hiredThisMonth'] = rawStats['hiredThisMonth'];
          if (rawStats['monthlyPayrollNet'] != null) _stats['monthlyPayrollNet'] = rawStats['monthlyPayrollNet'];
          if (rawStats['payrollProcessedThisMonth'] != null) _stats['payrollProcessedThisMonth'] = rawStats['payrollProcessedThisMonth'];
        }
      } catch (e) {
        debugPrint('[AdminDashboard] Stats fetch warning: $e');
      }

      // 2. Fetch Employees
      try {
        final empRes = await apiClient.get(ApiEndpoints.employeesAll).timeout(const Duration(seconds: 4));
        if (!mounted || currentReq != _requestId) return;
        dynamic rawEmps = empRes is Map<String, dynamic> && empRes.containsKey('data') ? empRes['data'] : empRes;
        if (rawEmps is List && rawEmps.isNotEmpty) {
          _stats['totalEmployees'] = rawEmps.length;
          _stats['activeEmployees'] = rawEmps.where((e) {
            if (e is! Map<String, dynamic>) return false;
            final st = (e['status'] ?? e['employmentStatus'] ?? '').toString().toUpperCase();
            final isAct = e['isActive'];
            return st == 'ACTIVE' || isAct == true;
          }).length;
        }
      } catch (e) {
        debugPrint('[AdminDashboard] Employees fetch warning: $e');
      }

      // 3. Fetch Department Distribution
      try {
        final deptRes = await apiClient.get(ApiEndpoints.dashboardDepartmentDistribution).timeout(const Duration(seconds: 4));
        if (!mounted || currentReq != _requestId) return;
        dynamic rawDept = deptRes is Map<String, dynamic> && deptRes.containsKey('data') ? deptRes['data'] : deptRes;

        List<Map<String, dynamic>> distList = [];
        int sumTotal = 0;
        final colors = [
          const Color(0xFF3B82F6),
          const Color(0xFF22C55E),
          const Color(0xFF0284C7),
          const Color(0xFFF97316),
          const Color(0xFFEF4444),
          const Color(0xFF06B6D4),
        ];

        if (rawDept is Map<String, dynamic> && rawDept.containsKey('labels') && rawDept.containsKey('datasets')) {
          final labels = rawDept['labels'] as List? ?? [];
          final datasets = rawDept['datasets'] as List? ?? [];
          if (datasets.isNotEmpty && datasets[0] is Map<String, dynamic>) {
            final dataList = (datasets[0]['data'] as List?) ?? [];
            for (int i = 0; i < labels.length; i++) {
              final cnt = (i < dataList.length) ? (int.tryParse(dataList[i].toString()) ?? 0) : 0;
              sumTotal += cnt;
              distList.add({
                'name': labels[i].toString(),
                'count': cnt,
                'color': colors[i % colors.length],
              });
            }
          }
        } else if (rawDept is List && rawDept.isNotEmpty) {
          int i = 0;
          for (final item in rawDept) {
            if (item is Map<String, dynamic>) {
              final cnt = int.tryParse((item['count'] ?? item['employeeCount'] ?? 0).toString()) ?? 0;
              sumTotal += cnt;
              distList.add({
                'name': (item['name'] ?? item['departmentName'] ?? 'General').toString(),
                'count': cnt,
                'color': colors[i % colors.length],
              });
              i++;
            }
          }
        }

        if (distList.isNotEmpty) {
          final total = sumTotal > 0 ? sumTotal : (_stats['totalEmployees'] as int? ?? 15);
          for (var d in distList) {
            final c = d['count'] as int;
            d['pct'] = total > 0 ? ((c / total) * 100).round() : 0;
          }
          _deptDistribution = distList;
          _deptTotalCount = total;
        }
      } catch (e) {
        debugPrint('[AdminDashboard] Department distribution warning: $e');
      }

      // 4. Fetch Pending Leaves
      try {
        final leaveRes = await apiClient.get(ApiEndpoints.leavePending).timeout(const Duration(seconds: 4));
        if (!mounted || currentReq != _requestId) return;
        dynamic rawLeaves = leaveRes is Map<String, dynamic> && leaveRes.containsKey('data') ? leaveRes['data'] : leaveRes;

        List<Map<String, dynamic>> leaveList = [];
        if (rawLeaves is List && rawLeaves.isNotEmpty) {
          for (final req in rawLeaves) {
            if (req is Map<String, dynamic>) {
              final empName = (req['employeeName'] ?? req['name'] ?? 'Employee').toString();
              final initialsRaw = empName.isNotEmpty
                  ? empName.split(' ').map((n) => n.isNotEmpty ? n[0] : '').join('').toUpperCase()
                  : 'EM';
              final initials = initialsRaw.length >= 2 ? initialsRaw.substring(0, 2) : initialsRaw;
              final startStr = _formatDate(req['startDate']?.toString());
              final endStr = _formatDate(req['endDate']?.toString());
              final dateRangeStr = startStr != '—' ? (endStr != '—' && startStr != endStr ? '$startStr – $endStr' : startStr) : 'Recent';

              leaveList.add({
                'id': (req['id'] ?? req['_id'])?.toString(),
                'employee': empName,
                'name': empName,
                'leaveType': (req['leaveType'] ?? req['type'] ?? 'Leave').toString(),
                'days': '${req['totalDays'] ?? req['days'] ?? 1} days',
                'dateRange': dateRangeStr,
                'initials': initials,
                'avatar': req['employeeAvatar'] ?? req['avatar'],
                'from': startStr,
                'to': endStr,
              });
            }
          }
          _pendingLeaves = leaveList;
          _stats['pendingLeaves'] = leaveList.length;
        }
      } catch (e) {
        debugPrint('[AdminDashboard] Pending leaves fetch warning: $e');
      }

      // 5. Fetch Announcements
      try {
        final ancRes = await apiClient.get(ApiEndpoints.announcements).timeout(const Duration(seconds: 4));
        if (!mounted || currentReq != _requestId) return;
        dynamic rawAnc = ancRes is Map<String, dynamic> && ancRes.containsKey('data') ? ancRes['data'] : ancRes;

        List<Map<String, dynamic>> ancList = [];
        if (rawAnc is List && rawAnc.isNotEmpty) {
          for (final a in rawAnc) {
            if (a is Map<String, dynamic>) {
              ancList.add({
                'id': (a['id'] ?? a['_id'])?.toString(),
                'title': (a['title'] ?? 'Announcement').toString(),
                'time': _formatTimeAgo(a['publishedDate'] ?? a['createdAt']?.toString()),
                'type': (a['type'] ?? a['priority'] ?? 'GENERAL').toString().toUpperCase(),
                'icon': 'fas fa-bullhorn',
                'colorClass': 'icon-orange',
              });
            }
          }
          _announcements = ancList.take(5).toList();
        }
      } catch (e) {
        debugPrint('[AdminDashboard] Announcements fetch warning: $e');
      }

      // 6. Fetch Upcoming Birthdays
      try {
        final bdayRes = await apiClient.get(ApiEndpoints.dashboardUpcomingBirthdays).timeout(const Duration(seconds: 4));
        if (!mounted || currentReq != _requestId) return;
        dynamic rawBdays = bdayRes is Map<String, dynamic> && bdayRes.containsKey('data') ? bdayRes['data'] : bdayRes;

        List<Map<String, dynamic>> bdayList = [];
        if (rawBdays is List && rawBdays.isNotEmpty) {
          for (final b in rawBdays) {
            if (b is Map<String, dynamic>) {
              final empName = (b['name'] ?? '${b['firstName'] ?? ''} ${b['lastName'] ?? ''}').toString().trim();
              final initialsRaw = empName.isNotEmpty
                  ? empName.split(' ').map((n) => n.isNotEmpty ? n[0] : '').join('').toUpperCase()
                  : 'EM';
              final initials = initialsRaw.length >= 2 ? initialsRaw.substring(0, 2) : initialsRaw;
              bdayList.add({
                'name': empName.isNotEmpty ? empName : 'Employee',
                'initials': initials,
                'avatar': b['avatar'] ?? b['avatarUrl'],
                'formattedDate': b['isToday'] == true ? 'Today' : (b['daysUntil'] == 1 ? 'Tomorrow' : 'Upcoming'),
              });
            }
          }
          if (bdayList.isNotEmpty) {
            _upcomingBirthdays = bdayList;
          }
        }
      } catch (e) {
        debugPrint('[AdminDashboard] Birthdays fetch warning: $e');
      }

      // 7. Fetch Upcoming Meetings
      try {
        final mtgRes = await apiClient.get(ApiEndpoints.meetingsUpcoming).timeout(const Duration(seconds: 4));
        if (!mounted || currentReq != _requestId) return;
        dynamic rawMtgs = mtgRes is Map<String, dynamic> && mtgRes.containsKey('data') ? mtgRes['data'] : mtgRes;

        List<Map<String, dynamic>> mtgList = [];
        if (rawMtgs is List && rawMtgs.isNotEmpty) {
          final months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
          final colors = ['red', 'amber', 'blue', 'purple', 'green'];
          int idx = 0;
          for (final m in rawMtgs.take(5)) {
            if (m is Map<String, dynamic>) {
              final dt = DateTime.tryParse(m['meetingDate']?.toString() ?? '') ?? DateTime.now();
              mtgList.add({
                'id': (m['id'] ?? m['_id'])?.toString(),
                'day': dt.day.toString(),
                'month': months[dt.month - 1],
                'title': (m['title'] ?? 'Scheduled Meeting').toString(),
                'time': '${m['startTime'] ?? ''}${m['endTime'] != null ? ' - ' + m['endTime'] : ''}',
                'platform': 'LiveKit Room',
                'icon': 'fas fa-video',
                'color': colors[idx % colors.length],
              });
              idx++;
            }
          }
          _upcomingMeetings = mtgList;
        }
      } catch (e) {
        debugPrint('[AdminDashboard] Meetings fetch warning: $e');
      }

      // 8. Today's Attendance
      try {
        final todayStr = DateTime.now().toIso8601String().substring(0, 10);
        final attRes = await apiClient.get('${ApiEndpoints.attendanceRecords}?date=$todayStr').timeout(const Duration(seconds: 4));
        if (!mounted || currentReq != _requestId) return;
        dynamic rawAtt = attRes is Map<String, dynamic> && attRes.containsKey('data') ? attRes['data'] : attRes;

        int present = 0;
        int absent = 0;
        int wfh = 0;
        int late = 0;
        final Set<String> seenIds = {};

        if (rawAtt is List && rawAtt.isNotEmpty) {
          for (final a in rawAtt) {
            if (a is Map<String, dynamic>) {
              final empId = (a['employeeId'] ?? a['employeeCode'] ?? a['id'] ?? '').toString();
              if (empId.isNotEmpty) {
                if (seenIds.contains(empId)) continue;
                seenIds.add(empId);
              }
              final st = (a['status'] ?? '').toString().toUpperCase();
              final mode = (a['workMode'] ?? a['location'] ?? '').toString().toUpperCase();
              final isLate = a['isLate'] == true || st.contains('LATE');
              final isWfh = st.contains('WFH') || st.contains('REMOTE') || mode.contains('REMOTE') || mode.contains('HOME');

              if (isWfh) {
                wfh++;
              } else if (isLate) {
                late++;
              } else if (st.contains('PRESENT') || a['checkIn'] != null) {
                present++;
              } else if (st.contains('ABSENT')) {
                absent++;
              }
            }
          }
          final totalEmp = (_stats['totalEmployees'] as int? ?? 15);
          final recorded = present + absent + wfh + late;
          if (recorded == 0) {
            absent = totalEmp;
          }
          final total = totalEmp > 0 ? totalEmp : (present + absent + wfh + late);
          _attendanceStats = {
            'total': total,
            'present': present,
            'presentPct': total > 0 ? ((present / total) * 100).round() : 0,
            'absent': absent,
            'absentPct': total > 0 ? ((absent / total) * 100).round() : 100,
            'wfh': wfh,
            'wfhPct': total > 0 ? ((wfh / total) * 100).round() : 0,
            'late': late,
            'latePct': total > 0 ? ((late / total) * 100).round() : 0,
          };
        }
      } catch (e) {
        debugPrint('[AdminDashboard] Attendance fetch warning: $e');
      }

      if (!mounted || currentReq != _requestId) return;
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted || currentReq != _requestId) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _approveLeaveRequest(Map<String, dynamic> req) async {
    final leaveId = req['id'];
    if (leaveId == null || leaveId.toString().isEmpty) return;

    if (_processingLeaveIds.contains(leaveId)) return;
    setState(() => _processingLeaveIds.add(leaveId.toString()));

    final apiClient = ref.read(apiClientProvider);
    try {
      await apiClient.post(ApiEndpoints.approveOrRejectLeave(leaveId.toString()), body: {
        'status': 'APPROVED',
        'rejectionReason': null,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Approved leave request for ${req['employee'] ?? req['name']}')),
      );
      _loadDashboardData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to approve leave request.'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _processingLeaveIds.remove(leaveId.toString()));
    }
  }

  Future<void> _rejectLeaveRequest(Map<String, dynamic> req) async {
    final leaveId = req['id'];
    if (leaveId == null || leaveId.toString().isEmpty) return;

    if (_processingLeaveIds.contains(leaveId)) return;
    setState(() => _processingLeaveIds.add(leaveId.toString()));

    final apiClient = ref.read(apiClientProvider);
    try {
      await apiClient.post(ApiEndpoints.approveOrRejectLeave(leaveId.toString()), body: {
        'status': 'REJECTED',
        'rejectionReason': 'Rejected from dashboard',
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Rejected leave request for ${req['employee'] ?? req['name']}')),
      );
      _loadDashboardData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to reject leave request.'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _processingLeaveIds.remove(leaveId.toString()));
    }
  }

  String _greeting(String name) {
    final hour = DateTime.now().hour;
    final timeGreeting = hour < 12 ? 'Good morning' : (hour < 17 ? 'Good afternoon' : 'Good evening');
    return '$timeGreeting, $name';
  }

  String _dateLabel(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${weekdays[date.weekday - 1]}, ${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _formatDate(String? d) {
    if (d == null || d.trim().isEmpty) return '—';
    try {
      final dt = DateTime.parse(d);
      return DateFormat('MMM d').format(dt);
    } catch (_) {
      return d;
    }
  }

  String _formatTimeAgo(String? timestampStr) {
    if (timestampStr == null || timestampStr.trim().isEmpty) return 'Recently';
    try {
      final dt = DateTime.parse(timestampStr).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    } catch (_) {
      return 'Recently';
    }
  }

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBgColor = isDark ? const Color(0xFF141D2E) : Colors.white;

    ref.listen<AuthState>(authServiceProvider, (previous, next) {
      if (next.user?.id != _currentUserId) {
        _checkUserAndLoad();
      }
    });

    final authState = ref.watch(authServiceProvider);
    final user = authState.user;
    final userRole = user?.role;
    final bool isAuthorized = userRole == UserRole.ADMIN || userRole == UserRole.HR;

    final userName = (user?.firstName != null && user!.firstName!.isNotEmpty)
        ? '${user.firstName} ${user.lastName ?? ''}'.trim()
        : 'Admin';

    final bodyContent = !isAuthorized
        ? Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: GlassCard(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_outline, size: 48, color: Color(0xFFEF4444)),
                    const SizedBox(height: 16),
                    Text('Access Restricted', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: glass.textPrimary)),
                    const SizedBox(height: 8),
                    Text('You do not have administrative permissions to view the portal dashboard.', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: glass.textSecondary)),
                  ],
                ),
              ),
            ),
          )
        : RefreshIndicator(
            onRefresh: _loadDashboardData,
            child: _buildMainContent(glass, cardBgColor, userName, isDark),
          );

    if (!widget.showAppBar) return Material(color: Colors.transparent, child: bodyContent);

    return GlassScaffold(
      body: bodyContent,
    );
  }

  Widget _buildMainContent(GlassTheme glass, Color cardBgColor, String userName, bool isDark) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. GREETING & DATE HEADER (Matching Employee Dashboard)
          Text(
            _greeting(userName),
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText),
          ),
          const SizedBox(height: 2),
          Text(
            _dateLabel(DateTime.now()),
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? AppColors.darkMutedText : AppColors.lightMutedText),
          ),
          const SizedBox(height: 14),

          // 2. ADMIN HERO GRADIENT BANNER (Dark Teal Gradient matching Employee Dashboard)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F6B66), Color(0xFF054F4B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(color: const Color(0xFF0F6B66).withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 6)),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.admin_panel_settings_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Stay in control, manage efficiently, and keep operations running smoothly.',
                    style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (widget.onNavigateTab != null) widget.onNavigateTab!(1);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF0F6B66),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Manage', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      SizedBox(width: 2),
                      Icon(Icons.chevron_right_rounded, size: 16),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 3. SIX COMPACT KPI CARDS GRID (Compact 2-Column Grid)
          GridView.count(
            crossAxisCount: MediaQuery.of(context).size.width > 900 ? 6 : 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: MediaQuery.of(context).size.width > 900 ? 2.4 : 2.25,
            children: [
              _buildStatCard('Total Employees', '${_stats['totalEmployees']}', Icons.groups_rounded, const Color(0xFF2563EB), const Color(0xFFE0EDFF), '+12%', true, cardBgColor, glass),
              _buildStatCard('Active Employees', '${_stats['activeEmployees']}', Icons.check_circle_outline_rounded, const Color(0xFF16A34A), const Color(0xFFDCFCE7), '+8%', true, cardBgColor, glass),
              _buildStatCard('Departments', '${_stats['departments']}', Icons.business_rounded, const Color(0xFF2563EB), const Color(0xFFEFF6FF), '0%', false, cardBgColor, glass),
              _buildStatCard('Branches / Teams', '${_stats['branches']}', Icons.people_alt_rounded, const Color(0xFFEA580C), const Color(0xFFFFEDD5), '+9%', true, cardBgColor, glass),
              _buildStatCard('On Leave Today', '${_stats['onLeaveToday']}', Icons.calendar_today_rounded, const Color(0xFFDC2626), const Color(0xFFFEE2E2), '+20%', true, cardBgColor, glass),
              _buildStatCard('Pending Approvals', '${_stats['pendingLeaves']}', Icons.access_time_rounded, const Color(0xFF0891B2), const Color(0xFFCFFAFE), '-25%', false, isDown: true, cardBgColor, glass),
            ],
          ),
          const SizedBox(height: 14),

          // 4. ORGANIZATION & DATE FILTERS ROW
          _buildFilterBar(glass, cardBgColor),
          const SizedBox(height: 14),

          // 5. FOUR CATEGORY TAB CHIPS
          _buildCategoryTabBar(glass),
          const SizedBox(height: 16),

          // 6. CATEGORY TAB VIEW CONTENTS
          if (_selectedCategoryTab == 0) ...[
            // TAB 1 – OVERVIEW
            _buildOverviewTabContent(glass, cardBgColor),
          ] else if (_selectedCategoryTab == 1) ...[
            // TAB 2 – WORKFORCE
            _buildWorkforceTabContent(glass, cardBgColor),
          ] else if (_selectedCategoryTab == 2) ...[
            // TAB 3 – OPERATIONS
            _buildOperationsTabContent(glass, cardBgColor),
          ] else ...[
            // TAB 4 – INSIGHTS & APPROVALS
            _buildInsightsApprovalsTabContent(glass, cardBgColor),
          ],
        ],
      ),
    );
  }

  /// Status Pill matching Employee Dashboard
  Widget _statusPill({
    required IconData icon,
    required String label,
    required Color color,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color iconColor, Color iconBg, String trendText, bool isUp, Color cardBgColor, GlassTheme glass, {bool isDown = false}) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: iconColor, size: 17),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Text(value, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: glass.textPrimary, height: 1.1)),
                    if (trendText.isNotEmpty) ...[
                      const SizedBox(width: 4),
                      Icon(isDown ? Icons.arrow_downward : Icons.arrow_upward, size: 10, color: isDown ? const Color(0xFFDC2626) : const Color(0xFF16A34A)),
                      Text(trendText, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: isDown ? const Color(0xFFDC2626) : const Color(0xFF16A34A))),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(title, style: TextStyle(fontSize: 10.5, color: glass.textSecondary, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Filter Bar with Date Range and Department selector dropdowns
  Widget _buildFilterBar(GlassTheme glass, Color cardBgColor) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: cardBgColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: glass.cardBorder),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today_rounded, size: 14, color: Color(0xFF0F6B66)),
                const SizedBox(width: 6),
                DropdownButton<String>(
                  value: _selectedDateFilter,
                  isDense: true,
                  underline: const SizedBox.shrink(),
                  dropdownColor: cardBgColor,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: glass.textPrimary),
                  items: const [
                    DropdownMenuItem(value: 'Today', child: Text('Today')),
                    DropdownMenuItem(value: 'This Week', child: Text('This Week')),
                    DropdownMenuItem(value: 'This Month', child: Text('This Month')),
                    DropdownMenuItem(value: 'This Year', child: Text('This Year')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedDateFilter = val);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: cardBgColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: glass.cardBorder),
            ),
            child: Row(
              children: [
                const Icon(Icons.business_rounded, size: 14, color: Color(0xFF0F6B66)),
                const SizedBox(width: 6),
                DropdownButton<String>(
                  value: _selectedDeptFilter,
                  isDense: true,
                  underline: const SizedBox.shrink(),
                  dropdownColor: cardBgColor,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: glass.textPrimary),
                  items: const [
                    DropdownMenuItem(value: 'All Departments', child: Text('All Departments')),
                    DropdownMenuItem(value: 'Engineering', child: Text('Engineering')),
                    DropdownMenuItem(value: 'Sales', child: Text('Sales')),
                    DropdownMenuItem(value: 'Finance', child: Text('Finance')),
                    DropdownMenuItem(value: 'Human Resources', child: Text('Human Resources')),
                    DropdownMenuItem(value: 'Marketing', child: Text('Marketing')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedDeptFilter = val);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Four Main Category Segmented Tab Bar
  Widget _buildCategoryTabBar(GlassTheme glass) {
    final tabs = [
      {'title': 'Overview', 'icon': Icons.space_dashboard_rounded},
      {'title': 'Workforce', 'icon': Icons.groups_rounded},
      {'title': 'Operations', 'icon': Icons.tune_rounded},
      {'title': 'Insights & Approvals', 'icon': Icons.insights_rounded},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: List.generate(tabs.length, (idx) {
          final isSelected = _selectedCategoryTab == idx;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              avatar: Icon(tabs[idx]['icon'] as IconData, size: 15, color: isSelected ? Colors.white : const Color(0xFF0F6B66)),
              label: Text(
                tabs[idx]['title'] as String,
                style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.w600, color: isSelected ? Colors.white : glass.textPrimary),
              ),
              selected: isSelected,
              selectedColor: const Color(0xFF0F6B66),
              backgroundColor: const Color(0xFF0F6B66).withOpacity(0.1),
              onSelected: (_) => setState(() => _selectedCategoryTab = idx),
            ),
          );
        }),
      ),
    );
  }

  /// TAB 1: OVERVIEW CONTENT
  Widget _buildOverviewTabContent(GlassTheme glass, Color cardBgColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quick Actions', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: glass.textPrimary)),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              _buildQuickPill('Add Employee', Icons.person_add_alt_1_rounded, () {
                if (widget.onNavigateTab != null) widget.onNavigateTab!(1);
              }),
              const SizedBox(width: 8),
              _buildQuickPill('Approve Leave', Icons.check_circle_outline_rounded, () {
                if (widget.onNavigateTab != null) widget.onNavigateTab!(0);
              }),
              const SizedBox(width: 8),
              _buildQuickPill('Run Payroll', Icons.request_quote_rounded, () {
                if (widget.onNavigateTab != null) widget.onNavigateTab!(3);
              }),
              const SizedBox(width: 8),
              _buildQuickPill('Announcements', Icons.campaign_outlined, () {
                if (widget.onNavigateTab != null) widget.onNavigateTab!(2);
              }),
              const SizedBox(width: 8),
              _buildQuickPill('Run Reports', Icons.bar_chart_rounded, () {}),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Today's Attendance Panel
        _buildAttendancePanel(glass, cardBgColor),
        const SizedBox(height: 14),

        // Pending Leave Requests Panel
        _buildPendingLeavePanel(glass, cardBgColor),
        const SizedBox(height: 14),

        // Announcements Noticeboard Panel
        _buildAnnouncementsPanel(glass, cardBgColor),
      ],
    );
  }

  /// TAB 2: WORKFORCE CONTENT
  Widget _buildWorkforceTabContent(GlassTheme glass, Color cardBgColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildAttendancePanel(glass, cardBgColor),
        const SizedBox(height: 16),
        _buildDeptDistributionPanel(glass, cardBgColor),
        const SizedBox(height: 16),
        _buildBirthdaysPanel(glass, cardBgColor),
      ],
    );
  }

  /// TAB 3: OPERATIONS CONTENT
  Widget _buildOperationsTabContent(GlassTheme glass, Color cardBgColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildRecruitmentStatusPanel(glass, cardBgColor),
        const SizedBox(height: 16),
        _buildPayrollSummaryPanel(glass, cardBgColor),
        const SizedBox(height: 16),
        _buildMeetingsPanel(glass, cardBgColor),
        const SizedBox(height: 16),
        _buildAnnouncementsPanel(glass, cardBgColor),
      ],
    );
  }

  /// TAB 4: INSIGHTS & APPROVALS CONTENT
  Widget _buildInsightsApprovalsTabContent(GlassTheme glass, Color cardBgColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPendingLeavePanel(glass, cardBgColor),
        const SizedBox(height: 16),
        _buildDeptDistributionPanel(glass, cardBgColor),
        const SizedBox(height: 16),
        _buildMeetingsPanel(glass, cardBgColor),
      ],
    );
  }

  Widget _buildQuickPill(String label, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: const [BoxShadow(color: Color.fromRGBO(15, 107, 102, 0.08), blurRadius: 8, offset: Offset(0, 2))],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: const Color(0xFF0F6B66)),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingLeavePanel(GlassTheme glass, Color cardBgColor) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(color: const Color(0xFFFFEDD5), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.calendar_today_rounded, color: Color(0xFFEA580C), size: 18),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Pending Leave Requests', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: glass.textPrimary)),
                      Text('Requires your approval', style: TextStyle(fontSize: 11, color: glass.textSecondary)),
                    ],
                  ),
                ],
              ),
              const Text('View All', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F6B66))),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 8),
          if (_pendingLeaves.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Center(child: Text('No pending leave requests requiring approval', style: TextStyle(fontSize: 12, color: glass.textSecondary))),
            )
          else
            ..._pendingLeaves.map((req) {
              final isProcessing = _processingLeaveIds.contains(req['id']?.toString());
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: const Color(0xFFD1FAE5),
                      child: Text(req['initials'] ?? 'RT', style: const TextStyle(color: Color(0xFF0F6B66), fontWeight: FontWeight.bold, fontSize: 11)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(req['employee'] ?? req['name'] ?? '', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: glass.textPrimary)),
                          Text(req['leaveType'] ?? '', style: TextStyle(fontSize: 11, color: glass.textSecondary)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(req['days'] ?? '', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: glass.textPrimary)),
                        Text(req['dateRange'] ?? '', style: TextStyle(fontSize: 10, color: glass.textSecondary)),
                      ],
                    ),
                    const SizedBox(width: 8),
                    if (isProcessing)
                      const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    else
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, size: 18, color: Color(0xFF94A3B8)),
                        onSelected: (val) {
                          if (val == 'approve') _approveLeaveRequest(req);
                          if (val == 'reject') _rejectLeaveRequest(req);
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(value: 'approve', child: Text('Approve')),
                          const PopupMenuItem(value: 'reject', child: Text('Reject')),
                        ],
                      ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildDeptDistributionPanel(GlassTheme glass, Color cardBgColor) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.pie_chart_rounded, color: Color(0xFF2563EB), size: 18),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Department Distribution', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: glass.textPrimary)),
                      Text('Employee headcount by department', style: TextStyle(fontSize: 10.5, color: glass.textSecondary)),
                    ],
                  ),
                ],
              ),
              const Text('View Details', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F6B66))),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 12),
          if (_deptDistribution.isEmpty)
            Center(child: Padding(padding: const EdgeInsets.all(20), child: Text('No department distribution data available', style: TextStyle(fontSize: 12, color: glass.textSecondary))))
          else
            Row(
              children: [
                SizedBox(
                  width: 120,
                  height: 120,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 36,
                      sections: _deptDistribution.map((item) {
                        final cnt = (item['count'] as num?)?.toDouble() ?? 0.0;
                        final color = item['color'] as Color? ?? const Color(0xFF3B82F6);
                        return PieChartSectionData(
                          color: color,
                          value: cnt > 0 ? cnt : 0.1,
                          radius: 16,
                          showTitle: false,
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    children: _deptDistribution.map((item) {
                      final name = item['name']?.toString() ?? '';
                      final count = item['count'] ?? 0;
                      final pct = item['pct'] ?? 0;
                      final color = item['color'] as Color? ?? const Color(0xFF3B82F6);
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                                const SizedBox(width: 6),
                                Text(name, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: glass.textPrimary)),
                              ],
                            ),
                            Text('$count ($pct%)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: glass.textPrimary)),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildAnnouncementsPanel(GlassTheme glass, Color cardBgColor) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(color: const Color(0xFFFFEDD5), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.campaign_outlined, color: Color(0xFFEA580C), size: 18),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Announcements', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: glass.textPrimary)),
                      Text('Company notices & updates', style: TextStyle(fontSize: 10.5, color: glass.textSecondary)),
                    ],
                  ),
                ],
              ),
              const Text('View All', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F6B66))),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 8),
          if (_announcements.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Center(child: Text('No announcements posted yet', style: TextStyle(fontSize: 12, color: glass.textSecondary))),
            )
          else
            ..._announcements.map((anc) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(color: const Color(0xFFFFEDD5), borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.campaign, color: Color(0xFFEA580C), size: 16),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(anc['title'] ?? '', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: glass.textPrimary)),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                  decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(6)),
                                  child: const Text('PINNED', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Color(0xFF4338CA))),
                                ),
                              ],
                            ),
                            const SizedBox(height: 1),
                            Text('Company notice & updates', style: TextStyle(fontSize: 10.5, color: glass.textSecondary)),
                          ],
                        ),
                      ),
                      Text(anc['time'] ?? '', style: TextStyle(fontSize: 10, color: glass.textSecondary)),
                    ],
                  ),
                )),
        ],
      ),
    );
  }

  Widget _buildBirthdaysPanel(GlassTheme glass, Color cardBgColor) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(color: const Color(0xFFFCE7F3), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.cake_rounded, color: Color(0xFFDB2777), size: 18),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Upcoming Birthdays', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: glass.textPrimary)),
                      Text("Let's celebrate together!", style: TextStyle(fontSize: 10.5, color: glass.textSecondary)),
                    ],
                  ),
                ],
              ),
              const Text('View All', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F6B66))),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 10),
          if (_upcomingBirthdays.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Center(child: Text('No upcoming birthdays in the next 30 days', style: TextStyle(fontSize: 12, color: glass.textSecondary))),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: _upcomingBirthdays.map((b) => Padding(
                      padding: const EdgeInsets.only(right: 14),
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: const Color(0xFFD1FAE5),
                            child: Text(b['initials'] ?? 'EM', style: const TextStyle(color: Color(0xFF0F6B66), fontWeight: FontWeight.bold, fontSize: 13)),
                          ),
                          const SizedBox(height: 4),
                          Text(b['name'] ?? '', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: glass.textPrimary)),
                          Text(b['formattedDate'] ?? '', style: TextStyle(fontSize: 9.5, color: glass.textSecondary)),
                        ],
                      ),
                    )).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMeetingsPanel(GlassTheme glass, Color cardBgColor) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.video_call_rounded, color: Color(0xFF2563EB), size: 18),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Upcoming Meetings', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: glass.textPrimary)),
                      Text('Scheduled video calls & meetings', style: TextStyle(fontSize: 10.5, color: glass.textSecondary)),
                    ],
                  ),
                ],
              ),
              const Text('View All', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F6B66))),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 8),
          if (_upcomingMeetings.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Center(child: Text('No upcoming meetings scheduled', style: TextStyle(fontSize: 12, color: glass.textSecondary))),
            )
          else
            ..._upcomingMeetings.map((m) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFF60A5FA), Color(0xFF3B82F6)]),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(m['day'] ?? '1', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white, height: 1)),
                            Text(m['month'] ?? 'NOV', style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(m['title'] ?? '', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: glass.textPrimary)),
                            Text(m['time'] ?? '', style: TextStyle(fontSize: 10.5, color: glass.textSecondary)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.video_camera_front, size: 11, color: Color(0xFF2563EB)),
                            SizedBox(width: 3),
                            Text('LiveKit Room', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                          ],
                        ),
                      ),
                    ],
                  ),
                )),
        ],
      ),
    );
  }

  Widget _buildAttendancePanel(GlassTheme glass, Color cardBgColor) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(color: const Color(0xFFE0EDFF), borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.calendar_month_rounded, color: Color(0xFF2563EB), size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Today’s Attendance", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: glass.textPrimary), overflow: TextOverflow.ellipsis),
                          Text('Overview of attendance today', style: TextStyle(fontSize: 10.5, color: glass.textSecondary), overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('View All', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F6B66))),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(12)),
                    child: const Text('Live', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF16A34A))),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 12),
          Row(
            children: [
              SizedBox(
                width: 120,
                height: 120,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 36,
                        sections: [
                          PieChartSectionData(color: const Color(0xFF16A34A), value: (_attendanceStats['present'] as num).toDouble(), radius: 16, showTitle: false),
                          PieChartSectionData(color: const Color(0xFFEF4444), value: (_attendanceStats['absent'] as num).toDouble(), radius: 16, showTitle: false),
                          PieChartSectionData(color: const Color(0xFF2563EB), value: (_attendanceStats['wfh'] as num).toDouble(), radius: 16, showTitle: false),
                          PieChartSectionData(color: const Color(0xFFF59E0B), value: (_attendanceStats['late'] as num).toDouble(), radius: 16, showTitle: false),
                        ],
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Total Employees', style: TextStyle(fontSize: 8, color: glass.textSecondary, fontWeight: FontWeight.bold)),
                        Text('${_attendanceStats['total']}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: glass.textPrimary)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  children: [
                    _buildAttRow('Present', '${_attendanceStats['present']}', '${_attendanceStats['presentPct']}%', const Color(0xFF16A34A), const Color(0xFFDCFCE7), Icons.groups),
                    const SizedBox(height: 6),
                    _buildAttRow('Absent', '${_attendanceStats['absent']}', '${_attendanceStats['absentPct']}%', const Color(0xFFDC2626), const Color(0xFFFEE2E2), Icons.person_off),
                    const SizedBox(height: 6),
                    _buildAttRow('Work From Home', '${_attendanceStats['wfh']}', '${_attendanceStats['wfhPct']}%', const Color(0xFF2563EB), const Color(0xFFDBEAFE), Icons.home),
                    const SizedBox(height: 6),
                    _buildAttRow('Late Arrivals', '${_attendanceStats['late']}', '${_attendanceStats['latePct']}%', const Color(0xFFD97706), const Color(0xFFFEF3C7), Icons.access_time),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAttRow(String title, String count, String pct, Color color, Color bg, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  Text(pct, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: color)),
                ],
              ),
            ],
          ),
          Text(count, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }

  Widget _buildRecruitmentStatusPanel(GlassTheme glass, Color cardBgColor) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(color: const Color(0xFFF3E8FF), borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.person_add_rounded, color: Color(0xFF9333EA), size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Recruitment Status', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: glass.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                          Text('Current hiring pipeline', style: TextStyle(fontSize: 10.5, color: glass.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const Text('Manage →', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F6B66))),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 12),
          _buildMetricRow('Open Positions', '${_stats['openPositions']}', Icons.work_outline, const Color(0xFF2563EB), const Color(0xFFE0EDFF)),
          const SizedBox(height: 10),
          _buildMetricRow('Candidates', '${_stats['candidatesInPipeline']}', Icons.groups_outlined, const Color(0xFF9333EA), const Color(0xFFF3E8FF)),
          const SizedBox(height: 10),
          _buildMetricRow('Hired This Month', '${_stats['hiredThisMonth']}', Icons.verified_user_outlined, const Color(0xFF16A34A), const Color(0xFFDCFCE7)),
        ],
      ),
    );
  }

  Widget _buildPayrollSummaryPanel(GlassTheme glass, Color cardBgColor) {
    final netPay = _stats['monthlyPayrollNet'] ?? 0.0;
    final formattedNetPay = netPay is num ? '₹${netPay.toStringAsFixed(0)}' : '₹0';
    final processed = _stats['payrollProcessedThisMonth'] ?? 0;

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.request_quote_rounded, color: Color(0xFF16A34A), size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Payroll Summary', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: glass.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                          Text('Latest payment disbursement details', style: TextStyle(fontSize: 10.5, color: glass.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const Text('Manage Payroll →', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F6B66))),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 12),
          _buildMetricRow('Net Pay this Month', formattedNetPay, Icons.account_balance_wallet_outlined, const Color(0xFF16A34A), const Color(0xFFDCFCE7)),
          const SizedBox(height: 10),
          _buildMetricRow('Records Processed', '$processed', Icons.description_outlined, const Color(0xFF2563EB), const Color(0xFFE0EDFF)),
        ],
      ),
    );
  }

  Widget _buildMetricRow(String title, String value, IconData icon, Color iconColor, Color iconBg) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: iconColor, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
          ),
          Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: iconColor)),
        ],
      ),
    );
  }
}
