import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/auth/auth_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/glass_header.dart';
import '../../core/widgets/glass_scaffold.dart';
import 'admin_department_detail_screen.dart';
import 'admin_department_form_screen.dart';

class AdminDepartmentsScreen extends ConsumerStatefulWidget {
  const AdminDepartmentsScreen({super.key});

  @override
  ConsumerState<AdminDepartmentsScreen> createState() => _AdminDepartmentsScreenState();
}

class _AdminDepartmentsScreenState extends ConsumerState<AdminDepartmentsScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<dynamic> _departments = [];
  String _searchTerm = '';
  String _statusFilter = 'All Status';

  final Map<String, Map<String, dynamic>> _deptThemeMap = {
    'Marketing': {'icon': Icons.campaign_rounded, 'color': const Color(0xFF0284C7), 'bg': const Color(0xFFE0F2FE)},
    'Human Resources': {'icon': Icons.people_alt_rounded, 'color': const Color(0xFF16A34A), 'bg': const Color(0xFFDCFCE7)},
    'Finance': {'icon': Icons.show_chart_rounded, 'color': const Color(0xFF2563EB), 'bg': const Color(0xFFDBEAFE)},
    'Sales': {'icon': Icons.track_changes_rounded, 'color': const Color(0xFFDB2777), 'bg': const Color(0xFFFCE7F3)},
    'IT & Software': {'icon': Icons.computer_rounded, 'color': const Color(0xFF0369A1), 'bg': const Color(0xFFE0F2FE)},
    'Engineering': {'icon': Icons.developer_mode_rounded, 'color': const Color(0xFF2563EB), 'bg': const Color(0xFFE0EDFF)},
    'Operations': {'icon': Icons.settings_rounded, 'color': const Color(0xFFD97706), 'bg': const Color(0xFFFEF3C7)},
  };

  @override
  void initState() {
    super.initState();
    _loadDepartments();
  }

  Future<void> _loadDepartments() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    final apiClient = ref.read(apiClientProvider);
    final storageService = ref.read(storageServiceProvider);
    final token = await storageService.getToken();
    if (token != null && token.isNotEmpty) {
      apiClient.setAuthToken(token);
    }

    try {
      final res = await apiClient.get(ApiEndpoints.departments);
      List<dynamic> items = [];
      if (res is List) {
        items = res;
      } else if (res is Map<String, dynamic>) {
        items = res['items'] ?? res['data'] ?? [];
      }

      if (mounted) {
        setState(() {
          _departments = items;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load departments: $e';
          _isLoading = false;
        });
      }
    }
  }

  List<dynamic> get _filteredDepartments {
    return _departments.where((d) {
      final map = d is Map<String, dynamic> ? d : {};
      final name = (map['name'] ?? '').toString().toLowerCase();
      final code = (map['code'] ?? '').toString().toLowerCase();
      final desc = (map['description'] ?? '').toString().toLowerCase();
      final statusUpper = (map['status'] ?? 'ACTIVE').toString().toUpperCase();

      final matchesSearch = _searchTerm.trim().isEmpty ||
          name.contains(_searchTerm.toLowerCase()) ||
          code.contains(_searchTerm.toLowerCase()) ||
          desc.contains(_searchTerm.toLowerCase());

      final matchesStatus = _statusFilter == 'All Status' ||
          (_statusFilter == 'Active' && statusUpper == 'ACTIVE') ||
          (_statusFilter == 'Inactive' && statusUpper == 'INACTIVE');

      return matchesSearch && matchesStatus;
    }).toList();
  }

  int get _activeCount => _departments.where((d) => ((d as Map)['status'] ?? 'Active').toString().toUpperCase() == 'ACTIVE').length;
  int get _inactiveCount => _departments.length - _activeCount;
  int get _totalEmployeesCount => _departments.fold(0, (sum, d) {
    final count = (d as Map)['employeeCount'] ?? 0;
    return sum + (count is int ? count : (int.tryParse(count.toString()) ?? 0));
  });

  Map<String, dynamic> _getDeptTheme(String name) {
    for (final key in _deptThemeMap.keys) {
      if (name.toLowerCase().contains(key.toLowerCase())) {
        return _deptThemeMap[key]!;
      }
    }
    return {'icon': Icons.business_rounded, 'color': const Color(0xFF2563EB), 'bg': const Color(0xFFE0EDFF)};
  }

  Future<void> _deleteDepartment(Map<String, dynamic> d) async {
    final deptId = d['id']?.toString() ?? '';
    final deptName = d['name']?.toString() ?? 'Department';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Deactivate "$deptName"?'),
        content: const Text('This action will deactivate the selected department.'),
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

    final apiClient = ref.read(apiClientProvider);
    try {
      await apiClient.delete('${ApiEndpoints.departments}/$deptId');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Department "$deptName" deactivated successfully')));
        _loadDepartments();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to deactivate department: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return GlassScaffold(
      appBar: const GlassHeader(
        title: 'Departments Management',
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDepartments,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Summary Metric KPI Cards (4 Compact & Elegant Cards)
                    Row(
                      children: [
                        Expanded(child: _buildMetricCard('Total', '${_departments.length}', Icons.apartment_rounded, const Color(0xFF2563EB), const Color(0xFFE0EDFF))),
                        const SizedBox(width: 8),
                        Expanded(child: _buildMetricCard('Active', '$_activeCount', Icons.check_circle_rounded, const Color(0xFF16A34A), const Color(0xFFDCFCE7))),
                        const SizedBox(width: 8),
                        Expanded(child: _buildMetricCard('Inactive', '$_inactiveCount', Icons.pause_circle_rounded, const Color(0xFFDC2626), const Color(0xFFFEE2E2))),
                        const SizedBox(width: 8),
                        Expanded(child: _buildMetricCard('Staff', '$_totalEmployeesCount', Icons.group_rounded, const Color(0xFF9333EA), const Color(0xFFF3E8FF))),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Search & Status Filter Controls Row
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: dark ? AppColors.darkSecondarySurface : Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: dark ? AppColors.darkBordersAndDividers : const Color(0xFFE2E8F0)),
                              boxShadow: const [BoxShadow(color: Color.fromRGBO(15, 23, 42, 0.03), blurRadius: 10, offset: Offset(0, 2))],
                            ),
                            child: TextField(
                              decoration: const InputDecoration(
                                hintText: 'Search by name, code, description...',
                                hintStyle: TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                                prefixIcon: Icon(Icons.search_rounded, size: 20, color: Color(0xFF64748B)),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              ),
                              onChanged: (val) => setState(() => _searchTerm = val),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: dark ? AppColors.darkSecondarySurface : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: dark ? AppColors.darkBordersAndDividers : const Color(0xFFE2E8F0)),
                            boxShadow: const [BoxShadow(color: Color.fromRGBO(15, 23, 42, 0.03), blurRadius: 10, offset: Offset(0, 2))],
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _statusFilter,
                              style: TextStyle(fontSize: 12, color: dark ? AppColors.darkPrimaryText : const Color(0xFF0F172A), fontWeight: FontWeight.w600),
                              items: const [
                                DropdownMenuItem(value: 'All Status', child: Text('All Status')),
                                DropdownMenuItem(value: 'Active', child: Text('Active')),
                                DropdownMenuItem(value: 'Inactive', child: Text('Inactive')),
                              ],
                              onChanged: (val) => setState(() => _statusFilter = val ?? 'All Status'),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Action Bar below Search: Department Count + Create Department Button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Flexible(
                                child: Text('Departments List', overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: dark ? AppColors.darkPrimaryText : const Color(0xFF0F172A))),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(color: const Color(0xFFE0EDFF), borderRadius: BorderRadius.circular(12)),
                                child: Text('${_filteredDepartments.length}', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        ElevatedButton.icon(
                          onPressed: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const AdminDepartmentFormScreen()),
                            );
                            if (result == true) _loadDepartments();
                          },
                          icon: const Icon(Icons.add_rounded, size: 16),
                          label: const Text('Create Department', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Error or Empty States
                    if (_errorMessage != null)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [
                              const Icon(Icons.error_outline_rounded, color: Colors.red, size: 48),
                              const SizedBox(height: 8),
                              Text(_errorMessage!, textAlign: TextAlign.center),
                              const SizedBox(height: 12),
                              ElevatedButton(onPressed: _loadDepartments, child: const Text('Retry')),
                            ],
                          ),
                        ),
                      )
                    else if (_filteredDepartments.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(child: Text('No departments found matching your criteria.', style: TextStyle(color: Color(0xFF64748B), fontSize: 13))),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _filteredDepartments.length,
                        itemBuilder: (context, index) {
                          final dept = _filteredDepartments[index] as Map<String, dynamic>;
                          final deptId = dept['id']?.toString() ?? '';
                          final deptName = dept['name']?.toString() ?? 'Department';
                          final deptCode = dept['code']?.toString() ?? 'CODE';
                          final deptDesc = dept['description']?.toString() ?? '';
                          final empCount = dept['employeeCount'] ?? 0;
                          final headName = dept['headName']?.toString() ?? 'Unassigned';
                          final status = (dept['status'] ?? 'Active').toString().toUpperCase();
                          final isActive = status == 'ACTIVE';
                          final theme = _getDeptTheme(deptName);

                          return Container(
                            margin: const EdgeInsets.only(bottom: 14),
                            decoration: BoxDecoration(
                              color: dark ? AppColors.darkMainSurface : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: dark ? AppColors.darkBordersAndDividers : const Color(0xFFF1F5F9)),
                              boxShadow: const [BoxShadow(color: Color.fromRGBO(15, 23, 42, 0.04), blurRadius: 16, offset: Offset(0, 4))],
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => AdminDepartmentDetailScreen(deptId: deptId)),
                                );
                                _loadDepartments();
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          width: 46,
                                          height: 46,
                                          decoration: BoxDecoration(
                                            color: theme['bg'] as Color,
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          alignment: Alignment.center,
                                          child: Icon(theme['icon'] as IconData, color: theme['color'] as Color, size: 22),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Expanded(
                                                    child: Text(deptName, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: dark ? AppColors.darkPrimaryText : const Color(0xFF0F172A))),
                                                  ),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                    decoration: BoxDecoration(
                                                      color: isActive ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
                                                      borderRadius: BorderRadius.circular(20),
                                                    ),
                                                    child: Text(
                                                      isActive ? 'Active' : 'Inactive',
                                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: isActive ? const Color(0xFF16A34A) : const Color(0xFF64748B)),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: (theme['color'] as Color).withOpacity(0.12),
                                                      borderRadius: BorderRadius.circular(6),
                                                    ),
                                                    child: Text(deptCode, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: theme['color'] as Color)),
                                                  ),
                                                  if (deptDesc.isNotEmpty) ...[
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: Text(deptDesc, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: dark ? AppColors.darkSecondaryText : const Color(0xFF64748B))),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const Padding(
                                      padding: EdgeInsets.symmetric(vertical: 12),
                                      child: Divider(height: 1, color: Color(0xFFF1F5F9)),
                                    ),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(Icons.people_alt_outlined, size: 13, color: Color(0xFF2563EB)),
                                            const SizedBox(width: 4),
                                            Text('$empCount Staff', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: dark ? AppColors.darkPrimaryText : const Color(0xFF0F172A))),
                                            const SizedBox(width: 12),
                                            const Icon(Icons.person_outline, size: 13, color: Color(0xFF9333EA)),
                                            const SizedBox(width: 4),
                                            Text('HOD: $headName', style: TextStyle(fontSize: 12, color: dark ? AppColors.darkSecondaryText : const Color(0xFF64748B))),
                                          ],
                                        ),
                                        Row(
                                          children: [
                                            InkWell(
                                              onTap: () async {
                                                final updated = await Navigator.push(
                                                  context,
                                                  MaterialPageRoute(builder: (_) => AdminDepartmentFormScreen(deptId: deptId, initialData: dept)),
                                                );
                                                if (updated == true) _loadDepartments();
                                              },
                                              borderRadius: BorderRadius.circular(8),
                                              child: Container(
                                                padding: const EdgeInsets.all(8),
                                                decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(8)),
                                                child: const Icon(Icons.edit_rounded, size: 16, color: Color(0xFF2563EB)),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            InkWell(
                                              onTap: () => _deleteDepartment(dept),
                                              borderRadius: BorderRadius.circular(8),
                                              child: Container(
                                                padding: const EdgeInsets.all(8),
                                                decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(8)),
                                                child: const Icon(Icons.delete_rounded, size: 16, color: Color(0xFFDC2626)),
                                              ),
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
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  value,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: color, height: 1.1),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(title, style: const TextStyle(fontSize: 10, color: Color(0xFF475569), fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}
