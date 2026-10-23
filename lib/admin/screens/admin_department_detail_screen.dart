import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_card.dart';
import 'admin_department_form_screen.dart';

class AdminDepartmentDetailScreen extends ConsumerStatefulWidget {
  final String deptId;

  const AdminDepartmentDetailScreen({super.key, required this.deptId});

  @override
  ConsumerState<AdminDepartmentDetailScreen> createState() => _AdminDepartmentDetailScreenState();
}

class _AdminDepartmentDetailScreenState extends ConsumerState<AdminDepartmentDetailScreen> {
  bool _isLoading = true;
  Map<String, dynamic> _department = {};
  List<dynamic> _deptEmployees = [];

  @override
  void initState() {
    super.initState();
    _loadDeptDetail();
  }

  Future<void> _loadDeptDetail() async {
    setState(() => _isLoading = true);
    final apiClient = ref.read(apiClientProvider);

    try {
      final res = await apiClient.get('/departments').catchError((_) => null);
      final empRes = await apiClient.get('/management/employees').catchError((_) => null);

      List<dynamic> depts = res is List ? res : (res is Map ? (res['items'] ?? res['data'] ?? []) : []);
      final d = depts.firstWhere((item) => item['id'] == widget.deptId, orElse: () => null);

      List<dynamic> emps = empRes is List ? empRes : (empRes is Map ? (empRes['items'] ?? empRes['data'] ?? []) : []);

      setState(() {
        _department = d ?? {'name': 'Engineering', 'code': 'ENG', 'description': 'Core software engineering', 'status': 'Active'};
        _deptEmployees = emps;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deactivateDepartment() async {
    try {
      await ref.read(apiClientProvider).delete('/departments/${widget.deptId}');
      setState(() {
        _department['status'] = 'Inactive';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Department deactivated successfully')));
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final isActive = (_department['status'] ?? 'Active').toString().toUpperCase() == 'ACTIVE';

    return Scaffold(
      appBar: AppBar(
        title: Text(_department['name'] ?? 'Department Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Edit Department',
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => AdminDepartmentFormScreen(deptId: widget.deptId, initialData: _department)));
              _loadDeptDetail();
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            tooltip: 'Deactivate Department',
            onPressed: _deactivateDepartment,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Card
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 28,
                              backgroundColor: AppColors.primary.withOpacity(0.1),
                              child: const Icon(Icons.apartment, size: 28, color: AppColors.primary),
                            ),
                            const SizedBox(width: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_department['name'] ?? 'Department Name', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                                Text('Code: ${_department['code'] ?? 'CODE'}', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                              ],
                            ),
                          ],
                        ),
                        Chip(
                          label: Text(isActive ? 'Active' : 'Inactive', style: const TextStyle(color: Colors.white)),
                          backgroundColor: isActive ? Colors.green : Colors.grey,
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Text(_department['description'] ?? 'No description specified.', style: TextStyle(color: Colors.grey[700])),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Department Staff Roster
            const Text('Department Staff Roster', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
            const SizedBox(height: 12),
            _deptEmployees.isEmpty
                ? const Center(child: Text('No employees found in this department.'))
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _deptEmployees.length,
                    itemBuilder: (context, index) {
                      final emp = _deptEmployees[index];
                      final name = '${emp['firstName'] ?? ''} ${emp['lastName'] ?? ''}'.trim().isNotEmpty ? '${emp['firstName']} ${emp['lastName']}' : (emp['name'] ?? 'Employee');
                      return AppCard(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppColors.primary.withOpacity(0.1),
                            child: Text(name[0].toUpperCase(), style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                          ),
                          title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('${emp['employeeCode'] ?? emp['id']} • ${emp['department'] ?? 'General'} (${emp['designation'] ?? 'Staff'})'),
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
