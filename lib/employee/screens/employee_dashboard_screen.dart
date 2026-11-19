import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/api/leave_service.dart';
import '../../core/auth/auth_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_card.dart';
import '../../shared/widgets/loading_shimmer.dart';
import '../../helpdesk/screens/helpdesk_dashboard_screen.dart';
import 'announcements_screen.dart';
import 'apply_leave_screen.dart';
import 'holidays_screen.dart';
import 'job_board_screen.dart';
import 'my_attendance_screen.dart';
import 'my_leave_screen.dart';
import 'my_payslips_screen.dart';
import 'my_profile_screen.dart';
import 'punch_in_out_screen.dart';
import 'training_screens.dart';

class EmployeeDashboardScreen extends ConsumerStatefulWidget {
  final Function(int) onNavigateTab;

  const EmployeeDashboardScreen({super.key, required this.onNavigateTab});

  @override
  ConsumerState<EmployeeDashboardScreen> createState() => _EmployeeDashboardScreenState();
}

class _EmployeeDashboardScreenState extends ConsumerState<EmployeeDashboardScreen> {
  bool _isLoading = true;
  bool _isLeaveSummaryExpanded = false;

  Map<String, dynamic> _today = {};
  List<dynamic> _balances = [];
  List<dynamic> _holidays = [];
  List<dynamic> _tasks = [];
  List<dynamic> _announcements = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final apiClient = ref.read(apiClientProvider);
    final leaveService = ref.read(leaveServiceProvider);

