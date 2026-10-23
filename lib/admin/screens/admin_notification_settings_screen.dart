import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_card.dart';

class AdminNotificationSettingsScreen extends ConsumerStatefulWidget {
  const AdminNotificationSettingsScreen({super.key});

  @override
  ConsumerState<AdminNotificationSettingsScreen> createState() => _AdminNotificationSettingsScreenState();
}

class _AdminNotificationSettingsScreenState extends ConsumerState<AdminNotificationSettingsScreen> {
  bool _isLoading = true;
  List<dynamic> _preferences = [];

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    setState(() => _isLoading = true);
    final apiClient = ref.read(apiClientProvider);

    try {
      final res = await apiClient.get('/system-settings/notifications').catchError((_) => null);
      List<dynamic> prefs = [];
      if (res is List) {
        prefs = res;
      } else if (res is Map<String, dynamic>) {
        prefs = res['items'] ?? res['data'] ?? [];
      }

      if (prefs.isEmpty) {
        prefs = [
          {'id': '1', 'eventName': 'LEAVE_APPLICATION_SUBMITTED', 'emailEnabled': true, 'smsEnabled': false, 'inAppEnabled': true},
          {'id': '2', 'eventName': 'ATTENDANCE_LATE_ALERT', 'emailEnabled': true, 'smsEnabled': true, 'inAppEnabled': true},
          {'id': '3', 'eventName': 'PAYROLL_DISBURSED', 'emailEnabled': true, 'smsEnabled': false, 'inAppEnabled': true},
        ];
      }

      setState(() {
        _preferences = prefs;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _togglePref(Map<String, dynamic> pref, String channel) async {
    final current = pref[channel] == true;
    setState(() {
      pref[channel] = !current;
    });

    try {
      await ref.read(apiClientProvider).put('/system-settings/notifications/${pref['id']}', data: {
        'emailEnabled': pref['emailEnabled'],
        'smsEnabled': pref['smsEnabled'],
        'inAppEnabled': pref['inAppEnabled']
      });
    } catch (_) {}
  }

  String _prettyName(String eventName) {
    return eventName.replaceAll('_', ' ').toLowerCase().replaceFirstMapped(RegExp(r'\w'), (m) => m[0]!.toUpperCase());
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Preferences'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Event Notification Policies', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
            const SizedBox(height: 12),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _preferences.length,
              itemBuilder: (context, index) {
                final pref = _preferences[index];
                return AppCard(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_prettyName(pref['eventName'] ?? 'EVENT'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        const Divider(height: 16),
                        SwitchListTile(
                          title: const Text('Email Notifications'),
                          value: pref['emailEnabled'] == true,
                          activeColor: AppColors.primary,
                          onChanged: (_) => _togglePref(pref, 'emailEnabled'),
                        ),
                        SwitchListTile(
                          title: const Text('SMS Notifications'),
                          value: pref['smsEnabled'] == true,
                          activeColor: AppColors.primary,
                          onChanged: (_) => _togglePref(pref, 'smsEnabled'),
                        ),
                        SwitchListTile(
                          title: const Text('In-App Alerts'),
                          value: pref['inAppEnabled'] == true,
                          activeColor: AppColors.primary,
                          onChanged: (_) => _togglePref(pref, 'inAppEnabled'),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
