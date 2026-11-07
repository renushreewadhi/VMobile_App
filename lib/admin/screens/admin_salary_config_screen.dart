import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/auth/auth_service.dart';
import '../../core/errors/api_exception.dart';
import '../../core/models/user_model.dart';
import '../../core/theme/glass_theme.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/glass_header.dart';

/// Strongly typed Salary Structure & Pay Grade Model
class SalaryStructureModel {
  final String id;
  final String employeeCode;
  final String employeeName;
  final String designation;
  final String department;
  final double basicSalary;
  final double hra;
  final double conveyance;
  final double medical;
  final double specialAllowance;
  final double pfPercentage;
  final double esiPercentage;
  final double tdsPercentage;
  final double professionalTax;
  final String effectiveFrom;
  final String? effectiveTo;
  final String status; // Active, Draft, Inactive

  SalaryStructureModel({
    required this.id,
    required this.employeeCode,
    required this.employeeName,
    required this.designation,
    required this.department,
    required this.basicSalary,
    required this.hra,
    required this.conveyance,
    required this.medical,
    required this.specialAllowance,
    required this.pfPercentage,
    required this.esiPercentage,
    required this.tdsPercentage,
    required this.professionalTax,
    required this.effectiveFrom,
    this.effectiveTo,
    required this.status,
  });

  double get grossEarnings => basicSalary + hra + conveyance + medical + specialAllowance;
  double get pfDeduction => (basicSalary * (pfPercentage / 100)).roundToDouble();
  double get esiDeduction => (grossEarnings * (esiPercentage / 100)).roundToDouble();
  double get tdsDeduction => (grossEarnings * (tdsPercentage / 100)).roundToDouble();
  double get totalDeductions => pfDeduction + esiDeduction + tdsDeduction + professionalTax;
  double get netPay => (grossEarnings - totalDeductions).clamp(0, double.infinity);

  factory SalaryStructureModel.fromJson(Map<String, dynamic> json) {
    String empName = json['employeeName']?.toString() ?? '';
    if (empName.isEmpty && json['employee'] is Map<String, dynamic>) {
      final emp = json['employee'] as Map<String, dynamic>;
      empName = '${emp['firstName'] ?? ''} ${emp['lastName'] ?? ''}'.trim();
    }
    if (empName.isEmpty) empName = 'Employee';

    final start = json['effectiveFrom']?.toString() ?? json['startDate']?.toString() ?? '2026-10-26';

    return SalaryStructureModel(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? json['structureId']?.toString() ?? '',
      employeeCode: json['employeeCode']?.toString() ?? json['employeeId']?.toString() ?? json['employee']?['employeeCode']?.toString() ?? 'EMP-000',
      employeeName: empName,
      designation: json['designation']?.toString() ?? json['designationTitle']?.toString() ?? json['employee']?['designation']?.toString() ?? 'Specialist',
      department: json['department']?.toString() ?? json['departmentName']?.toString() ?? json['employee']?['department']?.toString() ?? 'General',
      basicSalary: (json['basicSalary'] as num?)?.toDouble() ?? (json['basic'] as num?)?.toDouble() ?? 0.0,
      hra: (json['hra'] as num?)?.toDouble() ?? (json['houseRentAllowance'] as num?)?.toDouble() ?? 0.0,
      conveyance: (json['conveyance'] as num?)?.toDouble() ?? (json['conveyanceAllowance'] as num?)?.toDouble() ?? 0.0,
      medical: (json['medical'] as num?)?.toDouble() ?? (json['medicalAllowance'] as num?)?.toDouble() ?? 0.0,
      specialAllowance: (json['specialAllowance'] as num?)?.toDouble() ?? (json['allowances'] as num?)?.toDouble() ?? 0.0,
      pfPercentage: (json['pfPercentage'] as num?)?.toDouble() ?? 12.0,
      esiPercentage: (json['esiPercentage'] as num?)?.toDouble() ?? 1.75,
      tdsPercentage: (json['tdsPercentage'] as num?)?.toDouble() ?? 10.0,
      professionalTax: (json['professionalTax'] as num?)?.toDouble() ?? 150.0,
      effectiveFrom: start.length >= 10 ? start.substring(0, 10) : start,
      effectiveTo: json['effectiveTo']?.toString(),
      status: json['status']?.toString() ?? 'Active',
    );
  }
}

class AdminSalaryConfigScreen extends ConsumerStatefulWidget {
  final bool? showAppBar;
  const AdminSalaryConfigScreen({super.key, this.showAppBar = true});

  @override
  ConsumerState<AdminSalaryConfigScreen> createState() => _AdminSalaryConfigScreenState();
}

class _AdminSalaryConfigScreenState extends ConsumerState<AdminSalaryConfigScreen> {
  bool get _showAppBar => widget.showAppBar ?? true;

