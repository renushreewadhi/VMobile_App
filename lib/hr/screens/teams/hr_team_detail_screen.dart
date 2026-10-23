import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/loading_shimmer.dart';
import 'hr_team_form_screen.dart';

class HrTeamDetailScreen extends ConsumerStatefulWidget {
  final String teamId;

  const HrTeamDetailScreen({super.key, required this.teamId});

  @override
  ConsumerState<HrTeamDetailScreen> createState() => _HrTeamDetailScreenState();
}

class _HrTeamDetailScreenState extends ConsumerState<HrTeamDetailScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _team;

  @override
  void initState() {
    super.initState();
    _loadTeamDetail();
  }

  Future<void> _loadTeamDetail() async {
    setState(() => _isLoading = true);
    final apiClient = ref.read(apiClientProvider);
    try {
      final res = await apiClient.get('/departments/teams/${widget.teamId}').catchError((_) => null);
      final map = res is Map<String, dynamic> ? (res['data'] ?? res) : null;
      setState(() {
        _team = map;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const LoadingShimmer();
    if (_team == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Team Detail')),
        body: const Center(child: Text('Team not found')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_team!['name'] ?? 'Team Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => HrTeamFormScreen(teamId: widget.teamId, initialData: _team)),
              );
              _loadTeamDetail();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppCard(
              backgroundColor: AppColors.primary,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_team!['name'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('Department: ${_team!['departmentName'] ?? 'General'} • Lead: ${_team!['teamLeadName'] ?? 'Unassigned'}', style: const TextStyle(color: Colors.white70)),
                  const SizedBox(height: 8),
                  Text(_team!['description'] ?? 'No description provided.', style: const TextStyle(color: Color(0xDDFFFFFF), fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
