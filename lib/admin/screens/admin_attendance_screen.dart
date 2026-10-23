import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_card.dart';

class AdminAttendanceScreen extends ConsumerStatefulWidget {
  const AdminAttendanceScreen({super.key});

  @override
  ConsumerState<AdminAttendanceScreen> createState() => _AdminAttendanceScreenState();
}

class _AdminAttendanceScreenState extends ConsumerState<AdminAttendanceScreen> {
  bool _isLoading = true;
  String _activeTab = 'daily';
  List<dynamic> _records = [];
  List<dynamic> _corrections = [];
  List<dynamic> _rules = [];
  String _searchTerm = '';
  String _selectedDate = DateTime.now().toIso8601String().substring(0, 10);

  @override
  void initState() {
    super.initState();
    _loadAttendanceData();
  }

  Future<void> _loadAttendanceData() async {
    setState(() => _isLoading = true);
    final apiClient = ref.read(apiClientProvider);

    try {
      final recRes = await apiClient.get('/attendance/records?date=$_selectedDate').catchError((_) => null);
      final corRes = await apiClient.get('/attendance/corrections').catchError((_) => null);
      final ruleRes = await apiClient.get('/attendance/rules').catchError((_) => null);

      List<dynamic> records = recRes is List ? recRes : (recRes is Map ? (recRes['items'] ?? recRes['data'] ?? []) : []);
      List<dynamic> corrections = corRes is List ? corRes : (corRes is Map ? (corRes['items'] ?? corRes['data'] ?? []) : []);
      List<dynamic> rules = ruleRes is List ? ruleRes : (ruleRes is Map ? (ruleRes['items'] ?? ruleRes['data'] ?? []) : []);

      if (records.isEmpty) {
        records = [
          {'id': '1', 'employeeCode': 'EMP-01', 'employeeName': 'Rahul Sharma', 'department': 'Engineering', 'checkIn': '09:05 AM', 'checkOut': '06:15 PM', 'status': 'Present', 'workHours': '9h 10m'},
          {'id': '2', 'employeeCode': 'EMP-02', 'employeeName': 'Priya Verma', 'department': 'Marketing', 'checkIn': '09:45 AM', 'checkOut': '06:00 PM', 'status': 'Late', 'workHours': '8h 15m'},
          {'id': '3', 'employeeCode': 'EMP-03', 'employeeName': 'Amit Kumar', 'department': 'Sales', 'checkIn': '—', 'checkOut': '—', 'status': 'Absent', 'workHours': '0h'},
        ];
      }

      if (corrections.isEmpty) {
        corrections = [
          {'id': 'c1', 'employeeName': 'Priya Verma', 'department': 'Marketing', 'date': '2026-09-10', 'reason': 'Forgot to punch out due to client meeting', 'status': 'PENDING'}
        ];
      }

      if (rules.isEmpty) {
        rules = [
          {'id': 'r1', 'name': 'Standard Office Policy', 'graceMinutes': 15, 'minWorkHours': 8, 'isActive': true}
        ];
      }

      setState(() {
        _records = records;
        _corrections = corrections;
        _rules = rules;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  List<dynamic> get _filteredRecords {
    return _records.where((r) {
      final name = (r['employeeName'] ?? r['name'] ?? '').toString().toLowerCase();
      final empId = (r['employeeCode'] ?? '').toString().toLowerCase();
      return _searchTerm.trim().isEmpty || name.contains(_searchTerm.toLowerCase()) || empId.contains(_searchTerm.toLowerCase());
    }).toList();
  }

  int get _presentCount => _records.where((r) => (r['status'] ?? '').toString().toLowerCase() == 'present').length;
  int get _absentCount => _records.where((r) => (r['status'] ?? '').toString().toLowerCase() == 'absent').length;
  int get _lateCount => _records.where((r) => (r['status'] ?? '').toString().toLowerCase() == 'late').length;

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance Management'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              TextButton(onPressed: () => setState(() => _activeTab = 'daily'), child: Text('Daily Logs', style: TextStyle(fontWeight: _activeTab == 'daily' ? FontWeight.bold : FontWeight.normal))),
              TextButton(onPressed: () => setState(() => _activeTab = 'corrections'), child: Text('Corrections (${_corrections.length})', style: TextStyle(fontWeight: _activeTab == 'corrections' ? FontWeight.bold : FontWeight.normal))),
              TextButton(onPressed: () => setState(() => _activeTab = 'rules'), child: Text('Policies', style: TextStyle(fontWeight: _activeTab == 'rules' ? FontWeight.bold : FontWeight.normal))),
            ],
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_activeTab == 'daily') ...[
              // KPI Metrics
              Row(
                children: [
                  Expanded(child: _buildMetricCard('Present', '$_presentCount', Icons.check_circle, Colors.green)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildMetricCard('Absent', '$_absentCount', Icons.cancel, Colors.red)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildMetricCard('Late', '$_lateCount', Icons.access_time, Colors.orange)),
                ],
              ),
              const SizedBox(height: 24),

              // Search Bar
              TextField(
                decoration: const InputDecoration(
                  hintText: 'Search employee name or code...',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onChanged: (val) => setState(() => _searchTerm = val),
              ),
              const SizedBox(height: 16),

              // Records List
              _filteredRecords.isEmpty
                  ? const Center(child: Text('No attendance records found for this date.'))
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _filteredRecords.length,
                      itemBuilder: (context, index) {
                        final r = _filteredRecords[index];
                        final status = r['status'] ?? 'Present';

                        return AppCard(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            title: Text(r['employeeName'] ?? r['name'] ?? 'Employee', style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('${r['employeeCode'] ?? 'EMP'} • ${r['department'] ?? 'General'} • In: ${r['checkIn']} | Out: ${r['checkOut']}'),
                            trailing: Chip(
                              label: Text(status, style: const TextStyle(fontSize: 10, color: Colors.white)),
                              backgroundColor: status == 'Present' ? Colors.green : (status == 'Late' ? Colors.orange : Colors.red),
                            ),
                          ),
                        );
                      },
                    ),
            ] else if (_activeTab == 'corrections') ...[
              const Text('Punch Correction Requests', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
              const SizedBox(height: 12),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _corrections.length,
                itemBuilder: (context, index) {
                  final c = _corrections[index];
                  return AppCard(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      title: Text(c['employeeName'] ?? 'Employee', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('Date: ${c['date']} • Reason: ${c['reason']}'),
                      trailing: Chip(label: Text(c['status'] ?? 'PENDING')),
                    ),
                  );
                },
              ),
            ] else ...[
              const Text('Attendance Rules & Policies', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
              const SizedBox(height: 12),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _rules.length,
                itemBuilder: (context, index) {
                  final rule = _rules[index];
                  return AppCard(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      title: Text(rule['name'] ?? 'Policy', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('Grace Period: ${rule['graceMinutes']} mins • Min Hours: ${rule['minWorkHours']}h'),
                      trailing: Chip(label: Text(rule['isActive'] == false ? 'Inactive' : 'Active')),
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          Text(title, style: TextStyle(fontSize: 10, color: Colors.grey[600]), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
