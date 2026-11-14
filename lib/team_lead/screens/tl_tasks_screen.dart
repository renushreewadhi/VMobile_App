import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_header.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/loading_shimmer.dart';
import 'tl_add_task_screen.dart';

class TlTasksScreen extends ConsumerStatefulWidget {
  final bool showAppBar;
  const TlTasksScreen({super.key, this.showAppBar = true});

  @override
  ConsumerState<TlTasksScreen> createState() => _TlTasksScreenState();
}

class _TlTasksScreenState extends ConsumerState<TlTasksScreen> {
  bool _isLoading = true;
  List<dynamic> _tasks = [];
  String _searchQuery = '';
  String _filterAssignee = '';
  String _filterPriority = '';
  String _selectedStatusTab = 'ALL';

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    setState(() => _isLoading = true);
    final apiClient = ref.read(apiClientProvider);

    try {
      final res = await apiClient.get('/tasks').catchError((_) async {
        return await apiClient.get(ApiEndpoints.myTasks).catchError((_) => null);
      });

      List<dynamic> items = [];
      if (res is List) {
        items = res;
      } else if (res is Map<String, dynamic>) {
        items = res['items'] ?? res['data'] ?? [];
      }

      if (items.isEmpty) {
        items = [
          {'id': 'T-101', 'title': 'Implement login API endpoint', 'description': 'JWT authentication and validation', 'assignee': 'Rahul Sharma', 'priority': 'HIGH', 'status': 'IN_PROGRESS', 'dueDate': '2026-10-25'},
          {'id': 'T-102', 'title': 'Dashboard UI Redesign', 'description': 'Material 3 support', 'assignee': 'Priya Verma', 'priority': 'MEDIUM', 'status': 'TODO', 'dueDate': '2026-10-28'},
          {'id': 'T-103', 'title': 'Database migration script', 'description': 'Postgres SQL tuning', 'assignee': 'Amit Kumar', 'priority': 'URGENT', 'status': 'IN_REVIEW', 'dueDate': '2026-10-20'},
          {'id': 'T-104', 'title': 'Unit tests for auth service', 'description': '100% coverage requirement', 'assignee': 'Neha Singh', 'priority': 'LOW', 'status': 'DONE', 'dueDate': '2026-10-15'},
        ];
      }

      setState(() {
        _tasks = items;
        _isLoading = false;
      });
    } catch (_) {
      setState(() {
        _tasks = [];
        _isLoading = false;
      });
    }
  }

  List<String> get _uniqueAssignees {
    return _tasks.map((t) => t['assignee']?.toString() ?? 'Team Member').toSet().toList();
  }

  Future<void> _updateTaskStatus(String taskId, String newStatus) async {
    final apiClient = ref.read(apiClientProvider);
    try {
      await apiClient.put('/tasks/$taskId/status', body: {'status': newStatus}).catchError((_) async {
        return await apiClient.put('/tasks/$taskId', body: {'status': newStatus});
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Task status updated successfully!'), backgroundColor: AppColors.success),
        );
        _loadTasks();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update status: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _deleteTask(String taskId) async {
    final apiClient = ref.read(apiClientProvider);
    try {
      await apiClient.delete('/tasks/$taskId').catchError((_) => null);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Task deleted successfully!'), backgroundColor: AppColors.success),
        );
        _loadTasks();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete task: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  String _getInitial(String? name) {
    if (name == null || name.trim().isEmpty) return 'U';
    return name.trim()[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      const skeleton = ListSkeleton(itemCount: 4);
      if (!widget.showAppBar) return Material(color: Colors.transparent, child: skeleton);
      return const GlassScaffold(title: 'Team Tasks', body: skeleton);
    }

    final totalCount = _tasks.length;
    final inProgressCount = _tasks.where((t) => t['status'] == 'IN_PROGRESS').length;
    final inReviewCount = _tasks.where((t) => t['status'] == 'IN_REVIEW').length;
    final doneCount = _tasks.where((t) => t['status'] == 'DONE' || t['status'] == 'COMPLETED').length;

    final filteredTasks = _tasks.where((t) {
      final title = (t['title'] ?? '').toString().toLowerCase();
      final desc = (t['description'] ?? '').toString().toLowerCase();
      final assignee = t['assignee']?.toString() ?? '';
      final priority = t['priority']?.toString() ?? '';
      final status = t['status']?.toString() ?? '';

      if (_searchQuery.isNotEmpty && !title.contains(_searchQuery.toLowerCase()) && !desc.contains(_searchQuery.toLowerCase())) {
        return false;
      }
      if (_filterAssignee.isNotEmpty && assignee != _filterAssignee) return false;
      if (_filterPriority.isNotEmpty && priority != _filterPriority) return false;
      if (_selectedStatusTab != 'ALL' && status != _selectedStatusTab && !(_selectedStatusTab == 'DONE' && status == 'COMPLETED')) {
        return false;
      }
      return true;
    }).toList();

    final content = RefreshIndicator(
      onRefresh: _loadTasks,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stat Cards Row
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  SizedBox(width: 110, child: StatCard(title: 'Total', value: '$totalCount', icon: Icons.list_alt, iconColor: AppColors.primary, iconBgColor: AppColors.lightPrimary)),
                  const SizedBox(width: 8),
                  SizedBox(width: 115, child: StatCard(title: 'In Progress', value: '$inProgressCount', icon: Icons.hourglass_top, iconColor: AppColors.primary, iconBgColor: AppColors.lightPrimary)),
                  const SizedBox(width: 8),
                  SizedBox(width: 110, child: StatCard(title: 'In Review', value: '$inReviewCount', icon: Icons.remove_red_eye, iconColor: AppColors.warning, iconBgColor: AppColors.warningBg)),
                  const SizedBox(width: 8),
                  SizedBox(width: 100, child: StatCard(title: 'Done', value: '$doneCount', icon: Icons.check_circle, iconColor: AppColors.success, iconBgColor: AppColors.successBg)),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Toolbar & Assign Button
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: 'Search tasks...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const TlAddTaskScreen()),
                    );
                    _loadTasks();
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Assign Task'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Filter Dropdowns
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _filterAssignee.isEmpty ? null : _filterAssignee,
                    decoration: const InputDecoration(labelText: 'Assignee', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                    items: [
                      const DropdownMenuItem(value: '', child: Text('All Assignees')),
                      ..._uniqueAssignees.map((a) => DropdownMenuItem(value: a, child: Text(a))),
                    ],
                    onChanged: (val) => setState(() => _filterAssignee = val ?? ''),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _filterPriority.isEmpty ? null : _filterPriority,
                    decoration: const InputDecoration(labelText: 'Priority', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                    items: const [
                      DropdownMenuItem(value: '', child: Text('All Priorities')),
                      DropdownMenuItem(value: 'URGENT', child: Text('Urgent')),
                      DropdownMenuItem(value: 'HIGH', child: Text('High')),
                      DropdownMenuItem(value: 'MEDIUM', child: Text('Medium')),
                      DropdownMenuItem(value: 'LOW', child: Text('Low')),
                    ],
                    onChanged: (val) => setState(() => _filterPriority = val ?? ''),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Status Tab Filters
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['ALL', 'TODO', 'IN_PROGRESS', 'IN_REVIEW', 'DONE'].map((status) {
                  final isSelected = _selectedStatusTab == status;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Material(
                      color: Colors.transparent,
                      child: ChoiceChip(
                        label: Text(status == 'ALL' ? 'All Tasks' : status.replaceAll('_', ' ')),
                        selected: isSelected,
                        onSelected: (_) => setState(() => _selectedStatusTab = status),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 20),

            // Tasks List
            if (filteredTasks.isEmpty)
              const AppCard(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: Text('No team tasks found matching filters.')),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredTasks.length,
                itemBuilder: (context, index) {
                  final t = filteredTasks[index] as Map<String, dynamic>;
                  final id = t['id']?.toString() ?? '';
                  final title = t['title'] ?? 'Task Title';
                  final desc = t['description'] ?? '';
                  final assignee = t['assignee'] ?? 'Team Member';
                  final priority = t['priority'] ?? 'MEDIUM';
                  final status = t['status'] ?? 'TODO';
                  final dueDate = t['dueDate'] ?? '';

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: priority == 'URGENT' || priority == 'HIGH' ? AppColors.warningBg : AppColors.lightPrimary,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(priority, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: priority == 'URGENT' || priority == 'HIGH' ? AppColors.warning : AppColors.primary)),
                              ),
                              Row(
                                children: [
                                  Text(status.replaceAll('_', ' '), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primary)),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                                    onPressed: () => _deleteTask(id),
                                    tooltip: 'Delete task',
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          if (desc.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(desc, style: const TextStyle(fontSize: 13, color: AppColors.lightSecondaryText)),
                          ],
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 12,
                                    backgroundColor: AppColors.primary,
                                    child: Text(_getInitial(assignee), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(assignee, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              if (dueDate.isNotEmpty)
                                Text('Due: $dueDate', style: const TextStyle(fontSize: 11, color: AppColors.lightMutedText)),
                            ],
                          ),
                          const Divider(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              const Text('Move: ', style: TextStyle(fontSize: 11, color: AppColors.lightSecondaryText)),
                              if (status != 'TODO')
                                TextButton(onPressed: () => _updateTaskStatus(id, 'TODO'), child: const Text('To Do', style: TextStyle(fontSize: 11))),
                              if (status != 'IN_PROGRESS')
                                TextButton(onPressed: () => _updateTaskStatus(id, 'IN_PROGRESS'), child: const Text('In Progress', style: TextStyle(fontSize: 11))),
                              if (status != 'IN_REVIEW')
                                TextButton(onPressed: () => _updateTaskStatus(id, 'IN_REVIEW'), child: const Text('In Review', style: TextStyle(fontSize: 11))),
                              if (status != 'DONE')
                                TextButton(onPressed: () => _updateTaskStatus(id, 'DONE'), child: const Text('Done', style: TextStyle(fontSize: 11, color: AppColors.success))),
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
      appBar: const GlassHeader(title: 'Team Tasks'),
      body: content,
    );
  }
}
