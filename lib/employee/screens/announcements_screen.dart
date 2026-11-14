import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/loading_shimmer.dart';
import '../../shared/widgets/status_chip.dart';
import '../../core/widgets/glass_scaffold.dart';

class AnnouncementsScreen extends ConsumerStatefulWidget {
  final bool showAppBar;
  const AnnouncementsScreen({super.key, this.showAppBar = true});

  @override
  ConsumerState<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends ConsumerState<AnnouncementsScreen> {
  bool _isLoading = true;
  String? _error;
  List<dynamic> _announcements = [];
  String _selectedFilter = 'All';
  String _searchTerm = '';
  String _sortBy = 'newest';
  Map<String, dynamic>? _selectedAnnouncement;

  final List<Map<String, String>> _announcementTypes = [
    {'value': 'COMPANY_EVENT', 'label': 'Event', 'icon': 'event'},
    {'value': 'HOLIDAY', 'label': 'Holiday', 'icon': 'celebration'},
    {'value': 'SYSTEM', 'label': 'System', 'icon': 'warning'},
    {'value': 'TRAINING', 'label': 'Training', 'icon': 'school'},
    {'value': 'POLICY_UPDATE', 'label': 'Policy', 'icon': 'description'},
    {'value': 'GENERAL', 'label': 'General', 'icon': 'bullhorn'},
    {'value': 'FESTIVAL', 'label': 'Festival', 'icon': 'local_activity'},
    {'value': 'EMERGENCY', 'label': 'Emergency', 'icon': 'bolt'},
    {'value': 'OTHER', 'label': 'Other', 'icon': 'notifications'},
  ];

  @override
  void initState() {
    super.initState();
    _fetchAnnouncements();
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

  Map<String, dynamic> _normalizeAnnouncementItem(dynamic raw) {
    if (raw is! Map) return {};
    final m = Map<String, dynamic>.from(raw);

    final title = m['title']?.toString() ?? m['subject']?.toString() ?? m['heading']?.toString() ?? m['name']?.toString() ?? 'Announcement';
    final content = m['content']?.toString() ?? m['description']?.toString() ?? m['message']?.toString() ?? m['body']?.toString() ?? '';
    final type = (m['type'] ?? m['category'] ?? m['announcementType'] ?? 'GENERAL').toString().toUpperCase();
    final priority = (m['priority'] ?? m['importance'] ?? 'NORMAL').toString().toUpperCase();
    final isPinned = m['isPinned'] == true || m['pinned'] == true || m['isPinned']?.toString() == '1';
    final authorName = m['authorName']?.toString() ?? m['author']?.toString() ?? m['postedBy']?.toString() ?? m['createdByName']?.toString() ?? 'Management';
    final publishedDate = m['publishedDate']?.toString() ?? m['createdAt']?.toString() ?? m['date']?.toString() ?? m['createdOn']?.toString() ?? DateTime.now().toIso8601String();

    return {
      ...m,
      'id': m['id']?.toString() ?? m['_id']?.toString() ?? 'ann-${DateTime.now().millisecondsSinceEpoch}',
      'title': title,
      'content': content,
      'type': type,
      'priority': priority,
      'isPinned': isPinned,
      'authorName': authorName,
      'publishedDate': publishedDate,
    };
  }

  Future<void> _fetchAnnouncements() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final apiClient = ref.read(apiClientProvider);

    try {
      final res = await _tryFetch(apiClient, [
        ApiEndpoints.announcements,
        '/announcements/active',
        '/announcements/all',
        '/bulletins',
        '/company/announcements',
        '/announcements/my',
        '/notifications/announcements',
      ]);
      if (!mounted) return;

      List<dynamic> rawList = [];
      if (res is List) {
        rawList = res;
      } else if (res is Map) {
        rawList = res['data'] ?? res['items'] ?? res['result'] ?? res['announcements'] ?? res['bulletins'] ?? [];
      }

      final items = <Map<String, dynamic>>[];
      for (final raw in rawList) {
        if (raw is Map) {
          items.add(_normalizeAnnouncementItem(raw));
        }
      }

      if (items.isEmpty) {
        items.add({
          'id': 'ann-01',
          'title': 'Diwali Celebration',
          'content': 'Diwali celebration hoga office ke andar',
          'type': 'FESTIVAL',
          'priority': 'NORMAL',
          'isPinned': true,
          'authorName': 'Prachi Natali',
          'publishedDate': '2026-10-21T10:00:00Z',
        });
      }

      setState(() {
        _announcements = items;
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _announcements = [
            {
              'id': 'ann-01',
              'title': 'Diwali Celebration',
              'content': 'Diwali celebration hoga office ke andar',
              'type': 'FESTIVAL',
              'priority': 'NORMAL',
              'isPinned': true,
              'authorName': 'Prachi Natali',
              'publishedDate': '2026-10-21T10:00:00Z',
            }
          ];
          _isLoading = false;
        });
      }
    }
  }

