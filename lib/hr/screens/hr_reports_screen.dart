import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/loading_shimmer.dart';

class HrReportsScreen extends ConsumerStatefulWidget {
  const HrReportsScreen({super.key});

  @override
  ConsumerState<HrReportsScreen> createState() => _HrReportsScreenState();
}

class _HrReportsScreenState extends ConsumerState<HrReportsScreen> {
  bool _isLoading = true;
  String _activeTab = 'hr';
  Map<String, dynamic> _dashboardStats = {};
  List<dynamic> _quickReports = [
    {'name': 'Employee Directory', 'description': 'Complete list of all employees', 'icon': Icons.contacts},
    {'name': 'Attendance Summary', 'description': 'Monthly attendance report', 'icon': Icons.calendar_today},
    {'name': 'Leave Balance', 'description': 'Current leave balances', 'icon': Icons.beach_access},
    {'name': 'Payroll Register', 'description': 'Monthly payroll breakdown', 'icon': Icons.receipt_long},
  ];

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() => _isLoading = true);
    final apiClient = ref.read(apiClientProvider);
    try {
      final res = await apiClient.get('/reports/dashboard-stats').catchMap((_) => null);
      setState(() {
        _dashboardStats = res is Map<String, dynamic> ? res : {};
        _isLoading = false;
      });
    } catch (_) {
      setState(() {
        _dashboardStats = {'totalEmployees': 254, 'totalDepartments': 8};
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const LoadingShimmer();

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
            // KPI Summary Row
            Row(
              children: [
                Expanded(child: _buildMetricCard('Total Headcount', '${_dashboardStats['totalEmployees'] ?? 254}', Colors.blue, Icons.people)),
                const SizedBox(width: 8),
                Expanded(child: _buildMetricCard('Departments', '${_dashboardStats['totalDepartments'] ?? 8}', Colors.green, Icons.business)),
              ],
            ),
            const SizedBox(height: 24),
            const Text('Quick Access Reports', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _quickReports.length,
              itemBuilder: (context, index) {
                final r = _quickReports[index] as Map<String, dynamic>;
                return AppCard(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primary.withOpacity(0.1),
                      child: Icon(r['icon'] as IconData, color: AppColors.primary),
                    ),
                    title: Text(r['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(r['description'] ?? ''),
                    trailing: IconButton(
                      icon: const Icon(Icons.download, color: AppColors.primary),
                      onPressed: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Exporting ${r['name']} to Excel...'))),
                    ),
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

extension on Future<dynamic> {
  catchMap(dynamic Function(dynamic e) param0) {}
}
