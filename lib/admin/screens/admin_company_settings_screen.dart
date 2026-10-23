import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_card.dart';

class AdminCompanySettingsScreen extends ConsumerStatefulWidget {
  const AdminCompanySettingsScreen({super.key});

  @override
  ConsumerState<AdminCompanySettingsScreen> createState() => _AdminCompanySettingsScreenState();
}

class _AdminCompanySettingsScreenState extends ConsumerState<AdminCompanySettingsScreen> {
  bool _isLoading = true;
  bool _isSaving = false;

  final TextEditingController _nameController = TextEditingController(text: 'Envision Beyond India Pvt Ltd');
  final TextEditingController _emailController = TextEditingController(text: 'hr@envision.com');
  final TextEditingController _phoneController = TextEditingController(text: '+91 9876543210');
  final TextEditingController _addressController = TextEditingController(text: 'Surat, Gujarat, India');
  final TextEditingController _latController = TextEditingController(text: '21.1986872');
  final TextEditingController _lngController = TextEditingController(text: '72.7965515');
  final TextEditingController _radiusController = TextEditingController(text: '200');

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    final apiClient = ref.read(apiClientProvider);

    try {
      final res = await apiClient.get('/system-settings/company-profile').catchError((_) => null);
      if (res is Map<String, dynamic>) {
        _nameController.text = res['companyName'] ?? 'Envision Beyond India Pvt Ltd';
        _emailController.text = res['email'] ?? 'hr@envision.com';
        _phoneController.text = res['phone'] ?? '+91 9876543210';
        _addressController.text = res['address'] ?? 'Surat, Gujarat, India';
        _latController.text = '${res['latitude'] ?? 21.1986872}';
        _lngController.text = '${res['longitude'] ?? 72.7965515}';
        _radiusController.text = '${res['geofenceRadiusMeters'] ?? 200}';
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
      'companyName': _nameController.text.trim(),
      'email': _emailController.text.trim(),
      'phone': _phoneController.text.trim(),
      'address': _addressController.text.trim(),
      'latitude': double.tryParse(_latController.text) ?? 21.1986872,
      'longitude': double.tryParse(_lngController.text) ?? 72.7965515,
      'geofenceRadiusMeters': int.tryParse(_radiusController.text) ?? 200,
    };

    try {
      await apiClient.post('/system-settings/company-profile', data: payload);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Company profile updated successfully')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save company profile: $e')));
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
        title: const Text('Company & Location Settings'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Corporate Profile & Headquarters', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
            const SizedBox(height: 16),
            AppCard(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: 'Company Name', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _emailController,
                      decoration: const InputDecoration(labelText: 'Corporate Email', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _phoneController,
                      decoration: const InputDecoration(labelText: 'Phone Number', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _addressController,
                      decoration: const InputDecoration(labelText: 'HQ Address', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _latController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(labelText: 'Latitude', border: OutlineInputBorder()),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _lngController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(labelText: 'Longitude', border: OutlineInputBorder()),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _radiusController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Geofence Radius (Meters)', border: OutlineInputBorder()),
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
                label: Text(_isSaving ? 'Saving...' : 'Save Company Profile', style: const TextStyle(fontSize: 16)),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
