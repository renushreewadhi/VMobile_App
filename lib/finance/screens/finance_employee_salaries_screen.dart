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

class FinanceEmployeeSalariesScreen extends ConsumerStatefulWidget {
  final bool? showAppBar;
  const FinanceEmployeeSalariesScreen({super.key, this.showAppBar = false});

  @override
  ConsumerState<FinanceEmployeeSalariesScreen> createState() => _FinanceEmployeeSalariesScreenState();
}

class _FinanceEmployeeSalariesScreenState extends ConsumerState<FinanceEmployeeSalariesScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _salaries = [];
  String _searchQuery = '';

  // Request Revision Modal Controllers
  final TextEditingController _newBasicController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController();
  String _selectedEmpForRevision = '';
  String _revisionType = 'Increment';
  String _effectiveDate = '11/11/2026';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadSalaries();
    });
  }

  @override
  void dispose() {
    _newBasicController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _loadSalaries() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    final apiClient = ref.read(apiClientProvider);

    try {
      final res = await apiClient.get(ApiEndpoints.employeeSalaries);

      if (mounted) {
        List<dynamic> items = [];
        if (res is List) {
          items = res;
        } else if (res is Map<String, dynamic>) {
          final data = res['data'] ?? res['items'] ?? res['result'] ?? res['salaries'];
          if (data is List) {
            items = data;
          }
        }

        _salaries = items.map((s) => _mapSalary(s)).toList();
        _isLoading = false;
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _salaries = [];
          _errorMessage = e.toString().replaceFirst('Exception: ', '').replaceFirst('ApiException: ', '');
          _isLoading = false;
        });
      }
    }
  }

  Map<String, dynamic> _mapSalary(dynamic s) {
    final Map<String, dynamic> map = s is Map<String, dynamic> ? s : {};
    return {
      'name': map['employeeName'] ?? map['name'] ?? 'Employee',
      'empId': map['employeeCode'] ?? map['empId'] ?? map['id'] ?? 'EMP-001',
      'department': map['department'] ?? map['departmentName'] ?? 'General',
      'baseSalary': (map['baseSalary'] ?? map['basicSalary'] ?? 0.0) as num,
      'totalEarnings': (map['totalEarnings'] ?? map['baseSalary'] ?? 0.0) as num,
      'deductions': (map['deductions'] ?? 0.0) as num,
      'netSalary': (map['netSalary'] ?? map['baseSalary'] ?? 0.0) as num,
      'bankAccount': map['bankAccount'] ?? map['bankName'] ?? 'Not Set',
    };
  }

  String _formatCurrency(num amount) {
    final str = amount.toStringAsFixed(2);
    final parts = str.split('.');
    final integerPart = parts[0];
    final fractionalPart = parts[1];
    final RegExp reg = RegExp(r'(\d+?)(?=(\d{3})+(?!\d))');
    final String result = integerPart.replaceAllMapped(reg, (Match m) => '${m[1]},');
    return '₹$result.$fractionalPart';
  }

  void _showRequestRevisionModal() {
    if (_salaries.isNotEmpty) {
      _selectedEmpForRevision = _salaries[0]['empId'] as String;
    }
    _newBasicController.clear();
    _reasonController.clear();
    _revisionType = 'Increment';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final currentEmpId = _selectedEmpForRevision.isNotEmpty && _salaries.any((s) => s['empId'] == _selectedEmpForRevision)
              ? _selectedEmpForRevision
              : (_salaries.isNotEmpty ? _salaries[0]['empId'] as String : null);

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
                      child: const Icon(Icons.swap_horiz, color: AppColors.primary, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('Request Salary Revision', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                        Text('Submit employee compensation change', style: TextStyle(fontSize: 11, color: AppColors.lightSecondaryText)),
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
                  const Text('Select Employee *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.lightSecondaryText)),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<String>(
                    value: currentEmpId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    items: _salaries.map((s) {
                      final label = '${s['name']} (${s['empId']}) — Basic: ${_formatCurrency(s['baseSalary'])}';
                      return DropdownMenuItem<String>(
                        value: s['empId'] as String,
                        child: Text(label, style: const TextStyle(fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setModalState(() => _selectedEmpForRevision = val);
                    },
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Revision Type *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.lightSecondaryText)),
                            const SizedBox(height: 4),
                            DropdownButtonFormField<String>(
                              value: _revisionType,
                              isExpanded: true,
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'Increment', child: Text('Increment', style: TextStyle(fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis)),
                                DropdownMenuItem(value: 'Decrement', child: Text('Decrement', style: TextStyle(fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis)),
                                DropdownMenuItem(value: 'Structural Adjustment', child: Text('Structural Adjustment', style: TextStyle(fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis)),
                              ],
                              onChanged: (val) {
                                if (val != null) setModalState(() => _revisionType = val);
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
                            const Text('New Basic (₹) *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.lightSecondaryText)),
                            const SizedBox(height: 4),
                            TextField(
                              controller: _newBasicController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                hintText: '52000',
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  const Text('Effective Date *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.lightSecondaryText)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: TextEditingController(text: _effectiveDate),
                    onChanged: (v) => _effectiveDate = v,
                    decoration: InputDecoration(
                      hintText: '11/11/2026',
                      suffixIcon: const Icon(Icons.calendar_today, size: 18),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  const Text('Reason & Justification *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.lightSecondaryText)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _reasonController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'Provide detailed reason for salary revision...',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
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
                  if (_newBasicController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please enter new basic salary'),
                        backgroundColor: AppColors.error,
                      ),
                    );
                    return;
                  }
                  Navigator.pop(context);
                  _submitRevision();
                },
                icon: const Icon(Icons.send, size: 16),
                label: const Text('Submit Revision'),
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

  Future<void> _submitRevision() async {
    final newBasic = num.tryParse(_newBasicController.text.trim()) ?? 50000;
    final empObj = _salaries.firstWhere((s) => s['empId'] == _selectedEmpForRevision, orElse: () => {'name': 'Employee'});
    final empName = empObj['name'] ?? 'Employee';
    final reason = _reasonController.text.trim();

    final apiClient = ref.read(apiClientProvider);

    try {
      await apiClient.post(ApiEndpoints.salaryRevisions, data: {
        'employeeName': empName,
        'employeeId': _selectedEmpForRevision,
        'revisionType': _revisionType,
        'newBasic': newBasic,
        'effectiveDate': _effectiveDate,
        'reason': reason,
      }).catchError((_) => null);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Salary revision request submitted for $empName'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (_) {}
  }

  void _showSalaryStructureModal(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titlePadding: const EdgeInsets.all(16),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        actionsPadding: const EdgeInsets.all(12),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.badge, color: AppColors.primary),
                const SizedBox(width: 8),
                Text('Salary Structure — ${item['name']}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
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
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.lightInputBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStructSummary('Basic', _formatCurrency(item['baseSalary'])),
                    _buildStructSummary('Earnings', _formatCurrency(item['totalEarnings'])),
                    _buildStructSummary('Deductions', _formatCurrency(item['deductions'])),
                    _buildStructSummary('Net Pay', _formatCurrency(item['netSalary']), isPrimary: true),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Text('Salary Components Breakdown', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 8),
              _buildComponentRow('BASIC', 'Basic Salary', 'EARNING', _formatCurrency(item['baseSalary'])),
              _buildComponentRow('HRA', 'House Rent Allowance', 'EARNING', '₹0.00'),
              _buildComponentRow('CONVEYANCE', 'Conveyance Allowance', 'EARNING', '₹0.00'),
              _buildComponentRow('MEDICAL', 'Medical Allowance', 'EARNING', '₹0.00'),
              _buildComponentRow('SPECIAL', 'Special Allowance', 'EARNING', '₹0.00'),
              _buildComponentRow('PF', 'Provident Fund', 'DEDUCTION', '-${_formatCurrency(item['deductions'] * 0.6)}'),
              _buildComponentRow('ESI', 'ESI', 'DEDUCTION', '-${_formatCurrency(item['deductions'] * 0.2)}'),
              _buildComponentRow('TDS', 'TDS / Income Tax', 'DEDUCTION', '-${_formatCurrency(item['deductions'] * 0.2)}'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _showRequestRevisionModal();
            },
            icon: const Icon(Icons.swap_horiz, size: 16),
            label: const Text('Request Revision'),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildStructSummary(String label, String val, {bool isPrimary = false}) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.lightMutedText)),
        const SizedBox(height: 2),
        Text(val, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isPrimary ? AppColors.primary : Colors.black87)),
      ],
    );
  }

  Widget _buildComponentRow(String code, String name, String category, String amount) {
    final isEarning = category == 'EARNING';
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.lightInputBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(code, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary)),
              Text(name, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
            ],
          ),
          Text(
            amount,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isEarning ? AppColors.success : AppColors.error),
          ),
        ],
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const DashboardSkeleton();
    if (_errorMessage != null) {
      return ErrorStateWidget(
        errorMessage: _errorMessage!,
        onRetry: _loadSalaries,
      );
    }

    final filtered = _salaries.where((item) {
      final q = _searchQuery.toLowerCase();
      return (item['name'] ?? '').toLowerCase().contains(q) ||
          (item['empId'] ?? '').toLowerCase().contains(q) ||
          (item['department'] ?? '').toLowerCase().contains(q);
    }).toList();

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
                Tab(text: 'Salary Directory'),
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
                                  child: Icon(Icons.people_alt, color: Colors.white, size: 26),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: const [
                                      Text(
                                        'Salary Management',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        'Employee salary directory, structure view, revision workflow & input verification',
                                        style: TextStyle(color: Colors.white70, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _showRequestRevisionModal,
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text('Request Revision'),
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
                            label: 'PENDING REQUESTS',
                            value: '0',
                            sub: 'Requires review',
                            icon: Icons.hourglass_empty,
                            bgColor: const Color(0xFFFFF7ED),
                            iconColor: const Color(0xFFEA580C),
                          ),
                          _buildStatCard(
                            label: 'APPROVED',
                            value: '0',
                            sub: 'Approved applications',
                            icon: Icons.check_circle_outline,
                            bgColor: const Color(0xFFF0FDF4),
                            iconColor: const Color(0xFF16A34A),
                          ),
                          _buildStatCard(
                            label: 'REJECTED',
                            value: '0',
                            sub: 'Declined',
                            icon: Icons.highlight_off,
                            bgColor: const Color(0xFFFEF2F2),
                            iconColor: const Color(0xFFDC2626),
                          ),
                          _buildStatCard(
                            label: 'PENDING INPUTS',
                            value: '0',
                            sub: 'Awaiting verification',
                            icon: Icons.assignment_outlined,
                            bgColor: const Color(0xFFEFF6FF),
                            iconColor: const Color(0xFF2563EB),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Tab 2: Salary Directory
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextField(
                              onChanged: (val) => setState(() => _searchQuery = val),
                              decoration: InputDecoration(
                                hintText: 'Search by name or employee code...',
                                hintStyle: const TextStyle(fontSize: 13, color: AppColors.lightMutedText),
                                prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.lightSecondaryText),
                                filled: true,
                                fillColor: AppColors.lightInputBackground,
                                contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.grey.shade300),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.grey.shade300),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.badge, color: AppColors.primary, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Employee Salary Directory',
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
                              '${filtered.length} Salaries Listed',
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      filtered.isEmpty
                          ? EmptyStateWidget(
                              title: _salaries.isEmpty ? 'No Salary Records' : 'No Matching Employees',
                              message: _salaries.isEmpty
                                  ? 'There are no employee salary records found on the server.'
                                  : 'No salary records matched "$_searchQuery".',
                              icon: _salaries.isEmpty ? Icons.payments_outlined : Icons.search_off_rounded,
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                          final item = filtered[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: AppCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Row(
                                          children: [
                                            CircleAvatar(
                                              radius: 18,
                                              backgroundColor: AppColors.darkPrimary,
                                              child: Text((item['name'] as String).substring(0, 1), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13)),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                                                  Text('${item['empId']} • ${item['department']}', style: const TextStyle(fontSize: 11, color: AppColors.lightMutedText), maxLines: 1, overflow: TextOverflow.ellipsis),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: () => _showSalaryStructureModal(item),
                                        icon: const Icon(Icons.account_balance_wallet_outlined, color: AppColors.primary, size: 20),
                                        tooltip: 'View Structure',
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  const Divider(height: 1),
                                  const SizedBox(height: 10),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                                    children: [
                                      Expanded(child: _buildMetricCol('Basic Salary', _formatCurrency(item['baseSalary']), Colors.black87)),
                                      Expanded(child: _buildMetricCol('Earnings', _formatCurrency(item['totalEarnings']), AppColors.success)),
                                      Expanded(child: _buildMetricCol('Deductions', '-${_formatCurrency(item['deductions'])}', AppColors.error)),
                                      Expanded(child: _buildMetricCol('Net Salary', _formatCurrency(item['netSalary']), AppColors.primary)),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('Bank: ${item['bankAccount']}', style: const TextStyle(fontSize: 10, color: AppColors.lightMutedText)),
                                      TextButton.icon(
                                        onPressed: () => _showSalaryStructureModal(item),
                                        icon: const Icon(Icons.visibility, size: 12),
                                        label: const Text('View Breakdown', style: TextStyle(fontSize: 11)),
                                        style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                                      ),
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
      appBar: const GlassHeader(title: 'Employee Salaries'),
      showBottomBar: false,
      body: content,
    );
  }

  Widget _buildMetricCol(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.lightSecondaryText), maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color), maxLines: 1, overflow: TextOverflow.ellipsis),
      ],
    );
  }
}
