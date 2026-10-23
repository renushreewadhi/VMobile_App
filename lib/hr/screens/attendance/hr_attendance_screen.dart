import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/loading_shimmer.dart';

class HrAttendanceScreen extends ConsumerStatefulWidget {
  const HrAttendanceScreen({super.key});

  @override
  ConsumerState<HrAttendanceScreen> createState() => _HrAttendanceScreenState();
}

class _HrAttendanceScreenState extends ConsumerState<HrAttendanceScreen> {
  bool _isLoading = true;
  List<dynamic> _attendanceRecords = [];
  List<dynamic> _employeesList = [];
  List<String> _departmentsList = ['Engineering', 'Marketing', 'Human Resources', 'Sales', 'Finance', 'Design'];
  
  String _selectedDate = DateTime.now().toIso8601String().substring(0, 10);
  String _searchTerm = '';
  String _selectedDepartment = '';
  String _selectedStatus = '';
  final Set<String> _selectedIds = {};

  // Correction Modal State
  bool _showCorrectionModal = false;
  Map<String, dynamic> _correctionForm = {
    'attendanceId': '',
    'employeeId': '',
    'employeeName': '',
    'date': '',
    'checkIn': '09:00',
    'checkOut': '18:00',
    'reason': '',
  };

  // Mark Attendance Modal State
  bool _showMarkModal = false;
  Map<String, dynamic> _markForm = {
    'employeeId': '',
    'date': DateTime.now().toIso8601String().substring(0, 10),
    'checkIn': '09:00',
    'checkOut': '18:00',
    'status': 'Present',
  };

  // Verification Modal State
  bool _showVerificationModal = false;
  Map<String, dynamic>? _selectedVerificationRecord;
  bool _isProcessingVerification = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final apiClient = ref.read(apiClientProvider);

