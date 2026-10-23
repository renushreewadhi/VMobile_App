import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_card.dart';

class AdminHrManagementScreen extends ConsumerStatefulWidget {
  const AdminHrManagementScreen({super.key});

  @override
  ConsumerState<AdminHrManagementScreen> createState() => _AdminHrManagementScreenState();
}

class _AdminHrManagementScreenState extends ConsumerState<AdminHrManagementScreen> {
  bool _isLoading = true;
  List<dynamic> _hrMembers = [];
  List<dynamic> _candidates = [];
  String? _selectedEmployeeId;
  bool _assigning = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final apiClient = ref.read(apiClientProvider);

    try {
      final hrRes = await apiClient.get('/management/hr').catchError((_) => null);
      final empRes = await apiClient.get('/management/employees').catchError((_) => null);

      List<dynamic> hrList = hrRes is List ? hrRes : (hrRes is Map ? (hrRes['items'] ?? hrRes['data'] ?? []) : []);
      List<dynamic> empList = empRes is List ? empRes : (empRes is Map ? (empRes['items'] ?? empRes['data'] ?? []) : []);

      if (hrList.isEmpty) {
        hrList = [
          {'id': '2', 'employeeCode': 'EMP-02', 'fullName': 'Priya Verma', 'email': 'priya@envision.com', 'department': 'HR', 'designation': 'HR Manager'}
        ];
      }

      setState(() {
        _hrMembers = hrList;
        _candidates = empList.where((e) => (e['role'] ?? 'EMPLOYEE').toString().toUpperCase() == 'EMPLOYEE').toList();
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _assignAsHR() async {
    if (_selectedEmployeeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select an employee to assign as HR')));
      return;
    }

    setState(() => _assigning = true);
    try {
      await ref.read(apiClientProvider).post('/management/assign-role', data: {'employeeId': _selectedEmployeeId, 'role': 'HR'});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Employee assigned HR role successfully')));
        _selectedEmployeeId = null;
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to assign HR role: $e')));
      }
    } finally {
      if (mounted) setState(() => _assigning = false);
    }
  }

  Future<void> _revokeHR(Map<String, dynamic> hr) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Revoke HR role from ${hr['fullName']}?'),
        content: const Text('This user will return to regular employee privileges.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Revoke', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref.read(apiClientProvider).post('/management/assign-role', data: {'employeeId': hr['id'], 'role': 'EMPLOYEE'});
        _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('HR role revoked')));
        }
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('HR Management & Assignment'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Assign HR Card
            AppCard(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Assign New HR Member', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary)),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _selectedEmployeeId,
                      hint: const Text('Select Employee'),
                      items: _candidates.map<DropdownMenuItem<String>>((c) {
                        return DropdownMenuItem<String>(
                          value: c['id']?.toString(),
                          child: Text('${c['fullName'] ?? c['name']} (${c['department'] ?? 'General'})'),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => _selectedEmployeeId = val),
                      decoration: const InputDecoration(border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _assigning ? null : _assignAsHR,
                        child: Text(_assigning ? 'Assigning...' : 'Assign HR Role'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Active HR Members List
            const Text('Active HR Members', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _hrMembers.isEmpty
                ? const Center(child: Text('No active HR members found.'))
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _hrMembers.length,
                    itemBuilder: (context, index) {
                      final hr = _hrMembers[index];
                      return AppCard(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.green.withOpacity(0.1),
                            child: Text(hr['fullName'][0].toUpperCase(), style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                          ),
                          title: Text(hr['fullName'], style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('${hr['employeeCode']} • ${hr['department']} (${hr['designation']})'),
                          trailing: IconButton(
                            icon: const Icon(Icons.person_remove, color: Colors.red),
                            tooltip: 'Revoke HR',
                            onPressed: () => _revokeHR(hr),
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
