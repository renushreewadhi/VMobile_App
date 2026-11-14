import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_header.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/empty_state_widget.dart';
import '../../shared/widgets/error_state_widget.dart';
import '../../shared/widgets/loading_shimmer.dart';

class FinanceBenefitReportsScreen extends ConsumerStatefulWidget {
  final bool? showAppBar;
  final VoidCallback? onViewDashboard;
  final VoidCallback? onViewPayments;

  const FinanceBenefitReportsScreen({
    super.key,
    this.showAppBar = false,
    this.onViewDashboard,
    this.onViewPayments,
  });

  @override
  ConsumerState<FinanceBenefitReportsScreen> createState() => _FinanceBenefitReportsScreenState();
}

class _FinanceBenefitReportsScreenState extends ConsumerState<FinanceBenefitReportsScreen> {
  String _searchTerm = '';
  String _selectedCategory = 'ALL'; // 'ALL', 'HEALTH_INSURANCE', 'TRAVEL', 'WELLNESS'
  bool _isLoading = true;
  String? _errorMessage;

  final List<Map<String, String>> _categories = [
    {'value': 'ALL', 'label': 'All Categories'},
    {'value': 'HEALTH_INSURANCE', 'label': 'Health Insurance'},
    {'value': 'TRAVEL', 'label': 'Travel'},
    {'value': 'WELLNESS', 'label': 'Wellness'},
  ];

  List<Map<String, dynamic>> _utilization = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadUtilization();
    });
  }

  Future<void> _loadUtilization() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    final apiClient = ref.read(apiClientProvider);

    try {
      final res = await apiClient.get(ApiEndpoints.benefitUtilization);

      if (mounted) {
        List<dynamic> items = [];
        if (res is List) {
          items = res;
        } else if (res is Map<String, dynamic>) {
          final data = res['data'] ?? res['items'] ?? res['result'] ?? res['utilization'];
          if (data is List) {
            items = data;
          }
        }

        _utilization = items.map((u) => _mapItem(u)).toList();
        _isLoading = false;
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _utilization = [];
          _errorMessage = e.toString().replaceFirst('Exception: ', '').replaceFirst('ApiException: ', '');
          _isLoading = false;
        });
      }
    }
  }

  Map<String, dynamic> _mapItem(dynamic u) {
    final Map<String, dynamic> map = u is Map<String, dynamic> ? u : {};
    return {
      'id': map['id']?.toString() ?? '1',
      'name': map['name'] ?? map['benefitName'] ?? 'Benefit Plan',
      'code': map['code'] ?? map['benefitCode'] ?? 'BEN-01',
      'category': map['category'] ?? 'HEALTH_INSURANCE',
      'status': map['status'] ?? 'PUBLISHED',
      'enrolledCount': (map['enrolledCount'] ?? 0) as int,
      'claimsCount': (map['claimsCount'] ?? 0) as int,
      'claimedAmount': (map['claimedAmount'] ?? 0) as num,
      'processedAmount': (map['processedAmount'] ?? 0) as num,
      'utilizationRate': (map['utilizationRate'] ?? 0) as int,
    };
  }

  List<Map<String, dynamic>> get _filteredData {
    return _utilization.where((u) {
      final name = (u['name'] ?? '').toString().toLowerCase();
      final code = (u['code'] ?? '').toString().toLowerCase();
      final search = _searchTerm.toLowerCase();

      final matchSearch = _searchTerm.isEmpty || name.contains(search) || code.contains(search);
      final matchCat = _selectedCategory == 'ALL' || u['category'] == _selectedCategory;

      return matchSearch && matchCat;
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
    final sum = _utilization.fold<int>(0, (s, u) => s + ((u['utilizationRate'] as int?) ?? 0));
    return (sum / _utilization.length).round();
  }

  int get _filteredAvgUtilization {
    final list = _filteredData;
    if (list.isEmpty) return 0;
    final sum = list.fold<int>(0, (s, u) => s + ((u['utilizationRate'] as int?) ?? 0));
    return (sum / list.length).round();
  }

  String _formatCurrency(num amount) {
    final str = amount.toInt().toString();
    final RegExp reg = RegExp(r'(\d+?)(?=(\d{3})+(?!\d))');
    final String result = str.replaceAllMapped(reg, (Match m) => '${m[1]},');
    return '₹$result';
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
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildUtilizationCard(Map<String, dynamic> item) {
    final status = item['status']?.toString() ?? 'PUBLISHED';
    final isPublished = status == 'PUBLISHED';
    final rate = (item['utilizationRate'] as int?) ?? 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.lightInputBackground,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    item['code'] ?? '',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.primary),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isPublished ? AppColors.successBg : AppColors.warningBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(color: isPublished ? AppColors.success : AppColors.warning, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              item['name'] ?? '',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 2),
            Text(
              'Category: ${item['category']}',
              style: const TextStyle(fontSize: 11, color: AppColors.lightSecondaryText),
            ),
            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.lightInputBackground,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildMetricColumn('Claimed', _formatCurrency(item['claimedAmount'] ?? 0), AppColors.primary),
                  _buildMetricColumn('Disbursed', _formatCurrency(item['processedAmount'] ?? 0), AppColors.success),
                  _buildMetricColumn('Enrolled', '${item['enrolledCount'] ?? 0} Emps', Colors.black87),
                ],
              ),
            ),
            const SizedBox(height: 12),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Utilization Rate: $rate%',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.lightPrimaryText),
                ),
                Text(
                  'Claims Count: ${item['claimsCount'] ?? 0}',
                  style: const TextStyle(fontSize: 11, color: AppColors.lightMutedText),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: rate / 100.0,
                minHeight: 6,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(rate > 50 ? AppColors.success : AppColors.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricColumn(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: AppColors.lightSecondaryText), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const DashboardSkeleton();
    if (_errorMessage != null) {
      return ErrorStateWidget(
        errorMessage: _errorMessage!,
        onRetry: _loadUtilization,
      );
    }

    final filteredList = _filteredData;
    final bool showHeader = widget.showAppBar ?? false;

    final content = DefaultTabController(
      length: 2,
      child: Column(
        children: [
          // Tab Header Bar
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            decoration: BoxDecoration(
              color: AppColors.lightSecondarySurface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: TabBar(
              labelColor: Colors.white,
              unselectedLabelColor: AppColors.lightSecondaryText,
              indicator: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              padding: const EdgeInsets.all(4),
              tabs: const [
                Tab(text: 'Overview'),
                Tab(text: 'Utilization Ledger'),
              ],
            ),
          ),

          // Tab Views
          Expanded(
            child: TabBarView(
              children: [
                // Tab 1: Overview
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                                        'Benefit Cost & Utilization Reports',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        'Financial analysis of employee benefit plan usage, coverage, and budget allocations.',
                                        style: TextStyle(color: Colors.white70, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
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
                                  label: const Text('Print Report'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    side: const BorderSide(color: Colors.white54),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

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
                    ],
                  ),
                ),

                // Tab 2: Utilization Ledger
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                                        'Avg Util: ',
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
                            final item = filteredList[index];
                            return _buildUtilizationCard(item);
                          },
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (!showHeader) {
      return Material(color: Colors.transparent, child: content);
    }

    return GlassScaffold(
      appBar: const GlassHeader(title: 'Benefit Reports'),
      showBottomBar: false,
      body: content,
    );
  }
}
