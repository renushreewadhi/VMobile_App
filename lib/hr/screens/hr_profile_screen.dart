import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/auth/auth_service.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/loading_shimmer.dart';

class HrProfileScreen extends ConsumerStatefulWidget {
  const HrProfileScreen({super.key});

  @override
  ConsumerState<HrProfileScreen> createState() => _HrProfileScreenState();
}

class _HrProfileScreenState extends ConsumerState<HrProfileScreen> {
  bool _isLoading = true;
  Map<String, dynamic> _profile = {};

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    final apiClient = ref.read(apiClientProvider);
    try {
      final res = await apiClient.get(ApiEndpoints.currentUser).catchError((_) => null);
      final map = res is Map<String, dynamic> ? (res['data'] ?? res) : {};
      setState(() {
        _profile = map;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const LoadingShimmer();

    final firstName = _profile['firstName'] ?? 'HR';
    final lastName = _profile['lastName'] ?? 'Manager';
    final email = _profile['email'] ?? 'hr@hrm.com';
    final designation = _profile['designation'] ?? 'HR Specialist';
    final department = _profile['department'] ?? 'Human Resources';

    return Scaffold(
      appBar: AppBar(title: const Text('My Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            AppCard(
              backgroundColor: AppColors.primary,
              child: Column(
                children: [
                  const CircleAvatar(radius: 35, child: Icon(Icons.person, size: 35)),
                  const SizedBox(height: 12),
                  Text('$firstName $lastName', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(email, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 8),
                  Chip(label: Text('$designation • $department')),
                ],
              ),
            ),
            const SizedBox(height: 20),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Employment Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const Divider(),
                  _infoRow('Employee ID', _profile['employeeId'] ?? 'EMP-HR-001'),
                  _infoRow('Designation', designation),
                  _infoRow('Department', department),
                  _infoRow('Branch', _profile['branch'] ?? 'HQ'),
                  _infoRow('Joined Date', _profile['joiningDate'] ?? '2024-01-01'),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                icon: const Icon(Icons.logout),
                label: const Text('LOG OUT'),
                onPressed: () {
                  ref.read(authServiceProvider.notifier).logout();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text('${value ?? '—'}', style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
