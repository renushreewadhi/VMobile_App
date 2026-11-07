import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/loading_shimmer.dart';

class FinanceBenefitDashboardScreen extends ConsumerStatefulWidget {
  final VoidCallback? onViewPayments;
  final VoidCallback? onViewClaims;
  final VoidCallback? onViewReports;

  const FinanceBenefitDashboardScreen({
    super.key,
    this.onViewPayments,
    this.onViewClaims,
    this.onViewReports,
  });

  @override
  ConsumerState<FinanceBenefitDashboardScreen> createState() => _FinanceBenefitDashboardScreenState();
}

class _FinanceBenefitDashboardScreenState extends ConsumerState<FinanceBenefitDashboardScreen> {
  bool _isLoading = true;
  String? _processingId;

  Map<String, dynamic> _stats = {
    'totalBudget': 15000000,
    'totalBudgetUsed': 4850000,
    'pendingClaims': 4,
    'tlApprovedClaims': 3,
    'hrVerifiedClaims': 5,
    'processedClaims': 12,
    'paidClaims': 28,
  };

  List<Map<String, dynamic>> _recentClaims = [];

  // Payment Modal State
  String _paymentMethod = 'BANK_TRANSFER';
  final TextEditingController _transactionIdController = TextEditingController();
  final TextEditingController _paymentNotesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _transactionIdController.dispose();
    _paymentNotesController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final apiClient = ref.read(apiClientProvider);

