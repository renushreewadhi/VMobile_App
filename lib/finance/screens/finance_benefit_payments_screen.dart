import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_header.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/loading_shimmer.dart';

class FinanceBenefitPaymentsScreen extends ConsumerStatefulWidget {
  final bool? showAppBar;
  final VoidCallback? onViewDashboard;
  final VoidCallback? onViewClaims;
  final VoidCallback? onViewReports;

  const FinanceBenefitPaymentsScreen({
    super.key,
    this.showAppBar = false,
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadClaims();
    });
  }

  Future<void> _loadClaims() async {
    setState(() => _isLoading = true);
    final apiClient = ref.read(apiClientProvider);

    try {
      final res = await apiClient.get(ApiEndpoints.benefitClaimsForPayment).catchError((_) => null);

      if (mounted) {
        if (res != null) {
          List<dynamic> items = [];
          if (res is List) {
            items = res;
          } else if (res is Map<String, dynamic>) {
            final data = res['data'] ?? res['items'] ?? res['result'] ?? res['payments'];
            if (data is List) {
              items = data;
            }
          }

          _claims = items.map((c) => Map<String, dynamic>.from(c)).toList();
        } else {
          _claims = [];
        }
        _isLoading = false;
        setState(() {});
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _claims = [];
          _isLoading = false;
        });
      }
    }
  }

  String _formatCurrency(num amount) {
    final str = amount.toInt().toString();
    final RegExp reg = RegExp(r'(\d+?)(?=(\d{3})+(?!\d))');
    final String result = str.replaceAllMapped(reg, (Match m) => '${m[1]},');
    return '₹$result';
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty || dateStr.startsWith('0001')) return '-';
    try {
      final dt = DateTime.parse(dateStr);
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${dt.day.toString().padLeft(2, '0')} ${months[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return dateStr;
    }
  }

  List<Map<String, dynamic>> get _filteredClaims {
    return _claims.where((c) {
      final empName = (c['employeeName'] ?? c['empName'] ?? '').toString().toLowerCase();
      final benName = (c['benefitName'] ?? c['benefit'] ?? '').toString().toLowerCase();
      final empCode = (c['employeeCode'] ?? c['empCode'] ?? '').toString().toLowerCase();
      final search = _searchTerm.toLowerCase();

      final matchSearch = _searchTerm.isEmpty || empName.contains(search) || benName.contains(search) || empCode.contains(search);

      final status = (c['paymentStatus'] ?? c['status'] ?? '').toString().toUpperCase();
      bool matchTab = true;
      if (_selectedTab == 'processing') {
        matchTab = status == 'PENDING' || status == 'PROCESSED';
      } else if (_selectedTab == 'paid') {
        matchTab = status == 'COMPLETED' || status == 'PAID';
      }

      return matchSearch && matchTab;
    }).toList();
  }

  num get _totalDisbursed {
    return _claims
        .where((c) {
          final s = (c['paymentStatus'] ?? c['status'] ?? '').toString().toUpperCase();
          return s == 'COMPLETED' || s == 'PAID';
        })
        .fold<num>(0, (sum, c) => sum + ((c['amount'] as num?) ?? 0));
  }

  int get _paidCount => _claims.where((c) {
        final s = (c['paymentStatus'] ?? c['status'] ?? '').toString().toUpperCase();
        return s == 'COMPLETED' || s == 'PAID';
      }).length;

  int get _processingCount => _claims.where((c) {
        final s = (c['paymentStatus'] ?? c['status'] ?? '').toString().toUpperCase();
        return s == 'PENDING' || s == 'PROCESSED';
      }).length;

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
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildTabChip(String label, String value, int count) {
    final isActive = _selectedTab == value;
    return Material(
      color: Colors.transparent,
      child: ChoiceChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isActive ? Colors.white : AppColors.lightSecondaryText,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '($count)',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isActive ? Colors.white70 : AppColors.lightMutedText,
              ),
            ),
          ],
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

  Widget _buildClaimCard(Map<String, dynamic> claim) {
    final status = (claim['paymentStatus'] ?? claim['status'] ?? '').toString().toUpperCase();
    final isPaid = status == 'COMPLETED' || status == 'PAID';

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
                    (claim['employeeName'] ?? 'E').toString().substring(0, 1).toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        claim['employeeName'] ?? '',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      Text(
                        claim['employeeCode'] ?? '',
                        style: const TextStyle(fontSize: 11, color: AppColors.lightMutedText),
                      ),
                    ],
                  ),
                ),
                Text(
                  _formatCurrency(claim['amount'] ?? 0),
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
              claim['benefitName'] ?? '',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 2),
            Text(
              'Claim Date: ${_formatDate(claim['claimDate'])} | Verified By: ${claim['hrReviewerName'] ?? '-'}',
              style: const TextStyle(fontSize: 11, color: AppColors.lightSecondaryText),
            ),
            const Divider(height: 18),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isPaid ? AppColors.successBg : AppColors.warningBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isPaid ? 'Paid' : 'Processing',
                    style: TextStyle(color: isPaid ? AppColors.success : AppColors.warning, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
                if (isPaid)
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
                          'Disbursed',
                          style: TextStyle(color: AppColors.success, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const DashboardSkeleton();

    final filteredList = _filteredClaims;
    final bool showHeader = widget.showAppBar ?? false;

    final content = RefreshIndicator(
      onRefresh: _loadClaims,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Header Card
            AppCard(
              backgroundColor: AppColors.darkPrimary,
              child: Row(
                children: const [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.white24,
                    child: Icon(Icons.payment, color: Colors.white, size: 26),
                  ),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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
                          'Track all processed and settled benefit claim payments.',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
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
                  value: '$_processingCount',
                  sub: 'Payment in progress',
                  icon: Icons.settings,
                  bgColor: const Color(0xFFFFF7ED),
                  iconColor: const Color(0xFFEA580C),
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
                  icon: Icons.receipt_long,
                  bgColor: const Color(0xFFEFF6FF),
                  iconColor: const Color(0xFF2563EB),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Search & Tab Filter Bar
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
                        _buildTabChip('All', 'all', _claims.length),
                        const SizedBox(width: 8),
                        _buildTabChip('Processing', 'processing', _processingCount),
                        const SizedBox(width: 8),
                        _buildTabChip('Paid', 'paid', _paidCount),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            if (filteredList.isEmpty)
              AppCard(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: const [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: AppColors.lightSecondarySurface,
                        child: Icon(Icons.receipt_long_outlined, size: 28, color: AppColors.lightSecondaryText),
                      ),
                      SizedBox(height: 12),
                      Text(
                        'No payment history found',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Try clearing or modifying your search and status filter.',
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
                  final claim = filteredList[index];
                  return _buildClaimCard(claim);
                },
              ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );

    if (!showHeader) {
      return Material(color: Colors.transparent, child: content);
    }

    return GlassScaffold(
      appBar: const GlassHeader(title: 'Benefit Payments'),
      showBottomBar: false,
      body: content,
    );
  }
}
