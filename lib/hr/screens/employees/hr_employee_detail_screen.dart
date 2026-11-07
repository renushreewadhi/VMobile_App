import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/glass_header.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/loading_shimmer.dart';
import 'hr_employee_form_screen.dart';

class HrEmployeeDetailScreen extends ConsumerStatefulWidget {
  final String employeeId;

  const HrEmployeeDetailScreen({super.key, required this.employeeId});

  @override
  ConsumerState<HrEmployeeDetailScreen> createState() => _HrEmployeeDetailScreenState();
}

class _HrEmployeeDetailScreenState extends ConsumerState<HrEmployeeDetailScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _employee;
  String _activeTab = 'personal';

  final List<Map<String, dynamic>> _tabs = [
    {'id': 'personal', 'label': 'Personal', 'icon': Icons.person},
    {'id': 'contact', 'label': 'Contact', 'icon': Icons.phone},
    {'id': 'job', 'label': 'Job', 'icon': Icons.work},
    {'id': 'salary', 'label': 'Salary', 'icon': Icons.wallet},
  ];

  @override
  void initState() {
    super.initState();
    _loadEmployeeDetail();
  }

  Future<void> _loadEmployeeDetail() async {
    setState(() => _isLoading = true);
    final apiClient = ref.read(apiClientProvider);
    try {
      final res = await apiClient.get('/management/employees/${widget.employeeId}').catchError((_) => null);
      final empMap = res is Map<String, dynamic> ? (res['data'] ?? res) : null;
      setState(() {
        _employee = empMap;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const LoadingShimmer();
    if (_employee == null) {
      return const GlassScaffold(
        title: 'Employee Details',
        body: Center(child: Text('Employee not found')),
      );
    }

    final fullName = '${_employee!['firstName'] ?? ''} ${_employee!['lastName'] ?? ''}'.trim();
    final name = fullName.isNotEmpty ? fullName : (_employee!['name'] ?? 'Employee');

    return GlassScaffold(
      appBar: GlassHeader(
        title: name,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => HrEmployeeFormScreen(employeeId: widget.employeeId, initialData: _employee)),
              );
              _loadEmployeeDetail();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppCard(
              backgroundColor: AppColors.primary,
              child: Row(
                children: [
                  CircleAvatar(radius: 30, child: Text(name.isNotEmpty ? name[0] : 'E', style: const TextStyle(fontSize: 24))),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('${_employee!['designation'] ?? 'Staff'} • ${_employee!['department'] ?? 'General'}', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                        const SizedBox(height: 2),
                        Text(_employee!['email'] ?? '', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Tab Buttons
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: _tabs.map((t) {
                  final isActive = _activeTab == t['id'];
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Material(
                      color: Colors.transparent,
                      child: ChoiceChip(
                        label: Text(t['label']),
                        selected: isActive,
                        onSelected: (val) => setState(() => _activeTab = t['id']),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
            // Tab Content
            if (_activeTab == 'personal') _buildPersonalTab(),
            if (_activeTab == 'contact') _buildContactTab(),
            if (_activeTab == 'job') _buildJobTab(),
            if (_activeTab == 'salary') _buildSalaryTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonalTab() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Personal Information', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const Divider(),
          _infoRow('First Name', _employee!['firstName']),
          _infoRow('Last Name', _employee!['lastName']),
          _infoRow('Gender', _employee!['gender']),
          _infoRow('Date of Birth', _employee!['dateOfBirth']),
          _infoRow('Marital Status', _employee!['maritalStatus']),
          _infoRow('Nationality', _employee!['nationality']),
        ],
      ),
    );
  }

  Widget _buildContactTab() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Contact Information', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const Divider(),
          _infoRow('Email', _employee!['email']),
          _infoRow('Phone', _employee!['phone']),
          _infoRow('Address', _employee!['address']),
          _infoRow('City', _employee!['city']),
          _infoRow('Country', _employee!['country']),
        ],
      ),
    );
  }

  Widget _buildJobTab() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Job Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const Divider(),
          _infoRow('Employee ID', _employee!['employeeId']),
          _infoRow('Department', _employee!['department']),
          _infoRow('Designation', _employee!['designation']),
          _infoRow('Branch', _employee!['branch']),
          _infoRow('Joining Date', _employee!['joiningDate']),
          _infoRow('Employment Type', _employee!['employmentType']),
        ],
      ),
    );
  }

  Widget _buildSalaryTab() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Salary & Bank Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const Divider(),
          _infoRow('Basic Salary', '\$${_employee!['salary'] ?? _employee!['basicSalary'] ?? 0}'),
          _infoRow('Allowances', '\$${_employee!['allowances'] ?? 0}'),
          _infoRow('Bank Name', _employee!['bankName']),
          _infoRow('Account Number', _employee!['bankAccountNumber'] ?? _employee!['accountNumber']),
        ],
      ),
    );
  }

  Widget _infoRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text('${value ?? '—'}', style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
