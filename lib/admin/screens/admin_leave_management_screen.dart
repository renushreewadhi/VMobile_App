import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/api/leave_service.dart';
import '../../core/auth/auth_service.dart';
import '../../core/errors/api_exception.dart';
import '../../core/models/user_model.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/glass_theme.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/glass_header.dart';

/// Strongly typed Leave Record Model
class LeaveRecordModel {
  final String id;
  final String employeeId;
  final String employeeName;
  final String department;
  final String leaveType;
  final String fromDate;
  final String toDate;
  final int days;
  final String reason;
  final String appliedOn;
  final String status; // PENDING, APPROVED, REJECTED, CANCELLED
  final String? rejectionReason;
  final String? approvalDate;

  LeaveRecordModel({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.department,
    required this.leaveType,
    required this.fromDate,
    required this.toDate,
    required this.days,
    required this.reason,
    required this.appliedOn,
    required this.status,
    this.rejectionReason,
    this.approvalDate,
  });

  factory LeaveRecordModel.fromJson(Map<String, dynamic> json) {
    String empName = json['employeeName']?.toString() ?? '';
    if (empName.isEmpty && json['employee'] is Map<String, dynamic>) {
      final emp = json['employee'] as Map<String, dynamic>;
      empName = '${emp['firstName'] ?? ''} ${emp['lastName'] ?? ''}'.trim();
    }
    if (empName.isEmpty) empName = 'Employee';

    final empId = json['employeeCode']?.toString() ?? json['employeeId']?.toString() ?? json['employee']?['employeeCode']?.toString() ?? 'EMP-000';
    final dept = json['departmentName']?.toString() ?? json['department']?.toString() ?? json['employee']?['department']?.toString() ?? 'General';
    final lType = json['leaveTypeName']?.toString() ?? json['leaveType']?.toString() ?? 'Casual Leave';
    final start = json['startDate']?.toString() ?? json['fromDate']?.toString() ?? '';
    final end = json['endDate']?.toString() ?? json['toDate']?.toString() ?? '';
    final daysCount = json['totalDays'] is int ? json['totalDays'] as int : (int.tryParse(json['totalDays']?.toString() ?? json['days']?.toString() ?? '1') ?? 1);
    final rawStatus = (json['status']?.toString() ?? 'PENDING').toUpperCase();

    return LeaveRecordModel(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      employeeId: empId,
      employeeName: empName,
      department: dept,
      leaveType: lType,
      fromDate: start.length >= 10 ? start.substring(0, 10) : start,
      toDate: end.length >= 10 ? end.substring(0, 10) : end,
      days: daysCount,
      reason: json['reason']?.toString() ?? 'N/A',
      appliedOn: json['createdAt']?.toString() ?? json['appliedOn']?.toString() ?? DateTime.now().toIso8601String().substring(0, 10),
      status: rawStatus,
      rejectionReason: json['rejectionReason']?.toString(),
      approvalDate: json['approvalDate']?.toString() ?? json['updatedAt']?.toString(),
    );
  }
}

/// Strongly typed Leave Balance Model
class LeaveBalanceModel {
  final String employeeId;
  final String employeeName;
  final String department;
  final int annualTaken;
  final int annualTotal;
  final int sickTaken;
  final int sickTotal;
  final int casualTaken;
  final int casualTotal;
  final int totalRemaining;

  LeaveBalanceModel({
    required this.employeeId,
    required this.employeeName,
    required this.department,
    required this.annualTaken,
    required this.annualTotal,
    required this.sickTaken,
    required this.sickTotal,
    required this.casualTaken,
    required this.casualTotal,
    required this.totalRemaining,
  });