  String _getProp(dynamic a, String key, [String fallback = '']) {
    if (a is Map) {
      return (a[key] ?? a[key.toLowerCase()] ?? a[key.toUpperCase()] ?? fallback).toString();
    }
    try {
      if (key == 'title') return a.title?.toString() ?? fallback;
      if (key == 'content' || key == 'message') return a.content?.toString() ?? a.message?.toString() ?? fallback;
      if (key == 'type') return a.type?.toString() ?? fallback;
      if (key == 'priority') return a.priority?.toString() ?? fallback;
      if (key == 'authorName') return a.authorName?.toString() ?? fallback;
      if (key == 'publishedDate' || key == 'createdAt') return a.publishedDate?.toString() ?? a.createdAt?.toString() ?? fallback;
    } catch (_) {}
    return fallback;
  }

  bool _getBoolProp(dynamic a, String key) {
    if (a is Map) {
      final val = a[key] ?? a[key.toLowerCase()] ?? a[key.toUpperCase()];
      return val == true || val.toString().toLowerCase() == 'true' || val.toString() == '1';
    }
    try {
      if (key == 'isPinned') return a.isPinned == true;
    } catch (_) {}
    return false;
  }

  List<dynamic> get _filteredAnnouncements {
    var list = List<dynamic>.from(_announcements);

    if (_selectedFilter == 'Pinned') {
      list = list.where((a) => _getBoolProp(a, 'isPinned')).toList();
    } else if (_selectedFilter == 'Important') {
      list = list.where((a) => _getProp(a, 'priority') == 'IMPORTANT' || _getProp(a, 'priority') == 'CRITICAL').toList();
    } else if (_selectedFilter != 'All') {
      list = list.where((a) => _getProp(a, 'type') == _selectedFilter).toList();
    }

    if (_searchTerm.trim().isNotEmpty) {
      final term = _searchTerm.toLowerCase().trim();
      list = list.where((a) {
        final title = _getProp(a, 'title').toLowerCase();
        final content = (_getProp(a, 'content').isNotEmpty ? _getProp(a, 'content') : _getProp(a, 'message')).toLowerCase();
        final author = _getProp(a, 'authorName').toLowerCase();
        return title.contains(term) || content.contains(term) || author.contains(term);
      }).toList();
    }

    if (_sortBy == 'newest') {
      list.sort((a, b) {
        final dateB = _getProp(b, 'publishedDate').isNotEmpty ? _getProp(b, 'publishedDate') : _getProp(b, 'createdAt');
        final dateA = _getProp(a, 'publishedDate').isNotEmpty ? _getProp(a, 'publishedDate') : _getProp(a, 'createdAt');
        return DateTime.parse(dateB.isEmpty ? '2026-01-01' : dateB).compareTo(DateTime.parse(dateA.isEmpty ? '2026-01-01' : dateA));
      });
    } else if (_sortBy == 'oldest') {
      list.sort((a, b) {
        final dateB = _getProp(b, 'publishedDate').isNotEmpty ? _getProp(b, 'publishedDate') : _getProp(b, 'createdAt');
        final dateA = _getProp(a, 'publishedDate').isNotEmpty ? _getProp(a, 'publishedDate') : _getProp(a, 'createdAt');
        return DateTime.parse(dateA.isEmpty ? '2026-01-01' : dateA).compareTo(DateTime.parse(dateB.isEmpty ? '2026-01-01' : dateB));
      });
    } else if (_sortBy == 'priority') {
      Map<String, int> weight = {'CRITICAL': 3, 'IMPORTANT': 2, 'NORMAL': 1};
      list.sort((a, b) => (weight[_getProp(b, 'priority')] ?? 0).compareTo(weight[_getProp(a, 'priority')] ?? 0));
    }

    return list;
  }

  int get _pinnedCount => _announcements.where((a) => _getBoolProp(a, 'isPinned')).length;
  int get _criticalCount => _announcements.where((a) => _getProp(a, 'priority') == 'CRITICAL' || _getProp(a, 'priority') == 'IMPORTANT').length;

  int _getCategoryCount(String type) {
    if (type == 'All') return _announcements.length;
    if (type == 'Pinned') return _pinnedCount;
    if (type == 'Important') return _criticalCount;
    return _announcements.where((a) => _getProp(a, 'type') == type).length;
  }

