import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/loading_shimmer.dart';

class FinanceBenefitReportsScreen extends ConsumerStatefulWidget {
  final VoidCallback? onViewDashboard;
  final VoidCallback? onViewPayments;

  const FinanceBenefitReportsScreen({
    super.key,
    this.onViewDashboard,
    this.onViewPayments,
  });

  @override
  ConsumerState<FinanceBenefitReportsScreen> createState() => _FinanceBenefitReportsScreenState();
}

class _FinanceBenefitReportsScreenState extends ConsumerState<FinanceBenefitReportsScreen> {
  String _searchTerm = '';
  String _selectedCategory = 'ALL';
  bool _isLoading = true;

  final List<Map<String, String>> _categories = [
    {'value': 'ALL', 'label': 'All Categories'},
    {'value': 'HEALTH_INSURANCE', 'label': 'Health Insurance'},
    {'value': 'LIFE_INSURANCE', 'label': 'Life Insurance'},
    {'value': 'WELLNESS', 'label': 'Wellness'},
    {'value': 'MEAL', 'label': 'Meal'},
    {'value': 'TRAVEL', 'label': 'Travel'},
    {'value': 'OTHER', 'label': 'Other'},
  ];

  List<Map<String, dynamic>> _utilization = [];

  @override
  void initState() {
    super.initState();
    _loadUtilization();
  }

