import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/empty_state_widget.dart';
import '../../shared/widgets/error_state_widget.dart';
import '../../shared/widgets/loading_shimmer.dart';

class FinancePayrollReportsScreen extends ConsumerStatefulWidget {
  const FinancePayrollReportsScreen({super.key});

  @override
  ConsumerState<FinancePayrollReportsScreen> createState() => _FinancePayrollReportsScreenState();
}

class _FinancePayrollReportsScreenState extends ConsumerState<FinancePayrollReportsScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _reports = [];

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    final apiClient = ref.read(apiClientProvider);

    try {
      final res = await apiClient.get(ApiEndpoints.payrollReports);

      if (mounted) {
        List<dynamic> items = [];
        if (res is List) {
          items = res;
        } else if (res is Map<String, dynamic> && res['data'] is List) {
          items = res['data'];
        } else if (res is Map<String, dynamic> && res['items'] is List) {
          items = res['items'];
        }

        _reports = items.map((r) => _mapReport(r)).toList();
        _isLoading = false;
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _reports = [];
          _errorMessage = e.toString().replaceFirst('Exception: ', '').replaceFirst('ApiException: ', '');
          _isLoading = false;
        });
      }
    }
  }

  Map<String, dynamic> _mapReport(dynamic r) {
    final Map<String, dynamic> map = r is Map<String, dynamic> ? r : {};
    return {
      'title': map['title'] ?? map['name'] ?? 'Payroll Report',
      'description': map['description'] ?? map['desc'] ?? 'Detailed breakdown of payroll and statutory liabilities',
      'frequency': map['frequency'] ?? 'Monthly',
      'icon': Icons.assessment,
    };
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const DashboardSkeleton();
    if (_errorMessage != null) {
      return ErrorStateWidget(
        errorMessage: _errorMessage!,
        onRetry: _loadReports,
      );
    }

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

            _reports.isEmpty
                ? const EmptyStateWidget(
                    title: 'No Payroll Reports',
                    message: 'There are no generated payroll reports found on the server.',
                    icon: Icons.assessment_outlined,
                  )
                : ListView.builder(
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
