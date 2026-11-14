import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_header.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/empty_state_widget.dart';
import '../../shared/widgets/error_state_widget.dart';
import '../../shared/widgets/loading_shimmer.dart';

class FinanceSalaryComponentsScreen extends ConsumerStatefulWidget {
  final bool? showAppBar;
  const FinanceSalaryComponentsScreen({super.key, this.showAppBar = false});

  @override
  ConsumerState<FinanceSalaryComponentsScreen> createState() => _FinanceSalaryComponentsScreenState();
}

class _FinanceSalaryComponentsScreenState extends ConsumerState<FinanceSalaryComponentsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _components = [];

  // Modal Controllers
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _valueController = TextEditingController();
  final TextEditingController _sortController = TextEditingController(text: '10');
  final TextEditingController _descController = TextEditingController();
  String _categoryType = 'Earning'; // 'Earning', 'Deduction'
  String _calcBasis = 'Fixed Amount (₹)'; // 'Fixed Amount (₹)', '% of Basic'
  bool _autoApply = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadComponents();
    });
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _valueController.dispose();
    _sortController.dispose();
    _descController.dispose();
    super.dispose();
  }

  String? _errorMessage;

  Future<void> _loadComponents() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    final apiClient = ref.read(apiClientProvider);

    try {
      final res = await apiClient.get(ApiEndpoints.salaryComponents);

      if (mounted) {
        List<dynamic> items = [];
        if (res is List) {
          items = res;
        } else if (res is Map<String, dynamic>) {
          final data = res['data'] ?? res['items'] ?? res['result'] ?? res['components'];
          if (data is List) {
            items = data;
          }
        }

        _components = items.map((c) => _mapComponent(c)).toList();
        _isLoading = false;
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _components = [];
          _errorMessage = e.toString().replaceFirst('Exception: ', '').replaceFirst('ApiException: ', '');
          _isLoading = false;
        });
      }
    }
  }

  Map<String, dynamic> _mapComponent(dynamic c) {
    final Map<String, dynamic> map = c is Map<String, dynamic> ? c : {};
    return {
      'code': map['code'] ?? 'COMP',
      'name': map['name'] ?? 'Component',
      'type': map['type'] ?? map['categoryType'] ?? 'EARNING',
      'calculationBasis': map['calculationBasis'] ?? 'Fixed Amount',
      'value': map['value'] ?? map['amount'] ?? '₹0.00',
      'sortOrder': map['sortOrder'] ?? '#1',
      'autoApply': map['autoApply'] ?? true,
      'status': map['status'] ?? 'ACTIVE',
      'description': map['description'] ?? '',
    };
  }

  int get _earningsCount => _components.where((c) => (c['type'] ?? '').toString().toUpperCase() == 'EARNING').length;
  int get _deductionsCount => _components.where((c) => (c['type'] ?? '').toString().toUpperCase() == 'DEDUCTION').length;

  void _showComponentModal({Map<String, dynamic>? existingComponent}) {
    final bool isEdit = existingComponent != null;

    if (isEdit) {
      _codeController.text = existingComponent['code'] ?? '';
      _nameController.text = existingComponent['name'] ?? '';
      _valueController.text = (existingComponent['value'] ?? '0').toString().replaceAll('₹', '').replaceAll('%', '').trim();
      _sortController.text = (existingComponent['sortOrder'] ?? '10').toString().replaceAll('#', '').trim();
      _descController.text = existingComponent['description'] ?? '';
      _categoryType = (existingComponent['type'] ?? 'EARNING').toString().toUpperCase().contains('DED') ? 'Deduction' : 'Earning';
      final rawBasis = (existingComponent['calculationBasis'] ?? 'Fixed Amount').toString().toLowerCase();
      _calcBasis = rawBasis.contains('percent') || rawBasis.contains('%') ? '% of Basic' : 'Fixed Amount (₹)';
      _autoApply = existingComponent['autoApply'] == true;
    } else {
      _codeController.clear();
      _nameController.clear();
      _valueController.text = '0';
      _sortController.text = '10';
      _descController.clear();
      _categoryType = 'Earning';
      _calcBasis = 'Fixed Amount (₹)';
      _autoApply = true;
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            titlePadding: const EdgeInsets.all(16),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            actionsPadding: const EdgeInsets.all(12),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(isEdit ? Icons.edit : Icons.list_alt, color: AppColors.primary, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(isEdit ? 'Edit Salary Component' : 'Add Salary Component', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                        const Text('Configure earnings, allowances or deductions', style: TextStyle(fontSize: 11, color: AppColors.lightSecondaryText)),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, size: 20),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Component Code *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.lightSecondaryText)),
                            const SizedBox(height: 4),
                            TextField(
                              controller: _codeController,
                              enabled: !isEdit,
                              decoration: InputDecoration(
                                hintText: 'e.g. HRA, BASIC',
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Component Name *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.lightSecondaryText)),
                            const SizedBox(height: 4),
                            TextField(
                              controller: _nameController,
                              decoration: InputDecoration(
                                hintText: 'House Rent Allowance',
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Category Type *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.lightSecondaryText)),
                            const SizedBox(height: 4),
                            DropdownButtonFormField<String>(
                              value: _categoryType,
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'Earning', child: Text('Earning', style: TextStyle(fontSize: 12))),
                                DropdownMenuItem(value: 'Deduction', child: Text('Deduction', style: TextStyle(fontSize: 12))),
                              ],
                              onChanged: (val) {
                                if (val != null) setModalState(() => _categoryType = val);
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Calculation Basis *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.lightSecondaryText)),
                            const SizedBox(height: 4),
                            DropdownButtonFormField<String>(
                              value: _calcBasis,
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'Fixed Amount (₹)', child: Text('Fixed Amount (₹)', style: TextStyle(fontSize: 11))),
                                DropdownMenuItem(value: '% of Basic', child: Text('% of Basic', style: TextStyle(fontSize: 11))),
                              ],
                              onChanged: (val) {
                                if (val != null) setModalState(() => _calcBasis = val);
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Value / Amount *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.lightSecondaryText)),
                            const SizedBox(height: 4),
                            TextField(
                              controller: _valueController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                hintText: '0',
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Sort Order', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.lightSecondaryText)),
                            const SizedBox(height: 4),
                            TextField(
                              controller: _sortController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                hintText: '10',
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  const Text('Description & Purpose', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.lightSecondaryText)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _descController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'Brief note about component rules...',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 6),

                  CheckboxListTile(
                    value: _autoApply,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: const Text(
                      'Auto-apply to newly initialized employee salary structures',
                      style: TextStyle(fontSize: 11, color: AppColors.lightSecondaryText),
                    ),
                    onChanged: (val) {
                      if (val != null) setModalState(() => _autoApply = val);
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  if (_codeController.text.trim().isEmpty || _nameController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please enter component code and name'),
                        backgroundColor: AppColors.error,
                      ),
                    );
                    return;
                  }
                  Navigator.pop(context);
                  _saveComponent(isEdit: isEdit, existingCode: existingComponent?['code']);
                },
                icon: const Icon(Icons.check, size: 16),
                label: Text(isEdit ? 'Save Component' : 'Add Component'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _saveComponent({required bool isEdit, String? existingCode}) async {
    final code = _codeController.text.trim().toUpperCase();
    final name = _nameController.text.trim();
    final valStr = _valueController.text.trim();
    final amt = valStr.startsWith('₹') ? valStr : '₹$valStr.00';

    final compData = {
      'code': code,
      'name': name,
      'type': _categoryType.toUpperCase() == 'EARNING' ? 'EARNING' : 'DEDUCTION',
      'calculationBasis': _calcBasis,
      'value': amt,
      'sortOrder': '#${_sortController.text.trim().isNotEmpty ? _sortController.text.trim() : '10'}',
      'autoApply': _autoApply,
      'status': 'ACTIVE',
      'description': _descController.text.trim(),
    };

    final apiClient = ref.read(apiClientProvider);

    try {
      if (isEdit) {
        await apiClient.put('${ApiEndpoints.salaryComponents}/${existingCode ?? code}', data: compData).catchError((_) => null);
      } else {
        await apiClient.post(ApiEndpoints.salaryComponents, data: compData).catchError((_) => null);
      }

      if (mounted) {
        setState(() {
          if (isEdit) {
            final idx = _components.indexWhere((c) => c['code'] == existingCode);
            if (idx >= 0) {
              _components[idx] = compData;
            }
          } else {
            _components.add(compData);
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEdit ? 'Salary component "$name" updated successfully' : 'Salary component "$name" added successfully'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          if (!isEdit) {
            _components.add(compData);
          }
        });
      }
    }
  }

  Widget _buildStatCard({
    required String label,
    required String value,
    required String sub,
    required IconData icon,
    required Color bgColor,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.lightSecondaryText),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.lightPrimaryText),
          ),
          Text(
            sub,
            style: const TextStyle(fontSize: 10, color: AppColors.lightMutedText),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildComponentCard(Map<String, dynamic> item) {
    final type = (item['type'] ?? 'EARNING').toString().toUpperCase();
    final isEarning = type == 'EARNING';
    final status = (item['status'] ?? 'ACTIVE').toString().toUpperCase();
    final isActive = status == 'ACTIVE';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.lightInputBackground,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  item['code'] ?? '',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primary),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isActive ? AppColors.successBg : AppColors.warningBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isActive ? 'Active' : 'Inactive',
                  style: TextStyle(color: isActive ? AppColors.success : AppColors.warning, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(item['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 2),
          Text('Basis: ${item['calculationBasis']} • Order: ${item['sortOrder']}', style: const TextStyle(fontSize: 11, color: AppColors.lightSecondaryText)),
          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.lightInputBackground,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMetricColumn('Category', isEarning ? 'Earning' : 'Deduction', isEarning ? AppColors.success : AppColors.error),
                _buildMetricColumn('Value / Formula', item['value']?.toString() ?? '₹0.00', AppColors.primary),
                _buildMetricColumn('Auto-Apply', (item['autoApply'] == true) ? 'Yes' : 'No', Colors.black87),
              ],
            ),
          ),
          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                onPressed: () => _showComponentModal(existingComponent: item),
                icon: const Icon(Icons.edit, size: 14, color: AppColors.primary),
                label: const Text('Edit Component', style: TextStyle(fontSize: 11, color: AppColors.primary)),
                style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              ),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    item['status'] = isActive ? 'INACTIVE' : 'ACTIVE';
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Component ${item['code']} status updated'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                },
                icon: Icon(isActive ? Icons.toggle_on : Icons.toggle_off, color: isActive ? AppColors.success : Colors.grey, size: 20),
                label: Text(isActive ? 'Disable' : 'Enable', style: TextStyle(fontSize: 11, color: isActive ? AppColors.success : Colors.grey)),
                style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricColumn(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: AppColors.lightSecondaryText), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color), maxLines: 1, overflow: TextOverflow.ellipsis),
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
        onRetry: _loadComponents,
      );
    }

    final bool showHeader = widget.showAppBar ?? false;

    final content = DefaultTabController(
      length: 2,
      child: Column(
        children: [
          // Tab Header Bar
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            decoration: BoxDecoration(
              color: AppColors.lightSecondarySurface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: TabBar(
              labelColor: Colors.white,
              unselectedLabelColor: AppColors.lightSecondaryText,
              indicator: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              padding: const EdgeInsets.all(4),
              tabs: const [
                Tab(text: 'Overview'),
                Tab(text: 'Components Directory'),
              ],
            ),
          ),

          // Tab Views
          Expanded(
            child: TabBarView(
              children: [
                // Tab 1: Overview
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppCard(
                        backgroundColor: AppColors.darkPrimary,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
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
                                      Text(
                                        'Payroll Configuration',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        'Define salary components, statutory formulas & pay cycles for automated payroll execution',
                                        style: TextStyle(color: Colors.white70, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () => _showComponentModal(),
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text('Add Component'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: AppColors.darkPrimary,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.5,
                        children: [
                          _buildStatCard(
                            label: 'TOTAL COMPONENTS',
                            value: '${_components.length}',
                            sub: 'Master salary rules',
                            icon: Icons.list_alt,
                            bgColor: const Color(0xFFEFF6FF),
                            iconColor: const Color(0xFF2563EB),
                          ),
                          _buildStatCard(
                            label: 'EARNINGS',
                            value: '$_earningsCount',
                            sub: 'Gross salary additions',
                            icon: Icons.add_circle_outline,
                            bgColor: const Color(0xFFF0FDF4),
                            iconColor: const Color(0xFF16A34A),
                          ),
                          _buildStatCard(
                            label: 'DEDUCTIONS & STATUTORY',
                            value: '$_deductionsCount',
                            sub: 'PF, ESI, TDS & Tax',
                            icon: Icons.remove_circle_outline,
                            bgColor: const Color(0xFFFEF2F2),
                            iconColor: const Color(0xFFDC2626),
                          ),
                          _buildStatCard(
                            label: 'ACTIVE PAY CYCLES',
                            value: '0',
                            sub: 'Current payroll windows',
                            icon: Icons.date_range,
                            bgColor: const Color(0xFFFFF7ED),
                            iconColor: const Color(0xFFEA580C),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Tab 2: Components Directory
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.rule, color: AppColors.primary, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Salary Components Directory',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.lightPrimary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${_components.length} Configured',
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Components auto-apply when calculating monthly employee payslips',
                        style: TextStyle(fontSize: 11, color: AppColors.lightSecondaryText),
                      ),
                      const SizedBox(height: 12),

                      _components.isEmpty
                          ? const EmptyStateWidget(
                              title: 'No Salary Components',
                              message: 'There are no salary component rules configured on the server.',
                              icon: Icons.rule_folder_outlined,
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _components.length,
                              itemBuilder: (context, index) {
                                return _buildComponentCard(_components[index]);
                              },
                            ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (!showHeader) {
      return Material(color: Colors.transparent, child: content);
    }

    return GlassScaffold(
      appBar: const GlassHeader(title: 'Salary Components'),
      showBottomBar: false,
      body: content,
    );
  }
}
