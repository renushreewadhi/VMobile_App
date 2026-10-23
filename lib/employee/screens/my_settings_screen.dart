import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../auth/login_screen.dart';
import '../../core/auth/auth_service.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/glass_theme.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/glass_app_bar.dart';
import '../../core/widgets/glass_card.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/status_chip.dart';

class MySettingsScreen extends ConsumerStatefulWidget {
  const MySettingsScreen({super.key});

  @override
  ConsumerState<MySettingsScreen> createState() => _MySettingsScreenState();
}

class _MySettingsScreenState extends ConsumerState<MySettingsScreen> {
  bool _loading = false;
  String _userEmail = 'user@hrms.com';
  String _userPhone = 'Not set';
  String _accountStatus = 'Active';
  String _lastLoginFormatted = 'Just now';
  String _lastLoginMeta = 'Current Session • Web Portal';
  bool _mfaEnabled = false;

  // Modals visibility
  bool _showPasswordModal = false;
  bool _showEmailModal = false;
  bool _showMobileModal = false;
  bool _showLoginHistoryModal = false;
  bool _showActiveDevicesModal = false;
  bool _showTrustedDevicesModal = false;
  bool _showLogoutAllModal = false;
  String? _activeGenericModal;

  // Password Form
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _showCurrentPassword = false;
  bool _showNewPassword = false;
  bool _showConfirmPassword = false;
  bool _savingPassword = false;

  // Email OTP Form
  final _emailInputController = TextEditingController();
  bool _emailOtpSent = false;
  final List<TextEditingController> _emailOtpControllers = List.generate(6, (_) => TextEditingController());
  int _emailOtpTimer = 30;
  bool _savingEmail = false;

  // Mobile OTP Form
  final _mobileInputController = TextEditingController();
  bool _mobileOtpSent = false;
  final List<TextEditingController> _mobileOtpControllers = List.generate(6, (_) => TextEditingController());
  int _mobileOtpTimer = 30;
  bool _savingMobile = false;

  // Authenticator Setup
  String _authenticatorSecret = '';
  String _authenticatorQrCode = '';
  final List<TextEditingController> _authOtpControllers = List.generate(6, (_) => TextEditingController());
  String _authenticatorStep = 'setup';
  List<String> _authenticatorBackupCodes = [];

  // Lists from Backend
  List<dynamic> _loginHistory = [];
  List<dynamic> _activeDevices = [];
  List<dynamic> _trustedDevices = [];

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadSettingsSummary();
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _emailInputController.dispose();
    _mobileInputController.dispose();
    for (var c in _emailOtpControllers) {
      c.dispose();
    }
    for (var c in _mobileOtpControllers) {
      c.dispose();
    }
    for (var c in _authOtpControllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final user = ref.read(authServiceProvider).user;
    if (user != null) {
      setState(() {
        _userEmail = user.email;
        _userPhone = user.phone ?? 'Not set';
      });
    }
  }

