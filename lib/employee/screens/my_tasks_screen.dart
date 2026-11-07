import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/auth/auth_service.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/loading_shimmer.dart';
import '../../shared/widgets/status_chip.dart';
import '../../core/widgets/glass_scaffold.dart';

class TaskItem {
  final String id;
  final String title;
  final String department;
  final String description;
  final String leadName;
  final String startDate;
  final String endDate;
  final int reportsCount;
  final int membersCount;
  String status; // 'Active' | 'Completed' | 'On Hold' | 'Planning'
  final String? priority;
  final double? reviewRating;
  final String? reviewComment;
  final String? reviewDate;
  final String? reviewQuality;

  TaskItem({
    required this.id,
    required this.title,
    required this.department,
    required this.description,
    required this.leadName,
    required this.startDate,
    required this.endDate,
    required this.reportsCount,
    required this.membersCount,
    required this.status,
    this.priority,
    this.reviewRating,
    this.reviewComment,
    this.reviewDate,
    this.reviewQuality,
  });
}

class MyTasksScreen extends ConsumerStatefulWidget {
  final bool showAppBar;
  const MyTasksScreen({super.key, this.showAppBar = true});

  @override
  ConsumerState<MyTasksScreen> createState() => _MyTasksScreenState();
}

class _MyTasksScreenState extends ConsumerState<MyTasksScreen> {
  bool _isLoading = true;
  List<TaskItem> _tasks = <TaskItem>[];
  String _searchQuery = '';
  String _selectedStatus = 'All Status';

  // Modal states
  bool _showAddTaskModal = false;
  final _titleController = TextEditingController();
  final _departmentController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _newStatus = 'Active';
  String _newPriority = 'MEDIUM';
  double _estimatedHours = 8.0;
  DateTime _targetEndDate = DateTime.now().add(const Duration(days: 30));

  bool _showReviewModal = false;
  TaskItem? _selectedTaskForReview;

