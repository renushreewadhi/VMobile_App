import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/auth/auth_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/glass_theme.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/glass_header.dart';
import '../../shared/widgets/app_card.dart';

class SystemSettingsScreen extends ConsumerStatefulWidget {
  final bool showAppBar;
  const SystemSettingsScreen({super.key, this.showAppBar = true});

  @override
  ConsumerState<SystemSettingsScreen> createState() => _SystemSettingsScreenState();
}

class _SystemSettingsScreenState extends ConsumerState<SystemSettingsScreen> {
  bool _isLoading = false;
  bool _mfaEnabled = false;
  bool _saving = false;

  final TextEditingController _emailController = TextEditingController(text: 'admin@hrm.com');
  final TextEditingController _phoneController = TextEditingController(text: '');

  @override
  void initState() {
    super.initState();
    final user = ref.read(authServiceProvider).user;
    if (user != null) {
      if (user.email != null) _emailController.text = user.email!;
    }
  }

  Future<void> _logoutAllDevices() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout from All Devices?'),
        content: const Text('This will sign you out from all active sessions across all devices.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Logout All'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Successfully signed out from all active sessions.'), backgroundColor: AppColors.success),
    );
  }

  Future<void> _updatePassword() async {
    final TextEditingController oldPass = TextEditingController();
    final TextEditingController newPass = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: oldPass, obscureText: true, decoration: const InputDecoration(labelText: 'Current Password', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: newPass, obscureText: true, decoration: const InputDecoration(labelText: 'New Password', border: OutlineInputBorder())),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F6B66)),
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Password updated successfully!'), backgroundColor: AppColors.success),
              );
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBgColor = isDark ? const Color(0xFF141D2E) : Colors.white;

    final content = SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Subtitle
          Text('Manage your account and security preferences', style: TextStyle(fontSize: 12, color: glass.textSecondary)),
          const SizedBox(height: 16),

          // Two Columns / Cards Layout matching web reference
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 700;
              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildAccountCard(glass, cardBgColor)),
                    const SizedBox(width: 16),
                    Expanded(child: _buildSecurityCard(glass, cardBgColor)),
                  ],
                );
              }
              return Column(
                children: [
                  _buildAccountCard(glass, cardBgColor),
                  const SizedBox(height: 16),
                  _buildSecurityCard(glass, cardBgColor),
                ],
              );
            },
          ),
        ],
      ),
    );

    if (!widget.showAppBar) return Material(color: Colors.transparent, child: content);

    return GlassScaffold(
      appBar: const GlassHeader(title: 'Settings'),
      body: content,
    );
  }

  Widget _buildAccountCard(GlassTheme glass, Color cardBgColor) {
    return AppCard(
      backgroundColor: cardBgColor,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.person_outline_rounded, color: Color(0xFF2563EB), size: 20),
              SizedBox(width: 8),
              Text('Account & Password', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 4),
          Text('Manage your account details and password', style: TextStyle(fontSize: 11.5, color: glass.textSecondary)),
          const Divider(height: 24),

          _buildSettingsItem(
            icon: Icons.lock_outline_rounded,
            title: 'Change Password',
            subtitle: 'Update your password regularly to keep your account secure',
            onTap: _updatePassword,
          ),
          _buildSettingsItem(
            icon: Icons.email_outlined,
            title: 'Email Address',
            subtitle: _emailController.text,
            onTap: () {},
          ),
          _buildSettingsItem(
            icon: Icons.phone_android_rounded,
            title: 'Mobile Number',
            subtitle: _phoneController.text.isEmpty ? 'Not set' : _phoneController.text,
            onTap: () {},
          ),
          _buildSettingsItem(
            icon: Icons.verified_user_outlined,
            title: 'Account Status',
            subtitle: 'Current status of your account',
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: const Color(0xFF10B981).withAlpha(30), borderRadius: BorderRadius.circular(8)),
              child: const Text('Active', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
            ),
          ),
          _buildSettingsItem(
            icon: Icons.access_time_rounded,
            title: 'Last Login',
            subtitle: '09:53 AM  11/5/2026 • Web Portal',
          ),
          _buildSettingsItem(
            icon: Icons.logout_rounded,
            title: 'Logout from All Devices',
            subtitle: 'Sign out from all active sessions on all devices',
            textColor: Colors.red,
            onTap: _logoutAllDevices,
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityCard(GlassTheme glass, Color cardBgColor) {
    return AppCard(
      backgroundColor: cardBgColor,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.shield_outlined, color: Color(0xFF10B981), size: 20),
              SizedBox(width: 8),
              Text('MFA / Security', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 4),
          Text('Manage your multi-factor authentication and security settings', style: TextStyle(fontSize: 11.5, color: glass.textSecondary)),
          const Divider(height: 24),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _mfaEnabled ? const Color(0xFF10B981).withAlpha(15) : Colors.grey.withAlpha(15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _mfaEnabled ? const Color(0xFF10B981).withAlpha(50) : glass.cardBorder),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.security_rounded, color: Color(0xFF10B981), size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Multi-Factor Authentication', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis),
                            Text('Add an extra layer of security to your account', style: TextStyle(fontSize: 11, color: glass.textSecondary), overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_mfaEnabled ? 'ON' : 'OFF', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _mfaEnabled ? const Color(0xFF10B981) : Colors.grey)),
                    const SizedBox(width: 4),
                    Switch(
                      value: _mfaEnabled,
                      activeColor: const Color(0xFF10B981),
                      onChanged: (val) => setState(() => _mfaEnabled = val),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          _buildSettingsItem(
            icon: Icons.phone_iphone_rounded,
            title: 'Authenticator App',
            subtitle: 'Set up or manage your authenticator app',
            onTap: () {},
          ),
          _buildSettingsItem(
            icon: Icons.mark_email_read_outlined,
            title: 'Email OTP',
            subtitle: 'Configure email OTP for verification',
            onTap: () {},
          ),
          _buildSettingsItem(
            icon: Icons.history_rounded,
            title: 'Login History',
            subtitle: 'View your recent login activity',
            onTap: () {},
          ),
          _buildSettingsItem(
            icon: Icons.devices_rounded,
            title: 'Active Devices',
            subtitle: 'Manage your currently active devices',
            onTap: () {},
          ),
          _buildSettingsItem(
            icon: Icons.verified_rounded,
            title: 'Trusted Devices',
            subtitle: 'Manage your trusted devices',
            onTap: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsItem({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
    Color? textColor,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            Icon(icon, size: 20, color: textColor ?? const Color(0xFF64748B)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textColor ?? const Color(0xFF0F172A))),
                  const SizedBox(height: 1),
                  Text(subtitle, style: TextStyle(fontSize: 11, color: textColor != null ? textColor.withAlpha(180) : const Color(0xFF64748B))),
                ],
              ),
            ),
            if (trailing != null)
              trailing
            else if (onTap != null)
              const Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }
}
