import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/compact_summary_widgets.dart';
import '../../shared/widgets/loading_shimmer.dart';

class ItDashboardScreen extends ConsumerStatefulWidget {
  final Function(int) onNavigateTab;

  const ItDashboardScreen({super.key, required this.onNavigateTab});

  @override
  ConsumerState<ItDashboardScreen> createState() => _ItDashboardScreenState();
}

class _ItDashboardScreenState extends ConsumerState<ItDashboardScreen> {
  bool _isLoading = true;
  List<dynamic> _assets = [];
  List<dynamic> _tickets = [];
  List<dynamic> _pendingRequests = [];
  Map<String, dynamic> _stats = {};

  @override
  void initState() {
    super.initState();
    _fetchItDashboard();
  }

  Future<void> _fetchItDashboard() async {
    setState(() => _isLoading = true);
    final apiClient = ref.read(apiClientProvider);

    try {
      final statsRes = await apiClient.get(ApiEndpoints.itDashboard).catchError((_) => null);
      final assetsRes = await apiClient.get(ApiEndpoints.itAssets).catchError((_) => null);
      final ticketsRes = await apiClient.get(ApiEndpoints.itTickets).catchError((_) => null);
      final requestsRes = await apiClient.get(ApiEndpoints.assetRequests).catchError((_) => null);

      if (mounted) {
        setState(() {
          if (statsRes is Map<String, dynamic>) {
            _stats = statsRes;
          }
          if (assetsRes is List) {
            _assets = assetsRes;
          } else if (assetsRes is Map<String, dynamic> && assetsRes['data'] is List) {
            _assets = assetsRes['data'];
          }

          if (ticketsRes is List) {
            _tickets = ticketsRes;
          } else if (ticketsRes is Map<String, dynamic> && ticketsRes['data'] is List) {
            _tickets = ticketsRes['data'];
          }

          if (requestsRes is List) {
            _pendingRequests = requestsRes.where((r) => r['status'] == 'PENDING' || r['status'] == 'APPLIED').toList();
          } else if (requestsRes is Map<String, dynamic> && requestsRes['data'] is List) {
            _pendingRequests = (requestsRes['data'] as List).where((r) => r['status'] == 'PENDING' || r['status'] == 'APPLIED').toList();
          }

          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const DashboardSkeleton();

    final totalAssets = _stats['totalAssets'] ?? _assets.length;
    final openTickets = _stats['openTickets'] ?? _tickets.where((t) => t['status'] == 'OPEN').length;
    final pendingOnboardings = _stats['pendingOnboardings'] ?? 3;
    final pendingReqsCount = _pendingRequests.length;

    return RefreshIndicator(
      onRefresh: _fetchItDashboard,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. COMPACT STATUS BANNER
            CompactStatusBanner(
              title: 'IT Operations Hub',
              subtitle: 'Assets Managed: $totalAssets • Open Tickets: $openTickets',
              actionLabel: 'Asset Mgmt',
              icon: Icons.laptop_mac_rounded,
              onActionPressed: () => widget.onNavigateTab(1),
            ),
            const SizedBox(height: 12),

            // 2. PASTEL SUMMARY PILLS
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  PastelSummaryPill(
                    label: '$totalAssets Managed Assets',
                    variant: PastelPillVariant.green,
                    onTap: () => widget.onNavigateTab(1),
                  ),
                  const SizedBox(width: 8),
                  PastelSummaryPill(
                    label: '$openTickets Open IT Tickets',
                    variant: PastelPillVariant.purple,
                    onTap: () => widget.onNavigateTab(5),
                  ),
                  const SizedBox(width: 8),
                  PastelSummaryPill(
                    label: '$pendingReqsCount Pending Requests',
                    variant: PastelPillVariant.amber,
                    onTap: () => widget.onNavigateTab(2),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 3. CIRCULAR STATISTIC INDICATOR GROUP
            CircularStatGroup(
              items: [
                CircularStatItemData(
                  label: 'Assets',
                  value: '$totalAssets',
                  ringColor: AppColors.primary,
                  onTap: () => widget.onNavigateTab(1),
                ),
                CircularStatItemData(
                  label: 'Requests',
                  value: '$pendingReqsCount',
                  ringColor: const Color(0xFFD97706),
                  onTap: () => widget.onNavigateTab(2),
                ),
                CircularStatItemData(
                  label: 'Tickets',
                  value: '$openTickets',
                  ringColor: const Color(0xFF9333EA),
                  onTap: () => widget.onNavigateTab(5),
                ),
                CircularStatItemData(
                  label: 'Onboard',
                  value: '$pendingOnboardings',
                  ringColor: const Color(0xFF2563EB),
                  onTap: () => widget.onNavigateTab(6),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // 4. COMPACT INFO ROWS
            CompactInfoRowTile(
              label: 'Total Registered IT Assets',
              value: '$totalAssets Items',
              dotColor: AppColors.success,
              icon: Icons.chevron_right_rounded,
              onTap: () => widget.onNavigateTab(1),
            ),
            const SizedBox(height: 8),
            CompactInfoRowTile(
              label: 'Open Support Tickets Queue',
              value: '$openTickets Tickets',
              dotColor: const Color(0xFF9333EA),
              icon: Icons.chevron_right_rounded,
              onTap: () => widget.onNavigateTab(5),
            ),
            const SizedBox(height: 18),

            const Text('IT Navigation Shortcuts', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 10),

            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.1,
              children: [
                _buildQuickActionCard('Assets', Icons.laptop_mac_rounded, 1, Colors.blue),
                _buildQuickActionCard('Requests', Icons.assignment_turned_in_rounded, 2, Colors.orange),
                _buildQuickActionCard('Software', Icons.grid_view_rounded, 3, Colors.purple),
                _buildQuickActionCard('Access', Icons.security_rounded, 4, Colors.teal),
                _buildQuickActionCard('Tickets', Icons.confirmation_number_rounded, 5, Colors.red),
                _buildQuickActionCard('Onboard', Icons.person_add_rounded, 6, Colors.indigo),
              ],
            ),
            const SizedBox(height: 18),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Pending Asset Requests', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                TextButton(
                  onPressed: () => widget.onNavigateTab(2),
                  child: const Text('View All', style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 8),

            if (_pendingRequests.isEmpty)
              const AppCard(
                child: Padding(
                  padding: EdgeInsets.all(14),
                  child: Center(child: Text('No pending asset requests')),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _pendingRequests.length > 3 ? 3 : _pendingRequests.length,
                itemBuilder: (context, index) {
                  final req = _pendingRequests[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: AppCard(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          const Icon(Icons.devices_rounded, color: AppColors.primary, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(req['employeeName'] ?? 'Employee', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                Text('Category: ${req['assetType'] ?? req['category'] ?? 'Hardware'}', style: const TextStyle(fontSize: 11, color: AppColors.lightMutedText)),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.warningBg,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('PENDING', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.warning)),
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

  Widget _buildQuickActionCard(String label, IconData icon, int tabIndex, MaterialColor color) {
    return InkWell(
      onTap: () => widget.onNavigateTab(tabIndex),
      borderRadius: BorderRadius.circular(12),
      child: AppCard(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
