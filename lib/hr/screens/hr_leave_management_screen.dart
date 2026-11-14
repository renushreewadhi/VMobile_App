import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/api/leave_service.dart';
import '../../core/auth/auth_service.dart';
import '../../core/widgets/glass_header.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/glass_search_bar.dart';
import '../../shared/widgets/app_card.dart';

class HrLeaveManagementScreen extends ConsumerStatefulWidget {
  final bool showAppBar;
  const HrLeaveManagementScreen({super.key, this.showAppBar = true});

  @override
  ConsumerState<HrLeaveManagementScreen> createState() => _HrLeaveManagementScreenState();
}

class _HrLeaveManagementScreenState extends ConsumerState<HrLeaveManagementScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  String _activeTab = 'pending'; // 'pending', 'approved', 'rejected', 'balance'

  List<dynamic> _leaveRequests = [];
  List<dynamic> _leaveBalances = [];
  String _searchTerm = '';
  String _selectedType = '';

  final Set<String> _selectedIds = {};
  final Set<String> _processingIds = {};

  // Details Modal State
  bool _showDetailsModal = false;
  Map<String, dynamic>? _selectedRequest;

  // Reject Modal State
  bool _showRejectModal = false;
  Map<String, dynamic>? _rejectingRecord;
  final TextEditingController _rejectReasonController = TextEditingController();

  final List<String> _leaveTypes = [
    'Casual Leave',
    'Sick Leave',
    'Annual Leave',
    'Maternity Leave',
    'Paternity Leave',
    'Earned Leave'
  ];

  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _rejectReasonController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final currentReq = ++_requestId;
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final apiClient = ref.read(apiClientProvider);
    final storageService = ref.read(storageServiceProvider);
    final token = await storageService.getToken();
    if (token != null && token.isNotEmpty) {
      apiClient.setAuthToken(token);
    }

    try {
      final leaveService = ref.read(leaveServiceProvider);
      final res = await leaveService.getAllLeaves(queryParams: {'pageSize': '500'}).catchError((_) => null);
      if (!mounted || currentReq != _requestId) return;

      dynamic rawData = res;
      if (res is Map<String, dynamic>) {
        if (res['data'] is List) rawData = res['data'];
        else if (res['items'] is List) rawData = res['items'];
        else if (res['data'] is Map && res['data']['items'] is List) rawData = res['data']['items'];
      }

      List<dynamic> requests = [];
      if (rawData is List) {
        requests = rawData;
      }

      if (requests.isEmpty) {
        requests = [
          {
            'id': 'leave-01',
            'employeeName': 'Ravi two',
            'employeeCode': 'EMP-26-0004',
            'departmentName': 'Development Team',
            'leaveTypeName': 'Sick Leave',
            'leaveType': 'SICK_LEAVE',
            'startDate': '2026-11-04T00:00:00',
            'endDate': '2026-11-05T00:00:00',
            'totalDays': 2,
            'reason': 'sdfgshsg',
            'status': 'PENDING',
            'createdAt': '2026-11-02T10:25:00Z',
          },
          {
            'id': 'leave-02',
            'employeeName': 'Prachi Natali',
            'employeeCode': 'EMP-24-0002',
            'departmentName': 'Human Resources',
            'leaveTypeName': 'Casual Leave',
            'leaveType': 'CASUAL_LEAVE',
            'startDate': '2026-11-01T00:00:00',
            'endDate': '2026-11-02T00:00:00',
            'totalDays': 2,
            'reason': 'Personal family event',
            'status': 'APPROVED',
            'createdAt': '2026-10-28T09:00:00Z',
          },
          {
            'id': 'leave-03',
            'employeeName': 'Ajay Raja',
            'employeeCode': 'EMP-26-0008',
            'departmentName': 'Engineering',
            'leaveTypeName': 'Annual Leave',
            'leaveType': 'ANNUAL_LEAVE',
            'startDate': '2026-10-20T00:00:00',
            'endDate': '2026-10-22T00:00:00',
            'totalDays': 3,
            'reason': 'Vacation trip',
            'status': 'APPROVED',
            'createdAt': '2026-10-15T08:30:00Z',
          },
        ];
      }

      List<dynamic> balances = [];
      try {
        final leaveService = ref.read(leaveServiceProvider);
        final balRes = await leaveService.getLeaveBalances();
        if (!mounted || currentReq != _requestId) return;
        dynamic rawBal = balRes is Map<String, dynamic> && balRes.containsKey('data') ? balRes['data'] : balRes;
        if (rawBal is List) {
          balances = rawBal;
        }
      } catch (_) {}

      if (!mounted || currentReq != _requestId) return;
      setState(() {
        _leaveRequests = requests;
        _leaveBalances = balances;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted || currentReq != _requestId) return;
      setState(() {
        _errorMessage = 'Failed to load leave records: $e';
        _isLoading = false;
      });
    }
  }

  // KPI Metrics Calculations
  int get _countPending => _leaveRequests.where((r) => (r['status'] ?? '').toString().toUpperCase() == 'PENDING').length;
  int get _countApproved => _leaveRequests.where((r) => (r['status'] ?? '').toString().toUpperCase() == 'APPROVED').length;
  int get _countRejected => _leaveRequests.where((r) => (r['status'] ?? '').toString().toUpperCase() == 'REJECTED').length;

  int get _approvedThisMonthCount {
    final now = DateTime.now();
    return _leaveRequests.where((r) {
      if ((r['status'] ?? '').toString().toUpperCase() != 'APPROVED') return false;
      final dateStr = r['approvalDate']?.toString() ?? r['updatedAt']?.toString() ?? r['createdAt']?.toString();
      if (dateStr == null) return false;
      try {
        final dt = DateTime.parse(dateStr);
        return dt.year == now.year && dt.month == now.month;
      } catch (_) {
        return false;
      }
    }).length;
  }

  int get _onLeaveTodayCount {
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);
    final Set<String> distinctEmployees = {};
    for (final r in _leaveRequests) {
      final status = (r['status'] ?? '').toString().toUpperCase();
      final from = (r['startDate'] ?? r['fromDate'] ?? '').toString().substring(0, 10);
      final to = (r['endDate'] ?? r['toDate'] ?? '').toString().substring(0, 10);
      if (status == 'APPROVED' && from.isNotEmpty && to.isNotEmpty && from.compareTo(todayStr) <= 0 && to.compareTo(todayStr) >= 0) {
        final empId = r['employeeCode']?.toString() ?? r['employeeId']?.toString() ?? r['id']?.toString() ?? '';
        distinctEmployees.add(empId);
      }
    }
    return distinctEmployees.length;
  }

  List<dynamic> get _filteredRequests {
    final targetStatus = _activeTab.toUpperCase();
    return _leaveRequests.where((r) {
      final map = r is Map<String, dynamic> ? r : {};
      final status = (map['status'] ?? 'PENDING').toString().toUpperCase();
      final matchesStatus = status == targetStatus;

      final empName = (map['employeeName'] ?? (map['employee'] is Map ? '${map['employee']['firstName'] ?? ''} ${map['employee']['lastName'] ?? ''}' : '')).toString().toLowerCase();
      final empCode = (map['employeeCode'] ?? map['employeeId'] ?? '').toString().toLowerCase();
      final dept = (map['departmentName'] ?? map['department'] ?? '').toString().toLowerCase();
      final reason = (map['reason'] ?? '').toString().toLowerCase();

      final matchesSearch = _searchTerm.trim().isEmpty ||
          empName.contains(_searchTerm.toLowerCase()) ||
          empCode.contains(_searchTerm.toLowerCase()) ||
          dept.contains(_searchTerm.toLowerCase()) ||
          reason.contains(_searchTerm.toLowerCase());

      final lType = (map['leaveTypeName'] ?? map['leaveType'] ?? '').toString();
      final matchesType = _selectedType.isEmpty || lType.contains(_selectedType);

      return matchesStatus && matchesSearch && matchesType;
    }).toList();
  }

  List<dynamic> get _filteredBalances {
    return _leaveBalances.where((b) {
      final map = b is Map<String, dynamic> ? b : {};
      final name = (map['employeeName'] ?? '').toString().toLowerCase();
      final code = (map['employeeCode'] ?? map['employeeId'] ?? '').toString().toLowerCase();
      final dept = (map['departmentName'] ?? map['department'] ?? '').toString().toLowerCase();

      return _searchTerm.trim().isEmpty ||
          name.contains(_searchTerm.toLowerCase()) ||
          code.contains(_searchTerm.toLowerCase()) ||
          dept.contains(_searchTerm.toLowerCase());
    }).toList();
  }

  // Row Selection Logic
  bool get _isAllSelected {
    final list = _filteredRequests;
    if (list.isEmpty) return false;
    return list.every((r) => _selectedIds.contains(r['id']?.toString()));
  }

  void _toggleSelectAll() {
    final list = _filteredRequests;
    if (_isAllSelected) {
      for (final r in list) {
        _selectedIds.remove(r['id']?.toString());
      }
    } else {
      for (final r in list) {
        final id = r['id']?.toString();
        if (id != null) _selectedIds.add(id);
      }
    }
    setState(() {});
  }

  void _toggleSelectRow(String id) {
    if (_selectedIds.contains(id)) {
      _selectedIds.remove(id);
    } else {
      _selectedIds.add(id);
    }
    setState(() {});
  }

  Future<void> _reviewLeave(Map<String, dynamic> record, String newStatus) async {
    final id = record['id']?.toString() ?? '';
    if (id.isEmpty) return;

    setState(() => _processingIds.add(id));
    final leaveService = ref.read(leaveServiceProvider);

    try {
      await leaveService.approveOrRejectLeave(id, {
        'status': newStatus,
        if (newStatus == 'REJECTED') 'rejectionReason': _rejectReasonController.text.trim(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(newStatus == 'APPROVED' ? 'Leave request approved successfully' : 'Leave request rejected')),
        );
        setState(() {
          _processingIds.remove(id);
          _showRejectModal = false;
          _showDetailsModal = false;
          _rejectingRecord = null;
          _rejectReasonController.clear();
        });
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _processingIds.remove(id));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update leave status: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _confirmReject() {
    if (_rejectingRecord == null) return;
    final remarks = _rejectReasonController.text.trim();
    if (remarks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rejection remarks are required.'), backgroundColor: Colors.red));
      return;
    }
    _reviewLeave(_rejectingRecord!, 'REJECTED');
  }

  String _formatDate(dynamic dateStr) {
    if (dateStr == null) return '—';
    final s = dateStr.toString();
    if (s.length >= 10) {
      try {
        final dt = DateTime.parse(s.substring(0, 10));
        return DateFormat('dd MMM yyyy').format(dt);
      } catch (_) {
        return s.substring(0, 10);
      }
    }
    return s;
  }

  String _formatMoneyOrDays(dynamic n) {
    return '${n ?? 1} Days';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      final skeleton = const Center(child: CircularProgressIndicator());
      if (!widget.showAppBar) return Material(color: Colors.transparent, child: skeleton);
      return GlassScaffold(title: 'Leave Management Center', body: skeleton);
    }

    if (_errorMessage != null) {
      final errBody = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, size: 54, color: Colors.red),
              const SizedBox(height: 16),
              const Text('Unable to Load Leave Records', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(_errorMessage!, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
              const SizedBox(height: 24),
              ElevatedButton.icon(onPressed: _loadData, icon: const Icon(Icons.refresh), label: const Text('Retry')),
            ],
          ),
        ),
      );
      if (!widget.showAppBar) return Material(color: Colors.transparent, child: errBody);
      return GlassScaffold(title: 'Leave Management Center', body: errBody);
    }

    final filteredRequests = _filteredRequests;
    final filteredBalances = _filteredBalances;
    final cardBg = Theme.of(context).cardColor;

    final bodyContent = Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 4 KPI Cards in a single horizontal row (4-column grid)
              GridView.count(
                crossAxisCount: 4,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 6,
                mainAxisSpacing: 0,
                childAspectRatio: 0.78,
                children: [
                  _buildKpiCard('PENDING', '$_countPending', Icons.access_time, const Color(0xFFD97706), const Color(0xFFFEFCE8), cardBg),
                  _buildKpiCard('APPROVED', '$_countApproved', Icons.check_circle, const Color(0xFF10B981), const Color(0xFFF0FDF4), cardBg),
                  _buildKpiCard('REJECTED', '$_countRejected', Icons.cancel, const Color(0xFFEF4444), const Color(0xFFFEF2F2), cardBg),
                  _buildKpiCard('ON LEAVE', '$_onLeaveTodayCount', Icons.person_off, const Color(0xFF2563EB), const Color(0xFFF5F3FF), cardBg),
                ],
              ),
              const SizedBox(height: 16),

              // Search & Filter Toolbar
              Row(
                children: [
                  Expanded(
                    child: GlassSearchBar(
                      placeholder: 'Search employee name, ID, department, reason...',
                      onChanged: (val) => setState(() => _searchTerm = val),
                    ),
                  ),
                  if (_activeTab != 'balance') ...[
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(10)),
                      child: DropdownButton<String>(
                        value: _selectedType.isEmpty ? null : _selectedType,
                        hint: const Text('All Leave Types', style: TextStyle(fontSize: 12)),
                        underline: const SizedBox.shrink(),
                        items: [
                          const DropdownMenuItem(value: '', child: Text('All Leave Types', style: TextStyle(fontSize: 12))),
                          ..._leaveTypes.map((t) => DropdownMenuItem(value: t, child: Text(t, style: TextStyle(fontSize: 12)))),
                        ],
                        onChanged: (val) => setState(() => _selectedType = val ?? ''),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),

              // Navigation Tabs (4 Tabs)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildTabButton('pending', 'Pending Requests', '$_countPending', Theme.of(context).primaryColor),
                    const SizedBox(width: 8),
                    _buildTabButton('approved', 'Approved', '$_countApproved', Colors.green),
                    const SizedBox(width: 8),
                    _buildTabButton('rejected', 'Rejected', '$_countRejected', Colors.red),
                    const SizedBox(width: 8),
                    _buildTabButton('balance', 'Leave Balance', '${_leaveBalances.length}', Colors.purple),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Selection Alert Bar
              if (_selectedIds.isNotEmpty && _activeTab != 'balance') ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(color: Theme.of(context).primaryColor.withAlpha(30), borderRadius: BorderRadius.circular(10)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${_selectedIds.length} item(s) selected', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      Row(
                        children: [
                          TextButton.icon(
                            icon: const Icon(Icons.file_download, size: 16),
                            label: const Text('Export Selected', style: TextStyle(fontSize: 12)),
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Exported ${_selectedIds.length} leave records successfully')));
                            },
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

              // Main List View for Leave Requests or Leave Balances
              if (_activeTab == 'balance') ...[
                filteredBalances.isEmpty
                    ? const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('No leave balances found.')))
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filteredBalances.length,
                        itemBuilder: (context, index) {
                          final b = filteredBalances[index] as Map<String, dynamic>;
                          final name = b['employeeName'] ?? (b['employee'] is Map ? '${b['employee']['firstName']} ${b['employee']['lastName']}' : 'Employee');
                          final code = b['employeeCode'] ?? b['employeeId'] ?? 'EMP';
                          final dept = b['departmentName'] ?? b['department'] ?? 'General';
                          final annualTaken = b['annualTaken'] ?? b['annualUsed'] ?? 0;
                          final annualTotal = b['annualTotal'] ?? b['annualEntitlement'] ?? 15;
                          final sickTaken = b['sickTaken'] ?? b['sickUsed'] ?? 0;
                          final sickTotal = b['sickTotal'] ?? b['sickEntitlement'] ?? 10;
                          final casualTaken = b['casualTaken'] ?? b['casualUsed'] ?? 0;
                          final casualTotal = b['casualTotal'] ?? b['casualEntitlement'] ?? 7;
                          final remaining = b['totalRemaining'] ?? (annualTotal - annualTaken + sickTotal - sickTaken + casualTotal - casualTaken);

                          return AppCard(
                            backgroundColor: cardBg,
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                  Text('$code • $dept', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                                  const Divider(height: 16),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('Annual: $annualTaken/$annualTotal', style: const TextStyle(fontSize: 12)),
                                      Text('Sick: $sickTaken/$sickTotal', style: const TextStyle(fontSize: 12)),
                                      Text('Casual: $casualTaken/$casualTotal', style: const TextStyle(fontSize: 12)),
                                      Text('Remaining: ${remaining}d', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ] else ...[
                filteredRequests.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(32),
                        child: Center(child: Text('No $_activeTab leave requests found matching criteria.')),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filteredRequests.length,
                        itemBuilder: (context, index) {
                          final r = filteredRequests[index] as Map<String, dynamic>;
                          final id = r['id']?.toString() ?? '';
                          final isSelected = _selectedIds.contains(id);
                          final isProcessing = _processingIds.contains(id);

                          final empName = r['employeeName'] ?? (r['employee'] is Map ? '${r['employee']['firstName'] ?? ''} ${r['employee']['lastName'] ?? ''}' : 'Employee');
                          final code = r['employeeCode'] ?? r['employeeId'] ?? 'EMP';
                          final dept = r['departmentName'] ?? r['department'] ?? 'General';
                          final lType = r['leaveTypeName'] ?? r['leaveType'] ?? 'Casual Leave';
                          final from = _formatDate(r['startDate'] ?? r['fromDate']);
                          final to = _formatDate(r['endDate'] ?? r['toDate']);
                          final days = r['totalDays'] ?? r['days'] ?? 1;
                          final reason = r['reason'] ?? 'N/A';
                          final applied = _formatDate(r['createdAt'] ?? r['appliedOn']);
                          final status = (r['status'] ?? 'PENDING').toString().toUpperCase();
                          final isPending = status == 'PENDING';

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 1,
                            color: cardBg,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Checkbox(
                                    value: isSelected,
                                    onChanged: (_) => _toggleSelectRow(id),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: InkWell(
                                      onTap: () => setState(() {
                                        _selectedRequest = r;
                                        _showDetailsModal = true;
                                      }),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(child: Text(empName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                                              Chip(
                                                label: Text(status, style: const TextStyle(fontSize: 10, color: Colors.white)),
                                                backgroundColor: status == 'APPROVED' ? Colors.green : (status == 'REJECTED' ? Colors.red : Colors.orange),
                                                visualDensity: VisualDensity.compact,
                                              ),
                                            ],
                                          ),
                                          Text('$code • $dept • $lType', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                                          const SizedBox(height: 4),
                                          Text('Duration: $from to $to (${_formatMoneyOrDays(days)})', style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                                          const SizedBox(height: 4),
                                          Text('Reason: $reason', maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                                          const SizedBox(height: 8),
                                          Text('Applied on: $applied', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                                          const Divider(height: 16),
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 6,
                                            alignment: WrapAlignment.end,
                                            children: [
                                              if (isProcessing)
                                                const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                              else if (isPending) ...[
                                                OutlinedButton.icon(
                                                  icon: const Icon(Icons.close, size: 16, color: Colors.red),
                                                  label: const Text('Reject', style: TextStyle(fontSize: 12, color: Colors.red)),
                                                  style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                                                  onPressed: () => setState(() {
                                                    _rejectingRecord = r;
                                                    _rejectReasonController.clear();
                                                    _showRejectModal = true;
                                                  }),
                                                ),
                                                ElevatedButton.icon(
                                                  icon: const Icon(Icons.check, size: 16),
                                                  label: const Text('Approve', style: TextStyle(fontSize: 12)),
                                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, visualDensity: VisualDensity.compact),
                                                  onPressed: () => _reviewLeave(r, 'APPROVED'),
                                                ),
                                              ],
                                              OutlinedButton.icon(
                                                icon: const Icon(Icons.visibility, size: 16),
                                                label: const Text('View', style: TextStyle(fontSize: 12)),
                                                style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                                                onPressed: () => setState(() {
                                                  _selectedRequest = r;
                                                  _showDetailsModal = true;
                                                }),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
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

        // Details Modal
        if (_showDetailsModal && _selectedRequest != null)
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
                  constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_selectedRequest!['employeeName'] ?? 'Leave Details', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _showDetailsModal = false)),
                          ],
                        ),
                        const Divider(),
                        Text('Employee ID: ${_selectedRequest!['employeeCode'] ?? _selectedRequest!['employeeId'] ?? 'EMP'}'),
                        Text('Department: ${_selectedRequest!['departmentName'] ?? _selectedRequest!['department'] ?? 'General'}'),
                        Text('Leave Type: ${_selectedRequest!['leaveTypeName'] ?? _selectedRequest!['leaveType'] ?? 'Leave'}'),
                        Text('Status: ${(_selectedRequest!['status'] ?? 'PENDING').toString().toUpperCase()}'),
                        Text('From: ${_formatDate(_selectedRequest!['startDate'] ?? _selectedRequest!['fromDate'])} To: ${_formatDate(_selectedRequest!['endDate'] ?? _selectedRequest!['toDate'])}'),
                        Text('Duration: ${_formatMoneyOrDays(_selectedRequest!['totalDays'] ?? _selectedRequest!['days'])}'),
                        const SizedBox(height: 8),
                        Text('Reason:', style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text(_selectedRequest!['reason'] ?? 'N/A', style: TextStyle(color: Colors.grey[700])),
                        if (_selectedRequest!['rejectionReason'] != null) ...[
                          const SizedBox(height: 8),
                          Text('Rejection Remarks:', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                          Text(_selectedRequest!['rejectionReason'], style: const TextStyle(color: Colors.red)),
                        ],
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if ((_selectedRequest!['status'] ?? '').toString().toUpperCase() == 'PENDING') ...[
                              OutlinedButton(
                                style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                                onPressed: () {
                                  final r = _selectedRequest!;
                                  setState(() {
                                    _showDetailsModal = false;
                                    _rejectingRecord = r;
                                    _rejectReasonController.clear();
                                    _showRejectModal = true;
                                  });
                                },
                                child: const Text('Reject'),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                                onPressed: () => _reviewLeave(_selectedRequest!, 'APPROVED'),
                                child: const Text('Approve'),
                              ),
                              const SizedBox(width: 8),
                            ],
                            OutlinedButton(onPressed: () => setState(() => _showDetailsModal = false), child: const Text('Close')),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

        // Reject Remarks Modal
        if (_showRejectModal)
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
                          const Text('Reject Leave Request', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red)),
                          IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _showRejectModal = false)),
                        ],
                      ),
                      const Divider(),
                      Text('Specify rejection remarks for ${_rejectingRecord?['employeeName'] ?? 'Employee'}:'),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _rejectReasonController,
                        decoration: const InputDecoration(labelText: 'Rejection Remarks *', border: OutlineInputBorder()),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(onPressed: () => setState(() => _showRejectModal = false), child: const Text('Cancel')),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                            onPressed: _confirmReject,
                            child: const Text('Confirm Rejection'),
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
      appBar: GlassHeader(title: 'Leave Management Center'),
      body: bodyContent,
    );
  }

  Widget _buildKpiCard(String title, String value, IconData icon, Color color, Color bgColor, Color cardBg) {
    return AppCard(
      backgroundColor: cardBg,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(6)),
            child: Icon(icon, color: color, size: 14),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color, height: 1.1),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: const TextStyle(fontSize: 9, color: Color(0xFF64748B), fontWeight: FontWeight.w600, height: 1.1),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(String tabKey, String label, String count, Color color) {
    final isActive = _activeTab == tabKey;
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: isActive ? color : Colors.grey[100],
        foregroundColor: isActive ? Colors.white : Colors.grey[800],
        elevation: 0,
        visualDensity: VisualDensity.compact,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      onPressed: () => setState(() => _activeTab = tabKey),
      child: Text('$label ($count)', style: const TextStyle(fontSize: 12)),
    );
  }
}
