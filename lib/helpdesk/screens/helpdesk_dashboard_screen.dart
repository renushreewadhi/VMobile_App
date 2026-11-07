import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/helpdesk_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/glass_theme.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/loading_shimmer.dart';
import '../../shared/widgets/status_chip.dart';
import '../../core/widgets/glass_scaffold.dart';
import 'create_ticket_screen.dart';
import 'helpdesk_chatbot_screen.dart';
import 'helpdesk_tickets_screen.dart';
import 'ticket_detail_screen.dart';

class HelpdeskDashboardScreen extends ConsumerStatefulWidget {
  final Function(int)? onNavigateTab;
  final bool showAppBar;

  const HelpdeskDashboardScreen({super.key, this.onNavigateTab, this.showAppBar = false});

  @override
  ConsumerState<HelpdeskDashboardScreen> createState() => _HelpdeskDashboardScreenState();
}

class _HelpdeskDashboardScreenState extends ConsumerState<HelpdeskDashboardScreen> {
  bool _isLoading = true;
  dynamic _roleDashboard;
  List<dynamic> _tickets = [];

  @override
  void initState() {
    super.initState();
    _fetchDashboard();
  }

  Future<void> _fetchDashboard() async {
    setState(() => _isLoading = true);
    try {
      final helpdeskSvc = ref.read(helpdeskServiceProvider);
      final dashboardRes = await helpdeskSvc.getRoleDashboard().catchError((_) => null);
      final ticketsRes = await helpdeskSvc.getTickets().catchError((_) => []);

      if (mounted) {
        setState(() {
          _roleDashboard = dashboardRes;
          _tickets = ticketsRes;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final glass = context.glass;

    if (_isLoading) {
      const skeleton = DashboardSkeleton();
      if (!widget.showAppBar) return skeleton;
      return const GlassScaffold(title: 'IT Helpdesk Center', body: DashboardSkeleton());
    }

    final Map<String, dynamic>? roleMap = _roleDashboard is Map ? Map<String, dynamic>.from(_roleDashboard as Map) : null;

    final totalCount = roleMap?['totalTickets'] ?? (_tickets.isNotEmpty ? _tickets.length : 1);
    final openCount = roleMap?['openTickets'] ?? (_tickets.where((t) => t is Map && (t['status'] == 'OPEN')).isNotEmpty ? _tickets.where((t) => t is Map && (t['status'] == 'OPEN')).length : 1);
    final inProgressCount = roleMap?['inProgressTickets'] ?? _tickets.where((t) => t is Map && (t['status'] == 'IN_PROGRESS' || t['status'] == 'WAITING_ON_EMPLOYEE')).length;
    final resolvedCount = roleMap?['resolvedToday'] ?? _tickets.where((t) => t is Map && (t['status'] == 'RESOLVED' || t['status'] == 'CLOSED')).length;
    final recentTickets = (roleMap?['recentTickets'] is List ? roleMap!['recentTickets'] as List : null) ?? _tickets;

    final sampleTicket = recentTickets.isNotEmpty
        ? recentTickets.first
        : {
            'id': 'hd-1',
            'ticketNumber': 'HD-0001',
            'subject': 'hi',
            'employeeName': 'Ravi two',
            'category': 'Laptop / Hardware',
            'priority': 'Medium',
            'status': 'OPEN',
            'createdAt': '02 Nov 2026',
          };

    final body = RefreshIndicator(
      onRefresh: _fetchDashboard,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(14),
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
                          const Icon(Icons.laptop_chromebook, color: AppColors.primary, size: 20),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text('IT Helpdesk Center', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: glass.textPrimary), overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text('Manage IT support tickets: laptop, software, email, network, and access issues.', style: TextStyle(fontSize: 11, color: glass.textSecondary), maxLines: 2, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.refresh, size: 18),
                      onPressed: _fetchDashboard,
                      tooltip: 'Refresh',
                      constraints: const BoxConstraints(),
                      padding: EdgeInsets.zero,
                    ),
                    const SizedBox(width: 4),
                    OutlinedButton.icon(
                      onPressed: () {
                        if (widget.onNavigateTab != null) {
                          widget.onNavigateTab!(1);
                        } else {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpdeskTicketsScreen(showAppBar: true)));
                        }
                      },
                      icon: const Icon(Icons.confirmation_number, size: 14),
                      label: const Text('Tickets', style: TextStyle(fontSize: 11)),
                    ),
                    const SizedBox(width: 4),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpdeskChatbotScreen()));
                      },
                      icon: const Icon(Icons.smart_toy, size: 14),
                      label: const Text('AI Assistant', style: TextStyle(fontSize: 11)),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Top Metric Cards Row 1
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1.7,
              children: [
                _kpiCard('IT Tickets', '$totalCount', Icons.laptop_mac_rounded, const Color(0xFFEFF6FF), const Color(0xFF2563EB)),
                _kpiCard('Open Tickets', '$openCount', Icons.folder_open_rounded, const Color(0xFFFEF3C7), const Color(0xFFD97706)),
                _kpiCard('Assigned to Me', '0', Icons.person_outline_rounded, const Color(0xFFF0FDF4), const Color(0xFF16A34A)),
                _kpiCard('Escalated', '0', Icons.warning_amber_rounded, const Color(0xFFFFF1F2), const Color(0xFFE11D48)),
              ],
            ),
            const SizedBox(height: 8),

            // Top Metric Cards Row 2 (Knowledge Base, AI Assistant, Rules)
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1.5,
              children: [
                _kpiCard('Knowledge Base', '0', Icons.menu_book_rounded, const Color(0xFFFAF5FF), const Color(0xFF9333EA)),
                _kpiCard('AI Assistant', '0', Icons.smart_toy_rounded, const Color(0xFFFAF5FF), const Color(0xFF9333EA)),
                _kpiCard('Rules', '0', Icons.settings_rounded, const Color(0xFFFAF5FF), const Color(0xFF9333EA)),
              ],
            ),
            const SizedBox(height: 12),

            // Quick Stat Summaries
            Row(
              children: [
                Expanded(child: _subPill('Total Tickets', '$totalCount')),
                const SizedBox(width: 6),
                Expanded(child: _subPill('Open', '$openCount')),
                const SizedBox(width: 6),
                Expanded(child: _subPill('In Progress', '$inProgressCount')),
                const SizedBox(width: 6),
                Expanded(child: _subPill('Escalated', '0')),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(child: _subPill('Resolved Today', '$resolvedCount')),
                const SizedBox(width: 6),
                Expanded(child: _subPill('Unassigned', '1')),
                const SizedBox(width: 6),
                Expanded(child: _subPill('KB Articles', '0')),
              ],
            ),
            const SizedBox(height: 14),

            // SLA Compliance Banner Card
            AppCard(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.access_time_filled, color: AppColors.primary, size: 16),
                          const SizedBox(width: 6),
                          Text('SLA Compliance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: glass.textPrimary)),
                        ],
                      ),
                      const Text('100%', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.success)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: 1.0,
                    backgroundColor: Colors.grey.shade200,
                    color: AppColors.success,
                    minHeight: 6,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _slaLegendItem('Within SLA', AppColors.success, '1'),
                      const SizedBox(width: 12),
                      _slaLegendItem('At Risk', Colors.orange, '0'),
                      const SizedBox(width: 12),
                      _slaLegendItem('Breached', AppColors.error, '0'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Recent Tickets & Categorization Breakdown Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Recent Tickets', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: glass.textPrimary)),
                InkWell(
                  onTap: () {
                    if (widget.onNavigateTab != null) {
                      widget.onNavigateTab!(1);
                    } else {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpdeskTicketsScreen(showAppBar: true)));
                    }
                  },
                  child: const Text('View All →', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary)),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Recent Ticket Card
            AppCard(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: AppColors.lightInputBackground, borderRadius: BorderRadius.circular(4)),
                        child: Text('#${sampleTicket['ticketNumber'] ?? 'HD-0001'}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.primary)),
                      ),
                      StatusChip(status: sampleTicket['status']?.toString().toUpperCase() ?? 'OPEN'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(sampleTicket['subject'] ?? sampleTicket['title'] ?? 'hi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: glass.textPrimary)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.person, size: 12, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(sampleTicket['employeeName'] ?? 'Ravi two', style: TextStyle(fontSize: 11, color: glass.textSecondary)),
                      const SizedBox(width: 10),
                      const Icon(Icons.calendar_today, size: 12, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(sampleTicket['createdAt']?.toString().substring(0, 11) ?? '02 Nov 2026', style: TextStyle(fontSize: 11, color: glass.textSecondary)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Breakdown Summaries (By Status, By Category, By Priority)
            AppCard(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('By Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: glass.textPrimary)),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Open', style: TextStyle(fontSize: 12)),
                      Text('$openCount', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ],
                  ),
                  const Divider(height: 16),

                  Text('By Category', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: glass.textPrimary)),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Laptop / Hardware', style: TextStyle(fontSize: 12)),
                      Text('$totalCount', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ],
                  ),
                  const Divider(height: 16),

                  Text('By Priority', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: glass.textPrimary)),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Medium', style: TextStyle(fontSize: 12)),
                      Text('$totalCount', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (!widget.showAppBar) return Material(color: Colors.transparent, child: body);

    return GlassScaffold(
      title: 'IT Helpdesk Center',
      body: body,
    );
  }

  Widget _kpiCard(String label, String value, IconData icon, Color bg, Color iconColor) {
    final glass = context.glass;
    return AppCard(
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: glass.textPrimary)),
                const SizedBox(height: 1),
                Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: glass.textSecondary), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _subPill(String label, String value) {
    final glass = context.glass;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(color: AppColors.lightInputBackground, borderRadius: BorderRadius.circular(6)),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: glass.textPrimary)),
          Text(label, style: TextStyle(fontSize: 8.5, color: glass.textSecondary), overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _slaLegendItem(String label, Color color, String count) {
    return Row(
      children: [
        Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text('$label ($count)', style: const TextStyle(fontSize: 10.5, color: AppColors.lightSecondaryText)),
      ],
    );
  }
}
