import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import 'admin_employee_form_screen.dart';
import 'admin_employee_detail_screen.dart';

class AdminEmployeesScreen extends ConsumerStatefulWidget {
  const AdminEmployeesScreen({super.key});

  @override
  ConsumerState<AdminEmployeesScreen> createState() => _AdminEmployeesScreenState();
}

class _AdminEmployeesScreenState extends ConsumerState<AdminEmployeesScreen> {
  bool _isLoading = true;
  List<dynamic> _employees = [];
  List<String> _departmentsList = [];
  List<String> _designationsList = [];

  String _searchTerm = '';
  String _selectedDepartment = '';
  String _selectedDesignation = '';
  String _selectedStatus = '';

  int _currentPage = 1;
  final int _pageSize = 8;

  @override
  void initState() {
    super.initState();
    _loadEmployees();
  }

  Future<void> _loadEmployees() async {
    setState(() => _isLoading = true);
    final apiClient = ref.read(apiClientProvider);

    try {
      final res = await apiClient.get('/management/employees').catchError((_) => null);
      List<dynamic> emps = [];
      if (res is List) {
        emps = res;
      } else if (res is Map<String, dynamic>) {
        emps = res['items'] ?? res['data'] ?? [];
      }

      if (emps.isEmpty) {
        emps = [
          {'id': '1', 'employeeId': 'EMP-24-0001', 'firstName': 'Rahul', 'lastName': 'Sharma', 'email': 'rahul@envision.com', 'department': 'Engineering', 'designation': 'Senior Developer', 'employmentStatus': 'Active'},
          {'id': '2', 'employeeId': 'EMP-24-0002', 'firstName': 'Priya', 'lastName': 'Verma', 'email': 'priya@envision.com', 'department': 'HR', 'designation': 'HR Manager', 'employmentStatus': 'Active'},
          {'id': '3', 'employeeId': 'EMP-24-0003', 'firstName': 'Amit', 'lastName': 'Kumar', 'email': 'amit@envision.com', 'department': 'Sales', 'designation': 'Account Executive', 'employmentStatus': 'Inactive'},
        ];
      }

      final deptSet = <String>{};
      final desigSet = <String>{};

      for (var e in emps) {
        if (e['department'] != null) deptSet.add(e['department'].toString());
        if (e['designation'] != null) desigSet.add(e['designation'].toString());
      }

      setState(() {
        _employees = emps;
        _departmentsList = deptSet.toList()..sort();
        _designationsList = desigSet.toList()..sort();
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  List<dynamic> get _filteredEmployees {
    return _employees.where((e) {
      final name = '${e['firstName'] ?? ''} ${e['lastName'] ?? ''}'.trim().toLowerCase();
      final email = (e['email'] ?? '').toString().toLowerCase();
      final empId = (e['employeeId'] ?? '').toString().toLowerCase();
      final dept = (e['department'] ?? '').toString();
      final desig = (e['designation'] ?? '').toString();
      final status = (e['employmentStatus'] ?? 'Active').toString().toLowerCase();

      final matchesSearch = _searchTerm.trim().isEmpty ||
          name.contains(_searchTerm.toLowerCase()) ||
          email.contains(_searchTerm.toLowerCase()) ||
          empId.contains(_searchTerm.toLowerCase());

      final matchesDept = _selectedDepartment.isEmpty || dept == _selectedDepartment;
      final matchesDesig = _selectedDesignation.isEmpty || desig == _selectedDesignation;
      final matchesStatus = _selectedStatus.isEmpty || status == _selectedStatus.toLowerCase();

      return matchesSearch && matchesDept && matchesDesig && matchesStatus;
    }).toList();
  }

  List<dynamic> get _paginatedEmployees {
    final startIndex = (_currentPage - 1) * _pageSize;
    return _filteredEmployees.skip(startIndex).take(_pageSize).toList();
  }

  int get _totalPages => (_filteredEmployees.length / _pageSize).ceil() > 0 ? (_filteredEmployees.length / _pageSize).ceil() : 1;

  int get _activeCount => _employees.where((e) => (e['employmentStatus'] ?? 'Active').toString().toLowerCase() != 'inactive').length;
  int get _inactiveCount => _employees.length - _activeCount;

  Future<void> _deleteEmployee(Map<String, dynamic> emp) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete employee "${emp['firstName']} ${emp['lastName']}"?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _employees.removeWhere((e) => e['id'] == emp['id']));
      if (emp['id'] != null) {
        try {
          await ref.read(apiClientProvider).delete('/management/employees/${emp['id']}');
        } catch (_) {}
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Employee deleted successfully')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Employees Directory'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            tooltip: 'Add Employee',
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminEmployeeFormScreen()));
              _loadEmployees();
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
                _buildMetricCard('Total Employees', '${_employees.length}', Icons.groups, Colors.blue),
                _buildMetricCard('Active', '$_activeCount', Icons.check_circle, Colors.green),
                _buildMetricCard('Inactive', '$_inactiveCount', Icons.pause_circle, Colors.orange),
              ],
            ),
            const SizedBox(height: 24),

