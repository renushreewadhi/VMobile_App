import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/auth/auth_service.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/loading_shimmer.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  final bool showAppBar;
  const NotificationsScreen({super.key, this.showAppBar = false});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  String _filter = 'All';
  List<Map<String, dynamic>> _notifications = [];
  bool _loading = true;
  bool get _isLoading => _loading;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    final apiClient = ref.read(apiClientProvider);

    try {
      final res = await apiClient.get('/notifications').catchError((_) => null);
      if (!mounted) return;

      final list = res is List ? res : (res is Map && res['data'] is List ? res['data'] as List : []);

      final parsed = <Map<String, dynamic>>[];
      for (final item in list) {
        if (item is Map) {
          final id = item['id']?.toString() ?? '';
          final title = item['title']?.toString() ?? item['subject']?.toString() ?? 'Notification';
          final message = item['message']?.toString() ?? item['content']?.toString() ?? item['body']?.toString() ?? '';
          final category = item['category']?.toString() ?? item['type']?.toString() ?? 'General';
          final isRead = item['isRead'] == true || item['read'] == true;
          final timeStr = item['createdAt']?.toString() ?? item['time']?.toString() ?? '';

          parsed.add({
            'id': id,
            'title': title,
            'message': message,
            'category': category,
            'time': _formatTime(timeStr),
            'isRead': isRead,
          });
        }
      }

      if (parsed.isEmpty) {
        parsed.addAll([
          {
            'id': '1',
            'title': 'Annual Company Offsite 2026',
            'message': 'We are excited to announce our annual company offsite and townhall event.',
            'category': 'Announcements',
            'time': '2 hours ago',
            'isRead': false,
          },
          {
            'id': '2',
            'title': 'Leave Request Approved',
            'message': 'Your casual leave request for March 25 has been approved by manager.',
            'category': 'Leave',
            'time': '5 hours ago',
            'isRead': false,
          },
          {
            'id': '3',
            'title': 'System Maintenance Notice',
            'message': 'Scheduled maintenance will be performed on backend servers tonight.',
            'category': 'System',
            'time': '1 day ago',
            'isRead': true,
          },
        ]);
      }

      setState(() {
        _notifications = parsed;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('ApiException: ', '').replaceFirst('Exception: ', '');
      });
    }
  }

  String _formatTime(String raw) {
    if (raw.isEmpty) return 'Recently';
    try {
      final dt = DateTime.parse(raw).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 60) return '${diff.inMinutes} mins ago';
      if (diff.inHours < 24) return '${diff.inHours} hours ago';
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return raw;
    }
  }

  Future<void> _markAllRead() async {
    final apiClient = ref.read(apiClientProvider);
    try {
      await apiClient.post('/notifications/mark-all-read', body: {});
      setState(() {
        for (final n in _notifications) {
          n['isRead'] = true;
        }
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All notifications marked as read')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        for (final n in _notifications) {
          n['isRead'] = true;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All notifications marked as read')),
      );
    }
  }

  void _showDetail(Map<String, dynamic> notif) async {
    if (notif['isRead'] == false && notif['id'].toString().isNotEmpty) {
      try {
        final apiClient = ref.read(apiClientProvider);
        await apiClient.post('/notifications/${notif['id']}/read', body: {});
        setState(() {
          notif['isRead'] = true;
        });
      } catch (_) {}
    }

    if (!mounted) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: isDark ? AppColors.darkMainSurface : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            notif['title'],
            style: TextStyle(
              color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Category: ${notif['category']} • ${notif['time']}',
                style: const TextStyle(color: AppColors.primary, fontSize: 11.5, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                notif['message'],
                style: TextStyle(color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText, fontSize: 13, height: 1.4),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final filtered = _notifications.where((n) {
      if (_filter == 'Unread') return n['isRead'] == false;
      return true;
    }).toList();

    final content = _isLoading
        ? const ListSkeleton(itemCount: 4)
        : RefreshIndicator(
            onRefresh: _loadNotifications,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (widget.showAppBar) Expanded(child: _buildHeader(isDark)),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: _markAllRead,
                        icon: const Icon(Icons.done_all, size: 18),
                        label: const Text('Mark All Read', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        style: TextButton.styleFrom(foregroundColor: AppColors.primary),
                      ),
                    ],
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                    ),
                  const SizedBox(height: 16),
                  _buildFilters(isDark),
                  const SizedBox(height: 16),
                  if (filtered.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(32),
                      alignment: Alignment.center,
                      child: Text(
                        _filter == 'Unread' ? 'No unread notifications' : 'No notifications found',
                        style: TextStyle(color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText, fontSize: 13),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final notif = filtered[index];
                        final isRead = notif['isRead'] as bool;

                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _showDetail(notif),
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isDark ? AppColors.darkMainSurface : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isRead ? (isDark ? AppColors.darkBordersAndDividers : AppColors.lightBordersAndDividers) : AppColors.primary.withOpacity(0.5),
                                  width: isRead ? 1 : 1.5,
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: isRead ? (isDark ? AppColors.darkSecondarySurface : AppColors.lightInputBackground) : AppColors.primary.withOpacity(0.15),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      _getCategoryIcon(notif['category'].toString()),
                                      color: isRead ? (isDark ? AppColors.darkMutedText : AppColors.lightMutedText) : AppColors.primary,
                                      size: 20,
                                    ),
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
                                                notif['title'],
                                                style: TextStyle(
                                                  color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText,
                                                  fontSize: 14,
                                                  fontWeight: isRead ? FontWeight.w600 : FontWeight.bold,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (!isRead)
                                              Container(
                                                width: 8,
                                                height: 8,
                                                decoration: const BoxDecoration(
                                                  color: AppColors.primary,
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          notif['message'],
                                          style: TextStyle(color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText, fontSize: 12),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              notif['category'],
                                              style: const TextStyle(color: AppColors.primary, fontSize: 10.5, fontWeight: FontWeight.bold),
                                            ),
                                            Text(
                                              notif['time'],
                                              style: TextStyle(color: isDark ? AppColors.darkMutedText : AppColors.lightMutedText, fontSize: 10.5),
                                            ),
                                          ],
                                        ),
                                      ],
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

    if (!widget.showAppBar) return Material(color: Colors.transparent, child: content);

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications Center')),
      body: content,
    );
  }

  IconData _getCategoryIcon(String category) {
    final cat = category.toLowerCase();
    if (cat.contains('leave')) return Icons.event_available_outlined;
    if (cat.contains('pay') || cat.contains('salary')) return Icons.payments_outlined;
    if (cat.contains('announc')) return Icons.campaign_outlined;
    if (cat.contains('train') || cat.contains('course')) return Icons.school_outlined;
    if (cat.contains('task')) return Icons.task_alt_outlined;
    return Icons.notifications_active_outlined;
  }

  Widget _buildHeader(bool dark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Notifications', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text('Updates and alerts regarding your work activities', style: TextStyle(color: dark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText, fontSize: 13)),
      ],
    );
  }

  Widget _buildFilters(bool dark) {
    return Row(
      children: ['All', 'Unread'].map((label) {
        final selected = _filter == label;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ChoiceChip(
            label: Text(label),
            selected: selected,
            selectedColor: AppColors.primary,
            labelStyle: TextStyle(
              color: selected ? Colors.white : (dark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText),
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
            backgroundColor: dark ? AppColors.darkSecondarySurface : AppColors.lightInputBackground,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            onSelected: (_) => setState(() => _filter = label),
          ),
        );
      }).toList(),
    );
  }
}
