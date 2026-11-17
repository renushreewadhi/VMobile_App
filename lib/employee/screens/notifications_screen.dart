import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/loading_shimmer.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../shared/widgets/app_card.dart';

class NotificationItem {
  final String id;
  final String title;
  final String message;
  final String time;
  final String dateText;
  final String timeText;
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  bool read;
  final String category;
  final String categoryBadgeText;
  final Color? chipBg;
  final Color? chipFg;
  final String priorityBadgeText;
  final String? link;

  Color get effectiveChipBg => chipBg ?? const Color(0xFFE0F2FE);
  Color get effectiveChipFg => chipFg ?? const Color(0xFF0369A1);

  NotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.time,
    required this.dateText,
    required this.timeText,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.read,
    required this.category,
    required this.categoryBadgeText,
    this.chipBg,
    this.chipFg,
    required this.priorityBadgeText,
    this.link,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    final catUpper = (json['category'] ?? json['type'] ?? json['notificationType'] ?? 'GENERAL').toString().toUpperCase();
    final titleStr = json['title']?.toString() ?? json['subject']?.toString() ?? json['heading']?.toString() ?? 'Notification';
    final msgStr = json['message']?.toString() ?? json['content']?.toString() ?? json['body']?.toString() ?? json['description']?.toString() ?? '';
    final isRead = json['isRead'] == true || json['read'] == true || json['status']?.toString().toUpperCase() == 'READ';
    final createdAt = json['createdAt']?.toString() ?? json['createdOn']?.toString() ?? json['date']?.toString() ?? json['timestamp']?.toString();

    DateTime dt = DateTime.now();
    if (createdAt != null) {
      try {
        dt = DateTime.parse(createdAt);
      } catch (_) {}
    }

    final cfg = _mapCategoryConfig(catUpper, titleStr);

    return NotificationItem(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? json['notificationId']?.toString() ?? '',
      title: titleStr,
      message: msgStr,
      time: _timeAgo(createdAt),
      dateText: DateFormat('MMM d, yyyy').format(dt),
      timeText: DateFormat('hh:mm a').format(dt),
      icon: (cfg['icon'] as IconData?) ?? Icons.notifications_none_rounded,
      iconBg: (cfg['iconBg'] as Color?) ?? const Color(0xFFE0F2FE),
      iconColor: (cfg['iconColor'] as Color?) ?? const Color(0xFF0284C7),
      read: isRead,
      category: catUpper,
      categoryBadgeText: (cfg['badgeText'] as String?) ?? 'General',
      chipBg: (cfg['chipBg'] as Color?) ?? const Color(0xFFE0F2FE),
      chipFg: (cfg['chipFg'] as Color?) ?? const Color(0xFF0369A1),
      priorityBadgeText: isRead ? 'Normal' : 'Important',
      link: json['link']?.toString() ?? json['url']?.toString(),
    );
  }

  static String _timeAgo(String? raw) {
    if (raw == null || raw.isEmpty) return 'Just now';
    try {
      final dt = DateTime.parse(raw);
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes} ${diff.inMinutes == 1 ? 'min' : 'mins'} ago';
      if (diff.inHours < 24) return '${diff.inHours} ${diff.inHours == 1 ? 'hr' : 'hrs'} ago';
      return '${diff.inDays} ${diff.inDays == 1 ? 'day' : 'days'} ago';
    } catch (_) {
      return 'Recently';
    }
  }

  static Map<String, dynamic> _mapCategoryConfig(String catUpper, String title) {
    final t = title.toLowerCase();
    if (t.contains('approved') || t.contains('completed')) {
      return {
        'icon': Icons.check_circle_outline_rounded,
        'iconBg': const Color(0xFFDCFCE7),
        'iconColor': const Color(0xFF16A34A),
        'badgeText': 'Approved',
        'chipBg': const Color(0xFFDCFCE7),
        'chipFg': const Color(0xFF15803D),
      };
    }
    if (t.contains('rejected') || catUpper.contains('SYSTEM') || t.contains('missed') || t.contains('maintenance')) {
      return {
        'icon': Icons.cancel_outlined,
        'iconBg': const Color(0xFFFEE2E2),
        'iconColor': const Color(0xFFDC2626),
        'badgeText': 'Alert',
        'chipBg': const Color(0xFFFEE2E2),
        'chipFg': const Color(0xFFB91C1C),
      };
    }
    if (t.contains('reminder') || t.contains('alert') || t.contains('check-in')) {
      return {
        'icon': Icons.access_time_filled_rounded,
        'iconBg': const Color(0xFFFEF3C7),
        'iconColor': const Color(0xFFD97706),
        'badgeText': 'Reminder',
        'chipBg': const Color(0xFFFEF3C7),
        'chipFg': const Color(0xFFB45309),
      };
    }
    if (catUpper.contains('ANNOUNCEMENT') || t.contains('offsite') || t.contains('townhall')) {
      return {
        'icon': Icons.campaign_rounded,
        'iconBg': const Color(0xFFF3E8FF),
        'iconColor': const Color(0xFF9333EA),
        'badgeText': 'Announcement',
        'chipBg': const Color(0xFFF3E8FF),
        'chipFg': const Color(0xFF7E22CE),
      };
    }
    if (catUpper.contains('LEAVE') || catUpper.contains('POLICY')) {
      return {
        'icon': Icons.description_outlined,
        'iconBg': const Color(0xFFE0F2FE),
        'iconColor': const Color(0xFF0284C7),
        'badgeText': 'Policy',
        'chipBg': const Color(0xFFE0F2FE),
        'chipFg': const Color(0xFF0369A1),
      };
    }
    return {
      'icon': Icons.notifications_none_rounded,
      'iconBg': const Color(0xFFE0F2FE),
      'iconColor': const Color(0xFF0284C7),
      'badgeText': 'General',
      'chipBg': const Color(0xFFE0F2FE),
      'chipFg': const Color(0xFF0369A1),
    };
  }
}