  Future<void> _loadUtilization() async {
    setState(() => _isLoading = true);
    final apiClient = ref.read(apiClientProvider);

    try {
      final res = await apiClient.get(ApiEndpoints.benefitUtilization).catchError((_) => null);

      if (mounted) {
        List<dynamic> items = [];
        if (res is List) {
          items = res;
        } else if (res is Map<String, dynamic> && res['data'] is List) {
          items = res['data'];
        }

        if (items.isNotEmpty) {
          _utilization = items.map((u) => Map<String, dynamic>.from(u)).toList();
        } else {
          _utilization = _getMockUtilization();
        }
        _isLoading = false;
        setState(() {});
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _utilization = _getMockUtilization();
          _isLoading = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> _getMockUtilization() {
    return [
      {
        'id': '1',
        'name': 'Executive Health & OPD Policy',
        'code': 'BEN-HLT-01',
        'category': 'HEALTH_INSURANCE',
        'status': 'PUBLISHED',
        'enrolledCount': 142,
        'claimsCount': 38,
        'claimedAmount': 950000,
        'processedAmount': 820000,
        'utilizationRate': 68,
      },
      {
        'id': '2',
        'name': 'Term Life & Disability Cover',
        'code': 'BEN-LIF-02',
        'category': 'LIFE_INSURANCE',
        'status': 'PUBLISHED',
        'enrolledCount': 210,
        'claimsCount': 4,
        'claimedAmount': 1200000,
        'processedAmount': 1200000,
        'utilizationRate': 40,
      },
      {
        'id': '3',
        'name': 'Annual Gym & Wellness Stipend',
        'code': 'BEN-WLN-02',
        'category': 'WELLNESS',
        'status': 'PUBLISHED',
        'enrolledCount': 95,
        'claimsCount': 62,
        'claimedAmount': 310000,
        'processedAmount': 280000,
        'utilizationRate': 82,
      },
      {
        'id': '4',
        'name': 'Executive Dining & Meal Allowance',
        'code': 'BEN-MEL-01',
        'category': 'MEAL',
        'status': 'PUBLISHED',
        'enrolledCount': 180,
        'claimsCount': 145,
        'claimedAmount': 540000,
        'processedAmount': 540000,
        'utilizationRate': 90,
      },
      {
        'id': '5',
        'name': 'Corporate Travel & Commute Pass',
        'code': 'BEN-TRV-03',
        'category': 'TRAVEL',
        'status': 'DRAFT',
        'enrolledCount': 0,
        'claimsCount': 0,
        'claimedAmount': 0,
        'processedAmount': 0,
        'utilizationRate': 0,
      },
    ];
  }

  List<Map<String, dynamic>> get _filteredData {
    return _utilization.where((u) {
      final name = (u['name'] ?? '').toString().toLowerCase();
      final code = (u['code'] ?? '').toString().toLowerCase();
      final search = _searchTerm.toLowerCase();

      final matchSearch = _searchTerm.isEmpty || name.contains(search) || code.contains(search);
      final matchCategory = _selectedCategory == 'ALL' || u['category'] == _selectedCategory;

      return matchSearch && matchCategory;
    }).toList();
  }

  num get _totalClaimed {
    return _utilization.fold<num>(0, (sum, u) => sum + ((u['claimedAmount'] as num?) ?? 0));
  }

  num get _totalProcessed {
    return _utilization.fold<num>(0, (sum, u) => sum + ((u['processedAmount'] as num?) ?? 0));
  }

  int get _avgUtilization {
    if (_utilization.isEmpty) return 0;
    final total = _utilization.fold<num>(0, (sum, u) => sum + ((u['utilizationRate'] as num?) ?? 0));
    return (total / _utilization.length).round();
  }

  int get _filteredAvgUtilization {
    final filtered = _filteredData;
    if (filtered.isEmpty) return 0;
    final total = filtered.fold<num>(0, (sum, u) => sum + ((u['utilizationRate'] as num?) ?? 0));
    return (total / filtered.length).round();
  }

  Color _getUtilizationColor(int rate) {
    if (rate >= 75) return const Color(0xFFDC2626); // High -> Red
    if (rate >= 50) return const Color(0xFFD97706); // Moderate -> Amber
    return const Color(0xFF16A34A); // Normal -> Green
  }

  String _formatCurrency(num amount) {
    final str = amount.toInt().toString();
    final RegExp reg = RegExp(r'(\d+?)(?=(\d{3})+(?!\d))');
    final String result = str.replaceAllMapped(reg, (Match m) => '${m[1]},');
    return '₹$result';
  }

  String _formatCategoryLabel(String cat) {
    final found = _categories.firstWhere((c) => c['value'] == cat, orElse: () => {'label': cat});
    return found['label']!;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const DashboardSkeleton();

    final filteredList = _filteredData;

    return RefreshIndicator(
      onRefresh: _loadUtilization,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Header Banner Card
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
                        child: Icon(Icons.pie_chart, color: Colors.white, size: 26),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Benefit Cost & Reports',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Analysis of benefit plan usage & budget allocations',
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
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Generating PDF cost & utilization report...'),
                                backgroundColor: AppColors.primary,
                              ),
                            );
                          },
                          icon: const Icon(Icons.print_outlined, size: 16),
                          label: const Text('Print / Export'),
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
                  label: 'Total Claimed Amount',
                  value: _formatCurrency(_totalClaimed),
                  sub: 'Submitted benefit claims',
                  icon: Icons.receipt,
                  bgColor: const Color(0xFFEFF6FF),
                  iconColor: const Color(0xFF2563EB),
                ),
                _buildStatCard(
                  label: 'Total Processed',
                  value: _formatCurrency(_totalProcessed),
                  sub: 'Disbursed to employees',
                  icon: Icons.done_all,
                  bgColor: const Color(0xFFF0FDF4),
                  iconColor: const Color(0xFF16A34A),
                ),
                _buildStatCard(
                  label: 'Avg Utilization Rate',
                  value: '$_avgUtilization%',
                  sub: 'Of coverage amount used',
                  icon: Icons.trending_up,
                  bgColor: const Color(0xFFFFF7ED),
                  iconColor: const Color(0xFFEA580C),
                ),
                _buildStatCard(
                  label: 'Total Benefit Plans',
                  value: '${_utilization.length}',
                  sub: 'Active & draft plans',
                  icon: Icons.security,
                  bgColor: const Color(0xFFEFF6FF),
                  iconColor: const Color(0xFF2563EB),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Filters & Search Card
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    onChanged: (val) => setState(() => _searchTerm = val),
                    decoration: InputDecoration(
                      hintText: 'Search by plan name or code...',
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

                  Row(
                    children: [
                      const Icon(Icons.category_outlined, size: 18, color: AppColors.lightSecondaryText),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(10),
                            color: Colors.white,
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedCategory,
                              isExpanded: true,
                              icon: const Icon(Icons.arrow_drop_down, color: AppColors.primary),
                              style: const TextStyle(fontSize: 13, color: AppColors.lightPrimaryText, fontWeight: FontWeight.w500),
                              items: _categories.map((cat) {
                                return DropdownMenuItem<String>(
                                  value: cat['value'],
                                  child: Text(cat['label']!),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) setState(() => _selectedCategory = val);
                              },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.lightPrimary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Text(
                              'Avg Utilization: ',
                              style: TextStyle(fontSize: 11, color: AppColors.lightSecondaryText, fontWeight: FontWeight.w600),
                            ),
                            Text(
                              '$_filteredAvgUtilization%',
                              style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Benefit Utilization Analysis List Header & Cards
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: const [
                    Icon(Icons.analytics_outlined, color: AppColors.primary, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Plan Cost & Utilization Breakdown',
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
                    '${filteredList.length} Plans',
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
                        child: Icon(Icons.find_in_page_outlined, size: 28, color: AppColors.lightSecondaryText),
                      ),
                      SizedBox(height: 12),
                      Text(
                        'No benefit report data found',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Try clearing or modifying your search and filter parameters.',
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
                  final u = filteredList[index];
                  return _buildReportCard(u);
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

  Widget _buildReportCard(Map<String, dynamic> u) {
    final rate = (u['utilizationRate'] as int?) ?? 0;
    final rateColor = _getUtilizationColor(rate);
    final isPublished = u['status'] == 'PUBLISHED';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Code, Category & Status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.lightInputBackground,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Text(
                        u['code'] ?? '',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          color: AppColors.lightSecondaryText,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.lightInputBackground,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _formatCategoryLabel(u['category'] ?? ''),
                        style: const TextStyle(fontSize: 10, color: AppColors.lightSecondaryText, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: isPublished ? AppColors.successBg : AppColors.warningBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    u['status'] ?? 'DRAFT',
                    style: TextStyle(
                      color: isPublished ? AppColors.success : AppColors.warning,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Plan Name
            Text(
              u['name'] ?? '',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 10),

            // Metrics Grid: Enrolled, Claims, Claimed Amt, Disbursed Amt
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.lightInputBackground,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        const Text('Enrolled', style: TextStyle(fontSize: 10, color: AppColors.lightMutedText)),
                        const SizedBox(height: 2),
                        Text('${u['enrolledCount'] ?? 0}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                  ),
                  Container(height: 20, width: 1, color: Colors.grey.shade300),
                  Expanded(
                    child: Column(
                      children: [
                        const Text('Claims', style: TextStyle(fontSize: 10, color: AppColors.lightMutedText)),
                        const SizedBox(height: 2),
                        Text('${u['claimsCount'] ?? 0}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                  ),
                  Container(height: 20, width: 1, color: Colors.grey.shade300),
                  Expanded(
                    child: Column(
                      children: [
                        const Text('Claimed', style: TextStyle(fontSize: 10, color: AppColors.lightMutedText)),
                        const SizedBox(height: 2),
                        Text(_formatCurrency(u['claimedAmount'] ?? 0), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ],
                    ),
                  ),
                  Container(height: 20, width: 1, color: Colors.grey.shade300),
                  Expanded(
                    child: Column(
                      children: [
                        const Text('Disbursed', style: TextStyle(fontSize: 10, color: AppColors.lightMutedText)),
                        const SizedBox(height: 2),
                        Text(_formatCurrency(u['processedAmount'] ?? 0), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.success)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Utilization Progress Bar
            Row(
              children: [
                const Text(
                  'Utilization Rate:',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.lightSecondaryText),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: rate / 100,
                      minHeight: 6,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(rateColor),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$rate%',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: rateColor),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
