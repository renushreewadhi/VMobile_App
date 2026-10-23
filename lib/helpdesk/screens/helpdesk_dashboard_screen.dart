import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/helpdesk_service.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/compact_summary_widgets.dart';
import '../../shared/widgets/loading_shimmer.dart';
import 'create_ticket_screen.dart';
import 'helpdesk_chatbot_screen.dart';
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
    if (_isLoading) {
      final skeleton = const DashboardSkeleton();
      if (!widget.showAppBar) return skeleton;
      return Scaffold(
        appBar: AppBar(title: const Text('Helpdesk')),
        body: skeleton,
      );
    }

    final totalCount = _roleDashboard?['totalTickets'] ?? _tickets.length;
    final openCount = _roleDashboard?['openTickets'] ?? _tickets.where((t) => t['status'] == 'OPEN').length;
    final inProgressCount = _roleDashboard?['inProgressTickets'] ?? _tickets.where((t) => t['status'] == 'IN_PROGRESS' || t['status'] == 'WAITING_ON_EMPLOYEE').length;
    final resolvedCount = _roleDashboard?['resolvedToday'] ?? _tickets.where((t) => t['status'] == 'RESOLVED' || t['status'] == 'CLOSED').length;
    final recentTickets = _roleDashboard?['recentTickets'] ?? _tickets;

    final body = RefreshIndicator(
      onRefresh: _fetchDashboard,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. COMPACT STATUS BANNER
            CompactStatusBanner(
              title: 'Helpdesk & AI Support',
              subtitle: 'Open Tickets: $openCount • In Progress: $inProgressCount',
              actionLabel: 'Raise Ticket',
              icon: Icons.headset_mic_rounded,
              onActionPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateTicketScreen()))
                    .then((_) => _fetchDashboard());
              },
            ),
            const SizedBox(height: 12),

            // 2. PASTEL SUMMARY PILLS
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  PastelSummaryPill(
                    label: '$openCount Open Tickets',
                    variant: PastelPillVariant.amber,
                    onTap: () => widget.onNavigateTab?.call(1),
                  ),
                  const SizedBox(width: 8),
                  PastelSummaryPill(
                    label: '$inProgressCount In Progress',
                    variant: PastelPillVariant.purple,
                    onTap: () => widget.onNavigateTab?.call(1),
                  ),
                  const SizedBox(width: 8),
                  PastelSummaryPill(
                    label: '$resolvedCount Resolved Today',
                    variant: PastelPillVariant.green,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 3. CIRCULAR STATISTIC INDICATOR GROUP
            CircularStatGroup(
              items: [
                CircularStatItemData(
                  label: 'Total',
                  value: '$totalCount',
                  ringColor: AppColors.primary,
                  onTap: () => widget.onNavigateTab?.call(1),
                ),
                CircularStatItemData(
                  label: 'Open',
                  value: '$openCount',
                  ringColor: const Color(0xFFD97706),
                  onTap: () => widget.onNavigateTab?.call(1),
                ),
                CircularStatItemData(
                  label: 'In Prog',
                  value: '$inProgressCount',
                  ringColor: const Color(0xFF9333EA),
                  onTap: () => widget.onNavigateTab?.call(1),
                ),
                CircularStatItemData(
                  label: 'Resolved',
                  value: '$resolvedCount',
                  ringColor: AppColors.success,
                ),
              ],
            ),
            const SizedBox(height: 14),

            // 4. COMPACT INFO ROWS
            CompactInfoRowTile(
              label: 'Open Support Tickets',
              value: '$openCount Open',
              dotColor: const Color(0xFFD97706),
              icon: Icons.chevron_right_rounded,
              onTap: () => widget.onNavigateTab?.call(1),
            ),
            const SizedBox(height: 8),
            CompactInfoRowTile(
              label: 'Support AI Chatbot Assistant',
              value: 'Available 24/7',
              dotColor: AppColors.primary,
              icon: Icons.chevron_right_rounded,
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpdeskChatbotScreen()));
              },
            ),
            const SizedBox(height: 18),

            const Text('Support Shortcuts & AI Assistant', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: AppCard(
                    onTap: () => widget.onNavigateTab?.call(1),
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: const [
                        Icon(Icons.confirmation_number_rounded, color: AppColors.primary, size: 18),
                        SizedBox(width: 8),
                        Text('My Tickets', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AppCard(
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpdeskChatbotScreen()));
                    },
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: const [
                        Icon(Icons.smart_toy_rounded, color: Colors.purple, size: 18),
                        SizedBox(width: 8),
                        Text('AI Chatbot', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            const Text('Recent Support Tickets', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 10),

            if (recentTickets.isEmpty)
              const AppCard(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: Text('No recent support tickets found.')),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: recentTickets.length > 4 ? 4 : recentTickets.length,
                itemBuilder: (context, index) {
                  final t = recentTickets[index];
                  final id = t['id']?.toString() ?? '';
                  final ticketNumber = t['ticketNumber'] ?? 'TICKET';
                  final title = t['subject'] ?? 'Untitled';
                  final status = t['status'] ?? 'OPEN';

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: AppCard(
                      padding: const EdgeInsets.all(12),
                      onTap: () {
                        if (id.isNotEmpty) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => TicketDetailScreen(ticketId: id)),
                          ).then((_) => _fetchDashboard());
                        }
                      },
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(ticketNumber, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: AppColors.primary)),
                                const SizedBox(height: 2),
                                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.warningBg,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(status, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.warning)),
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

    if (!widget.showAppBar) return body;

    return Scaffold(
      appBar: AppBar(title: const Text('Helpdesk')),
      body: body,
    );
  }
}
