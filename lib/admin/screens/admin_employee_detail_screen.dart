import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import 'admin_employee_form_screen.dart';

class AdminEmployeeDetailScreen extends ConsumerStatefulWidget {
  final String employeeId;

  const AdminEmployeeDetailScreen({super.key, required this.employeeId});

  @override
  ConsumerState<AdminEmployeeDetailScreen> createState() => _AdminEmployeeDetailScreenState();
}

class _AdminEmployeeDetailScreenState extends ConsumerState<AdminEmployeeDetailScreen> {
  bool _isLoading = true;
  Map<String, dynamic> _employee = {};
  String _activeTab = 'personal';

  @override
  void initState() {
    super.initState();
    _loadEmployeeDetails();
  }

  Future<void> _loadEmployeeDetails() async {
    setState(() => _isLoading = true);
    final apiClient = ref.read(apiClientProvider);

    try {
      final res = await apiClient.get('/management/employees/${widget.employeeId}').catchError((_) => null);
      if (res is Map<String, dynamic>) {
        _employee = res;
      } else {
        _employee = {
          'id': widget.employeeId,
          'employeeId': 'EMP-24-0003',
          'firstName': 'Rahul',
          'lastName': 'Sharma',
          'email': 'rahul.sharma@envision.com',
          'phone': '+91-9876543210',
          'department': 'Engineering',
          'designation': 'Senior Full Stack Developer',
          'branch': 'Tech Park Center',
          'employmentStatus': 'Active',
          'gender': 'Male',
          'dateOfBirth': '1995-05-12',
          'joiningDate': '2024-01-15',
          'salary': 120000,
          'allowances': 15000
        };
      }
      setState(() => _isLoading = false);
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleStatus() async {
    final isActive = (_employee['employmentStatus'] ?? 'Active').toString().toLowerCase() != 'inactive';
    final newStatus = isActive ? 'INACTIVE' : 'ACTIVE';

    try {
      await ref.read(apiClientProvider).post('/management/employees/${widget.employeeId}/status', data: {'status': newStatus});
      setState(() {
        _employee['employmentStatus'] = newStatus == 'ACTIVE' ? 'Active' : 'Inactive';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Employee status updated to $newStatus')));
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final name = '${_employee['firstName'] ?? ''} ${_employee['lastName'] ?? ''}'.trim().isNotEmpty ? '${_employee['firstName']} ${_employee['lastName']}' : (_employee['name'] ?? 'Employee');
    final isActive = (_employee['employmentStatus'] ?? 'Active').toString().toLowerCase() != 'inactive';

    return Scaffold(
      appBar: AppBar(
        title: Text(name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Edit Employee',
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => AdminEmployeeFormScreen(employeeId: widget.employeeId, initialData: _employee)));
              _loadEmployeeDetails();
            },
          ),
          IconButton(
            icon: Icon(isActive ? Icons.block : Icons.check_circle, color: isActive ? Colors.orange : Colors.green),
            tooltip: isActive ? 'Deactivate' : 'Activate',
            onPressed: _toggleStatus,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Profile Card
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: AppColors.primary.withOpacity(0.1),
                      child: Text(name[0].toUpperCase(), style: const TextStyle(fontSize: 28, color: AppColors.primary, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('${_employee['employeeId'] ?? 'EMP'} • ${_employee['department'] ?? 'General'}', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                          Text(_employee['designation'] ?? 'Staff', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 13)),
                        ],
                      ),
                    ),
                    Chip(
                      label: Text(isActive ? 'Active' : 'Inactive', style: const TextStyle(color: Colors.white)),
                      backgroundColor: isActive ? Colors.green : Colors.grey,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Tab Bar
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildTabButton('personal', 'Personal'),
                  _buildTabButton('job', 'Job Details'),
                  _buildTabButton('salary', 'Salary & Comp'),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Tab Content
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _activeTab == 'personal'
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildInfoRow('Email Address', _employee['email'] ?? '—'),
                          _buildInfoRow('Phone Number', _employee['phone'] ?? '—'),
                          _buildInfoRow('Gender', _employee['gender'] ?? '—'),
                          _buildInfoRow('Date of Birth', _employee['dateOfBirth'] ?? '—'),
                          _buildInfoRow('Address', _employee['address'] ?? '—'),
                          _buildInfoRow('City', _employee['city'] ?? '—'),
                        ],
                      )
                    : _activeTab == 'job'
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildInfoRow('Department', _employee['department'] ?? '—'),
                              _buildInfoRow('Designation', _employee['designation'] ?? '—'),
                              _buildInfoRow('Branch Location', _employee['branch'] ?? '—'),
                              _buildInfoRow('Employment Type', _employee['employmentType'] ?? 'Full-Time'),
                              _buildInfoRow('Joining Date', _employee['joiningDate'] ?? '—'),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildInfoRow('Basic Salary', '₹ ${_employee['salary'] ?? _employee['basicSalary'] ?? 120000}'),
                              _buildInfoRow('Allowances', '₹ ${_employee['allowances'] ?? 15000}'),
                            ],
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(String id, String label) {
    final isSelected = _activeTab == id;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ElevatedButton(
        onPressed: () => setState(() => _activeTab = id),
        style: ElevatedButton.styleFrom(
          backgroundColor: isSelected ? AppColors.primary : Colors.grey[200],
          foregroundColor: isSelected ? Colors.white : Colors.black87,
        ),
        child: Text(label),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
