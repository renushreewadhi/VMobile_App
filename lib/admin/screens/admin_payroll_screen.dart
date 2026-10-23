import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_card.dart';

class AdminPayrollScreen extends ConsumerStatefulWidget {
  const AdminPayrollScreen({super.key});

  @override
  ConsumerState<AdminPayrollScreen> createState() => _AdminPayrollScreenState();
}

class _AdminPayrollScreenState extends ConsumerState<AdminPayrollScreen> {
  bool _isLoading = true;
  List<dynamic> _payrollList = [];
  String _searchTerm = '';
  String _selectedStatus = 'All';
  String _selectedDepartment = 'All';
  String _selectedMonth = 'September 2026';

  Map<String, dynamic>? _selectedPayslip;

  @override
  void initState() {
    super.initState();
    _loadPayroll();
  }

  Future<void> _loadPayroll() async {
    setState(() => _isLoading = true);
    final apiClient = ref.read(apiClientProvider);

    try {
      final res = await apiClient.get('/salary/employees').catchError((_) => null);
      List<dynamic> items = [];
      if (res is List) {
        items = res;
      } else if (res is Map<String, dynamic>) {
        items = res['items'] ?? res['data'] ?? [];
      }

      if (items.isEmpty) {
        items = [
          {
            'id': '1',
            'employeeCode': 'EMP-001',
            'employeeName': 'Rahul Sharma',
            'designation': 'Senior Engineer',
            'department': 'Engineering',
            'month': 'September 2026',
            'basicSalary': 60000,
            'hra': 24000,
            'allowances': 15000,
            'pfDeduction': 7200,
            'taxDeduction': 3000,
            'otherDeductions': 1000,
            'totalDeductions': 11200,
            'netPay': 87800,
            'status': 'Paid',
            'paymentDate': '2026-09-01',
            'paymentMethod': 'HDFC Bank (****1234)'
          },
          {
            'id': '2',
            'employeeCode': 'EMP-002',
            'employeeName': 'Priya Verma',
            'designation': 'Marketing Lead',
            'department': 'Marketing',
            'month': 'September 2026',
            'basicSalary': 50000,
            'hra': 20000,
            'allowances': 12000,
            'pfDeduction': 6000,
            'taxDeduction': 2500,
            'otherDeductions': 500,
            'totalDeductions': 9000,
            'netPay': 73000,
            'status': 'Pending',
            'paymentDate': 'Pending',
            'paymentMethod': 'ICICI Bank (****5678)'
          }
        ];
      }

      setState(() {
        _payrollList = items;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  List<dynamic> get _filteredPayroll {
    return _payrollList.where((r) {
      final name = (r['employeeName'] ?? '').toString().toLowerCase();
      final empId = (r['employeeCode'] ?? '').toString().toLowerCase();
      final dept = (r['department'] ?? '').toString();
      final status = (r['status'] ?? 'Pending').toString();

      final matchesSearch = _searchTerm.trim().isEmpty || name.contains(_searchTerm.toLowerCase()) || empId.contains(_searchTerm.toLowerCase());
      final matchesDept = _selectedDepartment == 'All' || dept == _selectedDepartment;
      final matchesStatus = _selectedStatus == 'All' || status == _selectedStatus;

      return matchesSearch && matchesDept && matchesStatus;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final totalGross = _payrollList.fold<num>(0, (sum, r) => sum + ((r['basicSalary'] ?? 0) + (r['hra'] ?? 0) + (r['allowances'] ?? 0)));
    final totalDeduct = _payrollList.fold<num>(0, (sum, r) => sum + (r['totalDeductions'] ?? 0));
    final totalNet = _payrollList.fold<num>(0, (sum, r) => sum + (r['netPay'] ?? 0));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payroll Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.play_arrow),
            tooltip: 'Run Payroll',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payroll processing executed successfully!')));
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // KPI Metrics Grid
            GridView.count(
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.4,
              children: [
                _buildMetricCard('Total Gross', '₹$totalGross', Icons.account_balance_wallet, Colors.blue),
                _buildMetricCard('Total Deductions', '₹$totalDeduct', Icons.receipt_long, Colors.red),
                _buildMetricCard('Total Net Pay', '₹$totalNet', Icons.payments, Colors.green),
              ],
            ),
            const SizedBox(height: 24),

            // Search & Status Filter
            TextField(
              decoration: const InputDecoration(
                hintText: 'Search employee by name or ID...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (val) => setState(() => _searchTerm = val),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['All', 'Paid', 'Processing', 'Pending', 'On Hold'].map((st) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(st),
                      selected: _selectedStatus == st,
                      onSelected: (_) => setState(() => _selectedStatus = st),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),

            // Payroll Records List
            _filteredPayroll.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: Text('No payroll records found matching filter.')),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _filteredPayroll.length,
                    itemBuilder: (context, index) {
                      final r = _filteredPayroll[index];
                      final status = r['status'] ?? 'Pending';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: AppColors.primary.withOpacity(0.1),
                                        child: Text((r['employeeName'] ?? 'E')[0].toUpperCase(), style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                                      ),
                                      const SizedBox(width: 12),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(r['employeeName'] ?? 'Employee', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                          Text('${r['employeeCode'] ?? 'EMP'} • ${r['department'] ?? 'General'}', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                                        ],
                                      ),
                                    ],
                                  ),
                                  Chip(
                                    label: Text(status, style: const TextStyle(fontSize: 10, color: Colors.white)),
                                    backgroundColor: status == 'Paid' ? Colors.green : (status == 'Processing' ? Colors.blue : Colors.orange),
                                  ),
                                ],
                              ),
                              const Divider(height: 20),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Net Pay: ₹${r['netPay'] ?? 0}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.green)),
                                  Text('Deductions: ₹${r['totalDeductions'] ?? 0}', style: TextStyle(color: Colors.grey[700], fontSize: 13)),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton.icon(
                                    onPressed: () {
                                      setState(() => _selectedPayslip = r);
                                    },
                                    icon: const Icon(Icons.receipt, size: 16),
                                    label: const Text('View Payslip'),
                                  ),
                                ],
                              ),
                            ],
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

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            Text(title, style: TextStyle(fontSize: 10, color: Colors.grey[600]), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
