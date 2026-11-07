import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/loading_shimmer.dart';

class FinanceSalaryComponentsScreen extends ConsumerStatefulWidget {
  const FinanceSalaryComponentsScreen({super.key});

  @override
  ConsumerState<FinanceSalaryComponentsScreen> createState() => _FinanceSalaryComponentsScreenState();
}

class _FinanceSalaryComponentsScreenState extends ConsumerState<FinanceSalaryComponentsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _components = [];

  @override
  void initState() {
    super.initState();
    _loadComponents();
  }

  Future<void> _loadComponents() async {
    setState(() => _isLoading = true);
    final apiClient = ref.read(apiClientProvider);

    try {
      final res = await apiClient.get(ApiEndpoints.salaryComponents).catchError((_) => null);

      if (mounted) {
        List<dynamic> items = [];
        if (res is List) {
          items = res;
        } else if (res is Map<String, dynamic> && res['data'] is List) {
          items = res['data'];
        } else if (res is Map<String, dynamic> && res['items'] is List) {
          items = res['items'];
        }

        if (items.isNotEmpty) {
          _components = items.map((c) => _mapComponent(c)).toList();
        } else {
          _components = _getMockComponents();
        }
        _isLoading = false;
        setState(() {});
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _components = _getMockComponents();
          _isLoading = false;
        });
      }
    }
  }

  Map<String, dynamic> _mapComponent(dynamic c) {
    final Map<String, dynamic> map = c is Map<String, dynamic> ? c : {};
    return {
      'name': map['name'] ?? 'Component',
      'type': map['type'] ?? 'Earning',
      'calculationType': map['calculationType'] ?? 'Percentage of Basic',
      'taxable': map['isTaxable'] == true ? 'Taxable' : 'Non-Taxable',
      'status': 'Active',
    };
  }

  List<Map<String, dynamic>> _getMockComponents() {
    return [
      {'name': 'Basic Salary', 'type': 'Earning', 'calculationType': 'Fixed / 50% of CTC', 'taxable': 'Taxable', 'status': 'Active'},
      {'name': 'House Rent Allowance (HRA)', 'type': 'Earning', 'calculationType': '40% of Basic', 'taxable': 'Exempt under Section 10(13A)', 'status': 'Active'},
      {'name': 'Dearness Allowance (DA)', 'type': 'Earning', 'calculationType': '10% of Basic', 'taxable': 'Taxable', 'status': 'Active'},
      {'name': 'Medical Allowance', 'type': 'Earning', 'calculationType': 'Fixed ₹1,250 / month', 'taxable': 'Non-Taxable', 'status': 'Active'},
      {'name': 'Provident Fund (PF)', 'type': 'Deduction', 'calculationType': '12% of Basic', 'taxable': 'Tax Deductible 80C', 'status': 'Active'},
      {'name': 'Professional Tax', 'type': 'Deduction', 'calculationType': 'Flat ₹200 / month', 'taxable': 'Statutory Deduction', 'status': 'Active'},
    ];
  }

  void _showAddComponentDialog() {
    final nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.list_alt, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Add Salary Component', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Component Name *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            TextField(controller: nameController, decoration: InputDecoration(hintText: 'e.g. Special Allowance', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.trim().isEmpty) return;
              setState(() {
                _components.insert(0, {
                  'name': nameController.text.trim(),
                  'type': 'Earning',
                  'calculationType': 'Fixed Amount',
                  'taxable': 'Taxable',
                  'status': 'Active',
                });
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Salary component added successfully'), backgroundColor: AppColors.success));
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            child: const Text('Save Component'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const DashboardSkeleton();

    return RefreshIndicator(
      onRefresh: _loadComponents,
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
                    child: Icon(Icons.list_alt, color: Colors.white, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('Salary Components', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        SizedBox(height: 4),
                        Text('Configure earnings, deductions, allowances & tax rules', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _showAddComponentDialog,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add Component'),
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

            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _components.length,
              itemBuilder: (context, index) {
                final item = _components[index];
                final isEarning = item['type'] == 'Earning';
                final badgeColor = isEarning ? AppColors.success : Colors.orange;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: badgeColor.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                              child: Text(item['type'], style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: badgeColor)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text('Calculation: ${item['calculationType']}', style: const TextStyle(fontSize: 12, color: AppColors.lightPrimaryText, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.info_outline, size: 13, color: AppColors.lightMutedText),
                            const SizedBox(width: 4),
                            Text(item['taxable'], style: const TextStyle(fontSize: 11, color: AppColors.lightMutedText)),
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
