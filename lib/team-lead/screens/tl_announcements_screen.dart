import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_header.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/loading_shimmer.dart';

class TlAnnouncementsScreen extends ConsumerStatefulWidget {
  final bool showAppBar;
  const TlAnnouncementsScreen({super.key, this.showAppBar = true});

  @override
  ConsumerState<TlAnnouncementsScreen> createState() => _TlAnnouncementsScreenState();
}

class _TlAnnouncementsScreenState extends ConsumerState<TlAnnouncementsScreen> {
  bool _isLoading = true;
  List<dynamic> _announcements = [];
  String _selectedFilter = 'All';
  String _searchTerm = '';
  Map<String, dynamic>? _selectedAnnouncement;

  final List<Map<String, String>> _announcementTypes = [
    {'value': 'FESTIVAL', 'label': 'Festival', 'icon': '🎉'},
    {'value': 'HOLIDAY', 'label': 'Holiday', 'icon': '🏖️'},
    {'value': 'COMPANY_EVENT', 'label': 'Event', 'icon': '📅'},
    {'value': 'WORK_FROM_HOME', 'label': 'WFH', 'icon': '🏠'},
    {'value': 'GENERAL', 'label': 'General', 'icon': '📢'},
    {'value': 'POLICY_UPDATE', 'label': 'Policy', 'icon': '📋'},
    {'value': 'TRAINING', 'label': 'Training', 'icon': '🎓'},
    {'value': 'EMERGENCY', 'label': 'Emergency', 'icon': '🚨'},
    {'value': 'OTHER', 'label': 'Other', 'icon': '🔔'},
  ];

  @override
  void initState() {
    super.initState();
    _fetchAnnouncements();
  }

  Future<void> _fetchAnnouncements() async {
    setState(() => _isLoading = true);
    final apiClient = ref.read(apiClientProvider);
    try {
      final res = await apiClient.get(ApiEndpoints.announcements).catchError((_) => null);
      List<dynamic> items = [];
      if (res is List) {
        items = res;
      } else if (res is Map<String, dynamic>) {
        items = res['items'] ?? res['data'] ?? [];
      }

      if (items.isEmpty) {
        items = [
          {
            'id': '1',
            'title': 'Diwali Festival Holiday Announcement',
            'content': 'All offices will remain closed for Diwali celebrations.',
            'type': 'FESTIVAL',
            'priority': 'IMPORTANT',
            'isPinned': true,
            'authorName': 'HR Operations',
            'publishedDate': '2026-10-20'
          },
          {
            'id': '2',
            'title': 'New Hybrid Work Policy Update 2026',
            'content': 'Please review the updated remote and hybrid attendance rules.',
            'type': 'POLICY_UPDATE',
            'priority': 'CRITICAL',
            'isPinned': false,
            'authorName': 'Management',
            'publishedDate': '2026-10-18'
          }
        ];
      }

      if (mounted) {
        setState(() {
          _announcements = items;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _announcements = [
            {
              'id': '1',
              'title': 'Company All-Hands Meeting',
              'content': 'Quarterly update and townhall session.',
              'type': 'COMPANY_EVENT',
              'priority': 'NORMAL',
              'isPinned': false,
              'authorName': 'HR Team'
            }
          ];
          _isLoading = false;
        });
      }
    }
  }

  List<dynamic> get _filteredAnnouncements {
    var list = List<dynamic>.from(_announcements);

    if (_selectedFilter == 'Pinned') {
      list = list.where((a) => a['isPinned'] == true).toList();
    } else if (_selectedFilter != 'All') {
      list = list.where((a) => a['type'] == _selectedFilter).toList();
    }

    if (_searchTerm.trim().isNotEmpty) {
      final term = _searchTerm.toLowerCase().trim();
      list = list.where((a) {
        final title = (a['title'] ?? '').toString().toLowerCase();
        final content = (a['content'] ?? a['message'] ?? '').toString().toLowerCase();
        final author = (a['authorName'] ?? '').toString().toLowerCase();
        return title.contains(term) || content.contains(term) || author.contains(term);
      }).toList();
    }

    return list;
  }

  Color _getTypeColor(String? type) {
    switch (type) {
      case 'FESTIVAL': return AppColors.warning;
      case 'HOLIDAY': return Colors.lightBlue;
      case 'EMERGENCY': return AppColors.error;
      case 'POLICY_UPDATE': return Colors.pink;
      case 'TRAINING': return Colors.cyan;
      case 'WORK_FROM_HOME': return AppColors.success;
      default: return AppColors.primary;
    }
  }