  Future<void> _loadSettingsSummary() async {
    final apiClient = ref.read(apiClientProvider);
    try {
      final res = await apiClient.get('/settings/summary').catchError((_) => null);
      if (res != null && res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          _mfaEnabled = data['mfaEnabled'] ?? false;
          _accountStatus = data['accountStatus'] ?? 'Active';
          if (data['lastLogin'] != null) {
            final date = DateTime.tryParse(data['lastLogin']['timestamp'] ?? '');
            if (date != null) {
              _lastLoginFormatted = DateFormat('MMM d, yyyy - hh:mm a').format(date);
            }
            _lastLoginMeta = '${data['lastLogin']['device'] ?? 'Mobile'} • ${data['lastLogin']['ip'] ?? 'Unknown'}';
          }
        });
      }
    } catch (_) {}
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _openChangePasswordModal() {
    _currentPasswordController.clear();
    _newPasswordController.clear();
    _confirmPasswordController.clear();
    setState(() => _showPasswordModal = true);
  }

  void _openEmailModal() {
    _emailInputController.text = _userEmail;
    _emailOtpSent = false;
    for (var c in _emailOtpControllers) {
      c.clear();
    }
    setState(() => _showEmailModal = true);
  }

  void _openMobileModal() {
    _mobileInputController.text = _userPhone == 'Not set' ? '' : _userPhone;
    _mobileOtpSent = false;
    for (var c in _mobileOtpControllers) {
      c.clear();
    }
    setState(() => _showMobileModal = true);
  }

  Future<void> _toggleMFA(bool val) async {
    final apiClient = ref.read(apiClientProvider);
    try {
      final res = await apiClient.post('/settings/mfa/toggle', body: {'enable': val}).catchError((_) => null);
      if (res != null && res.statusCode == 200) {
        setState(() => _mfaEnabled = val);
        _toast(val ? 'MFA Enabled' : 'MFA Disabled');
      } else {
        _toast('Failed to update MFA status');
      }
    } catch (_) {
      _toast('Network error');
    }
  }

  Future<void> _savePassword() async {
    final cur = _currentPasswordController.text;
    final newP = _newPasswordController.text;
    final conP = _confirmPasswordController.text;

    if (cur.isEmpty || newP.isEmpty || conP.isEmpty) {
      _toast('Please fill all fields');
      return;
    }
    if (newP != conP) {
      _toast('New passwords do not match');
      return;
    }

    setState(() => _savingPassword = true);
    final apiClient = ref.read(apiClientProvider);
    try {
      final res = await apiClient.post('/settings/password/change', body: {
        'currentPassword': cur,
        'newPassword': newP,
      }).catchError((_) => null);

      if (res != null && res.statusCode == 200) {
        _toast('Password updated successfully');
        setState(() => _showPasswordModal = false);
      } else {
        _toast('Failed to update password');
      }
    } catch (_) {
      _toast('Network error');
    } finally {
      setState(() => _savingPassword = false);
    }
  }

  Future<void> _sendEmailOtp() async {
    final email = _emailInputController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _toast('Enter a valid email');
      return;
    }
    final apiClient = ref.read(apiClientProvider);
    try {
      final res = await apiClient.post('/settings/otp/send', body: {'purpose': 'EmailChange', 'target': email}).catchError((_) => null);
      if (res != null && res.statusCode == 200) {
        setState(() => _emailOtpSent = true);
        _toast('OTP sent to $email');
      } else {
        _toast('Failed to send OTP');
      }
    } catch (_) {
      _toast('Network error');
    }
  }

  Future<void> _verifyEmailOtp() async {
    final otpCode = _emailOtpControllers.map((c) => c.text).join();
    if (otpCode.length < 6) {
      _toast('Enter 6-digit OTP');
      return;
    }
    setState(() => _savingEmail = true);
    final apiClient = ref.read(apiClientProvider);
    final email = _emailInputController.text.trim();
    try {
      final res = await apiClient.post('/settings/email/update', body: {'newEmail': email, 'otpCode': otpCode}).catchError((_) => null);
      if (res != null && res.statusCode == 200) {
        setState(() {
          _userEmail = email;
          _showEmailModal = false;
        });
        _toast('Email updated successfully');
        _loadSettingsSummary();
      } else {
        _toast('Invalid or expired OTP');
      }
    } catch (_) {
      _toast('Network error');
    } finally {
      setState(() => _savingEmail = false);
    }
  }

  Future<void> _sendMobileOtp() async {
    final mobile = _mobileInputController.text.trim();
    if (mobile.isEmpty) {
      _toast('Enter a mobile number');
      return;
    }
    final apiClient = ref.read(apiClientProvider);
    try {
      final res = await apiClient.post('/settings/otp/send', body: {'purpose': 'MobileChange', 'target': mobile}).catchError((_) => null);
      if (res != null && res.statusCode == 200) {
        setState(() => _mobileOtpSent = true);
        _toast('OTP sent to $mobile');
      } else {
        _toast('Failed to send OTP');
      }
    } catch (_) {
      _toast('Network error');
    }
  }

  Future<void> _verifyMobileOtp() async {
    final otpCode = _mobileOtpControllers.map((c) => c.text).join();
    if (otpCode.length < 6) {
      _toast('Enter 6-digit OTP');
      return;
    }
    setState(() => _savingMobile = true);
    final apiClient = ref.read(apiClientProvider);
    final mobile = _mobileInputController.text.trim();
    try {
      final res = await apiClient.post('/settings/mobile/update', body: {'newMobile': mobile, 'otpCode': otpCode}).catchError((_) => null);
      if (res != null && res.statusCode == 200) {
        setState(() {
          _userPhone = mobile;
          _showMobileModal = false;
        });
        _toast('Mobile number updated successfully');
        _loadSettingsSummary();
      } else {
        _toast('Invalid or expired OTP');
      }
    } catch (_) {
      _toast('Network error');
    } finally {
      setState(() => _savingMobile = false);
    }
  }

  Future<void> _openModal(String type) async {
    final apiClient = ref.read(apiClientProvider);
    if (type == 'loginHistory') {
      setState(() => _showLoginHistoryModal = true);
      try {
        final res = await apiClient.get('/settings/login-history').catchError((_) => null);
        if (res != null && res.statusCode == 200) {
          setState(() => _loginHistory = jsonDecode(res.body));
        }
      } catch (_) {}
    } else if (type == 'activeDevices') {
      setState(() => _showActiveDevicesModal = true);
      try {
        final res = await apiClient.get('/settings/devices/active').catchError((_) => null);
        if (res != null && res.statusCode == 200) {
          setState(() => _activeDevices = jsonDecode(res.body));
        }
      } catch (_) {}
    } else if (type == 'trustedDevices') {
      setState(() => _showTrustedDevicesModal = true);
      try {
        final res = await apiClient.get('/settings/devices/trusted').catchError((_) => null);
        if (res != null && res.statusCode == 200) {
          setState(() => _trustedDevices = jsonDecode(res.body));
        }
      } catch (_) {}
    } else if (type == 'authenticator') {
      setState(() {
        _activeGenericModal = 'authenticator';
        _authenticatorStep = 'setup';
      });
      try {
        final res = await apiClient.get('/settings/mfa/authenticator/setup').catchError((_) => null);
        if (res != null && res.statusCode == 200) {
          final data = jsonDecode(res.body);
          setState(() {
            _authenticatorSecret = data['secret'] ?? '';
            _authenticatorQrCode = data['qrCode'] ?? '';
          });
        }
      } catch (_) {}
    } else if (type == 'emailOtp') {
      setState(() => _activeGenericModal = 'emailOtp');
    }
  }

  Future<void> _verifyAuthenticator() async {
    final code = _authOtpControllers.map((c) => c.text).join();
    if (code.length < 6) {
      _toast('Enter 6-digit authenticator code');
      return;
    }
    final apiClient = ref.read(apiClientProvider);
    try {
      final res = await apiClient.post('/settings/mfa/authenticator/verify', body: {'code': code}).catchError((_) => null);
      if (res != null && res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          _authenticatorStep = 'backupCodes';
          _authenticatorBackupCodes = List<String>.from(data['backupCodes'] ?? []);
        });
        _toast('Authenticator app configured');
      } else {
        _toast('Invalid authenticator code');
      }
    } catch (_) {
      _toast('Network error');
    }
  }

  Future<void> _revokeDevice(String deviceId) async {
    final apiClient = ref.read(apiClientProvider);
    try {
      final res = await apiClient.post('/settings/devices/$deviceId/revoke', body: {}).catchError((_) => null);
      if (res != null && res.statusCode == 200) {
        setState(() => _activeDevices.removeWhere((d) => d['id'] == deviceId));
        _toast('Device session revoked');
      }
    } catch (_) {}
  }

  Future<void> _revokeTrustedDevice(String deviceId) async {
    final apiClient = ref.read(apiClientProvider);
    try {
      final res = await apiClient.post('/settings/devices/trusted/$deviceId/revoke', body: {}).catchError((_) => null);
      if (res != null && res.statusCode == 200) {
        setState(() => _trustedDevices.removeWhere((d) => d['id'] == deviceId));
        _toast('Trusted device removed');
      }
    } catch (_) {}
  }

  Future<void> _logoutAllDevices() async {
    final apiClient = ref.read(apiClientProvider);
    try {
      final res = await apiClient.post('/settings/devices/logout-all', body: {}).catchError((_) => null);
      if (res != null && res.statusCode == 200) {
        _toast('Logged out from all other devices');
        setState(() => _showLogoutAllModal = false);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;

    return GlassScaffold(
      appBar: const GlassAppBar(title: Text('Settings')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadSettingsSummary,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: glass.headerIconTileFill, borderRadius: BorderRadius.circular(14)),
                          child: Icon(Icons.settings, color: glass.headerIconColor, size: 26),
                        ),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Settings', style: Theme.of(context).textTheme.headlineLarge),
                            const SizedBox(height: 2),
                            Text('Manage your account and security preferences', style: Theme.of(context).textTheme.bodyMedium),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    _buildAppearanceCard(),
                    const SizedBox(height: 20),
                    _buildAccountCard(),
                    const SizedBox(height: 20),
                    _buildSecurityCard(),
                  ],
                ),
              ),
            ),
      bottomSheet: _buildModals(),
    );
  }

  Widget _buildAppearanceCard() {
    final themeMode = ref.watch(themeProvider);
    final reduceTransparency = ref.watch(reduceTransparencyProvider);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: context.glass.headerIconTileFill, borderRadius: BorderRadius.circular(20)),
                child: Icon(Icons.palette_outlined, color: context.glass.headerIconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Appearance & Accessibility', style: Theme.of(context).textTheme.titleLarge),
                  Text('Customize theme and glassmorphism transparency', style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ],
          ),
          const Divider(height: 24),
          _settingItem(
            icon: Icons.nightlight_round,
            color: context.glass.info,
            title: 'Dark Mode',
            subtitle: 'Switch between light and dark liquid glass themes',
            trailing: Switch(
              value: themeMode == ThemeMode.dark,
              onChanged: (_) => ref.read(themeProvider.notifier).toggleTheme(),
            ),
          ),
          const Divider(height: 1),
          _settingItem(
            icon: Icons.blur_off_rounded,
            color: context.glass.success,
            title: 'Reduce Transparency',
            subtitle: 'Disable blur effects and use solid glass fills',
            trailing: Switch(
              value: reduceTransparency,
              onChanged: (_) => ref.read(reduceTransparencyProvider.notifier).toggle(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountCard() {
    final glass = context.glass;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: glass.headerIconTileFill, borderRadius: BorderRadius.circular(20)),
                child: Icon(Icons.person, color: glass.headerIconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Account & Password', style: Theme.of(context).textTheme.titleLarge),
                  Text('Manage your account details and password', style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ],
          ),
          const Divider(height: 24),
          _settingItem(
            icon: Icons.lock,
            color: glass.info,
            title: 'Change Password',
            subtitle: 'Update your password regularly to keep your account secure',
            onTap: _openChangePasswordModal,
          ),
          const Divider(height: 1),
          _settingItem(
            icon: Icons.email_outlined,
            color: glass.warning,
            title: 'Email Address',
            subtitle: 'View or update your email address',
            valueText: _userEmail,
            onTap: _openEmailModal,
          ),
          const Divider(height: 1),
          _settingItem(
            icon: Icons.phone_android,
            color: glass.success,
            title: 'Mobile Number',
            subtitle: 'View or update your mobile number',
            valueText: _userPhone,
            onTap: _openMobileModal,
          ),
          const Divider(height: 1),
          _settingItem(
            icon: Icons.shield,
            color: glass.warning,
            title: 'Account Status',
            subtitle: 'Current status of your account',
            trailing: const StatusChip(status: 'ACTIVE'),
          ),
          const Divider(height: 1),
          _settingItem(
            icon: Icons.access_time,
            color: glass.info,
            title: 'Last Login',
            subtitle: 'Your most recent login activity',
            trailing: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(_lastLoginFormatted, style: Theme.of(context).textTheme.titleMedium),
                Text(_lastLoginMeta, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityCard() {
    final glass = context.glass;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: glass.headerIconTileFill, borderRadius: BorderRadius.circular(20)),
                child: Icon(Icons.shield_outlined, color: glass.headerIconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Security Settings', style: Theme.of(context).textTheme.titleLarge),
                  Text('Manage your multi-factor authentication and security settings', style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ],
          ),
          const Divider(height: 24),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: glass.cardFill,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: glass.cardBorder),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.security, color: glass.success, size: 22),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Multi-Factor Authentication', style: Theme.of(context).textTheme.titleMedium),
                        Text('Add an extra layer of security to your account', style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ],
                ),
                Switch(value: _mfaEnabled, onChanged: _toggleMFA),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _settingItem(
            icon: Icons.qr_code,
            color: glass.info,
            title: 'Authenticator App',
            subtitle: 'Set up or manage your authenticator app',
            onTap: () => _openModal('authenticator'),
          ),
          const Divider(height: 1),
          _settingItem(
            icon: Icons.email,
            color: glass.pending,
            title: 'Email OTP',
            subtitle: 'Configure email OTP for verification',
            onTap: () => _openModal('emailOtp'),
          ),
          const Divider(height: 1),
          _settingItem(
            icon: Icons.history,
            color: glass.warning,
            title: 'Login History',
            subtitle: 'View your recent login activity',
            onTap: () => _openModal('loginHistory'),
          ),
          const Divider(height: 1),
          _settingItem(
            icon: Icons.devices,
            color: glass.success,
            title: 'Active Devices',
            subtitle: 'Manage your currently active devices',
            onTap: () => _openModal('activeDevices'),
          ),
          const Divider(height: 1),
          _settingItem(
            icon: Icons.verified_user,
            color: glass.info,
            title: 'Trusted Devices',
            subtitle: 'Manage your trusted devices',
            onTap: () => _openModal('trustedDevices'),
          ),
        ],
      ),
    );
  }

  Widget _settingItem({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    String? valueText,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    final glass = context.glass;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            if (valueText != null) ...[
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  valueText,
                  style: Theme.of(context).textTheme.bodyMedium,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                ),
              ),
            ],
            if (trailing != null) ...[
              const SizedBox(width: 8),
              Flexible(child: trailing),
            ] else if (onTap != null) ...[
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, size: 18, color: glass.chevronColor),
            ],
          ],
        ),
      ),
    );
  }

  Widget? _buildModals() {
    return null;
  }
}
