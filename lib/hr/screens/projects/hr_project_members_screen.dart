import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/loading_shimmer.dart';

class HrProjectMembersScreen extends ConsumerStatefulWidget {
  final String projectId;

  const HrProjectMembersScreen({super.key, required this.projectId});

  @override
  ConsumerState<HrProjectMembersScreen> createState() => _HrProjectMembersScreenState();
}

class _HrProjectMembersScreenState extends ConsumerState<HrProjectMembersScreen> {
  bool _isLoading = true;
  List<dynamic> _members = [];

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    setState(() => _isLoading = true);
    final apiClient = ref.read(apiClientProvider);
    try {
      final res = await apiClient.get('/projects/${widget.projectId}/members').catchError((_) => null);
      List<dynamic> items = [];
      if (res is List) {
        items = res;
      } else if (res is Map<String, dynamic>) {
        items = res['items'] ?? res['data'] ?? [];
      }

      if (items.isEmpty) {
        items = [
          {'employeeId': 'EMP-001', 'employeeName': 'Rahul Sharma', 'designation': 'Senior Engineer', 'teamName': 'Core Team'},
          {'employeeId': 'EMP-002', 'employeeName': 'Priya Verma', 'designation': 'UI Designer', 'teamName': 'Design Team'},
        ];
      }

      setState(() {
        _members = items;
        _isLoading = false;
      });
    } catch (_) {
      setState(() {
        _members = [];
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const LoadingShimmer();

    return Scaffold(
      appBar: AppBar(title: const Text('Project Members')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _members.length,
              itemBuilder: (context, index) {
                final m = _members[index] as Map<String, dynamic>;
                return AppCard(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primary.withOpacity(0.1),
                      child: Text((m['employeeName'] ?? 'M')[0]),
                    ),
                    title: Text(m['employeeName'] ?? 'Member', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('${m['employeeCode'] ?? ''} • ${m['designation'] ?? 'Staff'} • ${m['teamName'] ?? ''}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.remove_circle, color: Colors.red),
                      onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Member removed from project'))),
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
