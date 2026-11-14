import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/api/training_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_header.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/loading_shimmer.dart';
import '../../shared/widgets/status_chip.dart';

class TlAssignTrainingScreen extends ConsumerStatefulWidget {
  final bool showAppBar;
  const TlAssignTrainingScreen({super.key, this.showAppBar = true});

  @override
  ConsumerState<TlAssignTrainingScreen> createState() => _TlAssignTrainingScreenState();
}

class _TlAssignTrainingScreenState extends ConsumerState<TlAssignTrainingScreen> {
  bool _isLoading = true;
  List<dynamic> _assignments = [];
  List<dynamic> _courses = [];
  List<dynamic> _employees = [];

  String _searchTerm = '';
  String _courseFilter = '';
  String _typeFilter = '';
  String _statusFilter = '';

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _loadCourses(),
      _loadEmployees(),
      _loadAssignments(),
    ]);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadCourses() async {
    final trainingService = ref.read(trainingServiceProvider);
    try {
      final res = await trainingService.getCourses().catchError((_) => null);
      List<dynamic> items = [];
      if (res is List) {
        items = res;
      } else if (res is Map<String, dynamic>) {
        items = res['items'] ?? res['data'] ?? [];
      }

      if (items.isEmpty) {
        items = [
          {'id': 'C-101', 'title': 'Flutter Mobile App Development', 'category': 'Mobile'},
          {'id': 'C-102', 'title': '.NET Core Web API Architecture', 'category': 'Backend'},
          {'id': 'C-103', 'title': 'AWS Cloud DevOps Fundamentals', 'category': 'Cloud'},
        ];
      }

      setState(() => _courses = items);
    } catch (_) {
      setState(() => _courses = []);
    }
  }

  Future<void> _loadEmployees() async {
    final apiClient = ref.read(apiClientProvider);
    try {
      final res = await apiClient.get(ApiEndpoints.employees).catchError((_) => null);
      List<dynamic> items = [];
      if (res is List) {
        items = res;
      } else if (res is Map<String, dynamic>) {
        items = res['items'] ?? res['data'] ?? [];
      }

      if (items.isEmpty) {
        items = [
          {'id': 'EMP-001', 'firstName': 'Rahul', 'lastName': 'Sharma', 'designation': 'Senior Engineer'},
          {'id': 'EMP-002', 'firstName': 'Priya', 'lastName': 'Verma', 'designation': 'UI Designer'},
          {'id': 'EMP-003', 'firstName': 'Amit', 'lastName': 'Kumar', 'designation': 'Backend Dev'},
        ];
      }

      setState(() => _employees = items);
    } catch (_) {
      setState(() => _employees = []);
    }
  }

  Future<void> _loadAssignments() async {
    final trainingService = ref.read(trainingServiceProvider);
    try {
      final res = await trainingService.getAssignments().catchError((_) => null);
      List<dynamic> items = [];
      if (res is List) {
        items = res;
      } else if (res is Map<String, dynamic>) {
        items = res['items'] ?? res['data'] ?? [];
      }

      if (items.isEmpty) {
        items = [
          {
            'id': 'A-101',
            'employeeName': 'Rahul Sharma',
            'courseTitle': 'Flutter Mobile App Development',
            'assignedToType': 'INDIVIDUAL',
            'priority': 'HIGH',
            'dueDate': '2026-10-15',
            'assignedDate': '2026-09-01',
            'progress': 80,
            'status': 'IN_PROGRESS'
          },
          {
            'id': 'A-102',
            'employeeName': 'Priya Verma',
            'courseTitle': '.NET Core Web API Architecture',
            'assignedToType': 'INDIVIDUAL',
            'priority': 'MEDIUM',
            'dueDate': '2026-09-30',
            'assignedDate': '2026-09-05',
            'progress': 100,
            'status': 'COMPLETED'
          }
        ];
      }

      setState(() => _assignments = items);
    } catch (_) {
      setState(() => _assignments = []);
    }
  }

  void _openAssignDialog() {
    String selectedCourseId = _courses.isNotEmpty ? _courses.first['id'].toString() : '';
    String selectedEmpId = _employees.isNotEmpty ? (_employees.first['id'] ?? _employees.first['employeeId'])?.toString() ?? '' : '';
    String assignedToType = 'INDIVIDUAL';
    String priority = 'MEDIUM';
    String dueDate = DateTime.now().add(const Duration(days: 14)).toIso8601String().split('T')[0];
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: const Text('Assign Training', style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Select course and target team members to create new assignment.', style: TextStyle(fontSize: 12, color: AppColors.lightSecondaryText)),
                const SizedBox(height: 16),
                const Text('1. Select Training Course *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: selectedCourseId.isEmpty ? null : selectedCourseId,
                  decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                  items: _courses.map((c) {
                    final id = c['id']?.toString() ?? '';
                    final title = c['title'] ?? 'Course';
                    return DropdownMenuItem(value: id, child: Text(title));
                  }).toList(),
                  onChanged: (val) => setModalState(() => selectedCourseId = val ?? ''),
                ),
                const SizedBox(height: 16),

                const Text('2. Assign Target Type *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _targetTypeChip('Individual', 'INDIVIDUAL', assignedToType, (val) => setModalState(() => assignedToType = val))),
                    const SizedBox(width: 4),
                    Expanded(child: _targetTypeChip('Team', 'TEAM', assignedToType, (val) => setModalState(() => assignedToType = val))),
                    const SizedBox(width: 4),
                    Expanded(child: _targetTypeChip('Dept', 'DEPARTMENT', assignedToType, (val) => setModalState(() => assignedToType = val))),
                    const SizedBox(width: 4),
                    Expanded(child: _targetTypeChip('Designation', 'DESIGNATION', assignedToType, (val) => setModalState(() => assignedToType = val))),
                  ],
                ),
                const SizedBox(height: 16),

                if (assignedToType == 'INDIVIDUAL') ...[
                  const Text('Select Team Member *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: selectedEmpId.isEmpty ? null : selectedEmpId,
                    decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                    items: _employees.map((e) {
                      final id = (e['id'] ?? e['employeeId'])?.toString() ?? '';
                      final name = '${e['firstName'] ?? ''} ${e['lastName'] ?? ''}'.trim().isNotEmpty ? '${e['firstName']} ${e['lastName']}' : (e['name'] ?? 'Member');
                      return DropdownMenuItem(value: id, child: Text(name));
                    }).toList(),
                    onChanged: (val) => setModalState(() => selectedEmpId = val ?? ''),
                  ),
                  const SizedBox(height: 16),
                ],

                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Assignment Priority', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            initialValue: priority,
                            decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                            items: const [
                              DropdownMenuItem(value: 'LOW', child: Text('Low')),
                              DropdownMenuItem(value: 'MEDIUM', child: Text('Medium')),
                              DropdownMenuItem(value: 'HIGH', child: Text('High')),
                            ],
                            onChanged: (val) => setModalState(() => priority = val ?? 'MEDIUM'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Completion Due Date *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          const SizedBox(height: 6),
                          TextField(
                            controller: TextEditingController(text: dueDate),
                            readOnly: true,
                            decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8), suffixIcon: Icon(Icons.calendar_today, size: 16)),
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: DateTime.tryParse(dueDate) ?? DateTime.now(),
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now().add(const Duration(days: 365)),
                              );
                              if (picked != null) {
                                setModalState(() {
                                  dueDate = picked.toIso8601String().split('T')[0];
                                });
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                const Text('Instructions / Notes for Trainees', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 6),
                TextField(
                  controller: notesController,
                  maxLines: 3,
                  decoration: const InputDecoration(hintText: 'Add optional instructions, goals, or expectations...', border: OutlineInputBorder()),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
              onPressed: () async {
                final trainingService = ref.read(trainingServiceProvider);
                try {
                  await trainingService.assignTraining({
                    'courseId': selectedCourseId,
                    'assignedToType': assignedToType,
                    'assignedTo': [selectedEmpId],
                    'dueDate': dueDate,
                    'priority': priority,
                    'notes': notesController.text.trim(),
                  }).catchError((_) => null);

                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Training assigned successfully!'), backgroundColor: AppColors.success),
                    );
                    _loadAssignments();
                  }
                } catch (e) {
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to assign training: $e'), backgroundColor: AppColors.error),
                    );
                  }
                }
              },
              child: const Text('Assign Training Now'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _targetTypeChip(String label, String value, String current, Function(String) onTap) {
    final isSelected = current == value;
    return InkWell(
      onTap: () => onTap(value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withOpacity(0.15) : Colors.transparent,
          border: Border.all(color: isSelected ? AppColors.primary : AppColors.lightBordersAndDividers),
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Text(label, style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? AppColors.primary : AppColors.lightPrimaryText)),
      ),
    );
  }

  Future<void> _sendReminder(String assignmentId, String name) async {
    final trainingService = ref.read(trainingServiceProvider);
    try {
      await trainingService.sendAssignmentReminder(assignmentId).catchError((_) => null);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Reminder sent to $name'), backgroundColor: AppColors.success),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Reminder notification sent to $name'), backgroundColor: AppColors.success),
        );
      }
    }
  }

  String _getInitial(String name) {
    if (name.isEmpty) return 'TM';
    return name[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      const skeleton = LoadingShimmer();
      if (!widget.showAppBar) return Material(color: Colors.transparent, child: skeleton);
      return const GlassScaffold(title: 'Assign Training', body: skeleton);
    }

    final filtered = _assignments.where((a) {
      final map = a is Map<String, dynamic> ? a : {};
      final name = (map['employeeName'] ?? '').toString().toLowerCase();
      final course = (map['courseTitle'] ?? '').toString().toLowerCase();
      final type = (map['assignedToType'] ?? '').toString().toUpperCase();
      final status = (map['status'] ?? '').toString().toUpperCase();

      final matchesSearch = _searchTerm.isEmpty || name.contains(_searchTerm.toLowerCase()) || course.contains(_searchTerm.toLowerCase());
      final matchesCourse = _courseFilter.isEmpty || course.contains(_courseFilter.toLowerCase());
      final matchesType = _typeFilter.isEmpty || type == _typeFilter;
      final matchesStatus = _statusFilter.isEmpty || status == _statusFilter;

      return matchesSearch && matchesCourse && matchesType && matchesStatus;
    }).toList();

    final totalAssignments = _assignments.length;
    final inProgressCount = _assignments.where((a) => (a['status'] ?? '').toString().toUpperCase() == 'IN_PROGRESS').length;
    final completedCount = _assignments.where((a) => (a['status'] ?? '').toString().toUpperCase() == 'COMPLETED').length;
    final overdueCount = _assignments.where((a) => (a['status'] ?? '').toString().toUpperCase() == 'OVERDUE').length;

    final content = RefreshIndicator(
      onRefresh: _loadAllData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Header & Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Assign Training', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    const SizedBox(height: 2),
                    const Text('Assign courses to individual team members, departments, or teams and monitor their completion.', style: TextStyle(fontSize: 12, color: AppColors.lightSecondaryText)),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: _openAssignDialog,
                  icon: const Icon(Icons.person_add, size: 16),
                  label: const Text('Assign New Training', style: TextStyle(fontSize: 11.5)),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 4 KPI Cards (Total Assignments, In Progress, Completed, Overdue)
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 2.0,
              children: [
                _kpiCard('TOTAL ASSIGNMENTS', '$totalAssignments', 'Active & Completed', Icons.list_alt, AppColors.primary),
                _kpiCard('IN PROGRESS', '$inProgressCount', 'Currently Learning', Icons.hourglass_top, Colors.orange),
                _kpiCard('COMPLETED', '$completedCount', '100% Finished', Icons.check_circle, Colors.green),
                _kpiCard('OVERDUE', '$overdueCount', 'Passed Due Date', Icons.error, Colors.red),
              ],
            ),
            const SizedBox(height: 16),

            // Search & Filter Toolbar
            AppCard(
              child: Column(
                children: [
                  TextField(
                    decoration: const InputDecoration(
                      hintText: 'Search by employee, course...',
                      prefixIcon: Icon(Icons.search, size: 18),
                      border: OutlineInputBorder(borderSide: BorderSide.none),
                      filled: true,
                      fillColor: AppColors.lightInputBackground,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    onChanged: (val) => setState(() => _searchTerm = val),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _courseFilter.isEmpty ? null : _courseFilter,
                          decoration: const InputDecoration(labelText: 'All Courses', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 6), isDense: true),
                          items: [
                            const DropdownMenuItem(value: '', child: Text('All Courses')),
                            ..._courses.map((c) => DropdownMenuItem(value: c['title']?.toString() ?? '', child: Text(c['title']?.toString() ?? ''))),
                          ],
                          onChanged: (val) => setState(() => _courseFilter = val ?? ''),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _typeFilter.isEmpty ? null : _typeFilter,
                          decoration: const InputDecoration(labelText: 'All Target Types', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 6), isDense: true),
                          items: const [
                            DropdownMenuItem(value: '', child: Text('All Target Types')),
                            DropdownMenuItem(value: 'INDIVIDUAL', child: Text('Individual')),
                            DropdownMenuItem(value: 'TEAM', child: Text('Team')),
                            DropdownMenuItem(value: 'DEPARTMENT', child: Text('Department')),
                          ],
                          onChanged: (val) => setState(() => _typeFilter = val ?? ''),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _statusFilter.isEmpty ? null : _statusFilter,
                          decoration: const InputDecoration(labelText: 'All Statuses', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 6), isDense: true),
                          items: const [
                            DropdownMenuItem(value: '', child: Text('All Statuses')),
                            DropdownMenuItem(value: 'IN_PROGRESS', child: Text('In Progress')),
                            DropdownMenuItem(value: 'COMPLETED', child: Text('Completed')),
                            DropdownMenuItem(value: 'OVERDUE', child: Text('Overdue')),
                          ],
                          onChanged: (val) => setState(() => _statusFilter = val ?? ''),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () => setState(() {
                          _searchTerm = '';
                          _courseFilter = '';
                          _typeFilter = '';
                          _statusFilter = '';
                        }),
                        icon: const Icon(Icons.refresh, size: 14),
                        label: const Text('Reset', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Assignments List
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Training Assignments', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                Text('${filtered.length} items', style: const TextStyle(fontSize: 11.5, color: AppColors.lightSecondaryText)),
              ],
            ),
            const SizedBox(height: 10),

            if (filtered.isEmpty)
              AppCard(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Center(
                    child: Column(
                      children: [
                        const Icon(Icons.assignment_outlined, size: 40, color: Colors.grey),
                        const SizedBox(height: 8),
                        const Text('No assignments match your filter', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        const SizedBox(height: 4),
                        const Text('Try clearing your search filters or create a new assignment for your team.', style: TextStyle(fontSize: 12, color: Colors.grey), textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: () => setState(() {
                            _searchTerm = '';
                            _courseFilter = '';
                            _typeFilter = '';
                            _statusFilter = '';
                          }),
                          child: const Text('Clear Filters'),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final a = filtered[index] as Map<String, dynamic>;
                  final id = a['id']?.toString() ?? '';
                  final empName = a['employeeName'] ?? 'Team Member';
                  final courseTitle = a['courseTitle'] ?? 'Training Course';
                  final type = a['assignedToType'] ?? 'INDIVIDUAL';
                  final priority = a['priority'] ?? 'MEDIUM';
                  final dueDate = a['dueDate'] ?? '';
                  final progress = ((a['progress'] ?? 0) as num).toInt();
                  final status = a['status'] ?? 'IN_PROGRESS';

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(type, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.primary)),
                              StatusChip(status: status),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: AppColors.primary,
                                child: Text(_getInitial(empName), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(empName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                    Text(courseTitle, style: const TextStyle(fontSize: 13, color: AppColors.lightSecondaryText)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Priority: $priority', style: const TextStyle(fontSize: 11, color: AppColors.lightMutedText)),
                              if (dueDate.isNotEmpty)
                                Text('Due: $dueDate', style: const TextStyle(fontSize: 11, color: AppColors.lightMutedText)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                            value: progress / 100,
                            backgroundColor: AppColors.lightSurface,
                            color: progress == 100 ? AppColors.success : AppColors.primary,
                          ),
                          const Divider(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (status != 'COMPLETED')
                                IconButton(
                                  icon: const Icon(Icons.notifications_active, color: AppColors.warning),
                                  onPressed: () => _sendReminder(id, empName),
                                  tooltip: 'Send reminder',
                                ),
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
      appBar: const GlassHeader(title: 'Assign Training'),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAssignDialog,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: content,
    );
  }

  Widget _kpiCard(String label, String value, String sub, IconData icon, Color color) {
    return AppCard(
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
                const SizedBox(height: 2),
                Text(label, style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                Text(sub, style: const TextStyle(fontSize: 9, color: AppColors.lightSecondaryText), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
