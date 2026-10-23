import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/compact_summary_widgets.dart';
import '../../shared/widgets/loading_shimmer.dart';

class FinanceDashboardScreen extends ConsumerStatefulWidget {
  final Function(int) onNavigateTab;

  const FinanceDashboardScreen({super.key, required this.onNavigateTab});

  @override
  ConsumerState<FinanceDashboardScreen> createState() => _FinanceDashboardScreenState();
}

class _FinanceDashboardScreenState extends ConsumerState<FinanceDashboardScreen> {
  bool _isLoading = true;
  String _selectedMonth = 'Sep 2026';

  final List<String> _months = ['Sep 2026', 'Aug 2026', 'Jul 2026'];

  Map<String, dynamic> _stats = {
    'totalPayroll': '₹ 54,20,000',
    'pendingReimbursementsCount': 18,
    'pendingReimbursementsAmount': '₹ 2,15,000',
    'activeLoansCount': 12,
    'taxDeductionsYtd': '₹ 6,80,000',
  };

  List<Map<String, dynamic>> _pendingApprovals = [];
  List<Map<String, dynamic>> _recentPayments = [];

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    final apiClient = ref.read(apiClientProvider);

    try {
      final dashRes = await apiClient.get(ApiEndpoints.financeDashboard).catchError((_) => null);
      if (dashRes is Map<String, dynamic>) {
        _stats = {..._stats, ...dashRes};
      }

      final appRes = await apiClient.get(ApiEndpoints.financeApprovals).catchError((_) => null);
      if (appRes is List && appRes.isNotEmpty) {
        _pendingApprovals = appRes.take(5).map((a) {
          final map = a is Map<String, dynamic> ? a : {};
          return {
            'id': map['reqId'] ?? 'APR-101',
            'type': map['requestType'] ?? map['description'] ?? 'Expense Claim',
            'employee': map['requestedBy'] ?? map['employeeName'] ?? 'Staff',
            'amount': map['amount'] != null ? '₹${map['amount']}' : '₹24,500',
            'requestedOn': map['date'] ?? '14 Oct 2026',
            'status': map['status'] ?? 'Pending',
          };
        }).toList();
      } else {
        _pendingApprovals = [
          {'id': 'APR-101', 'type': 'Conference Travel', 'employee': 'David Miller', 'amount': '₹24,500', 'requestedOn': '14 Oct 2026', 'status': 'Pending'},
          {'id': 'APR-102', 'type': 'Medical Advance', 'employee': 'Emily Watson', 'amount': '₹50,000', 'requestedOn': '12 Oct 2026', 'status': 'Pending'},
          {'id': 'APR-103', 'type': 'IT Workstation', 'employee': 'Alex Rivera', 'amount': '₹38,000', 'requestedOn': '10 Oct 2026', 'status': 'Pending'},
        ];
      }

      final payRes = await apiClient.get(ApiEndpoints.financePayments).catchError((_) => null);
      if (payRes is List && payRes.isNotEmpty) {
        _recentPayments = payRes.take(5).map((p) {
          final map = p is Map<String, dynamic> ? p : {};
          return {
            'id': map['paymentId'] ?? 'PAY-8901',
            'employee': map['employeeName'] ?? 'Staff',
            'type': map['paymentType'] ?? 'Salary Payout',
            'amount': map['amount'] != null ? '₹${map['amount']}' : '₹45,000',
            'paidOn': map['paidOn'] ?? map['createdAt'] ?? '12 Oct 2026',
            'status': map['status'] ?? 'Completed',
          };
        }).toList();
      } else {
        _recentPayments = [
          {'id': 'PAY-89012', 'employee': 'Sarah Jenkins', 'type': 'Health Benefit', 'amount': '₹25,000', 'paidOn': '12 Oct 2026', 'status': 'Completed'},
          {'id': 'PAY-89015', 'employee': 'Rajesh Sharma', 'type': 'Education Allowance', 'amount': '₹45,000', 'paidOn': '11 Oct 2026', 'status': 'Completed'},
          {'id': 'PAY-89018', 'employee': 'Anita Roy', 'type': 'Wellness Stipend', 'amount': '₹12,000', 'paidOn': '09 Oct 2026', 'status': 'In Process'},
        ];
      }

      if (mounted) setState(() => _isLoading = false);
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const DashboardSkeleton();

    final payrollTotal = _stats['totalPayroll'] ?? '₹ 54,20,000';
    final reimbursementsCount = _stats['pendingReimbursementsCount'] ?? 18;
    final activeLoansCount = _stats['activeLoansCount'] ?? 12;

    return RefreshIndicator(
      onRefresh: _loadDashboardData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. COMPACT STATUS BANNER WITH MONTH SELECTOR
            CompactStatusBanner(
              title: 'Finance Operations ($selectedMonthText)',
              subtitle: 'Total Payroll: $payrollTotal • Claims Pending: $reimbursementsCount',
              actionLabel: 'Approvals',
              icon: Icons.account_balance_rounded,
              onActionPressed: () => widget.onNavigateTab(3),
            ),
            const SizedBox(height: 12),

            // 2. PASTEL SUMMARY PILLS
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  PastelSummaryPill(
                    label: '$payrollTotal Total Payroll',
                    variant: PastelPillVariant.blue,
                    onTap: () => widget.onNavigateTab(1),
                  ),
                  const SizedBox(width: 8),
                  PastelSummaryPill(
                    label: '$reimbursementsCount Claims Pending',
                    variant: PastelPillVariant.amber,
                    onTap: () => widget.onNavigateTab(3),
                  ),
                  const SizedBox(width: 8),
                  PastelSummaryPill(
                    label: '$activeLoansCount Active Loans',
                    variant: PastelPillVariant.purple,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 3. CIRCULAR STATISTIC INDICATOR GROUP
            CircularStatGroup(
              items: [
                CircularStatItemData(
                  label: 'Payroll',
                  value: '₹54L',
                  ringColor: AppColors.primary,
                  onTap: () => widget.onNavigateTab(1),
                ),
                CircularStatItemData(
                  label: 'Claims',
                  value: '$reimbursementsCount',
                  ringColor: const Color(0xFFD97706),
                  onTap: () => widget.onNavigateTab(3),
                ),
                CircularStatItemData(
                  label: 'Loans',
                  value: '$activeLoansCount',
                  ringColor: const Color(0xFF9333EA),
                ),
                CircularStatItemData(
                  label: 'Payouts',
                  value: '${_recentPayments.length}',
                  ringColor: AppColors.success,
                  onTap: () => widget.onNavigateTab(5),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // 4. COMPACT INFO ROWS
            CompactInfoRowTile(
              label: 'Total Monthly Payroll Overhead',
              value: '$payrollTotal',
              dotColor: AppColors.primary,
              icon: Icons.chevron_right_rounded,
              onTap: () => widget.onNavigateTab(1),
            ),
            const SizedBox(height: 8),
            CompactInfoRowTile(
              label: 'Pending Reimbursements Queue',
              value: '$reimbursementsCount Requests',
              dotColor: const Color(0xFFD97706),
              icon: Icons.chevron_right_rounded,
              onTap: () => widget.onNavigateTab(3),
            ),
            const SizedBox(height: 18),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Month Period Selector', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.lightBackgroundTint,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedMonth,
                      isDense: true,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                      items: _months.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedMonth = val);
                      },
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Pending Approvals
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Pending Approvals', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                TextButton(
                  onPressed: () => widget.onNavigateTab(3),
                  child: const Text('View All', style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 8),

            ..._pendingApprovals.map((req) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AppCard(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(req['employee'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            Text('${req['type']} • ${req['requestedOn']}', style: const TextStyle(fontSize: 11, color: AppColors.lightSecondaryText)),
                          ],
                        ),
                      ),
                      Text(req['amount'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary)),
                      const SizedBox(width: 8),
                      const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.lightMutedText),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  String get selectedMonthText => _selectedMonth;
}