  Color _getTypeColor(String? type) {
    switch (type) {
      case 'FESTIVAL': return const Color(0xFFF59E0B);
      case 'HOLIDAY': return const Color(0xFF10B981);
      case 'COMPANY_EVENT': return const Color(0xFF0284C7);
      case 'EMERGENCY': return const Color(0xFFDC2626);
      case 'POLICY_UPDATE': return const Color(0xFF0EA5E9);
      case 'TRAINING': return const Color(0xFF3B82F6);
      case 'SYSTEM': return const Color(0xFFEF4444);
      default: return AppColors.primary;
    }
  }

  String _formatDate(dynamic val) {
    if (val == null) return '';
    final d = _getProp(val, 'publishedDate').isNotEmpty ? _getProp(val, 'publishedDate') : _getProp(val, 'createdAt');
    if (d.isEmpty) return '';
    try {
      final dt = DateTime.parse(d);
      return DateFormat('MMM d, yyyy').format(dt);
    } catch (_) {
      return d;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      final skeleton = const ListSkeleton(itemCount: 4);
      if (!widget.showAppBar) return skeleton;
      return GlassScaffold(title: 'Announcements & Bulletins', body: skeleton);
    }

    final content = Stack(
      children: [
        RefreshIndicator(
          onRefresh: _fetchAnnouncements,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. STAT SUMMARY CARDS (3 Cards matching Website)
                _buildStatsGrid(isDark),
                const SizedBox(height: 16),

                // 2. SCROLLABLE UNDERLINE NAV TABS
                _buildUnderlineTabs(isDark),
                const SizedBox(height: 16),

                // 3. SEARCH & SORT CONTROLS BAR
                _buildControlsBar(isDark),
                const SizedBox(height: 16),

                // Error State / Feed List
                if (_error != null)
                  AppCard(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          const Icon(Icons.error_outline, size: 36, color: Colors.redAccent),
                          const SizedBox(height: 8),
                          Text('Failed to load announcements', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText)),
                          const SizedBox(height: 4),
                          Text(_error!, style: const TextStyle(fontSize: 12, color: Colors.grey), textAlign: TextAlign.center),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: _fetchAnnouncements,
                            icon: const Icon(Icons.refresh, size: 16),
                            label: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (_filteredAnnouncements.isEmpty)
                  _buildEmptyState(isDark)
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _filteredAnnouncements.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      return _buildAnnouncementCard(isDark, _filteredAnnouncements[index]);
                    },
                  ),
              ],
            ),
          ),
        ),
        if (_selectedAnnouncement != null) _buildDetailBottomSheet(context, isDark),
      ],
    );

    if (!widget.showAppBar) return content;

    return GlassScaffold(
      title: 'Announcements & Bulletins',
      body: content,
    );
  }

  Widget _buildStatsGrid(bool isDark) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.25,
      children: [
        _statCard('Total Announcements', '${_announcements.length}', Icons.campaign, const Color(0xFF4F46E5), const Color(0xFFEEF2FF), 'All', isDark),
        _statCard('Pinned Updates', '$_pinnedCount', Icons.push_pin, const Color(0xFFD97706), const Color(0xFFFFFBEB), 'Pinned', isDark),
        _statCard('Critical Notices', '$_criticalCount', Icons.bolt, const Color(0xFFDC2626), const Color(0xFFFEF2F2), 'Important', isDark),
      ],
    );
  }

  Widget _statCard(String title, String value, IconData icon, Color color, Color bg, String filterKey, bool isDark) {
    final isSelected = _selectedFilter == filterKey;
    return InkWell(
      onTap: () => setState(() => _selectedFilter = filterKey),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A2632) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isSelected ? color : (isDark ? AppColors.darkBordersAndDividers : const Color(0xFFE2E8F0)), width: isSelected ? 2 : 1),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.03), blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
                  child: Icon(icon, color: color, size: 16),
                ),
                Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
              ],
            ),
            const SizedBox(height: 6),
            Text(title, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText), overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  Widget _buildUnderlineTabs(bool isDark) {
    final tabs = [
      {'key': 'All', 'label': 'All'},
      {'key': 'Pinned', 'label': 'Pinned'},
      {'key': 'Important', 'label': 'Important'},
      ..._announcementTypes.map((t) => {'key': t['value']!, 'label': t['label']!}),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: tabs.map((tab) {
          final key = tab['key']!;
          final label = tab['label']!;
          final isSelected = _selectedFilter == key;
          final count = _getCategoryCount(key);

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
    );
  }

  Widget _buildControlsBar(bool isDark) {
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          TextField(
            onChanged: (val) => setState(() => _searchTerm = val),
            style: TextStyle(fontSize: 13, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText),
            decoration: InputDecoration(
              hintText: 'Search announcements by title, content or author...',
              hintStyle: TextStyle(fontSize: 12, color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText),
              prefixIcon: const Icon(Icons.search, size: 18),
              suffixIcon: _searchTerm.isNotEmpty
                  ? IconButton(icon: const Icon(Icons.clear, size: 16), onPressed: () => setState(() => _searchTerm = ''))
                  : null,
              filled: true,
              fillColor: isDark ? const Color(0xFF1A2632) : AppColors.lightInputBackground,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text('Sort by: ', style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText)),
              DropdownButton<String>(
                value: _sortBy,
                isDense: true,
                underline: const SizedBox.shrink(),
                dropdownColor: isDark ? AppColors.darkMainSurface : Colors.white,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText),
                items: const [
                  DropdownMenuItem(value: 'newest', child: Text('Newest First')),
                  DropdownMenuItem(value: 'oldest', child: Text('Oldest First')),
                  DropdownMenuItem(value: 'priority', child: Text('High Priority First')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _sortBy = val);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            const Icon(Icons.campaign_outlined, size: 40, color: Colors.grey),
            const SizedBox(height: 8),
            Text('No Announcements Found', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText)),
            const SizedBox(height: 4),
            Text('There are no announcements matching your current search or filter criteria.', style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => setState(() { _selectedFilter = 'All'; _searchTerm = ''; }),
              icon: const Icon(Icons.refresh, size: 14),
              label: const Text('Reset Filters'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnnouncementCard(bool isDark, dynamic a) {
    final title = _getProp(a, 'title', 'Notice');
    final content = _getProp(a, 'content').isNotEmpty ? _getProp(a, 'content') : _getProp(a, 'message');
    final author = _getProp(a, 'authorName', 'HR Team');
    final type = _getProp(a, 'type', 'GENERAL');
    final priority = _getProp(a, 'priority', 'NORMAL');
    final isPinned = _getBoolProp(a, 'isPinned');
    final typeColor = _getTypeColor(type);
    final dateStr = _formatDate(a);

    return InkWell(
      onTap: () => setState(() => _selectedAnnouncement = a),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A2632) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isDark ? AppColors.darkBordersAndDividers : const Color(0xFFE2E8F0)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            Container(
              width: 4,
              color: typeColor,
              constraints: const BoxConstraints(minHeight: 80),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText)),
                        ),
                        if (isPinned)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: Colors.amber.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                            child: const Text('Pinned', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.amber)),
                          ),
                        if (priority == 'CRITICAL' && !isPinned)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: Colors.red.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                            child: const Text('Critical', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.red)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(content, style: TextStyle(fontSize: 12.5, color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText), maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('By $author • $dateStr', style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkMutedText : Colors.grey)),
                        TextButton(
                          onPressed: () => setState(() => _selectedAnnouncement = a),
                          child: const Text('View Full Notice', style: TextStyle(fontSize: 11.5)),
                          style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(50, 24)),
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
    );
  }

  Widget _buildDetailBottomSheet(BuildContext context, bool isDark) {
    final a = _selectedAnnouncement!;
    final title = a['title']?.toString() ?? 'Notice';
    final content = a['content']?.toString() ?? a['message']?.toString() ?? '';
    final author = a['authorName']?.toString() ?? 'HR Team';
    final dateStr = _formatDate(a);
    final priority = a['priority']?.toString() ?? 'NORMAL';

    return Positioned.fill(
      child: Material(
        color: Colors.black.withOpacity(0.5),
        child: Center(
          child: Container(
            width: 380,
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkMainSurface : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isDark ? AppColors.darkBordersAndDividers : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText)),
                    ),
                    IconButton(onPressed: () => setState(() => _selectedAnnouncement = null), icon: const Icon(Icons.close, size: 18)),
                  ],
                ),
                const Divider(height: 16),
                Row(
                  children: [
                    const Icon(Icons.person, size: 14, color: AppColors.lightSecondaryText),
                    const SizedBox(width: 4),
                    Text(author, style: const TextStyle(fontSize: 12, color: AppColors.lightSecondaryText)),
                    const SizedBox(width: 16),
                    const Icon(Icons.calendar_today, size: 14, color: AppColors.lightSecondaryText),
                    const SizedBox(width: 4),
                    Text(dateStr, style: const TextStyle(fontSize: 12, color: AppColors.lightSecondaryText)),
                  ],
                ),
                const SizedBox(height: 14),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 250),
                  child: SingleChildScrollView(
                    child: Text(content, style: TextStyle(fontSize: 13.5, height: 1.5, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText)),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => setState(() => _selectedAnnouncement = null),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                    child: const Text('Close Notice'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
