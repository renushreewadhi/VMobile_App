import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/empty_state_widget.dart';
import '../../shared/widgets/error_state_widget.dart';
import '../../shared/widgets/loading_shimmer.dart';

class FinancePayrollInputsScreen extends ConsumerStatefulWidget {
  const FinancePayrollInputsScreen({super.key});

  @override
  ConsumerState<FinancePayrollInputsScreen> createState() => _FinancePayrollInputsScreenState();
}

class _FinancePayrollInputsScreenState extends ConsumerState<FinancePayrollInputsScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _inputs = [];
  String _searchQuery = '';
  String _selectedCycle = 'October 2025';

  @override
  void initState() {
    super.initState();
    _loadInputs();
  }

  Future<void> _loadInputs() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    final apiClient = ref.read(apiClientProvider);

    try {
      final res = await apiClient.get(ApiEndpoints.payrollInputs);

      if (mounted) {
        List<dynamic> items = [];
        if (res is List) {
          items = res;
        } else if (res is Map<String, dynamic> && res['data'] is List) {
          items = res['data'];
        } else if (res is Map<String, dynamic> && res['items'] is List) {
          items = res['items'];
        }

        _inputs = items.map((i) => _mapInput(i)).toList();
        _isLoading = false;
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _inputs = [];
          _errorMessage = e.toString().replaceFirst('Exception: ', '').replaceFirst('ApiException: ', '');
          _isLoading = false;
        });
      }
    }
  }

  Map<String, dynamic> _mapInput(dynamic i) {
    final Map<String, dynamic> map = i is Map<String, dynamic> ? i : {};
    return {
      'name': map['employeeName'] ?? map['name'] ?? 'John Doe',
      'empId': map['employeeId'] ?? map['empId'] ?? map['id'] ?? 'EMP-1024',
      'department': map['department'] ?? map['departmentName'] ?? 'Engineering',
      'overtimeHours': map['overtimeHours']?.toString() ?? '0',
      'bonus': map['bonus'] != null ? '₹${map['bonus']}' : '₹0',
      'deductions': map['deductions'] != null ? '₹${map['deductions']}' : '₹0',
      'status': map['status'] ?? 'Submitted',
    };
  }

  void _showAddInputDialog() {
    final nameController = TextEditingController();
    final empIdController = TextEditingController();
    final bonusController = TextEditingController();
    final otController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.playlist_add, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Add Payroll Input', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Employee Name *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              TextField(controller: nameController, decoration: InputDecoration(hintText: 'e.g. Vikram Singh', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
              const SizedBox(height: 12),
              const Text('Employee ID *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              TextField(controller: empIdController, decoration: InputDecoration(hintText: 'e.g. EMP-5021', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
              const SizedBox(height: 12),
              const Text('Variable Bonus (₹)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              TextField(controller: bonusController, keyboardType: TextInputType.number, decoration: InputDecoration(hintText: 'e.g. 5000', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
              const SizedBox(height: 12),
              const Text('Overtime Hours', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              TextField(controller: otController, keyboardType: TextInputType.number, decoration: InputDecoration(hintText: 'e.g. 10', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.trim().isEmpty) return;
              setState(() {
                _inputs.insert(0, {
                  'name': nameController.text.trim(),
                  'empId': empIdController.text.trim().isNotEmpty ? empIdController.text.trim() : 'EMP-9999',
                  'department': 'General',
                  'overtimeHours': otController.text.trim().isNotEmpty ? otController.text.trim() : '0',
                  'bonus': bonusController.text.trim().isNotEmpty ? '₹${bonusController.text.trim()}' : '₹0',
                  'deductions': '₹1,000',
                  'status': 'Submitted',
                });
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payroll input added successfully'), backgroundColor: AppColors.success));
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const DashboardSkeleton();
    if (_errorMessage != null) {
      return ErrorStateWidget(
        errorMessage: _errorMessage!,
        onRetry: _loadInputs,
      );
    }

    final filtered = _inputs.where((item) {
      final q = _searchQuery.toLowerCase();
      return (item['name'] ?? '').toLowerCase().contains(q) ||
          (item['empId'] ?? '').toLowerCase().contains(q) ||
          (item['department'] ?? '').toLowerCase().contains(q);
    }).toList();

    return RefreshIndicator(
      onRefresh: _loadInputs,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppCard(
              backgroundColor: AppColors.darkPrimary,
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.white24,
                    child: Icon(Icons.playlist_add_check, color: Colors.white, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Payroll Inputs & Adjustments',
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Cycle: $_selectedCycle | Overtime, Bonuses & Deductions',
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _showAddInputDialog,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add Input'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.darkPrimary,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Search Bar
            TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: 'Search by employee name, ID or department...',
                prefixIcon: const Icon(Icons.search, color: AppColors.primary),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade300)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade300)),
              ),
            ),
            const SizedBox(height: 16),

            // List of Inputs
            filtered.isEmpty
                ? EmptyStateWidget(
                    title: _inputs.isEmpty ? 'No Payroll Inputs' : 'No Matching Inputs',
                    message: _inputs.isEmpty
                        ? 'There are no payroll input adjustments found for this cycle.'
                        : 'No payroll inputs matched "$_searchQuery".',
                    icon: _inputs.isEmpty ? Icons.playlist_add_check_outlined : Icons.search_off_rounded,
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                final item = filtered[index];
                final status = item['status'] ?? 'Submitted';
                final statusColor = status == 'Approved' ? AppColors.success : (status == 'Pending' ? Colors.orange : AppColors.primary);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: AppColors.primary.withOpacity(0.15),
                                  child: Text(
                                    (item['name'] as String).substring(0, 1),
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                    Text('${item['empId']} • ${item['department']}', style: const TextStyle(fontSize: 11, color: AppColors.lightMutedText)),
                                  ],
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Divider(height: 1),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildInputStat('Overtime', '${item['overtimeHours']} hrs', Icons.timer),
                            _buildInputStat('Bonus', item['bonus'], Icons.card_giftcard),
                            _buildInputStat('Deductions', item['deductions'], Icons.remove_circle_outline),
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

  Widget _buildInputStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: AppColors.lightMutedText),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 11, color: AppColors.lightMutedText)),
          ],
        ),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.lightPrimaryText)),
      ],
    );
  }
}
