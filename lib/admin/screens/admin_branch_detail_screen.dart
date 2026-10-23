import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_card.dart';
import 'admin_branch_form_screen.dart';

class AdminBranchDetailScreen extends ConsumerStatefulWidget {
  final String branchId;

  const AdminBranchDetailScreen({super.key, required this.branchId});

  @override
  ConsumerState<AdminBranchDetailScreen> createState() => _AdminBranchDetailScreenState();
}

class _AdminBranchDetailScreenState extends ConsumerState<AdminBranchDetailScreen> {
  bool _isLoading = true;
  Map<String, dynamic> _branch = {};
  List<dynamic> _branchEmployees = [];

  @override
  void initState() {
    super.initState();
    _loadBranchDetail();
  }

  Future<void> _loadBranchDetail() async {
    setState(() => _isLoading = true);
    final apiClient = ref.read(apiClientProvider);

    try {
      final res = await apiClient.get('/departments/branches').catchError((_) => null);
      final empRes = await apiClient.get('/management/employees').catchError((_) => null);

      List<dynamic> branches = res is List ? res : (res is Map ? (res['items'] ?? res['data'] ?? []) : []);
      final b = branches.firstWhere((item) => item['id'] == widget.branchId, orElse: () => null);

      List<dynamic> emps = empRes is List ? empRes : (empRes is Map ? (empRes['items'] ?? empRes['data'] ?? []) : []);

      setState(() {
        _branch = b ?? {'name': 'Head Office', 'code': 'HO-01', 'city': 'Surat', 'state': 'Gujarat', 'country': 'India', 'status': 'Active'};
        _branchEmployees = emps;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deactivateBranch() async {
    try {
      await ref.read(apiClientProvider).delete('/departments/branches/${widget.branchId}');
      setState(() {
        _branch['status'] = 'Inactive';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Branch deactivated successfully')));
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final isActive = (_branch['status'] ?? 'Active').toString().toUpperCase() == 'ACTIVE';

    return Scaffold(
      appBar: AppBar(
        title: Text(_branch['name'] ?? 'Branch Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Edit Branch',
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => AdminBranchFormScreen(branchId: widget.branchId, initialData: _branch)));
              _loadBranchDetail();
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            tooltip: 'Deactivate Branch',
            onPressed: _deactivateBranch,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Branch Header Card
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
                            CircleAvatar(
                              radius: 28,
                              backgroundColor: AppColors.primary.withOpacity(0.1),
                              child: const Icon(Icons.business, size: 28, color: AppColors.primary),
                            ),
                            const SizedBox(width: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_branch['name'] ?? 'Branch Name', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                                Text('${_branch['code'] ?? 'CODE'} • ${_branch['city'] ?? 'City'}', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                              ],
                            ),
                          ],
                        ),
                        Chip(
                          label: Text(isActive ? 'Active' : 'Inactive', style: const TextStyle(color: Colors.white)),
                          backgroundColor: isActive ? Colors.green : Colors.grey,
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      children: [
                        const Icon(Icons.location_on, size: 18, color: Colors.grey),
                        const SizedBox(width: 8),
                        Text('Address: ${_branch['address'] ?? 'Not specified'}, ${_branch['city'] ?? ''}, ${_branch['state'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.phone, size: 18, color: Colors.grey),
                        const SizedBox(width: 8),
                        Text('Phone: ${_branch['phone'] ?? 'N/A'}', style: const TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Branch Employees
            const Text('Branch Staff Roster', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
            const SizedBox(height: 12),
            _branchEmployees.isEmpty
                ? const Center(child: Text('No employees found for this branch.'))
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _branchEmployees.length,
                    itemBuilder: (context, index) {
                      final emp = _branchEmployees[index];
                      final name = '${emp['firstName'] ?? ''} ${emp['lastName'] ?? ''}'.trim().isNotEmpty ? '${emp['firstName']} ${emp['lastName']}' : (emp['name'] ?? 'Employee');
                      return AppCard(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppColors.primary.withOpacity(0.1),
                            child: Text(name[0].toUpperCase(), style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                          ),
                          title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('${emp['employeeCode'] ?? emp['id']} • ${emp['department'] ?? 'General'} (${emp['designation'] ?? 'Staff'})'),
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
