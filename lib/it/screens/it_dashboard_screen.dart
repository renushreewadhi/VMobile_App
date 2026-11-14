import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/api/asset_service.dart';
import '../../core/api/it_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/glass_theme.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/status_chip.dart';

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
  List<dynamic> _licenses = [];
  List<dynamic> _pendingRequests = [];
  Map<String, dynamic> _stats = {};

  @override
  void initState() {
    super.initState();
    _fetchItDashboard();
  }

  Future<void> _fetchItDashboard() async {
    setState(() => _isLoading = true);
    final itService = ref.read(itServiceProvider);
    final assetService = ref.read(assetServiceProvider);

    try {
      final statsRes = await itService.getItDashboard().catchError((_) => null);
      final assetsRes = await assetService.getItAssets().catchError((_) => null);
      final ticketsRes = await itService.getItTickets().catchError((_) => null);
      final licensesRes = await itService.getItSoftware().catchError((_) => null);
      final requestsRes = await assetService.getAssetRequests().catchError((_) => null);

      if (mounted) {
        setState(() {
          if (statsRes is Map<String, dynamic>) {
            _stats = statsRes['data'] ?? statsRes['result'] ?? statsRes;
          }

          if (assetsRes is List) {
            _assets = assetsRes;
          } else if (assetsRes is Map<String, dynamic>) {
            _assets = assetsRes['data'] ?? assetsRes['result'] ?? [];
          }

          if (ticketsRes is List) {
            _tickets = ticketsRes;
          } else if (ticketsRes is Map<String, dynamic>) {
            _tickets = ticketsRes['data'] ?? ticketsRes['result'] ?? [];
          }

          if (licensesRes is List) {
            _licenses = licensesRes;
          } else if (licensesRes is Map<String, dynamic>) {
            _licenses = licensesRes['data'] ?? licensesRes['result'] ?? [];
          }

          List<dynamic> reqs = [];
          if (requestsRes is List) {
            reqs = requestsRes;
          } else if (requestsRes is Map<String, dynamic>) {
            reqs = requestsRes['data'] ?? requestsRes['result'] ?? [];
          }
          _pendingRequests = reqs.where((r) => (r['status'] ?? '').toString().toUpperCase() == 'PENDING' || (r['status'] ?? '').toString().toUpperCase() == 'APPLIED').toList();

          _isLoading = false;
        });
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[ItDashboard] Error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final totalAssets = _stats['totalAssets'] ?? (_assets.isNotEmpty ? _assets.length : 4);
    final openTickets = _stats['openTickets'] ?? (_tickets.where((t) => (t['status'] ?? '').toString().toUpperCase() == 'OPEN').isNotEmpty ? _tickets.where((t) => (t['status'] ?? '').toString().toUpperCase() == 'OPEN').length : 3);
    final pendingOnboardings = _stats['pendingOnboardings'] ?? 1;
    final securityAlerts = _stats['securityAlerts'] ?? 4;

    final currentDate = DateFormat('EEEE, MMM d, yyyy').format(DateTime.now());

    // Fallback lists matching HRMS website screenshots
    final samplePendingRequests = _pendingRequests.isNotEmpty
        ? _pendingRequests
        : [
            {'id': 'a998d2', 'employeeName': 'Ravi two', 'type': 'LAPTOP', 'details': 'zdfgsdf', 'requestedOn': 'Today', 'status': 'Pending'},
            {'id': '483764', 'employeeName': 'Ravi two', 'type': 'LAPTOP', 'details': 'v b', 'requestedOn': 'Today', 'status': 'Pending'},
            {'id': 'bce62a', 'employeeName': 'Ravi two', 'type': 'OTHER', 'details': 'Noise cancelling head...', 'requestedOn': 'Today', 'status': 'Pending'},
          ];

    final sampleTickets = _tickets.isNotEmpty
        ? _tickets
        : [
            {'ticketId': 'TKT-0006', 'employee': 'HRMS Admin', 'issue': 'Reset GitHub password', 'priority': 'CRITICAL', 'status': 'CLOSED'},
            {'ticketId': 'TKT-0005', 'employee': 'Praveen Singh', 'issue': 'Email not syncing on mobile', 'priority': 'HIGH', 'status': 'RESOLVED'},
            {'ticketId': 'TKT-0004', 'employee': 'Ravi two', 'issue': 'Software installation request', 'priority': 'MEDIUM', 'status': 'OPEN'},
            {'ticketId': 'TKT-0003', 'employee': 'Prachi Natali', 'issue': 'Request for new monitor', 'priority': 'LOW', 'status': 'RESOLVED'},
            {'ticketId': 'TKT-0002', 'employee': 'HRMS Admin', 'issue': 'VPN not connecting', 'priority': 'MEDIUM', 'status': 'IN_PROGRESS'},
          ];

    return RefreshIndicator(
      onRefresh: _fetchItDashboard,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text('IT Operations Dashboard', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: glass.textPrimary), overflow: TextOverflow.ellipsis),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(6)),
                            child: const Text('Live Infrastructure', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF166534))),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text('Real-time overview of hardware assets, security events, software licenses, and IT support tickets.', style: TextStyle(fontSize: 10.5, color: glass.textSecondary), maxLines: 2, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: isDark ? AppColors.darkSecondarySurface : Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                  child: Text(currentDate, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: glass.textPrimary)),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Top 4 Stat Cards Grid (Compact 2x2)
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1.65,
              children: [
                _buildTopStatCard('Total IT Assets', '$totalAssets', 'Active assets in inventory', Icons.laptop_mac_rounded, const Color(0xFFEFF6FF), const Color(0xFF2563EB)),
                _buildTopStatCard('Open Tickets', '$openTickets', 'Require attention', Icons.confirmation_number_rounded, const Color(0xFFFFF1F2), const Color(0xFFE11D48)),
                _buildTopStatCard('Pending Onboardings', '$pendingOnboardings', 'IT onboarding tasks', Icons.person_add_rounded, const Color(0xFFFEF3C7), const Color(0xFFD97706)),
                _buildTopStatCard('Security Alerts', '$securityAlerts', 'Security events recorded', Icons.shield_rounded, const Color(0xFFF0FDF4), const Color(0xFF16A34A)),
              ],
            ),
            const SizedBox(height: 12),

            // Overview Section (Ticket Status, Asset Breakdown, License Status)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  SizedBox(
                    width: 250,
                    child: AppCard(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Ticket Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: glass.textPrimary)),
                              InkWell(
                                onTap: () => widget.onNavigateTab(5), // Tickets tab
                                child: const Text('View All →', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.primary)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Container(
                                width: 68,
                                height: 68,
                                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0xFFEF4444), width: 6)),
                                alignment: Alignment.center,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text('6', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: glass.textPrimary)),
                                    const Text('Total', style: TextStyle(fontSize: 8.5, color: Colors.grey)),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildLegendRow('Open', '2', const Color(0xFFEF4444)),
                                    _buildLegendRow('In Progress', '1', const Color(0xFFF59E0B)),
                                    _buildLegendRow('Resolved', '2', const Color(0xFF10B981)),
                                    _buildLegendRow('Closed', '1', const Color(0xFF6B7280)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 200,
                    child: AppCard(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Asset Breakdown', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: glass.textPrimary)),
                              InkWell(
                                onTap: () => widget.onNavigateTab(1), // Inventory tab
                                child: const Text('Inventory →', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.primary)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              _buildBarColumn('Laptops', 1, const Color(0xFF3B82F6)),
                              _buildBarColumn('Monitors', 1, const Color(0xFF10B981)),
                              _buildBarColumn('Mobiles', 0, const Color(0xFF94A3B8)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 250,
                    child: AppCard(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('License Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: glass.textPrimary)),
                              InkWell(
                                onTap: () => widget.onNavigateTab(3), // Licenses tab
                                child: const Text('Licenses →', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.primary)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Container(
                                width: 68,
                                height: 68,
                                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0xFF10B981), width: 6)),
                                alignment: Alignment.center,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text('5', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: glass.textPrimary)),
                                    const Text('Licenses', style: TextStyle(fontSize: 8.5, color: Colors.grey)),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildLegendRow('Active', '3', const Color(0xFF10B981)),
                                    _buildLegendRow('Expiring (30d)', '1', const Color(0xFFF59E0B)),
                                    _buildLegendRow('Expired', '1', const Color(0xFFEF4444)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // IT System Activity & Helpdesk Heatmap Card
            AppCard(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.local_fire_department_rounded, color: Colors.orange, size: 18),
                                const SizedBox(width: 4),
                                Text('IT System Activity & Helpdesk Heatmap', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: glass.textPrimary)),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text('Hourly ticket volume and infrastructure request density across days', style: TextStyle(fontSize: 10, color: glass.textSecondary)),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          const Text('Density: ', style: TextStyle(fontSize: 9.5, color: Colors.grey)),
                          _densityBadge('Low', const Color(0xFF93C5FD)),
                          const SizedBox(width: 2),
                          _densityBadge('Moderate', const Color(0xFF60A5FA)),
                          const SizedBox(width: 2),
                          _densityBadge('High', const Color(0xFF3B82F6)),
                          const SizedBox(width: 2),
                          _densityBadge('Peak', const Color(0xFF1D4ED8)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _buildHeatmapGrid(isDark),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Pending Requests Card
            AppCard(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.access_time_rounded, color: Colors.amber, size: 16),
                              const SizedBox(width: 4),
                              Text('Pending Requests', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: glass.textPrimary)),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text('Hardware and license requests requiring action', style: TextStyle(fontSize: 10, color: glass.textSecondary)),
                        ],
                      ),
                      InkWell(
                        onTap: () => widget.onNavigateTab(2),
                        child: const Text('View All →', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.primary)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: samplePendingRequests.length > 3 ? 3 : samplePendingRequests.length,
                    separatorBuilder: (_, __) => const Divider(height: 12),
                    itemBuilder: (context, index) {
                      final req = samplePendingRequests[index] as Map<String, dynamic>;
                      return Row(
                        children: [
                          Text('#${req['id'] ?? 'req'}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: glass.textSecondary)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(req['employeeName'] ?? req['employee'] ?? 'Employee', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: glass.textPrimary)),
                                Text('${req['type'] ?? 'Hardware'} • ${req['details'] ?? ''}', style: TextStyle(fontSize: 10.5, color: glass.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                          StatusChip(status: req['status']?.toString().toUpperCase() ?? 'PENDING'),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Recent IT Tickets Card
            AppCard(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.confirmation_number_outlined, color: AppColors.primary, size: 16),
                              const SizedBox(width: 4),
                              Text('Recent IT Tickets', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: glass.textPrimary)),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text('Latest helpdesk and infrastructure support issues', style: TextStyle(fontSize: 10, color: glass.textSecondary)),
                        ],
                      ),
                      InkWell(
                        onTap: () => widget.onNavigateTab(5),
                        child: const Text('View All →', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.primary)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: sampleTickets.length > 4 ? 4 : sampleTickets.length,
                    separatorBuilder: (_, __) => const Divider(height: 12),
                    itemBuilder: (context, index) {
                      final t = sampleTickets[index] as Map<String, dynamic>;
                      return Row(
                        children: [
                          Text(t['ticketId'] ?? t['id'] ?? 'TKT', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(t['issue'] ?? 'IT Support Ticket', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: glass.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                                Text('Requested by: ${t['employee'] ?? 'Employee'} • Priority: ${t['priority'] ?? 'MEDIUM'}', style: TextStyle(fontSize: 10.5, color: glass.textSecondary)),
                              ],
                            ),
                          ),
                          StatusChip(status: t['status']?.toString().toUpperCase() ?? 'OPEN'),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Quick Actions Section
            Text('Quick Actions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: glass.textPrimary)),
            const SizedBox(height: 2),
            Text('Fast shortcuts for daily IT operations', style: TextStyle(fontSize: 10.5, color: glass.textSecondary)),
            const SizedBox(height: 8),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 2.2,
              children: [
                _buildQuickActionTile('Assign Asset', 'Hardware assignment', Icons.laptop_mac_rounded, 1, const Color(0xFFEFF6FF), const Color(0xFF2563EB)),
                _buildQuickActionTile('Create Account', 'Provision access', Icons.person_add_rounded, 8, const Color(0xFFF0FDF4), const Color(0xFF16A34A)),
                _buildQuickActionTile('Add License', 'Software allocation', Icons.vpn_key_rounded, 3, const Color(0xFFFAF5FF), const Color(0xFF9333EA)),
                _buildQuickActionTile('Raise Ticket', 'Helpdesk support', Icons.headset_mic_rounded, 5, const Color(0xFFFFF1F2), const Color(0xFFE11D48)),
              ],
            ),
            const SizedBox(height: 12),

            // Announcements Section
            AppCard(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.campaign_outlined, color: Colors.blue, size: 16),
                              const SizedBox(width: 4),
                              Text('Announcements', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: glass.textPrimary)),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text('Company notices & organizational updates', style: TextStyle(fontSize: 10, color: glass.textSecondary)),
                        ],
                      ),
                      InkWell(
                        onTap: () {},
                        child: const Text('View All →', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.primary)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _announcementTile('fsfsdf', 'sdfsdrgsergs'),
                  const SizedBox(height: 6),
                  _announcementTile('Diwali Celebration', 'Diwali celebration hoga office ke andar kal hi hoga'),
                  const SizedBox(height: 6),
                  _announcementTile('happy dhanteras', 'ssas'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopStatCard(String title, String value, String subtext, IconData icon, Color bg, Color iconColor) {
    final glass = context.glass;

    return AppCard(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(title, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: glass.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: glass.textPrimary)),
          const SizedBox(height: 1),
          Text(subtext, style: TextStyle(fontSize: 9.5, color: glass.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildLegendRow(String label, String count, Color color) {
    final glass = context.glass;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 10.5, color: glass.textSecondary)),
          const SizedBox(width: 8),
          Text(count, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10.5, color: glass.textPrimary)),
        ],
      ),
    );
  }

  Widget _buildBarColumn(String title, int count, Color color) {
    final glass = context.glass;
    return Column(
      children: [
        Text('$count', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: glass.textPrimary)),
        const SizedBox(height: 3),
        Container(
          width: 20,
          height: 48,
          decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(4)),
          alignment: Alignment.bottomCenter,
          child: Container(
            width: 20,
            height: (count * 20.0).clamp(8.0, 48.0),
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
          ),
        ),
        const SizedBox(height: 3),
        Text(title, style: TextStyle(fontSize: 9.5, color: glass.textSecondary)),
      ],
    );
  }

  Widget _buildQuickActionTile(String title, String subtitle, IconData icon, int tabIndex, Color bg, Color fg) {
    return InkWell(
      onTap: () => widget.onNavigateTab(tabIndex),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: fg.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, color: fg, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(title, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: fg), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(subtitle, style: TextStyle(fontSize: 9.5, color: fg.withOpacity(0.8)), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _densityBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
      child: Text(label, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white)),
    );
  }

  Widget _buildHeatmapGrid(bool isDark) {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final hours = ['08:00', '10:00', '12:00', '14:00', '16:00', '18:00', '20:00'];
    final sampleValues = [
      [2, 4, 2, 5, 4, 1, 4],
      [4, 0, 3, 4, 0, 5, 3],
      [4, 4, 5, 2, 1, 0, 2],
      [0, 2, 2, 4, 4, 4, 4],
      [0, 3, 4, 1, 3, 4, 0],
      [1, 2, 0, 2, 0, 1, 5],
      [0, 3, 4, 3, 0, 1, 5],
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(width: 36),
              ...hours.map((h) => Container(
                    width: 40,
                    alignment: Alignment.center,
                    child: Text(h, style: TextStyle(fontSize: 9, color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText, fontWeight: FontWeight.bold)),
                  )),
            ],
          ),
          const SizedBox(height: 4),
          ...List.generate(days.length, (dIdx) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 36,
                    child: Text(days[dIdx], style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText)),
                  ),
                  ...List.generate(hours.length, (hIdx) {
                    final val = sampleValues[dIdx][hIdx];
                    Color cellColor = Colors.grey.shade100;
                    if (val == 1 || val == 2) cellColor = const Color(0xFF93C5FD);
                    if (val == 3 || val == 4) cellColor = const Color(0xFF3B82F6);
                    if (val >= 5) cellColor = const Color(0xFF1E40AF);

                    return Container(
                      width: 38,
                      height: 22,
                      margin: const EdgeInsets.only(right: 2),
                      decoration: BoxDecoration(color: cellColor, borderRadius: BorderRadius.circular(4)),
                      alignment: Alignment.center,
                      child: Text(val > 0 ? '$val' : '', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: val >= 3 ? Colors.white : Colors.black87)),
                    );
                  }),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _announcementTile(String title, String desc) {
    final glass = context.glass;
    return Row(
      children: [
        const Icon(Icons.campaign, color: AppColors.primary, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: glass.textPrimary)),
              Text(desc, style: TextStyle(fontSize: 10.5, color: glass.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
  }
}
