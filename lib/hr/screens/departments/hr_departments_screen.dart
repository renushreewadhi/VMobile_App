import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/loading_shimmer.dart';
import 'hr_department_detail_screen.dart';
import 'hr_department_form_screen.dart';

class HrDepartmentsScreen extends ConsumerStatefulWidget {
  const HrDepartmentsScreen({super.key});

  @override
  ConsumerState<HrDepartmentsScreen> createState() => _HrDepartmentsScreenState();
}

class _HrDepartmentsScreenState extends ConsumerState<HrDepartmentsScreen> {
  bool _isLoading = true;
  List<dynamic> _departments = [];
  String _searchTerm = '';
  String _statusFilter = 'All Status';

  @override
  void initState() {
    super.initState();
    _loadDepartments();
  }

  Future<void> _loadDepartments() async {
    setState(() => _isLoading = true);
    final apiClient = ref.read(apiClientProvider);
    try {
      final res = await apiClient.get('/departments').catchError((_) => null);
      List<dynamic> items = [];
      if (res is List) {
        items = res;
      } else if (res is Map<String, dynamic>) {
        items = res['items'] ?? res['data'] ?? [];
      }
      setState(() {
        _departments = items;
        _isLoading = false;
      });
    } catch (_) {
      setState(() {
        _departments = [];
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteDepartment(String id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Deactivate $name?'),
        content: const Text('This action will deactivate the selected department.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Deactivate')),
        ],
      ),
    );

    if (confirmed == true) {
      final apiClient = ref.read(apiClientProvider);
      try {
        await apiClient.delete('/departments/$id');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Department deactivated')));
          _loadDepartments();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const LoadingShimmer();

    final filtered = _departments.where((d) {
      final map = d is Map<String, dynamic> ? d : {};
      final name = (map['name'] ?? '').toString().toLowerCase();
      final code = (map['code'] ?? '').toString().toLowerCase();
      final status = (map['status'] ?? 'Active').toString();

      final matchesSearch = _searchTerm.isEmpty || name.contains(_searchTerm.toLowerCase()) || code.contains(_searchTerm.toLowerCase());
      final matchesStatus = _statusFilter == 'All Status' || status.toLowerCase() == _statusFilter.toLowerCase();

      return matchesSearch && matchesStatus;
    }).toList();

    final activeCount = _departments.where((d) => (d['status'] ?? 'Active').toString().toLowerCase() == 'active').length;
    final inactiveCount = _departments.length - activeCount;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Departments'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const HrDepartmentFormScreen()));
              _loadDepartments();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Metrics Summary
            Row(
              children: [
                Expanded(child: _buildMetricCard('Total', '${_departments.length}', Colors.blue, Icons.account_tree)),
                const SizedBox(width: 8),
                Expanded(child: _buildMetricCard('Active', '$activeCount', Colors.green, Icons.check_circle)),
                const SizedBox(width: 8),
                Expanded(child: _buildMetricCard('Inactive', '$inactiveCount', Colors.red, Icons.pause_circle)),
              ],
            ),
            const SizedBox(height: 16),
            // Search & Filter
            TextField(
              decoration: const InputDecoration(
                labelText: 'Search departments...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (val) => setState(() => _searchTerm = val),
            ),
            const SizedBox(height: 16),
            // Departments List
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final dept = filtered[index] as Map<String, dynamic>;
                final deptId = dept['id'] ?? '';
                return AppCard(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primary.withOpacity(0.1),
                      child: Text((dept['name'] ?? 'D')[0]),
                    ),
                    title: Text(dept['name'] ?? 'Department', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Code: ${dept['code'] ?? ''} • Employees: ${dept['employeeCount'] ?? 0}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, size: 20),
                          onPressed: () async {
                            await Navigator.push(context, MaterialPageRoute(builder: (_) => HrDepartmentFormScreen(deptId: deptId, initialData: dept)));
                            _loadDepartments();
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                          onPressed: () => _deleteDepartment(deptId, dept['name']),
                        ),
                      ],
                    ),
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => HrDepartmentDetailScreen(deptId: deptId)));
                    },
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