    try {
      final results = await Future.wait([
        apiClient.get(ApiEndpoints.attendanceToday).catchError((_) => null),
        leaveService.getLeaveBalances().catchError((_) => null),
        apiClient.get('/Holiday').catchError((_) => null),
        apiClient.get(ApiEndpoints.myTasks).catchError((_) => null),
        apiClient.get(ApiEndpoints.announcements).catchError((_) => null),
      ]);

      if (!mounted) return;

      final todayRes = results[0] is Map<String, dynamic> ? (results[0]['data'] ?? results[0]) : <String, dynamic>{};
      final balancesRes = results[1] is List ? results[1] as List : (results[1] is Map && results[1]['data'] is List ? results[1]['data'] as List : []);
      final holidaysRes = results[2] is List ? results[2] as List : (results[2] is Map && results[2]['data'] is List ? results[2]['data'] as List : []);
      final tasksRes = results[3] is List ? results[3] as List : (results[3] is Map && results[3]['data'] is List ? results[3]['data'] as List : []);
      final announcementsRes = results[4] is List ? results[4] as List : (results[4] is Map && results[4]['data'] is List ? results[4]['data'] as List : []);

      setState(() {
        _today = todayRes is Map<String, dynamic> ? todayRes : {};
        _balances = balancesRes.isNotEmpty ? balancesRes : [
          {'leaveType': 'Earned Leave', 'remaining': 15, 'total': 15},
          {'leaveType': 'Sick Leave', 'remaining': 10, 'total': 10},
          {'leaveType': 'Casual Leave', 'remaining': 8, 'total': 12},
          {'leaveType': 'Comp Off', 'remaining': 4, 'total': 5},
          {'leaveType': 'Personal Leave', 'remaining': 5, 'total': 5},
          {'leaveType': 'Paid Leave', 'remaining': 0, 'total': 15},
        ];
        _holidays = holidaysRes.isNotEmpty ? holidaysRes : [
          {'title': 'Republic Day', 'date': '26 Jan 2026', 'type': 'Public Holiday'},
          {'title': 'Holi', 'date': '04 Mar 2026', 'type': 'Public Holiday'},
          {'title': 'Eid-ul-Fitr', 'date': '21 Mar 2026', 'type': 'Gazetted'},
        ];
        _tasks = tasksRes;
        _announcements = announcementsRes;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  String _greeting(String name) {
    final hour = DateTime.now().hour;
    final timeGreeting = hour < 12 ? 'Good morning' : (hour < 17 ? 'Good afternoon' : 'Good evening');
    return '$timeGreeting, $name!';
  }

  Widget _buildHeroPunchCard(bool isDark) {
    final statusColor = _isCheckedIn ? const Color(0xFF10B981) : AppColors.primary;
    final checkInTimeFormatted = _formatTimeString(_today['checkInTime'] ?? _today['checkIn']);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF132230), const Color(0xFF0F2624)]
              : [const Color(0xFFF0FDF4), const Color(0xFFE0F2FE)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.18),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isCheckedIn ? Icons.check_circle_rounded : Icons.fingerprint_rounded,
                  color: statusColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _isCheckedIn ? 'CLOCKED IN AT $checkInTimeFormatted' : 'NOT CLOCKED IN YET',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w900,
                            color: statusColor,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _isCheckedIn ? 'Workday active · Standard Day Shift' : 'Ready to start your workday?',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const PunchInOutScreen())).then((_) => _loadData());
              },
              icon: Icon(_isCheckedIn ? Icons.logout_rounded : Icons.fingerprint_rounded, size: 20),
              label: Text(
                _isCheckedIn ? 'Clock Out / Stepping Out' : 'PUNCH IN NOW',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5, letterSpacing: 0.5),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: statusColor,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _dateLabel(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    const weekdays = ['Fri', 'Sat', 'Sun', 'Mon', 'Tue', 'Wed', 'Thu'];
    return '${weekdays[date.weekday - 1]}, ${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _formatTimeString(dynamic isoStr) {
    if (isoStr == null || isoStr.toString().trim().isEmpty) return '—';
    final str = isoStr.toString().trim();
    if (str.contains('AM') || str.contains('PM')) return str;
    try {
      final dt = DateTime.parse(str).toLocal();
      final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final minute = dt.minute.toString().padLeft(2, '0');
      final amPm = dt.hour >= 12 ? 'PM' : 'AM';
      return '${hour.toString().padLeft(2, '0')}:$minute $amPm';
    } catch (_) {
      return str;
    }
  }

  double _number(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  double get _remainingLeave => _balances.fold<double>(0, (sum, item) => sum + _number(item['remaining'] ?? item['remainingDays'] ?? item['available'] ?? 119));
  int get _pendingTasks => _tasks.where((t) => !(t['status'] ?? '').toString().toLowerCase().contains('completed') && !(t['status'] ?? '').toString().toLowerCase().contains('done')).length;

  bool get _isCheckedIn => _today['checkInTime'] != null || _today['checkIn'] != null;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authServiceProvider).user;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final employeeName = user?.firstName ?? 'Ravi';
    final avatarUrl = user?.avatar ?? '';
    final checkInTimeFormatted = _formatTimeString(_today['checkInTime'] ?? _today['checkIn']);

    if (_isLoading) {
      return const DashboardSkeleton();
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 36),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. WEB-STYLE HERO WELCOME BANNER
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF1B2A38), const Color(0xFF0F2E2C)]
                      : [Colors.white, const Color(0xFFF3F7F7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppColors.primary.withOpacity(0.15)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _greeting(employeeName),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Stay focused, stay productive, and keep moving forward.',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: AppColors.primary.withOpacity(0.15),
                    backgroundImage: avatarUrl.isNotEmpty
                        ? NetworkImage(avatarUrl.startsWith('http') ? avatarUrl : (avatarUrl.startsWith('/') ? 'https://hrms.etaprise.ai$avatarUrl' : 'https://hrms.etaprise.ai/$avatarUrl'))
                        : null,
                    child: avatarUrl.isEmpty
                        ? Text(
                            employeeName.isNotEmpty ? employeeName[0].toUpperCase() : 'R',
                            style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w900, fontSize: 18),
                          )
                        : null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 2. HERO PUNCH IN/OUT ACTION CARD
            _buildHeroPunchCard(isDark),
            const SizedBox(height: 14),

            // 3. TOP METRICS 2x2 COMPACT GRID
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 2.1,
              children: [
                _metricCard(
                  title: _isCheckedIn ? 'Checked In' : 'Not Checked In',
                  value: _isCheckedIn ? checkInTimeFormatted : '--:--',
                  subtitle: 'Check-In Time',
                  icon: Icons.access_time_filled_rounded,
                  color: const Color(0xFF10B981),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PunchInOutScreen())).then((_) => _loadData()),
                ),
                _metricCard(
                  title: 'Leave Balance',
                  value: '${_remainingLeave.toInt()} Days',
                  subtitle: 'Available Leaves',
                  icon: Icons.eco_rounded,
                  color: const Color(0xFF0F6B66),
                  onTap: () => widget.onNavigateTab(2),
                ),
                _metricCard(
                  title: 'My Tasks',
                  value: _pendingTasks == 0 ? 'All Done 🎉' : '$_pendingTasks Pending',
                  subtitle: _pendingTasks == 0 ? 'No Active Tasks' : 'Active Tasks',
                  icon: Icons.checklist_rounded,
                  color: const Color(0xFF8B5CF6),
                  onTap: () => widget.onNavigateTab(3),
                ),
                _metricCard(
                  title: 'Announcements',
                  value: '${_announcements.length} New',
                  subtitle: 'Company Updates',
                  icon: Icons.campaign_rounded,
                  color: const Color(0xFFF59E0B),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AnnouncementsScreen())),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 4. LEAVE BALANCE BREAKDOWN CARD (Collapsible to reduce clutter)
            GlassCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Leave Balance Summary',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => setState(() => _isLeaveSummaryExpanded = !_isLeaveSummaryExpanded),
                        child: Text(
                          _isLeaveSummaryExpanded ? 'Collapse ▴' : 'Expand ▾',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _leaveBreakdownItem('Earned Leave', '15', 'Available / 15', const Color(0xFF10B981))),
                      const SizedBox(width: 8),
                      Expanded(child: _leaveBreakdownItem('Sick Leave', '10', 'Available / 10', const Color(0xFFEF4444))),
                    ],
                  ),
                  if (_isLeaveSummaryExpanded) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: _leaveBreakdownItem('Casual Leave', '8', 'Available / 12', const Color(0xFF3B82F6))),
                        const SizedBox(width: 8),
                        Expanded(child: _leaveBreakdownItem('Comp Off', '4', 'Available / 5', const Color(0xFFF59E0B))),
                      ],
                    ),
                  ],
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ApplyLeaveScreen())),
                      icon: const Icon(Icons.add_circle_outline_rounded, size: 16),
                      label: const Text('Apply Leave', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 4. QUICK ACTIONS GRID
            _sectionHeader(isDark, 'Quick Actions', () {}),
            const SizedBox(height: 8),
            _quickActionsGrid(isDark),
            const SizedBox(height: 16),

            // 5. UPCOMING HOLIDAYS
            _sectionHeader(isDark, 'Upcoming Holidays', () => Navigator.push(context, MaterialPageRoute(builder: (_) => HolidaysScreen()))),
            const SizedBox(height: 8),
            _holidaysList(isDark),
            const SizedBox(height: 16),

            // 6. ANNOUNCEMENTS PREVIEW
            _sectionHeader(isDark, 'Announcements', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AnnouncementsScreen()))),
            const SizedBox(height: 8),
            _announcementsCard(isDark),
          ],
        ),
      ),
    );
  }

  Widget _metricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: color.withOpacity(0.18),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(title, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey[700])),
                  const SizedBox(height: 1),
                  Text(value, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900, color: color), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 1),
                  Text(subtitle, style: TextStyle(fontSize: 8.5, color: Colors.grey[500])),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 16, color: color.withOpacity(0.6)),
          ],
        ),
      ),
    );
  }

  Widget _leaveBreakdownItem(String label, String count, String sub, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 32,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                const SizedBox(height: 1),
                Row(
                  children: [
                    Text(count, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: color)),
                    const SizedBox(width: 4),
                    Text(sub, style: TextStyle(fontSize: 9.5, color: Colors.grey[600])),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(bool dark, String title, VoidCallback onViewAll) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: dark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText)),
        TextButton(
          onPressed: onViewAll,
          style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 0)),
          child: const Text('View all >', style: TextStyle(color: AppColors.primary, fontSize: 11.5, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _quickActionsGrid(bool dark) {
    final actions = [
      {'label': 'Apply Leave', 'icon': Icons.calendar_month_rounded, 'color': const Color(0xFF10B981), 'screen': const ApplyLeaveScreen()},
      {'label': 'View Payslip', 'icon': Icons.description_rounded, 'color': const Color(0xFFF59E0B), 'screen': const MyPayslipsScreen()},
      {'label': 'Certificate', 'icon': Icons.verified_rounded, 'color': const Color(0xFF8B5CF6), 'screen': const MyCertificatesScreen()},
      {'label': 'Job Openings', 'icon': Icons.work_rounded, 'color': const Color(0xFF3B82F6), 'screen': const JobBoardScreen()},
      {'label': 'Helpdesk', 'icon': Icons.support_agent_rounded, 'color': const Color(0xFF0EA5E9), 'screen': const HelpdeskDashboardScreen(showAppBar: true)},
    ];

    return SizedBox(
      height: 78,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: actions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final action = actions[index];
          return GestureDetector(
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => action['screen'] as Widget));
            },
            child: SizedBox(
              width: 70,
              child: Column(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: (action['color'] as Color).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(action['icon'] as IconData, color: action['color'] as Color, size: 22),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    action['label'] as String,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, height: 1.1),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _holidaysList(bool dark) {
    if (_holidays.isEmpty) {
      return GlassCard(child: const Padding(padding: EdgeInsets.all(12), child: Center(child: Text('No upcoming holidays.'))));
    }

    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
      child: Column(
        children: _holidays.take(2).map((h) {
          final title = h['holidayName']?.toString() ?? h['name']?.toString() ?? h['title']?.toString() ?? 'Holiday';
          final dateStr = h['holidayDate']?.toString() ?? h['date']?.toString() ?? h['startDate']?.toString() ?? '';
          final type = h['type']?.toString() ?? h['description']?.toString() ?? 'Public Holiday';

          String day = '26';
          String month = 'JAN';
          try {
            if (dateStr.contains('-') || dateStr.contains('T')) {
              final dt = DateTime.parse(dateStr);
              day = dt.day.toString().padLeft(2, '0');
              const months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
              month = months[dt.month - 1];
            } else if (dateStr.isNotEmpty) {
              final parts = dateStr.split(' ');
              if (parts.length >= 2) {
                day = parts[0].padLeft(2, '0');
                month = parts[1].toUpperCase().substring(0, math.min(3, parts[1].length));
              }
            }
          } catch (_) {}

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFCA5A5).withOpacity(0.4)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(day, style: const TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.w900, fontSize: 13)),
                      Text(month, style: const TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.w800, fontSize: 8.5)),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 1),
                      Text(type, style: const TextStyle(fontSize: 10.5, color: AppColors.lightSecondaryText)),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _announcementsCard(bool dark) {
    if (_announcements.isEmpty) {
      return GlassCard(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.article_rounded, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('No announcements posted yet.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                  SizedBox(height: 1),
                  Text('Stay tuned for updates from your organization.', style: TextStyle(fontSize: 10.5, color: AppColors.lightSecondaryText)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final item = _announcements.first;
    final title = item['title']?.toString() ?? item['subject']?.toString() ?? 'Announcement';
    final content = item['content']?.toString() ?? item['description']?.toString() ?? '';

    return GlassCard(
      padding: const EdgeInsets.all(12),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AnnouncementsScreen())),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.campaign_rounded, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                if (content.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(content, style: const TextStyle(fontSize: 11, color: AppColors.lightSecondaryText), maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 18),
        ],
      ),
    );
  }
}
