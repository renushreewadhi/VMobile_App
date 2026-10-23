import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/auth/auth_service.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/compact_summary_widgets.dart';

class SystemSettingsScreen extends ConsumerStatefulWidget {
  const SystemSettingsScreen({super.key});

  @override
  ConsumerState<SystemSettingsScreen> createState() => _SystemSettingsScreenState();
}

class _SystemSettingsScreenState extends ConsumerState<SystemSettingsScreen> {
  bool _isLoading = true;
  bool _saving = false;
  bool _isAdmin = true;
  String _userRole = 'ADMIN';

  // Company Profile & Location Settings
  final TextEditingController _companyNameController = TextEditingController(text: 'Envision Beyond India Pvt Ltd');
  final TextEditingController _premisesNameController = TextEditingController(text: 'Surat, Gujarat, India');
  final TextEditingController _latController = TextEditingController(text: '21.1986872');
  final TextEditingController _lngController = TextEditingController(text: '72.7965515');
  final TextEditingController _geofenceController = TextEditingController(text: '200');

  // Shift & Attendance Settings
  final TextEditingController _shiftStartController = TextEditingController(text: '09:30');
  final TextEditingController _shiftEndController = TextEditingController(text: '18:30');
  final TextEditingController _graceController = TextEditingController(text: '15');
  final TextEditingController _minHoursController = TextEditingController(text: '8');
  final TextEditingController _maxBreakController = TextEditingController(text: '60');

  @override
  void initState() {
    super.initState();
    _checkUserRole();
    _loadSettings();
  }

  void _checkUserRole() {
    final user = ref.read(authServiceProvider).user;
    if (user != null) {
      _userRole = user.role.toString();
      final r = _userRole.toUpperCase();
      _isAdmin = r == 'ADMIN' || r == 'SYSTEM ADMIN' || r == 'SUPERADMIN';
    }
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    final apiClient = ref.read(apiClientProvider);

    try {
      final locRes = await apiClient.get('/attendance/office-location').catchError((_) => null);
      if (locRes is Map<String, dynamic>) {
        if (locRes['latitude'] != null) _latController.text = '${locRes['latitude']}';
        if (locRes['longitude'] != null) _lngController.text = '${locRes['longitude']}';
        if (locRes['geofenceRadiusMeters'] != null) _geofenceController.text = '${locRes['geofenceRadiusMeters']}';
        if (locRes['officeAddress'] != null) _premisesNameController.text = '${locRes['officeAddress']}';
        if (locRes['officeName'] != null) _companyNameController.text = '${locRes['officeName']}';
      }

      final attRes = await apiClient.get('/attendance/settings').catchError((_) => null);
      if (attRes is Map<String, dynamic>) {
        if (attRes['defaultShiftStart'] != null) _shiftStartController.text = attRes['defaultShiftStart'];
        if (attRes['defaultShiftEnd'] != null) _shiftEndController.text = attRes['defaultShiftEnd'];
        if (attRes['gracePeriodMinutes'] != null) _graceController.text = '${attRes['gracePeriodMinutes']}';
        if (attRes['minWorkHours'] != null) _minHoursController.text = '${attRes['minWorkHours']}';
        if (attRes['maxBreakMinutes'] != null) _maxBreakController.text = '${attRes['maxBreakMinutes']}';
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    if (!_isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Read-only mode: Only System Admins can modify settings.')));
      return;
    }

    setState(() => _saving = true);
    final apiClient = ref.read(apiClientProvider);

    final lat = double.tryParse(_latController.text) ?? 21.1986872;
    final lng = double.tryParse(_lngController.text) ?? 72.7965515;
    final geofence = int.tryParse(_geofenceController.text) ?? 200;

    try {
      await apiClient.post('/attendance/office-location', body: {
        'latitude': lat,
        'longitude': lng,
        'officeName': _companyNameController.text.trim(),
        'officeAddress': _premisesNameController.text.trim(),
        'geofenceRadiusMeters': geofence,
      });

      await apiClient.post('/attendance/settings', body: {
        'defaultShiftStart': _shiftStartController.text.trim(),
        'defaultShiftEnd': _shiftEndController.text.trim(),
        'gracePeriodMinutes': int.tryParse(_graceController.text) ?? 15,
        'geofenceRadiusMeters': geofence,
        'minWorkHours': int.tryParse(_minHoursController.text) ?? 8,
        'maxBreakMinutes': int.tryParse(_maxBreakController.text) ?? 60,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('System settings saved successfully!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save settings: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Read-Only Banner if not admin
          if (!_isAdmin)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: Colors.amber[100], borderRadius: BorderRadius.circular(8)),
              child: Row(
                children: [
                  Icon(Icons.lock, color: Colors.amber[800]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('System Overview (Read-Only Mode)', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text('You are logged in as $_userRole. System configuration can only be edited by System Admins.'),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // Compact Reference System Info Rows
          CompactInfoRowTile(
            label: 'Environment Status',
            value: 'Production Active',
            dotColor: AppColors.success,
          ),
          const SizedBox(height: 8),
          CompactInfoRowTile(
            label: 'Geofence Perimeter Radius',
            value: '${_geofenceController.text} Meters',
            dotColor: AppColors.primary,
          ),
          const SizedBox(height: 8),
          CompactInfoRowTile(
            label: 'Standard Shift Hours',
            value: '${_shiftStartController.text} - ${_shiftEndController.text}',
            dotColor: const Color(0xFF9333EA),
          ),
          const SizedBox(height: 20),

          // Office Premises & Location
          const Text('Office Premises & Location', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary)),
          const SizedBox(height: 12),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _companyNameController,
                  readOnly: !_isAdmin,
                  decoration: const InputDecoration(labelText: 'Company Name', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _premisesNameController,
                  readOnly: !_isAdmin,
                  decoration: const InputDecoration(labelText: 'Office Address', border: OutlineInputBorder(), prefixIcon: Icon(Icons.location_on)),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _latController,
                        readOnly: !_isAdmin,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Latitude', border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _lngController,
                        readOnly: !_isAdmin,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Longitude', border: OutlineInputBorder()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _geofenceController,
                  readOnly: !_isAdmin,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Geofence Perimeter (Meters)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.radar)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Shift & Attendance Rules
          const Text('Shift & Attendance Rules', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary)),
          const SizedBox(height: 12),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _shiftStartController,
                        readOnly: !_isAdmin,
                        decoration: const InputDecoration(labelText: 'Default Shift Start', border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _shiftEndController,
                        readOnly: !_isAdmin,
                        decoration: const InputDecoration(labelText: 'Default Shift End', border: OutlineInputBorder()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _graceController,
                        readOnly: !_isAdmin,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Grace Period (mins)', border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _minHoursController,
                        readOnly: !_isAdmin,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Min Work Hours', border: OutlineInputBorder()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _maxBreakController,
                  readOnly: !_isAdmin,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Max Break Duration (mins)', border: OutlineInputBorder()),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // Save Button
          if (_isAdmin)
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _saveSettings,
                icon: _saving ? const CircularProgressIndicator(color: Colors.white) : const Icon(Icons.save),
                label: Text(_saving ? 'Saving...' : 'Save System Settings', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}
