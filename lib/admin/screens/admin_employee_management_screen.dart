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

class AdminEmployeeManagementScreen extends ConsumerStatefulWidget {
  const AdminEmployeeManagementScreen({super.key});

  @override
  ConsumerState<AdminEmployeeManagementScreen> createState() => _AdminEmployeeManagementScreenState();
}

class _AdminEmployeeManagementScreenState extends ConsumerState<AdminEmployeeManagementScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<dynamic> _employees = [];
  String _selectedRole = 'ALL';
  String _searchTerm = '';

  // Pagination (10 records per page matching Angular spec)
  int _currentPage = 1;
  final int _pageSize = 10;

  final List<Map<String, String>> _roles = [
    {'value': 'ALL', 'label': 'All Roles'},
    {'value': 'ADMIN', 'label': 'Administrator'},
    {'value': 'EMPLOYEE', 'label': 'Employee'},
    {'value': 'FINANCE', 'label': 'Finance Manager'},
    {'value': 'HR', 'label': 'HR Manager'},
    {'value': 'IT', 'label': 'IT Manager'},
    {'value': 'TL', 'label': 'Team Lead'},
  ];

  // Request ID guard
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
    _requestId++; // Immediately invalidate any in-flight requests
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

    // Role Guard Check: Must be ADMIN or HR
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

    _loadEmployees();
  }

  void _resetState() {
    _employees = [];
    _selectedRole = 'ALL';
    _searchTerm = '';
    _currentPage = 1;
  }

  Future<void> _loadEmployees() async {
    final currentReq = ++_requestId;
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final apiClient = ref.read(apiClientProvider);

    try {
      final queryParam = _selectedRole != 'ALL' ? '?role=$_selectedRole' : '';
      final res = await apiClient.get('${ApiEndpoints.employees}$queryParam').catchError((_) => null);
      if (!mounted || currentReq != _requestId) return;

      dynamic rawData = res;
      if (res is Map<String, dynamic> && res.containsKey('data')) {
        rawData = res['data'];
      } else if (res is Map<String, dynamic> && res.containsKey('items')) {
        rawData = res['items'];
      }

      List<dynamic> emps = [];
      if (rawData is List) {
        emps = rawData;
      }

      if (!mounted || currentReq != _requestId) return;
      setState(() {
        _employees = emps;
        _isLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted || currentReq != _requestId) return;
      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
        _employees = [];
      });
    } catch (e) {
      if (!mounted || currentReq != _requestId) return;
      setState(() {
        _errorMessage = 'Failed to load employee directory. Please check network connection.';
        _isLoading = false;
        _employees = [];
      });
    }
  }

  List<dynamic> get _filteredEmployees {
    return _employees.where((e) {
      final name = (e['fullName'] ?? '${e['firstName'] ?? ''} ${e['lastName'] ?? ''}').toString().toLowerCase();
      final email = (e['email'] ?? '').toString().toLowerCase();
      final empCode = (e['employeeCode'] ?? e['employeeId'] ?? e['code'] ?? '').toString().toLowerCase();
      final dept = (e['department'] ?? '').toString().toLowerCase();
      final desig = (e['designation'] ?? '').toString().toLowerCase();
      final team = (e['teamName'] ?? e['team'] ?? '').toString().toLowerCase();

      final search = _searchTerm.trim().toLowerCase();

      return search.isEmpty ||
          name.contains(search) ||
          email.contains(search) ||
          empCode.contains(search) ||
          dept.contains(search) ||
          desig.contains(search) ||
          team.contains(search);
    }).toList();
  }

  List<dynamic> get _paginatedEmployees {
    final filtered = _filteredEmployees;
    if (filtered.isEmpty) return [];
    final startIndex = (_currentPage - 1) * _pageSize;
    if (startIndex >= filtered.length) return [];
    final endIndex = (startIndex + _pageSize < filtered.length) ? startIndex + _pageSize : filtered.length;
    return filtered.sublist(startIndex, endIndex);
  }

  int get _totalPages {
    final count = _filteredEmployees.length;
    return (count / _pageSize).ceil() > 0 ? (count / _pageSize).ceil() : 1;
  }

  Map<String, dynamic> _getRoleBadgeStyle(String roleStr, bool isDark) {
    final role = roleStr.toUpperCase().trim();
    if (role.contains('ADMIN')) {
      return {'bg': isDark ? const Color(0x339333EA) : const Color(0xFFF3E8FF), 'fg': const Color(0xFF9333EA), 'label': 'ADMIN'};
    } else if (role.contains('HR')) {
      return {'bg': isDark ? const Color(0x3316A34A) : const Color(0xFFDCFCE7), 'fg': const Color(0xFF16A34A), 'label': 'HR'};
    } else if (role.contains('TL') || role.contains('LEAD')) {
      return {'bg': isDark ? const Color(0x332563EB) : const Color(0xFFE0EDFF), 'fg': const Color(0xFF2563EB), 'label': 'TL'};
    } else if (role.contains('FINANCE')) {
      return {'bg': isDark ? const Color(0x33D97706) : const Color(0xFFFEF3C7), 'fg': const Color(0xFFD97706), 'label': 'FINANCE'};
    } else if (role.contains('IT')) {
      return {'bg': isDark ? const Color(0x330891B2) : const Color(0xFFCFFAFE), 'fg': const Color(0xFF0891B2), 'label': 'IT'};
    } else {
      return {'bg': isDark ? const Color(0x3364748B) : const Color(0xFFF1F5F9), 'fg': const Color(0xFF64748B), 'label': 'EMPLOYEE'};
    }
  }

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBgColor = isDark ? AppColors.darkMainSurface : Colors.white;

    ref.listen<AuthState>(authServiceProvider, (previous, next) {
      if (next.user?.id != _currentUserId) {
        _checkUserAndLoad();
      }
    });

    final authState = ref.watch(authServiceProvider);
    final userRole = authState.user?.role;
    final bool isAuthorized = userRole == UserRole.ADMIN || userRole == UserRole.HR;

    final mainContent = !isAuthorized
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
                    Text('You do not have permissions to view employee management records.', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: glass.textSecondary)),
                  ],
                ),
              ),
            ),
          )
        : RefreshIndicator(
            onRefresh: _loadEmployees,
            child: _buildMainContent(glass, cardBgColor, isDark),
          );

    return GlassScaffold(
      appBar: GlassHeader(
        title: 'Employee Management',
        actions: [
          if (isAuthorized)
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Refresh',
              onPressed: _loadEmployees,
            ),
        ],
      ),
      body: mainContent,
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
              Text('Unable to Load Employees', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: glass.textPrimary)),
              const SizedBox(height: 8),
              Text(_errorMessage!, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: glass.textSecondary)),
              const SizedBox(height: 24),
              AppButton(label: 'Retry', icon: Icons.refresh_rounded, width: 140, onPressed: _loadEmployees),
            ],
          ),
        ),
      );
    }

    final filtered = _filteredEmployees;
    final paginated = _paginatedEmployees;
    final startIndex = filtered.isEmpty ? 0 : (_currentPage - 1) * _pageSize + 1;
    final endIndex = (_currentPage * _pageSize < filtered.length) ? _currentPage * _pageSize : filtered.length;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Role Filter Pills Row matching Website
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _roles.map((r) {
                final isSelected = _selectedRole == r['value'];
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _selectedRole = r['value']!;
                        _currentPage = 1;
                      });
                      _loadEmployees();
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFFD97706)
                            : (dark ? AppColors.darkSecondarySurface : const Color(0xFFF1F5F9)),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? const Color(0xFFD97706) : (dark ? AppColors.darkBordersAndDividers : const Color(0xFFE2E8F0)),
                        ),
                      ),
                      child: Text(
                        r['label']!,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                          color: isSelected ? Colors.white : (dark ? AppColors.darkPrimaryText : const Color(0xFF64748B)),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 14),

          // Search Box
          TextField(
            decoration: InputDecoration(
              hintText: 'Search by employee name, email, code, designation...',
              hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
              prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF94A3B8), size: 20),
              suffixIcon: _searchTerm.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18, color: Color(0xFF94A3B8)),
                      onPressed: () => setState(() {
                        _searchTerm = '';
                        _currentPage = 1;
                      }),
                    )
                  : null,
              filled: true,
              fillColor: dark ? AppColors.darkSecondarySurface : Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            ),
            style: TextStyle(color: dark ? AppColors.darkPrimaryText : const Color(0xFF0F172A), fontSize: 13),
            onChanged: (val) {
              setState(() {
                _searchTerm = val;
                _currentPage = 1;
              });
            },
          ),
          const SizedBox(height: 14),

          // Employees Feed
          if (filtered.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 16),
              alignment: Alignment.center,
              child: Column(
                children: [
                  Icon(Icons.people_outline_rounded, size: 56, color: glass.textSecondary.withAlpha(128)),
                  const SizedBox(height: 16),
                  Text('No Employees Found', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: glass.textPrimary)),
                  const SizedBox(height: 8),
                  Text('No employee records match the selected role filter or search criteria.', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: glass.textSecondary)),
                ],
              ),
            )
          else ...[
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: paginated.length,
              itemBuilder: (context, index) {
                final emp = paginated[index];
                final name = emp['fullName'] ?? '${emp['firstName'] ?? ''} ${emp['lastName'] ?? ''}'.trim();
                final code = emp['employeeCode'] ?? emp['employeeId'] ?? emp['code'] ?? 'EMP';
                final dept = emp['department'] ?? 'General';
                final desig = emp['designation'] ?? 'Staff';
                final email = emp['email'] ?? '';
                final team = emp['teamName'] ?? emp['team'] ?? '';
                final roleStr = emp['role']?.toString() ?? 'EMPLOYEE';

                final badgeStyle = _getRoleBadgeStyle(roleStr, dark);

                return AppCard(
                  backgroundColor: dark ? AppColors.darkMainSurface : Colors.white,
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: (badgeStyle['fg'] as Color).withAlpha(30),
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : 'E',
                          style: TextStyle(color: badgeStyle['fg'] as Color, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14.5,
                                color: dark ? AppColors.darkPrimaryText : const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$code • $dept • $desig',
                              style: const TextStyle(color: Color(0xFF64748B), fontSize: 11.5, fontWeight: FontWeight.w500),
                            ),
                            if (email.toString().isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                team.toString().isNotEmpty ? '$email • $team' : email.toString(),
                                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10.5),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: badgeStyle['bg'] as Color,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          badgeStyle['label'] as String,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: badgeStyle['fg'] as Color,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            // Pagination Controls Footer
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Showing $startIndex to $endIndex of ${filtered.length} entries',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left_rounded, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: _currentPage > 1 ? () => setState(() => _currentPage--) : null,
                    ),
                    const SizedBox(width: 8),
                    Text('Page $_currentPage', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: dark ? AppColors.darkPrimaryText : const Color(0xFF0F172A))),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.chevron_right_rounded, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: _currentPage < _totalPages ? () => setState(() => _currentPage++) : null,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
