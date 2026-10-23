import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/loading_shimmer.dart';
import 'hr_team_detail_screen.dart';
import 'hr_team_form_screen.dart';

class HrTeamsScreen extends ConsumerStatefulWidget {
  const HrTeamsScreen({super.key});

  @override
  ConsumerState<HrTeamsScreen> createState() => _HrTeamsScreenState();
}

class _HrTeamsScreenState extends ConsumerState<HrTeamsScreen> {
  bool _isLoading = true;
  List<dynamic> _teams = [];
  String _searchTerm = '';

  @override
  void initState() {
    super.initState();
    _loadTeams();
  }

  Future<void> _loadTeams() async {
    setState(() => _isLoading = true);
    final apiClient = ref.read(apiClientProvider);
    try {
      final res = await apiClient.get('/departments/teams').catchError((_) => null);
      List<dynamic> items = [];
      if (res is List) {
        items = res;
      } else if (res is Map<String, dynamic>) {
        items = res['items'] ?? res['data'] ?? [];
      }

      if (items.isEmpty) {
        items = [
          {'id': '1', 'name': 'Alpha Squad', 'departmentName': 'Engineering', 'teamLeadName': 'Michael Chen', 'memberCount': 8, 'status': 'Active'},
          {'id': '2', 'name': 'Growth Team', 'departmentName': 'Marketing', 'teamLeadName': 'Emily Davis', 'memberCount': 6, 'status': 'Active'},
        ];
      }

      setState(() {
        _teams = items;
        _isLoading = false;
      });
    } catch (_) {
      setState(() {
        _teams = [];
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const LoadingShimmer();

    final filtered = _teams.where((t) {
      final map = t is Map<String, dynamic> ? t : {};
      final name = (map['name'] ?? '').toString().toLowerCase();
      final dept = (map['departmentName'] ?? '').toString().toLowerCase();
      return _searchTerm.isEmpty || name.contains(_searchTerm.toLowerCase()) || dept.contains(_searchTerm.toLowerCase());
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Teams Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.group_add),
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const HrTeamFormScreen()));
              _loadTeams();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(
                labelText: 'Search teams by name or department...',
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
                final t = filtered[index] as Map<String, dynamic>;
                return AppCard(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(t['name'] ?? 'Team', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('${t['departmentName'] ?? 'General'} • Lead: ${t['teamLeadName'] ?? 'Unassigned'} • ${t['memberCount'] ?? 0} members'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Chip(label: Text(t['status'] ?? 'Active')),
                        IconButton(
                          icon: const Icon(Icons.edit, size: 20, color: AppColors.primary),
                          onPressed: () async {
                            await Navigator.push(context, MaterialPageRoute(builder: (_) => HrTeamFormScreen(teamId: t['id'], initialData: t)));
                            _loadTeams();
                          },
                        ),
                      ],
                    ),
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => HrTeamDetailScreen(teamId: t['id'] ?? '1')));
                    },
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
