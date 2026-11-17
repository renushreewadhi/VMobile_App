import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/auth/auth_service.dart';
import '../../core/theme/app_colors.dart';
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

  Future<void> _deleteDepartment(Map<String, dynamic> d) async {
    final deptId = (d['id'] ?? d['_id'])?.toString() ?? '';
    final deptName = d['name']?.toString() ?? 'Department';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "$deptName"?'),
        content: const Text('This action will delete the selected department.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final apiClient = ref.read(apiClientProvider);
    try {
      await apiClient.delete('${ApiEndpoints.departments}/$deptId').catchError((_) async {
        return await apiClient.delete('/departments/$deptId');
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Department "$deptName" deleted successfully')));
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
    final cardBg = dark ? AppColors.darkMainSurface : Colors.white;
    final borderColor = dark ? AppColors.darkBordersAndDividers : const Color(0xFFE5E7EB);

    return GlassScaffold(
      appBar: const GlassHeader(
        title: 'Departments Management',
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF0F6B63)))
          : RefreshIndicator(
              onRefresh: _loadDepartments,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. STAT TILES: One row of 4 white cards (1px #E5E7EB border, radius 14px, padding 10px 8px, gap 8px)
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricCard(
                            'Total',
                            '${_departments.length}',
                            Icons.apartment_rounded,
                            const Color(0xFF0F6B63),
                            const Color(0xFFE6F4F1),
                            cardBg,
                            borderColor,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildMetricCard(
                            'Active',
                            '$_activeCount',
                            Icons.check_circle_rounded,
                            const Color(0xFF047857),
                            const Color(0xFFECFDF5),
                            cardBg,
                            borderColor,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildMetricCard(
                            'Inactive',
                            '$_inactiveCount',
                            Icons.pause_circle_rounded,
                            _inactiveCount > 0 ? const Color(0xFFDC2626) : const Color(0xFF64748B),
                            _inactiveCount > 0 ? const Color(0xFFFEF2F2) : const Color(0xFFF1F5F9),
                            cardBg,
                            borderColor,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildMetricCard(
                            'Staff',
                            '$_totalEmployeesCount',
                            Icons.group_rounded,
                            const Color(0xFF0F6B63),
                            const Color(0xFFE6F4F1),
                            cardBg,
                            borderColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // 2. SEARCH + STATUS FILTER (44px high, radius 12-14px, white bg, 1px #CBD5E1 border)
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 44,
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: dark ? AppColors.darkBordersAndDividers : const Color(0xFFCBD5E1)),
                            ),
                            alignment: Alignment.center,
                            child: TextField(
                              style: TextStyle(fontSize: 14, color: dark ? AppColors.darkPrimaryText : const Color(0xFF0F172A), fontWeight: FontWeight.w500),
                              decoration: const InputDecoration(
                                hintText: 'Search by name, code, description...',
                                hintStyle: TextStyle(fontSize: 14, color: Color(0xFF94A3B8), fontWeight: FontWeight.w400),
                                prefixIcon: Icon(Icons.search_rounded, size: 20, color: Color(0xFF64748B)),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                              ),
                              onChanged: (val) => setState(() => _searchTerm = val),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 120,
                          height: 44,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: dark ? AppColors.darkBordersAndDividers : const Color(0xFFCBD5E1)),
                          ),
                          alignment: Alignment.center,
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _statusFilter,
                              isExpanded: true,
                              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF0F6B63), size: 20),
                              style: TextStyle(fontSize: 13, color: dark ? AppColors.darkPrimaryText : const Color(0xFF0F172A), fontWeight: FontWeight.w500),
                              items: const [
                                DropdownMenuItem(value: 'All Status', child: Text('All Status', overflow: TextOverflow.ellipsis)),
                                DropdownMenuItem(value: 'Active', child: Text('Active', overflow: TextOverflow.ellipsis)),
                                DropdownMenuItem(value: 'Inactive', child: Text('Inactive', overflow: TextOverflow.ellipsis)),
                              ],
                              onChanged: (val) => setState(() => _statusFilter = val ?? 'All Status'),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // 3. HEADING ROW: Departments List + count chip & Create Department button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  'Departments List',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: dark ? AppColors.darkPrimaryText : const Color(0xFF0F172A)),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE6F4F1),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  '${_filteredDepartments.length}',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF0F6B63)),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          height: 40,
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const AdminDepartmentFormScreen()),
                              );
                              if (result == true) _loadDepartments();
                            },
                            icon: const Icon(Icons.add_rounded, size: 16, color: Colors.white),
                            label: const Text('Create Department', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0F6B63),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              elevation: 2,
                              shadowColor: const Color.fromRGBO(15, 107, 99, 0.22),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // 4. DEPARTMENT CARDS FEED
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
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 16),
                        alignment: Alignment.center,
                        child: Column(
                          children: const [
                            Icon(Icons.apartment_outlined, size: 56, color: Color(0xFF94A3B8)),
                            SizedBox(height: 16),
                            Text('No Departments Found', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                            SizedBox(height: 8),
                            Text('No departments match the selected status filter or search criteria.', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                          ],
                        ),
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
                          final empCountRaw = dept['employeeCount'] ?? 0;
                          final empCount = empCountRaw is int ? empCountRaw : (int.tryParse(empCountRaw.toString()) ?? 0);
                          final headName = dept['headName']?.toString() ?? 'Unassigned';
                          final status = (dept['status'] ?? 'Active').toString().toUpperCase();
                          final isActive = status == 'ACTIVE';

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: borderColor, width: 1),
                              boxShadow: const [BoxShadow(color: Color.fromRGBO(15, 23, 42, 0.03), blurRadius: 10, offset: Offset(0, 2))],
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
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Row 1: 44px Icon tile + Title + Active/Inactive chip
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          width: 44,
                                          height: 44,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFE6F4F1),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          alignment: Alignment.center,
                                          child: const Icon(Icons.apartment_rounded, color: Color(0xFF0F6B63), size: 22),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      deptName,
                                                      maxLines: 2,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: dark ? AppColors.darkPrimaryText : const Color(0xFF0F172A)),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Container(
                                                    height: 24,
                                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                    decoration: BoxDecoration(
                                                      color: isActive ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9),
                                                      borderRadius: BorderRadius.circular(999),
                                                    ),
                                                    child: Text(
                                                      isActive ? 'Active' : 'Inactive',
                                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isActive ? const Color(0xFF047857) : const Color(0xFF475569)),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 6),
                                              // Row 2: Code chip + Description
                                              Row(
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFFF1F5F9),
                                                      borderRadius: BorderRadius.circular(8),
                                                    ),
                                                    child: Text(
                                                      deptCode,
                                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155), fontFamily: 'monospace'),
                                                    ),
                                                  ),
                                                  if (deptDesc.isNotEmpty) ...[
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: Text(
                                                        deptDesc,
                                                        maxLines: 2,
                                                        overflow: TextOverflow.ellipsis,
                                                        style: const TextStyle(fontSize: 12, color: Color(0xFF475569), height: 1.4),
                                                      ),
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
                                      padding: EdgeInsets.symmetric(vertical: 8),
                                      child: Divider(height: 1, color: Color(0xFFE5E7EB)),
                                    ),
                                    // Footer: Staff count & HOD on left; Edit & Delete buttons on right
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Row(
                                            children: [
                                              const Icon(Icons.people_alt_outlined, size: 14, color: Color(0xFF64748B)),
                                              const SizedBox(width: 4),
                                              Text(
                                                '$empCount Staff',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: empCount > 0 ? FontWeight.w600 : FontWeight.w400,
                                                  color: empCount > 0 ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              const Icon(Icons.person_outline, size: 14, color: Color(0xFF64748B)),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Text(
                                                  'HOD: $headName',
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: Color(0xFF64748B)),
                                                ),
                                              ),
                                            ],
                                          ),
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
                                              borderRadius: BorderRadius.circular(10),
                                              child: Container(
                                                width: 40,
                                                height: 40,
                                                decoration: BoxDecoration(color: const Color(0xFFE6F4F1), borderRadius: BorderRadius.circular(10)),
                                                alignment: Alignment.center,
                                                child: const Icon(Icons.edit_rounded, size: 18, color: Color(0xFF0F6B63)),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            InkWell(
                                              onTap: () => _deleteDepartment(dept),
                                              borderRadius: BorderRadius.circular(10),
                                              child: Container(
                                                width: 40,
                                                height: 40,
                                                decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(10)),
                                                alignment: Alignment.center,
                                                child: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFDC2626)),
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

  Widget _buildMetricCard(String title, String value, IconData icon, Color iconColor, Color iconBg, Color cardBg, Color borderColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(8)),
                alignment: Alignment.center,
                child: Icon(icon, color: iconColor, size: 16),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  value,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF0F172A), height: 1.1),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
