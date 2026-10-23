import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/compact_summary_widgets.dart';
import '../../shared/widgets/loading_shimmer.dart';

class AnnouncementsScreen extends ConsumerStatefulWidget {
  const AnnouncementsScreen({super.key});

  @override
  ConsumerState<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends ConsumerState<AnnouncementsScreen> {
  bool _isLoading = true;
  List<dynamic> _announcements = [];
  String _selectedFilter = 'All';
  String _searchTerm = '';
  String _sortBy = 'newest';
  Map<String, dynamic>? _selectedAnnouncement;

  final List<Map<String, String>> _announcementTypes = [
    {'value': 'FESTIVAL', 'label': 'Festival'},
    {'value': 'HOLIDAY', 'label': 'Holiday'},
    {'value': 'COMPANY_EVENT', 'label': 'Event'},
    {'value': 'GENERAL', 'label': 'General'},
    {'value': 'POLICY_UPDATE', 'label': 'Policy'},
    {'value': 'TRAINING', 'label': 'Training'},
    {'value': 'EMERGENCY', 'label': 'Emergency'},
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
      if (mounted) {
        setState(() {
          if (res is List) {
            _announcements = res;
          } else if (res is Map<String, dynamic> && res['data'] is List) {
            _announcements = res['data'];
          } else {
            _announcements = [];
          }
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
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

    if (_sortBy == 'newest') {
      list.sort((a, b) => DateTime.parse(b['publishedDate'] ?? b['createdAt'] ?? '2026-01-01').compareTo(DateTime.parse(a['publishedDate'] ?? a['createdAt'] ?? '2026-01-01')));
    } else if (_sortBy == 'oldest') {
      list.sort((a, b) => DateTime.parse(a['publishedDate'] ?? a['createdAt'] ?? '2026-01-01').compareTo(DateTime.parse(b['publishedDate'] ?? b['createdAt'] ?? '2026-01-01')));
    } else if (_sortBy == 'priority') {
      Map<String, int> weight = {'CRITICAL': 3, 'IMPORTANT': 2, 'NORMAL': 1};
      list.sort((a, b) => (weight[b['priority']] ?? 0).compareTo(weight[a['priority']] ?? 0));
    }

    return list;
  }

  int get _pinnedCount => _announcements.where((a) => a['isPinned'] == true).length;
  int get _criticalCount => _announcements.where((a) => a['priority'] == 'CRITICAL').length;

  Color _getTypeColor(String? type) {
    switch (type) {
      case 'FESTIVAL': return Colors.amber;
      case 'HOLIDAY': return Colors.lightBlue;
      case 'EMERGENCY': return Colors.red;
      case 'POLICY_UPDATE': return Colors.pink;
      case 'TRAINING': return Colors.green;
      default: return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Announcements & Bulletins')),
      body: _isLoading
          ? const ListSkeleton(itemCount: 4)
          : RefreshIndicator(
              onRefresh: _fetchAnnouncements,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. PASTEL SUMMARY PILLS
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: [
                          PastelSummaryPill(
                            label: '${_announcements.length} Total Notices',
                            variant: PastelPillVariant.blue,
                            onTap: () => setState(() => _selectedFilter = 'All'),
                          ),
                          const SizedBox(width: 8),
                          PastelSummaryPill(
                            label: '$_pinnedCount Pinned',
                            variant: PastelPillVariant.amber,
                            onTap: () => setState(() => _selectedFilter = 'Pinned'),
                          ),
                          const SizedBox(width: 8),
                          PastelSummaryPill(
                            label: '$_criticalCount Critical',
                            variant: PastelPillVariant.purple,
                            onTap: () => setState(() => _selectedFilter = 'EMERGENCY'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // 2. Filter Chips Scrollable
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _filterChip('All', _announcements.length),
                          _filterChip('Pinned', _pinnedCount),
                          ..._announcementTypes.map((t) => _filterChip(t['value']!, _announcements.where((a) => a['type'] == t['value']).length, label: t['label'])),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 3. Search & Sort Bar
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSecondarySurface : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: isDark ? AppColors.darkBordersAndDividers : AppColors.lightBordersAndDividers),
                      ),
                      child: Column(
                        children: [
                          TextField(
                            onChanged: (val) => setState(() => _searchTerm = val),
                            decoration: InputDecoration(
                              hintText: 'Search announcements...',
                              prefixIcon: const Icon(Icons.search, size: 20),
                              suffixIcon: _searchTerm.isNotEmpty ? IconButton(icon: const Icon(Icons.clear, size: 16), onPressed: () => setState(() => _searchTerm = '')) : null,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                              filled: true,
                              fillColor: isDark ? AppColors.darkMainSurface : AppColors.lightInputBackground,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              const Text('Sort by: ', style: TextStyle(fontSize: 12, color: AppColors.lightSecondaryText)),
                              DropdownButton<String>(
                                value: _sortBy,
                                underline: const SizedBox.shrink(),
                                items: const [
                                  DropdownMenuItem(value: 'newest', child: Text('Newest First', style: TextStyle(fontSize: 12))),
                                  DropdownMenuItem(value: 'oldest', child: Text('Oldest First', style: TextStyle(fontSize: 12))),
                                  DropdownMenuItem(value: 'priority', child: Text('Priority', style: TextStyle(fontSize: 12))),
                                ],
                                onChanged: (val) {
                                  if (val != null) setState(() => _sortBy = val);
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 4. Feed List
                    _filteredAnnouncements.isEmpty
                        ? AppCard(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                children: [
                                  const Icon(Icons.campaign, size: 40, color: AppColors.lightMutedText),
                                  const SizedBox(height: 12),
                                  const Text('No Announcements Found', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  const SizedBox(height: 4),
                                  const Text('No notices match your search criteria.', style: TextStyle(fontSize: 12, color: AppColors.lightSecondaryText)),
                                  const SizedBox(height: 16),
                                  ElevatedButton.icon(
                                    onPressed: () => setState(() { _selectedFilter = 'All'; _searchTerm = ''; }),
                                    icon: const Icon(Icons.refresh, size: 14),
                                    label: const Text('Reset Filters'),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _filteredAnnouncements.length,
                            itemBuilder: (context, index) {
                              final a = _filteredAnnouncements[index];
                              final isPinned = a['isPinned'] == true;
                              final isCritical = a['priority'] == 'CRITICAL';
                              final typeColor = _getTypeColor(a['type']);

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: InkWell(
                                  onTap: () => setState(() => _selectedAnnouncement = a),
                                  borderRadius: BorderRadius.circular(16),
                                  child: AppCard(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(10),
                                              decoration: BoxDecoration(color: typeColor.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                                              child: Icon(Icons.campaign, color: typeColor, size: 20),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(a['title']?.toString() ?? 'Notice', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                                  const SizedBox(height: 2),
                                                  Text(a['authorName']?.toString() ?? 'HR Team', style: const TextStyle(fontSize: 11, color: AppColors.lightSecondaryText)),
                                                ],
                                              ),
                                            ),
                                            if (isPinned)
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                decoration: BoxDecoration(color: Colors.amber.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                                                child: const Text('Pinned', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.amber)),
                                              ),
                                            if (isCritical && !isPinned)
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                decoration: BoxDecoration(color: Colors.red.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                                                child: const Text('Critical', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.red)),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          a['content']?.toString() ?? a['message']?.toString() ?? '',
                                          style: const TextStyle(fontSize: 13.5, color: AppColors.lightPrimaryText),
                                          maxLines: 3,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 12),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          children: [
                                            TextButton.icon(
                                              onPressed: () => setState(() => _selectedAnnouncement = a),
                                              icon: const Icon(Icons.arrow_forward, size: 14),
                                              label: const Text('View Full Notice', style: TextStyle(fontSize: 12)),
                                            ),
                                          ],
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
            ),
      bottomSheet: _selectedAnnouncement != null ? _buildDetailBottomSheet(context) : null,
    );
  }

  Widget _filterChip(String key, int count, {String? label}) {
    final isSelected = _selectedFilter == key;
    final displayLabel = label ?? key;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text('$displayLabel ($count)', style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
        selected: isSelected,
        onSelected: (selected) {
          if (selected) setState(() => _selectedFilter = key);
        },
      ),
    );
  }

  Widget _buildDetailBottomSheet(BuildContext context) {
    final a = _selectedAnnouncement!;
    return Container(
      padding: const EdgeInsets.all(20),
      constraints: const BoxConstraints(maxHeight: 500),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20)],
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
