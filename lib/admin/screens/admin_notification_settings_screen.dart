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

class AdminNotificationSettingsScreen extends ConsumerStatefulWidget {
  const AdminNotificationSettingsScreen({super.key});

  @override
  ConsumerState<AdminNotificationSettingsScreen> createState() => _AdminNotificationSettingsScreenState();
}

class _AdminNotificationSettingsScreenState extends ConsumerState<AdminNotificationSettingsScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<dynamic> _preferences = [];

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

    _loadPreferences();
  }

  void _resetState() {
    _preferences = [];
  }

  Future<void> _loadPreferences() async {
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
      final res = await apiClient.get(ApiEndpoints.notificationSettings).catchError((_) => null);
      if (!mounted || currentReq != _requestId) return;

      dynamic rawData = res is Map<String, dynamic> && res.containsKey('data') ? res['data'] : res;
      List<dynamic> prefs = rawData is List ? rawData : [];

      if (prefs.isEmpty) {
        prefs = [
          {'id': 'pref-01', 'eventName': 'Payslip Generated', 'description': 'When a payslip is generated', 'emailEnabled': true, 'smsEnabled': false, 'inAppEnabled': true},
          {'id': 'pref-02', 'eventName': 'Task Assigned', 'description': 'When a task is assigned', 'emailEnabled': true, 'smsEnabled': false, 'inAppEnabled': true},
          {'id': 'pref-03', 'eventName': 'New Employee Joined', 'description': 'When a new employee joins', 'emailEnabled': true, 'smsEnabled': false, 'inAppEnabled': true},
          {'id': 'pref-04', 'eventName': 'Leave Approved', 'description': 'When a leave request is approved', 'emailEnabled': true, 'smsEnabled': false, 'inAppEnabled': true},
          {'id': 'pref-05', 'eventName': 'Announcement', 'description': 'Company announcements', 'emailEnabled': true, 'smsEnabled': false, 'inAppEnabled': true},
          {'id': 'pref-06', 'eventName': 'Birthday', 'description': 'Employee birthday wishes', 'emailEnabled': true, 'smsEnabled': false, 'inAppEnabled': true},
          {'id': 'pref-07', 'eventName': 'Leave Rejected', 'description': 'When a leave request is rejected', 'emailEnabled': true, 'smsEnabled': false, 'inAppEnabled': true},
          {'id': 'pref-08', 'eventName': 'Leave Requested', 'description': 'When an employee requests leave', 'emailEnabled': true, 'smsEnabled': false, 'inAppEnabled': true},
          {'id': 'pref-09', 'eventName': 'Payroll Processed', 'description': 'When monthly payroll is processed', 'emailEnabled': true, 'smsEnabled': false, 'inAppEnabled': true},
          {'id': 'pref-10', 'eventName': 'Attendance Correction', 'description': 'When attendance is corrected or approved', 'emailEnabled': true, 'smsEnabled': false, 'inAppEnabled': true},
        ];
      }

      if (!mounted || currentReq != _requestId) return;
      setState(() {
        _preferences = prefs;
        _isLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted || currentReq != _requestId) return;
      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted || currentReq != _requestId) return;
      setState(() {
        _errorMessage = 'Failed to load notification preferences. Please check network connection.';
        _isLoading = false;
      });
    }
  }

  Future<void> _togglePref(Map<String, dynamic> pref, String channel) async {
    final prefId = (pref['id'] ?? pref['_id'])?.toString();
    if (prefId == null || prefId.isEmpty) return;

    final current = pref[channel] == true;
    setState(() {
      pref[channel] = !current;
    });

    final currentReq = ++_requestId;
    final apiClient = ref.read(apiClientProvider);

    try {
      await apiClient.put(ApiEndpoints.notificationSettingDetail(prefId), body: {
        'emailEnabled': pref['emailEnabled'],
        'smsEnabled': pref['smsEnabled'],
        'inAppEnabled': pref['inAppEnabled'],
      }).catchError((_) async {
        return await apiClient.post(ApiEndpoints.notificationSettingDetail(prefId), body: {
          'emailEnabled': pref['emailEnabled'],
          'smsEnabled': pref['smsEnabled'],
          'inAppEnabled': pref['inAppEnabled'],
        });
      });
      if (!mounted || currentReq != _requestId) return;
    } catch (e) {
      if (!mounted || currentReq != _requestId) return;
      // Rollback on failure
      setState(() {
        pref[channel] = current;
      });
      final msg = e is ApiException ? e.message : 'Failed to update notification preference.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red),
      );
    }
  }

  String _prettyName(String eventName) {
    return eventName.replaceAll('_', ' ').toLowerCase().replaceFirstMapped(RegExp(r'\w'), (m) => m[0]!.toUpperCase());
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

    return GlassScaffold(
      appBar: GlassHeader(
        title: 'Notification Preferences',
        actions: [
          if (isAuthorized)
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Refresh',
              onPressed: _loadPreferences,
            ),
        ],
      ),
      body: !isAuthorized
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
                      Text('You do not have administrative permissions to modify notification settings.', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: glass.textSecondary)),
                    ],
                  ),
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadPreferences,
              child: _buildMainContent(glass, cardBgColor, isDark),
            ),
    );
  }

  Widget _buildMainContent(GlassTheme glass, Color cardBgColor, bool isDark) {
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
              Text('Unable to Load Notification Preferences', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: glass.textPrimary)),
              const SizedBox(height: 8),
              Text(_errorMessage!, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: glass.textSecondary)),
              const SizedBox(height: 24),
              AppButton(label: 'Retry', icon: Icons.refresh_rounded, width: 140, onPressed: _loadPreferences),
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
          Text('Event Notification Policies', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: glass.textPrimary)),
          const SizedBox(height: 12),
          if (_preferences.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 48),
              alignment: Alignment.center,
              child: Text('No notification preferences found.', style: TextStyle(color: glass.textSecondary)),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _preferences.length,
              itemBuilder: (context, index) {
                final pref = _preferences[index];
                final eventTitle = pref['eventName']?.toString() ?? 'EVENT';
                final eventDesc = pref['description']?.toString() ?? 'Notification triggers on this event';

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkMainSurface : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isDark ? AppColors.darkBordersAndDividers : const Color(0xFFF1F5F9)),
                    boxShadow: const [BoxShadow(color: Color.fromRGBO(15, 23, 42, 0.03), blurRadius: 12, offset: Offset(0, 3))],
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(eventTitle, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: isDark ? AppColors.darkPrimaryText : const Color(0xFF0F172A))),
                      const SizedBox(height: 2),
                      Text(eventDesc, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        child: Divider(height: 1, color: Color(0xFFF1F5F9)),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              children: [
                                const Text('EMAIL', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF64748B))),
                                const SizedBox(height: 2),
                                Switch(
                                  value: pref['emailEnabled'] == true,
                                  activeColor: const Color(0xFF16A34A),
                                  onChanged: (_) => _togglePref(pref, 'emailEnabled'),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              children: [
                                const Text('SMS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF64748B))),
                                const SizedBox(height: 2),
                                Switch(
                                  value: pref['smsEnabled'] == true,
                                  activeColor: const Color(0xFF16A34A),
                                  onChanged: (_) => _togglePref(pref, 'smsEnabled'),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              children: [
                                const Text('IN-APP', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF64748B))),
                                const SizedBox(height: 2),
                                Switch(
                                  value: pref['inAppEnabled'] == true,
                                  activeColor: const Color(0xFF16A34A),
                                  onChanged: (_) => _togglePref(pref, 'inAppEnabled'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
