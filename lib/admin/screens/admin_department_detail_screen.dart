import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/glass_header.dart';
import '../../core/widgets/glass_scaffold.dart';
import 'admin_department_form_screen.dart';

class AdminDepartmentDetailScreen extends ConsumerStatefulWidget {
  final String deptId;

  const AdminDepartmentDetailScreen({super.key, required this.deptId});

  @override
  ConsumerState<AdminDepartmentDetailScreen> createState() => _AdminDepartmentDetailScreenState();
}

class _AdminDepartmentDetailScreenState extends ConsumerState<AdminDepartmentDetailScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic> _department = {};
  List<dynamic> _deptEmployees = [];
  List<dynamic> _deptTeams = [];

  @override
  void initState() {
    super.initState();
    _loadDeptDetail();
  }

  Future<void> _loadDeptDetail() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    final apiClient = ref.read(apiClientProvider);

    try {
      final deptRes = await apiClient.get('${ApiEndpoints.departments}/${widget.deptId}').catchError((_) async {
        final listRes = await apiClient.get(ApiEndpoints.departments);
        List<dynamic> depts = listRes is List ? listRes : (listRes is Map ? (listRes['items'] ?? listRes['data'] ?? []) : []);
        return depts.firstWhere((item) => item['id'] == widget.deptId, orElse: () => null);
      });

      final empRes = await apiClient.get(ApiEndpoints.employees).catchError((_) => null);
      final teamRes = await apiClient.get(ApiEndpoints.teams).catchError((_) => null);

      List<dynamic> emps = empRes is List ? empRes : (empRes is Map ? (empRes['items'] ?? empRes['data'] ?? []) : []);
      List<dynamic> teams = teamRes is List ? teamRes : (teamRes is Map ? (teamRes['items'] ?? teamRes['data'] ?? []) : []);

      final deptObj = deptRes is Map<String, dynamic> ? deptRes : {};
      final deptName = (deptObj['name'] ?? '').toString().toLowerCase();
      final deptCode = (deptObj['code'] ?? '').toString().toLowerCase();

      final filteredEmps = emps.where((e) {
        final d = (e['department'] ?? e['departmentName'] ?? '').toString().toLowerCase();
        return d == deptName || d == deptCode;
      }).toList();

      final filteredTeams = teams.where((t) {
        final dId = (t['departmentId'] ?? '').toString();
        final dName = (t['departmentName'] ?? '').toString().toLowerCase();
        return dId == widget.deptId || dName == deptName;
      }).toList();

      if (mounted) {
        setState(() {
          _department = Map<String, dynamic>.from(deptObj);
          _deptEmployees = filteredEmps;
          _deptTeams = filteredTeams;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load department details: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deactivateDepartment() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Deactivate "${_department['name'] ?? 'Department'}"?'),
        content: const Text('This action will set department status to inactive.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await ref.read(apiClientProvider).delete('${ApiEndpoints.departments}/${widget.deptId}');
      setState(() {
        _department['status'] = 'Inactive';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Department deactivated successfully')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to deactivate: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = _department['name']?.toString() ?? 'Department Detail';
    final code = _department['code']?.toString() ?? 'CODE';
    final description = _department['description']?.toString() ?? 'No detailed description provided.';
    final headName = _department['headName']?.toString() ?? 'Unassigned';
    final imageUrl = _department['imageUrl']?.toString();
    final status = (_department['status'] ?? 'Active').toString().toUpperCase();
    final isActive = status == 'ACTIVE';

    return GlassScaffold(
      appBar: GlassHeader(
        title: name,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded),
            tooltip: 'Edit Department',
            onPressed: () async {
              final updated = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => AdminDepartmentFormScreen(deptId: widget.deptId, initialData: _department)),
              );
              if (updated == true) _loadDeptDetail();
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
            tooltip: 'Deactivate Department',
            onPressed: _deactivateDepartment,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline_rounded, color: Colors.red, size: 48),
                        const SizedBox(height: 8),
                        Text(_errorMessage!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        ElevatedButton(onPressed: _loadDeptDetail, child: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Hero Banner Card
                      AppCard(
                        padding: EdgeInsets.zero,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (imageUrl != null && imageUrl.isNotEmpty)
                              ClipRRect(
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                                child: Image.network(
                                  imageUrl,
                                  height: 120,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    height: 80,
                                    color: AppColors.primary.withOpacity(0.2),
                                    alignment: Alignment.center,
                                    child: const Icon(Icons.apartment_rounded, size: 40, color: AppColors.primary),
                                  ),
                                ),
                              ),
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                                          const SizedBox(width: 8),
                                          Chip(label: Text(code, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(description, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                                    ],
                                  ),
                                  Chip(
                                    label: Text(isActive ? 'Active' : 'Inactive', style: const TextStyle(color: Colors.white, fontSize: 11)),
                                    backgroundColor: isActive ? Colors.green : Colors.grey,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Metrics Summary
                      Row(
                        children: [
                          Expanded(child: _buildMetricTile('Staff', '${_deptEmployees.length}', Icons.people_alt_rounded, Colors.blue)),
                          const SizedBox(width: 8),
                          Expanded(child: _buildMetricTile('HOD', headName, Icons.person_rounded, Colors.purple)),
                          const SizedBox(width: 8),
                          Expanded(child: _buildMetricTile('Teams', '${_deptTeams.length}', Icons.account_tree_rounded, Colors.green)),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Department Roster List
                      const Text('Department Staff Roster', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary)),
                      const SizedBox(height: 10),
                      _deptEmployees.isEmpty
                          ? const AppCard(child: Padding(padding: EdgeInsets.all(16), child: Center(child: Text('No employees assigned to this department.'))))
                          : ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _deptEmployees.length,
                              itemBuilder: (context, index) {
                                final emp = _deptEmployees[index] as Map<String, dynamic>;
                                final fName = emp['firstName'] ?? '';
                                final lName = emp['lastName'] ?? '';
                                final empName = '$fName $lName'.trim().isNotEmpty ? '$fName $lName' : (emp['name'] ?? 'Employee');
                                final empCode = emp['employeeCode'] ?? emp['id'] ?? '';
                                final desig = emp['designation'] ?? 'Staff';

                                return AppCard(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: CircleAvatar(
                                      backgroundColor: AppColors.primary.withOpacity(0.1),
                                      child: Text(empName[0].toUpperCase(), style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                                    ),
                                    title: Text(empName, style: const TextStyle(fontWeight: FontWeight.bold)),
                                    subtitle: Text('$empCode • $desig'),
                                  ),
                                );
                              },
                            ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildMetricTile(String label, String value, IconData icon, Color color) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(value, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
        ],
      ),
    );
  }
}
