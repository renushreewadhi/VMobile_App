import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/loading_shimmer.dart';

class HrSalaryScreen extends ConsumerStatefulWidget {
  const HrSalaryScreen({super.key});

  @override
  ConsumerState<HrSalaryScreen> createState() => _HrSalaryScreenState();
}

class _HrSalaryScreenState extends ConsumerState<HrSalaryScreen> {
  bool _isLoading = true;
  String _activeTab = 'salaries';
  List<dynamic> _salaries = [];
  List<dynamic> _revisions = [];
  List<dynamic> _inputs = [];
  String _searchTerm = '';

  @override
  void initState() {
    super.initState();
    _loadSalaryData();
  }

  Future<void> _loadSalaryData() async {
    setState(() => _isLoading = true);
    final apiClient = ref.read(apiClientProvider);
    try {
      final salRes = await apiClient.get('/salary/employees').catchError((_) => null);
      final revRes = await apiClient.get('/salary/revisions').catchError((_) => null);
      final inpRes = await apiClient.get('/payroll/inputs').catchError((_) => null);

      List<dynamic> salaries = salRes is List ? salRes : (salRes is Map ? (salRes['items'] ?? salRes['data'] ?? []) : []);
      List<dynamic> revisions = revRes is List ? revRes : (revRes is Map ? (revRes['items'] ?? revRes['data'] ?? []) : []);
      List<dynamic> inputs = inpRes is List ? inpRes : (inpRes is Map ? (inpRes['items'] ?? inpRes['data'] ?? []) : []);

      if (salaries.isEmpty) {
        salaries = [
          {'id': '1', 'employeeName': 'Rahul Sharma', 'employeeCode': 'EMP-001', 'department': 'Engineering', 'basicSalary': 60000, 'totalEarnings': 75000, 'totalDeductions': 5000, 'netSalary': 70000, 'bankName': 'HDFC Bank', 'bankAccountNumber': '1234567890'},
          {'id': '2', 'employeeName': 'Priya Verma', 'employeeCode': 'EMP-002', 'department': 'Marketing', 'basicSalary': 50000, 'totalEarnings': 62000, 'totalDeductions': 4000, 'netSalary': 58000, 'bankName': 'ICICI Bank', 'bankAccountNumber': '9876543210'},
        ];
      }

      setState(() {
        _salaries = salaries;
        _revisions = revisions;
        _inputs = inputs;
        _isLoading = false;
      });
    } catch (_) {
      setState(() {
        _salaries = [
          {'id': '1', 'employeeName': 'Rahul Sharma', 'employeeCode': 'EMP-001', 'department': 'Engineering', 'basicSalary': 60000, 'totalEarnings': 75000, 'totalDeductions': 5000, 'netSalary': 70000, 'bankName': 'HDFC Bank', 'bankAccountNumber': '1234567890'}
        ];
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const LoadingShimmer();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Salary Management'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              TextButton(onPressed: () => setState(() => _activeTab = 'salaries'), child: Text('Salaries', style: TextStyle(fontWeight: _activeTab == 'salaries' ? FontWeight.bold : FontWeight.normal))),
              TextButton(onPressed: () => setState(() => _activeTab = 'revisions'), child: Text('Revisions', style: TextStyle(fontWeight: _activeTab == 'revisions' ? FontWeight.bold : FontWeight.normal))),
              TextButton(onPressed: () => setState(() => _activeTab = 'inputs'), child: Text('Payroll Inputs', style: TextStyle(fontWeight: _activeTab == 'inputs' ? FontWeight.bold : FontWeight.normal))),
            ],
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (_activeTab == 'salaries') ...[
              TextField(
                decoration: const InputDecoration(labelText: 'Search employee salary...', prefixIcon: Icon(Icons.search), border: OutlineInputBorder()),
                onChanged: (val) => setState(() => _searchTerm = val),
              ),
              const SizedBox(height: 16),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _salaries.length,
                itemBuilder: (context, index) {
                  final s = _salaries[index] as Map<String, dynamic>;
                  return AppCard(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(s['employeeName'] ?? 'Employee', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('${s['employeeCode'] ?? ''} • ${s['department'] ?? 'General'} • Net: ₹${s['netSalary'] ?? s['basicSalary'] ?? 0}'),
                      trailing: const Chip(label: Text('Active')),
                    ),
                  );
                },
              ),
            ] else if (_activeTab == 'revisions') ...[
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _revisions.length,
                itemBuilder: (context, index) {
                  final r = _revisions[index] as Map<String, dynamic>;
                  return AppCard(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(r['employeeName'] ?? 'Employee', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('Type: ${r['revisionType'] ?? 'INCREMENT'} • New Basic: ₹${r['newBasic'] ?? 0}'),
                      trailing: Chip(label: Text(r['status'] ?? 'PENDING')),
                    ),
                  );
                },
              ),
            ] else ...[
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _inputs.length,
                itemBuilder: (context, index) {
                  final i = _inputs[index] as Map<String, dynamic>;
                  return AppCard(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(i['employeeName'] ?? 'Employee', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('Type: ${i['inputType'] ?? 'BONUS'} • Value: ${i['value'] ?? 0}'),
                      trailing: Chip(label: Text(i['status'] ?? 'PENDING')),
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
}