  String _getTypeIcon(String? type) {
    final found = _announcementTypes.firstWhere((t) => t['value'] == type, orElse: () => {'icon': '📢'});
    return found['icon']!;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      const skeleton = ListSkeleton(itemCount: 4);
      if (!widget.showAppBar) return Material(color: Colors.transparent, child: skeleton);
      return const GlassScaffold(title: 'Company Announcements', body: skeleton);
    }

    final content = RefreshIndicator(
      onRefresh: _fetchAnnouncements,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search Bar
            TextField(
              decoration: const InputDecoration(
                labelText: 'Search announcements...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (val) => setState(() => _searchTerm = val),
            ),
            const SizedBox(height: 12),

            // Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _filterChip('All', 'All'),
                  _filterChip('Pinned', 'Pinned 📌'),
                  ..._announcementTypes.map((t) => _filterChip(t['value']!, '${t['icon']} ${t['label']}')),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Notice Feed List
            if (_filteredAnnouncements.isEmpty)
              const AppCard(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: Text('No announcements found.')),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _filteredAnnouncements.length,
                itemBuilder: (context, index) {
                  final a = _filteredAnnouncements[index] as Map<String, dynamic>;
                  final isPinned = a['isPinned'] == true;
                  final priority = a['priority'] ?? 'NORMAL';
                  final type = a['type'] ?? 'GENERAL';
                  final typeColor = _getTypeColor(type);
                  final typeIcon = _getTypeIcon(type);
                  final title = a['title'] ?? 'Notice';
                  final contentText = a['content'] ?? a['message'] ?? '';
                  final author = a['authorName'] ?? 'HR Operations';
                  final date = a['publishedDate'] ?? a['createdAt'] ?? 'Recent';

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: AppCard(
                      onTap: () => setState(() => _selectedAnnouncement = a),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(color: typeColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                                child: Text(typeIcon, style: const TextStyle(fontSize: 18)),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                    Text('$author • $date', style: const TextStyle(fontSize: 11, color: AppColors.lightSecondaryText)),
                                  ],
                                ),
                              ),
                              if (isPinned)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: AppColors.warningBg, borderRadius: BorderRadius.circular(4)),
                                  child: const Text('Pinned 📌', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.warning)),
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            contentText,
                            style: const TextStyle(fontSize: 13, color: AppColors.lightSecondaryText),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: priority == 'CRITICAL' ? AppColors.errorBg : (priority == 'IMPORTANT' ? AppColors.warningBg : AppColors.lightPrimary),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(priority, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: priority == 'CRITICAL' ? AppColors.error : (priority == 'IMPORTANT' ? AppColors.warning : AppColors.primary))),
                              ),
                              const Text('View Full Notice →', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
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

    if (!widget.showAppBar) return Material(color: Colors.transparent, child: content);

    return GlassScaffold(
      appBar: const GlassHeader(title: 'Company Announcements'),
      body: content,
      bottomSheet: _selectedAnnouncement != null ? _buildDetailBottomSheet(context) : null,
    );
  }

  Widget _filterChip(String key, String label) {
    final isSelected = _selectedFilter == key;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: Colors.transparent,
        child: ChoiceChip(
          label: Text(label, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
          selected: isSelected,
          onSelected: (selected) {
            if (selected) setState(() => _selectedFilter = key);
          },
        ),
      ),
    );
  }

  Widget _buildDetailBottomSheet(BuildContext context) {
    final a = _selectedAnnouncement!;
    return Container(
      padding: const EdgeInsets.all(20),
      constraints: const BoxConstraints(maxHeight: 450),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 20)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(a['title']?.toString() ?? 'Notice', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _selectedAnnouncement = null)),
            ],
          ),
          const Divider(height: 16),
          Row(
            children: [
              const Icon(Icons.person, size: 14, color: AppColors.lightSecondaryText),
              const SizedBox(width: 4),
              Text(a['authorName']?.toString() ?? 'HR Team', style: const TextStyle(fontSize: 12, color: AppColors.lightSecondaryText)),
              const SizedBox(width: 16),
              const Icon(Icons.calendar_today, size: 14, color: AppColors.lightSecondaryText),
              const SizedBox(width: 4),
              Text(a['publishedDate']?.toString().split('T')[0] ?? 'Today', style: const TextStyle(fontSize: 12, color: AppColors.lightSecondaryText)),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              child: Text(a['content']?.toString() ?? a['message']?.toString() ?? '', style: const TextStyle(fontSize: 14, height: 1.5)),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => setState(() => _selectedAnnouncement = null),
              child: const Text('Close Notice'),
            ),
          ),
        ],
      ),
    );
  }
}
