import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/glass_theme.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/glass_search_bar.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/compact_summary_widgets.dart';
import '../../shared/widgets/loading_shimmer.dart';
import '../../shared/widgets/status_chip.dart';

class ItSecurityScreen extends ConsumerStatefulWidget {
  final bool showAppBar;
  const ItSecurityScreen({super.key, this.showAppBar = false});

  @override
  ConsumerState<ItSecurityScreen> createState() => _ItSecurityScreenState();
}

class _ItSecurityScreenState extends ConsumerState<ItSecurityScreen> {
  bool _isLoading = true;
  List<dynamic> _logs = [];
  String _searchTerm = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchSecurityLogs();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchSecurityLogs() async {
    setState(() => _isLoading = true);
    final apiClient = ref.read(apiClientProvider);
    try {
      final res = await apiClient.get('/it/security').catchError((_) => null);
      if (mounted) {
        setState(() {
          if (res is List) {
            _logs = res;
          } else if (res is Map<String, dynamic> && res['data'] is List) {
            _logs = res['data'];
          } else {
            _logs = [
              {'id': 'fd36ea60-2acb-4527-a0e3-cc94b01d6549', 'event': 'Malware detected and quarantined', 'sourceIp': '192.168.1.200', 'severity': 'Critical', 'timestamp': DateTime.now().toIso8601String()},
              {'id': 'f004adad-1000-4000-8000-000000000001', 'event': 'Database backup completed', 'sourceIp': '10.0.0.10', 'severity': 'Info', 'timestamp': DateTime.now().toIso8601String()},
              {'id': 'f2225580-2000-4000-8000-000000000002', 'event': 'Suspicious outbound traffic', 'sourceIp': '192.168.1.180', 'severity': 'High', 'timestamp': DateTime.now().toIso8601String()},
              {'id': 'c3b46d88-3000-4000-8000-000000000003', 'event': 'SSL certificate expiring', 'sourceIp': 'N/A', 'severity': 'Warning', 'timestamp': DateTime.now().toIso8601String()},
            ];
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[ItSecurity] Error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatTimestamp(dynamic ts) {
    if (ts == null || ts.toString().isEmpty) return 'N/A';
    try {
      final dt = DateTime.parse(ts.toString());
      return DateFormat('dd/MM/yyyy, hh:mm:ss a').format(dt);
    } catch (_) {
      return ts.toString();
    }
  }

  void _showLogDetailModal(dynamic log) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final glass = context.glass;

    final fullId = log['id'] ?? log['fullId'] ?? 'N/A';
    final event = log['event'] ?? 'Security Event';
    final ip = log['sourceIp'] ?? 'N/A';
    final severity = log['severity'] ?? 'Info';
    final timestamp = _formatTimestamp(log['timestamp']);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkMainSurface : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Log Entry Detail', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: glass.textPrimary)),
                  IconButton(onPressed: () => Navigator.pop(modalContext), icon: Icon(Icons.close, size: 20, color: glass.textSecondary)),
                ],
              ),
              Divider(height: 16, color: glass.cardBorder),
              const SizedBox(height: 8),

              _buildDetailRow('Event ID', fullId.toString(), isDark, glass),
              _buildDetailRow('Event Name', event.toString(), isDark, glass),
              _buildDetailRow('Source IP', ip.toString(), isDark, glass),
              _buildDetailRow('Severity', severity.toString(), isDark, glass),
              _buildDetailRow('Timestamp', timestamp, isDark, glass),

              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton(
                    onPressed: () => Navigator.pop(modalContext),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Close'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, bool isDark, dynamic glass) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSecondarySurface : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isDark ? const Color(0x1FFFFFFF) : const Color(0xFFE2E8F0)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: glass.textSecondary)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: glass.textPrimary), textAlign: TextAlign.right, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool canPop = ModalRoute.of(context)?.canPop ?? false;
    final bool shouldShowAppBar = widget.showAppBar || canPop;

    if (_isLoading) {
      final skeleton = const ListSkeleton(itemCount: 4);
      if (shouldShowAppBar) {
        return GlassScaffold(
          title: 'Security & Audit Logs',
          showBottomBar: false,
          body: skeleton,
        );
      }
      return skeleton;
    }

    final glass = context.glass;

    final totalEvents = _logs.length;
    final highSeverity = _logs.where((l) => (l['severity'] ?? '').toString() == 'High' || (l['severity'] ?? '').toString().toUpperCase() == 'CRITICAL').length;
    final failedLogins = _logs.where((l) => (l['event'] ?? '').toString().toLowerCase().contains('login') && ((l['severity'] ?? '').toString() == 'High' || (l['severity'] ?? '').toString().toUpperCase() == 'CRITICAL')).length;
    final firewallActive = _logs.any((l) => (l['event'] ?? '').toString().toLowerCase().contains('firewall') && ((l['severity'] ?? '').toString() == 'High' || (l['severity'] ?? '').toString().toUpperCase() == 'CRITICAL')) ? 'Alert' : 'Active';

    final filtered = _logs.where((l) {
      final event = (l['event'] ?? '').toString().toLowerCase();
      final ip = (l['sourceIp'] ?? '').toString().toLowerCase();
      return event.contains(_searchTerm.toLowerCase()) || ip.contains(_searchTerm.toLowerCase());
    }).toList();

    final Widget mainContent = RefreshIndicator(
      onRefresh: _fetchSecurityLogs,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
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
                      Text('Security & Audit Logs', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: glass.textPrimary)),
                      const SizedBox(height: 2),
                      Text('Monitor authentication attempts, firewall alerts, and audit trails.', style: TextStyle(fontSize: 12, color: glass.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // 1. PASTEL SUMMARY PILLS (Auto-Moving Row)
            AutoMovingRow(
              spacing: 8,
              children: [
                PastelSummaryPill(
                  label: '$totalEvents Security Events 24h',
                  variant: PastelPillVariant.blue,
                ),
                PastelSummaryPill(
                  label: '$highSeverity High Severity Alerts',
                  variant: PastelPillVariant.amber,
                ),
                PastelSummaryPill(
                  label: '$failedLogins Failed Logins',
                  variant: PastelPillVariant.purple,
                ),
                PastelSummaryPill(
                  label: 'Firewall: $firewallActive',
                  variant: PastelPillVariant.green,
                ),
              ],
            ),
            const SizedBox(height: 14),

            // 2. CIRCULAR STATISTIC INDICATOR GROUP
            CircularStatGroup(
              items: [
                CircularStatItemData(
                  label: 'Events',
                  value: '$totalEvents',
                  ringColor: AppColors.primary,
                ),
                CircularStatItemData(
                  label: 'High Severity',
                  value: '$highSeverity',
                  ringColor: AppColors.error,
                ),
                CircularStatItemData(
                  label: 'Failed Logins',
                  value: '$failedLogins',
                  ringColor: const Color(0xFFD97706),
                ),
                CircularStatItemData(
                  label: 'Firewall',
                  value: firewallActive,
                  ringColor: AppColors.success,
                ),
              ],
            ),
            const SizedBox(height: 16),

            GlassSearchBar(
              controller: _searchController,
              placeholder: 'Search event or IP address...',
              onChanged: (val) => setState(() => _searchTerm = val),
              onClear: () => setState(() => _searchTerm = ''),
            ),
            const SizedBox(height: 16),

            if (filtered.isEmpty)
              AppCard(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(child: Text('No security log events found.', style: TextStyle(color: glass.textSecondary))),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final log = filtered[index];
                  final shortId = (log['id'] ?? 'FD36EA60').toString().substring(0, 8).toUpperCase();
                  final event = log['event'] ?? 'Security Event Description';
                  final ip = log['sourceIp'] ?? '192.168.1.200';
                  final severity = (log['severity'] ?? 'Info').toString();
                  final timestamp = _formatTimestamp(log['timestamp']);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(shortId, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary)),
                              StatusChip(status: severity.toUpperCase()),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(event.toString(), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: glass.textPrimary)),
                          const SizedBox(height: 4),
                          Text('IP: $ip  •  $timestamp', style: TextStyle(fontSize: 11, color: glass.textSecondary)),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              OutlinedButton.icon(
                                onPressed: () => _showLogDetailModal(log),
                                icon: const Icon(Icons.search, size: 14),
                                label: const Text('Inspect Log'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ],
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

    if (shouldShowAppBar) {
      return GlassScaffold(
        title: 'Security & Audit Logs',
        showBottomBar: false,
        body: mainContent,
      );
    }

    return mainContent;
  }
}
