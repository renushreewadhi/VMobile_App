import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/loading_shimmer.dart';

class HrAttendanceVerificationsScreen extends ConsumerStatefulWidget {
  const HrAttendanceVerificationsScreen({super.key});

  @override
  ConsumerState<HrAttendanceVerificationsScreen> createState() => _HrAttendanceVerificationsScreenState();
}

class _HrAttendanceVerificationsScreenState extends ConsumerState<HrAttendanceVerificationsScreen> {
  bool _isLoading = true;
  List<dynamic> _verifications = [];
  String _activeTab = 'PENDING';
  String _searchTerm = '';

  @override
  void initState() {
    super.initState();
    _loadVerifications();
  }

  Future<void> _loadVerifications() async {
    setState(() => _isLoading = true);
    final apiClient = ref.read(apiClientProvider);
    try {
      final res = await apiClient.get('/attendance/verifications').catchError((_) => null);
      List<dynamic> items = [];
      if (res is List) {
        items = res;
      } else if (res is Map<String, dynamic>) {
        items = res['items'] ?? res['data'] ?? [];
      }
      setState(() {
        _verifications = items;
        _isLoading = false;
      });
    } catch (_) {
      setState(() {
        _verifications = [];
        _isLoading = false;
      });
    }
  }

  Future<void> _updateVerification(String id, String status) async {
    final apiClient = ref.read(apiClientProvider);
    try {
      final endpoint = status == 'APPROVED' ? '/attendance/verification/$id/approve' : '/attendance/verification/$id/reject';
      await apiClient.post(endpoint, body: {'reason': status == 'REJECTED' ? 'Rejected by HR' : ''});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Verification $status')));
        _loadVerifications();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const LoadingShimmer();

    final filtered = _verifications.where((v) {
      final map = v is Map<String, dynamic> ? v : {};
      final status = (map['verificationStatus'] ?? 'PENDING').toString().toUpperCase();
      final name = (map['employeeName'] ?? '').toString().toLowerCase();
      return status == _activeTab && (_searchTerm.isEmpty || name.contains(_searchTerm.toLowerCase()));
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Attendance Verifications')),
      body: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildTabButton('PENDING', 'Pending'),
              _buildTabButton('APPROVED', 'Approved'),
              _buildTabButton('REJECTED', 'Rejected'),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Search employee...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (val) => setState(() => _searchTerm = val),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final v = filtered[index] as Map<String, dynamic>;
                return AppCard(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(v['employeeName'] ?? 'Employee', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Chip(label: Text(v['verificationStatus'] ?? 'PENDING')),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text('Code: ${v['employeeCode'] ?? ''} • Dept: ${v['departmentName'] ?? 'General'}'),
                      const SizedBox(height: 4),
                      Text('Face Result: ${v['faceVerificationResult'] ?? 'N/A'} • Geofence: ${v['isWithinGeofence'] == true ? 'Inside' : 'Outside'}'),
                      const SizedBox(height: 12),
                      if (_activeTab == 'PENDING')
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => _updateVerification(v['attendanceId'] ?? v['id'], 'REJECTED'),
                              icon: const Icon(Icons.close, color: Colors.red),
                              label: const Text('Reject', style: TextStyle(color: Colors.red)),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              onPressed: () => _updateVerification(v['attendanceId'] ?? v['id'], 'APPROVED'),
                              icon: const Icon(Icons.check),
                              label: const Text('Approve'),
                            ),
                          ],
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(String tabKey, String label) {
    final isActive = _activeTab == tabKey;
    return TextButton(
      onPressed: () => setState(() => _activeTab = tabKey),
      child: Text(
        label,
        style: TextStyle(
          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          color: isActive ? AppColors.primary : Colors.grey,
        ),
      ),
    );
  }
}
