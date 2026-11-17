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
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/glass_header.dart';
import '../widgets/admin_dashboard_widgets.dart';
import '../widgets/user_management_widgets.dart';
import 'user_form_screen.dart';

class UserManagementScreen extends ConsumerStatefulWidget {
  final bool showAppBar;
  const UserManagementScreen({super.key, this.showAppBar = false});

  @override
  ConsumerState<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends ConsumerState<UserManagementScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<dynamic> _users = [];
  String _searchQuery = '';
  String _roleFilter = 'ALL';
  String _statusFilter = 'ALL';
  int _currentPage = 1;
  final int _pageSize = 10;

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

    _fetchUsers();
  }

  void _resetState() {
    _users = [];
    _searchQuery = '';
    _roleFilter = 'ALL';
    _statusFilter = 'ALL';
  }

  List<dynamic> _extractList(dynamic res) {
    if (res == null) return [];
    if (res is List) return res;
    if (res is Map) {
      if (res['data'] is List) return res['data'] as List;
      if (res['items'] is List) return res['items'] as List;
      if (res['users'] is List) return res['users'] as List;
      if (res['result'] is List) return res['result'] as List;
      if (res['value'] is List) return res['value'] as List;
      if (res['data'] is Map) {
        final inner = res['data'] as Map;
        if (inner['items'] is List) return inner['items'] as List;
        if (inner['users'] is List) return inner['users'] as List;
        if (inner['data'] is List) return inner['data'] as List;
      }
    }
    return [];
  }

  Future<void> _fetchUsers() async {
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
      final res = await apiClient.get(ApiEndpoints.users).catchError((_) async {
        return await apiClient.get('/users').catchError((_) => null);
      });
      if (!mounted || currentReq != _requestId) return;

      final rawList = _extractList(res);
      List<dynamic> users = [];

      for (final u in rawList) {
        if (u is Map) {
          final map = Map<String, dynamic>.from(u);
          final firstName = map['firstName']?.toString() ?? '';
          final lastName = map['lastName']?.toString() ?? '';
          final fullName = '$firstName $lastName'.trim();
          final name = fullName.isNotEmpty ? fullName : (map['name']?.toString() ?? map['fullName']?.toString() ?? map['username']?.toString() ?? 'System User');

          final email = map['email']?.toString() ?? 'N/A';
          final username = map['username']?.toString() ?? (email.contains('@') ? email.split('@')[0] : 'user');
          final role = map['role']?.toString() ?? 'EMPLOYEE';
          final department = map['department']?.toString() ?? 'General';
          final status = (map['status'] ?? (map['isActive'] == false ? 'INACTIVE' : 'ACTIVE')).toString().toUpperCase();

          users.add({
            'id': map['id']?.toString() ?? map['_id']?.toString() ?? '',
            'username': username,
            'name': name,
            'email': email,
            'role': role,
            'department': department,
            'status': status,
            'lastLogin': map['lastLoginAt']?.toString() ?? 'Never',
            'mfa': map['mfaEnabled'] == true ? 'Yes' : 'No',
            ...map,
          });
        }
      }

      if (!mounted || currentReq != _requestId) return;
      setState(() {
        _users = users;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted || currentReq != _requestId) return;
      setState(() {
        _users = [];
        _isLoading = false;
        _errorMessage = 'Failed to load users: $e';
      });
    }
  }

  Future<void> _deleteUser(dynamic user) async {
    final userId = (user['id'] ?? user['_id'])?.toString();
    final name = user['name']?.toString() ?? user['fullName']?.toString() ?? 'User';

    if (userId == null || userId.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete user "$name"?'),
        content: const Text('This will permanently delete the user account.'),
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
      await apiClient.delete(ApiEndpoints.userDetail(userId));
      if (!mounted || currentReq != _requestId) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User deleted successfully')),
      );
      _fetchUsers();
    } catch (e) {
      if (!mounted || currentReq != _requestId) return;
      final msg = e is ApiException ? e.message : 'Failed to delete user.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _resetPassword(dynamic user) async {
    final userId = (user['id'] ?? user['_id'])?.toString();
    final name = user['name']?.toString() ?? user['fullName']?.toString() ?? 'User';
    final email = user['email']?.toString() ?? '';

    if (userId == null || userId.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black45,
      builder: (ctx) => ConfirmResetPasswordDialog(
        name: name,
        email: email,
        onConfirm: () => Navigator.pop(ctx, true),
        onCancel: () => Navigator.pop(ctx, false),
      ),
    );

    if (confirmed != true) return;

    final currentReq = ++_requestId;
    final apiClient = ref.read(apiClientProvider);

    try {
      try {
        await apiClient.post(ApiEndpoints.forgotPassword, body: {'email': email});
      } catch (_) {
        try {
          await apiClient.post(ApiEndpoints.userResetPassword(userId), body: {});
        } catch (_) {
          await apiClient.post('/users/$userId/password-reset', body: {});
        }
      }

      if (!mounted || currentReq != _requestId) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Password reset instructions sent to $email'), backgroundColor: AppColors.success),
      );
    } catch (e) {
      if (!mounted || currentReq != _requestId) return;
      final msg = e is ApiException ? e.message : 'Failed to send password reset instructions.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red),
      );
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

    if (!isAuthorized) {
      final restrictedContent = Center(
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
                Text('You do not have administrative permissions to manage user accounts.', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: glass.textSecondary)),
              ],
            ),
          ),
        ),
      );
      if (!widget.showAppBar) return Material(color: Colors.transparent, child: restrictedContent);
      return GlassScaffold(
        appBar: GlassHeader(title: 'User Management'),
        body: restrictedContent,
      );
    }

    if (_isLoading) {
      const loadingWidget = Center(child: CircularProgressIndicator(color: AppColors.primary));
      if (!widget.showAppBar) return Material(color: Colors.transparent, child: loadingWidget);
      return GlassScaffold(
        appBar: GlassHeader(title: 'User Management'),
        body: loadingWidget,
      );
    }

    if (_errorMessage != null) {
      final errorWidget = SingleChildScrollView(
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
              Text('Unable to Load Users', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: glass.textPrimary)),
              const SizedBox(height: 8),
              Text(_errorMessage!, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: glass.textSecondary)),
              const SizedBox(height: 24),
              AppButton(label: 'Retry', icon: Icons.refresh_rounded, width: 140, onPressed: _fetchUsers),
            ],
          ),
        ),
      );
      if (!widget.showAppBar) return Material(color: Colors.transparent, child: errorWidget);
      return GlassScaffold(
        appBar: GlassHeader(title: 'User Management'),
        body: errorWidget,
      );
    }

    final totalCount = _users.length;
    final activeCount = _users.where((u) => (u['status'] ?? 'ACTIVE').toString().toUpperCase() == 'ACTIVE').length;
    final inactiveCount = totalCount - activeCount;
    final adminCount = _users.where((u) => (u['role'] ?? '').toString().toUpperCase().contains('ADMIN')).length;

    final filtered = _users.where((u) {
      final name = (u['name'] ?? u['fullName'] ?? '').toString().toLowerCase();
      final email = (u['email'] ?? '').toString().toLowerCase();
      final role = (u['role'] ?? '').toString().toUpperCase();
      final status = (u['status'] ?? 'ACTIVE').toString().toUpperCase();

      final matchesSearch = _searchQuery.trim().isEmpty || name.contains(_searchQuery.toLowerCase()) || email.contains(_searchQuery.toLowerCase());
      final matchesRole = _roleFilter == 'ALL' || role.contains(_roleFilter);
      final matchesStatus = _statusFilter == 'ALL' || status == _statusFilter;

      return matchesSearch && matchesRole && matchesStatus;
    }).toList();

    final totalFilteredCount = filtered.length;
    final totalPages = (totalFilteredCount / _pageSize).ceil();
    final safePage = totalPages == 0 ? 1 : _currentPage.clamp(1, totalPages);
    final startIndex = (safePage - 1) * _pageSize;
    final endIndex = (startIndex + _pageSize).clamp(0, totalFilteredCount);
    final paginatedList = totalFilteredCount > 0 ? filtered.sublist(startIndex, endIndex) : <dynamic>[];

    final roles = [
      {'value': 'ALL', 'label': 'All Roles'},
      {'value': 'ADMIN', 'label': 'Administrator'},
      {'value': 'HR', 'label': 'HR Admin'},
      {'value': 'FINANCE', 'label': 'Finance Admin'},
      {'value': 'MANAGER', 'label': 'Dept Manager'},
      {'value': 'TL', 'label': 'Team Lead'},
      {'value': 'EMPLOYEE', 'label': 'Employee'},
    ];

    final content = RefreshIndicator(
      onRefresh: _fetchUsers,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Role Filter Pills Row matching Employee Management
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: roles.map((r) {
                  final isSelected = _roleFilter == r['value'];
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _roleFilter = r['value']!;
                          _currentPage = 1;
                        });
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFFD97706)
                              : (isDark ? AppColors.darkSecondarySurface : const Color(0xFFF1F5F9)),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected ? const Color(0xFFD97706) : (isDark ? AppColors.darkBordersAndDividers : const Color(0xFFE2E8F0)),
                          ),
                        ),
                        child: Text(
                          r['label']!,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                            color: isSelected ? Colors.white : (isDark ? AppColors.darkPrimaryText : const Color(0xFF64748B)),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 14),

            // Stat Cards (Row of 4)
            Row(
              children: [
                Expanded(child: UserStatTile(label: 'Total', value: '$totalCount', icon: Icons.groups_rounded, iconColor: const Color(0xFF2563EB))),
                const SizedBox(width: 8),
                Expanded(child: UserStatTile(label: 'Active', value: '$activeCount', icon: Icons.check_circle_outline_rounded, iconColor: const Color(0xFF16A34A))),
                const SizedBox(width: 8),
                Expanded(child: UserStatTile(label: 'Admin', value: '$adminCount', icon: Icons.admin_panel_settings_rounded, iconColor: const Color(0xFF8B5CF6))),
                const SizedBox(width: 8),
                Expanded(child: UserStatTile(label: 'Inactive', value: '$inactiveCount', icon: Icons.pause_circle_outline_rounded, iconColor: const Color(0xFFF59E0B))),
              ],
            ),
            const SizedBox(height: 14),

            // Search Bar matching Employee Management
            TextField(
              decoration: InputDecoration(
                hintText: 'Search by user name, email, role...',
                hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF94A3B8), size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18, color: Color(0xFF94A3B8)),
                        onPressed: () => setState(() {
                          _searchQuery = '';
                          _currentPage = 1;
                        }),
                      )
                    : null,
                filled: true,
                fillColor: isDark ? AppColors.darkSecondarySurface : Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              ),
              style: TextStyle(color: isDark ? AppColors.darkPrimaryText : const Color(0xFF0F172A), fontSize: 13),
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                  _currentPage = 1;
                });
              },
            ),
            const SizedBox(height: 14),

            // User Cards Feed
            if (filtered.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 16),
                alignment: Alignment.center,
                child: Column(
                  children: [
                    Icon(Icons.person_search_outlined, size: 56, color: glass.textSecondary.withAlpha(128)),
                    const SizedBox(height: 16),
                    Text('No Users Found', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: glass.textPrimary)),
                    const SizedBox(height: 8),
                    Text('No user records match the selected role filter or search criteria.', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: glass.textSecondary)),
                  ],
                ),
              )
            else ...[
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: paginatedList.length,
                itemBuilder: (context, index) {
                  final u = paginatedList.elementAt(index);
                  final userId = (u['id'] ?? u['_id'])?.toString() ?? '1';

                  return FadeSlideEntrance(
                    delay: (index * 0.05).clamp(0.0, 0.3),
                    child: UserCardTile(
                      user: u,
                      onEdit: () async {
                        final updated = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(builder: (_) => UserFormScreen(userId: userId, initialData: u)),
                        );
                        if (updated == true) _fetchUsers();
                      },
                      onReset: () => _resetPassword(u),
                      onDelete: () => _deleteUser(u),
                    ),
                  );
                },
              ),

              // Pagination Controls Footer matching Employee Management
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Showing ${totalFilteredCount > 0 ? startIndex + 1 : 0} to $endIndex of $totalFilteredCount entries',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left_rounded, size: 20),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: safePage > 1 ? () => setState(() => _currentPage = safePage - 1) : null,
                      ),
                      const SizedBox(width: 8),
                      Text('Page $safePage', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? AppColors.darkPrimaryText : const Color(0xFF0F172A))),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.chevron_right_rounded, size: 20),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: safePage < totalPages ? () => setState(() => _currentPage = safePage + 1) : null,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );

    if (!widget.showAppBar) return Material(color: Colors.transparent, child: content);

    return GlassScaffold(
      appBar: GlassHeader(
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1_rounded, size: 20),
            tooltip: 'Add New User',
            onPressed: () async {
              final created = await Navigator.push<bool>(
                context,
                MaterialPageRoute(builder: (_) => const UserFormScreen()),
              );
              if (created == true) _fetchUsers();
            },
          ),
        ],
      ),
      body: content,
    );
  }
}
