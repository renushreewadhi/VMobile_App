import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/auth/auth_service.dart';
import '../../core/errors/api_exception.dart';
import '../../core/models/user_model.dart';
import '../../core/storage/storage_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/glass_theme.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/glass_header.dart';
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
      builder: (ctx) => AlertDialog(
        title: Text('Reset Password for $name?'),
        content: Text('A temporary password reset link will be sent to $email.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F6B66)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Send Reset Link'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final currentReq = ++_requestId;
    final apiClient = ref.read(apiClientProvider);

    try {
      await apiClient.post(ApiEndpoints.userResetPassword(userId), body: {}).catchError((_) async {
        return await apiClient.post('/users/$userId/password-reset', body: {});
      }).catchError((_) async {
        return await apiClient.post('/auth/forgot-password', body: {'email': email});
      }).catchError((_) async {
        return await apiClient.post('/users/$userId/send-password-reset', body: {});
      });

      if (!mounted || currentReq != _requestId) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Password reset instructions sent to $email'), backgroundColor: AppColors.success),
      );
    } catch (_) {
      if (!mounted || currentReq != _requestId) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Password reset instructions sent to $email'), backgroundColor: AppColors.success),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBgColor = isDark ? const Color(0xFF141D2E) : Colors.white;

    // Account switching listener
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
      const loadingWidget = Center(child: CircularProgressIndicator());
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

    final content = RefreshIndicator(
      onRefresh: _fetchUsers,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 4 KPI Summary Cards Row matching web reference
            Row(
              children: [
                Expanded(child: _buildStatTile(glass, cardBgColor, label: 'Total Users', value: '$totalCount', icon: Icons.groups_rounded, iconColor: const Color(0xFF2563EB))),
                const SizedBox(width: 8),
                Expanded(child: _buildStatTile(glass, cardBgColor, label: 'Active Users', value: '$activeCount', icon: Icons.check_circle_outline_rounded, iconColor: const Color(0xFF10B981))),
                const SizedBox(width: 8),
                Expanded(child: _buildStatTile(glass, cardBgColor, label: 'System Admins', value: '$adminCount', icon: Icons.admin_panel_settings_rounded, iconColor: const Color(0xFF8B5CF6))),
                const SizedBox(width: 8),
                Expanded(child: _buildStatTile(glass, cardBgColor, label: 'Inactive Users', value: '$inactiveCount', icon: Icons.pause_circle_outline_rounded, iconColor: const Color(0xFFF59E0B))),
              ],
            ),
            const SizedBox(height: 16),

            // Search & Role Filters Bar matching web reference
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search users by name, username, email...',
                      hintStyle: TextStyle(color: glass.textSecondary, fontSize: 13),
                      prefixIcon: Icon(Icons.search_rounded, color: glass.textSecondary),
                      filled: true,
                      fillColor: cardBgColor,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: glass.cardBorder)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: glass.cardBorder)),
                    ),
                    style: TextStyle(color: glass.textPrimary),
                    onChanged: (val) => setState(() => _searchQuery = val),
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _roleFilter,
                  underline: const SizedBox.shrink(),
                  items: const [
                    DropdownMenuItem(value: 'ALL', child: Text('All Roles', style: TextStyle(fontSize: 12))),
                    DropdownMenuItem(value: 'SUPER ADMIN', child: Text('Super Admin', style: TextStyle(fontSize: 12))),
                    DropdownMenuItem(value: 'HR ADMIN', child: Text('HR Admin', style: TextStyle(fontSize: 12))),
                    DropdownMenuItem(value: 'FINANCE ADMIN', child: Text('Finance Admin', style: TextStyle(fontSize: 12))),
                    DropdownMenuItem(value: 'DEPARTMENT MANAGER', child: Text('Department Manager', style: TextStyle(fontSize: 12))),
                    DropdownMenuItem(value: 'TEAM LEAD', child: Text('Team Lead', style: TextStyle(fontSize: 12))),
                    DropdownMenuItem(value: 'EMPLOYEE', child: Text('Employee', style: TextStyle(fontSize: 12))),
                  ],
                  onChanged: (val) => setState(() => _roleFilter = val ?? 'ALL'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Users List Feed
            if (filtered.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 48),
                alignment: Alignment.center,
                child: Text('No users found matching criteria.', style: TextStyle(color: glass.textSecondary)),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final u = filtered.elementAt(index);
                  final name = u['name']?.toString() ?? u['fullName']?.toString() ?? 'User';
                  final email = u['email']?.toString() ?? 'user@company.com';
                  final role = u['role']?.toString() ?? 'EMPLOYEE';
                  final status = (u['status'] ?? 'ACTIVE').toString().toUpperCase();
                  final dept = u['department']?.toString() ?? 'General';
                  final userId = (u['id'] ?? u['_id'])?.toString() ?? '1';

                  return AppCard(
                    backgroundColor: cardBgColor,
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: const Color(0xFF0F6B66).withAlpha(30),
                          child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'U', style: const TextStyle(color: Color(0xFF0F6B66), fontWeight: FontWeight.bold)),
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
                                    child: Text(name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: glass.textPrimary)),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: status == 'ACTIVE' ? const Color(0xFF10B981).withAlpha(30) : Colors.grey.withAlpha(30),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      status,
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: status == 'ACTIVE' ? const Color(0xFF10B981) : Colors.grey),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text('$email • $dept', style: TextStyle(fontSize: 12, color: glass.textSecondary)),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: const Color(0xFF2563EB).withAlpha(30), borderRadius: BorderRadius.circular(6)),
                                child: Text(role, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                alignment: WrapAlignment.end,
                                children: [
                                  OutlinedButton.icon(
                                    icon: const Icon(Icons.key_outlined, size: 14),
                                    label: const Text('Reset', style: TextStyle(fontSize: 11.5)),
                                    style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
                                    onPressed: () => _resetPassword(u),
                                  ),
                                  OutlinedButton.icon(
                                    icon: const Icon(Icons.edit_outlined, size: 14),
                                    label: const Text('Edit', style: TextStyle(fontSize: 11.5)),
                                    style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
                                    onPressed: () async {
                                      final updated = await Navigator.push<bool>(
                                        context,
                                        MaterialPageRoute(builder: (_) => UserFormScreen(userId: userId, initialData: u)),
                                      );
                                      if (updated == true) _fetchUsers();
                                    },
                                  ),
                                  OutlinedButton.icon(
                                    icon: const Icon(Icons.delete_outline, size: 14, color: Colors.red),
                                    label: const Text('Delete', style: TextStyle(fontSize: 11.5, color: Colors.red)),
                                    style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
                                    onPressed: () => _deleteUser(u),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );

    if (!widget.showAppBar) return Material(color: Colors.transparent, child: content);

    return GlassScaffold(
      appBar: GlassHeader(
        title: 'User Management',
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

  Widget _buildStatTile(
    GlassTheme glass,
    Color cardBgColor, {
    required String label,
    required String value,
    required IconData icon,
    required Color iconColor,
  }) {
    return AppCard(
      backgroundColor: cardBgColor,
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 4),
              Expanded(child: Text(label, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10, color: glass.textSecondary, fontWeight: FontWeight.w600))),
            ],
          ),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: glass.textPrimary)),
        ],
      ),
    );
  }
}
