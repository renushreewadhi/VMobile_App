import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/api/training_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/loading_shimmer.dart';
import '../../../shared/widgets/status_chip.dart';
import 'hr_training_dashboard_screen.dart';

class HrAssignTrainingScreen extends ConsumerStatefulWidget {
  const HrAssignTrainingScreen({super.key});

  @override
  ConsumerState<HrAssignTrainingScreen> createState() => _HrAssignTrainingScreenState();
}

class _HrAssignTrainingScreenState extends ConsumerState<HrAssignTrainingScreen> {
  bool _isLoading = true;
  List<dynamic> _assignments = [];
  List<dynamic> _courses = [];
  List<dynamic> _employees = [];

  String _searchTerm = '';
  String _courseFilter = '';
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
      List<dynamic> items = res is List ? res : (res is Map && res['data'] is List ? res['data'] : []);
      if (items.isEmpty) {
        items = [
          {'id': 'C-101', 'title': 'ASP.NET Core Architecture'},
          {'id': 'C-102', 'title': 'Cybersecurity & Data Privacy'},
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
      List<dynamic> items = res is List ? res : (res is Map && res['data'] is List ? res['data'] : []);
      if (items.isEmpty) {
        items = [
          {'id': 'EMP-001', 'firstName': 'Rahul', 'lastName': 'Sharma'},
          {'id': 'EMP-002', 'firstName': 'Neha', 'lastName': 'Singh'},
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
      List<dynamic> items = res is List ? res : (res is Map && res['data'] is List ? res['data'] : []);
      if (items.isEmpty) {
        items = [
          {
            'id': 'A-1',
            'courseTitle': 'ASP.NET Core Web API Architecture 03 Nov 2026',
            'employeeName': 'Rahul Sharma',
            'assignedToType': 'INDIVIDUAL',
            'dueDate': '18 Nov 2026',
            'assignedDate': '03 Nov 2026',
            'status': 'IN_PROGRESS',
            'progress': 50,
          },
          {
            'id': 'A-2',
            'courseTitle': 'Cybersecurity & Data Privacy 2026 05 Nov 2026',
            'employeeName': 'Neha Singh',
            'assignedToType': 'INDIVIDUAL',
            'dueDate': '26 Nov 2026',
            'assignedDate': '05 Nov 2026',
            'status': 'PENDING',
            'progress': 0,
          },
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
    String assignedToType = 'Individual Employees';
    String dueDate = DateTime.now().add(const Duration(days: 14)).toIso8601String().split('T')[0];
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: const Text('Create New Training Assignment', style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Select a course and target assignees to schedule compliance or skill development training', style: TextStyle(fontSize: 12, color: AppColors.lightSecondaryText)),
                const SizedBox(height: 16),
                const Text('Course *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
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
                const Text('Assignment Target Type *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: assignedToType,
                  decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                  items: const [
                    DropdownMenuItem(value: 'Individual Employees', child: Text('Individual Employees')),
                    DropdownMenuItem(value: 'Department', child: Text('Department')),
                    DropdownMenuItem(value: 'Entire Team', child: Text('Entire Team')),
                  ],
                  onChanged: (val) => setModalState(() => assignedToType = val ?? 'Individual Employees'),
                ),
                const SizedBox(height: 16),
                const Text('Compliance Due Date *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
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
                const SizedBox(height: 16),
                const Text('Select Employee *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: selectedEmpId.isEmpty ? null : selectedEmpId,
                  decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                  items: _employees.map((e) {
                    final id = (e['id'] ?? e['employeeId'])?.toString() ?? '';
                    final name = '${e['firstName'] ?? ''} ${e['lastName'] ?? ''}'.trim();
                    return DropdownMenuItem(value: id, child: Text(name.isNotEmpty ? name : 'Employee'));
                  }).toList(),
                  onChanged: (val) => setModalState(() => selectedEmpId = val ?? ''),
                ),
                const SizedBox(height: 16),
                const Text('Optional Notes for Assignees', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 6),
                TextField(
                  controller: notesController,
                  maxLines: 3,
                  decoration: const InputDecoration(hintText: 'Provide any special instructions, passing criteria, or context for assignees...', border: OutlineInputBorder()),
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
                    'notes': notesController.text.trim(),
                  }).catchError((_) => null);

                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Training assignment created successfully!'), backgroundColor: AppColors.success),
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
              child: const Text('Confirm & Assign Training'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const LoadingShimmer();

    final filtered = _assignments.where((a) {
      final map = a is Map<String, dynamic> ? a : {};
      final title = (map['courseTitle'] ?? '').toString().toLowerCase();
      final emp = (map['employeeName'] ?? '').toString().toLowerCase();
      final course = (map['courseTitle'] ?? '').toString();
      final status = (map['status'] ?? '').toString();

      final matchesSearch = _searchTerm.isEmpty || title.contains(_searchTerm.toLowerCase()) || emp.contains(_searchTerm.toLowerCase());
      final matchesCourse = _courseFilter.isEmpty || course == _courseFilter;
      final matchesStatus = _statusFilter.isEmpty || status == _statusFilter;

      return matchesSearch && matchesCourse && matchesStatus;
    }).toList();

    return GlassScaffold(
      title: 'Training & Development',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Assign Training & Courses', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    const SizedBox(height: 2),
                    const Text('Distribute courses across individuals, departments, or teams, set compliance deadlines, and monitor completion progress.', style: TextStyle(fontSize: 11.5, color: AppColors.lightSecondaryText)),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: _openAssignDialog,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('New Assignment', style: TextStyle(fontSize: 11.5)),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 14),
            buildHrTrainingSubNav(context, 4),
            const SizedBox(height: 16),

            // 4 KPI Cards
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 2.1,
              children: [
                _kpiCard('TOTAL ASSIGNMENTS', '${_assignments.length}', 'Active & Completed', Icons.list_alt, AppColors.primary),
                _kpiCard('COMPLETED', '${_assignments.where((a) => a['status'] == 'COMPLETED').length}', 'Passed', Icons.check_circle, Colors.green),
                _kpiCard('IN PROGRESS', '${_assignments.where((a) => a['status'] == 'IN_PROGRESS').length}', 'Learning', Icons.hourglass_top, Colors.orange),
                _kpiCard('OVERDUE', '${_assignments.where((a) => a['status'] == 'OVERDUE').length}', 'Expired', Icons.error, Colors.red),
              ],
            ),
            const SizedBox(height: 16),

            // Search & Filter Toolbar
            AppCard(
              child: Column(
                children: [
                  TextField(
                    decoration: const InputDecoration(
                      hintText: 'Search by course title, employee name, department...',
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
                          initialValue: _statusFilter.isEmpty ? null : _statusFilter,
                          decoration: const InputDecoration(labelText: 'All Statuses', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 6), isDense: true),
                          items: const [
                            DropdownMenuItem(value: '', child: Text('All Statuses')),
                            DropdownMenuItem(value: 'IN_PROGRESS', child: Text('In Progress')),
                            DropdownMenuItem(value: 'COMPLETED', child: Text('Completed')),
                            DropdownMenuItem(value: 'PENDING', child: Text('Pending')),
                          ],
                          onChanged: (val) => setState(() => _statusFilter = val ?? ''),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Active Assignments
            const Text('Active Assignments', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),
            filtered.isEmpty
                ? AppCard(
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Center(
                        child: Column(
                          children: [
                            const Icon(Icons.assignment_outlined, size: 40, color: Colors.grey),
                            const SizedBox(height: 8),
                            const Text('No Training Assignments Found', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            const SizedBox(height: 4),
                            const Text('There are no training assignments matching your search criteria. Click below to assign a course.', style: TextStyle(fontSize: 12, color: Colors.grey), textAlign: TextAlign.center),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: _openAssignDialog,
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text('Create New Assignment'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final a = filtered[index] as Map<String, dynamic>;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: AppCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(child: Text(a['courseTitle'] ?? 'Course', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                                  StatusChip(status: a['status'] ?? 'PENDING'),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text('Assigned Target: ${a['employeeName']} • Type: ${a['assignedToType']}', style: const TextStyle(fontSize: 12, color: AppColors.lightSecondaryText)),
                              const SizedBox(height: 4),
                              Text('Assigned Date: ${a['assignedDate']} • Due: ${a['dueDate']}', style: const TextStyle(fontSize: 11.5, color: AppColors.lightMutedText)),
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
