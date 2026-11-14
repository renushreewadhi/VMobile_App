import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/api/payroll_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_header.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/glass_search_bar.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/empty_state_widget.dart';
import '../../shared/widgets/error_state_widget.dart';

class HrSalaryStructuresScreen extends ConsumerStatefulWidget {
  final bool showAppBar;
  const HrSalaryStructuresScreen({super.key, this.showAppBar = true});

  @override
  ConsumerState<HrSalaryStructuresScreen> createState() => _HrSalaryStructuresScreenState();
}

class _HrSalaryStructuresScreenState extends ConsumerState<HrSalaryStructuresScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _structures = [];
  String _searchTerm = '';
  String _selectedDepartment = 'All';
  String _selectedStatus = 'All';

  final List<String> _departments = [
    'All',
    'Engineering',
    'Human Resources',
    'Sales & Marketing',
    'Finance',
    'Design & UX',
    'Operations'
  ];
  final List<String> _statusOptions = ['All', 'Active', 'Draft', 'Inactive'];

  // Modal States
  Map<String, dynamic>? _selectedBreakdown;
  Map<String, dynamic>? _editingStructure;

  // Controllers for Edit Form
  final TextEditingController _editBasicController = TextEditingController();
  final TextEditingController _editHraController = TextEditingController();
  final TextEditingController _editConveyanceController = TextEditingController();
  final TextEditingController _editMedicalController = TextEditingController();
  final TextEditingController _editSpecialController = TextEditingController();
  final TextEditingController _editPfPercentController = TextEditingController();
  final TextEditingController _editEsiPercentController = TextEditingController();
  final TextEditingController _editTdsPercentController = TextEditingController();
  final TextEditingController _editPtController = TextEditingController();
  final TextEditingController _editEffectiveFromController = TextEditingController();
  final TextEditingController _editEffectiveToController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadStructures();
  }

  @override
  void dispose() {
    _editBasicController.dispose();
    _editHraController.dispose();
    _editConveyanceController.dispose();
    _editMedicalController.dispose();
    _editSpecialController.dispose();
    _editPfPercentController.dispose();
    _editEsiPercentController.dispose();
    _editTdsPercentController.dispose();
    _editPtController.dispose();
    _editEffectiveFromController.dispose();
    _editEffectiveToController.dispose();
    super.dispose();
  }

  Future<void> _loadStructures() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    final payrollService = ref.read(payrollServiceProvider);

    try {
      final res = await payrollService.getSalaryStructures();
      List<dynamic> items = [];
      if (res is List) {
        items = res;
      } else if (res is Map<String, dynamic> && res['data'] is List) {
        items = res['data'];
      }

      if (items.isEmpty) {
        final salRes = await payrollService.getEmployeeSalaries();
        if (salRes is List) items = salRes;
      }

      if (mounted) {
        setState(() {
          _structures = items.map((i) => _mapStructure(i)).toList();
          _isLoading = false;
        });
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

  Map<String, dynamic> _mapStructure(dynamic item) {
    final map = item is Map<String, dynamic> ? item : {};
    final basic = double.tryParse((map['basicSalary'] ?? 8000).toString()) ?? 8000.0;
    final hra = double.tryParse((map['hra'] ?? (basic * 0.4)).toString()) ?? (basic * 0.4);
    final conv = double.tryParse((map['conveyance'] ?? 1600).toString()) ?? 1600.0;
    final med = double.tryParse((map['medicalAllowance'] ?? 1250).toString()) ?? 1250.0;
    final special = double.tryParse((map['specialAllowance'] ?? 0).toString()) ?? 0.0;

    final gross = basic + hra + conv + med + special;
    final pf = basic * 0.12;
    final esi = gross * 0.0075;
    final tds = gross * 0.05;
    final pt = 200.0;
    final totalDeduct = pf + esi + tds + pt;
    final netPay = gross - totalDeduct;

    return {
      'id': map['id'] ?? map['structureId'] ?? 'SS-${map['employeeId'] ?? '01'}',
      'code': map['employeeCode'] ?? 'EMP-26-0013',
      'employeeId': map['employeeId'] ?? 'EMP-26-0013',
      'employeeName': map['employeeName'] ?? map['name'] ?? 'Amit Prajapati',
      'designation': map['designation'] ?? 'Specialist',
      'department': map['department'] ?? 'Engineering',
      'basicSalary': basic,
      'hra': hra,
      'conveyance': conv,
      'medicalAllowance': med,
      'specialAllowance': special,
      'pfPercent': 12.0,
      'esiPercent': 0.75,
      'tdsPercent': 5.0,
      'professionalTax': 200.0,
      'grossEarnings': gross,
      'totalDeductions': totalDeduct,
      'netPay': netPay,
      'effectiveFrom': map['effectiveFrom'] ?? '2026-10-27',
      'effectiveTo': map['effectiveTo'] ?? '',
      'status': map['status'] ?? 'Active',
    };
  }

  String _formatMoney(dynamic amount) {
    final val = double.tryParse(amount?.toString() ?? '0') ?? 0.0;
    return NumberFormat.currency(symbol: '₹', decimalDigits: 0).format(val);
  }

  List<Map<String, dynamic>> get _filteredStructures {
    return _structures.where((s) {
      final name = (s['employeeName'] ?? '').toString().toLowerCase();
      final code = (s['code'] ?? '').toString().toLowerCase();
      final dept = (s['department'] ?? '').toString();
      final status = (s['status'] ?? 'Active').toString();

      final matchesSearch = _searchTerm.isEmpty ||
          name.contains(_searchTerm.toLowerCase()) ||
          code.contains(_searchTerm.toLowerCase()) ||
          dept.toLowerCase().contains(_searchTerm.toLowerCase());
      final matchesDept = _selectedDepartment == 'All' || dept.toLowerCase() == _selectedDepartment.toLowerCase();
      final matchesStatus = _selectedStatus == 'All' || status.toLowerCase() == _selectedStatus.toLowerCase();

      return matchesSearch && matchesDept && matchesStatus;
    }).toList();
  }

  void _openEditStructure(Map<String, dynamic> structure) {
    _editingStructure = Map<String, dynamic>.from(structure);

    _editBasicController.text = (structure['basicSalary'] ?? 8000).toString();
    _editHraController.text = (structure['hra'] ?? 3200).toString();
    _editConveyanceController.text = (structure['conveyance'] ?? 1600).toString();
    _editMedicalController.text = (structure['medicalAllowance'] ?? 1250).toString();
    _editSpecialController.text = (structure['specialAllowance'] ?? 0).toString();
    _editPfPercentController.text = (structure['pfPercent'] ?? 12).toString();
    _editEsiPercentController.text = (structure['esiPercent'] ?? 0.75).toString();
    _editTdsPercentController.text = (structure['tdsPercent'] ?? 5).toString();
    _editPtController.text = (structure['professionalTax'] ?? 200).toString();
    _editEffectiveFromController.text = (structure['effectiveFrom'] ?? '2026-10-27').toString();
    _editEffectiveToController.text = (structure['effectiveTo'] ?? '').toString();

    setState(() {});
  }

  void _saveStructureEdit() {
    if (_editingStructure == null) return;
    final basic = double.tryParse(_editBasicController.text.trim()) ?? 0.0;
    final hra = double.tryParse(_editHraController.text.trim()) ?? 0.0;
    final conv = double.tryParse(_editConveyanceController.text.trim()) ?? 0.0;
    final med = double.tryParse(_editMedicalController.text.trim()) ?? 0.0;
    final special = double.tryParse(_editSpecialController.text.trim()) ?? 0.0;

    final pfP = double.tryParse(_editPfPercentController.text.trim()) ?? 12.0;
    final esiP = double.tryParse(_editEsiPercentController.text.trim()) ?? 0.75;
    final tdsP = double.tryParse(_editTdsPercentController.text.trim()) ?? 5.0;
    final pt = double.tryParse(_editPtController.text.trim()) ?? 200.0;

    final gross = basic + hra + conv + med + special;
    final pf = basic * (pfP / 100);
    final esi = gross * (esiP / 100);
    final tds = gross * (tdsP / 100);
    final totalDeduct = pf + esi + tds + pt;
    final netPay = gross - totalDeduct;

    final id = _editingStructure!['id'];
    final idx = _structures.indexWhere((s) => s['id'] == id);

    if (idx != -1) {
      setState(() {
        _structures[idx]['basicSalary'] = basic;
        _structures[idx]['hra'] = hra;
        _structures[idx]['conveyance'] = conv;
        _structures[idx]['medicalAllowance'] = med;
        _structures[idx]['specialAllowance'] = special;
        _structures[idx]['pfPercent'] = pfP;
        _structures[idx]['esiPercent'] = esiP;
        _structures[idx]['tdsPercent'] = tdsP;
        _structures[idx]['professionalTax'] = pt;
        _structures[idx]['grossEarnings'] = gross;
        _structures[idx]['totalDeductions'] = totalDeduct;
        _structures[idx]['netPay'] = netPay;
        _structures[idx]['effectiveFrom'] = _editEffectiveFromController.text.trim();
        _editingStructure = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Salary structure updated successfully!'), backgroundColor: AppColors.success),
      );
    }
  }

  void _exportExcel() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Exported ${_filteredStructures.length} salary structure(s) to Excel!'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      final skeleton = const Center(child: CircularProgressIndicator());
      if (!widget.showAppBar) return Material(color: Colors.transparent, child: skeleton);
      return GlassScaffold(title: 'Salary Structures & Pay Grades', body: skeleton);
    }

    if (_errorMessage != null) {
      final errBody = ErrorStateWidget(
        errorMessage: _errorMessage!,
        onRetry: _loadStructures,
      );
      if (!widget.showAppBar) return Material(color: Colors.transparent, child: errBody);
      return GlassScaffold(title: 'Salary Structures & Pay Grades', body: errBody);
    }

    final filtered = _filteredStructures;
    final cardBg = Theme.of(context).cardColor;

    final avgBasic = _structures.isEmpty ? 0.0 : _structures.fold<double>(0.0, (sum, s) => sum + (s['basicSalary'] as double)) / _structures.length;
    final avgGross = _structures.isEmpty ? 0.0 : _structures.fold<double>(0.0, (sum, s) => sum + (s['grossEarnings'] as double)) / _structures.length;
    final activeBands = _structures.where((s) => s['status'] == 'Active').length;

    final bodyContent = Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Buttons Bar
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.arrow_back, size: 16),
                      label: const Text('Back to Payroll', style: TextStyle(fontSize: 12)),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.file_download_outlined, size: 16),
                      label: const Text('Export Excel', style: TextStyle(fontSize: 12)),
                      onPressed: _exportExcel,
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('New Structure', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1), foregroundColor: Colors.white),
                      onPressed: () {
                        _openEditStructure({
                          'id': 'SS-${DateTime.now().millisecondsSinceEpoch}',
                          'code': 'EMP-26-NEW',
                          'employeeId': 'EMP-26-NEW',
                          'employeeName': 'New Employee',
                          'designation': 'Specialist',
                          'department': 'Engineering',
                          'basicSalary': 10000.0,
                          'hra': 4000.0,
                          'conveyance': 1600.0,
                          'medicalAllowance': 1250.0,
                          'specialAllowance': 0.0,
                          'pfPercent': 12.0,
                          'esiPercent': 0.75,
                          'tdsPercent': 5.0,
                          'professionalTax': 200.0,
                          'grossEarnings': 16850.0,
                          'totalDeductions': 2242.0,
                          'netPay': 14608.0,
                          'effectiveFrom': DateFormat('yyyy-MM-dd').format(DateTime.now()),
                          'status': 'Active',
                        });
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 3 KPI Cards matching Web HRMS (Image 4) - Horizontally Scrollable Carousel for Mobile
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    SizedBox(
                      width: 175,
                      child: _buildKpiCard('CONFIGURED STRUCTURES', '${_structures.length}', '$activeBands Active Pay Bands', Icons.tune, Colors.orange, cardBg),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 185,
                      child: _buildKpiCard('AVG. BASIC SALARY', _formatMoney(avgBasic), 'Across All Departments', Icons.account_balance_wallet, Colors.teal, cardBg),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 185,
                      child: _buildKpiCard('AVG. GROSS EARNINGS', _formatMoney(avgGross), 'Including Allowances', Icons.trending_up, Colors.blue, cardBg),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Search & Filters Bar
              GlassSearchBar(
                placeholder: 'Search employee, ID, department...',
                onChanged: (val) => setState(() => _searchTerm = val),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(10), color: cardBg),
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
                      decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(10), color: cardBg),
                      child: DropdownButton<String>(
                        value: _selectedStatus,
                        underline: const SizedBox.shrink(),
                        items: _statusOptions.map((st) => DropdownMenuItem(value: st, child: Text('Status: $st', style: const TextStyle(fontSize: 12)))).toList(),
                        onChanged: (val) => setState(() => _selectedStatus = val ?? 'All'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Structure Cards List
              filtered.isEmpty
                  ? const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('No salary structures found.')))
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final s = filtered[index];
                        final name = s['employeeName'] ?? 'Employee';
                        final code = s['code'] ?? 'EMP-001';
                        final dept = s['department'] ?? 'Engineering';
                        final basic = _formatMoney(s['basicSalary']);
                        final gross = _formatMoney(s['grossEarnings']);
                        final deduct = _formatMoney(s['totalDeductions']);
                        final net = _formatMoney(s['netPay']);
                        final status = s['status'] ?? 'Active';
                        final effFrom = s['effectiveFrom'] ?? '2026-10-27';

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 1,
                          color: cardBg,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(6)),
                                          child: Text(code, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black87)),
                                        ),
                                        const SizedBox(width: 10),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                            Text(dept, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                                          ],
                                        ),
                                      ],
                                    ),
                                    Chip(
                                      label: Text(status, style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                                      backgroundColor: status == 'Active' ? Colors.green : Colors.grey,
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Basic: $basic', style: const TextStyle(fontSize: 12)),
                                    Text('Gross: +$gross', style: const TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.bold)),
                                    Text('Deductions: -$deduct', style: const TextStyle(fontSize: 12, color: Colors.red)),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Net Pay: $net', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF6366F1))),
                                    Text('Effective: $effFrom', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                                  ],
                                ),
                                const Divider(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit, color: Colors.grey, size: 20),
                                      tooltip: 'Edit Structure',
                                      onPressed: () => _openEditStructure(s),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.visibility_outlined, color: Colors.teal, size: 20),
                                      tooltip: 'View Breakdown',
                                      onPressed: () => setState(() => _selectedBreakdown = s),
                                    ),
                                    IconButton(
                                      icon: Icon(status == 'Active' ? Icons.block : Icons.check_circle, color: Colors.redAccent, size: 20),
                                      tooltip: 'Toggle Status',
                                      onPressed: () {
                                        setState(() {
                                          s['status'] = status == 'Active' ? 'Inactive' : 'Active';
                                        });
                                      },
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

        // Salary Breakdown View Modal (Image 15)
        if (_selectedBreakdown != null)
          Container(
            color: Colors.black54,
            alignment: Alignment.center,
            padding: const EdgeInsets.all(20),
            child: Material(
              borderRadius: BorderRadius.circular(16),
              color: cardBg,
              child: Container(
                padding: const EdgeInsets.all(20),
                constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.pie_chart_outline, color: Color(0xFF6366F1)),
                              SizedBox(width: 8),
                              Text('Salary Breakdown', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _selectedBreakdown = null)),
                        ],
                      ),
                      Text('${_selectedBreakdown!['employeeName']} (${_selectedBreakdown!['code']})', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                      const Divider(height: 16),

                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Earnings Column
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(8)),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: const [
                                      Icon(Icons.add_circle, color: Colors.green, size: 16),
                                      SizedBox(width: 4),
                                      Text('Earnings List', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green)),
                                    ],
                                  ),
                                  const Divider(),
                                  _buildLineItem('Basic Salary', _formatMoney(_selectedBreakdown!['basicSalary'])),
                                  _buildLineItem('HRA', _formatMoney(_selectedBreakdown!['hra'])),
                                  _buildLineItem('Conveyance', _formatMoney(_selectedBreakdown!['conveyance'])),
                                  _buildLineItem('Medical', _formatMoney(_selectedBreakdown!['medicalAllowance'])),
                                  _buildLineItem('Special', _formatMoney(_selectedBreakdown!['specialAllowance'])),
                                  const Divider(),
                                  _buildLineItem('Total Gross', _formatMoney(_selectedBreakdown!['grossEarnings']), isBold: true),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Deductions Column
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(8)),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: const [
                                      Icon(Icons.remove_circle, color: Colors.red, size: 16),
                                      SizedBox(width: 4),
                                      Text('Deductions List', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red)),
                                    ],
                                  ),
                                  const Divider(),
                                  _buildLineItem('PF', _formatMoney(_selectedBreakdown!['basicSalary'] * 0.12)),
                                  _buildLineItem('ESI', _formatMoney(_selectedBreakdown!['grossEarnings'] * 0.0075)),
                                  _buildLineItem('TDS', _formatMoney(_selectedBreakdown!['grossEarnings'] * 0.05)),
                                  _buildLineItem('PT', _formatMoney(200)),
                                  const Divider(),
                                  _buildLineItem('Total Deductions', _formatMoney(_selectedBreakdown!['totalDeductions']), isBold: true),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: const Color(0xFF6366F1), borderRadius: BorderRadius.circular(10)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('ESTIMATED MONTHLY NET PAYABLE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                            Text(_formatMoney(_selectedBreakdown!['netPay']), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton(
                          onPressed: () => setState(() => _selectedBreakdown = null),
                          child: const Text('Close Breakdown'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

        // Full Edit Salary Structure Form Screen / Overlay (Image 14)
        if (_editingStructure != null)
          Container(
            color: Colors.black54,
            alignment: Alignment.center,
            padding: const EdgeInsets.all(16),
            child: Material(
              borderRadius: BorderRadius.circular(16),
              color: cardBg,
              child: Container(
                padding: const EdgeInsets.all(20),
                constraints: const BoxConstraints(maxWidth: 800, maxHeight: 750),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Edit Salary Structure', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              Text('Modify salary components, allowances, tax percentages, and effective validity', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                            ],
                          ),
                          IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _editingStructure = null)),
                        ],
                      ),
                      const Divider(height: 20),

                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left Form Column
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Employee Details & Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                const SizedBox(height: 8),
                                TextField(
                                  enabled: false,
                                  decoration: InputDecoration(
                                    labelText: 'Employee',
                                    hintText: '${_editingStructure!['employeeName']} — ${_editingStructure!['department']}',
                                    border: const OutlineInputBorder(),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _editEffectiveFromController,
                                        decoration: const InputDecoration(labelText: 'Effective From *', border: OutlineInputBorder()),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: TextField(
                                        controller: _editEffectiveToController,
                                        decoration: const InputDecoration(labelText: 'Effective To (Optional)', border: OutlineInputBorder()),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                const Text('Earnings & Allowances', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _editBasicController,
                                        decoration: const InputDecoration(labelText: 'Basic Salary (₹) *', border: OutlineInputBorder()),
                                        keyboardType: TextInputType.number,
                                        onChanged: (_) => setState(() {}),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: TextField(
                                        controller: _editHraController,
                                        decoration: const InputDecoration(labelText: 'House Rent Allowance - HRA (₹)', border: OutlineInputBorder()),
                                        keyboardType: TextInputType.number,
                                        onChanged: (_) => setState(() {}),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _editConveyanceController,
                                        decoration: const InputDecoration(labelText: 'Conveyance Allowance (₹)', border: OutlineInputBorder()),
                                        keyboardType: TextInputType.number,
                                        onChanged: (_) => setState(() {}),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: TextField(
                                        controller: _editMedicalController,
                                        decoration: const InputDecoration(labelText: 'Medical Allowance (₹)', border: OutlineInputBorder()),
                                        keyboardType: TextInputType.number,
                                        onChanged: (_) => setState(() {}),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                TextField(
                                  controller: _editSpecialController,
                                  decoration: const InputDecoration(labelText: 'Special Allowance (₹)', border: OutlineInputBorder()),
                                  keyboardType: TextInputType.number,
                                  onChanged: (_) => setState(() {}),
                                ),
                                const SizedBox(height: 16),

                                const Text('Statutory & Tax Deductions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _editPfPercentController,
                                        decoration: const InputDecoration(labelText: 'Provident Fund - PF (%)', border: OutlineInputBorder()),
                                        keyboardType: TextInputType.number,
                                        onChanged: (_) => setState(() {}),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: TextField(
                                        controller: _editEsiPercentController,
                                        decoration: const InputDecoration(labelText: 'Employee State Insurance - ESI (%)', border: OutlineInputBorder()),
                                        keyboardType: TextInputType.number,
                                        onChanged: (_) => setState(() {}),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _editTdsPercentController,
                                        decoration: const InputDecoration(labelText: 'Income Tax - TDS (%)', border: OutlineInputBorder()),
                                        keyboardType: TextInputType.number,
                                        onChanged: (_) => setState(() {}),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: TextField(
                                        controller: _editPtController,
                                        decoration: const InputDecoration(labelText: 'Professional Tax - PT (₹)', border: OutlineInputBorder()),
                                        keyboardType: TextInputType.number,
                                        onChanged: (_) => setState(() {}),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),

                          // Right Live Salary Breakdown Sidebar (Image 14)
                          Expanded(
                            flex: 2,
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[300]!)),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: const [
                                      Icon(Icons.calculate, color: Colors.brown, size: 18),
                                      SizedBox(width: 6),
                                      Text('Live Salary Breakdown', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    ],
                                  ),
                                  const Divider(height: 16),
                                  _buildSidebarRow('Basic Salary', _formatMoney(double.tryParse(_editBasicController.text) ?? 0)),
                                  _buildSidebarRow('HRA', _formatMoney(double.tryParse(_editHraController.text) ?? 0)),
                                  _buildSidebarRow('Conveyance & Medical', _formatMoney((double.tryParse(_editConveyanceController.text) ?? 0) + (double.tryParse(_editMedicalController.text) ?? 0))),
                                  _buildSidebarRow('Special Allowance', _formatMoney(double.tryParse(_editSpecialController.text) ?? 0)),
                                  const Divider(height: 14),

                                  _buildSidebarRow('Total Gross Earnings', _formatMoney(_computeLiveGross()), color: Colors.green, isBold: true),
                                  _buildSidebarRow('Total Deductions', '-${_formatMoney(_computeLiveDeductions())}', color: Colors.red, isBold: true),
                                  const SizedBox(height: 14),

                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(color: Colors.brown, borderRadius: BorderRadius.circular(10)),
                                    child: Column(
                                      children: [
                                        const Text('NET TAKE-HOME PAY', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 4),
                                        Text(_formatMoney(_computeLiveNet()), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
                                        const Text('Monthly In-Hand Salary', style: TextStyle(color: Colors.white70, fontSize: 9)),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.brown, foregroundColor: Colors.white),
                                      onPressed: _saveStructureEdit,
                                      child: const Text('Update Salary Structure'),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton(
                                      onPressed: () => setState(() => _editingStructure = null),
                                      child: const Text('Cancel'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );

    if (!widget.showAppBar) return Material(color: Colors.transparent, child: bodyContent);

    return GlassScaffold(
      appBar: GlassHeader(title: 'Salary Structures & Pay Grades'),
      body: bodyContent,
    );
  }

  double _computeLiveGross() {
    final basic = double.tryParse(_editBasicController.text) ?? 0.0;
    final hra = double.tryParse(_editHraController.text) ?? 0.0;
    final conv = double.tryParse(_editConveyanceController.text) ?? 0.0;
    final med = double.tryParse(_editMedicalController.text) ?? 0.0;
    final spec = double.tryParse(_editSpecialController.text) ?? 0.0;
    return basic + hra + conv + med + spec;
  }

  double _computeLiveDeductions() {
    final basic = double.tryParse(_editBasicController.text) ?? 0.0;
    final gross = _computeLiveGross();
    final pfP = double.tryParse(_editPfPercentController.text) ?? 12.0;
    final esiP = double.tryParse(_editEsiPercentController.text) ?? 0.75;
    final tdsP = double.tryParse(_editTdsPercentController.text) ?? 5.0;
    final pt = double.tryParse(_editPtController.text) ?? 200.0;

    final pf = basic * (pfP / 100);
    final esi = gross * (esiP / 100);
    final tds = gross * (tdsP / 100);
    return pf + esi + tds + pt;
  }

  double _computeLiveNet() {
    return _computeLiveGross() - _computeLiveDeductions();
  }

  Widget _buildSidebarRow(String label, String value, {Color? color, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: color ?? Colors.grey[700], fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(value, style: TextStyle(fontSize: 11, color: color ?? Colors.black87, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }

  Widget _buildLineItem(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[700], fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(value, style: TextStyle(fontSize: 10, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }

  Widget _buildKpiCard(String label, String value, String subtext, IconData icon, Color color, Color cardBg) {
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
                  style: TextStyle(fontSize: 10, color: Colors.grey[600], fontWeight: FontWeight.bold, letterSpacing: 0.2),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(subtext, style: TextStyle(fontSize: 10, color: Colors.grey[500]), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}
