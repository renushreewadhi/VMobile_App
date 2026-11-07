import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/auth/auth_service.dart';
import '../../core/errors/api_exception.dart';
import '../../core/models/user_model.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/glass_theme.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/glass_header.dart';
import '../../core/widgets/glass_scaffold.dart';
import 'admin_branch_detail_screen.dart';
import 'admin_branch_form_screen.dart';

/// Strongly typed Branch Model
class BranchModel {
  final String id;
  final String name;
  final String code;
  final String? address;
  final String city;
  final String? state;
  final String? country;
  final String? phone;
  final String? email;
  final String? imageUrl;
  final String status;
  final int employeeCount;

  BranchModel({
    required this.id,
    required this.name,
    required this.code,
    this.address,
    required this.city,
    this.state,
    this.country,
    this.phone,
    this.email,
    this.imageUrl,
    required this.status,
    required this.employeeCount,
  });

  bool get isActive {
    final s = status.toUpperCase();
    return s == 'ACTIVE' || s == 'TRUE';
  }

  factory BranchModel.fromJson(Map<String, dynamic> json) {
    final rawStatus = json['status']?.toString() ?? 'Active';
    final isAct = rawStatus.toUpperCase() == 'ACTIVE' || rawStatus.toUpperCase() == 'TRUE';

    return BranchModel(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Branch Name',
      code: json['code']?.toString() ?? 'CODE',
      address: json['address']?.toString(),
      city: json['city']?.toString() ?? 'City',
      state: json['state']?.toString(),
      country: json['country']?.toString(),
      phone: json['phone']?.toString(),
      email: json['email']?.toString(),
      imageUrl: json['imageUrl']?.toString() ?? json['image']?.toString(),
      status: isAct ? 'Active' : 'Inactive',
      employeeCount: json['employeeCount'] is int ? json['employeeCount'] as int : (int.tryParse(json['employeeCount']?.toString() ?? '0') ?? 0),
    );
  }
}

class AdminBranchesScreen extends ConsumerStatefulWidget {
  const AdminBranchesScreen({super.key});

  @override
  ConsumerState<AdminBranchesScreen> createState() => _AdminBranchesScreenState();
}

