import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/auth/auth_service.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/compact_summary_widgets.dart';
import '../../shared/widgets/loading_shimmer.dart';
import 'tl_attendance_screen.dart';
import 'tl_expenses_screen.dart';
import 'tl_performance_screen.dart';
import 'tl_projects_screen.dart';
import 'tl_reports_screen.dart';
import 'tl_tasks_screen.dart';

class TlDashboardScreen extends ConsumerStatefulWidget {
  final Function(int) onNavigateTab;

  const TlDashboardScreen({super.key, required this.onNavigateTab});

  @override
  ConsumerState<TlDashboardScreen> createState() => _TlDashboardScreenState();
}

class _TlDashboardScreenState extends ConsumerState<TlDashboardScreen> {
  bool _isLoading = true;
  List<dynamic> _teamAttendance = [];
  List<dynamic> _pendingLeaves = [];

  @override
  void initState() {
    super.initState();
    _fetchTlDashboard();
  }

  Future<void> _fetchTlDashboard() async {
    setState(() => _isLoading = true);
    final apiClient = ref.read(apiClientProvider);

    try {
      final teamAtt = await apiClient.get(ApiEndpoints.attendanceTeam).catchError((_) => null);
      final pendingLeaves = await apiClient.get(ApiEndpoints.leavePending).catchError((_) => null);

      if (mounted) {
        setState(() {
          if (teamAtt is List) {
            _teamAttendance = teamAtt;
          } else if (teamAtt is Map<String, dynamic> && teamAtt['data'] is List) {
            _teamAttendance = teamAtt['data'];
          }

          if (pendingLeaves is List) {
            _pendingLeaves = pendingLeaves;
          } else if (pendingLeaves is Map<String, dynamic> && pendingLeaves['data'] is List) {
            _pendingLeaves = pendingLeaves['data'];
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
    final user = ref.watch(authServiceProvider).user;

    if (_isLoading) return const DashboardSkeleton();

    final teamSize = _teamAttendance.isNotEmpty ? _teamAttendance.length : 8;
    final pendingCount = _pendingLeaves.length;

    return RefreshIndicator(
      onRefresh: _fetchTlDashboard,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. COMPACT STATUS BANNER
            CompactStatusBanner(
              title: 'Team Lead Portal',
              subtitle: 'Lead: ${user?.fullName ?? 'Team Lead'} • $teamSize Members',
              actionLabel: 'My Team',
              icon: Icons.groups_rounded,
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
                    label: '$teamSize Team Members',
                    variant: PastelPillVariant.green,
                    onTap: () => widget.onNavigateTab(1),
                  ),
                  const SizedBox(width: 8),
                  PastelSummaryPill(
                    label: '$pendingCount Approvals Pending',
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
                  label: 'Team',
                  value: '$teamSize',
                  ringColor: AppColors.primary,
                  onTap: () => widget.onNavigateTab(1),
                ),
                CircularStatItemData(
                  label: 'Approvals',
                  value: '$pendingCount',
                  ringColor: const Color(0xFFD97706),
                  onTap: () => widget.onNavigateTab(2),
                ),
                CircularStatItemData(
                  label: 'Tasks',
                  value: '4',
                  ringColor: const Color(0xFF9333EA),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => Scaffold(
                          appBar: AppBar(title: const Text('Team Tasks')),
                          body: const TlTasksScreen(),
                        ),
                      ),
                    );
                  },
                ),
                CircularStatItemData(
                  label: 'Projects',
                  value: '2',
                  ringColor: const Color(0xFF2563EB),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => Scaffold(
                          appBar: AppBar(title: const Text('Team Projects')),
                          body: const TlProjectsScreen(),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 14),

            // 4. COMPACT INFO ROWS
            CompactInfoRowTile(
              label: 'Team Size Registered',
              value: '$teamSize Members',
              dotColor: AppColors.primary,
              icon: Icons.chevron_right_rounded,
              onTap: () => widget.onNavigateTab(1),
            ),
            const SizedBox(height: 8),
            CompactInfoRowTile(
              label: 'Pending Approvals Queue',
              value: '$pendingCount Requests',
              dotColor: const Color(0xFFD97706),
              icon: Icons.chevron_right_rounded,
              onTap: () => widget.onNavigateTab(2),
            ),
            const SizedBox(height: 18),

            const Text('Quick Lead Actions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 10),

            _menuTile('Team Projects & Member Assignment', Icons.folder_shared_rounded, () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => Scaffold(
                    appBar: AppBar(title: const Text('Team Projects')),
                    body: const TlProjectsScreen(),
                  ),
                ),
              );
            }),
            _menuTile('Team Analytics & Reports', Icons.bar_chart_rounded, () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => Scaffold(
                    appBar: AppBar(title: const Text('Team Analytics')),
                    body: const TlReportsScreen(),
                  ),
                ),
              );
            }),
            _menuTile('Team Tasks & Workflow', Icons.task_alt_rounded, () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => Scaffold(
                    appBar: AppBar(title: const Text('Team Tasks')),
                    body: const TlTasksScreen(),
                  ),
                ),
              );
            }),
            _menuTile('Team Expense Claims Review', Icons.monetization_on_rounded, () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => Scaffold(
                    appBar: AppBar(title: const Text('Expense Claims')),
                    body: const TlExpensesScreen(),
                  ),
                ),
              );
            }),
            _menuTile('Team Attendance & Approvals', Icons.event_available_rounded, () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TlAttendanceScreen()),
              );
            }),
            _menuTile('Team Performance & Goals', Icons.trending_up_rounded, () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => Scaffold(
                    appBar: AppBar(title: const Text('Performance & Goals')),
                    body: const TlPerformanceScreen(),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _menuTile(String label, IconData icon, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
            const Icon(Icons.chevron_right_rounded, color: AppColors.lightMutedText, size: 18),
          ],
        ),
      ),
    );
  }
}
