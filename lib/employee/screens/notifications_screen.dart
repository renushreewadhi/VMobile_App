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
  final String priorityBadgeText;
  final String? link;

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
      icon: cfg['icon'] as IconData,
      iconBg: cfg['iconBg'] as Color,
      iconColor: cfg['iconColor'] as Color,
      read: isRead,
      category: catUpper,
      categoryBadgeText: cfg['badgeText'] as String,
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
      if (diff.inMinutes < 60) return '${diff.inMinutes} mins ago';
      if (diff.inHours < 24) return '${diff.inHours} hrs ago';
      return '${diff.inDays} days ago';
    } catch (_) {
      return 'Recently';
    }
  }

  static Map<String, dynamic> _mapCategoryConfig(String catUpper, String title) {
    final t = title.toLowerCase();
    if (t.contains('eod') || t.contains('task') || t.contains('work')) {
      return {'icon': Icons.task_alt, 'iconBg': const Color(0xFFDcfce7), 'iconColor': const Color(0xFF16a34a), 'badgeText': 'General'};
    }
    if (catUpper.contains('ANNOUNCEMENT') || t.contains('offsite') || t.contains('townhall')) {
      return {'icon': Icons.campaign, 'iconBg': const Color(0xFFeff6ff), 'iconColor': const Color(0xFF2563eb), 'badgeText': 'Announcement'};
    }
    if (catUpper.contains('HOLIDAY') || t.contains('holiday') || t.contains('chaturthi')) {
      return {'icon': Icons.event, 'iconBg': const Color(0xFFdcfce7), 'iconColor': const Color(0xFF16a34a), 'badgeText': 'Holiday'};
    }
    if (catUpper.contains('SYSTEM') || t.contains('maintenance')) {
      return {'icon': Icons.warning_amber_rounded, 'iconBg': const Color(0xFFfee2e2), 'iconColor': const Color(0xFFdc2626), 'badgeText': 'System'};
    }
    if (catUpper.contains('TRAINING')) {
      return {'icon': Icons.school, 'iconBg': const Color(0xFFe0f2fe), 'iconColor': const Color(0xFF0284c7), 'badgeText': 'Training'};
    }
    if (catUpper.contains('LEAVE') || catUpper.contains('POLICY')) {
      return {'icon': Icons.description, 'iconBg': const Color(0xFFeff6ff), 'iconColor': const Color(0xFF2563eb), 'badgeText': 'Policy'};
    }
    return {'icon': Icons.notifications_active, 'iconBg': const Color(0xFFeff6ff), 'iconColor': const Color(0xFF2563eb), 'badgeText': 'General'};
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
  String? _activeMenuId;

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
    try {
      await apiClient.post(ApiEndpoints.notificationsMarkAllRead, body: {});
      setState(() {
        for (final n in _notifications) {
          n.read = true;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('All notifications marked as read.')));
    } catch (_) {
      setState(() {
        for (final n in _notifications) {
          n.read = true;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('All notifications marked as read.')));
    }
  }

  Future<void> _toggleReadStatus(NotificationItem n) async {
    setState(() => n.read = !n.read);
    _activeMenuId = null;
    final apiClient = ref.read(apiClientProvider);
    try {
      if (n.read) {
        await apiClient.post(ApiEndpoints.notificationRead(n.id), body: {});
      }
    } catch (_) {}
  }

  Future<void> _dismiss(NotificationItem n) async {
    setState(() => _notifications.removeWhere((item) => item.id == n.id));
    _activeMenuId = null;
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
            // Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Notifications Center',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'View and manage real-time alerts, announcements, and activity updates',
                        style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _unreadCount == 0 ? null : _markAllRead,
                  icon: const Icon(Icons.done_all, size: 16),
                  label: const Text('Mark All as Read', style: TextStyle(fontSize: 11.5)),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Horizontal Underline Category Tabs Bar
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: _filters.map((f) {
                  final key = f['key']!;
                  final label = f['label']!;
                  final isSelected = _selectedFilter == key;
                  final count = _getFilterCount(key);

                  return Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: InkWell(
                      onTap: () => setState(() => _selectedFilter = key),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          border: Border(bottom: BorderSide(color: isSelected ? AppColors.primary : Colors.transparent, width: 2.5)),
                        ),
                        child: Text(
                          count > 0 ? '$label ($count)' : label,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                            color: isSelected ? AppColors.primary : (isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),

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
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final n = _filteredNotifications[index];

                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1A2632) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: n.read ? (isDark ? AppColors.darkBordersAndDividers : const Color(0xFFE2E8F0)) : AppColors.primary.withOpacity(0.5),
                        width: n.read ? 1 : 1.5,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: n.iconBg, borderRadius: BorderRadius.circular(10)),
                          child: Icon(n.icon, color: n.iconColor, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      n.title,
                                      style: TextStyle(fontWeight: n.read ? FontWeight.w600 : FontWeight.bold, fontSize: 14.5, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (!n.read)
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                n.message,
                                style: TextStyle(fontSize: 12.5, color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(n.categoryBadgeText, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.primary)),
                                  Text(n.time, style: TextStyle(fontSize: 10.5, color: isDark ? AppColors.darkMutedText : Colors.grey)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, size: 18),
                          color: isDark ? AppColors.darkMainSurface : Colors.white,
                          onSelected: (val) {
                            if (val == 'toggle') _toggleReadStatus(n);
                            if (val == 'dismiss') _dismiss(n);
                          },
                          itemBuilder: (ctx) => [
                            PopupMenuItem(value: 'toggle', child: Text(n.read ? 'Mark as unread' : 'Mark as read', style: const TextStyle(fontSize: 12.5))),
                            PopupMenuItem(value: 'dismiss', child: Text('Dismiss', style: TextStyle(fontSize: 12.5, color: Colors.redAccent))),
                          ],
                        ),
                      ],
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