class _AdminBranchesScreenState extends ConsumerState<AdminBranchesScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<BranchModel> _branches = [];
  List<dynamic> _employees = [];

  String _searchTerm = '';
  String _statusFilter = 'All Status';

  int _requestId = 0;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _checkUserAndLoad();
      }
    });
  }

  void _checkUserAndLoad() {
    _requestId++;
    final authState = ref.read(authServiceProvider);
    final user = authState.user;

    if (user == null || !authState.isAuthenticated) {
      if (!mounted) return;
      _resetState();
      setState(() {
        _isLoading = false;
        _errorMessage = 'No authenticated user found.';
      });
      return;
    }

    if (_currentUserId != user.id) {
      _currentUserId = user.id;
      _resetState();
    }

    final userRole = user.role;
    final bool isAuthorized = userRole == UserRole.ADMIN || userRole == UserRole.HR;

    if (!isAuthorized) {
      if (!mounted) return;
      _resetState();
      setState(() {
        _isLoading = false;
        _errorMessage = null;
      });
      return;
    }

    _loadBranches();
  }

  void _resetState() {
    _branches = [];
    _employees = [];
    _searchTerm = '';
    _statusFilter = 'All Status';
  }

  Future<void> _loadBranches() async {
    final currentReq = ++_requestId;
    if (!mounted) return;
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
      final res = await apiClient.get(ApiEndpoints.branches);
      if (!mounted || currentReq != _requestId) return;

      dynamic rawData = res;
      if (res is Map<String, dynamic> && res.containsKey('data')) {
        rawData = res['data'];
      }

      if (rawData is! List) {
        if (!mounted || currentReq != _requestId) return;
        setState(() {
          _errorMessage = 'Invalid response format received from server.';
          _isLoading = false;
        });
        return;
      }

      List<BranchModel> items = [];
      for (final item in rawData) {
        if (item is Map<String, dynamic>) {
          try {
            items.add(BranchModel.fromJson(item));
          } catch (e) {
            debugPrint('[AdminBranches] Skipped invalid branch item: $e');
          }
        }
      }

      List<dynamic> emps = [];
      try {
        final empRes = await apiClient.get(ApiEndpoints.employeesAll);
        if (!mounted || currentReq != _requestId) return;
        dynamic rawEmps = empRes is Map<String, dynamic> && empRes.containsKey('data') ? empRes['data'] : empRes;
        if (rawEmps is List) emps = rawEmps;
      } catch (e) {
        debugPrint('[AdminBranches] Employee list warning: $e');
      }

      if (!mounted || currentReq != _requestId) return;
      setState(() {
        _branches = items;
        _employees = emps;
        _isLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted || currentReq != _requestId) return;
      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted || currentReq != _requestId) return;
      setState(() {
        _errorMessage = 'Failed to load branch offices. Please check network connection.';
        _isLoading = false;
      });
    }
  }

  int _getBranchEmployeeCount(BranchModel branch) {
    final assignedCount = _employees.where((e) {
      if (e is! Map<String, dynamic>) return false;
      final bVal = (e['branch'] ?? e['branchName'] ?? '').toString().toLowerCase();
      final bId = (e['branchId'] ?? '').toString().toLowerCase();

      if (bId.isNotEmpty) {
        return bId == branch.id.toLowerCase();
      }
      return bVal.isNotEmpty && (bVal == branch.name.toLowerCase() || bVal == branch.code.toLowerCase());
    }).length;

    if (assignedCount > 0) return assignedCount;
    return branch.employeeCount;
  }

  int get _activeBranchesCount => _branches.where((b) => b.isActive).length;
  int get _inactiveBranchesCount => _branches.where((b) => !b.isActive).length;

  int get _totalEmployeesCount {
    if (_employees.isNotEmpty) return _employees.length;
    return _branches.fold(0, (sum, b) => sum + _getBranchEmployeeCount(b));
  }

  List<BranchModel> get _filteredBranches {
    return _branches.where((b) {
      final name = b.name.toLowerCase();
      final code = b.code.toLowerCase();
      final city = b.city.toLowerCase();
      final addr = (b.address ?? '').toLowerCase();

      final matchesSearch = _searchTerm.trim().isEmpty ||
          name.contains(_searchTerm.toLowerCase()) ||
          code.contains(_searchTerm.toLowerCase()) ||
          city.contains(_searchTerm.toLowerCase()) ||
          addr.contains(_searchTerm.toLowerCase());

      final matchesStatus = _statusFilter == 'All Status' ||
          (_statusFilter == 'Active' && b.isActive) ||
          (_statusFilter == 'Inactive' && !b.isActive);

      return matchesSearch && matchesStatus;
    }).toList();
  }

  Future<void> _deleteBranch(BranchModel b) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete branch "${b.name}"?'),
        content: const Text('This action will delete the branch location from the system.'),
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

    if (confirmed != true) return;

    final currentReq = ++_requestId;
    final apiClient = ref.read(apiClientProvider);

    try {
      await apiClient.delete('${ApiEndpoints.branches}/${b.id}');
      if (!mounted || currentReq != _requestId) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Branch deleted successfully')),
      );
      _loadBranches();
    } catch (e) {
      if (!mounted || currentReq != _requestId) return;
      final msg = e is ApiException ? e.message : 'Failed to delete branch.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBgColor = isDark ? const Color(0xFF141D2E) : Colors.white;

    ref.listen<AuthState>(authServiceProvider, (previous, next) {
      if (next.user?.id != _currentUserId) {
        _checkUserAndLoad();
      }
    });

    final authState = ref.watch(authServiceProvider);
    final userRole = authState.user?.role;
    final bool isAuthorized = userRole == UserRole.ADMIN || userRole == UserRole.HR;

    return GlassScaffold(
      appBar: const GlassHeader(
        title: 'Branches Management',
      ),
      body: !isAuthorized
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: AppCard(
                  backgroundColor: cardBgColor,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.lock_outline, size: 48, color: Color(0xFFEF4444)),
                      const SizedBox(height: 16),
                      Text('Access Restricted', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: glass.textPrimary)),
                      const SizedBox(height: 8),
                      Text('You do not have administrative permissions to view or manage branch offices.', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: glass.textSecondary)),
                    ],
                  ),
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadBranches,
              child: _buildMainContent(glass, cardBgColor, isDark),
            ),
    );
  }

  Widget _buildMainContent(GlassTheme glass, Color cardBgColor, bool dark) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Container(
          constraints: BoxConstraints(minHeight: MediaQuery.of(context).size.height * 0.7),
          padding: const EdgeInsets.all(24),
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, size: 54, color: Color(0xFFEF4444)),
              const SizedBox(height: 16),
              Text('Unable to Load Branches', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: glass.textPrimary)),
              const SizedBox(height: 8),
              Text(_errorMessage!, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: glass.textSecondary)),
              const SizedBox(height: 24),
              AppButton(label: 'Retry', icon: Icons.refresh_rounded, width: 140, onPressed: _loadBranches),
            ],
          ),
        ),
      );
    }

    final filtered = _filteredBranches;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 4 Compact KPI Metric Cards (Matching Departments & Designations style)
          Row(
            children: [
              Expanded(child: _buildMetricCard('Total', '${_branches.length}', Icons.location_city_rounded, const Color(0xFF2563EB), const Color(0xFFE0EDFF))),
              const SizedBox(width: 8),
              Expanded(child: _buildMetricCard('Active', '$_activeBranchesCount', Icons.check_circle_rounded, const Color(0xFF16A34A), const Color(0xFFDCFCE7))),
              const SizedBox(width: 8),
              Expanded(child: _buildMetricCard('Inactive', '$_inactiveBranchesCount', Icons.pause_circle_rounded, const Color(0xFFDC2626), const Color(0xFFFEE2E2))),
              const SizedBox(width: 8),
              Expanded(child: _buildMetricCard('Staff', '$_totalEmployeesCount', Icons.group_rounded, const Color(0xFF8B5CF6), const Color(0xFFEFF6FF))),
            ],
          ),
          const SizedBox(height: 16),

          // Search and Filter Bar
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
                      hintText: 'Search branches, city...',
                      hintStyle: TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                      prefixIcon: Icon(Icons.search_rounded, size: 20, color: Color(0xFF64748B)),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    style: TextStyle(color: dark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText, fontSize: 13),
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
                child: DropdownButton<String>(
                  value: _statusFilter,
                  underline: const SizedBox.shrink(),
                  items: const [
                    DropdownMenuItem(value: 'All Status', child: Text('All Status', style: TextStyle(fontSize: 12))),
                    DropdownMenuItem(value: 'Active', child: Text('Active', style: TextStyle(fontSize: 12))),
                    DropdownMenuItem(value: 'Inactive', child: Text('Inactive', style: TextStyle(fontSize: 12))),
                  ],
                  onChanged: (val) => setState(() => _statusFilter = val ?? 'All Status'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Action Bar: Branches List Count + Add Branch (+) Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text('Branches List', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: dark ? AppColors.darkPrimaryText : const Color(0xFF0F172A))),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: const Color(0xFFE0EDFF), borderRadius: BorderRadius.circular(12)),
                    child: Text('${filtered.length}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  final created = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(builder: (_) => const AdminBranchFormScreen()),
                  );
                  if (created == true) _loadBranches();
                },
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add Branch', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: Text('No branches found', style: TextStyle(color: glass.textSecondary, fontSize: 14, fontWeight: FontWeight.w600)),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final b = filtered[index];
                return _buildBranchCard(glass, cardBgColor, b, dark);
              },
            ),
        ],
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

  Widget _buildBranchCard(GlassTheme glass, Color cardBgColor, BranchModel b, bool dark) {
    final empCount = _getBranchEmployeeCount(b);
    final locationText = [b.address, b.city, b.state, b.country].where((p) => p != null && p.trim().isNotEmpty).join(', ');

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: dark ? AppColors.darkMainSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: dark ? AppColors.darkBordersAndDividers : const Color(0xFFF1F5F9)),
        boxShadow: const [BoxShadow(color: Color.fromRGBO(15, 23, 42, 0.04), blurRadius: 16, offset: Offset(0, 4))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0EDFF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.business_rounded, color: Color(0xFF2563EB), size: 22),
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
                            child: Text(b.name, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: dark ? AppColors.darkPrimaryText : const Color(0xFF0F172A))),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: b.isActive ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              b.status.toUpperCase(),
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: b.isActive ? const Color(0xFF16A34A) : const Color(0xFF64748B)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(b.code, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
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
              children: [
                const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF94A3B8)),
                const SizedBox(width: 6),
                Expanded(child: Text(locationText.isNotEmpty ? locationText : 'Address not specified', style: TextStyle(fontSize: 12, color: dark ? AppColors.darkSecondaryText : const Color(0xFF64748B)))),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.groups_outlined, size: 14, color: Color(0xFF94A3B8)),
                const SizedBox(width: 6),
                Text('$empCount employees', style: TextStyle(fontSize: 12, color: dark ? AppColors.darkPrimaryText : const Color(0xFF0F172A), fontWeight: FontWeight.w600)),
              ],
            ),
            if (b.phone != null && b.phone!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.phone_outlined, size: 14, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 6),
                  Text(b.phone!, style: TextStyle(fontSize: 12, color: dark ? AppColors.darkPrimaryText : const Color(0xFF0F172A))),
                ],
              ),
            ],
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1, color: Color(0xFFF1F5F9)),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                InkWell(
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => AdminBranchDetailScreen(branchId: b.id)),
                    );
                    _loadBranches();
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.remove_red_eye_rounded, size: 16, color: Color(0xFF2563EB)),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () async {
                    final updated = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(builder: (_) => AdminBranchFormScreen(branchId: b.id, initialData: {
                        'id': b.id,
                        'name': b.name,
                        'code': b.code,
                        'address': b.address,
                        'city': b.city,
                        'state': b.state,
                        'country': b.country,
                        'phone': b.phone,
                        'email': b.email,
                        'imageUrl': b.imageUrl,
                        'status': b.status,
                      })),
                    );
                    if (updated == true) _loadBranches();
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.edit_rounded, size: 16, color: Color(0xFFD97706)),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => _deleteBranch(b),
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
      ),
    );
  }
}
