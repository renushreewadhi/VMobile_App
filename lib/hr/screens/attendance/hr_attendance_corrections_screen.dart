import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/loading_shimmer.dart';

class HrAttendanceCorrectionsScreen extends ConsumerStatefulWidget {
  const HrAttendanceCorrectionsScreen({super.key});

  @override
  ConsumerState<HrAttendanceCorrectionsScreen> createState() => _HrAttendanceCorrectionsScreenState();
}

class _HrAttendanceCorrectionsScreenState extends ConsumerState<HrAttendanceCorrectionsScreen> {
  bool _isLoading = true;
  List<dynamic> _corrections = [];
  String _searchTerm = '';
  String _selectedStatus = '';

  @override
  void initState() {
    super.initState();
    _loadCorrections();
  }

  Future<void> _loadCorrections() async {
    setState(() => _isLoading = true);
    final apiClient = ref.read(apiClientProvider);
    try {
      final res = await apiClient.get('/attendance/corrections').catchError((_) => null);
      List<dynamic> items = [];
      if (res is List) {
        items = res;
      } else if (res is Map<String, dynamic>) {
        items = res['items'] ?? res['data'] ?? [];
      }
      setState(() {
        _corrections = items;
        _isLoading = false;
      });
    } catch (_) {
      setState(() {
        _corrections = [];
        _isLoading = false;
      });
    }
  }

  Future<void> _reviewCorrection(String id, String status) async {
    final apiClient = ref.read(apiClientProvider);
    try {
      await apiClient.post('/attendance/corrections/$id/review', body: {'status': status});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Correction request $status')));
        _loadCorrections();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update status: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const LoadingShimmer();

    final filtered = _corrections.where((c) {
      final map = c is Map<String, dynamic> ? c : {};
      final name = (map['employeeName'] ?? '').toString().toLowerCase();
      final status = (map['status'] ?? '').toString().toUpperCase();
      final matchesSearch = _searchTerm.isEmpty || name.contains(_searchTerm.toLowerCase());
      final matchesStatus = _selectedStatus.isEmpty || status == _selectedStatus.toUpperCase();
      return matchesSearch && matchesStatus;
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Attendance Corrections')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(
                labelText: 'Search employee or reason...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (val) => setState(() => _searchTerm = val),
            ),
            const SizedBox(height: 16),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final c = filtered[index] as Map<String, dynamic>;
                final status = (c['status'] ?? 'PENDING').toString();
                return AppCard(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(c['employeeName'] ?? 'Employee', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Chip(label: Text(status)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text('Date: ${c['date'] ?? ''} • Dept: ${c['departmentName'] ?? 'General'}'),
                      const SizedBox(height: 4),
                      Text('Reason: ${c['reason'] ?? 'N/A'}', style: const TextStyle(color: Colors.grey)),
                      const SizedBox(height: 12),
                      if (status.toUpperCase() == 'PENDING')
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => _reviewCorrection(c['id'], 'REJECTED'),
                              icon: const Icon(Icons.close, color: Colors.red),
                              label: const Text('Reject', style: TextStyle(color: Colors.red)),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              onPressed: () => _reviewCorrection(c['id'], 'APPROVED'),
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
          ],
        ),
      ),
    );
  }
}
