import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/auth/auth_service.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_card.dart';

class TlAddTaskScreen extends ConsumerStatefulWidget {
  const TlAddTaskScreen({super.key});

  @override
  ConsumerState<TlAddTaskScreen> createState() => _TlAddTaskScreenState();
}

class _TlAddTaskScreenState extends ConsumerState<TlAddTaskScreen> {
  bool _submitting = false;
  List<dynamic> _teamMembers = [];

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _hoursController = TextEditingController(text: '8');

  String _assignedToId = '';
  String _priority = 'MEDIUM';
  String _dueDate = DateTime.now().add(const Duration(days: 7)).toIso8601String().split('T')[0];

  @override
  void initState() {
    super.initState();
    _loadTeamMembers();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _hoursController.dispose();
    super.dispose();
  }

  Future<void> _loadTeamMembers() async {
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

      if (mounted) {
        setState(() {
          _teamMembers = items;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _teamMembers = [
            {'id': 'EMP-001', 'firstName': 'Rahul', 'lastName': 'Sharma', 'designation': 'Senior Engineer'},
            {'id': 'EMP-002', 'firstName': 'Priya', 'lastName': 'Verma', 'designation': 'UI Designer'},
          ];
        });
      }
    }
  }

  Future<void> _saveTask() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Task title is required'), backgroundColor: AppColors.error),
      );
      return;
    }
    if (_assignedToId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an assignee'), backgroundColor: AppColors.error),
      );
      return;
    }

    setState(() => _submitting = true);
    final apiClient = ref.read(apiClientProvider);

    try {
      await apiClient.post('/tasks', body: {
        'title': _titleController.text.trim(),
        'description': _descController.text.trim(),
        'assignedToId': _assignedToId,
        'priority': _priority,
        'dueDate': _dueDate,
        'estimatedHours': int.tryParse(_hoursController.text) ?? 8,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Task assigned successfully!'), backgroundColor: AppColors.success),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to assign task: $e'), backgroundColor: AppColors.error),
        );
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Assign New Task')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Task Assignment Form', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 4),
              const Text('Fill out the details below to assign work to your team member', style: TextStyle(fontSize: 13, color: AppColors.lightSecondaryText)),
              const Divider(height: 24),

              // Title
              const Text('Task Title *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(hintText: 'e.g. Implement user login API endpoint', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),

              // Assign To
              const Text('Assign To Team Member *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: _assignedToId.isEmpty ? null : _assignedToId,
                decoration: const InputDecoration(hintText: '-- Select Team Member --', border: OutlineInputBorder()),
                items: _teamMembers.map((m) {
                  final id = m['id']?.toString() ?? m['employeeId']?.toString() ?? '';
                  final name = '${m['firstName'] ?? ''} ${m['lastName'] ?? ''}'.trim().isNotEmpty ? '${m['firstName']} ${m['lastName']}' : (m['name'] ?? 'Employee');
                  final desig = m['designation'] ?? 'Staff';
                  return DropdownMenuItem(value: id, child: Text('$name ($desig)'));
                }).toList(),
                onChanged: (val) => setState(() => _assignedToId = val ?? ''),
              ),
              const SizedBox(height: 16),

              // Priority & Hours Row
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Priority Level', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          value: _priority,
                          decoration: const InputDecoration(border: OutlineInputBorder()),
                          items: const [
                            DropdownMenuItem(value: 'LOW', child: Text('Low')),
                            DropdownMenuItem(value: 'MEDIUM', child: Text('Medium')),
                            DropdownMenuItem(value: 'HIGH', child: Text('High')),
                            DropdownMenuItem(value: 'URGENT', child: Text('Urgent')),
                          ],
                          onChanged: (val) => setState(() => _priority = val ?? 'MEDIUM'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Estimated Hours', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _hoursController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(border: OutlineInputBorder()),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Due Date
              const Text('Due Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              TextField(
                controller: TextEditingController(text: _dueDate),
                readOnly: true,
                decoration: const InputDecoration(border: OutlineInputBorder(), suffixIcon: Icon(Icons.calendar_today)),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.tryParse(_dueDate) ?? DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) {
                    setState(() {
                      _dueDate = picked.toIso8601String().split('T')[0];
                    });
                  }
                },
              ),
              const SizedBox(height: 16),

              // Description
              const Text('Description & Acceptance Criteria', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              TextField(
                controller: _descController,
                maxLines: 4,
                decoration: const InputDecoration(hintText: 'Provide detailed task requirements, scope, deliverables...', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 24),

              // Action Buttons
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _submitting ? null : _saveTask,
                  icon: _submitting ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2) : const Icon(Icons.check_circle),
                  label: Text(_submitting ? 'Assigning Task...' : 'Assign Task'),
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
