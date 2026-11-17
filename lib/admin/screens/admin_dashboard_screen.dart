import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/api/leave_service.dart';
import '../../core/api/payroll_service.dart';
import '../../core/api/recruitment_service.dart';
import '../../core/auth/auth_service.dart';
import '../../core/models/user_model.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme_tokens.dart';
import '../../core/theme/glass_theme.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../widgets/admin_dashboard_widgets.dart';

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
  final ScrollController _categoryTabScrollController = ScrollController();

  // Global Dashboard Filters
  String _selectedDateFilter = 'This Month';
  String _selectedDeptFilter = 'All Departments';

  // Key KPI Statistics (Clean 0 initial values, populated purely from real backend APIs)
  final Map<String, dynamic> _stats = {
    'totalEmployees': 0,
    'activeEmployees': 0,
    'departments': 0,
    'branches': 0,
    'onLeaveToday': 0,
    'pendingLeaves': 0,
    'openPositions': 0,
    'candidatesInPipeline': 0,
    'hiredThisMonth': 0,
    'monthlyPayrollNet': 0.0,
    'payrollProcessedThisMonth': 0,
  };

  // Department Distribution (Categorical Palette with NO RED)
  List<Map<String, dynamic>> _deptDistribution = [];
  int _deptTotalCount = 0;

  // Upcoming Birthdays
  List<Map<String, dynamic>> _upcomingBirthdays = [];

  // Announcements
  List<Map<String, dynamic>> _announcements = [];

  // Upcoming Meetings
  List<Map<String, dynamic>> _upcomingMeetings = [];

  // Today's Attendance Summary
  Map<String, dynamic> _attendanceStats = {
    'total': 0,
    'present': 0,
    'presentPct': 0,
    'absent': 0,
    'absentPct': 0,
    'wfh': 0,
    'wfhPct': 0,
    'late': 0,
    'latePct': 0,
  };

  // Pending Leave Requests
  List<Map<String, dynamic>> _pendingLeaves = [];

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

  @override
  void dispose() {
    _categoryTabScrollController.dispose();
    super.dispose();
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
      // 1. Fetch Overall Reports / Dashboard Stats
      try {
        final statsRes = await apiClient.get(ApiEndpoints.reportsDashboardStats).timeout(const Duration(seconds: 5));
        if (mounted && currentReq == _requestId) {
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
            if (rawStats['monthlyPayrollNet'] != null) _stats['monthlyPayrollNet'] = (rawStats['monthlyPayrollNet'] as num).toDouble();
            if (rawStats['payrollProcessedThisMonth'] != null) _stats['payrollProcessedThisMonth'] = rawStats['payrollProcessedThisMonth'];
          }
        }
      } catch (e) {
        debugPrint('[AdminDashboard] Stats fetch note: $e');
      }

      // 2. Fetch All Employees (Real backend employee list & department breakdown)
      List<dynamic> rawEmpsList = [];
      try {
        final empRes = await apiClient.get(ApiEndpoints.employeesAll).timeout(const Duration(seconds: 5));
        if (mounted && currentReq == _requestId) {
          dynamic rawEmps = empRes is Map<String, dynamic> && empRes.containsKey('data') ? empRes['data'] : empRes;
          if (rawEmps is List) {
            rawEmpsList = rawEmps;
            _stats['totalEmployees'] = rawEmps.length;
            _stats['activeEmployees'] = rawEmps.where((e) {
              if (e is! Map<String, dynamic>) return false;
              final st = (e['status'] ?? e['employmentStatus'] ?? '').toString().toUpperCase();
              final isAct = e['isActive'];
              return st == 'ACTIVE' || isAct == true;
            }).length;
          }
        }
      } catch (e) {
        debugPrint('[AdminDashboard] Employees fetch note: $e');
      }

      // 3. Fetch Departments Count
      try {
        final deptCountRes = await apiClient.get(ApiEndpoints.departments).timeout(const Duration(seconds: 5));
        if (mounted && currentReq == _requestId) {
          dynamic rawDeptList = deptCountRes is Map<String, dynamic> && deptCountRes.containsKey('data') ? deptCountRes['data'] : deptCountRes;
          if (rawDeptList is List) {
            _stats['departments'] = rawDeptList.length;
          }
        }
      } catch (_) {}

      // 4. Fetch Branches & Teams Count
      try {
        final branchRes = await apiClient.get(ApiEndpoints.branches).timeout(const Duration(seconds: 5));
        final teamRes = await apiClient.get(ApiEndpoints.teams).timeout(const Duration(seconds: 5));
        if (mounted && currentReq == _requestId) {
          dynamic rawBranches = branchRes is Map<String, dynamic> && branchRes.containsKey('data') ? branchRes['data'] : branchRes;
          dynamic rawTeams = teamRes is Map<String, dynamic> && teamRes.containsKey('data') ? teamRes['data'] : teamRes;
          int branchCount = rawBranches is List ? rawBranches.length : 0;
          int teamCount = rawTeams is List ? rawTeams.length : 0;
          _stats['branches'] = branchCount + teamCount;
        }
      } catch (_) {}

      // 5. Fetch Department Distribution (Categorical Palette with NO RED)
      try {
        final deptRes = await apiClient.get(ApiEndpoints.dashboardDepartmentDistribution).timeout(const Duration(seconds: 5));
        if (mounted && currentReq == _requestId) {
          dynamic rawDept = deptRes is Map<String, dynamic> && deptRes.containsKey('data') ? deptRes['data'] : deptRes;

          List<Map<String, dynamic>> distList = [];
          int sumTotal = 0;

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
                  'color': AppThemeTokens.departmentColors[i % AppThemeTokens.departmentColors.length],
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
                  'color': AppThemeTokens.departmentColors[i % AppThemeTokens.departmentColors.length],
                });
                i++;
              }
            }
          }

          // If distribution endpoint was empty, compute dynamically from employee list
          if (distList.isEmpty && rawEmpsList.isNotEmpty) {
            Map<String, int> deptCounts = {};
            for (final e in rawEmpsList) {
              if (e is Map<String, dynamic>) {
                final dName = (e['department'] ?? e['departmentName'] ?? 'General').toString();
                deptCounts[dName] = (deptCounts[dName] ?? 0) + 1;
              }
            }
            int idx = 0;
            int total = rawEmpsList.length;
            deptCounts.forEach((dept, count) {
              distList.add({
                'name': dept,
                'count': count,
                'pct': total > 0 ? ((count / total) * 100).round() : 0,
                'color': AppThemeTokens.departmentColors[idx % AppThemeTokens.departmentColors.length],
              });
              idx++;
            });
            sumTotal = total;
          }

          if (distList.isNotEmpty) {
            final total = sumTotal > 0 ? sumTotal : (_stats['totalEmployees'] as int? ?? 0);
            for (var d in distList) {
              final c = d['count'] as int;
              d['pct'] = total > 0 ? ((c / total) * 100).round() : 0;
            }
            _deptDistribution = distList;
            _deptTotalCount = total;
          } else {
            _deptDistribution = [];
            _deptTotalCount = 0;
          }
        }
      } catch (e) {
        debugPrint('[AdminDashboard] Department distribution note: $e');
      }

      // 6. Fetch Recruitment Data (Open Positions & Candidates)
      try {
        final recruitmentService = ref.read(recruitmentServiceProvider);
        final jobsRes = await recruitmentService.getJobs().timeout(const Duration(seconds: 5));
        final candidatesRes = await recruitmentService.getCandidates().timeout(const Duration(seconds: 5));
        if (mounted && currentReq == _requestId) {
          dynamic rawJobs = jobsRes is Map<String, dynamic> && jobsRes.containsKey('data') ? jobsRes['data'] : jobsRes;
          dynamic rawCandidates = candidatesRes is Map<String, dynamic> && candidatesRes.containsKey('data') ? candidatesRes['data'] : candidatesRes;
          if (rawJobs is List) {
            _stats['openPositions'] = rawJobs.where((j) {
              if (j is! Map<String, dynamic>) return false;
              final st = (j['status'] ?? '').toString().toUpperCase();
              return st == 'OPEN' || st == 'ACTIVE' || st == 'PUBLISHED';
            }).length;
          }
          if (rawCandidates is List) {
            _stats['candidatesInPipeline'] = rawCandidates.length;
            final now = DateTime.now();
            _stats['hiredThisMonth'] = rawCandidates.where((c) {
              if (c is! Map<String, dynamic>) return false;
              final st = (c['status'] ?? '').toString().toUpperCase();
              final hiredAt = c['hiredAt'] ?? c['updatedAt'];
              if (st == 'HIRED' && hiredAt != null) {
                try {
                  final dt = DateTime.parse(hiredAt.toString());
                  return dt.month == now.month && dt.year == now.year;
                } catch (_) {}
              }
              return st == 'HIRED';
            }).length;
          }
        }
      } catch (e) {
        debugPrint('[AdminDashboard] Recruitment fetch note: $e');
      }

      // 7. Fetch Payroll Summary
      try {
        final payrollService = ref.read(payrollServiceProvider);
        final payrollRes = await payrollService.getPayrollRecords().timeout(const Duration(seconds: 5));
        if (mounted && currentReq == _requestId) {
          dynamic rawPayroll = payrollRes is Map<String, dynamic> && payrollRes.containsKey('data') ? payrollRes['data'] : payrollRes;
          if (rawPayroll is List) {
            double totalNet = 0.0;
            int count = 0;
            for (final p in rawPayroll) {
              if (p is Map<String, dynamic>) {
                final net = (p['netPay'] ?? p['totalNet'] ?? p['netSalary'] ?? 0).toDouble();
                totalNet += net;
                count++;
              }
            }
            _stats['monthlyPayrollNet'] = totalNet;
            _stats['payrollProcessedThisMonth'] = count;
          }
        }
      } catch (e) {
        debugPrint('[AdminDashboard] Payroll fetch note: $e');
      }

      // 8. Fetch Pending Leaves
      try {
        final leaveService = ref.read(leaveServiceProvider);
        final leaveRes = await leaveService.getPendingLeaves().timeout(const Duration(seconds: 5));
        if (mounted && currentReq == _requestId) {
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
          } else {
            _pendingLeaves = [];
            _stats['pendingLeaves'] = 0;
          }
        }
      } catch (e) {
        debugPrint('[AdminDashboard] Pending leaves fetch note: $e');
      }

      // 9. Fetch Announcements
      try {
        final ancRes = await apiClient.get(ApiEndpoints.announcements).timeout(const Duration(seconds: 5));
        if (mounted && currentReq == _requestId) {
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
          } else {
            _announcements = [];
          }
        }
      } catch (e) {
        debugPrint('[AdminDashboard] Announcements fetch note: $e');
      }

      // 10. Fetch Upcoming Birthdays
      try {
        final bdayRes = await apiClient.get(ApiEndpoints.dashboardUpcomingBirthdays).timeout(const Duration(seconds: 5));
        if (mounted && currentReq == _requestId) {
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
            _upcomingBirthdays = bdayList;
          } else {
            _upcomingBirthdays = [];
          }
        }
      } catch (e) {
        debugPrint('[AdminDashboard] Birthdays fetch note: $e');
      }

      // 11. Fetch Upcoming Meetings
      try {
        final mtgRes = await apiClient.get(ApiEndpoints.meetingsUpcoming).timeout(const Duration(seconds: 5));
        if (mounted && currentReq == _requestId) {
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
          } else {
            _upcomingMeetings = [];
          }
        }
      } catch (e) {
        debugPrint('[AdminDashboard] Meetings fetch note: $e');
      }

      // 12. Today's Attendance
      try {
        final todayStr = DateTime.now().toIso8601String().substring(0, 10);
        final attRes = await apiClient.get('${ApiEndpoints.attendanceRecords}?date=$todayStr').timeout(const Duration(seconds: 5));
        if (mounted && currentReq == _requestId) {
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
            final totalEmp = (_stats['totalEmployees'] as int? ?? 0);
            final recorded = present + absent + wfh + late;
            final total = totalEmp > 0 ? totalEmp : (recorded > 0 ? recorded : 0);
            if (recorded == 0 && total > 0) {
              absent = total;
            }
            _attendanceStats = {
              'total': total,
              'present': present,
              'presentPct': total > 0 ? ((present / total) * 100).round() : 0,
              'absent': absent,
              'absentPct': total > 0 ? ((absent / total) * 100).round() : 0,
              'wfh': wfh,
              'wfhPct': total > 0 ? ((wfh / total) * 100).round() : 0,
              'late': late,
              'latePct': total > 0 ? ((late / total) * 100).round() : 0,
            };
          } else {
            final totalEmp = (_stats['totalEmployees'] as int? ?? 0);
            _attendanceStats = {
              'total': totalEmp,
              'present': 0,
              'presentPct': 0,
              'absent': totalEmp,
              'absentPct': totalEmp > 0 ? 100 : 0,
              'wfh': 0,
              'wfhPct': 0,
              'late': 0,
              'latePct': 0,
            };
          }
        }
      } catch (e) {
        debugPrint('[AdminDashboard] Attendance fetch note: $e');
      }

      if (mounted && currentReq == _requestId) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted && currentReq == _requestId) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _approveLeaveRequest(Map<String, dynamic> req) async {
    final leaveId = req['id'];
    if (leaveId == null || leaveId.toString().isEmpty) return;

    if (_processingLeaveIds.contains(leaveId)) return;
    setState(() => _processingLeaveIds.add(leaveId.toString()));

    final leaveService = ref.read(leaveServiceProvider);
    try {
      await leaveService.approveOrRejectLeave(leaveId.toString(), {
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

    final leaveService = ref.read(leaveServiceProvider);
    try {
      await leaveService.approveOrRejectLeave(leaveId.toString(), {
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

  void _scrollToTab(int idx) {
    setState(() => _selectedCategoryTab = idx);
    if (_categoryTabScrollController.hasClients) {
      _categoryTabScrollController.animateTo(
        idx * 110.0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBgColor = isDark ? AppColors.darkMainSurface : Colors.white;

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
        : 'Admin User';

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
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(48.0),
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    // Bottom padding equal to floating nav height (85px) + 16px safe margin = 101px
    final bottomNavInset = 101.0;

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      slivers: [
        // 1. TOP HEADER & HERO BANNER & KPI GRID
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppThemeTokens.space16,
            AppThemeTokens.space12,
            AppThemeTokens.space16,
            AppThemeTokens.space12,
          ),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Greeting & Date Header
                Text(
                  _greeting(userName),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _dateLabel(DateTime.now()),
                  style: AppThemeTokens.cardSubtitle(isDark),
                ),
                const SizedBox(height: AppThemeTokens.space12),

                // Compact Hero Gradient Banner
                _buildCompactHeroBanner(isDark),
                const SizedBox(height: AppThemeTokens.space12),

                // 6 Compact KPI Stat Cards Grid (3 Columns x 2 Rows)
                GridView.count(
                  crossAxisCount: MediaQuery.of(context).size.width > 900 ? 6 : 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: MediaQuery.of(context).size.width > 900 ? 2.4 : 1.35,
                  children: [
                    StatCard(
                      title: 'Total Employees',
                      value: '${_stats['totalEmployees']}',
                      icon: Icons.groups_rounded,
                      iconColor: const Color(0xFF2563EB),
                      iconBg: const Color(0xFFE0EDFF),
                      trendText: '+12%',
                      isUp: true,
                      cardBgColor: cardBgColor,
                    ),
                    StatCard(
                      title: 'Active Employees',
                      value: '${_stats['activeEmployees']}',
                      icon: Icons.check_circle_outline_rounded,
                      iconColor: const Color(0xFF16A34A),
                      iconBg: const Color(0xFFDCFCE7),
                      trendText: '+8%',
                      isUp: true,
                      cardBgColor: cardBgColor,
                    ),
                    StatCard(
                      title: 'Departments',
                      value: '${_stats['departments']}',
                      icon: Icons.business_rounded,
                      iconColor: const Color(0xFF2563EB),
                      iconBg: const Color(0xFFEFF6FF),
                      trendText: '0%',
                      isUp: true,
                      cardBgColor: cardBgColor,
                    ),
                    StatCard(
                      title: 'Branches / Teams',
                      value: '${_stats['branches']}',
                      icon: Icons.people_alt_rounded,
                      iconColor: const Color(0xFFEA580C),
                      iconBg: const Color(0xFFFFEDD5),
                      trendText: '+9%',
                      isUp: true,
                      cardBgColor: cardBgColor,
                    ),
                    StatCard(
                      title: 'On Leave Today',
                      value: '${_stats['onLeaveToday']}',
                      icon: Icons.calendar_today_rounded,
                      iconColor: const Color(0xFFDC2626),
                      iconBg: const Color(0xFFFEE2E2),
                      trendText: '+20%',
                      isUp: true,
                      cardBgColor: cardBgColor,
                    ),
                    StatCard(
                      title: 'Pending Approvals',
                      value: '${_stats['pendingLeaves']}',
                      icon: Icons.access_time_rounded,
                      iconColor: const Color(0xFF0891B2),
                      iconBg: const Color(0xFFCFFAFE),
                      trendText: '-25%',
                      isDown: true,
                      cardBgColor: cardBgColor,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // 2. PINNED STICKY HEADER FOR FILTERS & CATEGORY TAB BAR
        SliverPersistentHeader(
          pinned: true,
          delegate: _StickyHeaderDelegate(
            height: 98.0,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Filter Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppThemeTokens.space16),
                  child: _buildFilterBar(glass, cardBgColor),
                ),
                const SizedBox(height: 8),

                // Category Tabs Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppThemeTokens.space16),
                  child: _buildCategoryTabBar(glass, isDark),
                ),
              ],
            ),
          ),
        ),

        // 3. TAB CONTENT SLIVER
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            AppThemeTokens.space16,
            AppThemeTokens.space12,
            AppThemeTokens.space16,
            bottomNavInset,
          ),
          sliver: SliverToBoxAdapter(
            child: FadeSlideEntrance(
              key: ValueKey<int>(_selectedCategoryTab),
              child: _buildSelectedTabContent(glass, cardBgColor),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedTabContent(GlassTheme glass, Color cardBgColor) {
    if (_selectedCategoryTab == 0) {
      return _buildOverviewTabContent(glass, cardBgColor);
    } else if (_selectedCategoryTab == 1) {
      return _buildWorkforceTabContent(glass, cardBgColor);
    } else if (_selectedCategoryTab == 2) {
      return _buildOperationsTabContent(glass, cardBgColor);
    } else {
      return _buildInsightsApprovalsTabContent(glass, cardBgColor);
    }
  }

  /// Compact Hero Gradient Banner with exact same text & "Manage" action
  Widget _buildCompactHeroBanner(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F6B66), Color(0xFF054F4B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppThemeTokens.radiusBanner),
        boxShadow: const [
          BoxShadow(
            color: Color(0x330F6B66),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.admin_panel_settings_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: AppThemeTokens.space12),
          Expanded(
            child: Text(
              'Stay in control, manage efficiently, and keep operations running smoothly.',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
                height: 1.3,
              ),
            ),
          ),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            child: ElevatedButton(
              onPressed: () {
                if (widget.onNavigateTab != null) widget.onNavigateTab!(1);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF0F6B66),
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Manage', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                  SizedBox(width: 2),
                  Icon(Icons.chevron_right_rounded, size: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Filter Bar with Date Range and Department selector dropdowns
  Widget _buildFilterBar(GlassTheme glass, Color cardBgColor) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final border = BorderSide(color: isDark ? AppColors.darkBordersAndDividers : const Color(0xFFE5E7EB));

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              color: cardBgColor,
              borderRadius: BorderRadius.circular(AppThemeTokens.radiusTile),
              border: Border.fromBorderSide(border),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.primary),
                const SizedBox(width: 6),
                DropdownButton<String>(
                  value: _selectedDateFilter,
                  isDense: true,
                  underline: const SizedBox.shrink(),
                  dropdownColor: cardBgColor,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: glass.textPrimary),
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
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              color: cardBgColor,
              borderRadius: BorderRadius.circular(AppThemeTokens.radiusTile),
              border: Border.fromBorderSide(border),
            ),
            child: Row(
              children: [
                const Icon(Icons.business_rounded, size: 14, color: AppColors.primary),
                const SizedBox(width: 6),
                DropdownButton<String>(
                  value: _selectedDeptFilter,
                  isDense: true,
                  underline: const SizedBox.shrink(),
                  dropdownColor: cardBgColor,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: glass.textPrimary),
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

  /// Four Main Category Segmented Tab Bar with right-edge fade and subtle 1px borders
  Widget _buildCategoryTabBar(GlassTheme glass, bool isDark) {
    final tabs = [
      {'title': 'Overview', 'icon': Icons.space_dashboard_rounded},
      {'title': 'Workforce', 'icon': Icons.groups_rounded},
      {'title': 'Operations', 'icon': Icons.tune_rounded},
      {'title': 'Insights & Approvals', 'icon': Icons.insights_rounded},
    ];

    return Stack(
      children: [
        SingleChildScrollView(
          controller: _categoryTabScrollController,
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(right: 16),
          child: Row(
            children: List.generate(tabs.length, (idx) {
              final isSelected = _selectedCategoryTab == idx;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  avatar: Icon(
                    tabs[idx]['icon'] as IconData,
                    size: 14,
                    color: isSelected ? Colors.white : AppColors.primary,
                  ),
                  label: Text(
                    tabs[idx]['title'] as String,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected ? Colors.white : (isDark ? AppColors.darkPrimaryText : const Color(0xFF334155)),
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: AppColors.primary,
                  backgroundColor: isDark ? AppColors.darkSecondarySurface : const Color(0xFFF1F5F9),
                  checkmarkColor: Colors.white,
                  showCheckmark: false,
                  shape: StadiumBorder(
                    side: BorderSide(
                      color: isSelected
                          ? AppColors.primary
                          : (isDark ? AppColors.darkBordersAndDividers : const Color(0xFFE5E7EB)),
                      width: 1,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onSelected: (_) => _scrollToTab(idx),
                ),
              );
            }),
          ),
        ),
        Positioned(
          right: 0,
          top: 0,
          bottom: 0,
          width: 20,
          child: IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    (isDark ? AppColors.darkAppBackground : AppColors.lightAppBackground).withOpacity(0.0),
                    (isDark ? AppColors.darkAppBackground : AppColors.lightAppBackground),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// TAB 1: OVERVIEW CONTENT
  Widget _buildOverviewTabContent(GlassTheme glass, Color cardBgColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quick Actions', style: AppThemeTokens.cardTitle(Theme.of(context).brightness == Brightness.dark)),
        const SizedBox(height: AppThemeTokens.space8),
        _buildQuickActionsRow(),
        const SizedBox(height: AppThemeTokens.space16),

        // Today's Attendance Panel
        _buildAttendancePanel(glass, cardBgColor),
        const SizedBox(height: AppThemeTokens.space16),

        // Pending Leave Requests Panel
        _buildPendingLeavePanel(glass, cardBgColor),
        const SizedBox(height: AppThemeTokens.space16),

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
        const SizedBox(height: AppThemeTokens.space16),
        _buildDeptDistributionPanel(glass, cardBgColor),
        const SizedBox(height: AppThemeTokens.space16),
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
        const SizedBox(height: AppThemeTokens.space16),
        _buildPayrollSummaryPanel(glass, cardBgColor),
        const SizedBox(height: AppThemeTokens.space16),
        _buildMeetingsPanel(glass, cardBgColor),
        const SizedBox(height: AppThemeTokens.space16),
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
        const SizedBox(height: AppThemeTokens.space16),
        _buildDeptDistributionPanel(glass, cardBgColor),
        const SizedBox(height: AppThemeTokens.space16),
        _buildMeetingsPanel(glass, cardBgColor),
      ],
    );
  }

  /// Quick Actions Scrollable Row with right-edge fade
  Widget _buildQuickActionsRow() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(right: 16),
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
        Positioned(
          right: 0,
          top: 0,
          bottom: 0,
          width: 20,
          child: IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    (isDark ? AppColors.darkAppBackground : AppColors.lightAppBackground).withOpacity(0.0),
                    (isDark ? AppColors.darkAppBackground : AppColors.lightAppBackground),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickPill(String label, IconData icon, VoidCallback onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Semantics(
      button: true,
      label: label,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(30),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkMainSurface : Colors.white,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: isDark ? AppColors.darkBordersAndDividers : const Color(0xFFE2E8F0)),
              boxShadow: const [BoxShadow(color: Color.fromRGBO(15, 107, 102, 0.06), blurRadius: 8, offset: Offset(0, 2))],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkPrimaryText : const Color(0xFF334155),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Pending Leave Requests Panel with Presentational LeaveRequestTile
  Widget _buildPendingLeavePanel(GlassTheme glass, Color cardBgColor) {
    return SectionCard(
      title: 'Pending Leave Requests',
      subtitle: 'Requires your approval',
      headerIcon: Icons.calendar_today_rounded,
      iconColor: const Color(0xFFEA580C),
      iconBg: const Color(0xFFFFEDD5),
      actionLabel: 'View All',
      onActionTap: () {
        if (widget.onNavigateTab != null) widget.onNavigateTab!(0);
      },
      child: _pendingLeaves.isEmpty
          ? const EmptyPlaceholder(
              icon: Icons.event_available_rounded,
              title: 'No pending leave requests requiring approval',
            )
          : Column(
              children: _pendingLeaves.map((req) {
                final isProcessing = _processingLeaveIds.contains(req['id']?.toString());
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: LeaveRequestTile(
                    request: req,
                    isProcessing: isProcessing,
                    onApprove: _approveLeaveRequest,
                    onReject: _rejectLeaveRequest,
                  ),
                );
              }).toList(),
            ),
    );
  }

  /// Department Distribution Panel (Categorical Palette with NO RED & De-emphasized Zero Counts)
  Widget _buildDeptDistributionPanel(GlassTheme glass, Color cardBgColor) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SectionCard(
      title: 'Department Distribution',
      subtitle: 'Employee headcount by department',
      headerIcon: Icons.pie_chart_rounded,
      iconColor: const Color(0xFF2563EB),
      iconBg: const Color(0xFFEFF6FF),
      actionLabel: 'View Details',
      onActionTap: () {},
      child: _deptDistribution.isEmpty
          ? const EmptyPlaceholder(
              icon: Icons.pie_chart_outline_rounded,
              title: 'No department distribution data available',
            )
          : Row(
              children: [
                Semantics(
                  label: 'Department Distribution Donut Chart',
                  child: SizedBox(
                    width: 120,
                    height: 120,
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 3,
                        centerSpaceRadius: 36,
                        sections: _deptDistribution.map((item) {
                          final cnt = (item['count'] as num?)?.toDouble() ?? 0.0;
                          final color = item['color'] as Color? ?? AppThemeTokens.departmentColors[0];
                          return PieChartSectionData(
                            color: color,
                            value: cnt > 0 ? cnt : 0.1,
                            radius: 12,
                            showTitle: false,
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppThemeTokens.space16),
                Expanded(
                  child: Column(
                    children: _deptDistribution.map((item) {
                      final name = item['name']?.toString() ?? '';
                      final count = item['count'] ?? 0;
                      final pct = item['pct'] ?? 0;
                      final color = item['color'] as Color? ?? AppThemeTokens.departmentColors[0];
                      final isZero = count == 0;

                      return Opacity(
                        opacity: isZero ? 0.45 : 1.0,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    name,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                '$count ($pct%)',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
    );
  }

  /// Announcements Panel with Tidy Row Alignment
  Widget _buildAnnouncementsPanel(GlassTheme glass, Color cardBgColor) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SectionCard(
      title: 'Announcements',
      subtitle: 'Company notices & updates',
      headerIcon: Icons.campaign_outlined,
      iconColor: const Color(0xFFEA580C),
      iconBg: const Color(0xFFFFEDD5),
      actionLabel: 'View All',
      onActionTap: () {
        if (widget.onNavigateTab != null) widget.onNavigateTab!(2);
      },
      child: _announcements.isEmpty
          ? const EmptyPlaceholder(
              icon: Icons.campaign_outlined,
              title: 'No announcements posted yet',
            )
          : Column(
              children: _announcements.map((anc) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFEDD5),
                            borderRadius: BorderRadius.circular(AppThemeTokens.radiusTile),
                          ),
                          child: const Icon(Icons.campaign, color: Color(0xFFEA580C), size: 16),
                        ),
                        const SizedBox(width: AppThemeTokens.space12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      anc['title'] ?? '',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEEF2FF),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'PINNED',
                                      style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Color(0xFF4338CA)),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 1),
                              Text(
                                'Company notice & updates',
                                style: AppThemeTokens.cardSubtitle(isDark),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          anc['time'] ?? '',
                          style: AppThemeTokens.caption(isDark),
                        ),
                      ],
                    ),
                  )).toList(),
            ),
    );
  }

  /// Birthdays Panel
  Widget _buildBirthdaysPanel(GlassTheme glass, Color cardBgColor) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SectionCard(
      title: 'Upcoming Birthdays',
      subtitle: "Let's celebrate together!",
      headerIcon: Icons.cake_rounded,
      iconColor: const Color(0xFFDB2777),
      iconBg: const Color(0xFFFCE7F3),
      actionLabel: 'View All',
      onActionTap: () {},
      child: _upcomingBirthdays.isEmpty
          ? const EmptyPlaceholder(
              icon: Icons.cake_outlined,
              title: 'No upcoming birthdays in the next 30 days',
            )
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: _upcomingBirthdays.map((b) => Padding(
                      padding: const EdgeInsets.only(right: 14),
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: const Color(0xFFD1FAE5),
                            child: Text(
                              b['initials'] ?? 'EM',
                              style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            b['name'] ?? '',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText),
                          ),
                          Text(
                            b['formattedDate'] ?? '',
                            style: AppThemeTokens.caption(isDark),
                          ),
                        ],
                      ),
                    )).toList(),
              ),
            ),
    );
  }

  /// Meetings Panel with Styled Empty Placeholder
  Widget _buildMeetingsPanel(GlassTheme glass, Color cardBgColor) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SectionCard(
      title: 'Upcoming Meetings',
      subtitle: 'Scheduled video calls & meetings',
      headerIcon: Icons.video_call_rounded,
      iconColor: const Color(0xFF2563EB),
      iconBg: const Color(0xFFEFF6FF),
      actionLabel: 'View All',
      onActionTap: () {},
      child: _upcomingMeetings.isEmpty
          ? const EmptyPlaceholder(
              icon: Icons.video_camera_back_outlined,
              title: 'No upcoming meetings scheduled',
              message: 'Check back later for new events',
            )
          : Column(
              children: _upcomingMeetings.map((m) => Padding(
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
                              Text(m['title'] ?? '', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText)),
                              Text(m['time'] ?? '', style: AppThemeTokens.caption(isDark)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkSecondarySurface : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: isDark ? AppColors.darkBordersAndDividers : const Color(0xFFCBD5E1)),
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
                  )).toList(),
            ),
    );
  }

  /// Today's Attendance Panel with Softened Donut Ring & Semantic Labels
  Widget _buildAttendancePanel(GlassTheme glass, Color cardBgColor) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final total = _attendanceStats['total'] ?? 0;
    final present = _attendanceStats['present'] ?? 0;
    final absent = _attendanceStats['absent'] ?? 0;
    final wfh = _attendanceStats['wfh'] ?? 0;
    final late = _attendanceStats['late'] ?? 0;

    return SectionCard(
      title: "Today's Attendance",
      subtitle: 'Overview of attendance today',
      headerIcon: Icons.calendar_month_rounded,
      iconColor: const Color(0xFF2563EB),
      iconBg: const Color(0xFFE0EDFF),
      headerTrailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            child: InkWell(
              onTap: () {},
              borderRadius: BorderRadius.circular(20),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: Text('View All', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(12)),
            child: const Text('Live', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF16A34A))),
          ),
        ],
      ),
      child: Row(
        children: [
          // Softened Donut Ring (Thinner stroke radius 12, subtle track color, rounded stroke caps)
          Semantics(
            label: 'Attendance Donut Chart: $present present, $absent absent, $wfh work from home, $late late out of $total employees',
            child: SizedBox(
              width: 120,
              height: 120,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 40,
                      sections: [
                        PieChartSectionData(color: const Color(0xFF16A34A), value: (present as num).toDouble() > 0 ? (present as num).toDouble() : 0.05, radius: 12, showTitle: false),
                        PieChartSectionData(color: const Color(0xFFEF4444), value: (absent as num).toDouble() > 0 ? (absent as num).toDouble() : 0.05, radius: 12, showTitle: false),
                        PieChartSectionData(color: const Color(0xFF2563EB), value: (wfh as num).toDouble() > 0 ? (wfh as num).toDouble() : 0.05, radius: 12, showTitle: false),
                        PieChartSectionData(color: const Color(0xFFF59E0B), value: (late as num).toDouble() > 0 ? (late as num).toDouble() : 0.05, radius: 12, showTitle: false),
                      ],
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Total Employees', style: TextStyle(fontSize: 8.5, color: glass.textSecondary, fontWeight: FontWeight.bold)),
                      Text('$total', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: glass.textPrimary)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: AppThemeTokens.space16),
          Expanded(
            child: Column(
              children: [
                StatusTile(title: 'Present', count: '$present', pct: '${_attendanceStats['presentPct']}%', color: const Color(0xFF16A34A), bg: const Color(0xFFDCFCE7), icon: Icons.groups),
                const SizedBox(height: 6),
                StatusTile(title: 'Absent', count: '$absent', pct: '${_attendanceStats['absentPct']}%', color: const Color(0xFFDC2626), bg: const Color(0xFFFEE2E2), icon: Icons.person_off),
                const SizedBox(height: 6),
                StatusTile(title: 'Work From Home', count: '$wfh', pct: '${_attendanceStats['wfhPct']}%', color: const Color(0xFF2563EB), bg: const Color(0xFFDBEAFE), icon: Icons.home),
                const SizedBox(height: 6),
                StatusTile(title: 'Late Arrivals', count: '$late', pct: '${_attendanceStats['latePct']}%', color: const Color(0xFFD97706), bg: const Color(0xFFFEF3C7), icon: Icons.access_time),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Recruitment Status Panel with Visual Empty Styling
  Widget _buildRecruitmentStatusPanel(GlassTheme glass, Color cardBgColor) {
    return SectionCard(
      title: 'Recruitment Status',
      subtitle: 'Current hiring pipeline',
      headerIcon: Icons.person_add_rounded,
      iconColor: const Color(0xFF9333EA),
      iconBg: const Color(0xFFF3E8FF),
      actionLabel: 'Manage →',
      onActionTap: () {},
      child: Column(
        children: [
          _buildMetricRow('Open Positions', '${_stats['openPositions']}', Icons.work_outline, const Color(0xFF2563EB), const Color(0xFFE0EDFF)),
          const SizedBox(height: 10),
          _buildMetricRow('Candidates', '${_stats['candidatesInPipeline']}', Icons.groups_outlined, const Color(0xFF9333EA), const Color(0xFFF3E8FF)),
          const SizedBox(height: 10),
          _buildMetricRow('Hired This Month', '${_stats['hiredThisMonth']}', Icons.verified_user_outlined, const Color(0xFF16A34A), const Color(0xFFDCFCE7)),
        ],
      ),
    );
  }

  /// Payroll Summary Panel with Visual Empty Styling
  Widget _buildPayrollSummaryPanel(GlassTheme glass, Color cardBgColor) {
    final netPay = _stats['monthlyPayrollNet'] ?? 0.0;
    final formattedNetPay = netPay is num ? '₹${netPay.toStringAsFixed(0)}' : '₹0';
    final processed = _stats['payrollProcessedThisMonth'] ?? 0;

    return SectionCard(
      title: 'Payroll Summary',
      subtitle: 'Latest payment disbursement details',
      headerIcon: Icons.request_quote_rounded,
      iconColor: const Color(0xFF16A34A),
      iconBg: const Color(0xFFDCFCE7),
      actionLabel: 'Manage Payroll →',
      onActionTap: () {},
      child: Column(
        children: [
          _buildMetricRow('Net Pay this Month', formattedNetPay, Icons.account_balance_wallet_outlined, const Color(0xFF16A34A), const Color(0xFFDCFCE7)),
          const SizedBox(height: 10),
          _buildMetricRow('Records Processed', '$processed', Icons.description_outlined, const Color(0xFF2563EB), const Color(0xFFE0EDFF)),
        ],
      ),
    );
  }

  Widget _buildMetricRow(String title, String value, IconData icon, Color iconColor, Color iconBg) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final intVal = int.tryParse(value.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    final isZero = intVal == 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSecondarySurface.withOpacity(0.5) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(AppThemeTokens.radiusTile),
        border: Border.all(color: isDark ? AppColors.darkBordersAndDividers : const Color(0xFFF1F5F9)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(AppThemeTokens.radiusTile)),
            child: Icon(icon, color: iconColor, size: 16),
          ),
          const SizedBox(width: AppThemeTokens.space12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.darkPrimaryText : const Color(0xFF334155),
              ),
            ),
          ),
          AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: isZero ? 0.5 : 1.0,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: isZero ? (isDark ? AppColors.darkMutedText : const Color(0xFF64748B)) : iconColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Helper delegate for Sticky Persistent Header
class _StickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double height;

  _StickyHeaderDelegate({required this.child, required this.height});

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      color: (isDark ? AppColors.darkAppBackground : AppColors.lightAppBackground).withOpacity(shrinkOffset > 0 ? 0.96 : 1.0),
      alignment: Alignment.center,
      child: child,
    );
  }

  @override
  double get maxExtent => height;

  @override
  double get minExtent => height;

  @override
  bool shouldRebuild(covariant _StickyHeaderDelegate oldDelegate) {
    return oldDelegate.child != child || oldDelegate.height != height;
  }
}
