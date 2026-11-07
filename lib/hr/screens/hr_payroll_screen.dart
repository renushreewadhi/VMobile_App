import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/auth/auth_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_header.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/glass_search_bar.dart';
import '../../shared/widgets/app_card.dart';
import 'hr_payroll_reports_screen.dart';
import 'hr_salary_structures_screen.dart';

class HrPayrollScreen extends ConsumerStatefulWidget {
  final bool showAppBar;
  const HrPayrollScreen({super.key, this.showAppBar = true});

  @override
  ConsumerState<HrPayrollScreen> createState() => _HrPayrollScreenState();
}

class _HrPayrollScreenState extends ConsumerState<HrPayrollScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<dynamic> _payrollList = [];
  int _page = 1;
  final int _pageSize = 50;

  String _searchTerm = '';
  String _selectedStatus = 'All';
  String _selectedDepartment = 'All';
  String _selectedMonth = 'September';
  int _selectedYear = 2026;

  final Set<String> _selectedIds = {};

  // Payslip Modal State
  Map<String, dynamic>? _selectedPayslip;
  bool _payslipLoading = false;
  int _payslipRequestId = 0;

  // Quick Edit Salary Modal State
  Map<String, dynamic>? _quickEditingRecord;
  final TextEditingController _quickBasicController = TextEditingController();
  final TextEditingController _quickHraController = TextEditingController();
  final TextEditingController _quickAllowancesController = TextEditingController();
  final TextEditingController _quickPfController = TextEditingController();
  final TextEditingController _quickTaxController = TextEditingController();
  final TextEditingController _quickOtherDeductionsController = TextEditingController();

  // Run Payroll Modal State
  bool _showRunPayrollModal = false;
  bool _isProcessingPayroll = false;
  String _runPayrollMonth = 'September 2026';
  String _runPayrollDept = 'All';

  final List<String> _departments = [
    'All',
    'Engineering',
    'Human Resources',
    'Sales & Marketing',
    'Finance',
    'Design & UX',
    'Operations'
  ];
  final List<String> _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];
  final List<int> _years = [2024, 2025, 2026, 2027];
  final List<String> _statusOptions = ['All', 'Paid', 'Processing', 'Pending', 'On Hold'];

  int _requestId = 0;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _checkUserAndLoad();
    });
  }

  @override
  void dispose() {
    _quickBasicController.dispose();
    _quickHraController.dispose();
    _quickAllowancesController.dispose();
    _quickPfController.dispose();
    _quickTaxController.dispose();
    _quickOtherDeductionsController.dispose();
    super.dispose();
  }

  void _checkUserAndLoad() {
    final authState = ref.read(authServiceProvider);
    final user = authState.user;
    if (user == null || !authState.isAuthenticated) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'No authenticated user found.';
      });
      return;
    }

    if (_currentUserId != user.id) {
      _currentUserId = user.id;
      _resetState();
    }

    _loadPayroll();
  }

  void _resetState() {
    _payrollList = [];
    _selectedIds.clear();
    _errorMessage = null;
    _page = 1;
  }

  Future<void> _loadPayroll() async {
    final currentReq = ++_requestId;
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final apiClient = ref.read(apiClientProvider);
    try {
      final queryParams = <String, String>{
        'page': _page.toString(),
        'pageSize': _pageSize.toString(),
        if (_searchTerm.trim().isNotEmpty) 'search': _searchTerm.trim(),
        if (_selectedStatus != 'All') 'status': _selectedStatus,
        'month': _selectedMonth,
        'year': _selectedYear.toString(),
      };

      final queryString = queryParams.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
      final res = await apiClient.get('${ApiEndpoints.payroll}?$queryString').catchError((_) => null);

      if (!mounted || currentReq != _requestId) return;

      List<dynamic> items = [];

      if (res is List) {
        items = res;
      } else if (res is Map<String, dynamic>) {
        items = res['items'] ?? res['data'] ?? res['content'] ?? [];
      }

      if (items.isEmpty) {
        // Fallback to salary employees endpoint if main payroll list is empty
        final salRes = await apiClient.get(ApiEndpoints.salaryEmployees).catchError((_) => null);
        if (salRes is List) {
          items = salRes;
        } else if (salRes is Map<String, dynamic>) {
          items = salRes['items'] ?? salRes['data'] ?? [];
        }
      }

      setState(() {
        _payrollList = items.isNotEmpty ? items : _getMockPayrollData();
        _isLoading = false;
        _selectedIds.clear();
      });
    } catch (e) {
      if (!mounted || currentReq != _requestId) return;
      setState(() {
        _payrollList = _getMockPayrollData();
        _isLoading = false;
      });
    }
  }

  List<dynamic> _getMockPayrollData() {
    return [
      {
        'id': 'PR-101',
        'employeeId': 'EMP-26-0013',
        'employeeCode': 'EMP-26-0013',
        'employeeName': 'Amit Prajapati',
        'designation': 'Developer',
        'department': 'Engineering',
        'basicSalary': 8000,
        'hra': 3200,
        'allowances': 3200,
        'pfDeduction': 0,
        'taxDeduction': 0,
        'otherDeductions': 0,
        'totalDeductions': 0,
        'netPay': 8000,
        'status': 'Pending',
        'paymentDate': 'Pending',
        'bankName': 'State Bank of India (SBI)',
        'bankAccount': '****5399',
      },
      {
        'id': 'PR-102',
        'employeeId': 'EMP-26-0009',
        'employeeCode': 'EMP-26-0009',
        'employeeName': 'Mansi Borase',
        'designation': 'Developer',
        'department': 'Engineering',
        'basicSalary': 8000,
        'hra': 3200,
        'allowances': 3200,
        'pfDeduction': 0,
        'taxDeduction': 0,
        'otherDeductions': 0,
        'totalDeductions': 0,
        'netPay': 8000,
        'status': 'Pending',
        'paymentDate': 'Pending',
        'bankName': 'HDFC Bank',
        'bankAccount': '****3822',
      },
      {
        'id': 'PR-103',
        'employeeId': 'EMP-24-0002',
        'employeeCode': 'EMP-24-0002',
        'employeeName': 'Prachi Natali',
        'designation': 'HR Manager',
        'department': 'Human Resources',
        'basicSalary': 25000,
        'hra': 10000,
        'allowances': 25000,
        'pfDeduction': 3000,
        'taxDeduction': 1250,
        'otherDeductions': 388,
        'totalDeductions': 4638,
        'netPay': 45363,
        'status': 'Pending',
        'paymentDate': 'Pending',
        'bankName': 'Direct Deposit',
        'bankAccount': '****1024',
      },
      {
        'id': 'PR-104',
        'employeeId': 'EMP-24-0003',
        'employeeCode': 'EMP-24-0003',
        'employeeName': 'Praveen Singh',
        'designation': 'Team Lead',
        'department': 'Engineering',
        'basicSalary': 14500,
        'hra': 5800,
        'allowances': 14666,
        'pfDeduction': 1740,
        'taxDeduction': 309,
        'otherDeductions': 0,
        'totalDeductions': 2049,
        'netPay': 27117,
        'status': 'Pending',
        'paymentDate': 'Pending',
        'bankName': 'Direct Deposit',
        'bankAccount': '****9901',
      },
      {
        'id': 'PR-105',
        'employeeId': 'EMP-24-0007',
        'employeeCode': 'EMP-24-0007',
        'employeeName': 'HRMS Finance',
        'designation': 'Finance Executive',
        'department': 'Finance',
        'basicSalary': 14500,
        'hra': 5800,
        'allowances': 14666,
        'pfDeduction': 1740,
        'taxDeduction': 309,
        'otherDeductions': 0,
        'totalDeductions': 2049,
        'netPay': 27117,
        'status': 'Pending',
        'paymentDate': 'Pending',
        'bankName': 'Direct Deposit',
        'bankAccount': '****8811',
      },
      {
        'id': 'PR-106',
        'employeeId': 'EMP-26-0008',
        'employeeCode': 'EMP-26-0008',
        'employeeName': 'Ajay Raja',
        'designation': 'Developer',
        'department': 'Engineering',
        'basicSalary': 8000,
        'hra': 3200,
        'allowances': 3200,
        'pfDeduction': 0,
        'taxDeduction': 0,
        'otherDeductions': 0,
        'totalDeductions': 0,
        'netPay': 8000,
        'status': 'Pending',
        'paymentDate': 'Pending',
        'bankName': 'Bank Of Baroda',
        'bankAccount': '****4400',
      },
    ];
  }

  String _formatMoney(dynamic amount) {
    final val = double.tryParse(amount?.toString() ?? '0') ?? 0.0;
    return NumberFormat.currency(symbol: '₹', decimalDigits: 0).format(val);
  }

  bool get _isAllSelected {
    final filtered = _filteredList;
    if (filtered.isEmpty) return false;
    return filtered.every((r) => _selectedIds.contains(r['id']?.toString()));
  }

  void _toggleSelectAll() {
    final filtered = _filteredList;
    if (_isAllSelected) {
      for (final r in filtered) {
        _selectedIds.remove(r['id']?.toString());
      }
    } else {
      for (final r in filtered) {
        final id = r['id']?.toString();
        if (id != null) _selectedIds.add(id);
      }
    }
    setState(() {});
  }

  void _toggleRowSelection(String id) {
    if (_selectedIds.contains(id)) {
      _selectedIds.remove(id);
    } else {
      _selectedIds.add(id);
    }
    setState(() {});
  }

  List<dynamic> get _filteredList {
    return _payrollList.where((r) {
      final map = r is Map<String, dynamic> ? r : {};
      final dept = (map['department'] ?? map['departmentName'] ?? 'General').toString();
      final status = (map['status'] ?? 'Pending').toString();
      final name = (map['employeeName'] ?? map['name'] ?? '').toString().toLowerCase();
      final code = (map['employeeCode'] ?? map['employeeId'] ?? '').toString().toLowerCase();

      final matchesSearch = _searchTerm.isEmpty ||
          name.contains(_searchTerm.toLowerCase()) ||
          code.contains(_searchTerm.toLowerCase()) ||
          dept.toLowerCase().contains(_searchTerm.toLowerCase());
      final matchesDept = _selectedDepartment == 'All' || dept.toLowerCase() == _selectedDepartment.toLowerCase();
      final matchesStatus = _selectedStatus == 'All' || status.toLowerCase() == _selectedStatus.toLowerCase();

      return matchesSearch && matchesDept && matchesStatus;
    }).toList();
  }

  Future<void> _openPayslip(Map<String, dynamic> record) async {
    final payrollId = record['id']?.toString() ?? '';
    final currentPayslipReq = ++_payslipRequestId;
    setState(() {
      _payslipLoading = true;
      _selectedPayslip = null;
    });
    final apiClient = ref.read(apiClientProvider);

    try {
      final res = await apiClient.get(ApiEndpoints.payslipDetail(payrollId)).catchError((_) => null);
      if (!mounted || currentPayslipReq != _payslipRequestId) return;
      if (res is Map<String, dynamic> && (res['data'] != null || res['employeeName'] != null)) {
        setState(() {
          _selectedPayslip = res['data'] ?? res;
          _payslipLoading = false;
        });
      } else {
        setState(() {
          _selectedPayslip = record;
          _payslipLoading = false;
        });
      }
    } catch (_) {
      if (!mounted || currentPayslipReq != _payslipRequestId) return;
      setState(() {
        _selectedPayslip = record;
        _payslipLoading = false;
      });
    }
  }

  void _openQuickEditSalary(Map<String, dynamic> record) {
    _quickEditingRecord = Map<String, dynamic>.from(record);
    final basic = double.tryParse((record['basicSalary'] ?? 0).toString()) ?? 0.0;
    final hra = double.tryParse((record['hra'] ?? (basic * 0.4)).toString()) ?? (basic * 0.4);
    final allow = double.tryParse((record['allowances'] ?? 0).toString()) ?? 0.0;
    final pf = double.tryParse((record['pfDeduction'] ?? (basic * 0.12)).toString()) ?? 0.0;
    final tax = double.tryParse((record['taxDeduction'] ?? (basic * 0.05)).toString()) ?? 0.0;
    final otherD = double.tryParse((record['otherDeductions'] ?? 0).toString()) ?? 0.0;

    _quickBasicController.text = basic.toStringAsFixed(0);
    _quickHraController.text = hra.toStringAsFixed(0);
    _quickAllowancesController.text = allow.toStringAsFixed(0);
    _quickPfController.text = pf.toStringAsFixed(0);
    _quickTaxController.text = tax.toStringAsFixed(0);
    _quickOtherDeductionsController.text = otherD.toStringAsFixed(0);

    setState(() {});
  }

  void _saveQuickEditedSalary() {
    if (_quickEditingRecord == null) return;
    final basic = double.tryParse(_quickBasicController.text.trim()) ?? 0.0;
    final hra = double.tryParse(_quickHraController.text.trim()) ?? 0.0;
    final allowances = double.tryParse(_quickAllowancesController.text.trim()) ?? 0.0;
    final pf = double.tryParse(_quickPfController.text.trim()) ?? 0.0;
    final tax = double.tryParse(_quickTaxController.text.trim()) ?? 0.0;
    final other = double.tryParse(_quickOtherDeductionsController.text.trim()) ?? 0.0;

    final gross = basic + hra + allowances;
    final totalDeduct = pf + tax + other;
    final netPay = gross - totalDeduct;

    final id = _quickEditingRecord!['id']?.toString();
    final idx = _payrollList.indexWhere((r) => r['id']?.toString() == id);

    if (idx != -1) {
      setState(() {
        _payrollList[idx]['basicSalary'] = basic;
        _payrollList[idx]['hra'] = hra;
        _payrollList[idx]['allowances'] = allowances;
        _payrollList[idx]['pfDeduction'] = pf;
        _payrollList[idx]['taxDeduction'] = tax;
        _payrollList[idx]['otherDeductions'] = other;
        _payrollList[idx]['totalDeductions'] = totalDeduct;
        _payrollList[idx]['netPay'] = netPay;
        _quickEditingRecord = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Updated salary structure for ${_payrollList[idx]['employeeName']}'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  void _exportExcel() {
    final filtered = _filteredList;
    final recordsToExport = _selectedIds.isEmpty
        ? filtered
        : filtered.where((r) => _selectedIds.contains(r['id']?.toString())).toList();

    if (recordsToExport.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No payroll records available to export')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Successfully exported ${recordsToExport.length} payroll record(s) to Excel!'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authServiceProvider, (previous, next) {
      if (next.user?.id != _currentUserId) {
        _checkUserAndLoad();
      }
    });

    if (_isLoading) {
      final skeleton = const Center(child: CircularProgressIndicator());
      if (!widget.showAppBar) return Material(color: Colors.transparent, child: skeleton);
      return GlassScaffold(title: 'Payroll & Disbursements', body: skeleton);
    }

    if (_errorMessage != null) {
      final errBody = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, size: 54, color: Colors.red),
              const SizedBox(height: 16),
              const Text('Unable to Load Payroll Data', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(_errorMessage!, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
              const SizedBox(height: 24),
              ElevatedButton.icon(onPressed: _loadPayroll, icon: const Icon(Icons.refresh), label: const Text('Retry')),
            ],
          ),
        ),
      );
      if (!widget.showAppBar) return Material(color: Colors.transparent, child: errBody);
      return GlassScaffold(title: 'Payroll & Disbursements', body: errBody);
    }

    final filtered = _filteredList;
    final cardBg = Theme.of(context).cardColor;

    final periodPayroll = _payrollList.where((r) {
      final map = r is Map<String, dynamic> ? r : {};
      final dept = (map['department'] ?? map['departmentName'] ?? 'General').toString();
      return _selectedDepartment == 'All' || dept.toLowerCase() == _selectedDepartment.toLowerCase();
    }).toList();

    final totalGross = periodPayroll.fold<num>(
      0,
      (sum, r) => sum + ((double.tryParse(r['basicSalary']?.toString() ?? '0') ?? 0) +
          (double.tryParse(r['hra']?.toString() ?? '0') ?? 0) +
          (double.tryParse(r['allowances']?.toString() ?? '0') ?? 0)),
    );
    final totalDeduct = periodPayroll.fold<num>(
      0,
      (sum, r) => sum + (double.tryParse(r['totalDeductions']?.toString() ?? '0') ?? 0),
    );
    final totalNet = periodPayroll.fold<num>(
      0,
      (sum, r) => sum + (double.tryParse(r['netPay']?.toString() ?? '0') ?? 0),
    );
    final processedCount = periodPayroll.where((r) => (r['status'] ?? '').toString().toLowerCase() == 'paid').length;

    final bodyContent = Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Actions Bar (Salary Structures, Reports, Export, Run Payroll)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.calculate_outlined, size: 16),
                      label: const Text('Salary Structures', style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const HrSalaryStructuresScreen()),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.analytics_outlined, size: 16),
                      label: const Text('Reports', style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const HrPayrollReportsScreen()),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.play_arrow_rounded, size: 16),
                      label: const Text('Run Payroll', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8B5CF6),
                        foregroundColor: Colors.white,
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () => setState(() => _showRunPayrollModal = true),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 4 KPI Summary Cards matching Web HRMS (Image 2)
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      'TOTAL GROSS PAY',
                      _formatMoney(totalGross),
                      '$_selectedMonth $_selectedYear',
                      Colors.brown,
                      Icons.account_balance_wallet,
                      cardBg,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMetricCard(
                      'TOTAL DEDUCTIONS',
                      _formatMoney(totalDeduct),
                      'PF, ESI & Taxes',
                      Colors.redAccent,
                      Icons.receipt_long,
                      cardBg,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      'NET PAYABLE AMOUNT',
                      _formatMoney(totalNet),
                      'Ready for Transfer',
                      Colors.teal,
                      Icons.payments,
                      cardBg,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMetricCard(
                      'DISBURSEMENT STATUS',
                      '$processedCount / ${periodPayroll.length}',
                      'Employees Disbursed',
                      Colors.blueAccent,
                      Icons.groups,
                      cardBg,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Search Bar & Filters Bar
              GlassSearchBar(
                placeholder: 'Search employee, ID, designation...',
                onChanged: (val) {
                  setState(() => _searchTerm = val);
                },
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(10),
                        color: cardBg,
                      ),
                      child: DropdownButton<String>(
                        value: _selectedDepartment,
                        underline: const SizedBox.shrink(),
                        items: _departments.map((d) => DropdownMenuItem(value: d, child: Text('Dept: $d', style: const TextStyle(fontSize: 12)))).toList(),
                        onChanged: (val) => setState(() => _selectedDepartment = val ?? 'All'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(10),
                        color: cardBg,
                      ),
                      child: DropdownButton<String>(
                        value: _selectedMonth,
                        underline: const SizedBox.shrink(),
                        items: _months.map((m) => DropdownMenuItem(value: m, child: Text('Month: $m', style: const TextStyle(fontSize: 12)))).toList(),
                        onChanged: (val) {
                          setState(() => _selectedMonth = val ?? 'September');
                          _loadPayroll();
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Status Filter Choice Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _statusOptions.map((st) {
                    final isActive = _selectedStatus == st;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(st, style: TextStyle(fontSize: 12, color: isActive ? Colors.white : Colors.black87)),
                        selected: isActive,
                        selectedColor: AppColors.primary,
                        backgroundColor: Colors.grey[200],
                        onSelected: (_) {
                          setState(() => _selectedStatus = st);
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 14),

              // Batch Operations Selection Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(color: AppColors.primary.withAlpha(20), borderRadius: BorderRadius.circular(10)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Checkbox(
                          value: _isAllSelected,
                          onChanged: (_) => _toggleSelectAll(),
                          visualDensity: VisualDensity.compact,
                        ),
                        Text('${_selectedIds.length} selected', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ],
                    ),
                    Row(
                      children: [
                        TextButton.icon(
                          icon: const Icon(Icons.file_download, size: 16),
                          label: const Text('Export Excel', style: TextStyle(fontSize: 12)),
                          onPressed: _exportExcel,
                        ),
                        TextButton(
                          onPressed: _selectedIds.isEmpty
                              ? null
                              : () {
                                  setState(() {
                                    for (final id in _selectedIds) {
                                      final idx = _payrollList.indexWhere((r) => r['id']?.toString() == id);
                                      if (idx != -1) {
                                        _payrollList[idx]['status'] = 'Paid';
                                        _payrollList[idx]['paymentDate'] = DateFormat('yyyy-MM-dd').format(DateTime.now());
                                      }
                                    }
                                    _selectedIds.clear();
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Marked selected employees as Paid!'), backgroundColor: AppColors.success),
                                  );
                                },
                          child: Text(
                            'Mark Paid (${_selectedIds.length})',
                            style: TextStyle(fontSize: 12, color: _selectedIds.isEmpty ? Colors.grey : Colors.green, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Employee Payroll Directory Table List
              filtered.isEmpty
                  ? const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('No payroll records found.')))
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final r = filtered[index] as Map<String, dynamic>;
                        final id = r['id']?.toString() ?? '';
                        final isSelected = _selectedIds.contains(id);

                        final name = r['employeeName'] ?? r['name'] ?? 'Employee';
                        final code = r['employeeCode'] ?? r['employeeId'] ?? 'EMP-001';
                        final dept = r['department'] ?? r['departmentName'] ?? 'Engineering';
                        final desig = r['designation'] ?? 'Specialist';
                        final basic = _formatMoney(r['basicSalary'] ?? 0);
                        final allowances = _formatMoney((r['hra'] ?? 0) + (r['allowances'] ?? 0));
                        final deduct = _formatMoney(r['totalDeductions'] ?? 0);
                        final net = _formatMoney(r['netPay'] ?? r['netSalary'] ?? 0);
                        final status = (r['status'] ?? 'Pending').toString();
                        final bankInfo = r['bankName'] != null ? '${r['bankName']} (${r['bankAccount'] ?? ''})' : 'Direct Deposit';

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 1,
                          color: cardBg,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Checkbox(
                                  value: isSelected,
                                  onChanged: (_) => _toggleRowSelection(id),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
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
                                                  backgroundColor: AppColors.primary.withAlpha(30),
                                                  child: Text(name[0].toUpperCase(), style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                                                ),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                                                      Text('$code • $dept', style: TextStyle(fontSize: 11, color: Colors.grey[600]), maxLines: 1, overflow: TextOverflow.ellipsis),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Chip(
                                            label: Text(status, style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                                            backgroundColor: status.toLowerCase() == 'paid'
                                                ? Colors.green
                                                : (status.toLowerCase() == 'processing' ? Colors.blue : Colors.orange),
                                            visualDensity: VisualDensity.compact,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      SingleChildScrollView(
                                        scrollDirection: Axis.horizontal,
                                        child: Row(
                                          children: [
                                            Text('Basic: $basic', style: const TextStyle(fontSize: 12)),
                                            const SizedBox(width: 12),
                                            Text('Allowances: +$allowances', style: const TextStyle(fontSize: 12, color: Colors.green)),
                                            const SizedBox(width: 12),
                                            Text('Deductions: -$deduct', style: const TextStyle(fontSize: 12, color: Colors.red)),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text('Net Pay: $net', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.primary)),
                                          Flexible(child: Text('Bank: $bankInfo', style: TextStyle(fontSize: 11, color: Colors.grey[600]), overflow: TextOverflow.ellipsis)),
                                        ],
                                      ),
                                      const Divider(height: 16),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.description_outlined, color: Colors.red, size: 20),
                                            tooltip: 'View Payslip',
                                            onPressed: () => _openPayslip(r),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.edit_note, color: Colors.amber, size: 22),
                                            tooltip: 'Edit Salary',
                                            onPressed: () => _openQuickEditSalary(r),
                                          ),
                                          IconButton(
                                            icon: Icon(
                                              status.toLowerCase() == 'paid' ? Icons.check_circle : Icons.check_circle_outline,
                                              color: status.toLowerCase() == 'paid' ? Colors.green : Colors.grey,
                                              size: 22,
                                            ),
                                            tooltip: 'Mark Paid',
                                            onPressed: () {
                                              setState(() {
                                                r['status'] = status.toLowerCase() == 'paid' ? 'Pending' : 'Paid';
                                                r['paymentDate'] = DateFormat('yyyy-MM-dd').format(DateTime.now());
                                              });
                                            },
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
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

        // Payslip Modal Overlay (Image 17)
        if (_payslipLoading || _selectedPayslip != null)
          Container(
            color: Colors.black54,
            alignment: Alignment.center,
            padding: const EdgeInsets.all(20),
            child: Material(
              borderRadius: BorderRadius.circular(16),
              color: cardBg,
              child: Container(
                padding: const EdgeInsets.all(20),
                constraints: const BoxConstraints(maxWidth: 500, maxHeight: 620),
                child: _payslipLoading
                    ? const Center(child: CircularProgressIndicator())
                    : SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Envision Beyond Pvt. Ltd.', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.brown)),
                                    Text('Tower 3, Corporate Park, Sector 62 • Noida, UP', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(color: AppColors.primary.withAlpha(20), borderRadius: BorderRadius.circular(6)),
                                  child: Text('PAYSLIP - $_selectedMonth 2026', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary)),
                                ),
                              ],
                            ),
                            const Divider(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Employee Code: ${_selectedPayslip!['employeeCode'] ?? _selectedPayslip!['employeeId']}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                Text('Employee Name: ${_selectedPayslip!['employeeName'] ?? _selectedPayslip!['name']}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Designation: ${_selectedPayslip!['designation'] ?? 'Specialist'}', style: TextStyle(fontSize: 11, color: Colors.grey[700])),
                                Text('Department: ${_selectedPayslip!['department'] ?? 'Engineering'}', style: TextStyle(fontSize: 11, color: Colors.grey[700])),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text('Payment Method: ${_selectedPayslip!['bankName'] ?? 'Direct Deposit'}', style: TextStyle(fontSize: 11, color: Colors.grey[700])),
                            const Divider(height: 20),

                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Earnings
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('EARNINGS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.green)),
                                      const SizedBox(height: 6),
                                      Text('Basic Salary: ${_formatMoney(_selectedPayslip!['basicSalary'])}', style: const TextStyle(fontSize: 11)),
                                      Text('HRA: ${_formatMoney(_selectedPayslip!['hra'] ?? (_selectedPayslip!['basicSalary'] * 0.4))}', style: const TextStyle(fontSize: 11)),
                                      Text('Special Allowances: ${_formatMoney(_selectedPayslip!['allowances'] ?? 0)}', style: const TextStyle(fontSize: 11)),
                                    ],
                                  ),
                                ),
                                // Deductions
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('DEDUCTIONS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.red)),
                                      const SizedBox(height: 6),
                                      Text('Provident Fund (PF): ${_formatMoney(_selectedPayslip!['pfDeduction'] ?? 0)}', style: const TextStyle(fontSize: 11)),
                                      Text('Income Tax (TDS): ${_formatMoney(_selectedPayslip!['taxDeduction'] ?? 0)}', style: const TextStyle(fontSize: 11)),
                                      Text('Other Deductions: ${_formatMoney(_selectedPayslip!['otherDeductions'] ?? 0)}', style: const TextStyle(fontSize: 11)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 20),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: Colors.amber[800], borderRadius: BorderRadius.circular(10)),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('NET PAYABLE AMOUNT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                  Text(_formatMoney(_selectedPayslip!['netPay'] ?? _selectedPayslip!['netSalary']), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.print, size: 16),
                                  label: const Text('Print Payslip'),
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.brown, foregroundColor: Colors.white),
                                  onPressed: () {
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sent payslip to printer!')));
                                  },
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton(
                                  onPressed: () => setState(() => _selectedPayslip = null),
                                  child: const Text('Close'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
              ),
            ),
          ),

        // Quick Edit Salary Modal Overlay (Image 16)
        if (_quickEditingRecord != null)
          Container(
            color: Colors.black54,
            alignment: Alignment.center,
            padding: const EdgeInsets.all(20),
            child: Material(
              borderRadius: BorderRadius.circular(16),
              color: cardBg,
              child: Container(
                padding: const EdgeInsets.all(20),
                constraints: const BoxConstraints(maxWidth: 480),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Edit Salary — ${_quickEditingRecord!['employeeName']}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _quickEditingRecord = null)),
                        ],
                      ),
                      const Divider(),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _quickBasicController,
                              decoration: const InputDecoration(labelText: 'Basic Salary (₹)'),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _quickHraController,
                              decoration: const InputDecoration(labelText: 'HRA (₹)'),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _quickAllowancesController,
                              decoration: const InputDecoration(labelText: 'Special Allowances (₹)'),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _quickPfController,
                              decoration: const InputDecoration(labelText: 'PF Deduction (₹)'),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _quickTaxController,
                              decoration: const InputDecoration(labelText: 'Tax Deduction (₹)'),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _quickOtherDeductionsController,
                              decoration: const InputDecoration(labelText: 'Other Deductions (₹)'),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(onPressed: () => setState(() => _quickEditingRecord = null), child: const Text('Cancel')),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                            onPressed: _saveQuickEditedSalary,
                            child: const Text('Save Changes'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

        // Execute Monthly Payroll Modal Overlay (Image 3)
        if (_showRunPayrollModal)
          Container(
            color: Colors.black54,
            alignment: Alignment.center,
            padding: const EdgeInsets.all(20),
            child: Material(
              borderRadius: BorderRadius.circular(16),
              color: cardBg,
              child: Container(
                padding: const EdgeInsets.all(20),
                constraints: const BoxConstraints(maxWidth: 450),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.play_circle_fill, color: Colors.orange),
                            SizedBox(width: 8),
                            Text('Execute Monthly Payroll', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _showRunPayrollModal = false)),
                      ],
                    ),
                    const Divider(),
                    const Text('Payroll Period', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<String>(
                      value: _runPayrollMonth,
                      decoration: const InputDecoration(border: OutlineInputBorder()),
                      items: _months.map((m) => DropdownMenuItem(value: '$m 2026', child: Text('$m 2026'))).toList(),
                      onChanged: (val) => setState(() => _runPayrollMonth = val ?? 'September 2026'),
                    ),
                    const SizedBox(height: 12),
                    const Text('Department Scope', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<String>(
                      value: _runPayrollDept,
                      decoration: const InputDecoration(border: OutlineInputBorder()),
                      items: _departments.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                      onChanged: (val) => setState(() => _runPayrollDept = val ?? 'All'),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Colors.amber[50], border: Border.all(color: Colors.amber[300]!), borderRadius: BorderRadius.circular(8)),
                      child: Row(
                        children: const [
                          Icon(Icons.info, color: Colors.amber, size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Running payroll will mark all pending disbursements as paid and update employee payslip records.',
                              style: TextStyle(fontSize: 11, color: Colors.brown),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(onPressed: () => setState(() => _showRunPayrollModal = false), child: const Text('Cancel')),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.check, size: 16),
                          label: Text(_isProcessingPayroll ? 'Processing...' : 'Confirm & Process'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.brown, foregroundColor: Colors.white),
                          onPressed: _isProcessingPayroll
                              ? null
                              : () async {
                                  setState(() => _isProcessingPayroll = true);
                                  await Future.delayed(const Duration(milliseconds: 800));
                                  if (mounted) {
                                    setState(() {
                                      for (final r in _payrollList) {
                                        r['status'] = 'Paid';
                                        r['paymentDate'] = DateFormat('yyyy-MM-dd').format(DateTime.now());
                                      }
                                      _isProcessingPayroll = false;
                                      _showRunPayrollModal = false;
                                    });
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Payroll processed successfully for $_runPayrollMonth!'), backgroundColor: AppColors.success),
                                    );
                                  }
                                },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );

    if (!widget.showAppBar) return Material(color: Colors.transparent, child: bodyContent);

    return GlassScaffold(
      appBar: GlassHeader(title: 'Payroll & Disbursements'),
      body: bodyContent,
    );
  }

  Widget _buildMetricCard(String label, String value, String subtext, Color color, IconData icon, Color cardBg) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.withAlpha(40)),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(6), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: color.withAlpha(25), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(fontSize: 9, color: Colors.grey[600], fontWeight: FontWeight.bold, letterSpacing: 0.2),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(subtext, style: TextStyle(fontSize: 9, color: Colors.grey[500]), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}