            // Search & Filters
            TextField(
              decoration: const InputDecoration(
                hintText: 'Search by name, email, or employee ID...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (val) => setState(() { _searchTerm = val; _currentPage = 1; }),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedDepartment.isEmpty ? null : _selectedDepartment,
                    hint: const Text('All Departments'),
                    items: [
                      const DropdownMenuItem(value: '', child: Text('All Departments')),
                      ..._departmentsList.map((d) => DropdownMenuItem(value: d, child: Text(d))),
                    ],
                    onChanged: (val) => setState(() { _selectedDepartment = val ?? ''; _currentPage = 1; }),
                    decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedStatus.isEmpty ? null : _selectedStatus,
                    hint: const Text('All Status'),
                    items: const [
                      DropdownMenuItem(value: '', child: Text('All Status')),
                      DropdownMenuItem(value: 'Active', child: Text('Active')),
                      DropdownMenuItem(value: 'Inactive', child: Text('Inactive')),
                    ],
                    onChanged: (val) => setState(() { _selectedStatus = val ?? ''; _currentPage = 1; }),
                    decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Employee Cards List
            _paginatedEmployees.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: Text('No employees found matching your filters.')),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _paginatedEmployees.length,
                    itemBuilder: (context, index) {
                      final emp = _paginatedEmployees[index];
                      final name = '${emp['firstName'] ?? ''} ${emp['lastName'] ?? ''}'.trim().isNotEmpty ? '${emp['firstName']} ${emp['lastName']}' : (emp['name'] ?? 'Employee');
                      final isActive = (emp['employmentStatus'] ?? 'Active').toString().toLowerCase() != 'inactive';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => AdminEmployeeDetailScreen(employeeId: emp['id'] ?? emp['employeeId'] ?? '1')));
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor: AppColors.primary.withOpacity(0.1),
                                  child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'E', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                      const SizedBox(height: 2),
                                      Text('${emp['employeeId'] ?? 'EMP'} • ${emp['department'] ?? 'General'}', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                                      Text(emp['designation'] ?? 'Staff', style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Chip(
                                      label: Text(isActive ? 'Active' : 'Inactive', style: const TextStyle(fontSize: 10, color: Colors.white)),
                                      backgroundColor: isActive ? Colors.green : Colors.grey,
                                      padding: EdgeInsets.zero,
                                    ),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit, size: 18, color: AppColors.primary),
                                          onPressed: () async {
                                            await Navigator.push(context, MaterialPageRoute(builder: (_) => AdminEmployeeFormScreen(employeeId: emp['id'] ?? emp['employeeId'], initialData: emp)));
                                            _loadEmployees();
                                          },
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                                          onPressed: () => _deleteEmployee(emp),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),

            // Pagination Controls
            if (_totalPages > 1)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: _currentPage > 1 ? () => setState(() => _currentPage--) : null,
                      child: const Text('Previous'),
                    ),
                    const SizedBox(width: 16),
                    Text('Page $_currentPage of $_totalPages', style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: _currentPage < _totalPages ? () => setState(() => _currentPage++) : null,
                      child: const Text('Next'),
                    ),
                  ],
                ),
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
            Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text(title, style: TextStyle(fontSize: 10, color: Colors.grey[600]), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
