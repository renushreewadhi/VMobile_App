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
import '../../core/widgets/glass_header.dart';
import '../../core/widgets/glass_scaffold.dart';

class AdminEmailSmsConfigScreen extends ConsumerStatefulWidget {
  const AdminEmailSmsConfigScreen({super.key});

  @override
  ConsumerState<AdminEmailSmsConfigScreen> createState() => _AdminEmailSmsConfigScreenState();
}

class _AdminEmailSmsConfigScreenState extends ConsumerState<AdminEmailSmsConfigScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  bool _obscureSmtpPassword = true;
  bool _obscureSmsApiKey = true;
  bool _enableSsl = true;

  final TextEditingController _smtpHostController = TextEditingController(text: 'webmail.nvisionbeyond.com');
  final TextEditingController _smtpPortController = TextEditingController(text: '587');
  final TextEditingController _smtpUserController = TextEditingController(text: 'jigar.chovdiya@in.nvisionbeyond.com');
  final TextEditingController _smtpPassController = TextEditingController(text: '••••••••••••');
  final TextEditingController _smtpFromEmailController = TextEditingController(text: 'jigar.chovdiya@in.nvisionbeyond.com');
  final TextEditingController _smtpFromNameController = TextEditingController(text: 'Etaprise HRMS');

  final TextEditingController _smsApiUrlController = TextEditingController(text: 'https://api.smsprovider.com/send');
  final TextEditingController _smsApiKeyController = TextEditingController(text: '••••••••');
  final TextEditingController _smsSenderIdController = TextEditingController(text: 'HRMPRO');

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

  @override
  void dispose() {
    _smtpHostController.dispose();
    _smtpPortController.dispose();
    _smtpUserController.dispose();
    _smtpPassController.dispose();
    _smtpFromEmailController.dispose();
    _smtpFromNameController.dispose();
    _smsApiUrlController.dispose();
    _smsApiKeyController.dispose();
    _smsSenderIdController.dispose();
    super.dispose();
  }

  void _checkUserAndLoad() {
    _requestId++;
    final authState = ref.read(authServiceProvider);
    final user = authState.user;

    if (user == null || !authState.isAuthenticated) {
      if (!mounted) return;
      _resetDefaults();
      setState(() {
        _isLoading = false;
        _errorMessage = 'No authenticated user found.';
      });
      return;
    }

    if (_currentUserId != user.id) {
      _currentUserId = user.id;
      _resetDefaults();
    }

    final userRole = user.role;
    final bool isAuthorized = userRole == UserRole.ADMIN || userRole == UserRole.HR;

    if (!isAuthorized) {
      if (!mounted) return;
      _resetDefaults();
      setState(() {
        _isLoading = false;
        _errorMessage = null;
      });
      return;
    }

    _loadConfig();
  }

  void _resetDefaults() {
    _smtpHostController.text = 'webmail.nvisionbeyond.com';
    _smtpPortController.text = '587';
    _smtpUserController.text = 'jigar.chovdiya@in.nvisionbeyond.com';
    _smtpPassController.text = '••••••••••••';
    _smtpFromEmailController.text = 'jigar.chovdiya@in.nvisionbeyond.com';
    _smtpFromNameController.text = 'Etaprise HRMS';
    _enableSsl = true;

    _smsApiUrlController.text = 'https://api.smsprovider.com/send';
    _smsApiKeyController.text = '••••••••';
    _smsSenderIdController.text = 'HRMPRO';
  }

  Future<void> _loadConfig() async {
    final currentReq = ++_requestId;
    if (!mounted) return;

    // Start with default values matching website
    _resetDefaults();

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
      final res = await apiClient.get(ApiEndpoints.emailSmsConfig).catchError((_) => null);
      if (!mounted || currentReq != _requestId) return;

      dynamic rawData = res is Map<String, dynamic>
          ? (res['data'] ?? res['settings'] ?? res)
          : res;

      if (rawData is Map<String, dynamic>) {
        final host = rawData['SMTP_HOST'] ?? rawData['smtpHost'];
        final port = rawData['SMTP_PORT'] ?? rawData['smtpPort'];
        final user = rawData['SMTP_USERNAME'] ?? rawData['smtpUsername'];
        final pass = rawData['SMTP_PASSWORD'] ?? rawData['smtpPassword'];
        final from = rawData['SMTP_FROM'] ?? rawData['smtpFrom'] ?? rawData['fromEmail'];
        final name = rawData['FROM_NAME'] ?? rawData['fromName'];
        final ssl = rawData['ENABLE_SSL'] ?? rawData['enableSsl'];
        final smsUrl = rawData['SMS_API_URL'] ?? rawData['smsApiUrl'];
        final smsKey = rawData['SMS_API_KEY'] ?? rawData['smsApiKey'];
        final smsSender = rawData['SMS_SENDER_ID'] ?? rawData['smsSenderId'];

        if (host != null && host.toString().trim().isNotEmpty) _smtpHostController.text = host.toString().trim();
        if (port != null && port.toString().trim().isNotEmpty) _smtpPortController.text = port.toString().trim();
        if (user != null && user.toString().trim().isNotEmpty) _smtpUserController.text = user.toString().trim();
        if (pass != null && pass.toString().trim().isNotEmpty) _smtpPassController.text = pass.toString().trim();
        if (from != null && from.toString().trim().isNotEmpty) _smtpFromEmailController.text = from.toString().trim();
        if (name != null && name.toString().trim().isNotEmpty) _smtpFromNameController.text = name.toString().trim();
        if (ssl != null) _enableSsl = ssl == true || ssl.toString().toLowerCase() == 'true';

        if (smsUrl != null && smsUrl.toString().trim().isNotEmpty) _smsApiUrlController.text = smsUrl.toString().trim();
        if (smsKey != null && smsKey.toString().trim().isNotEmpty) _smsApiKeyController.text = smsKey.toString().trim();
        if (smsSender != null && smsSender.toString().trim().isNotEmpty) _smsSenderIdController.text = smsSender.toString().trim();
      }

      if (!mounted || currentReq != _requestId) return;
      setState(() => _isLoading = false);
    } catch (e) {
      if (!mounted || currentReq != _requestId) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    final currentReq = ++_requestId;
    final apiClient = ref.read(apiClientProvider);

    final payload = {
      'SMTP_HOST': _smtpHostController.text.trim(),
      'SMTP_PORT': _smtpPortController.text.trim(),
      'SMTP_USERNAME': _smtpUserController.text.trim(),
      'SMTP_PASSWORD': _smtpPassController.text.trim(),
      'SMTP_FROM': _smtpFromEmailController.text.trim(),
      'FROM_NAME': _smtpFromNameController.text.trim(),
      'ENABLE_SSL': _enableSsl,
      'SMS_API_URL': _smsApiUrlController.text.trim(),
      'SMS_API_KEY': _smsApiKeyController.text.trim(),
      'SMS_SENDER_ID': _smsSenderIdController.text.trim(),
      'smtpHost': _smtpHostController.text.trim(),
      'smtpPort': _smtpPortController.text.trim(),
      'smtpUsername': _smtpUserController.text.trim(),
      'smtpPassword': _smtpPassController.text.trim(),
      'smtpFrom': _smtpFromEmailController.text.trim(),
      'fromName': _smtpFromNameController.text.trim(),
      'enableSsl': _enableSsl,
      'smsApiUrl': _smsApiUrlController.text.trim(),
      'smsApiKey': _smsApiKeyController.text.trim(),
      'smsSenderId': _smsSenderIdController.text.trim(),
    };

    try {
      await apiClient.put(ApiEndpoints.emailSmsConfig, body: {'settings': payload}).catchError((_) async {
        return await apiClient.post(ApiEndpoints.emailSmsConfig, body: {'settings': payload}).catchError((_) async {
          return await apiClient.patch(ApiEndpoints.emailSmsConfig, body: {'settings': payload}).catchError((_) async {
            return await apiClient.put(ApiEndpoints.emailSmsConfig, body: payload).catchError((_) async {
              return await apiClient.post(ApiEndpoints.emailSmsConfig, body: payload);
            });
          });
        });
      });
      if (!mounted || currentReq != _requestId) return;

      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Email & SMS Configuration saved successfully!'),
          backgroundColor: Color(0xFF16A34A),
        ),
      );
    } catch (e) {
      if (!mounted || currentReq != _requestId) return;
      setState(() => _isSaving = false);
      final msg = e is ApiException ? e.message : 'Failed to save settings.';
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
    final bool canEdit = isAuthorized; // HR and Admin can both edit and save Email/SMS configuration

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
                    Text('You do not have permissions to view Email / SMS settings.', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: glass.textSecondary)),
                  ],
                ),
              ),
            ),
          )
        : RefreshIndicator(
            onRefresh: _loadConfig,
            child: _buildMainContent(glass, cardBgColor, isDark, canEdit),
          );

    return GlassScaffold(
      appBar: GlassHeader(
        title: 'Email / SMS Config',
      ),
      body: mainContent,
    );
  }

  Widget _buildMainContent(GlassTheme glass, Color cardBgColor, bool dark, bool canEdit) {
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
              Text('Unable to Load Configuration', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: glass.textPrimary)),
              const SizedBox(height: 8),
              Text(_errorMessage!, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: glass.textSecondary)),
              const SizedBox(height: 24),
              AppButton(label: 'Retry', icon: Icons.refresh_rounded, width: 140, onPressed: _loadConfig),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Title & Subtitle Card
          AppCard(
            backgroundColor: dark ? AppColors.darkMainSurface : Colors.white,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Email / SMS Configuration',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                    ),
                    if (canEdit) ...[
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: _isSaving ? null : _save,
                        icon: _isSaving
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.save_rounded, size: 14),
                        label: const Text('Save', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD97706),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Configure outgoing email (SMTP) and SMS gateway settings',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Card 1: SMTP / Email Settings
          AppCard(
            backgroundColor: dark ? AppColors.darkMainSurface : Colors.white,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.mail_outline_rounded, color: Color(0xFFD97706), size: 20),
                    SizedBox(width: 8),
                    Text(
                      'SMTP / Email Settings',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                  ],
                ),
                const Divider(height: 20),

                const Text('SMTP Host', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B))),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _smtpHostController,
                  enabled: !_isSaving && canEdit,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: dark ? AppColors.darkSecondarySurface : const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 14),

                const Text('SMTP Port', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B))),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _smtpPortController,
                  enabled: !_isSaving && canEdit,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: dark ? AppColors.darkSecondarySurface : const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 14),

                const Text('Username', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B))),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _smtpUserController,
                  enabled: !_isSaving && canEdit,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: dark ? AppColors.darkSecondarySurface : const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 14),

                const Text('Password / App Password', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B))),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _smtpPassController,
                  enabled: !_isSaving && canEdit,
                  obscureText: _obscureSmtpPassword,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: dark ? AppColors.darkSecondarySurface : const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    suffixIcon: IconButton(
                      icon: Icon(_obscureSmtpPassword ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: const Color(0xFF64748B), size: 18),
                      onPressed: () => setState(() => _obscureSmtpPassword = !_obscureSmtpPassword),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                const Text('From Email', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B))),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _smtpFromEmailController,
                  enabled: !_isSaving && canEdit,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: dark ? AppColors.darkSecondarySurface : const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 14),

                const Text('From Name', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B))),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _smtpFromNameController,
                  enabled: !_isSaving && canEdit,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: dark ? AppColors.darkSecondarySurface : const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 14),

                // Enable SSL / TLS Encryption Checkbox
                InkWell(
                  onTap: (!canEdit || _isSaving) ? null : () => setState(() => _enableSsl = !_enableSsl),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Checkbox(
                          value: _enableSsl,
                          onChanged: (!canEdit || _isSaving) ? null : (val) => setState(() => _enableSsl = val ?? false),
                          activeColor: const Color(0xFF2563EB),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'Enable SSL / TLS Encryption',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Card 2: SMS Gateway Settings
          AppCard(
            backgroundColor: dark ? AppColors.darkMainSurface : Colors.white,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFFD97706), size: 20),
                    SizedBox(width: 8),
                    Text(
                      'SMS Gateway Settings',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                  ],
                ),
                const Divider(height: 20),

                const Text('API URL', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B))),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _smsApiUrlController,
                  enabled: !_isSaving && canEdit,
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: dark ? AppColors.darkSecondarySurface : const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 14),

                const Text('API Key', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B))),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _smsApiKeyController,
                  enabled: !_isSaving && canEdit,
                  obscureText: _obscureSmsApiKey,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: dark ? AppColors.darkSecondarySurface : const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    suffixIcon: IconButton(
                      icon: Icon(_obscureSmsApiKey ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: const Color(0xFF64748B), size: 18),
                      onPressed: () => setState(() => _obscureSmsApiKey = !_obscureSmsApiKey),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                const Text('Sender ID', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B))),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _smsSenderIdController,
                  enabled: !_isSaving && canEdit,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: dark ? AppColors.darkSecondarySurface : const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Bottom Info Callout Box
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: dark ? const Color(0x222563EB) : const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Icon(Icons.info_rounded, color: Color(0xFF2563EB), size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'These credentials are stored in the database and utilized dynamically across all modules for system emails (authentication OTPs, password resets, attendance alerts, payroll slips, leave notifications).',
                    style: TextStyle(fontSize: 12, height: 1.4, color: Color(0xFF1E40AF)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Bottom Primary Save Button (Only for ADMIN)
          if (canEdit)
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _save,
                icon: _isSaving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check, size: 18),
                label: const Text('Save Configuration', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD97706),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
