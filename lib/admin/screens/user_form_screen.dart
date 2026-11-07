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

class UserFormScreen extends ConsumerStatefulWidget {
  final String? userId;
  final Map<String, dynamic>? initialData;

  const UserFormScreen({super.key, this.userId, this.initialData});

  @override
  ConsumerState<UserFormScreen> createState() => _UserFormScreenState();
}

class _UserFormScreenState extends ConsumerState<UserFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;

  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  String _role = 'Employee';
  String _department = 'Engineering';
  String _status = 'ACTIVE';
  bool _mfaEnabled = false;

  final List<String> _roles = ['Super Admin', 'HR Admin', 'Finance Admin', 'Department Manager', 'Team Lead', 'Employee'];
  final List<String> _departments = ['Engineering', 'Human Resources', 'Sales', 'Finance', 'Marketing', 'Operations', 'Management'];

  // Request ID guard
  int _requestId = 0;
  String? _currentUserId;

  bool get _isEdit => widget.userId != null || widget.initialData != null;

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

    if (widget.initialData != null) {
      _populateData(widget.initialData!);
      setState(() => _isLoading = false);
    } else if (_isEdit && widget.userId != null) {
      _loadUserDetail();
    } else {
      setState(() => _isLoading = false);
    }
  }

  void _resetState() {
    _usernameController.clear();
    _nameController.clear();
    _emailController.clear();
    _phoneController.clear();
    _role = 'Employee';
    _department = 'Engineering';
    _status = 'ACTIVE';
    _mfaEnabled = false;
  }

  void _populateData(Map<String, dynamic> data) {
    _usernameController.text = data['username']?.toString() ?? '';
    _nameController.text = data['name']?.toString() ?? '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'.trim();
    _emailController.text = data['email']?.toString() ?? '';
    _phoneController.text = data['phone']?.toString() ?? '';
    
    final r = data['role']?.toString() ?? 'Employee';
    if (_roles.contains(r)) {
      _role = r;
    } else {
      final rUpper = r.toUpperCase();
      if (rUpper == 'ADMIN' || rUpper == 'SUPERADMIN') {
        _role = 'Super Admin';
      } else if (rUpper == 'HR' || rUpper == 'HR_MANAGER') {
        _role = 'HR Admin';
      } else if (rUpper == 'FINANCE') {
        _role = 'Finance Admin';
      } else if (rUpper == 'MANAGER') {
        _role = 'Department Manager';
      } else if (rUpper == 'TL') {
        _role = 'Team Lead';
      } else {
        _role = 'Employee';
      }
    }

    _department = data['department']?.toString() ?? 'Engineering';

    final allowedStatuses = ['ACTIVE', 'INACTIVE'];
    final rawStatus = data['status'] ?? (data['isActive'] == false ? 'INACTIVE' : 'ACTIVE');
    _status = allowedStatuses.firstWhere(
      (s) => s.toLowerCase() == rawStatus.toString().toLowerCase(),
      orElse: () => 'ACTIVE',
    );

    _mfaEnabled = data['mfaEnabled'] == true || data['mfa'] == true || data['isMfaEnabled'] == true;
  }

  Future<void> _loadUserDetail() async {
    final currentReq = ++_requestId;
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final apiClient = ref.read(apiClientProvider);
      final res = await apiClient.get(ApiEndpoints.userDetail(widget.userId!));
      if (!mounted || currentReq != _requestId) return;

      dynamic rawData = res is Map<String, dynamic> && res.containsKey('data') ? res['data'] : res;
      if (rawData is Map<String, dynamic>) {
        _populateData(rawData);
      }

      if (!mounted || currentReq != _requestId) return;
      setState(() => _isLoading = false);
    } on ApiException catch (e) {
      if (!mounted || currentReq != _requestId) return;
      if (widget.initialData != null) {
        _populateData(widget.initialData!);
        setState(() => _isLoading = false);
      } else {
        setState(() {
          _errorMessage = e.message;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted || currentReq != _requestId) return;
      if (widget.initialData != null) {
        _populateData(widget.initialData!);
        setState(() => _isLoading = false);
      } else {
        setState(() {
          _errorMessage = 'Failed to load user account details. Please check network connection.';
          _isLoading = false;
        });
      }
    }
  }

  String _roleCode(String label) {
    switch (label) {
      case 'Super Admin': return 'ADMIN';
      case 'HR Admin': return 'HR';
      case 'Finance Admin': return 'FINANCE';
      case 'Department Manager': return 'MANAGER';
      case 'Team Lead': return 'TL';
      default: return 'EMPLOYEE';
    }
  }

  Future<void> _saveUser() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final currentReq = ++_requestId;
    final apiClient = ref.read(apiClientProvider);

    final nameParts = _nameController.text.trim().split(' ');
    final firstName = nameParts.isNotEmpty ? nameParts[0] : '';
    final lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';

    final payload = {
      'username': _usernameController.text.trim(),
      'firstName': firstName,
      'lastName': lastName,
      'email': _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
      'role': _roleCode(_role),
      'department': _department,
      'phone': _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
      'isActive': _status == 'ACTIVE',
      'mfaEnabled': _mfaEnabled,
    };

    try {
      String targetUserId = widget.userId ?? '';
      if (_isEdit && targetUserId.isNotEmpty) {
        await apiClient.put(ApiEndpoints.userDetail(targetUserId), body: payload).catchError((_) async {
          return await apiClient.put('/users/$targetUserId', body: payload);
        });
      } else {
        final createRes = await apiClient.post('/auth/register', body: payload).catchError((_) async {
          return await apiClient.post(ApiEndpoints.users, body: payload);
        });
        if (createRes is Map<String, dynamic>) {
          targetUserId = (createRes['id'] ?? createRes['_id'])?.toString() ?? '';
        }
      }

      if (targetUserId.isNotEmpty) {
        try {
          await apiClient.post(ApiEndpoints.userToggleMfa(targetUserId), body: _mfaEnabled).catchError((_) async {
            return await apiClient.post('/users/$targetUserId/toggle-mfa', body: _mfaEnabled);
          });
        } catch (_) {}
      }

      if (!mounted || currentReq != _requestId) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isEdit ? 'User updated successfully' : 'User created successfully'), backgroundColor: AppColors.success),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted || currentReq != _requestId) return;
      setState(() => _isSaving = false);
      final msg = e is ApiException ? e.message : 'Failed to save user account.';
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

    final screenTitle = _isEdit ? 'Edit User Account' : 'Add New User';
    final subtitle = _isEdit ? 'Modify user credentials, permissions, and security status' : 'Create a new user account and set system permissions';

    final bodyContent = !isAuthorized
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
                    Text('You do not have administrative permissions to configure user accounts.', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: glass.textSecondary)),
                  ],
                ),
              ),
            ),
          )
        : _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
                ? SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline_rounded, size: 54, color: Color(0xFFEF4444)),
                          const SizedBox(height: 16),
                          Text(_errorMessage!, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: glass.textSecondary)),
                          const SizedBox(height: 24),
                          AppButton(label: 'Retry', icon: Icons.refresh_rounded, width: 140, onPressed: _loadUserDetail),
                        ],
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Section Header Banner matching web
                          AppCard(
                            backgroundColor: cardBgColor,
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: const [
                                    Icon(Icons.admin_panel_settings_rounded, color: Color(0xFF0F6B66), size: 20),
                                    SizedBox(width: 8),
                                    Text('Edit Account Settings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text('Update system role permissions, contact profile, and multi-factor security rules.', style: TextStyle(fontSize: 11.5, color: glass.textSecondary)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // 1. ACCOUNT PROFILE CARD
                          AppCard(
                            backgroundColor: cardBgColor,
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('ACCOUNT PROFILE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.5)),
                                const SizedBox(height: 14),
                                TextFormField(
                                  controller: _usernameController,
                                  enabled: !_isSaving,
                                  decoration: InputDecoration(
                                    labelText: 'Username *',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  ),
                                  validator: (val) => (val == null || val.trim().isEmpty) ? 'Username is required' : null,
                                ),
                                const SizedBox(height: 14),
                                TextFormField(
                                  controller: _nameController,
                                  enabled: !_isSaving,
                                  decoration: InputDecoration(
                                    labelText: 'Full Name *',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  ),
                                  validator: (val) => (val == null || val.trim().isEmpty) ? 'Full name is required' : null,
                                ),
                                const SizedBox(height: 14),
                                TextFormField(
                                  controller: _emailController,
                                  enabled: !_isSaving,
                                  keyboardType: TextInputType.emailAddress,
                                  decoration: InputDecoration(
                                    labelText: 'Email Address *',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                TextFormField(
                                  controller: _phoneController,
                                  enabled: !_isSaving,
                                  keyboardType: TextInputType.phone,
                                  decoration: InputDecoration(
                                    labelText: 'Phone Number',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // 2. ROLE & DEPARTMENT ACCESS CARD
                          AppCard(
                            backgroundColor: cardBgColor,
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('ROLE & DEPARTMENT ACCESS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.5)),
                                const SizedBox(height: 14),
                                DropdownButtonFormField<String>(
                                  value: _roles.contains(_role) ? _role : 'Employee',
                                  decoration: InputDecoration(
                                    labelText: 'System Role *',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  ),
                                  items: _roles.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                                  onChanged: _isSaving ? null : (val) => setState(() => _role = val ?? 'Employee'),
                                ),
                                const SizedBox(height: 14),
                                DropdownButtonFormField<String>(
                                  value: _departments.contains(_department) ? _department : 'Engineering',
                                  decoration: InputDecoration(
                                    labelText: 'Department',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  ),
                                  items: _departments.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                                  onChanged: _isSaving ? null : (val) => setState(() => _department = val ?? 'Engineering'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // 3. SECURITY & ACCESS CONTROLS CARD
                          AppCard(
                            backgroundColor: cardBgColor,
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('SECURITY & ACCESS CONTROLS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.5)),
                                const SizedBox(height: 14),
                                DropdownButtonFormField<bool>(
                                  value: _mfaEnabled,
                                  decoration: InputDecoration(
                                    labelText: 'MFA Authentication Enforced',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  ),
                                  items: const [
                                    DropdownMenuItem(value: false, child: Text('No (Optional)')),
                                    DropdownMenuItem(value: true, child: Text('Yes (Required)')),
                                  ],
                                  onChanged: _isSaving ? null : (val) => setState(() => _mfaEnabled = val ?? false),
                                ),
                                const SizedBox(height: 14),
                                DropdownButtonFormField<String>(
                                  value: _status,
                                  decoration: InputDecoration(
                                    labelText: 'Account Status',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  ),
                                  items: const [
                                    DropdownMenuItem(value: 'ACTIVE', child: Text('ACTIVE')),
                                    DropdownMenuItem(value: 'INACTIVE', child: Text('INACTIVE')),
                                  ],
                                  onChanged: _isSaving ? null : (val) => setState(() => _status = val ?? 'ACTIVE'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Footer Buttons matching web
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: _isSaving ? null : () => Navigator.pop(context),
                                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                                  child: const Text('Cancel'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _isSaving ? null : _saveUser,
                                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F6B66), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                                  child: Text(_isSaving ? 'Saving...' : (_isEdit ? 'Save Changes' : 'Create User Account')),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );

    return GlassScaffold(
      appBar: GlassHeader(
        title: screenTitle,
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, size: 16),
            label: const Text('Back to Users'),
          ),
        ],
      ),
      body: bodyContent,
    );
  }
}
