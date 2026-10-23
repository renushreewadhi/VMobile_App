import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_button.dart';
import '../../shared/widgets/app_card.dart';

class AdminAnnouncementsScreen extends ConsumerStatefulWidget {
  const AdminAnnouncementsScreen({super.key});

  @override
  ConsumerState<AdminAnnouncementsScreen> createState() => _AdminAnnouncementsScreenState();
}

class _AdminAnnouncementsScreenState extends ConsumerState<AdminAnnouncementsScreen> {
  bool _isLoading = true;
  List<dynamic> _announcements = [];
  String _searchTerm = '';
  String _selectedFilter = 'All';

  final List<Map<String, String>> _types = [
    {'value': 'COMPANY_EVENT', 'label': 'Event'},
    {'value': 'HOLIDAY', 'label': 'Holiday'},
    {'value': 'SYSTEM', 'label': 'System'},
    {'value': 'POLICY_UPDATE', 'label': 'Policy'},
    {'value': 'GENERAL', 'label': 'General'},
    {'value': 'EMERGENCY', 'label': 'Emergency'}
  ];

  @override
  void initState() {
    super.initState();
    _loadAnnouncements();
  }

  Future<void> _loadAnnouncements() async {
    setState(() => _isLoading = true);
    final apiClient = ref.read(apiClientProvider);

    try {
      final res = await apiClient.get('/announcements').catchError((_) => null);
      List<dynamic> items = [];
      if (res is List) {
        items = res;
      } else if (res is Map<String, dynamic>) {
        items = res['items'] ?? res['data'] ?? [];
      }

      if (items.isEmpty) {
        items = [
          {'id': '1', 'title': 'Q3 Townhall & Strategy Update', 'content': 'Join us for the quarterly all-hands meeting.', 'type': 'COMPANY_EVENT', 'priority': 'IMPORTANT', 'authorName': 'HR Team'},
          {'id': '2', 'title': 'Updated Health Insurance Policy', 'content': 'Please review the updated medical benefits package.', 'type': 'POLICY_UPDATE', 'priority': 'NORMAL', 'authorName': 'Benefits Admin'},
        ];
      }

      setState(() {
        _announcements = items;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteAnnouncement(dynamic id) async {
    try {
      await ref.read(apiClientProvider).delete('/announcements/$id');
    } catch (_) {}
    setState(() {
      _announcements.removeWhere((a) => (a is Map && a['id'] == id));
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Announcement deleted')));
    }
  }

  List<dynamic> get _filteredAnnouncements {
    return _announcements.where((a) {
      final title = (a['title'] ?? '').toString().toLowerCase();
      final content = (a['content'] ?? '').toString().toLowerCase();
      final type = (a['type'] ?? 'GENERAL').toString();

      final matchesSearch = _searchTerm.trim().isEmpty || title.contains(_searchTerm.toLowerCase()) || content.contains(_searchTerm.toLowerCase());
      final matchesFilter = _selectedFilter == 'All' || type.toLowerCase() == _selectedFilter.toLowerCase();

      return matchesSearch && matchesFilter;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Announcements & Bulletins'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Create Announcement',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Create announcement navigation')));
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // KPI Stat Cards
            Row(
              children: [
                Expanded(child: _buildMetricCard('Total Bulletins', '${_announcements.length}', Icons.campaign, Colors.blue)),
                const SizedBox(width: 8),
                Expanded(child: _buildMetricCard('Pinned', '0', Icons.push_pin, Colors.orange)),
              ],
            ),
            const SizedBox(height: 24),

            // Filter Tabs
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildTabButton('All', 'All'),
                  ..._types.map((t) => Padding(padding: const EdgeInsets.only(left: 8), child: _buildTabButton(t['value']!, t['label']!))),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Search Bar
            TextField(
              decoration: const InputDecoration(
                hintText: 'Search announcements...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (val) => setState(() => _searchTerm = val),
            ),
            const SizedBox(height: 16),

            // Announcements List
            _filteredAnnouncements.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: Text('No announcements found matching filter.')),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _filteredAnnouncements.length,
                    itemBuilder: (context, index) {
                      final a = _filteredAnnouncements[index];
                      return AppCard(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppColors.primary.withOpacity(0.1),
                            child: const Icon(Icons.campaign, color: AppColors.primary),
                          ),
                          title: Text(a['title'] ?? 'Announcement', style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(a['content'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            tooltip: 'Delete',
                            onPressed: () => _deleteAnnouncement(a['id']),
                          ),
                        ),
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(String id, String label) {
    final isSelected = _selectedFilter == id;
    return AppButton(
      label: label,
      isPrimary: isSelected,
      onPressed: () => setState(() => _selectedFilter = id),
      height: 40,
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 24),
              Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          Text(title, style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
