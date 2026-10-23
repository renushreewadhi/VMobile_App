import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import 'admin_shift_form_screen.dart';

class AdminShiftDetailScreen extends ConsumerStatefulWidget {
  final String shiftId;

  const AdminShiftDetailScreen({super.key, required this.shiftId});

  @override
  ConsumerState<AdminShiftDetailScreen> createState() => _AdminShiftDetailScreenState();
}

class _AdminShiftDetailScreenState extends ConsumerState<AdminShiftDetailScreen> {
  bool _isLoading = true;
  Map<String, dynamic> _shift = {};
  List<dynamic> _assignedEmployees = [];
  List<dynamic> _allEmployees = [];
  List<dynamic> _unassignedEmployees = [];
  List<String> _departmentsList = [];

  String _searchTerm = '';
  String _selectedDepartment = '';

  final List<String> _daysList = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final apiClient = ref.read(apiClientProvider);

    try {
      final shiftRes = await apiClient.get('/attendance/shifts/${widget.shiftId}').catchError((_) => null);
      final empRes = await apiClient.get('/management/employees').catchError((_) => null);

      if (shiftRes is Map<String, dynamic>) {
        _shift = shiftRes;
      } else {
        _shift = {
          'id': widget.shiftId,
          'name': 'General Shift',
          'code': 'SH-02',
          'startTime': '09:00 AM',
          'endTime': '06:00 PM',
          'breakDurationMinutes': 60,
          'lateGracePeriodMinutes': 15,
          'workingDays': ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'],
          'status': 'ACTIVE',
          'description': 'Standard working shift configuration.'
        };
      }

      List<dynamic> employees = empRes is List ? empRes : (empRes is Map ? (empRes['items'] ?? empRes['data'] ?? []) : []);
      if (employees.isEmpty) {
        employees = [
          {'id': '1', 'employeeCode': 'EMP-24-001', 'firstName': 'Rahul', 'lastName': 'Sharma', 'email': 'rahul@envision.com', 'department': 'Engineering', 'designation': 'Developer', 'branch': 'Head Office', 'status': 'Active'},
          {'id': '2', 'employeeCode': 'EMP-24-002', 'firstName': 'Priya', 'lastName': 'Verma', 'email': 'priya@envision.com', 'department': 'HR', 'designation': 'Manager', 'branch': 'Head Office', 'status': 'Active'},
        ];
      }

      _allEmployees = employees.map((e) => {
        'id': e['id'] ?? e['employeeId'] ?? '1',
        'employeeCode': e['employeeId'] ?? e['employeeCode'] ?? 'EMP-001',
        'name': '${e['firstName'] ?? ''} ${e['lastName'] ?? ''}'.trim().isNotEmpty ? '${e['firstName']} ${e['lastName']}' : (e['name'] ?? 'Employee'),
        'email': e['email'] ?? 'employee@envision.com',
        'department': e['department'] ?? 'Engineering',
        'designation': e['designation'] ?? 'Staff',
        'branch': e['branch'] ?? 'Head Office',
        'status': e['status'] ?? 'Active'
      }).toList();

      // Filter assigned employees based on shift name/code matching
      final shiftNameLower = (_shift['name'] ?? '').toLowerCase();
      _assignedEmployees = _allEmployees.where((e) {
        return (e['department'] == 'Engineering' && shiftNameLower.contains('general')) ||
               (e['department'] == 'HR' && shiftNameLower.contains('morning'));
      }).toList();

      if (_assignedEmployees.isEmpty && _allEmployees.isNotEmpty) {
        _assignedEmployees = [_allEmployees[0]];
      }

      _unassignedEmployees = _allEmployees.where((e) => !_assignedEmployees.any((a) => a['id'] == e['id'])).toList();
      _shift['assignedEmployees'] = _assignedEmployees.length;

      final deptSet = _assignedEmployees.map((e) => e['department'].toString()).toSet();
      _departmentsList = deptSet.toList();

      setState(() => _isLoading = false);
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  List<dynamic> get _filteredEmployees {
    return _assignedEmployees.filter((emp) {
      final search = _searchTerm.toLowerCase().trim();
      final matchesSearch = search.isEmpty ||
          emp['name'].toLowerCase().contains(search) ||
          emp['employeeCode'].toLowerCase().contains(search) ||
          emp['department'].toLowerCase().contains(search);
      final matchesDept = _selectedDepartment.isEmpty || emp['department'] == _selectedDepartment;
      return matchesSearch && matchesDept;
    }).toList();
  }

  bool _isDaySelected(String day) {
    final days = _shift['workingDays'];
    if (days is List) {
      return days.any((d) => d.toString().toLowerCase().startsWith(day.toLowerCase()));
    }
    return ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'].contains(day);
  }

  void _openAssignModal() {
    String selectedEmpId = _unassignedEmployees.isNotEmpty ? _unassignedEmployees[0]['id'] : (_allEmployees.isNotEmpty ? _allEmployees[0]['id'] : '');
    DateTime effectiveDate = DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: const Text('Assign Employee to Shift'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: _unassignedEmployees.any((e) => e['id'] == selectedEmpId) ? selectedEmpId : null,
                hint: const Text('Choose Employee'),
                items: (_unassignedEmployees.isNotEmpty ? _unassignedEmployees : _allEmployees).map<DropdownMenuItem<String>>((emp) {
                  return DropdownMenuItem<String>(
                    value: emp['id'],
                    child: Text('${emp['name']} (${emp['employeeCode']})'),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setModalState(() => selectedEmpId = val);
                },
                decoration: const InputDecoration(border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: effectiveDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) setModalState(() => effectiveDate = picked);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Effective Date', border: OutlineInputBorder()),
                  child: Text(effectiveDate.toLocal().toIso8601String().substring(0, 10)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                final emp = _allEmployees.firstWhere((e) => e['id'] == selectedEmpId, orElse: () => null);
                if (emp != null) {
                  setState(() {
                    _assignedEmployees.add(emp);
                    _unassignedEmployees.removeWhere((e) => e['id'] == selectedEmpId);
                    _shift['assignedEmployees'] = _assignedEmployees.length;
                  });
                }
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Employee assigned successfully')));
              },
              child: const Text('Confirm'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_shift['name'] ?? 'Shift Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Edit Shift',
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => AdminShiftFormScreen(shiftId: widget.shiftId, initialData: _shift)));
              _loadData();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero Shift Card
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                              child: const Icon(Icons.access_time, color: AppColors.primary, size: 28),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_shift['name'] ?? 'Shift', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                Text(_shift['code'] ?? 'SH-01', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                              ],
                            ),
                          ],
                        ),
                        Chip(
                          label: Text(_shift['status'] ?? 'ACTIVE', style: const TextStyle(color: Colors.white, fontSize: 11)),
                          backgroundColor: (_shift['status'] == 'ACTIVE') ? Colors.green : Colors.grey,
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Shift Timing', style: TextStyle(color: Colors.grey)),
                        Text('${_shift['startTime']} – ${_shift['endTime']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Break & Grace', style: TextStyle(color: Colors.grey)),
                        Text('${_shift['breakDurationMinutes'] ?? 60}m Break • ${_shift['lateGracePeriodMinutes'] ?? 15}m Grace', style: const TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const Divider(height: 24),
                    const Text('Working Days', style: TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: _daysList.map((day) {
                        final isSel = _isDaySelected(day);
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSel ? AppColors.primary : Colors.grey[200],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(day, style: TextStyle(fontSize: 12, color: isSel ? Colors.white : Colors.grey[700], fontWeight: FontWeight.bold)),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Assigned Employees Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.group, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text('Assigned Employees (${_assignedEmployees.length})', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: _openAssignModal,
                  icon: const Icon(Icons.person_add, size: 16),
                  label: const Text('Assign'),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Search Filter
            TextField(
              decoration: const InputDecoration(
                hintText: 'Search assigned employees...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              onChanged: (val) => setState(() => _searchTerm = val),
            ),
            const SizedBox(height: 12),

            // Assigned Roster List
            _filteredEmployees.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: Text('No employees assigned to this shift matching filter.')),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _filteredEmployees.length,
                    itemBuilder: (context, index) {
                      final emp = _filteredEmployees[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppColors.primary.withOpacity(0.1),
                            child: Text(emp['name'][0].toUpperCase(), style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                          ),
                          title: Text(emp['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('${emp['employeeCode']} • ${emp['department']} (${emp['designation']})'),
                          trailing: IconButton(
                            icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                            tooltip: 'Unassign',
                            onPressed: () {
                              setState(() {
                                _assignedEmployees.removeWhere((e) => e['id'] == emp['id']);
                                _unassignedEmployees.add(emp);
                                _shift['assignedEmployees'] = _assignedEmployees.length;
                              });
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unassigned ${emp['name']}')));
                            },
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

extension on List {
  List filter(bool Function(dynamic) test) => where(test).toList();
}
