import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/empty_state_widget.dart';
import '../../shared/widgets/error_state_widget.dart';
import '../../shared/widgets/loading_shimmer.dart';

class FinanceSalaryStructureScreen extends ConsumerStatefulWidget {
  const FinanceSalaryStructureScreen({super.key});

  @override
  ConsumerState<FinanceSalaryStructureScreen> createState() => _FinanceSalaryStructureScreenState();
}

class _FinanceSalaryStructureScreenState extends ConsumerState<FinanceSalaryStructureScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _structures = [];

  @override
  void initState() {
    super.initState();
    _loadStructures();
  }

  Future<void> _loadStructures() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    final apiClient = ref.read(apiClientProvider);

    try {
      final res = await apiClient.get(ApiEndpoints.salaryStructures);

      if (mounted) {
        List<dynamic> items = [];
        if (res is List) {
          items = res;
        } else if (res is Map<String, dynamic> && res['data'] is List) {
          items = res['data'];
        } else if (res is Map<String, dynamic> && res['items'] is List) {
          items = res['items'];
        }

        _structures = items.map((s) => _mapStructureItem(s)).toList();
        _isLoading = false;
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _structures = [];
          _errorMessage = e.toString().replaceFirst('Exception: ', '').replaceFirst('ApiException: ', '');
          _isLoading = false;
        });
      }
    }
  }

  Map<String, dynamic> _mapStructureItem(dynamic s) {
    final Map<String, dynamic> map = s is Map<String, dynamic> ? s : {};
    return {
      'grade': map['name'] ?? map['grade'] ?? 'Standard Structure',
      'basePay': map['basicSalary'] != null
          ? '₹${map['basicSalary']}'
          : (map['basePay'] ?? '₹0'),
      'HRA': map['hraPercent'] != null ? '${map['hraPercent']}%' : (map['HRA'] ?? '0%'),
      'DA': map['daPercent'] != null ? '${map['daPercent']}%' : (map['DA'] ?? '0%'),
      'medical': map['medicalAllowance'] != null ? '₹${map['medicalAllowance']}' : (map['medical'] ?? '₹0'),
      'bonus': map['bonusPercent'] != null ? '${map['bonusPercent']}%' : (map['bonus'] ?? '0%'),
    };
  }

  void _showAddGradeDialog() {
    final TextEditingController gradeController = TextEditingController();
    final TextEditingController basePayController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.calculate, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Add Salary Grade', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Grade Name *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.lightSecondaryText)),
            const SizedBox(height: 4),
            TextField(
              controller: gradeController,
              decoration: InputDecoration(
                hintText: 'e.g. Lead Engineer L3',
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 12),
            const Text('Base Pay Range *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.lightSecondaryText)),
            const SizedBox(height: 4),
            TextField(
              controller: basePayController,
              decoration: InputDecoration(
                hintText: 'e.g. ₹90,000 - ₹1,50,000',
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (gradeController.text.trim().isEmpty) return;
              setState(() {
                _structures.insert(0, {
                  'grade': gradeController.text.trim(),
                  'basePay': basePayController.text.trim().isNotEmpty ? basePayController.text.trim() : '₹50,000 - ₹90,000',
                  'HRA': '20%',
                  'DA': '10%',
                  'medical': '₹1,500',
                  'bonus': '8%',
                });
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Salary grade added successfully'), backgroundColor: AppColors.success),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            child: const Text('Save Grade'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const GlassScaffold(
        title: 'Salary Structures',
        body: DashboardSkeleton(),
      );
    }
    if (_errorMessage != null) {
      return GlassScaffold(
        title: 'Salary Structures',
        body: ErrorStateWidget(
          errorMessage: _errorMessage!,
          onRetry: _loadStructures,
        ),
      );
    }

    return GlassScaffold(
      title: 'Salary Structures',
      body: RefreshIndicator(
        onRefresh: _loadStructures,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Header Card
              AppCard(
                backgroundColor: AppColors.darkPrimary,
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.white24,
                      child: Icon(Icons.calculate, color: Colors.white, size: 26),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Salary Structure Configuration',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Configure salary grades, HRA, DA, medical, & variable bonuses',
                            style: TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _showAddGradeDialog,
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Add Grade'),
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

              // Salary Structure Cards Grid
              _structures.isEmpty
                  ? const EmptyStateWidget(
                      title: 'No Salary Structures',
                      message: 'There are no configured salary structures found on the server.',
                      icon: Icons.calculate_outlined,
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _structures.length,
                      itemBuilder: (context, index) {
                  final item = _structures[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                item['grade'] ?? '',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.successBg,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Text(
                                  'Active',
                                  style: TextStyle(fontSize: 11, color: AppColors.success, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          const Text('Base Pay Range', style: TextStyle(fontSize: 11, color: AppColors.lightMutedText)),
                          const SizedBox(height: 2),
                          Text(
                            item['basePay'] ?? '',
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.lightPrimaryText),
                          ),
                          const SizedBox(height: 14),

                          // Components Grid (HRA, DA, Medical, Bonus)
                          Row(
                            children: [
                              Expanded(child: _buildComponentBox('HRA', item['HRA'] ?? '')),
                              const SizedBox(width: 8),
                              Expanded(child: _buildComponentBox('DA', item['DA'] ?? '')),
                              const SizedBox(width: 8),
                              Expanded(child: _buildComponentBox('Medical', item['medical'] ?? '')),
                              const SizedBox(width: 8),
                              Expanded(child: _buildComponentBox('Bonus', item['bonus'] ?? '')),
                            ],
                          ),
                          const Divider(height: 18),

                          Align(
                            alignment: Alignment.centerRight,
                            child: OutlinedButton.icon(
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Editing grade: ${item['grade']}'), backgroundColor: AppColors.primary),
                                );
                              },
                              icon: const Icon(Icons.edit_outlined, size: 14),
                              label: const Text('Edit Grade'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildComponentBox(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.lightInputBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: AppColors.lightMutedText, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.lightPrimaryText)),
        ],
      ),
    );
  }
}
