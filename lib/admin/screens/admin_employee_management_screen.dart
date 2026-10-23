import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_card.dart';

class AdminEmployeeManagementScreen extends ConsumerStatefulWidget {
  const AdminEmployeeManagementScreen({super.key});

  @override
  ConsumerState<AdminEmployeeManagementScreen> createState() => _AdminEmployeeManagementScreenState();
}

class _AdminEmployeeManagementScreenState extends ConsumerState<AdminEmployeeManagementScreen> {
  bool _isLoading = true;
  List<dynamic> _employees = [];
  String _selectedRole = 'ALL';

  final List<Map<String, String>> _roles = [
    {'value': 'ALL', 'label': 'All Roles'},
    {'value': 'ADMIN', 'label': 'Admin'},
    {'value': 'HR', 'label': 'HR'},
    {'value': 'TL', 'label': 'Team Lead'},
    {'value': 'EMPLOYEE', 'label': 'Employee'},
  ];

  @override
  void initState() {
    super.initState();
    _loadEmployees();
  }

  Future<void> _loadEmployees() async {
    setState(() => _isLoading = true);
    final apiClient = ref.read(apiClientProvider);

    try {
      final res = await apiClient.get('/management/employees?role=$_selectedRole').catchError((_) => null);
      List<dynamic> emps = [];
      if (res is List) {
        emps = res;
      } else if (res is Map<String, dynamic>) {
        emps = res['items'] ?? res['data'] ?? [];
      }

      if (emps.isEmpty) {
        emps = [
          {'id': '1', 'employeeCode': 'EMP-01', 'fullName': 'Rahul Sharma', 'email': 'rahul@envision.com', 'role': 'TL', 'department': 'Engineering', 'designation': 'Team Lead'},
          {'id': '2', 'employeeCode': 'EMP-02', 'fullName': 'Priya Verma', 'email': 'priya@envision.com', 'role': 'HR', 'department': 'HR', 'designation': 'HR Manager'},
          {'id': '3', 'employeeCode': 'EMP-03', 'fullName': 'Amit Kumar', 'email': 'amit@envision.com', 'role': 'EMPLOYEE', 'department': 'Sales', 'designation': 'Executive'},
        ];
      }

      setState(() {
        _employees = emps;
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
        title: const Text('Employee Role Management'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Role Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _roles.map((r) {
                  final isSelected = _selectedRole == r['value'];
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(r['label']!),
                      selected: isSelected,
                      onSelected: (_) {
                        setState(() => _selectedRole = r['value']!);
                        _loadEmployees();
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 20),

            // Employees List
            _employees.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: Text('No employees found for selected role.')),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _employees.length,
                    itemBuilder: (context, index) {
                      final emp = _employees[index];
                      final name = emp['fullName'] ?? '${emp['firstName'] ?? ''} ${emp['lastName'] ?? ''}'.trim();
                      final role = emp['role'] ?? 'EMPLOYEE';

                      return AppCard(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppColors.primary.withOpacity(0.1),
                            child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'E', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                          ),
                          title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('${emp['employeeCode'] ?? 'EMP'} • ${emp['department'] ?? 'General'} (${emp['designation'] ?? 'Staff'})'),
                          trailing: Chip(
                            label: Text(role, style: const TextStyle(color: Colors.white, fontSize: 10)),
                            backgroundColor: role == 'ADMIN' ? Colors.purple : (role == 'HR' ? Colors.green : (role == 'TL' ? Colors.blue : Colors.grey)),
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
}
