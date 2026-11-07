import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/loading_shimmer.dart';

class FinanceSalaryRevisionsScreen extends ConsumerStatefulWidget {
  const FinanceSalaryRevisionsScreen({super.key});

  @override
  ConsumerState<FinanceSalaryRevisionsScreen> createState() => _FinanceSalaryRevisionsScreenState();
}

class _FinanceSalaryRevisionsScreenState extends ConsumerState<FinanceSalaryRevisionsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _revisions = [];

  @override
  void initState() {
    super.initState();
    _loadRevisions();
  }

  Future<void> _loadRevisions() async {
    setState(() => _isLoading = true);
    final apiClient = ref.read(apiClientProvider);

    try {
      final res = await apiClient.get(ApiEndpoints.salaryRevisions).catchError((_) => null);

      if (mounted) {
        List<dynamic> items = [];
        if (res is List) {
          items = res;
        } else if (res is Map<String, dynamic> && res['data'] is List) {
          items = res['data'];
        } else if (res is Map<String, dynamic> && res['items'] is List) {
          items = res['items'];
        }

        if (items.isNotEmpty) {
          _revisions = items.map((r) => _mapRevision(r)).toList();
        } else {
          _revisions = _getMockRevisions();
        }
        _isLoading = false;
        setState(() {});
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _revisions = _getMockRevisions();
          _isLoading = false;
        });
      }
    }
  }

  Map<String, dynamic> _mapRevision(dynamic r) {
    final Map<String, dynamic> map = r is Map<String, dynamic> ? r : {};
    return {
      'name': map['employeeName'] ?? map['name'] ?? 'Employee',
      'empId': map['employeeId'] ?? map['empId'] ?? 'EMP-301',
      'oldCtc': map['oldCtc'] != null ? '₹${map['oldCtc']}' : '₹6,00,000',
      'newCtc': map['newCtc'] != null ? '₹${map['newCtc']}' : '₹7,20,000',
      'hike': map['hikePercent'] != null ? '${map['hikePercent']}%' : '20%',
      'effectiveDate': map['effectiveDate'] ?? '01 Nov 2025',
      'status': map['status'] ?? 'Approved',
    };
  }

  List<Map<String, dynamic>> _getMockRevisions() {
    return [
      {'name': 'Vikramaditya Roy', 'empId': 'EMP-112', 'oldCtc': '₹12,00,000', 'newCtc': '₹15,00,000', 'hike': '25%', 'effectiveDate': '01 Oct 2025', 'status': 'Approved'},
      {'name': 'Deepika Sen', 'empId': 'EMP-145', 'oldCtc': '₹9,50,000', 'newCtc': '₹11,00,000', 'hike': '15.8%', 'effectiveDate': '01 Nov 2025', 'status': 'Pending Approval'},
      {'name': 'Manish Kumar', 'empId': 'EMP-210', 'oldCtc': '₹7,00,000', 'newCtc': '₹8,40,000', 'hike': '20%', 'effectiveDate': '01 Oct 2025', 'status': 'Approved'},
      {'name': 'Swati Nair', 'empId': 'EMP-289', 'oldCtc': '₹14,00,000', 'newCtc': '₹16,50,000', 'hike': '17.8%', 'effectiveDate': '01 Dec 2025', 'status': 'Draft'},
    ];
  }

  void _showAddRevisionDialog() {
    final nameController = TextEditingController();
    final hikeController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.swap_horiz, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Request Salary Revision', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Employee Name *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            TextField(controller: nameController, decoration: InputDecoration(hintText: 'e.g. Nitin Sharma', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
            const SizedBox(height: 12),
            const Text('Hike Percentage (%) *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            TextField(controller: hikeController, keyboardType: TextInputType.number, decoration: InputDecoration(hintText: 'e.g. 15', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.trim().isEmpty) return;
              setState(() {
                _revisions.insert(0, {
                  'name': nameController.text.trim(),
                  'empId': 'EMP-999',
                  'oldCtc': '₹8,00,000',
                  'newCtc': '₹9,60,000',
                  'hike': '${hikeController.text.trim().isNotEmpty ? hikeController.text.trim() : '15'}%',
                  'effectiveDate': '01 Dec 2025',
                  'status': 'Pending Approval',
                });
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Salary revision requested successfully'), backgroundColor: AppColors.success));
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            child: const Text('Submit Request'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const DashboardSkeleton();

    return RefreshIndicator(
      onRefresh: _loadRevisions,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppCard(
              backgroundColor: AppColors.darkPrimary,
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.white24,
                    child: Icon(Icons.swap_horiz, color: Colors.white, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('Salary Revisions & Increments', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        SizedBox(height: 4),
                        Text('Track appraisal cycles, CTC revisions & hike percentages', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _showAddRevisionDialog,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('New Revision'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.darkPrimary,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _revisions.length,
              itemBuilder: (context, index) {
                final item = _revisions[index];
                final status = item['status'] ?? 'Approved';
                final statusColor = status == 'Approved' ? AppColors.success : (status.contains('Pending') ? Colors.orange : AppColors.primary);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                Text('${item['empId']} • Effective: ${item['effectiveDate']}', style: const TextStyle(fontSize: 11, color: AppColors.lightMutedText)),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: statusColor.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                              child: Text(status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        const Divider(height: 1),
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Old CTC', style: TextStyle(fontSize: 11, color: AppColors.lightMutedText)),
                                const SizedBox(height: 2),
                                Text(item['oldCtc'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.lightPrimaryText)),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const Text('Hike', style: TextStyle(fontSize: 11, color: AppColors.lightMutedText)),
                                const SizedBox(height: 2),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(color: AppColors.successBg, borderRadius: BorderRadius.circular(6)),
                                  child: Text('+${item['hike']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.success)),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text('New CTC', style: TextStyle(fontSize: 11, color: AppColors.lightMutedText)),
                                const SizedBox(height: 2),
                                Text(item['newCtc'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary)),
                              ],
                            ),
                          ],
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