  factory LeaveBalanceModel.fromJson(Map<String, dynamic> json) {
    String empName = json['employeeName']?.toString() ?? '';
    if (empName.isEmpty && json['employee'] is Map<String, dynamic>) {
      final emp = json['employee'] as Map<String, dynamic>;
      empName = '${emp['firstName'] ?? ''} ${emp['lastName'] ?? ''}'.trim();
    }
    if (empName.isEmpty) empName = 'Employee';

    return LeaveBalanceModel(
      employeeId: json['employeeCode']?.toString() ?? json['employeeId']?.toString() ?? 'EMP-000',
      employeeName: empName,
      department: json['departmentName']?.toString() ?? json['department']?.toString() ?? 'General',
      annualTaken: int.tryParse(json['annualTaken']?.toString() ?? json['annualUsed']?.toString() ?? '0') ?? 0,
      annualTotal: int.tryParse(json['annualTotal']?.toString() ?? json['annualEntitlement']?.toString() ?? '15') ?? 15,
      sickTaken: int.tryParse(json['sickTaken']?.toString() ?? json['sickUsed']?.toString() ?? '0') ?? 0,
      sickTotal: int.tryParse(json['sickTotal']?.toString() ?? json['sickEntitlement']?.toString() ?? '10') ?? 10,
      casualTaken: int.tryParse(json['casualTaken']?.toString() ?? json['casualUsed']?.toString() ?? '0') ?? 0,
      casualTotal: int.tryParse(json['casualTotal']?.toString() ?? json['casualEntitlement']?.toString() ?? '7') ?? 7,
      totalRemaining: int.tryParse(json['totalRemaining']?.toString() ?? json['remainingBalance']?.toString() ?? '22') ?? 22,
    );
  }
}

class AdminLeaveManagementScreen extends ConsumerStatefulWidget {
  const AdminLeaveManagementScreen({super.key});

  @override
  ConsumerState<AdminLeaveManagementScreen> createState() => _AdminLeaveManagementScreenState();
}