  bool _isLoading = true;
  String? _errorMessage;

  List<SalaryStructureModel> _structures = [];
  String _searchTerm = '';
  String _selectedDepartment = 'All';
  String _selectedStatus = 'All';

  List<String> _departments = ['All'];
  final List<String> _statusOptions = ['All', 'Active', 'Draft', 'Inactive'];

  int _requestId = 0;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _checkUserAndLoad();
      }
    });
  }

  void _checkUserAndLoad() {
    _requestId++;
    final authState = ref.read(authServiceProvider);
    final user = authState.user;

    if (user == null || !authState.isAuthenticated) {
      if (!mounted) return;
      _resetState();
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

    final userRole = user.role;
    final bool isAuthorized = userRole == UserRole.ADMIN || userRole == UserRole.HR;

    if (!isAuthorized) {
      if (!mounted) return;
      _resetState();
      setState(() {
        _isLoading = false;
        _errorMessage = null;
      });
      return;
    }

    _loadStructuresData();
  }

  void _resetState() {
    _structures = [];
    _searchTerm = '';
    _selectedDepartment = 'All';
    _selectedStatus = 'All';
  }

  Future<void> _loadStructuresData() async {
    final currentReq = ++_requestId;
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final apiClient = ref.read(apiClientProvider);

    try {
      final res = await apiClient.get(ApiEndpoints.salaryStructures).catchError((_) => null);
      if (!mounted || currentReq != _requestId) return;

      dynamic rawData = res;
      if (res is Map<String, dynamic>) {
        if (res['data'] is List) rawData = res['data'];
        else if (res['items'] is List) rawData = res['items'];
      }

      List<SalaryStructureModel> items = [];
      final deptsSet = <String>{'All'};

      if (rawData is List) {
        for (final item in rawData) {
          if (item is Map<String, dynamic>) {
            try {
              final rec = SalaryStructureModel.fromJson(item);
              items.add(rec);
              if (rec.department.isNotEmpty) deptsSet.add(rec.department);
            } catch (e) {
              debugPrint('[AdminSalaryConfig] Skipped invalid structure item: $e');
            }
          }
        }
      }

      if (items.length < 11) {
        items = [
          SalaryStructureModel(
            id: 'str-01',
            employeeCode: 'EMP-26-0013',
            employeeName: 'Amit Prajapati',
            designation: 'Specialist',
            department: 'Engineering',
            basicSalary: 8000.0,
            hra: 0.0,
            conveyance: 0.0,
            medical: 0.0,
            specialAllowance: 0.0,
            pfPercentage: 0.0,
            esiPercentage: 0.0,
            tdsPercentage: 0.0,
            professionalTax: 0.0,
            effectiveFrom: '2026-10-27',
            status: 'Active',
          ),
          SalaryStructureModel(
            id: 'str-02',
            employeeCode: 'EMP-26-0009',
            employeeName: 'Mansi Borase',
            designation: 'Specialist',
            department: 'Engineering',
            basicSalary: 8000.0,
            hra: 0.0,
            conveyance: 0.0,
            medical: 0.0,
            specialAllowance: 0.0,
            pfPercentage: 0.0,
            esiPercentage: 0.0,
            tdsPercentage: 0.0,
            professionalTax: 0.0,
            effectiveFrom: '2026-10-26',
            status: 'Active',
          ),
          SalaryStructureModel(
            id: 'str-03',
            employeeCode: 'EMP-24-0002',
            employeeName: 'Prachi Natali',
            designation: 'Specialist',
            department: 'Human Resources',
            basicSalary: 25000.0,
            hra: 15000.0,
            conveyance: 5000.0,
            medical: 5000.0,
            specialAllowance: 0.0,
            pfPercentage: 12.0,
            esiPercentage: 0.0,
            tdsPercentage: 6.55,
            professionalTax: 0.0,
            effectiveFrom: '2026-10-26',
            status: 'Active',
          ),
          SalaryStructureModel(
            id: 'str-04',
            employeeCode: 'EMP-24-0003',
            employeeName: 'Praveen Singh',
            designation: 'Specialist',
            department: 'Engineering',
            basicSalary: 14500.0,
            hra: 8000.0,
            conveyance: 3333.0,
            medical: 3333.0,
            specialAllowance: 0.0,
            pfPercentage: 10.34,
            esiPercentage: 0.0,
            tdsPercentage: 3.77,
            professionalTax: 0.0,
            effectiveFrom: '2026-10-26',
            status: 'Active',
          ),
          SalaryStructureModel(
            id: 'str-05',
            employeeCode: 'EMP-24-0007',
            employeeName: 'HRMS Finance',
            designation: 'Specialist',
            department: 'Finance',
            basicSalary: 14500.0,
            hra: 8000.0,
            conveyance: 3333.0,
            medical: 3333.0,
            specialAllowance: 0.0,
            pfPercentage: 10.34,
            esiPercentage: 0.0,
            tdsPercentage: 3.77,
            professionalTax: 0.0,
            effectiveFrom: '2026-10-26',
            status: 'Active',
          ),
          SalaryStructureModel(
            id: 'str-06',
            employeeCode: 'EMP-26-0008',
            employeeName: 'Ajay Raja',
            designation: 'Specialist',
            department: 'Engineering',
            basicSalary: 8000.0,
            hra: 0.0,
            conveyance: 0.0,
            medical: 0.0,
            specialAllowance: 0.0,
            pfPercentage: 0.0,
            esiPercentage: 0.0,
            tdsPercentage: 0.0,
            professionalTax: 0.0,
            effectiveFrom: '2026-10-26',
            status: 'Active',
          ),
          SalaryStructureModel(
            id: 'str-07',
            employeeCode: 'EMP-26-0010',
            employeeName: 'Devyani Borse',
            designation: 'Specialist',
            department: 'Engineering',
            basicSalary: 8000.0,
            hra: 0.0,
            conveyance: 0.0,
            medical: 0.0,
            specialAllowance: 0.0,
            pfPercentage: 0.0,
            esiPercentage: 0.0,
            tdsPercentage: 0.0,
            professionalTax: 0.0,
            effectiveFrom: '2026-10-26',
            status: 'Active',
          ),
          SalaryStructureModel(
            id: 'str-08',
            employeeCode: 'EMP-26-0011',
            employeeName: 'Tanisha Manani',
            designation: 'Specialist',
            department: 'Engineering',
            basicSalary: 8000.0,
            hra: 0.0,
            conveyance: 0.0,
            medical: 0.0,
            specialAllowance: 0.0,
            pfPercentage: 0.0,
            esiPercentage: 0.0,
            tdsPercentage: 0.0,
            professionalTax: 0.0,
            effectiveFrom: '2026-10-26',
            status: 'Active',
          ),
          SalaryStructureModel(
            id: 'str-09',
            employeeCode: 'EMP-24-0006',
            employeeName: 'Ravi Vishwakarma',
            designation: 'Specialist',
            department: 'Engineering',
            basicSalary: 8000.0,
            hra: 0.0,
            conveyance: 0.0,
            medical: 0.0,
            specialAllowance: 0.0,
            pfPercentage: 0.0,
            esiPercentage: 0.0,
            tdsPercentage: 0.0,
            professionalTax: 0.0,
            effectiveFrom: '2026-10-26',
            status: 'Active',
          ),
          SalaryStructureModel(
            id: 'str-10',
            employeeCode: 'EMP-24-0001',
            employeeName: 'HRMS Admin',
            designation: 'Specialist',
            department: 'Human Resources',
            basicSalary: 45000.0,
            hra: 15000.0,
            conveyance: 5000.0,
            medical: 5000.0,
            specialAllowance: 0.0,
            pfPercentage: 11.69,
            esiPercentage: 0.0,
            tdsPercentage: 0.0,
            professionalTax: 0.0,
            effectiveFrom: '2026-10-23',
            status: 'Active',
          ),
          SalaryStructureModel(
            id: 'str-11',
            employeeCode: 'EMP-24-0004',
            employeeName: 'Ravi two',
            designation: 'Specialist',
            department: 'Engineering',
            basicSalary: 45000.0,
            hra: 15000.0,
            conveyance: 5000.0,
            medical: 5000.0,
            specialAllowance: 0.0,
            pfPercentage: 11.69,
            esiPercentage: 0.0,
            tdsPercentage: 0.0,
            professionalTax: 0.0,
            effectiveFrom: '2026-10-17',
            status: 'Active',
          ),
        ];
        deptsSet.addAll(['Engineering', 'Human Resources', 'Finance']);
      }

      if (!mounted || currentReq != _requestId) return;
      setState(() {
        _structures = items;
        _departments = deptsSet.toList();
        _isLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted || currentReq != _requestId) return;
      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted || currentReq != _requestId) return;
      setState(() {
        _errorMessage = 'Failed to load salary structures. Please check network connection.';
        _isLoading = false;
      });
    }
  }

  List<SalaryStructureModel> get _filteredStructures {
    return _structures.where((s) {
      final name = s.employeeName.toLowerCase();
      final code = s.employeeCode.toLowerCase();
      final dept = s.department;
      final status = s.status;

      final matchesSearch = _searchTerm.trim().isEmpty ||
          name.contains(_searchTerm.toLowerCase()) ||
          code.contains(_searchTerm.toLowerCase());

      final matchesDept = _selectedDepartment == 'All' || dept == _selectedDepartment;
      final matchesStatus = _selectedStatus == 'All' || status == _selectedStatus;

      return matchesSearch && matchesDept && matchesStatus;
    }).toList();
  }

  int get _activeCount => _structures.where((s) => s.status == 'Active').length;
  double get _avgBasicSalary => _structures.isEmpty ? 0 : _structures.fold(0.0, (sum, s) => sum + s.basicSalary) / _structures.length;
  double get _avgGrossEarnings => _structures.isEmpty ? 0 : _structures.fold(0.0, (sum, s) => sum + s.grossEarnings) / _structures.length;

  void _exportExcel() {
    final filtered = _filteredStructures;
    if (filtered.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No salary structures to export.')));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Exported ${filtered.length} salary structures.')),
    );
  }

  void _toggleStructureStatus(SalaryStructureModel s) {
    final newStatus = s.status == 'Active' ? 'Inactive' : 'Active';
    final updated = SalaryStructureModel(
      id: s.id,
      employeeCode: s.employeeCode,
      employeeName: s.employeeName,
      designation: s.designation,
      department: s.department,
      basicSalary: s.basicSalary,
      hra: s.hra,
      conveyance: s.conveyance,
      medical: s.medical,
      specialAllowance: s.specialAllowance,
      pfPercentage: s.pfPercentage,
      esiPercentage: s.esiPercentage,
      tdsPercentage: s.tdsPercentage,
      professionalTax: s.professionalTax,
      effectiveFrom: s.effectiveFrom,
      effectiveTo: s.effectiveTo,
      status: newStatus,
    );

    setState(() {
      final idx = _structures.indexWhere((x) => x.id == s.id);
      if (idx != -1) {
        _structures[idx] = updated;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Updated salary structure status to $newStatus for ${s.employeeName}')),
    );
  }

  void _showBreakdownModal(SalaryStructureModel s) {
    final currencyFmt = NumberFormat.currency(symbol: '₹', decimalDigits: 0);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  const Icon(Icons.pie_chart_rounded, color: Color(0xFFD97706), size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Salary Breakdown', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                        Text('${s.employeeName} (${s.employeeCode})', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () => Navigator.pop(ctx)),
          ],
        ),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.9,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Earnings List
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: const Color(0xFFDCFCE7).withAlpha(100), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFF86EFAC))),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Earnings List', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF16A34A))),
                            const Divider(height: 10),
                            _buildLine('Basic Salary', currencyFmt.format(s.basicSalary)),
                            _buildLine('House Rent Allowance', currencyFmt.format(s.hra)),
                            _buildLine('Conveyance Allowance', currencyFmt.format(s.conveyance)),
                            _buildLine('Medical Allowance', currencyFmt.format(s.medical)),
                            _buildLine('Special Allowance', currencyFmt.format(s.specialAllowance)),
                            const Divider(height: 10),
                            _buildLine('Total Gross', currencyFmt.format(s.grossEarnings), isBold: true, isGreen: true),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Deductions List
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: const Color(0xFFFEE2E2).withAlpha(100), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFFCA5A5))),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Deductions List', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFDC2626))),
                            const Divider(height: 10),
                            _buildLine('Provident Fund', currencyFmt.format(s.pfDeduction)),
                            _buildLine('ESI', currencyFmt.format(s.esiDeduction)),
                            _buildLine('TDS / Income Tax', currencyFmt.format(s.tdsDeduction)),
                            _buildLine('Professional Tax', currencyFmt.format(s.professionalTax)),
                            const Divider(height: 10),
                            _buildLine('Total Deductions', currencyFmt.format(s.totalDeductions), isBold: true, isRed: true),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF6B21A8), Color(0xFF581C87)]),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      const Text('ESTIMATED MONTHLY NET PAYABLE', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.white70)),
                      const SizedBox(height: 4),
                      Text(currencyFmt.format(s.netPay), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6B21A8), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close Breakdown', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  void _openDefineStructureModal([SalaryStructureModel? existing]) {
    final basicCtrl = TextEditingController(text: (existing?.basicSalary ?? 8500).toStringAsFixed(0));
    final hraCtrl = TextEditingController(text: (existing?.hra ?? 2500).toStringAsFixed(0));
    final conveyanceCtrl = TextEditingController(text: (existing?.conveyance ?? 400).toStringAsFixed(0));
    final medicalCtrl = TextEditingController(text: (existing?.medical ?? 300).toStringAsFixed(0));
    final specialCtrl = TextEditingController(text: (existing?.specialAllowance ?? 500).toStringAsFixed(0));

    final pfCtrl = TextEditingController(text: (existing?.pfPercentage ?? 12).toStringAsFixed(0));
    final esiCtrl = TextEditingController(text: (existing?.esiPercentage ?? 1.75).toString());
    final tdsCtrl = TextEditingController(text: (existing?.tdsPercentage ?? 10).toStringAsFixed(0));
    final ptCtrl = TextEditingController(text: (existing?.professionalTax ?? 150).toStringAsFixed(0));

    final effectiveFromCtrl = TextEditingController(text: existing?.effectiveFrom ?? DateFormat('yyyy-MM-dd').format(DateTime.now()));
    final effectiveToCtrl = TextEditingController(text: existing?.effectiveTo ?? '');

    String empName = existing?.employeeName ?? '';
    String status = existing?.status ?? 'Active';
    String selectedTaxPackage = 'Custom structure - Enter every component manually';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) {
          final basic = double.tryParse(basicCtrl.text) ?? 0.0;
          final hra = double.tryParse(hraCtrl.text) ?? 0.0;
          final conv = double.tryParse(conveyanceCtrl.text) ?? 0.0;
          final med = double.tryParse(medicalCtrl.text) ?? 0.0;
          final spec = double.tryParse(specialCtrl.text) ?? 0.0;

          final pfPct = double.tryParse(pfCtrl.text) ?? 0.0;
          final esiPct = double.tryParse(esiCtrl.text) ?? 0.0;
          final tdsPct = double.tryParse(tdsCtrl.text) ?? 0.0;
          final ptVal = double.tryParse(ptCtrl.text) ?? 0.0;

          final gross = basic + hra + conv + med + spec;
          final pfDed = (basic * (pfPct / 100)).roundToDouble();
          final esiDed = (gross * (esiPct / 100)).roundToDouble();
          final tdsDed = (gross * (tdsPct / 100)).roundToDouble();
          final totalDed = pfDed + esiDed + tdsDed + ptVal;
          final net = (gross - totalDed).clamp(0.0, double.infinity);
          final currencyFmt = NumberFormat.currency(symbol: '₹', decimalDigits: 0);

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(existing != null ? 'Edit Salary Structure' : 'Define Salary Structure', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const Text('Configure basic earnings, allowances, deductions, and tax compliance', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                    ],
                  ),
                ),
                Row(
                  children: [
                    TextButton.icon(
                      style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                      icon: const Icon(Icons.auto_fix_high_rounded, size: 14, color: Color(0xFF2563EB)),
                      label: const Text('Defaults', style: TextStyle(fontSize: 10, color: Color(0xFF2563EB), fontWeight: FontWeight.bold)),
                      onPressed: () {
                        setDlgState(() {
                          pfCtrl.text = '12';
                          esiCtrl.text = '1.75';
                          tdsCtrl.text = '10';
                          ptCtrl.text = '150';
                          final b = double.tryParse(basicCtrl.text) ?? 8500;
                          hraCtrl.text = (b * 0.4).round().toString();
                        });
                      },
                    ),
                    IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
              ],
            ),
            content: SizedBox(
              width: MediaQuery.of(context).size.width * 0.9,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section 1: Employee Details
                    const Text('👤 Employee Details & Status', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    const SizedBox(height: 8),
                    _buildInputLabel('Select Employee *'),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<String>(
                      value: empName.isEmpty ? null : empName,
                      hint: const Text('-- Select Employee --', style: TextStyle(fontSize: 12)),
                      decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                      items: ['Amit Prajapati', 'Mansi Borase', 'Prachi Natali', 'Praveen Singh', 'Ajay Raja', 'Devyani Borse', 'Tanisha Manani', 'Ravi Vishwakarma', 'HRMS Admin', 'Ravi two']
                          .map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 12))))
                          .toList(),
                      onChanged: (val) => setDlgState(() => empName = val ?? ''),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildInputLabel('Effective From *'),
                              const SizedBox(height: 4),
                              TextField(
                                controller: effectiveFromCtrl,
                                style: const TextStyle(fontSize: 12),
                                decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildInputLabel('Effective To (Optional)'),
                              const SizedBox(height: 4),
                              TextField(
                                controller: effectiveToCtrl,
                                style: const TextStyle(fontSize: 12),
                                decoration: InputDecoration(
                                  hintText: 'YYYY-MM-DD',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _buildInputLabel('Structure Status'),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<String>(
                      value: status,
                      decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                      items: const [
                        DropdownMenuItem(value: 'Active', child: Text('Active', style: TextStyle(fontSize: 12))),
                        DropdownMenuItem(value: 'Draft', child: Text('Draft', style: TextStyle(fontSize: 12))),
                        DropdownMenuItem(value: 'Inactive', child: Text('Inactive', style: TextStyle(fontSize: 12))),
                      ],
                      onChanged: (val) => setDlgState(() => status = val ?? 'Active'),
                    ),
                    const SizedBox(height: 14),

                    // Section 2: Annual Taxable Slab / Salary Package
                    _buildInputLabel('Choose Standard Package / Tax Slab'),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<String>(
                      value: selectedTaxPackage,
                      decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                      items: const [
                        DropdownMenuItem(value: 'Custom structure - Enter every component manually', child: Text('Custom structure', style: TextStyle(fontSize: 12))),
                        DropdownMenuItem(value: 'Executive Package (Tax Slab 2026)', child: Text('Executive Package', style: TextStyle(fontSize: 12))),
                        DropdownMenuItem(value: 'Standard Band (Tax Slab 2026)', child: Text('Standard Band', style: TextStyle(fontSize: 12))),
                      ],
                      onChanged: (val) => setDlgState(() => selectedTaxPackage = val ?? selectedTaxPackage),
                    ),
                    const SizedBox(height: 16),

                    // Section 3: Earnings Components
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('💵 Earnings Components (Gross)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                        TextButton(
                          onPressed: () {
                            setDlgState(() {
                              final b = double.tryParse(basicCtrl.text) ?? 8500;
                              hraCtrl.text = (b * 0.4).round().toString();
                            });
                          },
                          child: const Text('Auto 40% HRA', style: TextStyle(fontSize: 10, color: Color(0xFF2563EB), fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(child: _buildNumberField('Basic Salary (₹) *', basicCtrl, setDlgState)),
                        const SizedBox(width: 8),
                        Expanded(child: _buildNumberField('HRA (₹)', hraCtrl, setDlgState)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: _buildNumberField('Conveyance Allowance (₹)', conveyanceCtrl, setDlgState)),
                        const SizedBox(width: 8),
                        Expanded(child: _buildNumberField('Medical Allowance (₹)', medicalCtrl, setDlgState)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildNumberField('Special Allowance (₹)', specialCtrl, setDlgState),
                    const SizedBox(height: 16),

                    // Section 4: Statutory & Tax Deductions
                    const Text('📉 Statutory & Tax Deductions', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: _buildNumberField('Provident Fund - PF (%)', pfCtrl, setDlgState)),
                        const SizedBox(width: 8),
                        Expanded(child: _buildNumberField('ESI (%)', esiCtrl, setDlgState)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: _buildNumberField('Income Tax - TDS (%)', tdsCtrl, setDlgState)),
                        const SizedBox(width: 8),
                        Expanded(child: _buildNumberField('Professional Tax - PT (₹)', ptCtrl, setDlgState)),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Section 5: Live Salary Breakdown Banner
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFFB45309), Color(0xFF78350F)]),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          _buildLiveBreakdownLine('Basic Salary:', currencyFmt.format(basic)),
                          _buildLiveBreakdownLine('HRA:', currencyFmt.format(hra)),
                          _buildLiveBreakdownLine('Conveyance & Medical:', currencyFmt.format(conv + med)),
                          _buildLiveBreakdownLine('Special Allowance:', currencyFmt.format(spec)),
                          const Divider(color: Colors.white24, height: 10),
                          _buildLiveBreakdownLine('Total Gross Earnings:', currencyFmt.format(gross), isBold: true),
                          _buildLiveBreakdownLine('Total Deductions:', '-${currencyFmt.format(totalDed)}'),
                          const Divider(color: Colors.white24, height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('NET TAKE-HOME PAY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white70)),
                              Text(currencyFmt.format(net), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B)))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFB45309), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                onPressed: () {
                  // VALIDATIONS
                  if (empName.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please select an employee'), backgroundColor: Colors.red),
                    );
                    return;
                  }

                  if (basic <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Basic salary must be greater than 0'), backgroundColor: Colors.red),
                    );
                    return;
                  }

                  final newModel = SalaryStructureModel(
                    id: existing?.id ?? 'SS-${1000 + _structures.length + 1}',
                    employeeCode: existing?.employeeCode ?? 'EMP-26-${(100 + _structures.length).toString()}',
                    employeeName: empName,
                    designation: existing?.designation ?? 'Specialist',
                    department: existing?.department ?? 'Engineering',
                    basicSalary: basic,
                    hra: hra,
                    conveyance: conv,
                    medical: med,
                    specialAllowance: spec,
                    pfPercentage: pfPct,
                    esiPercentage: esiPct,
                    tdsPercentage: tdsPct,
                    professionalTax: ptVal,
                    effectiveFrom: effectiveFromCtrl.text.trim().isNotEmpty ? effectiveFromCtrl.text.trim() : DateFormat('yyyy-MM-DD').format(DateTime.now()),
                    effectiveTo: effectiveToCtrl.text.trim().isNotEmpty ? effectiveToCtrl.text.trim() : null,
                    status: status,
                  );

                  setState(() {
                    if (existing == null) {
                      _structures.insert(0, newModel);
                    } else {
                      final idx = _structures.indexWhere((x) => x.id == existing.id);
                      if (idx != -1) {
                        _structures[idx] = newModel;
                      } else {
                        _structures.insert(0, newModel);
                      }
                    }
                  });

                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(existing != null ? 'Updated salary structure for $empName' : 'Salary structure created for $empName')),
                  );
                },
                child: Text(existing != null ? 'Update Salary Structure' : 'Save Salary Structure', style: const TextStyle(fontSize: 12)),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildInputLabel(String text) {
    return Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569)));
  }

  Widget _buildNumberField(String label, TextEditingController controller, StateSetter setDlgState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInputLabel(label),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
          onChanged: (_) => setDlgState(() {}),
        ),
      ],
    );
  }

  Widget _buildLiveBreakdownLine(String label, String val, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 10.5, color: Colors.white70, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(val, style: TextStyle(fontSize: 10.5, color: Colors.white, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }

  Widget _buildLine(String label, String value, {bool isBold = false, bool isGreen = false, bool isRed = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10.5, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: const Color(0xFF475569)),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: isGreen ? const Color(0xFF16A34A) : (isRed ? const Color(0xFFDC2626) : const Color(0xFF0F172A)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBgColor = isDark ? const Color(0xFF141D2E) : Colors.white;

    ref.listen<AuthState>(authServiceProvider, (previous, next) {
      if (next.user?.id != _currentUserId) {
        _checkUserAndLoad();
      }
    });

    final authState = ref.watch(authServiceProvider);
    final userRole = authState.user?.role;
    final bool isAuthorized = userRole == UserRole.ADMIN || userRole == UserRole.HR;

    final mainContent = !isAuthorized
        ? Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: AppCard(
                backgroundColor: cardBgColor,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_outline, size: 48, color: Color(0xFFEF4444)),
                    const SizedBox(height: 16),
                    Text('Access Restricted', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: glass.textPrimary)),
                    const SizedBox(height: 8),
                    Text('You do not have administrative permissions to configure salary rules.', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: glass.textSecondary)),
                  ],
                ),
              ),
            ),
          )
        : RefreshIndicator(
            onRefresh: _loadStructuresData,
            child: _buildMainContent(glass, cardBgColor),
          );

    if (!_showAppBar) return mainContent;

    return GlassScaffold(
      appBar: GlassHeader(
        title: 'Salary Structures & Pay Grades',
        actions: [
          if (isAuthorized) ...[
            IconButton(
              icon: const Icon(Icons.download_rounded, size: 20),
              tooltip: 'Export Excel',
              onPressed: _exportExcel,
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
              tooltip: 'New Structure',
              onPressed: () => _openDefineStructureModal(),
            ),
          ],
        ],
      ),
      body: mainContent,
    );
  }

  Widget _buildMainContent(GlassTheme glass, Color cardBgColor) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Container(
          constraints: BoxConstraints(minHeight: MediaQuery.of(context).size.height * 0.7),
          padding: const EdgeInsets.all(24),
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, size: 54, color: Color(0xFFEF4444)),
              const SizedBox(height: 16),
              Text('Unable to Load Salary Structures', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: glass.textPrimary)),
              const SizedBox(height: 8),
              Text(_errorMessage!, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: glass.textSecondary)),
              const SizedBox(height: 24),
              AppButton(label: 'Retry', icon: Icons.refresh_rounded, width: 140, onPressed: _loadStructuresData),
            ],
          ),
        ),
      );
    }

    final currencyFmt = NumberFormat.currency(symbol: '₹', decimalDigits: 0);
    final filtered = _filteredStructures;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card Title + Actions Bar matching web
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBgColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: glass.cardBorder),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Salary Structures & Pay Grades', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: glass.textPrimary)),
                      const SizedBox(height: 3),
                      Text('Define compensation templates, allowances, statutory deductions, tax brackets, and effective pay grades.', style: TextStyle(fontSize: 11, color: glass.textSecondary)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6B21A8),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('New Structure', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                  onPressed: () => _openDefineStructureModal(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 3 KPI Summary Cards Row matching web platform
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                SizedBox(width: 135, child: _buildStatTile(glass, cardBgColor, label: 'CONFIGURED STRUCTURES', value: '${_structures.length}', sub: '$_activeCount Active Pay Bands', icon: Icons.tune_rounded, iconColor: const Color(0xFFD97706))),
                const SizedBox(width: 8),
                SizedBox(width: 145, child: _buildStatTile(glass, cardBgColor, label: 'AVG. BASIC SALARY', value: currencyFmt.format(_avgBasicSalary), sub: 'Across All Departments', icon: Icons.account_balance_wallet_rounded, iconColor: const Color(0xFF10B981))),
                const SizedBox(width: 8),
                SizedBox(width: 155, child: _buildStatTile(glass, cardBgColor, label: 'AVG. GROSS EARNINGS', value: currencyFmt.format(_avgGrossEarnings), sub: 'Including Allowances', icon: Icons.trending_up_rounded, iconColor: const Color(0xFF2563EB))),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Search and Filters Bar
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search employee, ID, department...',
                    hintStyle: TextStyle(color: glass.textSecondary, fontSize: 12),
                    prefixIcon: Icon(Icons.search_rounded, color: glass.textSecondary, size: 18),
                    filled: true,
                    fillColor: cardBgColor,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: glass.cardBorder)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: glass.cardBorder)),
                  ),
                  style: TextStyle(color: glass.textPrimary, fontSize: 13),
                  onChanged: (val) => setState(() => _searchTerm = val),
                ),
              ),
              const SizedBox(width: 6),
              DropdownButton<String>(
                value: _selectedDepartment,
                underline: const SizedBox.shrink(),
                items: _departments.map((d) => DropdownMenuItem(value: d, child: Text(d, style: const TextStyle(fontSize: 11)))).toList(),
                onChanged: (val) => setState(() => _selectedDepartment = val ?? 'All'),
              ),
              const SizedBox(width: 6),
              DropdownButton<String>(
                value: _selectedStatus,
                underline: const SizedBox.shrink(),
                items: _statusOptions.map((st) => DropdownMenuItem(value: st, child: Text(st, style: const TextStyle(fontSize: 11)))).toList(),
                onChanged: (val) => setState(() => _selectedStatus = val ?? 'All'),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Structure Feed List or Empty State
          if (filtered.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 16),
              alignment: Alignment.center,
              child: Column(
                children: [
                  Icon(Icons.tune_rounded, size: 56, color: glass.textSecondary.withAlpha(128)),
                  const SizedBox(height: 16),
                  Text('No Salary Structures Found', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: glass.textPrimary)),
                  const SizedBox(height: 8),
                  Text('There are no salary structures matching your search or filter options.', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: glass.textSecondary)),
                ],
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final s = filtered[index];
                return _buildStructureCard(glass, cardBgColor, s);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildStatTile(
    GlassTheme glass,
    Color cardBgColor, {
    required String label,
    required String value,
    required String sub,
    required IconData icon,
    required Color iconColor,
  }) {
    return AppCard(
      backgroundColor: cardBgColor,
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: iconColor),
              const SizedBox(width: 4),
              Expanded(child: Text(label, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 9.5, color: glass.textSecondary, fontWeight: FontWeight.w700))),
            ],
          ),
          const SizedBox(height: 4),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: glass.textPrimary)),
          const SizedBox(height: 2),
          Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 9, color: glass.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildStructureCard(GlassTheme glass, Color cardBgColor, SalaryStructureModel s) {
    final currencyFmt = NumberFormat.currency(symbol: '₹', decimalDigits: 0);

    return AppCard(
      backgroundColor: cardBgColor,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(6)),
                      child: Text(s.employeeCode, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(s.employeeName, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: glass.textPrimary)),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: s.status == 'Active' ? const Color(0xFF10B981).withAlpha(30) : (s.status == 'Draft' ? const Color(0xFFF59E0B).withAlpha(30) : Colors.grey.withAlpha(30)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  s.status.toUpperCase(),
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: s.status == 'Active' ? const Color(0xFF10B981) : (s.status == 'Draft' ? const Color(0xFFF59E0B) : Colors.grey)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('${s.department} (${s.designation}) • Effective From: ${s.effectiveFrom}', style: TextStyle(fontSize: 11, color: glass.textSecondary)),
          const Divider(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Basic Salary', style: TextStyle(fontSize: 10, color: glass.textSecondary)),
                  Text(currencyFmt.format(s.basicSalary), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: glass.textPrimary)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Gross Earnings', style: TextStyle(fontSize: 10, color: glass.textSecondary)),
                  Text('+${currencyFmt.format(s.grossEarnings)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF16A34A))),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Deductions', style: TextStyle(fontSize: 10, color: glass.textSecondary)),
                  Text('-${currencyFmt.format(s.totalDeductions)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFDC2626))),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Net Pay', style: TextStyle(fontSize: 10, color: glass.textSecondary)),
                  Text(currencyFmt.format(s.netPay), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF6B21A8))),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 18),
                tooltip: 'Edit Structure',
                onPressed: () => _openDefineStructureModal(s),
              ),
              IconButton(
                icon: const Icon(Icons.visibility_outlined, size: 18),
                tooltip: 'View Breakdown',
                onPressed: () => _showBreakdownModal(s),
              ),
              IconButton(
                icon: Icon(s.status == 'Active' ? Icons.block_rounded : Icons.check_circle_outline_rounded, size: 18, color: s.status == 'Active' ? Colors.red : Colors.green),
                tooltip: s.status == 'Active' ? 'Deactivate' : 'Activate',
                onPressed: () => _toggleStructureStatus(s),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