    try {
      final empRes = await apiClient.get(ApiEndpoints.employees).catchError((_) => null);
      if (empRes is List) {
        _employeesList = empRes;
      } else if (empRes is Map<String, dynamic> && empRes['data'] is List) {
        _employeesList = empRes['data'];
      }

      final attRes = await apiClient.get(ApiEndpoints.attendanceSummary, queryParams: {'date': _selectedDate}).catchError((_) => null);
      List<dynamic> rawItems = [];
      if (attRes is List) {
        rawItems = attRes;
      } else if (attRes is Map<String, dynamic>) {
        rawItems = attRes['items'] ?? attRes['data'] ?? [];
      }

      setState(() {
        _attendanceRecords = rawItems;
        _isLoading = false;
      });
    } catch (_) {
      setState(() {
        _attendanceRecords = [];
        _isLoading = false;
      });
    }
  }

  List<dynamic> get _filteredRecords {
    return _attendanceRecords.where((r) {
      final map = r is Map<String, dynamic> ? r : {};
      final name = (map['employeeName'] ?? map['name'] ?? '').toString().toLowerCase();
      final empId = (map['employeeCode'] ?? map['employeeId'] ?? '').toString().toLowerCase();
      final dept = (map['department'] ?? map['departmentName'] ?? '').toString();
      final status = (map['status'] ?? 'Present').toString();

      final matchesSearch = _searchTerm.isEmpty || name.contains(_searchTerm.toLowerCase()) || empId.contains(_searchTerm.toLowerCase());
      final matchesDept = _selectedDepartment.isEmpty || dept == _selectedDepartment;
      final matchesStatus = _selectedStatus.isEmpty || status.toLowerCase() == _selectedStatus.toLowerCase();

      return matchesSearch && matchesDept && matchesStatus;
    }).toList();
  }

  int get _presentCount => _attendanceRecords.where((r) => (r['status'] ?? '').toString().toLowerCase() == 'present').length;
  int get _absentCount => _attendanceRecords.where((r) => (r['status'] ?? '').toString().toLowerCase() == 'absent').length;
  int get _lateCount => _attendanceRecords.where((r) => (r['status'] ?? '').toString().toLowerCase() == 'late').length;
  int get _leaveCount => _attendanceRecords.where((r) => (r['status'] ?? '').toString().toLowerCase() == 'on leave').length;
  int get _wfhCount => _attendanceRecords.where((r) => (r['status'] ?? '').toString().toLowerCase() == 'work from home' || r['isWfh'] == true).length;

  void _openCorrection(Map<String, dynamic> rec) {
    setState(() {
      _correctionForm = {
        'attendanceId': rec['id'] ?? '',
        'employeeId': rec['employeeId'] ?? rec['employeeGuid'] ?? '',
        'employeeName': rec['employeeName'] ?? rec['name'] ?? 'Employee',
        'date': rec['date'] ?? _selectedDate,
        'checkIn': '09:00',
        'checkOut': '18:00',
        'reason': '',
      };
      _showCorrectionModal = true;
    });
  }

  Future<void> _submitCorrection() async {
    final apiClient = ref.read(apiClientProvider);
    try {
      await apiClient.post('/attendance/correction', body: _correctionForm);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Attendance correction request submitted')));
        setState(() => _showCorrectionModal = false);
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to submit correction: $e')));
      }
    }
  }

  Future<void> _submitMarkAttendance() async {
    final apiClient = ref.read(apiClientProvider);
    try {
      await apiClient.post('/attendance/manual-adjust', body: _markForm);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Attendance marked successfully')));
        setState(() => _showMarkModal = false);
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to mark attendance: $e')));
      }
    }
  }

  Future<void> _approveVerification() async {
    if (_selectedVerificationRecord == null) return;
    setState(() => _isProcessingVerification = true);
    final apiClient = ref.read(apiClientProvider);
    try {
      final id = _selectedVerificationRecord!['id'];
      await apiClient.post('/attendance/verification/$id/approve', body: {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Attendance verification approved')));
        setState(() {
          _isProcessingVerification = false;
          _showVerificationModal = false;
        });
        _loadData();
      }
    } catch (e) {
      setState(() => _isProcessingVerification = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to approve: $e')));
      }
    }
  }

  Future<void> _rejectVerification() async {
    if (_selectedVerificationRecord == null) return;
    setState(() => _isProcessingVerification = true);
    final apiClient = ref.read(apiClientProvider);
    try {
      final id = _selectedVerificationRecord!['id'];
      await apiClient.post('/attendance/verification/$id/reject', body: {'reason': 'Rejected by HR'});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Attendance verification rejected')));
        setState(() {
          _isProcessingVerification = false;
          _showVerificationModal = false;
        });
        _loadData();
      }
    } catch (e) {
      setState(() => _isProcessingVerification = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to reject: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const LoadingShimmer();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download),
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Exporting attendance report...'))),
          ),
          IconButton(
            icon: const Icon(Icons.add_box),
            onPressed: () => setState(() => _showMarkModal = true),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Metrics Row
            Row(
              children: [
                Expanded(child: _buildMetricCard('Present', '$_presentCount', Colors.green, Icons.how_to_reg)),
                const SizedBox(width: 8),
                Expanded(child: _buildMetricCard('Absent', '$_absentCount', Colors.red, Icons.person_off)),
                const SizedBox(width: 8),
                Expanded(child: _buildMetricCard('Late', '$_lateCount', Colors.orange, Icons.access_time)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _buildMetricCard('On Leave', '$_leaveCount', Colors.blue, Icons.beach_access)),
                const SizedBox(width: 8),
                Expanded(child: _buildMetricCard('WFH', '$_wfhCount', Colors.purple, Icons.home_work)),
              ],
            ),
            const SizedBox(height: 16),
            // Filter Bar
            TextField(
              decoration: const InputDecoration(
                labelText: 'Search employee name or ID',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (val) => setState(() => _searchTerm = val),
            ),
            const SizedBox(height: 16),
            // Records List
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _filteredRecords.length,
              itemBuilder: (context, index) {
                final rec = _filteredRecords[index] as Map<String, dynamic>;
                return AppCard(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primary.withOpacity(0.1),
                      child: Text((rec['employeeName'] ?? 'E')[0]),
                    ),
                    title: Text(rec['employeeName'] ?? 'Employee', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('${rec['employeeCode'] ?? ''} • ${rec['department'] ?? 'General'}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Chip(label: Text(rec['status'] ?? 'Present')),
                        IconButton(
                          icon: const Icon(Icons.edit, size: 20),
                          onPressed: () => _openCorrection(rec),
                        ),
                      ],
                    ),
                    onTap: () {
                      setState(() {
                        _selectedVerificationRecord = rec;
                        _showVerificationModal = true;
                      });
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(String label, String value, Color color, IconData icon) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }
}