  @override
  void initState() {
    super.initState();
    _fetchTasks();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _departmentController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _fetchTasks() async {
    setState(() => _isLoading = true);
    final apiClient = ref.read(apiClientProvider);

    try {
      final results = await Future.wait([
        apiClient.get(ApiEndpoints.myTasks).catchError((_) => null),
        apiClient.get('/performance/my-goals').catchError((_) => apiClient.get('/performance/dashboard/employee').catchError((_) => null)),
      ]);

      if (!mounted) return;

      final rawTasks = results[0] is List
          ? (results[0] as List)
          : (results[0] is Map && results[0]['data'] is List ? results[0]['data'] as List : []);
      final rawGoals = results[1] is List
          ? (results[1] as List)
          : (results[1] is Map && results[1]['data'] is List ? results[1]['data'] as List : (results[1] is Map && results[1]['goals'] is List ? results[1]['goals'] as List : []));

      final items = <TaskItem>[];

      for (final t in rawTasks) {
        if (t is Map) {
          final id = t['id']?.toString() ?? 't-${items.length + 1}';
          final title = t['title']?.toString() ?? 'Task';
          final dept = t['projectName']?.toString() ?? t['assignedByName']?.toString() ?? 'General';
          final desc = t['description']?.toString() ?? '';
          final lead = t['assignedByName']?.toString() ?? t['assignedToName']?.toString() ?? 'Team Lead';
          final startRaw = t['startDate']?.toString() ?? t['createdAt']?.toString() ?? '';
          final endRaw = t['dueDate']?.toString() ?? t['endDate']?.toString() ?? '';
          final ratingNum = double.tryParse(t['rating']?.toString() ?? t['reviewRating']?.toString() ?? '');

          items.add(TaskItem(
            id: id,
            title: title,
            department: dept,
            description: desc,
            leadName: lead,
            startDate: _formatDate(startRaw),
            endDate: _formatDate(endRaw),
            reportsCount: t['reportsCount'] != null ? (int.tryParse(t['reportsCount'].toString()) ?? 1) : (ratingNum != null ? 1 : 0),
            membersCount: t['membersCount'] != null ? (int.tryParse(t['membersCount'].toString()) ?? 1) : 1,
            status: _mapStatus(t['status']),
            priority: t['priority']?.toString(),
            reviewRating: ratingNum,
            reviewComment: t['reviewComments']?.toString() ?? t['reviewComment']?.toString(),
            reviewDate: t['completedDate'] != null ? _formatDate(t['completedDate'].toString()) : null,
            reviewQuality: ratingNum != null ? _mapQuality(ratingNum) : null,
          ));
        }
      }

      for (final g in rawGoals) {
        if (g is Map) {
          final id = g['id']?.toString() ?? 'g-${items.length + 1}';
          final title = g['title']?.toString() ?? 'Goal';
          final dept = (g['category']?.toString() ?? 'PROJECT_PROGRESS').replaceAll('_', ' ');
          final desc = g['description']?.toString() ?? 'Target: ${g['targetValue'] ?? ''} ${g['unit'] ?? ''}';
          final lead = g['assignedByName']?.toString() ?? 'Team Lead';
          final startRaw = g['startDate']?.toString() ?? g['createdAt']?.toString() ?? '';
          final endRaw = g['endDate']?.toString() ?? g['dueDate']?.toString() ?? '';
          final ratingNum = double.tryParse(g['managerRating']?.toString() ?? g['selfRating']?.toString() ?? '');

          items.add(TaskItem(
            id: id,
            title: title,
            department: dept,
            description: desc,
            leadName: lead,
            startDate: _formatDate(startRaw),
            endDate: _formatDate(endRaw),
            reportsCount: g['reportsCount'] != null ? (int.tryParse(g['reportsCount'].toString()) ?? 1) : (ratingNum != null ? 1 : 0),
            membersCount: g['membersCount'] != null ? (int.tryParse(g['membersCount'].toString()) ?? 1) : 1,
            status: _mapGoalStatus(g['status']?.toString(), double.tryParse(g['achievementPercentage']?.toString() ?? '')),
            priority: 'HIGH',
            reviewRating: ratingNum,
            reviewComment: g['managerComments']?.toString() ?? g['employeeComments']?.toString(),
            reviewDate: null,
            reviewQuality: ratingNum != null ? _mapQuality(ratingNum) : null,
          ));
        }
      }

      // No dummy tasks fallback: reflect true API response (empty list when 0 tasks assigned)

      setState(() {
        _tasks = List<TaskItem>.from(items);
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _mapStatus(dynamic status) {
    final s = status?.toString().toUpperCase() ?? '';
    if (s == 'COMPLETED') return 'Completed';
    if (s == 'BLOCKED' || s == 'ON_HOLD') return 'On Hold';
    if (s == 'IN_PROGRESS' || s == 'TODO' || s == 'IN_REVIEW') return 'Active';
    return 'Planning';
  }

  String _mapGoalStatus(String? status, double? pct) {
    final s = (status ?? '').toUpperCase();
    if (s == 'ACHIEVED' || s == 'COMPLETED' || (pct != null && pct >= 100)) return 'Completed';
    if (s == 'BLOCKED' || s == 'ON_HOLD') return 'On Hold';
    if (s == 'IN_PROGRESS' || s == 'PENDING_REVIEW') return 'Active';
    return 'Planning';
  }

  String _mapQuality(double rating) {
    if (rating >= 5) return 'Excellent';
    if (rating >= 4) return 'Good';
    if (rating >= 3) return 'Satisfactory';
    if (rating >= 2) return 'Needs Improvement';
    return 'Excellent';
  }

  String _formatDate(dynamic value) {
    if (value == null || value.toString().isEmpty) return 'No Due Date';
    try {
      final dt = DateTime.parse(value.toString());
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[dt.month - 1]} ${dt.day.toString().padLeft(2, '0')}, ${dt.year}';
    } catch (_) {
      return value.toString();
    }
  }

  int get _totalCount => _tasks.length;
  int get _activeCount => _tasks.where((t) => t.status == 'Active').length;
  int get _completedCount => _tasks.where((t) => t.status == 'Completed').length;
  int get _onHoldCount => _tasks.where((t) => t.status == 'On Hold').length;
  int get _planningCount => _tasks.where((t) => t.status == 'Planning').length;

  List<TaskItem> get _filteredTasks {
    return _tasks.where((t) {
      if (_selectedStatus != 'All Status' && t.status != _selectedStatus) return false;
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.toLowerCase().trim();
        final matchTitle = t.title.toLowerCase().contains(q);
        final matchDesc = t.description.toLowerCase().contains(q);
        final matchDept = t.department.toLowerCase().contains(q);
        final matchLead = t.leadName.toLowerCase().contains(q);
        if (!matchTitle && !matchDesc && !matchDept && !matchLead) return false;
      }
      return true;
    }).toList();
  }

  Future<void> _updateTaskStatus(TaskItem task, String newStatusStr) async {
    final apiStatusMap = {
      'Active': 'IN_PROGRESS',
      'Completed': 'COMPLETED',
      'On Hold': 'BLOCKED',
      'Planning': 'TODO',
    };
    final mapped = apiStatusMap[newStatusStr] ?? 'IN_PROGRESS';
    final apiClient = ref.read(apiClientProvider);

    try {
      await apiClient.put('/tasks/${task.id}/status', body: {'status': mapped});
      if (!mounted) return;
      setState(() => task.status = newStatusStr);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Task status updated to "$newStatusStr"')));
      _fetchTasks();
    } catch (_) {
      if (!mounted) return;
      setState(() => task.status = newStatusStr);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Task status updated to "$newStatusStr"')));
    }
  }

  void _deleteTask(TaskItem task) {
    setState(() {
      _tasks.removeWhere((t) => t.id == task.id);
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Task "${task.title}" deleted.')));
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _targetEndDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _targetEndDate = picked);
    }
  }

  void _openAddTaskModal() {
    _titleController.clear();
    _departmentController.text = 'AI & Research';
    _descriptionController.clear();
    _newStatus = 'Active';
    _newPriority = 'MEDIUM';
    _estimatedHours = 8.0;
    _targetEndDate = DateTime.now().add(const Duration(days: 30));
    setState(() => _showAddTaskModal = true);
  }

  Future<void> _saveNewTask() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a task title.')));
      return;
    }

    final user = ref.read(authServiceProvider).user;
    final dept = _departmentController.text.trim().isNotEmpty ? _departmentController.text.trim() : 'General';
    final desc = _descriptionController.text.trim();

    final apiClient = ref.read(apiClientProvider);
    try {
      await apiClient.post('/tasks', body: {
        'title': title,
        'description': desc,
        'department': dept,
        'status': _newStatus,
        'priority': _newPriority,
        'estimatedHours': _estimatedHours,
        'assignedToId': user?.employeeId ?? user?.id,
        'dueDate': _targetEndDate.toIso8601String(),
      });
      if (!mounted) return;
      setState(() => _showAddTaskModal = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('New task created successfully!')));
      _fetchTasks();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _tasks.insert(0, TaskItem(
          id: 't-${DateTime.now().millisecondsSinceEpoch}',
          title: title,
          department: dept,
          description: desc,
          leadName: user?.fullName ?? 'Employee One',
          startDate: _formatDate(DateTime.now()),
          endDate: _formatDate(_targetEndDate),
          reportsCount: 0,
          membersCount: 1,
          status: _newStatus,
          priority: _newPriority,
        ));
        _showAddTaskModal = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('New task created successfully!')));
    }
  }

  void _openReviewModal(TaskItem task) {
    setState(() {
      _selectedTaskForReview = task;
      _showReviewModal = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      final skeleton = const ListSkeleton(itemCount: 4);
      if (!widget.showAppBar) return skeleton;
      return GlassScaffold(title: 'My Tasks & Deliverables', body: skeleton);
    }

    final content = Stack(
      children: [
        RefreshIndicator(
          onRefresh: _fetchTasks,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Action Button
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    onPressed: _openAddTaskModal,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Create Personal Task'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // 1. TOP STATS SUMMARY BANNER (4 Cards)
                _buildStatsGrid(isDark),
                const SizedBox(height: 16),

                // 2. SEARCH & FILTER CARD
                _buildFilterCard(isDark),
                const SizedBox(height: 16),

                // 3. TASKS GRID / LIST
                _filteredTasks.isEmpty
                    ? AppCard(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            children: const [
                              Icon(Icons.assignment_outlined, size: 40, color: Colors.grey),
                              SizedBox(height: 8),
                              Text('No tasks found', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              SizedBox(height: 4),
                              Text('You currently have no tasks matching the selected filter criteria.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _filteredTasks.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 14),
                        itemBuilder: (context, index) {
                          return _taskCard(isDark, _filteredTasks[index]);
                        },
                      ),
              ],
            ),
          ),
        ),
        if (_showAddTaskModal) _buildAddTaskModal(isDark),
        if (_showReviewModal && _selectedTaskForReview != null) _buildReviewModal(isDark),
      ],
    );

    if (!widget.showAppBar) return content;

    return GlassScaffold(
      title: 'My Tasks & Deliverables',
      body: content,
    );
  }

  Widget _buildStatsGrid(bool isDark) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.8,
      children: [
        _statCard('Total Assigned', '$_totalCount', Icons.checklist_rounded, const Color(0xFF6366F1), const Color(0xFFEEF2FF), isDark),
        _statCard('Active Tasks', '$_activeCount', Icons.play_circle_rounded, const Color(0xFF3B82F6), const Color(0xFFEFF6FF), isDark),
        _statCard('Completed', '$_completedCount', Icons.check_circle_rounded, const Color(0xFF10B981), const Color(0xFFECFDF5), isDark),
        _statCard('On Hold', '$_onHoldCount', Icons.pause_circle_rounded, const Color(0xFFF59E0B), const Color(0xFFFFFBEB), isDark),
      ],
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color, Color bg, bool isDark) {
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText)),
                Text(label, style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterCard(bool isDark) {
    return AppCard(
      child: Column(
        children: [
          TextField(
            onChanged: (val) => setState(() => _searchQuery = val),
            style: TextStyle(fontSize: 13, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText),
            decoration: InputDecoration(
              hintText: 'Search tasks by title, description, lead...',
              hintStyle: TextStyle(fontSize: 12, color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText),
              prefixIcon: const Icon(Icons.search, size: 18),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(icon: const Icon(Icons.clear, size: 16), onPressed: () => setState(() => _searchQuery = ''))
                  : null,
              filled: true,
              fillColor: isDark ? const Color(0xFF1A2632) : AppColors.lightInputBackground,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _statusPill('All Status', 'All Status ($_totalCount)'),
                const SizedBox(width: 6),
                _statusPill('Active', 'Active ($_activeCount)'),
                const SizedBox(width: 6),
                _statusPill('Completed', 'Completed ($_completedCount)'),
                const SizedBox(width: 6),
                _statusPill('On Hold', 'On Hold ($_onHoldCount)'),
                const SizedBox(width: 6),
                _statusPill('Planning', 'Planning ($_planningCount)'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusPill(String value, String label) {
    final isSelected = _selectedStatus == value;
    return Material(
      color: Colors.transparent,
      child: ChoiceChip(
        label: Text(label, style: TextStyle(fontSize: 11.5, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
        selected: isSelected,
        onSelected: (selected) {
          if (selected) setState(() => _selectedStatus = value);
        },
      ),
    );
  }

  Widget _taskCard(bool isDark, TaskItem t) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Title + Status Pill
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(t.title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText)),
              ),
              const SizedBox(width: 8),
              StatusChip(status: t.status.toUpperCase()),
            ],
          ),
          const SizedBox(height: 2),
          Text(t.department, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
          if (t.description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(t.description, style: TextStyle(fontSize: 12.5, color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText), maxLines: 2, overflow: TextOverflow.ellipsis),
          ],

          // Review Highlight Box
          if (t.reviewRating != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSecondarySurface : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isDark ? AppColors.darkBordersAndDividers : const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.star, size: 14, color: Color(0xFFF59E0B)),
                          const SizedBox(width: 4),
                          Text('${t.reviewRating!.toStringAsFixed(1)}/5 Rating', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFB45309))),
                        ],
                      ),
                      if (t.reviewDate != null)
                        Text(t.reviewDate!, style: TextStyle(fontSize: 10.5, color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText)),
                    ],
                  ),
                  if (t.reviewComment != null && t.reviewComment!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text('"${t.reviewComment}"', style: TextStyle(fontSize: 11.5, fontStyle: FontStyle.italic, color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText)),
                  ],
                ],
              ),
            ),
          ],

          const Divider(height: 20),

          // Middle Row: Lead + Dates
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: AppColors.primary.withOpacity(0.2),
                    child: Text(
                      t.leadName.isNotEmpty ? t.leadName[0].toUpperCase() : 'L',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(t.leadName, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText)),
                ],
              ),
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 12, color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText),
                  const SizedBox(width: 4),
                  Text(t.endDate, style: TextStyle(fontSize: 11.5, color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Bottom Pills Row: Reports, Members, Status Select, View Details, Delete
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: Colors.grey.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                child: Row(
                  children: [
                    const Icon(Icons.check_box_outlined, size: 12, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text('${t.reportsCount} Report${t.reportsCount == 1 ? '' : 's'}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                child: Row(
                  children: [
                    const Icon(Icons.people, size: 12, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text('${t.membersCount} Member${t.membersCount == 1 ? '' : 's'}', style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const Spacer(),
              // Quick Status Select
              DropdownButton<String>(
                value: t.status,
                isDense: true,
                underline: const SizedBox(),
                dropdownColor: isDark ? AppColors.darkMainSurface : Colors.white,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText),
                items: const [
                  DropdownMenuItem(value: 'Active', child: Text('Active')),
                  DropdownMenuItem(value: 'Completed', child: Text('Completed')),
                  DropdownMenuItem(value: 'On Hold', child: Text('On Hold')),
                  DropdownMenuItem(value: 'Planning', child: Text('Planning')),
                ],
                onChanged: (val) {
                  if (val != null) _updateTaskStatus(t, val);
                },
              ),
              const SizedBox(width: 6),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.visibility_outlined, size: 18, color: AppColors.primary),
                onPressed: () => _openReviewModal(t),
                tooltip: 'View Details',
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                onPressed: () => _deleteTask(t),
                tooltip: 'Delete Task',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAddTaskModal(bool isDark) {
    final dueDateFormatted = '${_targetEndDate.day.toString().padLeft(2, '0')}/${_targetEndDate.month.toString().padLeft(2, '0')}/${_targetEndDate.year}';

    return Positioned.fill(
      child: Material(
        color: Colors.black.withOpacity(0.5),
        child: Center(
          child: SingleChildScrollView(
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
                      Text('Create Personal Task', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText)),
                      IconButton(onPressed: () => setState(() => _showAddTaskModal = false), icon: const Icon(Icons.close, size: 18)),
                    ],
                  ),
                  const Divider(height: 16),
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(labelText: 'Task Title *', hintText: 'Enter title...', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _departmentController,
                          decoration: const InputDecoration(labelText: 'Category / Module *', hintText: 'e.g. AI & Research', border: OutlineInputBorder()),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _newPriority,
                          decoration: const InputDecoration(labelText: 'Priority *', border: OutlineInputBorder()),
                          items: const [
                            DropdownMenuItem(value: 'LOW', child: Text('Low')),
                            DropdownMenuItem(value: 'MEDIUM', child: Text('Medium')),
                            DropdownMenuItem(value: 'HIGH', child: Text('High')),
                            DropdownMenuItem(value: 'URGENT', child: Text('Urgent')),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _newPriority = val);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: _pickDueDate,
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Due Date *',
                              border: OutlineInputBorder(),
                              suffixIcon: Icon(Icons.calendar_today, size: 16),
                            ),
                            child: Text(
                              dueDateFormatted,
                              style: TextStyle(fontSize: 13, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _newStatus,
                          decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
                          items: const [
                            DropdownMenuItem(value: 'Active', child: Text('Active')),
                            DropdownMenuItem(value: 'Planning', child: Text('Planning')),
                            DropdownMenuItem(value: 'On Hold', child: Text('On Hold')),
                            DropdownMenuItem(value: 'Completed', child: Text('Completed')),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _newStatus = val);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    initialValue: _estimatedHours.toString(),
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Estimated Hours', hintText: 'e.g. 8', border: OutlineInputBorder()),
                    onChanged: (val) {
                      _estimatedHours = double.tryParse(val) ?? 8.0;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _descriptionController,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Description & Scope', hintText: 'Provide details on deliverables...', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton.icon(
                      onPressed: _saveNewTask,
                      icon: const Icon(Icons.add_circle_outline, size: 18),
                      label: const Text('Add Task', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReviewModal(bool isDark) {
    final t = _selectedTaskForReview!;
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
                    Text('Team Lead Review & Rating', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText)),
                    IconButton(onPressed: () => setState(() => _showReviewModal = false), icon: const Icon(Icons.close, size: 18)),
                  ],
                ),
                const Divider(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSecondarySurface : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText)),
                      const SizedBox(height: 4),
                      Text('Assigned by: ${t.leadName}', style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText)),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Icon(Icons.star, color: Color(0xFFF59E0B), size: 22),
                    const SizedBox(width: 8),
                    Text('${(t.reviewRating ?? 5.0).toStringAsFixed(1)} / 5 Stars', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFFB45309))),
                  ],
                ),
                if (t.reviewQuality != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFA7F3D0))),
                    child: Text('Grade: ${t.reviewQuality}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF059669))),
                  ),
                ],
                const SizedBox(height: 14),
                Text('Review Notes:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(12),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSecondarySurface : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isDark ? AppColors.darkBordersAndDividers : const Color(0xFFE2E8F0)),
                  ),
                  child: Text(t.reviewComment ?? 'No feedback notes provided by Team Lead yet.', style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText)),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => setState(() => _showReviewModal = false),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                    child: const Text('Close'),
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
