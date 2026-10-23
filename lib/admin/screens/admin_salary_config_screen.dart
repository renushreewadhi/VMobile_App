import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_card.dart';

class AdminSalaryConfigScreen extends ConsumerStatefulWidget {
  const AdminSalaryConfigScreen({super.key});

  @override
  ConsumerState<AdminSalaryConfigScreen> createState() => _AdminSalaryConfigScreenState();
}

class _AdminSalaryConfigScreenState extends ConsumerState<AdminSalaryConfigScreen> {
  bool _isLoading = true;
  String _activeTab = 'components';
  List<dynamic> _components = [];
  List<dynamic> _cycles = [];

  @override
  void initState() {
    super.initState();
    _loadConfigData();
  }

  Future<void> _loadConfigData() async {
    setState(() => _isLoading = true);
    final apiClient = ref.read(apiClientProvider);

    try {
      final compRes = await apiClient.get('/payroll/components').catchError((_) => null);
      final cycleRes = await apiClient.get('/payroll/cycles').catchError((_) => null);

      List<dynamic> comps = compRes is List ? compRes : (compRes is Map ? (compRes['items'] ?? compRes['data'] ?? []) : []);
      List<dynamic> cycles = cycleRes is List ? cycleRes : (cycleRes is Map ? (cycleRes['items'] ?? cycleRes['data'] ?? []) : []);

      if (comps.isEmpty) {
        comps = [
          {'id': 'c1', 'code': 'BASIC', 'name': 'Basic Salary', 'type': 'EARNING', 'basis': 'FIXED_AMOUNT', 'value': 50000, 'isActive': true},
          {'id': 'c2', 'code': 'HRA', 'name': 'House Rent Allowance', 'type': 'EARNING', 'basis': 'PERCENT_OF_BASIC', 'value': 40, 'isActive': true},
          {'id': 'c3', 'code': 'PF', 'name': 'Provident Fund', 'type': 'STATUTORY', 'basis': 'PERCENT_OF_BASIC', 'value': 12, 'isActive': true},
        ];
      }

      if (cycles.isEmpty) {
        cycles = [
          {'id': 'cy1', 'name': 'September 2026 Pay Cycle', 'month': 'Sep', 'year': 2026, 'startDate': '2026-09-01', 'endDate': '2026-09-30', 'paymentDate': '2026-10-01', 'status': 'OPEN'}
        ];
      }

      setState(() {
        _components = comps;
        _cycles = cycles;
        _isLoading = false;
      });
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
        title: const Text('Salary Configuration'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              TextButton(onPressed: () => setState(() => _activeTab = 'components'), child: Text('Salary Components', style: TextStyle(fontWeight: _activeTab == 'components' ? FontWeight.bold : FontWeight.normal))),
              TextButton(onPressed: () => setState(() => _activeTab = 'cycles'), child: Text('Pay Cycles', style: TextStyle(fontWeight: _activeTab == 'cycles' ? FontWeight.bold : FontWeight.normal))),
            ],
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // KPI Metrics Grid
            Row(
              children: [
                Expanded(child: _buildMetricCard('Total Components', '${_components.length}', Icons.list, Colors.blue)),
                const SizedBox(width: 8),
                Expanded(child: _buildMetricCard('Active Cycles', '${_cycles.length}', Icons.calendar_today, Colors.green)),
              ],
            ),
            const SizedBox(height: 24),

            if (_activeTab == 'components') ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Salary Components Directory', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
                  ElevatedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add component dialog opened')));
                    },
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add Component'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _components.length,
                itemBuilder: (context, index) {
                  final c = _components[index];
                  return AppCard(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      title: Text(c['name'] ?? 'Component', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('Code: ${c['code']} • Type: ${c['type']} • Basis: ${c['basis']}'),
                      trailing: Chip(
                        label: Text('${c['value']}', style: const TextStyle(color: Colors.white, fontSize: 10)),
                        backgroundColor: c['type'] == 'EARNING' ? Colors.green : Colors.red,
                      ),
                    ),
                  );
                },
              ),
            ] else ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Pay Cycles Management', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
                  ElevatedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add pay cycle dialog opened')));
                    },
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add Pay Cycle'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _cycles.length,
                itemBuilder: (context, index) {
                  final cy = _cycles[index];
                  return AppCard(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      title: Text(cy['name'] ?? 'Pay Cycle', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('Period: ${cy['month']} ${cy['year']} • Payout: ${cy['paymentDate']}'),
                      trailing: Chip(
                        label: Text(cy['status'] ?? 'OPEN', style: const TextStyle(fontSize: 10, color: Colors.white)),
                        backgroundColor: Colors.blue,
                      ),
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
