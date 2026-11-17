import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/auth/auth_service.dart';
import '../../core/errors/api_exception.dart';
import '../../core/models/user_model.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme_tokens.dart';
import '../../core/theme/glass_theme.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/glass_header.dart';
import '../widgets/user_management_widgets.dart';

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

  bool _isCancelPressed = false;
  bool _isSavePressed = false;

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

  Widget _buildFieldWrapper({
    required String label,
    required bool isRequired,
    required Widget child,
    String? helperText,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Always-visible 12px medium label above field (6px gap)
        Text.rich(
          TextSpan(
            text: label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isDark ? AppColors.darkSecondaryText : const Color(0xFF475569),
            ),
            children: isRequired
                ? [
                    const TextSpan(
                      text: ' *',
                      style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ]
                : [],
          ),
        ),
        const SizedBox(height: 6),
        child,
        if (helperText != null) ...[
          const SizedBox(height: 4),
          Text(
            helperText,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppColors.darkMutedText : const Color(0xFF475569),
            ),
          ),
        ],
      ],
    );
  }

  InputDecoration _fieldDecoration({
    required IconData icon,
    required bool isDark,
    required Color borderColor,
    String? hintText,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(
        fontSize: 13,
        color: isDark ? AppColors.darkMutedText : const Color(0xFF94A3B8),
      ),
      prefixIcon: Icon(icon, size: 18, color: const Color(0xFF64748B)),
      filled: true,
      fillColor: isDark ? AppColors.darkMainSurface : Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor, width: 1)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor, width: 1)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBgColor = isDark ? AppColors.darkMainSurface : Colors.white;
    final borderColor = isDark ? AppColors.darkBordersAndDividers : const Color(0xFFCBD5E1);

    ref.listen<AuthState>(authServiceProvider, (previous, next) {
      if (next.user?.id != _currentUserId) {
        _checkUserAndLoad();
      }
    });

    final authState = ref.watch(authServiceProvider);
    final userRole = authState.user?.role;
    final bool isAuthorized = userRole == UserRole.ADMIN || userRole == UserRole.HR;

    final screenTitle = _isEdit ? 'Edit User Account' : 'Add New User';
    final userName = _nameController.text.trim().isNotEmpty ? _nameController.text.trim() : 'User Account';

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
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
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
                : Stack(
                    children: [
                      // Scrollable Form Content
                      SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // 1. Compact Info Banner (height 44px, padding 10px 12px, radius 14px, text 12px gray-700, icon 16px)
                              Container(
                                height: 44,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: cardBgColor,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.admin_panel_settings_rounded, color: AppColors.primary, size: 16),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _isEdit
                                            ? 'Update system role permissions, contact profile, and security rules.'
                                            : 'Create a new user account and set system permissions.',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: isDark ? AppColors.darkSecondaryText : const Color(0xFF334155),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),

                              // 2. Compact User Summary Card (padding 10px 12px, radius 16px, avatar 36px, name 15px semibold, email 12px gray-600)
                              if (_isEdit) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: cardBgColor,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
                                    boxShadow: [
                                      BoxShadow(
                                        color: isDark ? Colors.black12 : const Color(0x060F6B66),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 36,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withOpacity(0.18),
                                          shape: BoxShape.circle,
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                                          style: const TextStyle(color: Color(0xFF0F5F57), fontWeight: FontWeight.w600, fontSize: 15),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              userName,
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w600,
                                                color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 1),
                                            Text(
                                              _emailController.text,
                                              style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkSecondaryText : const Color(0xFF475569)),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      UserStatusBadge(status: _status),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],

                              // SECTION 1: ACCOUNT PROFILE CARD (padding 14px, radius 20px, 1px #E5E7EB border, 12px gap)
                              Container(
                                decoration: BoxDecoration(
                                  color: cardBgColor,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
                                  boxShadow: [
                                    BoxShadow(
                                      color: isDark ? Colors.black12 : const Color(0x060F6B66),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Section Header Title matching web HRMS reference
                                    Row(
                                      children: [
                                        const Icon(Icons.person_add_alt_1_rounded, size: 18, color: Color(0xFF0F5F57)),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                _isEdit ? 'Edit Account Settings' : 'User Account Details',
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFF0F5F57),
                                                ),
                                              ),
                                              const SizedBox(height: 1),
                                              Text(
                                                _isEdit
                                                    ? 'Update system role permissions, contact profile, and security rules.'
                                                    : 'Fill in the required information to provision a new user access credential.',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: isDark ? AppColors.darkSecondaryText : const Color(0xFF64748B),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Divider(height: 1, color: isDark ? AppColors.darkBordersAndDividers : const Color(0xFFE5E7EB)),
                                    const SizedBox(height: 12),

                                    // Sub-section header: ACCOUNT PROFILE
                                    Row(
                                      children: const [
                                        Icon(Icons.person_outline_rounded, size: 15, color: Color(0xFF0F5F57)),
                                        SizedBox(width: 6),
                                        Text(
                                          'ACCOUNT PROFILE',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF0F5F57),
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),

                                    // Username Field (48px, radius 12px, 14px text)
                                    _buildFieldWrapper(
                                      label: 'Username',
                                      isRequired: true,
                                      isDark: isDark,
                                      child: SizedBox(
                                        height: 48,
                                        child: TextFormField(
                                          controller: _usernameController,
                                          enabled: !_isSaving,
                                          decoration: _fieldDecoration(
                                            icon: Icons.alternate_email_rounded,
                                            isDark: isDark,
                                            borderColor: borderColor,
                                            hintText: 'e.g. jdoe',
                                          ),
                                          style: TextStyle(fontSize: 14, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText),
                                          validator: (val) => (val == null || val.trim().isEmpty) ? 'Username is required' : null,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 12),

                                    // Full Name Field
                                    _buildFieldWrapper(
                                      label: 'Full Name',
                                      isRequired: true,
                                      isDark: isDark,
                                      child: SizedBox(
                                        height: 48,
                                        child: TextFormField(
                                          controller: _nameController,
                                          enabled: !_isSaving,
                                          decoration: _fieldDecoration(
                                            icon: Icons.badge_outlined,
                                            isDark: isDark,
                                            borderColor: borderColor,
                                            hintText: 'e.g. John Doe',
                                          ),
                                          style: TextStyle(fontSize: 14, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText),
                                          validator: (val) => (val == null || val.trim().isEmpty) ? 'Full name is required' : null,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 12),

                                    // Email Address Field
                                    _buildFieldWrapper(
                                      label: 'Email Address',
                                      isRequired: true,
                                      isDark: isDark,
                                      child: SizedBox(
                                        height: 48,
                                        child: TextFormField(
                                          controller: _emailController,
                                          enabled: !_isSaving,
                                          keyboardType: TextInputType.emailAddress,
                                          decoration: _fieldDecoration(
                                            icon: Icons.mail_outline_rounded,
                                            isDark: isDark,
                                            borderColor: borderColor,
                                            hintText: 'john.doe@company.com',
                                          ),
                                          style: TextStyle(fontSize: 14, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 12),

                                    // Phone Number Field
                                    _buildFieldWrapper(
                                      label: 'Phone Number',
                                      isRequired: false,
                                      isDark: isDark,
                                      child: SizedBox(
                                        height: 48,
                                        child: TextFormField(
                                          controller: _phoneController,
                                          enabled: !_isSaving,
                                          keyboardType: TextInputType.phone,
                                          decoration: _fieldDecoration(
                                            icon: Icons.phone_outlined,
                                            isDark: isDark,
                                            borderColor: borderColor,
                                            hintText: '+91 98765 43210',
                                          ),
                                          style: TextStyle(fontSize: 14, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),

                              // SECTION 2: ROLE & DEPARTMENT ACCESS CARD
                              Container(
                                decoration: BoxDecoration(
                                  color: cardBgColor,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
                                  boxShadow: [
                                    BoxShadow(
                                      color: isDark ? Colors.black12 : const Color(0x060F6B66),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: const [
                                        Icon(Icons.admin_panel_settings_outlined, size: 16, color: Color(0xFF0F5F57)),
                                        SizedBox(width: 8),
                                        Text(
                                          'ROLE & DEPARTMENT ACCESS',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF0F5F57),
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),

                                    // System Role Dropdown
                                    _buildFieldWrapper(
                                      label: 'System Role',
                                      isRequired: true,
                                      isDark: isDark,
                                      helperText: 'Defines administrative privileges across all system modules',
                                      child: SizedBox(
                                        height: 48,
                                        child: DropdownButtonFormField<String>(
                                          value: _roles.contains(_role) ? _role : 'Employee',
                                          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: AppColors.primary),
                                          decoration: _fieldDecoration(icon: Icons.security_rounded, isDark: isDark, borderColor: borderColor),
                                          dropdownColor: cardBgColor,
                                          style: TextStyle(fontSize: 14, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText),
                                          items: _roles.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                                          onChanged: _isSaving ? null : (val) => setState(() => _role = val ?? 'Employee'),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 12),

                                    // Department Dropdown
                                    _buildFieldWrapper(
                                      label: 'Department',
                                      isRequired: false,
                                      isDark: isDark,
                                      child: SizedBox(
                                        height: 48,
                                        child: DropdownButtonFormField<String>(
                                          value: _departments.contains(_department) ? _department : 'Engineering',
                                          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: AppColors.primary),
                                          decoration: _fieldDecoration(icon: Icons.business_rounded, isDark: isDark, borderColor: borderColor),
                                          dropdownColor: cardBgColor,
                                          style: TextStyle(fontSize: 14, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText),
                                          items: _departments.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                                          onChanged: _isSaving ? null : (val) => setState(() => _department = val ?? 'Engineering'),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),

                              // SECTION 3: SECURITY & STATUS CARD (matching web HRMS reference)
                              Container(
                                decoration: BoxDecoration(
                                  color: cardBgColor,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
                                  boxShadow: [
                                    BoxShadow(
                                      color: isDark ? Colors.black12 : const Color(0x060F6B66),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: const [
                                        Icon(Icons.security_outlined, size: 16, color: Color(0xFF0F5F57)),
                                        SizedBox(width: 8),
                                        Text(
                                          'SECURITY & STATUS',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF0F5F57),
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),

                                    // MFA Authentication Enforced Dropdown
                                    _buildFieldWrapper(
                                      label: 'MFA Authentication Enforced',
                                      isRequired: false,
                                      isDark: isDark,
                                      helperText: 'Requires multi-factor authentication code at login',
                                      child: SizedBox(
                                        height: 48,
                                        child: DropdownButtonFormField<bool>(
                                          value: _mfaEnabled,
                                          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: AppColors.primary),
                                          decoration: _fieldDecoration(icon: Icons.phonelink_lock_rounded, isDark: isDark, borderColor: borderColor),
                                          dropdownColor: cardBgColor,
                                          style: TextStyle(fontSize: 14, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText),
                                          items: const [
                                            DropdownMenuItem(value: false, child: Text('No (Optional)')),
                                            DropdownMenuItem(value: true, child: Text('Yes (Required)')),
                                          ],
                                          onChanged: _isSaving ? null : (val) => setState(() => _mfaEnabled = val ?? false),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 12),

                                    // Account Status Dropdown with small 8px colored dot display
                                    _buildFieldWrapper(
                                      label: 'Account Status',
                                      isRequired: false,
                                      isDark: isDark,
                                      child: SizedBox(
                                        height: 48,
                                        child: DropdownButtonFormField<String>(
                                          value: _status,
                                          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: AppColors.primary),
                                          decoration: _fieldDecoration(icon: Icons.toggle_on_outlined, isDark: isDark, borderColor: borderColor),
                                          dropdownColor: cardBgColor,
                                          style: TextStyle(fontSize: 14, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText),
                                          items: [
                                            DropdownMenuItem(
                                              value: 'ACTIVE',
                                              child: Row(
                                                children: [
                                                  SizedBox.square(dimension: 8, child: DecoratedBox(decoration: BoxDecoration(color: Color(0xFF16A34A), shape: BoxShape.circle))),
                                                  const SizedBox(width: 8),
                                                  const Text('Active'),
                                                ],
                                              ),
                                            ),
                                            DropdownMenuItem(
                                              value: 'INACTIVE',
                                              child: Row(
                                                children: [
                                                  SizedBox.square(dimension: 8, child: DecoratedBox(decoration: BoxDecoration(color: Color(0xFF64748B), shape: BoxShape.circle))),
                                                  const SizedBox(width: 8),
                                                  const Text('Inactive'),
                                                ],
                                              ),
                                            ),
                                          ],
                                          onChanged: _isSaving ? null : (val) => setState(() => _status = val ?? 'ACTIVE'),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // SECTION 7: BOTTOM BAR (Transparent-to-page-background fade 24px, equal-width 48px buttons, shadow 0 4px 12px rgba(13,110,100,0.22), scale 0.98 pressed)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                (isDark ? AppColors.darkAppBackground : AppColors.lightAppBackground).withOpacity(0.0),
                                (isDark ? AppColors.darkAppBackground : AppColors.lightAppBackground).withOpacity(0.95),
                                isDark ? AppColors.darkAppBackground : AppColors.lightAppBackground,
                              ],
                              stops: const [0.0, 0.3, 1.0],
                            ),
                          ),
                          padding: EdgeInsets.fromLTRB(
                            16,
                            16,
                            16,
                            12 + MediaQuery.of(context).padding.bottom,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTapDown: (_) => setState(() => _isCancelPressed = true),
                                  onTapUp: (_) {
                                    setState(() => _isCancelPressed = false);
                                    if (!_isSaving) Navigator.pop(context);
                                  },
                                  onTapCancel: () => setState(() => _isCancelPressed = false),
                                  child: AnimatedScale(
                                    scale: _isCancelPressed ? 0.98 : 1.0,
                                    duration: const Duration(milliseconds: 100),
                                    child: Container(
                                      height: 48,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: cardBgColor,
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(color: const Color(0xFFCBD5E1), width: 1),
                                      ),
                                      child: const Text(
                                        'Cancel',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF334155),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: GestureDetector(
                                  onTapDown: (_) => setState(() => _isSavePressed = true),
                                  onTapUp: (_) {
                                    setState(() => _isSavePressed = false);
                                    if (!_isSaving) _saveUser();
                                  },
                                  onTapCancel: () => setState(() => _isSavePressed = false),
                                  child: AnimatedScale(
                                    scale: _isSavePressed ? 0.98 : 1.0,
                                    duration: const Duration(milliseconds: 100),
                                    child: Container(
                                      height: 48,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF0F5F57),
                                        borderRadius: BorderRadius.circular(14),
                                        boxShadow: const [
                                          BoxShadow(
                                            color: Color.fromRGBO(13, 110, 100, 0.22),
                                            blurRadius: 12,
                                            offset: Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.check_rounded, size: 18, color: Colors.white),
                                          const SizedBox(width: 6),
                                          Text(
                                            _isSaving ? 'Saving...' : (_isEdit ? 'Save Changes' : 'Create User Account'),
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );

    return GlassScaffold(
      appBar: GlassHeader(
        title: screenTitle,
        showBackButton: true,
        onBackPressed: () => Navigator.pop(context),
      ),
      body: bodyContent,
    );
  }
}
