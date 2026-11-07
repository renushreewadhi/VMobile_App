import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/loading_shimmer.dart';

class FinanceBenefitPaymentsScreen extends ConsumerStatefulWidget {
  final VoidCallback? onViewDashboard;
  final VoidCallback? onViewClaims;
  final VoidCallback? onViewReports;

  const FinanceBenefitPaymentsScreen({
    super.key,
    this.onViewDashboard,
    this.onViewClaims,
    this.onViewReports,
  });

  @override
  ConsumerState<FinanceBenefitPaymentsScreen> createState() => _FinanceBenefitPaymentsScreenState();
}

class _FinanceBenefitPaymentsScreenState extends ConsumerState<FinanceBenefitPaymentsScreen> {
  String _searchTerm = '';
  String _selectedTab = 'all'; // 'processed', 'paid', 'all'
  bool _isLoading = true;

  List<Map<String, dynamic>> _claims = [];

  @override
  void initState() {
    super.initState();
    _loadClaims();
  }

  Future<void> _loadClaims() async {
    setState(() => _isLoading = true);
    final apiClient = ref.read(apiClientProvider);

    try {
      final res = await apiClient.get(ApiEndpoints.benefitPaymentHistory).catchError((_) => null);

      if (mounted) {
        List<dynamic> items = [];
        if (res is List) {
          items = res;
        } else if (res is Map<String, dynamic> && res['data'] is List) {
          items = res['data'];
        }

        if (items.isNotEmpty) {
          _claims = items.map((c) => Map<String, dynamic>.from(c)).toList();
        } else {
          _claims = _getMockClaims();
        }
        _isLoading = false;
        setState(() {});
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _claims = _getMockClaims();
          _isLoading = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> _getMockClaims() {
    return [
      {
        'claimId': 'CLM-2026-801',
        'paymentId': 'PAY-89012',
        'employeeName': 'Sarah Jenkins',
        'employeeCode': 'EMP-1042',
        'benefitName': 'Executive Health Checkup & Dental',
        'benefitCode': 'BEN-HLT-01',
        'amount': 25000,
        'claimDate': '2026-10-10',
        'hrReviewerName': 'Marcus Vance',
        'paymentStatus': 'PROCESSED',
      },
      {
        'claimId': 'CLM-2026-802',
        'paymentId': 'PAY-89015',
        'employeeName': 'Rajesh Sharma',
        'employeeCode': 'EMP-1088',
        'benefitName': 'Child Higher Education Allowance',
        'benefitCode': 'BEN-EDU-03',
        'amount': 45000,
        'claimDate': '2026-10-08',
        'hrReviewerName': 'Marcus Vance',
        'paymentStatus': 'COMPLETED',
      },
      {
        'claimId': 'CLM-2026-803',
        'paymentId': 'PAY-89018',
        'employeeName': 'Anita Roy',
        'employeeCode': 'EMP-1102',
        'benefitName': 'Gym & Wellness Membership Stipend',
        'benefitCode': 'BEN-WLN-02',
        'amount': 12000,
        'claimDate': '2026-10-05',
        'hrReviewerName': 'Helen Carter',
        'paymentStatus': 'PROCESSED',
      },
      {
        'claimId': 'CLM-2026-804',
        'paymentId': 'PAY-88992',
        'employeeName': 'Michael Chen',
        'employeeCode': 'EMP-1015',
        'benefitName': 'Home Office Ergonomic Setup',
        'benefitCode': 'BEN-WFH-05',
        'amount': 30000,
        'claimDate': '2026-10-01',
        'hrReviewerName': 'Helen Carter',
        'paymentStatus': 'COMPLETED',
      },
      {
        'claimId': 'CLM-2026-805',
        'paymentId': 'PAY-88950',
        'employeeName': 'David Miller',
        'employeeCode': 'EMP-1022',
        'benefitName': 'Professional Certification Reimbursement',
        'benefitCode': 'BEN-LRN-04',
        'amount': 18500,
        'claimDate': '2026-09-28',
        'hrReviewerName': 'Marcus Vance',
        'paymentStatus': 'COMPLETED',
      },
    ];
  }

  int get _processedCount => _claims.where((c) => c['paymentStatus'] == 'PROCESSED').length;
  int get _paidCount => _claims.where((c) => c['paymentStatus'] == 'COMPLETED').length;
  num get _totalDisbursed {
    return _claims
        .where((c) => c['paymentStatus'] == 'COMPLETED')
        .fold<num>(0, (sum, c) => sum + ((c['amount'] as num?) ?? 0));
  }

  List<Map<String, dynamic>> get _filteredClaims {
    return _claims.where((c) {
      final statusStr = (c['paymentStatus'] == 'COMPLETED') ? 'paid' : 'processed';
      final matchTab = _selectedTab == 'all' || _selectedTab == statusStr;

      final empName = (c['employeeName'] ?? '').toString().toLowerCase();
      final benName = (c['benefitName'] ?? '').toString().toLowerCase();
      final empCode = (c['employeeCode'] ?? '').toString().toLowerCase();
      final search = _searchTerm.toLowerCase();

      final matchSearch = _searchTerm.isEmpty ||
          empName.contains(search) ||
          benName.contains(search) ||
          empCode.contains(search);

      return matchTab && matchSearch;
    }).toList();
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const DashboardSkeleton();

    final filteredList = _filteredClaims;

    return RefreshIndicator(
      onRefresh: _loadClaims,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Banner Card
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
                        child: Icon(Icons.history_edu, color: Colors.white, size: 26),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Payment History',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Track all processed and settled benefit claim payments',
                              style: TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Header Quick Link Buttons
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: widget.onViewDashboard,
                          icon: const Icon(Icons.dashboard_outlined, size: 16),
                          label: const Text('Dashboard'),
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
                          onPressed: widget.onViewClaims,
                          icon: const Icon(Icons.receipt_long_outlined, size: 16),
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
                          icon: const Icon(Icons.pie_chart_outline, size: 16),
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
                  label: 'Processing',
                  value: '$_processedCount',
                  sub: 'Payment in progress',
                  icon: Icons.settings_suggest,
                  bgColor: const Color(0xFFEFF6FF),
                  iconColor: const Color(0xFF2563EB),
                ),
                _buildStatCard(
                  label: 'Paid Claims',
                  value: '$_paidCount',
                  sub: 'Successfully disbursed',
                  icon: Icons.check_circle_outline,
                  bgColor: const Color(0xFFF0FDF4),
                  iconColor: const Color(0xFF16A34A),
                ),
                _buildStatCard(
                  label: 'Total Disbursed',
                  value: _formatCurrency(_totalDisbursed),
                  sub: 'Settled amount',
                  icon: Icons.monetization_on_outlined,
                  bgColor: const Color(0xFFFEFCE8),
                  iconColor: const Color(0xFFCA8A04),
                ),
                _buildStatCard(
                  label: 'Total Claims',
                  value: '${_claims.length}',
                  sub: 'All processed/paid',
                  icon: Icons.description_outlined,
                  bgColor: const Color(0xFFEFF6FF),
                  iconColor: const Color(0xFF2563EB),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Filter & Search Controls Card
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    onChanged: (val) => setState(() => _searchTerm = val),
                    decoration: InputDecoration(
                      hintText: 'Search by employee or benefit...',
                      hintStyle: const TextStyle(fontSize: 13, color: AppColors.lightMutedText),
                      prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.lightSecondaryText),
                      filled: true,
                      fillColor: AppColors.lightInputBackground,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildTabChip('Processing', 'processed'),
                        const SizedBox(width: 8),
                        _buildTabChip('Paid', 'paid'),
                        const SizedBox(width: 8),
                        _buildTabChip('All', 'all'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Payment History List Header & Cards
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: const [
                    Icon(Icons.receipt_long, color: AppColors.primary, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Settled & Processing Claims',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.lightPrimary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${filteredList.length} Listed',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            if (filteredList.isEmpty)
              AppCard(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: const [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: AppColors.lightSecondarySurface,
                        child: Icon(Icons.search_off, size: 28, color: AppColors.lightSecondaryText),
                      ),
                      SizedBox(height: 12),
                      Text(
                        'No payment history found',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Try adjusting your search criteria or tab filters.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: AppColors.lightSecondaryText),
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredList.length,
                itemBuilder: (context, index) {
                  final c = filteredList[index];
                  return _buildPaymentCard(c);
                },
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

  Widget _buildTabChip(String label, String value) {
    final isActive = _selectedTab == value;
    return Material(
      color: Colors.transparent,
      child: ChoiceChip(
        label: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isActive ? Colors.white : AppColors.lightSecondaryText,
          ),
        ),
        selected: isActive,
        selectedColor: AppColors.primary,
        backgroundColor: AppColors.lightInputBackground,
        onSelected: (_) => setState(() => _selectedTab = value),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isActive ? AppColors.primary : Colors.grey.shade300,
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentCard(Map<String, dynamic> c) {
    final status = c['paymentStatus']?.toString() ?? 'PENDING';
    final isCompleted = status == 'COMPLETED';
    final isProcessed = status == 'PROCESSED';

    Color statusBg = AppColors.warningBg;
    Color statusFg = AppColors.warning;
    String statusLabel = 'Pending';

    if (isCompleted) {
      statusBg = AppColors.successBg;
      statusFg = AppColors.success;
      statusLabel = 'Paid';
    } else if (isProcessed) {
      statusBg = AppColors.infoBg;
      statusFg = AppColors.info;
      statusLabel = 'Processed';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.darkPrimary,
                  child: Text(
                    (c['employeeName'] ?? 'E').toString().substring(0, 1).toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c['employeeName'] ?? '',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
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
                    fontSize: 15,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            Text(
              c['benefitName'] ?? '',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 2),
            Text(
              'Claim Date: ${_formatDate(c['claimDate'])} | Verified By: ${c['hrReviewerName'] ?? '-'}',
              style: const TextStyle(fontSize: 11, color: AppColors.lightSecondaryText),
            ),
            const Divider(height: 18),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(color: statusFg, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
                if (c['paymentId'] != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.lightInputBackground,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Text(
                      'ID: ${c['paymentId']}',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        color: AppColors.lightSecondaryText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
