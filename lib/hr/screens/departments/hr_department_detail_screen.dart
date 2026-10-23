import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/loading_shimmer.dart';
import 'hr_department_form_screen.dart';

class HrDepartmentDetailScreen extends ConsumerStatefulWidget {
  final String deptId;

  const HrDepartmentDetailScreen({super.key, required this.deptId});

  @override
  ConsumerState<HrDepartmentDetailScreen> createState() => _HrDepartmentDetailScreenState();
}

class _HrDepartmentDetailScreenState extends ConsumerState<HrDepartmentDetailScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _department;
  List<dynamic> _deptEmployees = [];

  @override
  void initState() {
    super.initState();
    _loadDepartmentDetail();
  }

  Future<void> _loadDepartmentDetail() async {
    setState(() => _isLoading = true);
    final apiClient = ref.read(apiClientProvider);
    try {
      final res = await apiClient.get('/departments/${widget.deptId}').catchError((_) => null);
      final empRes = await apiClient.get('/management/employees').catchError((_) => null);

      List<dynamic> employees = [];
      if (empRes is List) {
        employees = empRes;
      } else if (empRes is Map<String, dynamic> && empRes['data'] is List) {
        employees = empRes['data'];
      }

      final deptMap = res is Map<String, dynamic> ? (res['data'] ?? res) : null;
      final deptName = (deptMap?['name'] ?? '').toString().toLowerCase();

      final filteredEmps = employees.where((e) {
        final d = (e['department'] ?? '').toString().toLowerCase();
        return d == deptName;
      }).toList();

      setState(() {
        _department = deptMap;
        _deptEmployees = filteredEmps;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const LoadingShimmer();
    if (_department == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Department Detail')),
        body: const Center(child: Text('Department not found')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_department!['name'] ?? 'Department Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => HrDepartmentFormScreen(deptId: widget.deptId, initialData: _department)),
              );
              _loadDepartmentDetail();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppCard(
              backgroundColor: AppColors.primary,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_department!['name'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('Code: ${_department!['code'] ?? ''}', style: const TextStyle(color: Colors.white70)),
                  const SizedBox(height: 8),
                  Text(_department!['description'] ?? 'No description provided.', style: const TextStyle(color: Color(0xDDFFFFFF), fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text('Assigned Employees (${_deptEmployees.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _deptEmployees.length,
              itemBuilder: (context, index) {
                final emp = _deptEmployees[index] as Map<String, dynamic>;
                return AppCard(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(child: Text((emp['fullName'] ?? 'E')[0])),
                    title: Text(emp['fullName'] ?? 'Employee', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('${emp['employeeCode'] ?? ''} • ${emp['designation'] ?? 'Staff'}'),
                    trailing: Chip(label: Text(emp['active'] == true ? 'Active' : 'Inactive')),
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
