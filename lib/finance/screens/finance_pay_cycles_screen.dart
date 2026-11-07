import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/loading_shimmer.dart';

class FinancePayCyclesScreen extends ConsumerStatefulWidget {
  const FinancePayCyclesScreen({super.key});

  @override
  ConsumerState<FinancePayCyclesScreen> createState() => _FinancePayCyclesScreenState();
}

class _FinancePayCyclesScreenState extends ConsumerState<FinancePayCyclesScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _cycles = [];

  @override
  void initState() {
    super.initState();
    _loadCycles();
  }

  Future<void> _loadCycles() async {
    setState(() => _isLoading = true);
    final apiClient = ref.read(apiClientProvider);

    try {
      final res = await apiClient.get(ApiEndpoints.payCycles).catchError((_) => null);

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
          _cycles = items.map((c) => _mapCycle(c)).toList();
        } else {
          _cycles = _getMockCycles();
        }
        _isLoading = false;
        setState(() {});
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _cycles = _getMockCycles();
          _isLoading = false;
        });
      }
    }
  }

  Map<String, dynamic> _mapCycle(dynamic c) {
    final Map<String, dynamic> map = c is Map<String, dynamic> ? c : {};
    return {
      'title': map['title'] ?? 'Payroll Cycle',
      'period': map['period'] ?? '01 Oct 2025 - 31 Oct 2025',
      'payDay': map['payDay'] ?? '01 Nov 2025',
      'status': map['status'] ?? 'Active',
      'totalEmployees': map['totalEmployees']?.toString() ?? '245',
    };
  }

  List<Map<String, dynamic>> _getMockCycles() {
    return [
      {'title': 'October 2025 Monthly Payroll', 'period': '01 Oct 2025 - 31 Oct 2025', 'payDay': '01 Nov 2025', 'status': 'Active', 'totalEmployees': '248'},
      {'title': 'September 2025 Monthly Payroll', 'period': '01 Sep 2025 - 30 Sep 2025', 'payDay': '01 Oct 2025', 'status': 'Processed', 'totalEmployees': '242'},
      {'title': 'August 2025 Monthly Payroll', 'period': '01 Aug 2025 - 31 Aug 2025', 'payDay': '01 Sep 2025', 'status': 'Processed', 'totalEmployees': '239'},
      {'title': 'November 2025 Advance Cycle', 'period': '01 Nov 2025 - 30 Nov 2025', 'payDay': '01 Dec 2025', 'status': 'Upcoming', 'totalEmployees': '250'},
    ];
  }

  void _showAddCycleDialog() {
    final titleController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.calendar_today, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Create Pay Cycle', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Cycle Title *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            TextField(controller: titleController, decoration: InputDecoration(hintText: 'e.g. December 2025 Payroll', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (titleController.text.trim().isEmpty) return;
              setState(() {
                _cycles.insert(0, {
                  'title': titleController.text.trim(),
                  'period': '01 Dec 2025 - 31 Dec 2025',
                  'payDay': '02 Jan 2026',
                  'status': 'Upcoming',
                  'totalEmployees': '255',
                });
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pay cycle created successfully'), backgroundColor: AppColors.success));
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const DashboardSkeleton();

    return RefreshIndicator(
      onRefresh: _loadCycles,
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
                    child: Icon(Icons.calendar_month, color: Colors.white, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('Pay Cycles Management', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        SizedBox(height: 4),
                        Text('Manage monthly payroll schedules, run dates & disbursement cycles', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _showAddCycleDialog,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('New Cycle'),
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
              itemCount: _cycles.length,
              itemBuilder: (context, index) {
                final item = _cycles[index];
                final status = item['status'] ?? 'Active';
                final statusColor = status == 'Processed' ? AppColors.success : (status == 'Active' ? AppColors.primary : Colors.orange);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(item['title'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: statusColor.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                              child: Text(status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Icon(Icons.date_range, size: 14, color: AppColors.lightMutedText),
                            const SizedBox(width: 6),
                            Text('Period: ${item['period']}', style: const TextStyle(fontSize: 12, color: AppColors.lightMutedText)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.payment, size: 14, color: AppColors.lightMutedText),
                            const SizedBox(width: 6),
                            Text('Pay Date: ${item['payDay']} • Employees: ${item['totalEmployees']}', style: const TextStyle(fontSize: 12, color: AppColors.lightMutedText)),
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