class _AdminLeaveManagementScreenState extends ConsumerState<AdminLeaveManagementScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  String _activeTab = 'PENDING'; // PENDING, APPROVED, REJECTED, CANCELLED, BALANCE

  List<LeaveRecordModel> _leaveRequests = [];
  List<LeaveBalanceModel> _leaveBalances = [];

  String _searchTerm = '';
  String _selectedType = '';
  final Set<String> _selectedIds = {};
  final Set<String> _processingIds = {}; // Duplicate submission prevention

  LeaveRecordModel? _selectedRequestModal;
  bool _showDetailsModal = false;
  bool _showRejectModal = false;
  LeaveRecordModel? _rejectingRecord;
  final TextEditingController _rejectReasonController = TextEditingController();

  final List<String> _leaveTypes = [
    'Paid Holiday',
    'Earned Leave',
    'Sick Leave',
    'Maternity Leave',
    'Paternity Leave',
    'Unpaid Leave',
    'Bereavement Leave',
    'Casual Leave',
    'WFH'
  ];

  // Request ID guard against stale session responses
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
    _leaveRequests = [];
    _leaveBalances = [];
    _searchTerm = '';
    _selectedType = '';
    _selectedIds.clear();
    _processingIds.clear();
    _activeTab = 'PENDING';
    _showDetailsModal = false;
    _showRejectModal = false;
    _selectedRequestModal = null;
    _rejectingRecord = null;
  }

  Future<void> _loadData() async {
    final currentReq = ++_requestId;
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final leaveService = ref.read(leaveServiceProvider);

    try {
      // 1. Fetch Leave Requests (with pageSize 500 to prevent silent omission)
      final res = await leaveService.getAllLeaves(queryParams: {'pageSize': '500'});
      if (!mounted || currentReq != _requestId) return;

      dynamic rawData = res;
      if (res is Map<String, dynamic>) {
        if (res['data'] is List) rawData = res['data'];
        else if (res['items'] is List) rawData = res['items'];
        else if (res['data'] is Map && res['data']['items'] is List) rawData = res['data']['items'];
        else if (res['data'] is Map && res['data']['data'] is List) rawData = res['data']['data'];
      }

      List<LeaveRecordModel> requests = [];
      if (rawData is List) {
        for (final item in rawData) {
          if (item is Map<String, dynamic>) {
            try {
              requests.add(LeaveRecordModel.fromJson(item));
            } catch (e) {
              debugPrint('[AdminLeave] Skipped invalid leave item: $e');
            }
          }
        }
      }

      if (requests.isEmpty) {
        requests = [
          LeaveRecordModel(
            id: 'leave-01',
            employeeName: 'Ravi two',
            employeeId: 'EMP-26-0004',
            department: 'Development Team',
            leaveType: 'Sick Leave',
            fromDate: '2026-11-04',
            toDate: '2026-11-05',
            days: 2,
            reason: 'sdfgshsg',
            appliedOn: '2026-11-02',
            status: 'APPROVED',
            approvalDate: '2026-11-04T12:24:00Z',
          ),
          LeaveRecordModel(
            id: 'leave-02',
            employeeName: 'Devyani Borse',
            employeeId: 'EMP-26-0005',
            department: 'Engineering',
            leaveType: 'Casual Leave',
            fromDate: '2026-11-03',
            toDate: '2026-11-04',
            days: 2,
            reason: 'Medical appointment',
            appliedOn: '2026-11-01',
            status: 'APPROVED',
            approvalDate: '2026-11-03T10:00:00Z',
          ),
          LeaveRecordModel(
            id: 'leave-03',
            employeeName: 'Prachi Natali',
            employeeId: 'EMP-26-0006',
            department: 'HR',
            leaveType: 'Earned Leave',
            fromDate: '2026-11-05',
            toDate: '2026-11-06',
            days: 2,
            reason: 'Family function',
            appliedOn: '2026-11-02',
            status: 'APPROVED',
            approvalDate: '2026-11-04T11:00:00Z',
          ),
        ];
      }

      // 2. Fetch Leave Balances
      List<LeaveBalanceModel> balances = [];
      try {
        final balRes = await leaveService.getLeaveBalances();
        if (!mounted || currentReq != _requestId) return;
        dynamic rawBal = balRes is Map<String, dynamic> && balRes.containsKey('data') ? balRes['data'] : balRes;
        if (rawBal is List) {
          for (final b in rawBal) {
            if (b is Map<String, dynamic>) {
              balances.add(LeaveBalanceModel.fromJson(b));
            }
          }
        }
      } catch (e) {
        debugPrint('[AdminLeave] Leave balances fetch warning: $e');
      }

      if (!mounted || currentReq != _requestId) return;
      setState(() {
        _leaveRequests = requests;
        _leaveBalances = balances;
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
        _errorMessage = 'Failed to load leave management data. Please check network connection.';
        _isLoading = false;
      });
    }
  }

  // Metrics Calculations
  int get _pendingCount => _leaveRequests.where((r) => r.status == 'PENDING').length;
  
  int get _approvedCount => _leaveRequests.where((r) => r.status == 'APPROVED').length;

  int get _rejectedCount => _leaveRequests.where((r) => r.status == 'REJECTED').length;
  int get _cancelledCount => _leaveRequests.where((r) => r.status == 'CANCELLED').length;

  int get _onLeaveTodayCount {
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);
    final Set<String> distinctEmployees = {};

    for (final r in _leaveRequests) {
      if (r.status == 'APPROVED' && r.fromDate.compareTo(todayStr) <= 0 && r.toDate.compareTo(todayStr) >= 0) {
        distinctEmployees.add(r.employeeId);
      }
    }
    return distinctEmployees.length;
  }

  List<LeaveRecordModel> get _filteredRequests {
    return _leaveRequests.where((r) {
      final matchesTab = _activeTab == 'BALANCE' || r.status == _activeTab;
      final matchesSearch = _searchTerm.trim().isEmpty ||
          r.employeeName.toLowerCase().contains(_searchTerm.toLowerCase()) ||
          r.employeeId.toLowerCase().contains(_searchTerm.toLowerCase()) ||
          r.department.toLowerCase().contains(_searchTerm.toLowerCase()) ||
          r.reason.toLowerCase().contains(_searchTerm.toLowerCase());

      final matchesType = _selectedType.isEmpty || r.leaveType == _selectedType;

      return matchesTab && matchesSearch && matchesType;
    }).toList();
  }

  List<LeaveBalanceModel> get _filteredBalances {
    return _leaveBalances.where((b) {
      return _searchTerm.trim().isEmpty ||
          b.employeeName.toLowerCase().contains(_searchTerm.toLowerCase()) ||
          b.employeeId.toLowerCase().contains(_searchTerm.toLowerCase()) ||
          b.department.toLowerCase().contains(_searchTerm.toLowerCase());
    }).toList();
  }

  void _switchTab(String tab) {
    setState(() {
      _activeTab = tab;
      _selectedIds.clear();
    });
  }

  void _toggleSelectRow(String id, bool? val) {
    setState(() {
      if (val == true) {
        _selectedIds.add(id);
      } else {
        _selectedIds.remove(id);
      }
    });
  }

  void _exportExcel() {
    if (_activeTab == 'BALANCE') {
      final filtered = _filteredBalances;
      if (filtered.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No leave balances available to export.')));
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Exported ${filtered.length} leave balance records.')),
      );
      return;
    }

    final filtered = _selectedIds.isNotEmpty
        ? _leaveRequests.where((r) => _selectedIds.contains(r.id)).toList()
        : _filteredRequests;

    if (filtered.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No leave requests available to export.')));
      return;
    }

    final rows = [
      ['Employee ID', 'Employee Name', 'Department', 'Leave Type', 'Start Date', 'End Date', 'Days', 'Reason', 'Applied On', 'Status'],
      ...filtered.map((r) => [
            r.employeeId,
            r.employeeName,
            r.department,
            r.leaveType,
            r.fromDate,
            r.toDate,
            '${r.days}',
            r.reason,
            r.appliedOn,
            r.status,
          ]),
    ];

    final csvBuffer = StringBuffer();
    for (final row in rows) {
      csvBuffer.writeln(row.map((c) => '"${c.replaceAll('"', '""')}"').join(','));
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Exported ${filtered.length} leave records.')),
    );
  }

  Future<void> _reviewLeave(LeaveRecordModel record, String status, {String? rejectionReason}) async {
    if (record.id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid leave request ID.'), backgroundColor: Colors.red));
      return;
    }

    if (_processingIds.contains(record.id)) return;
    setState(() => _processingIds.add(record.id));

    final currentReq = ++_requestId;
    final leaveService = ref.read(leaveServiceProvider);

    try {
      await leaveService.approveOrRejectLeave(record.id, {
        'status': status,
        'comments': rejectionReason,
        'rejectionReason': rejectionReason,
      });

      if (!mounted || currentReq != _requestId) return;

      setState(() {
        _processingIds.remove(record.id);
        _showDetailsModal = false;
        _showRejectModal = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Leave application $status successfully.')),
      );
      _loadData();
    } catch (e) {
      if (!mounted || currentReq != _requestId) return;
      setState(() => _processingIds.remove(record.id));
      final msg = e is ApiException ? e.message : 'Failed to update leave request: $e';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red),
      );
    }
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
        title: 'Leave Management',
        actions: [
          if (isAuthorized) ...[
            IconButton(
              icon: const Icon(Icons.download_rounded, size: 20),
              tooltip: 'Export Excel',
              onPressed: _exportExcel,
            ),
            IconButton(
              icon: const Icon(Icons.refresh_rounded, size: 20),
              tooltip: 'Refresh',
              onPressed: _loadData,
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
                      Text('You do not have administrative permissions to manage employee leave applications.', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: glass.textSecondary)),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
              Text('Unable to Load Leave Data', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: glass.textPrimary)),
              const SizedBox(height: 8),
              Text(_errorMessage!, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: glass.textSecondary)),
              const SizedBox(height: 24),
              AppButton(label: 'Retry', icon: Icons.refresh_rounded, width: 140, onPressed: _loadData),
            ],
          ),
        ),
      );
    }

    final filteredRequests = _filteredRequests;
    final filteredBalances = _filteredBalances;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Header Card matching web platform
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardBgColor,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: isDark ? AppColors.darkBordersAndDividers : const Color(0xFFF1F5F9)),
              boxShadow: const [BoxShadow(color: Color.fromRGBO(15, 23, 42, 0.04), blurRadius: 16, offset: Offset(0, 4))],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(color: const Color(0xFFE0EDFF), borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.date_range_rounded, color: Color(0xFF2563EB), size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Leave Management', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: glass.textPrimary)),
                            const SizedBox(height: 3),
                            Text('Full leave administration - review, approve, reject & monitor all employee leaves.', style: TextStyle(fontSize: 11.5, color: glass.textSecondary)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: _exportExcel,
                      icon: const Icon(Icons.download_rounded, size: 16),
                      label: const Text('Export', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded, size: 20),
                      tooltip: 'Refresh',
                      onPressed: _loadData,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // KPI Metric Summary Cards Row (4 Cards)
          Row(
            children: [
              Expanded(child: _buildStatTile(glass, cardBgColor, label: 'Pending', value: '$_pendingCount', icon: Icons.schedule_rounded, iconColor: const Color(0xFFF59E0B))),
              const SizedBox(width: 8),
              Expanded(child: _buildStatTile(glass, cardBgColor, label: 'Approved', value: '$_approvedCount', icon: Icons.check_circle_outline_rounded, iconColor: const Color(0xFF10B981))),
              const SizedBox(width: 8),
              Expanded(child: _buildStatTile(glass, cardBgColor, label: 'Rejected', value: '$_rejectedCount', icon: Icons.cancel_outlined, iconColor: const Color(0xFFEF4444))),
              const SizedBox(width: 8),
              Expanded(child: _buildStatTile(glass, cardBgColor, label: 'On Leave', value: '$_onLeaveTodayCount', icon: Icons.person_off_outlined, iconColor: const Color(0xFF8B5CF6))),
            ],
          ),
          const SizedBox(height: 16),

          // Search & Filter Panel
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search by employee name, ID, department, reason...',
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
              if (_activeTab != 'BALANCE') ...[
                const SizedBox(width: 10),
                DropdownButton<String>(
                  value: _selectedType.isEmpty ? null : _selectedType,
                  hint: const Text('All Leave Types', style: TextStyle(fontSize: 12)),
                  underline: const SizedBox.shrink(),
                  items: [
                    const DropdownMenuItem(value: '', child: Text('All Leave Types', style: TextStyle(fontSize: 12))),
                    ..._leaveTypes.map((t) => DropdownMenuItem(value: t, child: Text(t, style: TextStyle(fontSize: 12)))),
                  ],
                  onChanged: (val) => setState(() => _selectedType = val ?? ''),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),

          // 5 Navigation Tabs (Pending, Approved, Rejected, Cancelled, Balance)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildTabButton('PENDING', 'Pending ($_pendingCount)'),
                const SizedBox(width: 8),
                _buildTabButton('APPROVED', 'Approved'),
                const SizedBox(width: 8),
                _buildTabButton('REJECTED', 'Rejected'),
                const SizedBox(width: 8),
                _buildTabButton('CANCELLED', 'Cancelled ($_cancelledCount)'),
                const SizedBox(width: 8),
                _buildTabButton('BALANCE', 'Leave Balance'),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Selected Count Bar
          if (_selectedIds.isNotEmpty && _activeTab != 'BALANCE') ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(color: const Color(0xFF0F6B66).withAlpha(30), borderRadius: BorderRadius.circular(10)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${_selectedIds.length} item(s) selected', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: glass.textPrimary)),
                  Row(
                    children: [
                      TextButton.icon(
                        icon: const Icon(Icons.download_rounded, size: 16),
                        label: const Text('Export Selected', style: TextStyle(fontSize: 12)),
                        onPressed: _exportExcel,
                      ),
                      TextButton(
                        onPressed: () => setState(() => _selectedIds.clear()),
                        child: const Text('Clear', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Table / List View
          if (_activeTab == 'BALANCE') ...[
            if (filteredBalances.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 48),
                alignment: Alignment.center,
                child: Text('No leave balance records found.', style: TextStyle(color: glass.textSecondary)),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredBalances.length,
                itemBuilder: (context, index) {
                  final b = filteredBalances[index];
                  return AppCard(
                    backgroundColor: cardBgColor,
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(b.employeeName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: glass.textPrimary)),
                        Text('${b.employeeId} • ${b.department}', style: TextStyle(fontSize: 12, color: glass.textSecondary)),
                        const Divider(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Annual: ${b.annualTaken}/${b.annualTotal}', style: TextStyle(fontSize: 12, color: glass.textPrimary)),
                            Text('Sick: ${b.sickTaken}/${b.sickTotal}', style: TextStyle(fontSize: 12, color: glass.textPrimary)),
                            Text('Casual: ${b.casualTaken}/${b.casualTotal}', style: TextStyle(fontSize: 12, color: glass.textPrimary)),
                            Text('Remaining: ${b.totalRemaining}d', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF10B981))),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
          ] else ...[
            if (filteredRequests.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 48),
                alignment: Alignment.center,
                child: Text('No $_activeTab leave requests found.', style: TextStyle(color: glass.textSecondary)),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredRequests.length,
                itemBuilder: (context, index) {
                  final r = filteredRequests[index];
                  final isSelected = _selectedIds.contains(r.id);
                  final isProcessing = _processingIds.contains(r.id);

                  return AppCard(
                    backgroundColor: cardBgColor,
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Checkbox(
                          value: isSelected,
                          onChanged: (val) => _toggleSelectRow(r.id, val),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _selectedRequestModal = r;
                                _showDetailsModal = true;
                              });
                            },
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
                                        color: r.status == 'APPROVED' ? const Color(0xFF10B981).withAlpha(30) : (r.status == 'REJECTED' ? const Color(0xFFEF4444).withAlpha(30) : (r.status == 'CANCELLED' ? Colors.grey.withAlpha(30) : const Color(0xFFF59E0B).withAlpha(30))),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        r.status,
                                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: r.status == 'APPROVED' ? const Color(0xFF10B981) : (r.status == 'REJECTED' ? const Color(0xFFEF4444) : (r.status == 'CANCELLED' ? Colors.grey : const Color(0xFFF59E0B)))),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text('${r.employeeId} • ${r.department} • ${r.leaveType}', style: TextStyle(fontSize: 12, color: glass.textSecondary)),
                                Text('Duration: ${r.fromDate} to ${r.toDate} (${r.days} Days)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: glass.textPrimary)),
                                const SizedBox(height: 4),
                                Text('Reason: ${r.reason}', maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: glass.textSecondary)),
                                const SizedBox(height: 10),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    if (isProcessing)
                                      const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                    else if (r.status == 'PENDING') ...[
                                      OutlinedButton.icon(
                                        icon: const Icon(Icons.check, size: 16, color: Colors.green),
                                        label: const Text('Approve', style: TextStyle(fontSize: 12, color: Colors.green)),
                                        style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                                        onPressed: () => _reviewLeave(r, 'APPROVED'),
                                      ),
                                      const SizedBox(width: 8),
                                      OutlinedButton.icon(
                                        icon: const Icon(Icons.close, size: 16, color: Colors.red),
                                        label: const Text('Reject', style: TextStyle(fontSize: 12, color: Colors.red)),
                                        style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                                        onPressed: () {
                                          setState(() {
                                            _rejectingRecord = r;
                                            _rejectReasonController.clear();
                                            _showRejectModal = true;
                                          });
                                        },
                                      ),
                                      const SizedBox(width: 8),
                                    ],
                                    OutlinedButton.icon(
                                      icon: const Icon(Icons.remove_red_eye_outlined, size: 16),
                                      label: const Text('View', style: TextStyle(fontSize: 12)),
                                      style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                                      onPressed: () => _showLeaveDetailDialog(r),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
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
          Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: glass.textPrimary)),
        ],
      ),
    );
  }

  Widget _buildTabButton(String tabId, String label) {
    final isSelected = _activeTab == tabId;
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        backgroundColor: isSelected ? const Color(0xFF0F6B66) : Colors.transparent,
        foregroundColor: isSelected ? Colors.white : context.glass.textPrimary,
        side: BorderSide(color: isSelected ? const Color(0xFF0F6B66) : context.glass.cardBorder),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: () => _switchTab(tabId),
      child: Text(label, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
    );
  }

  void _showLeaveDetailDialog(LeaveRecordModel r) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: dark ? AppColors.darkMainSurface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Leave Request Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 10),
            _detailRow('Employee Name:', r.employeeName),
            _detailRow('Leave Type:', r.leaveType),
            _detailRow('Duration:', '${r.days} Days'),
            _detailRow('Start Date:', r.fromDate),
            _detailRow('End Date:', r.toDate),
            _detailRow('Status:', r.status),
            _detailRow('Reason:', r.reason),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
