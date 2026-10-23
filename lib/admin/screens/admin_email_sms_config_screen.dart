import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_card.dart';

class AdminEmailSmsConfigScreen extends ConsumerStatefulWidget {
  const AdminEmailSmsConfigScreen({super.key});

  @override
  ConsumerState<AdminEmailSmsConfigScreen> createState() => _AdminEmailSmsConfigScreenState();
}

class _AdminEmailSmsConfigScreenState extends ConsumerState<AdminEmailSmsConfigScreen> {
  bool _isLoading = true;
  bool _isSaving = false;

  final TextEditingController _smtpHostController = TextEditingController();
  final TextEditingController _smtpPortController = TextEditingController();
  final TextEditingController _smtpUserController = TextEditingController();
  final TextEditingController _smtpPassController = TextEditingController();
  final TextEditingController _smtpFromController = TextEditingController();
  final TextEditingController _smsApiUrlController = TextEditingController();
  final TextEditingController _smsApiKeyController = TextEditingController();
  final TextEditingController _smsSenderIdController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    setState(() => _isLoading = true);
    final apiClient = ref.read(apiClientProvider);

    try {
      final res = await apiClient.get('/system-settings/email-sms').catchError((_) => null);
      if (res is Map<String, dynamic> && res['settings'] != null) {
        final settings = res['settings'] as Map<String, dynamic>;
        _smtpHostController.text = settings['SMTP_HOST'] ?? '';
        _smtpPortController.text = settings['SMTP_PORT'] ?? '';
        _smtpUserController.text = settings['SMTP_USERNAME'] ?? '';
        _smtpPassController.text = settings['SMTP_PASSWORD'] ?? '';
        _smtpFromController.text = settings['SMTP_FROM'] ?? '';
        _smsApiUrlController.text = settings['SMS_API_URL'] ?? '';
        _smsApiKeyController.text = settings['SMS_API_KEY'] ?? '';
        _smsSenderIdController.text = settings['SMS_SENDER_ID'] ?? '';
      }
      setState(() => _isLoading = false);
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    final apiClient = ref.read(apiClientProvider);

    final payload = {
      'SMTP_HOST': _smtpHostController.text.trim(),
      'SMTP_PORT': _smtpPortController.text.trim(),
      'SMTP_USERNAME': _smtpUserController.text.trim(),
      'SMTP_PASSWORD': _smtpPassController.text.trim(),
      'SMTP_FROM': _smtpFromController.text.trim(),
      'SMS_API_URL': _smsApiUrlController.text.trim(),
      'SMS_API_KEY': _smsApiKeyController.text.trim(),
      'SMS_SENDER_ID': _smsSenderIdController.text.trim(),
    };

    try {
      await apiClient.post('/system-settings/email-sms', data: {'settings': payload});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Email/SMS configuration saved successfully')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save config: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Email & SMS Configuration'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('SMTP Email Server Settings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
            const SizedBox(height: 12),
            AppCard(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextField(
                      controller: _smtpHostController,
                      decoration: const InputDecoration(labelText: 'SMTP Host', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _smtpPortController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'SMTP Port', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _smtpUserController,
                      decoration: const InputDecoration(labelText: 'SMTP Username', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _smtpPassController,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'SMTP Password', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _smtpFromController,
                      decoration: const InputDecoration(labelText: 'Sender Email (From Address)', border: OutlineInputBorder()),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            const Text('SMS Gateway API Settings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
            const SizedBox(height: 12),
            AppCard(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextField(
                      controller: _smsApiUrlController,
                      decoration: const InputDecoration(labelText: 'SMS API URL', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _smsApiKeyController,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'SMS API Key', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _smsSenderIdController,
                      decoration: const InputDecoration(labelText: 'SMS Sender ID', border: OutlineInputBorder()),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _save,
                icon: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Icon(Icons.save),
                label: Text(_isSaving ? 'Saving...' : 'Save Configuration', style: const TextStyle(fontSize: 16)),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