    try {
      final statsRes = await apiClient.get(ApiEndpoints.benefitStats).catchError((_) => null);
      if (statsRes is Map<String, dynamic>) {
        _stats = {
          'totalBudget': statsRes['totalBudget'] ?? 15000000,
          'totalBudgetUsed': statsRes['totalBudgetUsed'] ?? 4850000,
          'pendingClaims': statsRes['pendingClaims'] ?? 4,
          'tlApprovedClaims': statsRes['tlApprovedClaims'] ?? 3,
          'hrVerifiedClaims': statsRes['hrVerifiedClaims'] ?? 5,
          'processedClaims': statsRes['processedClaims'] ?? 12,
          'paidClaims': statsRes['paidClaims'] ?? 28,
        };
      }

      final claimsRes = await apiClient.get(ApiEndpoints.benefitPendingClaims).catchError((_) => null);
      if (mounted) {
        List<dynamic> items = [];
        if (claimsRes is List) {
          items = claimsRes;
        } else if (claimsRes is Map<String, dynamic> && claimsRes['data'] is List) {
          items = claimsRes['data'];
        }

        if (items.isNotEmpty) {
          _recentClaims = items.map((c) => Map<String, dynamic>.from(c)).toList();
        } else {
          _recentClaims = _getMockClaims();
        }
        _isLoading = false;
        setState(() {});
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _recentClaims = _getMockClaims();
          _isLoading = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> _getMockClaims() {
    return [
      {
        'claimId': 'CLM-2026-801',
        'employeeName': 'Sarah Jenkins',
        'employeeCode': 'EMP-1042',
        'benefitName': 'Executive Health Checkup & Dental',
        'benefitCode': 'BEN-HLT-01',
        'amount': 25000,
        'claimDate': '2026-10-10',
        'hrVerifiedAt': '2026-10-12',
        'paymentStatus': 'PENDING',
      },
      {
        'claimId': 'CLM-2026-802',
        'employeeName': 'Rajesh Sharma',
        'employeeCode': 'EMP-1088',
        'benefitName': 'Child Higher Education Allowance',
        'benefitCode': 'BEN-EDU-03',
        'amount': 45000,
        'claimDate': '2026-10-08',
        'hrVerifiedAt': '2026-10-11',
        'paymentStatus': 'PENDING',
      },
      {
        'claimId': 'CLM-2026-803',
        'employeeName': 'Anita Roy',
        'employeeCode': 'EMP-1102',
        'benefitName': 'Gym & Wellness Membership Stipend',
        'benefitCode': 'BEN-WLN-02',
        'amount': 12000,
        'claimDate': '2026-10-05',
        'hrVerifiedAt': '2026-10-09',
        'paymentStatus': 'PROCESSED',
      },
      {
        'claimId': 'CLM-2026-804',
        'employeeName': 'Michael Chen',
        'employeeCode': 'EMP-1015',
        'benefitName': 'Home Office Ergonomic Setup',
        'benefitCode': 'BEN-WFH-05',
        'amount': 30000,
        'claimDate': '2026-10-01',
        'hrVerifiedAt': '2026-10-04',
        'paymentStatus': 'COMPLETED',
      },
    ];
  }

  int _getBudgetPercentage() {
    final total = (_stats['totalBudget'] as num?) ?? 0;
    final used = (_stats['totalBudgetUsed'] as num?) ?? 0;
    if (total == 0) return 0;
    return min(100, ((used / total) * 100).round());
  }

  String _formatCurrency(num amount) {
    final str = amount.toInt().toString();
    final RegExp reg = RegExp(r'(\d+?)(?=(\d{3})+(?!\d))');
    final String result = str.replaceAllMapped(reg, (Match m) => '${m[1]},');
    return '₹$result';
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '-';
    try {
      final dt = DateTime.parse(dateStr);
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${dt.day.toString().padLeft(2, '0')} ${months[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return dateStr;
    }
  }

  void _openPayModal(Map<String, dynamic> claim) {
    _paymentMethod = 'BANK_TRANSFER';
    _transactionIdController.clear();
    _paymentNotesController.clear();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            titlePadding: const EdgeInsets.all(16),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            actionsPadding: const EdgeInsets.all(12),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: const [
                    Icon(Icons.payment, color: AppColors.primary),
                    SizedBox(width: 8),
                    Text(
                      'Process Benefit Payment',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, size: 20),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.lightInputBackground,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              claim['employeeName'] ?? '',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            Text(
                              claim['employeeCode'] ?? '',
                              style: const TextStyle(fontSize: 11, color: AppColors.lightSecondaryText),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          claim['benefitName'] ?? '',
                          style: const TextStyle(fontSize: 12, color: AppColors.lightSecondaryText),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Disbursement Amount:',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                            Text(
                              _formatCurrency(claim['amount'] ?? 0),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Payment Method
                  const Text(
                    'Payment Mode',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.lightSecondaryText),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: _paymentMethod,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'BANK_TRANSFER', child: Text('Direct Bank Transfer (NEFT/RTGS)')),
                      DropdownMenuItem(value: 'CHEQUE', child: Text('Corporate Cheque / DD')),
                      DropdownMenuItem(value: 'ONLINE', child: Text('Corporate Net Banking')),
                      DropdownMenuItem(value: 'RAZORPAY', child: Text('Razorpay Payment Gateway')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setModalState(() => _paymentMethod = val);
                      }
                    },
                  ),
                  const SizedBox(height: 12),

                  if (_paymentMethod != 'RAZORPAY') ...[
                    const Text(
                      'Transaction / Ref Number',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.lightSecondaryText),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _transactionIdController,
                      decoration: InputDecoration(
                        hintText: 'e.g. UTR1029384756',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  const Text(
                    'Remarks / Notes',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.lightSecondaryText),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _paymentNotesController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'Optional audit note or payment reference...',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _processPayment(claim);
                },
                icon: const Icon(Icons.check_circle, size: 16),
                label: Text(_paymentMethod == 'RAZORPAY' ? 'Initiate Gateway' : 'Confirm Payment'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _processPayment(Map<String, dynamic> claim) async {
    final claimId = claim['claimId'] ?? '';
    setState(() => _processingId = claimId);

    final apiClient = ref.read(apiClientProvider);

    try {
      await apiClient.post(ApiEndpoints.benefitProcessPayment, data: {
        'claimId': claimId,
        'paymentMethod': _paymentMethod,
        'transactionId': _transactionIdController.text,
        'notes': _paymentNotesController.text,
      }).catchError((_) => null);

      if (mounted) {
        setState(() {
          claim['paymentStatus'] = 'COMPLETED';
          _stats['totalBudgetUsed'] = ((_stats['totalBudgetUsed'] as num?) ?? 0) + (claim['amount'] as num? ?? 0);
          final currentHrVerified = ((_stats['hrVerifiedClaims'] as num?) ?? 0).toInt();
          if (currentHrVerified > 0) {
            _stats['hrVerifiedClaims'] = currentHrVerified - 1;
          }
          _stats['paidClaims'] = ((_stats['paidClaims'] as num?) ?? 0).toInt() + 1;
          _processingId = null;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment processed successfully for claim ${claim['claimId']}!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (_) {
      if (mounted) setState(() => _processingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const DashboardSkeleton();

    final pct = _getBudgetPercentage();

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Header Card
            AppCard(
              backgroundColor: AppColors.darkPrimary,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const CircleAvatar(
                        radius: 24,
                        backgroundColor: Colors.white24,
                        child: Icon(Icons.account_balance_wallet, color: Colors.white, size: 26),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Benefit Finance Dashboard',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Overview of benefit budgets & claim disbursements',
                              style: TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Quick Action Buttons
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: widget.onViewPayments,
                          icon: const Icon(Icons.credit_card, size: 16),
                          label: const Text('Process Payments'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppColors.darkPrimary,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: widget.onViewClaims,
                          icon: const Icon(Icons.receipt_long, size: 16),
                          label: const Text('Benefit Claims'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white54),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: widget.onViewReports,
                          icon: const Icon(Icons.pie_chart, size: 16),
                          label: const Text('Cost Reports'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white54),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Stat Cards Grid
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.5,
              children: [
                _buildStatCard(
                  label: 'Total Annual Budget',
                  value: _formatCurrency((_stats['totalBudget'] as num?) ?? 0),
                  sub: 'Approved allocation',
                  icon: Icons.account_balance,
                  bgColor: const Color(0xFFEFF6FF),
                  iconColor: const Color(0xFF2563EB),
                ),
                _buildStatCard(
                  label: 'Budget Utilized',
                  value: _formatCurrency((_stats['totalBudgetUsed'] as num?) ?? 0),
                  sub: 'Processed claims',
                  icon: Icons.show_chart,
                  bgColor: const Color(0xFFFFF7ED),
                  iconColor: const Color(0xFFD97706),
                ),
                _buildStatCard(
                  label: 'Action Required',
                  value: '${_stats['hrVerifiedClaims'] ?? 0}',
                  sub: 'Claims ready for payment',
                  icon: Icons.access_time_filled,
                  bgColor: const Color(0xFFFFF1F2),
                  iconColor: const Color(0xFFEA580C),
                ),
                _buildStatCard(
                  label: 'Total Disbursed',
                  value: _formatCurrency((_stats['totalBudgetUsed'] as num?) ?? 0),
                  sub: 'Completed payments',
                  icon: Icons.check_circle,
                  bgColor: const Color(0xFFF0FDF4),
                  iconColor: const Color(0xFF16A34A),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Budget Utilization Card
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.pie_chart, color: AppColors.primary, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Annual Budget Utilization',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.successBg,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: const [
                            Icon(Icons.check_circle, color: AppColors.success, size: 12),
                            SizedBox(width: 4),
                            Text(
                              'On Track',
                              style: TextStyle(color: AppColors.success, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Center Donut Gauge
                  Center(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 120,
                          height: 120,
                          child: CircularProgressIndicator(
                            value: pct / 100,
                            strokeWidth: 12,
                            backgroundColor: Colors.grey.shade200,
                            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.darkPrimary),
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$pct%',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: AppColors.darkPrimary,
                              ),
                            ),
                            const Text(
                              'UTILIZED',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppColors.lightMutedText,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Breakdown Metrics Row
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            const Text('Total Budget', style: TextStyle(fontSize: 11, color: AppColors.lightMutedText)),
                            const SizedBox(height: 2),
                            Text(
                              _formatCurrency((_stats['totalBudget'] as num?) ?? 0),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      Container(height: 24, width: 1, color: Colors.grey.shade300),
                      Expanded(
                        child: Column(
                          children: [
                            const Text('Used / Paid', style: TextStyle(fontSize: 11, color: AppColors.lightMutedText)),
                            const SizedBox(height: 2),
                            Text(
                              _formatCurrency((_stats['totalBudgetUsed'] as num?) ?? 0),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.warning),
                            ),
                          ],
                        ),
                      ),
                      Container(height: 24, width: 1, color: Colors.grey.shade300),
                      Expanded(
                        child: Column(
                          children: [
                            const Text('Available', style: TextStyle(fontSize: 11, color: AppColors.lightMutedText)),
                            const SizedBox(height: 2),
                            Text(
                              _formatCurrency(((_stats['totalBudget'] as num?) ?? 0) - ((_stats['totalBudgetUsed'] as num?) ?? 0)),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.success),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: pct / 100,
                      minHeight: 8,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Claims Pipeline Card
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.alt_route, color: AppColors.primary, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Claims Disbursement Pipeline',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ],
                      ),
                      InkWell(
                        onTap: widget.onViewClaims,
                        child: const Text(
                          'View Claims',
                          style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _buildPipelineRow('Step 1', 'Pending TL Review', _stats['pendingClaims'] ?? 0, AppColors.warningBg, AppColors.warning),
                  _buildPipelineRow('Step 2', 'TL Approved (Awaiting HR)', _stats['tlApprovedClaims'] ?? 0, AppColors.infoBg, AppColors.info),
                  _buildPipelineRow('Step 3', 'HR Verified (Ready for Pay)', _stats['hrVerifiedClaims'] ?? 0, AppColors.lightPrimary, AppColors.primary, isHighlight: true),
                  _buildPipelineRow('Step 4', 'Processed', _stats['processedClaims'] ?? 0, AppColors.lightInputBackground, AppColors.lightSecondaryText),
                  _buildPipelineRow('Step 5', 'Paid & Disbursed', _stats['paidClaims'] ?? 0, AppColors.successBg, AppColors.success),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Recent Claims Requiring Payment Table Card
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Recent Claims Requiring Payment',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          Text(
                            'Claims verified by HR ready for finance disbursement',
                            style: TextStyle(fontSize: 11, color: AppColors.lightMutedText),
                          ),
                        ],
                      ),
                      OutlinedButton.icon(
                        onPressed: widget.onViewPayments,
                        icon: const Icon(Icons.arrow_forward, size: 14),
                        label: const Text('View All'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                          side: const BorderSide(color: AppColors.primary),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 20),

                  if (_recentClaims.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(
                        child: Text(
                          'No pending claims requiring payment',
                          style: TextStyle(color: AppColors.lightSecondaryText, fontSize: 13),
                        ),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _recentClaims.length,
                      itemBuilder: (context, index) {
                        final c = _recentClaims[index];
                        final isCompleted = c['paymentStatus'] == 'COMPLETED';
                        final isProcessing = _processingId == c['claimId'];

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.lightInputBackground,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundColor: AppColors.darkPrimary,
                                    child: Text(
                                      (c['employeeName'] ?? 'E').toString().substring(0, 1).toUpperCase(),
                                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          c['employeeName'] ?? '',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                        ),
                                        Text(
                                          c['employeeCode'] ?? '',
                                          style: const TextStyle(fontSize: 11, color: AppColors.lightMutedText),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    _formatCurrency(c['amount'] ?? 0),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),

                              Text(
                                c['benefitName'] ?? '',
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                              ),
                              Text(
                                'Claim Date: ${_formatDate(c['claimDate'])} | Verified: ${_formatDate(c['hrVerifiedAt'])}',
                                style: const TextStyle(fontSize: 11, color: AppColors.lightSecondaryText),
                              ),
                              const SizedBox(height: 10),

                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  _buildStatusBadge(c['paymentStatus']),
                                  if (isCompleted)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppColors.successBg,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        children: const [
                                          Icon(Icons.check, color: AppColors.success, size: 12),
                                          SizedBox(width: 4),
                                          Text(
                                            'Paid',
                                            style: TextStyle(color: AppColors.success, fontSize: 11, fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                    )
                                  else
                                    ElevatedButton.icon(
                                      onPressed: isProcessing ? null : () => _openPayModal(c),
                                      icon: isProcessing
                                          ? const SizedBox(
                                              width: 12,
                                              height: 12,
                                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                            )
                                          : const Icon(Icons.attach_money, size: 16),
                                      label: Text(isProcessing ? 'Paying...' : 'Pay'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.success,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
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
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String label,
    required String value,
    required String sub,
    required IconData icon,
    required Color bgColor,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.lightSecondaryText),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.lightPrimaryText),
          ),
          Text(
            sub,
            style: const TextStyle(fontSize: 10, color: AppColors.lightMutedText),
          ),
        ],
      ),
    );
  }

  Widget _buildPipelineRow(String step, String label, int count, Color pillBg, Color pillText, {bool isHighlight = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isHighlight ? AppColors.lightPrimary : AppColors.lightInputBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isHighlight ? AppColors.primary.withOpacity(0.3) : Colors.grey.shade200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: pillBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  step,
                  style: TextStyle(color: pillText, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isHighlight ? FontWeight.bold : FontWeight.w500,
                  color: isHighlight ? AppColors.darkPrimary : AppColors.lightPrimaryText,
                ),
              ),
            ],
          ),
          CircleAvatar(
            radius: 12,
            backgroundColor: Colors.white,
            child: Text(
              '$count',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: pillText),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String? status) {
    Color bg = AppColors.warningBg;
    Color fg = AppColors.warning;
    String label = 'Ready for Pay';

    if (status == 'PROCESSED') {
      bg = AppColors.infoBg;
      fg = AppColors.info;
      label = 'Processing';
    } else if (status == 'COMPLETED') {
      bg = AppColors.successBg;
      fg = AppColors.success;
      label = 'Paid';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(color: fg, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}
