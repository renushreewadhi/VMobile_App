import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/loading_shimmer.dart';

class FinancePayrollReportsScreen extends ConsumerStatefulWidget {
  const FinancePayrollReportsScreen({super.key});

  @override
  ConsumerState<FinancePayrollReportsScreen> createState() => _FinancePayrollReportsScreenState();
}

class _FinancePayrollReportsScreenState extends ConsumerState<FinancePayrollReportsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _reports = [];

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() => _isLoading = true);
    final apiClient = ref.read(apiClientProvider);

    try {
      final res = await apiClient.get(ApiEndpoints.payrollReports).catchError((_) => null);

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
          _reports = items.map((r) => _mapReport(r)).toList();
        } else {
          _reports = _getMockReports();
        }
        _isLoading = false;
        setState(() {});
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _reports = _getMockReports();
          _isLoading = false;
        });
      }
    }
  }

  Map<String, dynamic> _mapReport(dynamic r) {
    final Map<String, dynamic> map = r is Map<String, dynamic> ? r : {};
    return {
      'title': map['title'] ?? 'Payroll Report',
      'description': map['description'] ?? 'Detailed breakdown of payroll and statutory liabilities',
      'frequency': map['frequency'] ?? 'Monthly',
      'icon': Icons.assessment,
    };
  }

  List<Map<String, dynamic>> _getMockReports() {
    return [
      {'title': 'Monthly Salary Register', 'description': 'Comprehensive employee-wise earnings, deductions and net payout summary', 'frequency': 'Monthly', 'icon': Icons.receipt_long},
      {'title': 'PF & ESI Contribution Report', 'description': 'Statutory provident fund and employee state insurance breakdown', 'frequency': 'Monthly', 'icon': Icons.account_balance},
      {'title': 'TDS & Tax Deduction Summary', 'description': 'Income tax deducted at source across all payroll grades', 'frequency': 'Quarterly', 'icon': Icons.gavel},
      {'title': 'Department-wise Payroll Cost', 'description': 'Cost analysis across Engineering, Sales, HR, and Operations', 'frequency': 'Monthly', 'icon': Icons.pie_chart},
      {'title': 'Bonus & Overtime Dispersal Report', 'description': 'Ad-hoc bonuses, incentive payouts and overtime hours report', 'frequency': 'Monthly', 'icon': Icons.card_giftcard},
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const DashboardSkeleton();

    return RefreshIndicator(
      onRefresh: _loadReports,
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
                    child: Icon(Icons.assessment, color: Colors.white, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('Payroll Reports & Analytics', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        SizedBox(height: 4),
                        Text('Generate salary registers, statutory PF/ESI & tax compliance reports', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _reports.length,
              itemBuilder: (context, index) {
                final item = _reports[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: AppCard(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                        child: Icon(item['icon'] ?? Icons.assessment, color: AppColors.primary),
                      ),
                      title: Text(item['title'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(item['description'], style: const TextStyle(fontSize: 12, color: AppColors.lightMutedText)),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.download, color: AppColors.primary),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Downloading ${item['title']}...'), backgroundColor: AppColors.success),
                          );
                        },
                      ),
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
