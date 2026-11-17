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
  final Set<String> _readAnnouncementIds = {};

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
    final authorName = m['authorName']?.toString() ?? m['author']?.toString() ?? m['postedBy']?.toString() ?? m['createdByName']?.toString() ?? 'HR Manager';
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
    } else if (_sortBy == 'pinned') {
      list.sort((a, b) {
        final pinA = _getBoolProp(a, 'isPinned') ? 1 : 0;
        final pinB = _getBoolProp(b, 'isPinned') ? 1 : 0;
        return pinB.compareTo(pinA);
      });
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

  Color _getCategoryAccentColor(String type) {
    switch (type.toUpperCase()) {
      case 'IMPORTANT':
      case 'CRITICAL':
      case 'EMERGENCY':
        return const Color(0xFFDC2626); // Red
      case 'COMPANY_EVENT':
      case 'EVENT':
        return const Color(0xFF7C3AED); // Purple
      case 'HOLIDAY':
      case 'FESTIVAL':
        return const Color(0xFFF59E0B); // Amber
      case 'SYSTEM':
        return const Color(0xFF2563EB); // Blue
      case 'GENERAL':
      case 'TRAINING':
      default:
        return AppColors.primary; // Teal
    }
  }

  String _getCategoryLabel(String type) {
    switch (type.toUpperCase()) {
      case 'COMPANY_EVENT': return 'Event';
      case 'POLICY_UPDATE': return 'Policy';
      default: return type.toLowerCase();
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

  String _getRelativeTime(String dateStr) {
    if (dateStr.isEmpty) return '';
    try {
      final dt = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inDays == 0) {
        if (diff.inHours == 0) {
          return '${diff.inMinutes} mins ago';
        }
        return '${diff.inHours} hours ago';
      } else if (diff.inDays > 0 && diff.inDays <= 7) {
        return '${diff.inDays} days ago';
      } else {
        return DateFormat('MMM d').format(dt);
      }
    } catch (_) {
      return dateStr;
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
                // 1. Slim summary line under app bar
                _buildSummaryLine(isDark),
                const SizedBox(height: 12),

                // 2. Search + Sort (one row)
                _buildSearchSortRow(isDark),
                const SizedBox(height: 12),

                // 3. Filter chips
                _buildFilterChips(isDark),
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
                else
                  _buildAnnouncementsList(isDark),
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

  Widget _buildSummaryLine(bool isDark) {
    final total = _announcements.length;
    final pinned = _announcements.where((a) => _getBoolProp(a, 'isPinned')).length;
    final critical = _announcements.where((a) => _getProp(a, 'priority') == 'CRITICAL' || _getProp(a, 'priority') == 'IMPORTANT').length;

    return Row(
      children: [
        Text(
          '$total announcements · $pinned pinned',
          style: TextStyle(
            fontSize: 13,
            color: isDark ? AppColors.darkSecondaryText : const Color(0xFF4B5563), // gray-600
            fontWeight: FontWeight.w500,
          ),
        ),
        if (critical > 0) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.15),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$critical critical',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.redAccent,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSearchSortRow(bool isDark) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 44,
            child: TextField(
              onChanged: (val) => setState(() => _searchTerm = val),
              style: TextStyle(fontSize: 13, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText),
              decoration: InputDecoration(
                hintText: 'Search announcements',
                hintStyle: TextStyle(fontSize: 12, color: isDark ? AppColors.darkSecondaryText : const Color(0xFF6B7280)),
                prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF6B7280)),
                suffixIcon: _searchTerm.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: () => setState(() => _searchTerm = ''),
                      )
                    : null,
                filled: true,
                fillColor: isDark ? const Color(0xFF1A2632) : Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppColors.primary)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A2632) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isDark ? AppColors.darkBordersAndDividers : const Color(0xFFE5E7EB)),
          ),
          child: PopupMenuButton<String>(
            icon: Icon(Icons.swap_vert, size: 20, color: isDark ? AppColors.darkSecondaryText : const Color(0xFF4B5563)),
            tooltip: 'Sort announcements',
            onSelected: (val) => setState(() => _sortBy = val),
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'newest', child: Text('Newest First')),
              const PopupMenuItem(value: 'oldest', child: Text('Oldest First')),
              const PopupMenuItem(value: 'pinned', child: Text('Pinned First')),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChips(bool isDark) {
    final chips = [
      {'key': 'All', 'label': 'All'},
      {'key': 'Pinned', 'label': 'Pinned'},
      {'key': 'Important', 'label': 'Important'},
      {'key': 'COMPANY_EVENT', 'label': 'Event'},
      {'key': 'HOLIDAY', 'label': 'Holiday'},
      {'key': 'SYSTEM', 'label': 'System'},
      {'key': 'TRAINING', 'label': 'Training'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.only(right: 16),
        child: Row(
          children: chips.map((chip) {
            final key = chip['key']!;
            final label = chip['label']!;
            final isSelected = _selectedFilter == key;
            final count = _getCategoryCount(key);

            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: InkWell(
                onTap: () => setState(() => _selectedFilter = key),
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  height: 32,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : (isDark ? const Color(0xFF1A2632) : Colors.white),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : (isDark ? AppColors.darkBordersAndDividers : const Color(0xFFE5E7EB)),
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
                          color: isSelected ? Colors.white : (isDark ? AppColors.darkPrimaryText : const Color(0xFF374151)), // gray-700
                        ),
                      ),
                      if (count > 0) ...[
                        const SizedBox(width: 4),
                        Text(
                          '($count)',
                          style: TextStyle(
                            fontSize: 11,
                            color: isSelected ? Colors.white.withOpacity(0.8) : (isDark ? AppColors.darkSecondaryText : const Color(0xFF9CA3AF)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildAnnouncementsList(bool isDark) {
    final filtered = _filteredAnnouncements;

    if (filtered.isEmpty) {
      return _buildEmptyState(isDark);
    }

    final pinnedList = filtered.where((a) => _getBoolProp(a, 'isPinned')).toList();
    final recentList = filtered.where((a) => !_getBoolProp(a, 'isPinned')).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (pinnedList.isNotEmpty) ...[
          const Text(
            'PINNED',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF6B7280),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          ...pinnedList.map((a) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _buildAnnouncementCard(isDark, a),
              )),
          const SizedBox(height: 12),
        ],
        if (recentList.isNotEmpty) ...[
          if (pinnedList.isNotEmpty) ...[
            const Text(
              'RECENT',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF6B7280),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
          ],
          ...recentList.map((a) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _buildAnnouncementCard(isDark, a),
              )),
        ],
      ],
    );
  }

  Widget _buildAnnouncementCard(bool isDark, dynamic a) {
    final id = _getProp(a, 'id');
    final title = _getProp(a, 'title', 'Notice');
    final content = _getProp(a, 'content').isNotEmpty ? _getProp(a, 'content') : _getProp(a, 'message');
    final author = _getProp(a, 'authorName', 'HR Manager');
    final type = _getProp(a, 'type', 'GENERAL');
    final isPinned = _getBoolProp(a, 'isPinned');
    final accentColor = _getCategoryAccentColor(type);
    final relativeTime = _getRelativeTime(_getProp(a, 'publishedDate').isNotEmpty ? _getProp(a, 'publishedDate') : _getProp(a, 'createdAt'));
    final isUnread = !_readAnnouncementIds.contains(id);

    return AppCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: () {
          setState(() {
            _readAnnouncementIds.add(id);
            _selectedAnnouncement = a;
          });
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A2632) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? AppColors.darkBordersAndDividers : const Color(0xFFE5E7EB)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.2 : 0.02),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 4,
                  color: accentColor,
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
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: accentColor.withOpacity(isDark ? 0.25 : 0.12),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                _getCategoryLabel(type).toUpperCase(),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: accentColor,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                            if (isPinned)
                              const Icon(Icons.push_pin, size: 14, color: Colors.amber),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            if (isUnread) ...[
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                            ],
                            Expanded(
                              child: Text(
                                title,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: isUnread ? FontWeight.w700 : FontWeight.w600,
                                  color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.chevron_right, size: 18, color: Color(0xFF9CA3AF)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          content,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? AppColors.darkSecondaryText : const Color(0xFF4B5563),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '$author · $relativeTime',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppColors.darkMutedText : const Color(0xFF6B7280),
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
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    final hasActiveFilters = _selectedFilter != 'All' || _searchTerm.trim().isNotEmpty;

    return AppCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.campaign_outlined, size: 24, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            Text(
              'No announcements found',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'There are no announcements matching your current search or filter criteria.',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AppColors.darkSecondaryText : const Color(0xFF6B7280),
              ),
              textAlign: TextAlign.center,
            ),
            if (hasActiveFilters) ...[
              const SizedBox(height: 20),
              TextButton(
                onPressed: () => setState(() {
                  _selectedFilter = 'All';
                  _searchTerm = '';
                }),
                child: const Text(
                  'Clear filters',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailBottomSheet(BuildContext context, bool isDark) {
    final a = _selectedAnnouncement!;
    final title = _getProp(a, 'title', 'Notice');
    final content = _getProp(a, 'content').isNotEmpty ? _getProp(a, 'content') : _getProp(a, 'message');
    final author = _getProp(a, 'authorName', 'HR Manager');
    final dateStr = _formatDate(a);
    final type = _getProp(a, 'type', 'GENERAL');
    final isPinned = _getBoolProp(a, 'isPinned');
    final accentColor = _getCategoryAccentColor(type);
    final linkUrl = _getProp(a, 'link') ?? _getProp(a, 'url') ?? _getProp(a, 'attachment');

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _selectedAnnouncement = null),
      child: Container(
        color: Colors.black.withOpacity(0.4),
        alignment: Alignment.bottomCenter,
        child: GestureDetector(
          onTap: () {},
          child: Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkMainSurface : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
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
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: accentColor.withOpacity(isDark ? 0.25 : 0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            _getCategoryLabel(type).toUpperCase(),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: accentColor,
                            ),
                          ),
                        ),
                        if (isPinned) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.push_pin, size: 14, color: Colors.amber),
                        ],
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => setState(() => _selectedAnnouncement = null),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$author · $dateStr',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? AppColors.darkSecondaryText : const Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 12),
                Divider(height: 1, color: isDark ? AppColors.darkBordersAndDividers : const Color(0xFFE5E7EB)),
                const SizedBox(height: 12),
                Flexible(
                  child: SingleChildScrollView(
                    child: Text(
                      content,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.6,
                        color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText,
                      ),
                    ),
                  ),
                ),
                if (linkUrl.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('View Attachment / Link', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
