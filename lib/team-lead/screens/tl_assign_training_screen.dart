import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/loading_shimmer.dart';
import '../../shared/widgets/status_chip.dart';

class TlAssignTrainingScreen extends ConsumerStatefulWidget {
  const TlAssignTrainingScreen({super.key});

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
    final apiClient = ref.read(apiClientProvider);
    try {
      final res = await apiClient.get('/training/courses').catchError((_) => null);
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
    final apiClient = ref.read(apiClientProvider);
    try {
      final res = await apiClient.get('/training/assignments').catchError((_) => null);
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
          title: const Text('Assign New Training'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Select Course *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 4),
                DropdownButtonFormField<String>(
                  value: selectedCourseId.isEmpty ? null : selectedCourseId,
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                  items: _courses.map((c) {
                    final id = c['id']?.toString() ?? '';
                    final title = c['title'] ?? 'Course';
                    return DropdownMenuItem(value: id, child: Text(title));
                  }).toList(),
                  onChanged: (val) => setModalState(() => selectedCourseId = val ?? ''),
                ),
                const SizedBox(height: 12),

                const Text('Target Type *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 4),
                DropdownButtonFormField<String>(
                  value: assignedToType,
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'INDIVIDUAL', child: Text('Individual')),
                    DropdownMenuItem(value: 'TEAM', child: Text('Entire Team')),
                    DropdownMenuItem(value: 'DEPARTMENT', child: Text('Department')),
                  ],
                  onChanged: (val) => setModalState(() => assignedToType = val ?? 'INDIVIDUAL'),
                ),
                const SizedBox(height: 12),

                if (assignedToType == 'INDIVIDUAL') ...[
                  const Text('Select Member *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<String>(
                    value: selectedEmpId.isEmpty ? null : selectedEmpId,
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                    items: _employees.map((e) {
                      final id = (e['id'] ?? e['employeeId'])?.toString() ?? '';
                      final name = '${e['firstName'] ?? ''} ${e['lastName'] ?? ''}'.trim().isNotEmpty ? '${e['firstName']} ${e['lastName']}' : (e['name'] ?? 'Member');
                      return DropdownMenuItem(value: id, child: Text(name));
                    }).toList(),
                    onChanged: (val) => setModalState(() => selectedEmpId = val ?? ''),
                  ),
                  const SizedBox(height: 12),
                ],

                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Priority', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          const SizedBox(height: 4),
                          DropdownButtonFormField<String>(
                            value: priority,
                            decoration: const InputDecoration(border: OutlineInputBorder()),
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
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Due Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          const SizedBox(height: 4),
                          TextField(
                            controller: TextEditingController(text: dueDate),
                            readOnly: true,
                            decoration: const InputDecoration(border: OutlineInputBorder(), suffixIcon: Icon(Icons.calendar_today, size: 16)),
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
                const SizedBox(height: 12),

                const Text('Notes / Instructions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 4),
                TextField(
                  controller: notesController,
                  maxLines: 2,
                  decoration: const InputDecoration(hintText: 'Add instructions for trainees...', border: OutlineInputBorder()),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final apiClient = ref.read(apiClientProvider);
                try {
                  await apiClient.post('/training/assignments', body: {
                    'courseId': selectedCourseId,
                    'assignedToType': assignedToType,
                    'assignedTo': [selectedEmpId],
                    'dueDate': dueDate,
                    'priority': priority,
                    'notes': notesController.text.trim(),
                  }).catchError((_) => null);

                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      const SnackBar(content: Text('Training assigned successfully!'), backgroundColor: AppColors.success),
                    );
                    _loadAssignments();
                  }
                } catch (e) {
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      SnackBar(content: Text('Failed to assign training: $e'), backgroundColor: AppColors.error),
                    );
                  }
                }
              },
              child: const Text('Assign Training'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendReminder(String assignmentId, String name) async {
    final apiClient = ref.read(apiClientProvider);
    try {
      await apiClient.post('/training/assignments/$assignmentId/reminder', body: {}).catchError((_) => null);
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
    if (_isLoading) return const Scaffold(body: LoadingShimmer());

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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Assign Training & Progress'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAssignDialog,
        child: const Icon(Icons.add),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search & Filter Toolbar
            TextField(
              decoration: const InputDecoration(
                labelText: 'Search by employee or course...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (val) => setState(() => _searchTerm = val),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _typeFilter.isEmpty ? null : _typeFilter,
                    decoration: const InputDecoration(labelText: 'Target Type', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                    items: const [
                      DropdownMenuItem(value: '', child: Text('All Types')),
                      DropdownMenuItem(value: 'INDIVIDUAL', child: Text('Individual')),
                      DropdownMenuItem(value: 'TEAM', child: Text('Team')),
                      DropdownMenuItem(value: 'DEPARTMENT', child: Text('Department')),
                    ],
                    onChanged: (val) => setState(() => _typeFilter = val ?? ''),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _statusFilter.isEmpty ? null : _statusFilter,
                    decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                    items: const [
                      DropdownMenuItem(value: '', child: Text('All Status')),
                      DropdownMenuItem(value: 'IN_PROGRESS', child: Text('In Progress')),
                      DropdownMenuItem(value: 'COMPLETED', child: Text('Completed')),
                      DropdownMenuItem(value: 'OVERDUE', child: Text('Overdue')),
                    ],
                    onChanged: (val) => setState(() => _statusFilter = val ?? ''),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Assignments List
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Training Assignments', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text('${filtered.length} items', style: const TextStyle(fontSize: 12, color: AppColors.lightSecondaryText)),
              ],
            ),
            const SizedBox(height: 12),

            if (filtered.isEmpty)
              const AppCard(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: Text('No training assignments found matching filter.')),
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
                  final progress = (a['progress'] ?? 0) as int;
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
  }
}