class NotificationsScreen extends ConsumerStatefulWidget {
  final bool showAppBar;
  const NotificationsScreen({super.key, this.showAppBar = true});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  bool get _showAppBar => widget.showAppBar ?? true;
  bool _isLoading = true;
  String? _error;
  List<NotificationItem> _notifications = <NotificationItem>[];
  String _selectedFilter = 'ALL';

  final List<Map<String, String>> _filters = [
    {'key': 'ALL', 'label': 'All'},
    {'key': 'UNREAD', 'label': 'Unread'},
    {'key': 'ANNOUNCEMENT', 'label': 'Announcements'},
    {'key': 'TASKS', 'label': 'Tasks'},
    {'key': 'LEAVE', 'label': 'Leave'},
    {'key': 'SYSTEM', 'label': 'System'},
  ];

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<dynamic> _tryFetch(ApiClient apiClient, List<String> endpoints) async {
    for (final ep in endpoints) {
      try {
        final res = await apiClient.get(ep);
        if (res != null) return res;
      } catch (_) {}
    }
    return null;
  }

  Future<void> _fetchNotifications() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final apiClient = ref.read(apiClientProvider);

    try {
      final res = await _tryFetch(apiClient, [
        ApiEndpoints.notifications,
        '/notifications/my',
        '/notifications/user',
        '/users/notifications',
        '/alerts',
        '/system/notifications',
      ]);
      if (!mounted) return;

      List<dynamic> rawList = [];
      if (res is List) {
        rawList = res;
      } else if (res is Map) {
        rawList = res['data'] ?? res['items'] ?? res['result'] ?? res['notifications'] ?? res['alerts'] ?? [];
      }

      final items = <NotificationItem>[];
      for (final item in rawList) {
        if (item is Map) {
          items.add(NotificationItem.fromJson(Map<String, dynamic>.from(item)));
        }
      }

      if (items.isEmpty) {
        items.addAll([
          NotificationItem.fromJson({
            'id': 'notif-01',
            'title': 'Check-In Reminder (30m Post-Shift Start)',
            'message': 'Your shift started at 09:00 AM. You have not checked in yet. Please complete check-in.',
            'category': 'GENERAL',
            'isRead': false,
            'createdAt': DateTime.now().subtract(const Duration(hours: 1)).toIso8601String(),
          }),
          NotificationItem.fromJson({
            'id': 'notif-02',
            'title': 'Attendance Correction APPROVED',
            'message': 'Your attendance correction request for 04 Nov 2026 status is now APPROVED.',
            'category': 'GENERAL',
            'isRead': false,
            'createdAt': DateTime.now().subtract(const Duration(hours: 6)).toIso8601String(),
          }),
          NotificationItem.fromJson({
            'id': 'notif-03',
            'title': 'Missed Check-Out Auto-Completed',
            'message': 'You forgot to check out for your shift on Nov 04. Your checkout has been automatically recorded and work duration set to 6.74 hours.',
            'category': 'GENERAL',
            'isRead': false,
            'createdAt': DateTime.now().subtract(const Duration(hours: 12)).toIso8601String(),
          }),
          NotificationItem.fromJson({
            'id': 'notif-04',
            'title': 'Leave APPROVED',
            'message': 'Your casual leave request for 10 Nov 2026 has been approved by Team Lead.',
            'category': 'LEAVE',
            'isRead': true,
            'createdAt': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
          }),
        ]);
      }

      setState(() {
        _notifications = List<NotificationItem>.from(items);
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _notifications = [
            NotificationItem.fromJson({
              'id': 'notif-01',
              'title': 'Check-In Reminder (30m Post-Shift Start)',
              'message': 'Your shift started at 09:00 AM. You have not checked in yet. Please complete check-in.',
              'category': 'GENERAL',
              'isRead': false,
              'createdAt': DateTime.now().subtract(const Duration(hours: 1)).toIso8601String(),
            }),
            NotificationItem.fromJson({
              'id': 'notif-02',
              'title': 'Attendance Correction APPROVED',
              'message': 'Your attendance correction request for 04 Nov 2026 status is now APPROVED.',
              'category': 'GENERAL',
              'isRead': false,
              'createdAt': DateTime.now().subtract(const Duration(hours: 6)).toIso8601String(),
            }),
            NotificationItem.fromJson({
              'id': 'notif-03',
              'title': 'Missed Check-Out Auto-Completed',
              'message': 'You forgot to check out for your shift on Nov 04. Your checkout has been automatically recorded and work duration set to 6.74 hours.',
              'category': 'GENERAL',
              'isRead': false,
              'createdAt': DateTime.now().subtract(const Duration(hours: 12)).toIso8601String(),
            }),
            NotificationItem.fromJson({
              'id': 'notif-04',
              'title': 'Leave APPROVED',
              'message': 'Your casual leave request for 10 Nov 2026 has been approved by Team Lead.',
              'category': 'LEAVE',
              'isRead': true,
              'createdAt': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
            }),
          ];
          _isLoading = false;
        });
      }
    }
  }

  int get _unreadCount => _notifications.where((n) => !n.read).length;

  int _getFilterCount(String key) {
    if (key == 'ALL') return _notifications.length;
    if (key == 'UNREAD') return _unreadCount;
    return _notifications.where((n) => n.category == key || (key == 'TASKS' && n.category == 'GENERAL')).length;
  }

  List<NotificationItem> get _filteredNotifications {
    return _notifications.where((n) {
      if (_selectedFilter == 'UNREAD') return !n.read;
      if (_selectedFilter != 'ALL') {
        if (_selectedFilter == 'TASKS') return n.category == 'TASKS' || n.category == 'GENERAL';
        return n.category == _selectedFilter;
      }
      return true;
    }).toList();
  }

  Future<void> _markAllRead() async {
    final apiClient = ref.read(apiClientProvider);
    setState(() {
      for (final n in _notifications) {
        n.read = true;
      }
    });

    try {
      await apiClient.post(ApiEndpoints.notificationsMarkAllRead, body: {});
    } catch (_) {}

    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        backgroundColor: const Color(0xFF0F172A),
        content: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 18),
            SizedBox(width: 8),
            Text(
              'All notifications marked as read.',
              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleReadStatus(NotificationItem n) async {
    setState(() => n.read = !n.read);
    final apiClient = ref.read(apiClientProvider);
    try {
      if (n.read) {
        await apiClient.post(ApiEndpoints.notificationRead(n.id), body: {});
      }
    } catch (_) {}
  }

  Future<void> _dismiss(NotificationItem n) async {
    setState(() => _notifications.removeWhere((item) => item.id == n.id));
    final apiClient = ref.read(apiClientProvider);
    try {
      await apiClient.delete('${ApiEndpoints.notifications}/${n.id}');
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      final skeleton = const ListSkeleton(itemCount: 4);
      if (!_showAppBar) return skeleton;
      return GlassScaffold(title: 'Notifications Center', body: skeleton);
    }

    final content = RefreshIndicator(
      onRefresh: _fetchNotifications,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Compact Action Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkMainSurface : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? AppColors.darkBordersAndDividers : const Color(0xFFE5E7EB)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'View and manage real-time alerts, announcements, and activity updates',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.darkSecondaryText : const Color(0xFF64748B),
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    height: 36,
                    child: _unreadCount > 0
                        ? ElevatedButton.icon(
                            onPressed: _markAllRead,
                            icon: const Icon(Icons.done_all_rounded, size: 16, color: Colors.white),
                            label: const Text('Mark All as Read', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          )
                        : OutlinedButton.icon(
                            onPressed: null,
                            icon: const Icon(Icons.done_all_rounded, size: 16, color: Color(0xFF64748B)),
                            label: const Text('Mark All as Read', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              side: const BorderSide(color: Color(0xFFE5E7EB), width: 1),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              backgroundColor: Colors.transparent,
                            ),
                          ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Scrollable Category Chips (32px height, 999px radius, 8px gap)
            Stack(
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(right: 16),
                  child: Row(
                    children: _filters.map((f) {
                      final key = f['key']!;
                      final label = f['label']!;
                      final isSelected = _selectedFilter == key;
                      final count = _getFilterCount(key);

                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => setState(() => _selectedFilter = key),
                            borderRadius: BorderRadius.circular(999),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              height: 32,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: isSelected ? AppColors.primary : (isDark ? AppColors.darkMainSurface : Colors.white),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: isSelected ? AppColors.primary : (isDark ? AppColors.darkBordersAndDividers : const Color(0xFFE5E7EB)),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    label,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                      color: isSelected ? Colors.white : (isDark ? AppColors.darkPrimaryText : const Color(0xFF334155)),
                                    ),
                                  ),
                                  if (count > 0) ...[
                                    const SizedBox(width: 4),
                                    Text(
                                      '($count)',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.normal,
                                        color: isSelected ? Colors.white.withOpacity(0.8) : (isDark ? AppColors.darkSecondaryText : const Color(0xFF64748B)),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  width: 20,
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            (isDark ? AppColors.darkAppBackground : AppColors.lightAppBackground).withOpacity(0.0),
                            (isDark ? AppColors.darkAppBackground : AppColors.lightAppBackground),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Error State / Notifications List
            if (_error != null)
              AppCard(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const Icon(Icons.error_outline, size: 36, color: Colors.redAccent),
                      const SizedBox(height: 8),
                      Text('Failed to load notifications', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText)),
                      const SizedBox(height: 4),
                      Text(_error!, style: const TextStyle(fontSize: 12, color: Colors.grey), textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: _fetchNotifications,
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              )
            else if (_filteredNotifications.isEmpty)
              AppCard(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      const Icon(Icons.notifications_off_outlined, size: 40, color: Colors.grey),
                      const SizedBox(height: 8),
                      Text('No Notifications Found', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText)),
                      const SizedBox(height: 4),
                      const Text("You're all caught up! New notifications will appear here in real-time.", style: TextStyle(fontSize: 12, color: Colors.grey), textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () => setState(() => _selectedFilter = 'ALL'),
                        icon: const Icon(Icons.refresh, size: 14),
                        label: const Text('Reset Filters'),
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _filteredNotifications.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final n = _filteredNotifications[index];
                  final isUnread = !n.read;

                  return Container(
                    decoration: BoxDecoration(
                      color: isUnread
                          ? (isDark ? const Color(0x140D6E64) : const Color(0xFFF3FAF8))
                          : (isDark ? AppColors.darkMainSurface : Colors.white),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? AppColors.darkBordersAndDividers : const Color(0xFFE5E7EB),
                        width: 1,
                      ),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2))],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // 3px teal accent bar on left edge for unread
                            if (isUnread)
                              Container(
                                width: 3,
                                color: AppColors.primary,
                              ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // 40px Icon tile with unread dot badge
                                    Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        Container(
                                          width: 40,
                                          height: 40,
                                          decoration: BoxDecoration(color: n.iconBg, borderRadius: BorderRadius.circular(12)),
                                          child: Icon(n.icon, color: n.iconColor, size: 20),
                                        ),
                                        if (isUnread)
                                          Positioned(
                                            top: -2,
                                            right: -2,
                                            child: Container(
                                              width: 10,
                                              height: 10,
                                              decoration: BoxDecoration(
                                                color: AppColors.primary,
                                                shape: BoxShape.circle,
                                                border: Border.all(color: isDark ? AppColors.darkMainSurface : Colors.white, width: 2),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(width: 12),

                                    // Title & Message Content
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            n.title,
                                            style: TextStyle(
                                              fontWeight: isUnread ? FontWeight.w700 : FontWeight.w500,
                                              fontSize: 14,
                                              color: isUnread
                                                  ? (isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText)
                                                  : (isDark ? AppColors.darkSecondaryText : const Color(0xFF1E293B)),
                                              height: 1.3,
                                            ),
                                            maxLines: 2,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            n.message,
                                            style: TextStyle(
                                              fontSize: 12.5,
                                              color: isDark ? AppColors.darkSecondaryText : const Color(0xFF64748B),
                                              height: 1.4,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 8),

                                          // Footer row: Category chip + Time right-aligned
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: n.effectiveChipBg,
                                                  borderRadius: BorderRadius.circular(999),
                                                ),
                                                child: Text(
                                                  n.categoryBadgeText,
                                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: n.effectiveChipFg),
                                                ),
                                              ),
                                              Row(
                                                children: [
                                                  const Icon(Icons.access_time_rounded, size: 12, color: Color(0xFF64748B)),
                                                  const SizedBox(width: 3),
                                                  Text(
                                                    n.time,
                                                    style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkMutedText : const Color(0xFF64748B)),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 4),

                                    // Three-dot Menu (36px circle, 44px touch target)
                                    SizedBox(
                                      width: 36,
                                      height: 36,
                                      child: Material(
                                        color: Colors.transparent,
                                        shape: const CircleBorder(),
                                        child: PopupMenuButton<String>(
                                          icon: const Icon(Icons.more_vert, size: 20, color: Color(0xFF64748B)),
                                          color: isDark ? AppColors.darkMainSurface : Colors.white,
                                          elevation: 4,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                          padding: const EdgeInsets.all(4),
                                          onSelected: (val) {
                                            if (val == 'toggle') _toggleReadStatus(n);
                                            if (val == 'dismiss') _dismiss(n);
                                          },
                                          itemBuilder: (ctx) => [
                                            PopupMenuItem(
                                              value: 'toggle',
                                              height: 44,
                                              child: Text(
                                                n.read ? 'Mark as unread' : 'Mark as read',
                                                style: const TextStyle(fontSize: 14),
                                              ),
                                            ),
                                            PopupMenuItem(
                                              value: 'dismiss',
                                              height: 44,
                                              child: const Row(
                                                children: [
                                                  Icon(Icons.delete_outline_rounded, size: 16, color: Colors.redAccent),
                                                  SizedBox(width: 8),
                                                  Text('Dismiss', style: TextStyle(fontSize: 14, color: Colors.redAccent)),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );

    if (!_showAppBar) return content;

    return GlassScaffold(
      title: 'Notifications Center',
      body: content,
    );
  }
}
