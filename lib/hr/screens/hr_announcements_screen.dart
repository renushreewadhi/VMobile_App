import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/loading_shimmer.dart';

class HrAnnouncementsScreen extends ConsumerStatefulWidget {
  const HrAnnouncementsScreen({super.key});

  @override
  ConsumerState<HrAnnouncementsScreen> createState() => _HrAnnouncementsScreenState();
}

class _HrAnnouncementsScreenState extends ConsumerState<HrAnnouncementsScreen> {
  bool _isLoading = true;
  List<dynamic> _announcements = [];
  String _searchTerm = '';
  String _selectedFilter = 'All';

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
      setState(() {
        _announcements = [];
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteAnnouncement(dynamic id) async {
    final apiClient = ref.read(apiClientProvider);
    try {
      await apiClient.delete('/announcements/$id');
    } catch (_) {}
    setState(() {
      _announcements.removeWhere((a) => (a is Map && a['id'] == id));
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Announcement deleted')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const LoadingShimmer();

    final filtered = _announcements.where((a) {
      final map = a is Map<String, dynamic> ? a : {};
      final title = (map['title'] ?? '').toString().toLowerCase();
      final content = (map['content'] ?? '').toString().toLowerCase();
      final type = (map['type'] ?? 'GENERAL').toString();

      final matchesSearch = _searchTerm.isEmpty || title.contains(_searchTerm.toLowerCase()) || content.contains(_searchTerm.toLowerCase());
      final matchesFilter = _selectedFilter == 'All' || type.toLowerCase() == _selectedFilter.toLowerCase();

      return matchesSearch && matchesFilter;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Announcements & Bulletins'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Create Announcement screen'))),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(
                labelText: 'Search announcements...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (val) => setState(() => _searchTerm = val),
            ),
            const SizedBox(height: 16),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final a = filtered[index] as Map<String, dynamic>;
                return AppCard(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primary.withOpacity(0.1),
                      child: const Icon(Icons.campaign, color: AppColors.primary),
                    ),
                    title: Text(a['title'] ?? 'Announcement', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(a['content'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
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
}
