import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_card.dart';

class TlAddPayrollInputScreen extends ConsumerStatefulWidget {
  const TlAddPayrollInputScreen({super.key});

  @override
  ConsumerState<TlAddPayrollInputScreen> createState() => _TlAddPayrollInputScreenState();
}

class _TlAddPayrollInputScreenState extends ConsumerState<TlAddPayrollInputScreen> {
  bool _submitting = false;
  List<dynamic> _teamMembers = [];

  final TextEditingController _labelController = TextEditingController();
  final TextEditingController _valueController = TextEditingController();
  final TextEditingController _remarksController = TextEditingController();

  String _selectedEmployeeId = '';
  String _inputType = 'OVERTIME';
  String _month = 'Oct';
  int _year = 2026;

  @override
  void initState() {
    super.initState();
    _loadTeamMembers();
  }

  @override
  void dispose() {
    _labelController.dispose();
    _valueController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  Future<void> _loadTeamMembers() async {
    final apiClient = ref.read(apiClientProvider);
    try {
      final res = await apiClient.get('/payroll/team/members').catchError((_) async {
        return await apiClient.get(ApiEndpoints.employees).catchError((_) => null);
      });

      List<dynamic> items = [];
      if (res is List) {
        items = res;
      } else if (res is Map<String, dynamic>) {
        items = res['items'] ?? res['data'] ?? [];
      }

      if (items.isEmpty) {
        items = [
          {'employeeId': 'EMP-001', 'employeeName': 'Rahul Sharma', 'employeeCode': 'EMP-001'},
          {'employeeId': 'EMP-002', 'employeeName': 'Priya Verma', 'employeeCode': 'EMP-002'},
          {'employeeId': 'EMP-003', 'employeeName': 'Amit Kumar', 'employeeCode': 'EMP-003'},
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
            {'employeeId': 'EMP-001', 'employeeName': 'Rahul Sharma', 'employeeCode': 'EMP-001'},
            {'employeeId': 'EMP-002', 'employeeName': 'Priya Verma', 'employeeCode': 'EMP-002'},
          ];
        });
      }
    }
  }

  Future<void> _saveInput() async {
    if (_selectedEmployeeId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a team member.'), backgroundColor: AppColors.error),
      );
      return;
    }
    if (_labelController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an input label / description.'), backgroundColor: AppColors.error),
      );
      return;
    }

    setState(() => _submitting = true);
    final apiClient = ref.read(apiClientProvider);

    try {
      await apiClient.post('/payroll/team/inputs', body: {
        'employeeId': _selectedEmployeeId,
        'inputType': _inputType,
        'label': _labelController.text.trim(),
        'value': _valueController.text.trim(),
        'month': _month,
        'year': _year,
        'remarks': _remarksController.text.trim(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payroll input submitted for approval!'), backgroundColor: AppColors.success),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit input: $e'), backgroundColor: AppColors.error),
        );
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Payroll Input')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('New Payroll Input Form', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 4),
              const Text('Submit overtime, bonus, or attendance inputs for team members', style: TextStyle(fontSize: 13, color: AppColors.lightSecondaryText)),
              const Divider(height: 24),

              // Select Team Member
              const Text('Select Team Member *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: _selectedEmployeeId.isEmpty ? null : _selectedEmployeeId,
                decoration: const InputDecoration(hintText: '-- Select Employee --', border: OutlineInputBorder()),
                items: _teamMembers.map((e) {
                  final id = (e['employeeId'] ?? e['id'])?.toString() ?? '';
                  final name = '${e['firstName'] ?? ''} ${e['lastName'] ?? ''}'.trim().isNotEmpty ? '${e['firstName']} ${e['lastName']}' : (e['employeeName'] ?? e['name'] ?? 'Employee');
                  final code = e['employeeCode'] ?? id;
                  return DropdownMenuItem(value: id, child: Text('$name ($code)'));
                }).toList(),
                onChanged: (val) => setState(() => _selectedEmployeeId = val ?? ''),
              ),
              const SizedBox(height: 16),

              // Input Type & Month
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Input Category *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          value: _inputType,
                          decoration: const InputDecoration(border: OutlineInputBorder()),
                          items: const [
                            DropdownMenuItem(value: 'OVERTIME', child: Text('Overtime')),
                            DropdownMenuItem(value: 'BONUS', child: Text('Bonus')),
                            DropdownMenuItem(value: 'ATTENDANCE', child: Text('Attendance Adjustment')),
                          ],
                          onChanged: (val) => setState(() => _inputType = val ?? 'OVERTIME'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Pay Month & Year', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: TextEditingController(text: '$_month $_year'),
                          readOnly: true,
                          decoration: const InputDecoration(border: OutlineInputBorder(), suffixIcon: Icon(Icons.calendar_today)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Description / Label
              const Text('Input Description / Label *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              TextField(
                controller: _labelController,
                decoration: const InputDecoration(hintText: 'e.g. Weekend Sprint Overtime Hours or Spot Bonus', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),

              // Value
              const Text('Value (Hours or Amount) *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              TextField(
                controller: _valueController,
                decoration: const InputDecoration(hintText: 'e.g. 12 Hours or ₹5,000', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),

              // Remarks
              const Text('TL Remarks / Justification', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              TextField(
                controller: _remarksController,
                maxLines: 3,
                decoration: const InputDecoration(hintText: 'Add justification comments for HR & Finance review...', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 24),

              // Action Buttons
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _submitting ? null : _saveInput,
                  icon: _submitting ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2) : const Icon(Icons.check_circle),
                  label: Text(_submitting ? 'Submitting...' : 'Submit Payroll Input'),
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
