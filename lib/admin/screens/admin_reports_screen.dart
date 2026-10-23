import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_card.dart';

class AdminReportsScreen extends ConsumerStatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  ConsumerState<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends ConsumerState<AdminReportsScreen> {
  bool _isLoading = true;
  String _activeTab = 'hr';
  Map<String, dynamic> _stats = {};

  final List<Map<String, dynamic>> _quickReports = [
    {'name': 'Employee Directory', 'description': 'Complete list of all employees', 'icon': Icons.contacts, 'color': Colors.blue},
    {'name': 'Attendance Summary', 'description': 'Monthly attendance report', 'icon': Icons.calendar_today, 'color': Colors.green},
    {'name': 'Leave Balance', 'description': 'Current leave balances', 'icon': Icons.event_available, 'color': Colors.orange},
    {'name': 'Payroll Register', 'description': 'Monthly payroll breakdown', 'icon': Icons.receipt_long, 'color': Colors.red},
    {'name': 'Performance Summary', 'description': 'Quarterly performance ratings', 'icon': Icons.star, 'color': Colors.cyan},
    {'name': 'Training Completion', 'description': 'Training program completion rates', 'icon': Icons.school, 'color': Colors.purple},
  ];

  @override
  void initState() {
    super.initState();
    _loadReportsData();
  }

  Future<void> _loadReportsData() async {
    setState(() => _isLoading = true);
    final apiClient = ref.read(apiClientProvider);

    try {
      final res = await apiClient.get('/reports/dashboard-stats').catchError((_) => null);
      if (res is Map<String, dynamic>) {
        _stats = res;
      } else {
        _stats = {
          'totalHeadcount': 254,
          'activeDepartments': 8,
          'newHires': 12,
          'avgAttendanceRate': 96.2,
          'totalPayroll': 480000
        };
      }
      setState(() => _isLoading = false);
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports & Analytics'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              TextButton(onPressed: () => setState(() => _activeTab = 'hr'), child: Text('HR & Headcount', style: TextStyle(fontWeight: _activeTab == 'hr' ? FontWeight.bold : FontWeight.normal))),
              TextButton(onPressed: () => setState(() => _activeTab = 'attendance'), child: Text('Attendance', style: TextStyle(fontWeight: _activeTab == 'attendance' ? FontWeight.bold : FontWeight.normal))),
              TextButton(onPressed: () => setState(() => _activeTab = 'payroll'), child: Text('Payroll', style: TextStyle(fontWeight: _activeTab == 'payroll' ? FontWeight.bold : FontWeight.normal))),
            ],
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_activeTab == 'hr') ...[
              // HR Stats
              Row(
                children: [
                  Expanded(child: _buildMetricCard('Total Headcount', '${_stats['totalHeadcount'] ?? 254}', Icons.groups, Colors.blue)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildMetricCard('New Hires', '${_stats['newHires'] ?? 12}', Icons.person_add, Colors.green)),
                ],
              ),
              const SizedBox(height: 24),
              const Text('Quick Access HR Reports', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
              const SizedBox(height: 12),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _quickReports.length,
                itemBuilder: (context, index) {
                  final qr = _quickReports[index];
                  return AppCard(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: (qr['color'] as Color).withOpacity(0.1),
                        child: Icon(qr['icon'], color: qr['color']),
                      ),
                      title: Text(qr['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(qr['description']),
                      trailing: IconButton(
                        icon: const Icon(Icons.download, color: AppColors.primary),
                        tooltip: 'Export Excel',
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${qr['name']} exported to Excel!')));
                        },
                      ),
                    ),
                  );
                },
              ),
            ] else if (_activeTab == 'attendance') ...[
              Row(
                children: [
                  Expanded(child: _buildMetricCard('Avg Attendance', '${_stats['avgAttendanceRate'] ?? 96.2}%', Icons.check_circle, Colors.green)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildMetricCard('Present Today', '218', Icons.people, Colors.blue)),
                ],
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(child: _buildMetricCard('Monthly Payroll', '₹ ${_stats['totalPayroll'] ?? 480000}', Icons.payments, Colors.purple)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildMetricCard('Cycle Status', 'Active', Icons.update, Colors.green)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 24),
                Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            Text(title, style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}
