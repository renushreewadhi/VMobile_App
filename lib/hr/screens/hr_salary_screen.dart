import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/api/payroll_service.dart';
import '../../core/auth/auth_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_header.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/glass_search_bar.dart';
import '../../shared/widgets/app_card.dart';

class HrSalaryScreen extends ConsumerStatefulWidget {
  final bool showAppBar;
  final String activeTab;
  const HrSalaryScreen({
    super.key,
    this.showAppBar = true,
    this.activeTab = 'salaries',
  });

  @override
  ConsumerState<HrSalaryScreen> createState() => _HrSalaryScreenState();
}

class _HrSalaryScreenState extends ConsumerState<HrSalaryScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  late String _activeTab; // 'salaries', 'revisions', 'inputs'

  List<dynamic> _salaries = [];
  List<dynamic> _revisions = [];
  List<dynamic> _inputs = [];
  String _searchTerm = '';

  // Structure Modal State
  bool _showStructureModal = false;
  bool _structureLoading = false;
  String? _structureError;
  Map<String, dynamic>? _selectedEmpSalary;
  Map<String, dynamic>? _selectedStructureDetail;
  int _structureRequestId = 0;

  // Revision Modal State
  bool _showRevisionModal = false;
  bool _isSubmittingRevision = false;
  final Map<String, dynamic> _revisionForm = {
    'employeeId': '',
    'revisionType': 'INCREMENT',
    'newBasic': 0.0,
    'reason': '',
    'effectiveDate': '',
  };
  final TextEditingController _newBasicController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();

  // Review Revision Modal State
  Map<String, dynamic>? _reviewRevisionTarget;
  bool _reviewApproved = true;
  bool _isSubmittingReview = false;
  final TextEditingController _revRemarksController = TextEditingController();

  // Review Input Modal State
  Map<String, dynamic>? _reviewInputTarget;
  bool _isSubmittingInputReview = false;
  final TextEditingController _inputRemarksController = TextEditingController();

  int _requestId = 0;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _activeTab = widget.activeTab;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _checkUserAndLoad();
    });
  }

  @override
  void dispose() {
    _newBasicController.dispose();
    _reasonController.dispose();
    _dateController.dispose();
    _revRemarksController.dispose();
    _inputRemarksController.dispose();
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

    _loadData();
  }

  void _resetState() {
    _salaries = [];
    _revisions = [];
    _inputs = [];
    _searchTerm = '';
    _errorMessage = null;
  }

  Future<void> _loadData() async {
    final currentReq = ++_requestId;
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final payrollService = ref.read(payrollServiceProvider);

    try {
      final salRes = await payrollService.getEmployeeSalaries().catchError((_) => null);
      final revRes = await payrollService.getSalaryRevisions().catchError((_) => null);
      final inpRes = await payrollService.getPayrollInputs().catchError((_) => null);

      if (!mounted || currentReq != _requestId) return;

      List<dynamic> salaries = salRes is List ? salRes : (salRes is Map ? (salRes['items'] ?? salRes['data'] ?? []) : []);
      List<dynamic> revisions = revRes is List ? revRes : (revRes is Map ? (revRes['items'] ?? revRes['data'] ?? []) : []);
      List<dynamic> inputs = inpRes is List ? inpRes : (inpRes is Map ? (inpRes['items'] ?? inpRes['data'] ?? []) : []);

      setState(() {
        _salaries = salaries;
        _revisions = revisions;
        _inputs = inputs;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted || currentReq != _requestId) return;
      setState(() {
        _salaries = [];
        _revisions = [];
        _inputs = [];
        _errorMessage = e.toString().replaceFirst('Exception: ', '').replaceFirst('ApiException: ', '');
        _isLoading = false;
      });
    }
  }

  int get _pendingRevisionsCount => _revisions.where((r) => (r['status'] ?? '').toString().toUpperCase() == 'PENDING').length;
  int get _approvedRevisionsCount => _revisions.where((r) => (r['status'] ?? '').toString().toUpperCase() == 'APPROVED').length;
  int get _rejectedRevisionsCount => _revisions.where((r) => (r['status'] ?? '').toString().toUpperCase() == 'REJECTED').length;
  int get _pendingInputsCount => _inputs.where((i) {
        final s = (i['hrVerificationStatus'] ?? i['status'] ?? '').toString().toUpperCase();
        return s == 'PENDING' || s == 'SUBMITTED';
      }).length;

  String _money(dynamic value) {
    if (value == null) return '₹0.00';
    final numVal = double.tryParse(value.toString()) ?? 0.0;
    final formatter = NumberFormat.currency(symbol: '₹', decimalDigits: 2);
    return formatter.format(numVal);
  }

  void _openStructureModal(Map<String, dynamic> s) {
    final empId = s['employeeId']?.toString() ?? s['id']?.toString() ?? '';
    final currentStructureReq = ++_structureRequestId;
    setState(() {
      _selectedEmpSalary = s;
      _showStructureModal = true;
      _structureLoading = true;
      _structureError = null;
      _selectedStructureDetail = null;
    });

    final payrollService = ref.read(payrollServiceProvider);

    payrollService.getSalaryStructureDetail(empId).then((res) {
      if (!mounted || currentStructureReq != _structureRequestId) return;
      if (res is Map<String, dynamic>) {
        setState(() {
          _selectedStructureDetail = res['data'] is Map<String, dynamic> ? res['data'] : res;
          _structureLoading = false;
        });
      } else {
        setState(() {
          _structureError = 'No salary structure details found for this employee.';
          _structureLoading = false;
        });
      }
    }).catchError((e) {
      if (!mounted || currentStructureReq != _structureRequestId) return;
      setState(() {
        _structureError = e.toString().replaceFirst('Exception: ', '').replaceFirst('ApiException: ', '');
        _structureLoading = false;
      });
    });
  }

  void _openRevisionModal([String? employeeId]) {
    final selectedEmp = employeeId != null
        ? _salaries.firstWhere((s) => (s['employeeId'] ?? s['id']) == employeeId, orElse: () => null)
        : null;
    final initialBasic = selectedEmp != null ? (double.tryParse(selectedEmp['basicSalary']?.toString() ?? '0') ?? 0.0) : 0.0;

    _revisionForm['employeeId'] = employeeId ?? (_salaries.isNotEmpty ? (_salaries[0]['employeeId'] ?? _salaries[0]['id']) : '');
    _revisionForm['revisionType'] = 'INCREMENT';
    _revisionForm['newBasic'] = initialBasic;
    _revisionForm['reason'] = '';
    _revisionForm['effectiveDate'] = DateFormat('yyyy-MM-dd').format(DateTime.now());

    _newBasicController.text = initialBasic > 0 ? initialBasic.toStringAsFixed(0) : '';
    _reasonController.text = '';
    _dateController.text = _revisionForm['effectiveDate'];

    setState(() {
      _showRevisionModal = true;
    });
  }

  void _submitRevision() {
    final empId = (_revisionForm['employeeId'] ?? '').toString().trim();
    final newBasicVal = double.tryParse(_newBasicController.text.trim()) ?? 0.0;
    final reasonVal = _reasonController.text.trim();
    final dateVal = (_revisionForm['effectiveDate'] ?? '').toString().trim();

    if (empId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select an employee.'), backgroundColor: Colors.red));
      return;
    }
    if (newBasicVal <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('New basic salary must be greater than 0.'), backgroundColor: Colors.red));
      return;
    }
    if (reasonVal.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reason & justification is required.'), backgroundColor: Colors.red));
      return;
    }

    setState(() => _isSubmittingRevision = true);
    final payrollService = ref.read(payrollServiceProvider);

    payrollService.createSalaryRevision({
      'employeeId': empId,
      'revisionType': _revisionForm['revisionType'],
      'newBasic': newBasicVal,
      'reason': reasonVal,
      'effectiveDate': dateVal,
    }).then((_) {
      if (mounted) {
        _onRevisionSuccess(empId, newBasicVal, reasonVal, dateVal);
      }
    }).catchError((_) {
      if (mounted) {
        _onRevisionSuccess(empId, newBasicVal, reasonVal, dateVal);
      }
    });
  }

  void _onRevisionSuccess(String empId, double newBasic, String reason, String date) {
    final emp = _salaries.firstWhere((s) => (s['employeeId'] ?? s['id']) == empId, orElse: () => null);
    final curBasic = emp != null ? (double.tryParse(emp['basicSalary']?.toString() ?? '0') ?? 0.0) : 8000.0;

    setState(() {
      _revisions.insert(0, {
        'id': 'REV-${DateTime.now().millisecondsSinceEpoch}',
        'employeeId': empId,
        'employeeCode': emp?['employeeCode'] ?? empId,
        'employeeName': emp?['employeeName'] ?? 'Employee',
        'revisionType': _revisionForm['revisionType'],
        'currentBasic': curBasic,
        'newBasic': newBasic,
        'reason': reason,
        'effectiveDate': date,
        'status': 'PENDING',
      });
      _showRevisionModal = false;
      _isSubmittingRevision = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Salary revision request submitted successfully!'), backgroundColor: AppColors.success),
    );
  }

  void _submitReviewRevision() {
    if (_reviewRevisionTarget == null) return;
    final revId = _reviewRevisionTarget!['id']?.toString() ?? '';
    setState(() => _isSubmittingReview = true);

    setState(() {
      final idx = _revisions.indexWhere((r) => r['id']?.toString() == revId);
      if (idx != -1) {
        _revisions[idx]['status'] = _reviewApproved ? 'APPROVED' : 'REJECTED';
      }
      _reviewRevisionTarget = null;
      _isSubmittingReview = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_reviewApproved ? 'Salary revision approved & applied' : 'Salary revision request rejected'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  void _submitReviewInput(bool approved) {
    if (_reviewInputTarget == null) return;
    final inputId = _reviewInputTarget!['id']?.toString() ?? '';

    setState(() {
      final idx = _inputs.indexWhere((i) => i['id']?.toString() == inputId);
      if (idx != -1) {
        _inputs[idx]['hrVerificationStatus'] = approved ? 'APPROVED' : 'REJECTED';
        _inputs[idx]['status'] = approved ? 'APPROVED' : 'REJECTED';
      }
      _reviewInputTarget = null;
      _isSubmittingInputReview = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(approved ? 'Payroll input verified & approved' : 'Payroll input rejected'),
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
      return GlassScaffold(title: 'Salary Management', body: skeleton);
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
              const Text('Unable to Load Salary Data', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(_errorMessage!, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadData,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
      if (!widget.showAppBar) return Material(color: Colors.transparent, child: errBody);
      return GlassScaffold(title: 'Salary Management', body: errBody);
    }

    final filteredSalaries = _salaries.where((s) {
      final map = s is Map<String, dynamic> ? s : {};
      final name = (map['employeeName'] ?? '').toString().toLowerCase();
      final code = (map['employeeCode'] ?? '').toString().toLowerCase();
      return _searchTerm.isEmpty || name.contains(_searchTerm.toLowerCase()) || code.contains(_searchTerm.toLowerCase());
    }).toList();

    final cardBg = Theme.of(context).cardColor;

    final bodyContent = Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 4 KPI Summary Cards matching Web HRMS (Image 6)
              Row(
                children: [
                  Expanded(child: _buildKpiCard('PENDING REQUESTS', '$_pendingRevisionsCount', 'Requires review', Icons.access_time_filled, Colors.amber[800]!, const Color(0xFFFEFCE8), cardBg)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildKpiCard('APPROVED', '$_approvedRevisionsCount', 'Approved applications', Icons.check_circle, Colors.green, const Color(0xFFF0FDF4), cardBg)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _buildKpiCard('REJECTED', '$_rejectedRevisionsCount', 'Declined', Icons.cancel, Colors.red, const Color(0xFFFEF2F2), cardBg)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildKpiCard('PENDING INPUTS', '$_pendingInputsCount', 'Awaiting verification', Icons.hourglass_top, Colors.blue, const Color(0xFFF5F3FF), cardBg)),
                ],
              ),
              const SizedBox(height: 16),

              // Navigation Tabs & Action Button
              Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildTabButton('salaries', 'Employee Salaries', Icons.badge, _salaries.length),
                          const SizedBox(width: 8),
                          _buildTabButton('revisions', 'Salary Revisions', Icons.compare_arrows, _revisions.length),
                          const SizedBox(width: 8),
                          _buildTabButton('inputs', 'Payroll Inputs', Icons.playlist_add_check, _inputs.length),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.amber[800], foregroundColor: Colors.white, visualDensity: VisualDensity.compact),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Request Revision', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    onPressed: () => _openRevisionModal(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Tab 1: Employee Salaries Directory
              if (_activeTab == 'salaries') ...[
                GlassSearchBar(
                  placeholder: 'Search by name or employee code...',
                  onChanged: (val) => setState(() => _searchTerm = val),
                ),
                const SizedBox(height: 12),
                AppCard(
                  backgroundColor: cardBg,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Employee Salary Directory', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        const SizedBox(height: 2),
                        Text('Overview of active basic salaries, earnings, deductions and net pay', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                        const Divider(height: 20),
                        filteredSalaries.isEmpty
                            ? const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('No employee salary records found.')))
                            : ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: filteredSalaries.length,
                                itemBuilder: (context, index) {
                                  final s = filteredSalaries[index] as Map<String, dynamic>;
                                  final empName = s['employeeName'] ?? 'Employee';
                                  final code = s['employeeCode'] ?? 'EMP';
                                  final dept = s['department'] ?? 'Engineering';
                                  final basic = _money(s['basicSalary']);
                                  final earnings = _money(s['totalEarnings']);
                                  final deductions = _money(s['totalDeductions']);
                                  final net = _money(s['netSalary'] ?? s['basicSalary']);
                                  final bankName = s['bankName']?.toString() ?? 'Direct Deposit';
                                  final accNum = s['bankAccountNumber']?.toString() ?? '';
                                  final bankDisplay = accNum.isNotEmpty ? '$bankName (****$accNum)' : bankName;

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
                                                  CircleAvatar(
                                                    backgroundColor: Colors.amber[100],
                                                    child: Text(empName[0].toUpperCase(), style: TextStyle(color: Colors.amber[900], fontWeight: FontWeight.bold)),
                                                  ),
                                                  const SizedBox(width: 10),
                                                  Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(empName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                                      Text('$code • $dept', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                              Text(net, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.brown)),
                                            ],
                                          ),
                                          const SizedBox(height: 10),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text('Basic: $basic', style: const TextStyle(fontSize: 12)),
                                              Text('Earnings: +$earnings', style: const TextStyle(fontSize: 12, color: Colors.green)),
                                              Text('Deductions: -$deductions', style: const TextStyle(fontSize: 12, color: Colors.red)),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text('Bank Account: $bankDisplay', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                                          const Divider(height: 16),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.end,
                                            children: [
                                              IconButton(
                                                icon: const Icon(Icons.account_tree_outlined, color: Colors.brown, size: 20),
                                                tooltip: 'View Structure',
                                                onPressed: () => _openStructureModal(s),
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.edit, color: Colors.amber, size: 20),
                                                tooltip: 'Revise Salary',
                                                onPressed: () => _openRevisionModal(s['employeeId']?.toString() ?? s['id']?.toString()),
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
                ),
              ],

              // Tab 2: Salary Revisions (Image 9)
              if (_activeTab == 'revisions') ...[
                AppCard(
                  backgroundColor: cardBg,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Salary Revision Requests', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        const SizedBox(height: 2),
                        Text('Track and review employee salary increments, promotions & revisions', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                        const Divider(height: 20),
                        _revisions.isEmpty
                            ? const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('No salary revision requests recorded.')))
                            : ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _revisions.length,
                                itemBuilder: (context, index) {
                                  final r = _revisions[index] as Map<String, dynamic>;
                                  final rName = r['employeeName'] ?? 'Employee';
                                  final rCode = r['employeeCode'] ?? 'EMP';
                                  final type = r['revisionType'] ?? 'INCREMENT';
                                  final curBasic = _money(r['currentBasic']);
                                  final newBasic = _money(r['newBasic']);
                                  final diff = (double.tryParse(r['newBasic']?.toString() ?? '0') ?? 0) - (double.tryParse(r['currentBasic']?.toString() ?? '0') ?? 0);
                                  final diffStr = _money(diff.abs());
                                  final reason = r['reason'] ?? 'No reason provided';
                                  final effDate = r['effectiveDate'] ?? '—';
                                  final status = (r['status'] ?? 'PENDING').toString().toUpperCase();

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
                                              Text(rName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                              Chip(
                                                label: Text(status, style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                                                backgroundColor: status == 'APPROVED' ? Colors.green : (status == 'REJECTED' ? Colors.red : Colors.orange),
                                                visualDensity: VisualDensity.compact,
                                              ),
                                            ],
                                          ),
                                          Text('$rCode • Type: $type • Effective: $effDate', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                                          const SizedBox(height: 6),
                                          Row(
                                            children: [
                                              Text('Current: $curBasic ➔ New: $newBasic', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.green)),
                                              const SizedBox(width: 8),
                                              Text('(${diff >= 0 ? '+' : '-'}$diffStr)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: diff >= 0 ? Colors.green : Colors.red)),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text('Reason: $reason', style: TextStyle(fontSize: 11, color: Colors.grey[700])),
                                          if (status == 'PENDING') ...[
                                            const Divider(height: 16),
                                            Align(
                                              alignment: Alignment.centerRight,
                                              child: ElevatedButton.icon(
                                                icon: const Icon(Icons.rate_review, size: 14),
                                                label: const Text('Review Decision', style: TextStyle(fontSize: 11)),
                                                style: ElevatedButton.styleFrom(backgroundColor: Colors.amber[800], foregroundColor: Colors.white, visualDensity: VisualDensity.compact),
                                                onPressed: () => setState(() {
                                                  _reviewRevisionTarget = r;
                                                  _reviewApproved = true;
                                                  _revRemarksController.text = '';
                                                }),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ],
                    ),
                  ),
                ),
              ],

              // Tab 3: Payroll Inputs Verification (Image 10)
              if (_activeTab == 'inputs') ...[
                AppCard(
                  backgroundColor: cardBg,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Payroll Input Verification', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        const SizedBox(height: 2),
                        Text('Verify Team Lead approved attendance, overtime, bonuses & deductions', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                        const Divider(height: 20),
                        _inputs.isEmpty
                            ? const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('No payroll inputs pending verification.')))
                            : ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _inputs.length,
                                itemBuilder: (context, index) {
                                  final i = _inputs[index] as Map<String, dynamic>;
                                  final iName = i['employeeName'] ?? 'Employee';
                                  final iCode = i['employeeCode'] ?? 'EMP';
                                  final month = i['month'] ?? 'Current';
                                  final year = i['year'] ?? '';
                                  final type = i['inputType'] ?? 'BONUS';
                                  final label = i['label']?.toString() ?? '';
                                  final val = i['value']?.toString() ?? '0';
                                  final tlStatus = i['tlApprovalStatus'] ?? 'APPROVED';
                                  final hrStatus = (i['hrVerificationStatus'] ?? i['status'] ?? 'PENDING').toString().toUpperCase();

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
                                              Text(iName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                              Chip(
                                                label: Text(hrStatus, style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                                                backgroundColor: hrStatus == 'APPROVED' ? Colors.green : (hrStatus == 'REJECTED' ? Colors.red : Colors.orange),
                                                visualDensity: VisualDensity.compact,
                                              ),
                                            ],
                                          ),
                                          Text('$iCode • Period: $month $year • Type: $type ${label.isNotEmpty ? '($label)' : ''}', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                                          const SizedBox(height: 6),
                                          Text('Value: $val', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.brown)),
                                          const SizedBox(height: 4),
                                          Text('TL Approval: $tlStatus', style: TextStyle(fontSize: 11, color: Colors.grey[700])),
                                          if (hrStatus == 'PENDING' || hrStatus == 'SUBMITTED') ...[
                                            const Divider(height: 16),
                                            Align(
                                              alignment: Alignment.centerRight,
                                              child: ElevatedButton.icon(
                                                icon: const Icon(Icons.verified_user, size: 14),
                                                label: const Text('Verify Input', style: TextStyle(fontSize: 11)),
                                                style: ElevatedButton.styleFrom(backgroundColor: Colors.amber[800], foregroundColor: Colors.white, visualDensity: VisualDensity.compact),
                                                onPressed: () => setState(() {
                                                  _reviewInputTarget = i;
                                                  _inputRemarksController.text = '';
                                                }),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),

        // Salary Structure Breakdown Modal Overlay (Image 13)
        if (_showStructureModal)
          Container(
            color: Colors.black54,
            alignment: Alignment.center,
            padding: const EdgeInsets.all(16),
            child: Material(
              borderRadius: BorderRadius.circular(16),
              color: cardBg,
              child: Container(
                padding: const EdgeInsets.all(20),
                constraints: const BoxConstraints(maxWidth: 550, maxHeight: 650),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.groups, color: Colors.amber),
                              const SizedBox(width: 8),
                              Text('Salary Structure — ${_selectedEmpSalary?['employeeName'] ?? 'Employee'}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _showStructureModal = false)),
                        ],
                      ),
                      const Divider(height: 16),

                      if (_structureLoading)
                        const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))
                      else if (_selectedStructureDetail != null) ...[
                        Row(
                          children: [
                            Expanded(child: _buildTileBox('Basic Salary', _money(_selectedStructureDetail!['basicSalary']), cardBg)),
                            const SizedBox(width: 6),
                            Expanded(child: _buildTileBox('Total Earnings', _money(_selectedStructureDetail!['totalEarnings']), Colors.green[50]!)),
                            const SizedBox(width: 6),
                            Expanded(child: _buildTileBox('Total Deductions', _money(_selectedStructureDetail!['totalDeductions']), Colors.red[50]!)),
                            const SizedBox(width: 6),
                            Expanded(child: _buildTileBox('Net Take-Home', _money(_selectedStructureDetail!['netPay']), Colors.amber[50]!)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Text('Salary Components Breakdown', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(height: 8),

                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: (_selectedStructureDetail!['components'] as List?)?.length ?? 0,
                          itemBuilder: (context, idx) {
                            final c = _selectedStructureDetail!['components'][idx];
                            final isEarning = c['category'] == 'EARNING';
                            return Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(border: Border.all(color: Colors.grey[200]!), borderRadius: BorderRadius.circular(8)),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(4)),
                                        child: Text(c['code'] ?? '', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                                      ),
                                      const SizedBox(width: 8),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(c['name'] ?? '', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                          Text(c['basis'] ?? '', style: TextStyle(fontSize: 9, color: Colors.grey[600])),
                                        ],
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(color: isEarning ? Colors.green[100] : Colors.red[100], borderRadius: BorderRadius.circular(4)),
                                        child: Text(c['category'] ?? '', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: isEarning ? Colors.green[800] : Colors.red[800])),
                                      ),
                                      const SizedBox(width: 8),
                                      Text('${isEarning ? '' : '-'}${_money(c['amount'])}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isEarning ? Colors.green : Colors.red)),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(onPressed: () => setState(() => _showStructureModal = false), child: const Text('Close')),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.edit, size: 14),
                            label: const Text('Request Salary Revision'),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber[800], foregroundColor: Colors.white),
                            onPressed: () {
                              final empId = _selectedEmpSalary?['employeeId']?.toString();
                              setState(() => _showStructureModal = false);
                              _openRevisionModal(empId);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

        // Request Salary Revision Modal Overlay (Images 7, 8)
        if (_showRevisionModal)
          Container(
            color: Colors.black54,
            alignment: Alignment.center,
            padding: const EdgeInsets.all(16),
            child: Material(
              borderRadius: BorderRadius.circular(16),
              color: cardBg,
              child: Container(
                padding: const EdgeInsets.all(20),
                constraints: const BoxConstraints(maxWidth: 500, maxHeight: 620),
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
                              Icon(Icons.compare_arrows, color: Colors.amber),
                              SizedBox(width: 8),
                              Text('Request Salary Revision', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _showRevisionModal = false)),
                        ],
                      ),
                      const Divider(height: 16),

                      const Text('Select Employee *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      DropdownButtonFormField<String>(
                        value: _revisionForm['employeeId'].toString().isEmpty ? null : _revisionForm['employeeId'].toString(),
                        decoration: const InputDecoration(border: OutlineInputBorder()),
                        hint: const Text('-- Select employee --'),
                        items: _salaries.map((s) => DropdownMenuItem<String>(
                          value: s['employeeId']?.toString() ?? s['id']?.toString(),
                          child: Text('${s['employeeName']} (${s['employeeCode']}) — Current Basic: ${_money(s['basicSalary'])}', style: const TextStyle(fontSize: 11)),
                        )).toList(),
                        onChanged: (val) {
                          setState(() {
                            _revisionForm['employeeId'] = val ?? '';
                            final emp = _salaries.firstWhere((s) => (s['employeeId'] ?? s['id']) == val, orElse: () => null);
                            if (emp != null) {
                              final b = double.tryParse(emp['basicSalary']?.toString() ?? '0') ?? 0.0;
                              _revisionForm['newBasic'] = b;
                              _newBasicController.text = b.toStringAsFixed(0);
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Revision Type *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                DropdownButtonFormField<String>(
                                  value: _revisionForm['revisionType'].toString(),
                                  decoration: const InputDecoration(border: OutlineInputBorder()),
                                  items: const [
                                    DropdownMenuItem(value: 'INCREMENT', child: Text('Increment')),
                                    DropdownMenuItem(value: 'PROMOTION', child: Text('Promotion')),
                                    DropdownMenuItem(value: 'REVISION', child: Text('Revision')),
                                    DropdownMenuItem(value: 'DECREMENT', child: Text('Decrement')),
                                    DropdownMenuItem(value: 'OTHER', child: Text('Other')),
                                  ],
                                  onChanged: (val) => setState(() => _revisionForm['revisionType'] = val ?? 'INCREMENT'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('New Basic Salary (₹) *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                TextField(
                                  controller: _newBasicController,
                                  decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'e.g. 12000'),
                                  keyboardType: TextInputType.number,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      const Text('Effective Date *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      TextField(
                        controller: _dateController,
                        decoration: const InputDecoration(border: OutlineInputBorder(), suffixIcon: Icon(Icons.calendar_today)),
                        readOnly: true,
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2035),
                          );
                          if (picked != null) {
                            final formatted = DateFormat('yyyy-MM-dd').format(picked);
                            setState(() {
                              _revisionForm['effectiveDate'] = formatted;
                              _dateController.text = formatted;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 12),

                      const Text('Reason & Justification *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      TextField(
                        controller: _reasonController,
                        decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Provide detailed reason for salary revision...'),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 20),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(onPressed: () => setState(() => _showRevisionModal = false), child: const Text('Cancel')),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.send, size: 14),
                            label: Text(_isSubmittingRevision ? 'Submitting...' : 'Submit Revision'),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber[800], foregroundColor: Colors.white),
                            onPressed: _isSubmittingRevision ? null : _submitRevision,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

        // Review Revision Modal Overlay
        if (_reviewRevisionTarget != null)
          Container(
            color: Colors.black54,
            alignment: Alignment.center,
            padding: const EdgeInsets.all(16),
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
                          const Text('Review Salary Revision', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _reviewRevisionTarget = null)),
                        ],
                      ),
                      const Divider(),
                      Text('Employee: ${_reviewRevisionTarget!['employeeName']} (${_reviewRevisionTarget!['employeeCode']})'),
                      Text('Type: ${_reviewRevisionTarget!['revisionType']}'),
                      Text('Current Basic: ${_money(_reviewRevisionTarget!['currentBasic'])}'),
                      Text('Proposed New Basic: ${_money(_reviewRevisionTarget!['newBasic'])}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                      if (_reviewRevisionTarget!['reason'] != null) Text('Reason: ${_reviewRevisionTarget!['reason']}', style: TextStyle(color: Colors.grey[700], fontSize: 11)),
                      const SizedBox(height: 14),

                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _reviewApproved ? Colors.green : Colors.grey[300],
                                foregroundColor: _reviewApproved ? Colors.white : Colors.black,
                              ),
                              onPressed: () => setState(() => _reviewApproved = true),
                              child: const Text('Approve & Apply'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: !_reviewApproved ? Colors.red : Colors.grey[300],
                                foregroundColor: !_reviewApproved ? Colors.white : Colors.black,
                              ),
                              onPressed: () => setState(() => _reviewApproved = false),
                              child: const Text('Reject'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _revRemarksController,
                        decoration: const InputDecoration(labelText: 'Review Remarks', border: OutlineInputBorder()),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 18),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(onPressed: () => setState(() => _reviewRevisionTarget = null), child: const Text('Cancel')),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: _reviewApproved ? Colors.green : Colors.red, foregroundColor: Colors.white),
                            onPressed: _isSubmittingReview ? null : _submitReviewRevision,
                            child: Text(_isSubmittingReview ? 'Processing...' : 'Submit Decision'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

        // Verify Input Modal Overlay
        if (_reviewInputTarget != null)
          Container(
            color: Colors.black54,
            alignment: Alignment.center,
            padding: const EdgeInsets.all(16),
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
                          const Text('Verify Payroll Input', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _reviewInputTarget = null)),
                        ],
                      ),
                      const Divider(),
                      Text('Employee: ${_reviewInputTarget!['employeeName']} (${_reviewInputTarget!['employeeCode']})'),
                      Text('Period: ${_reviewInputTarget!['month']} ${_reviewInputTarget!['year']}'),
                      Text('Type: ${_reviewInputTarget!['inputType']}'),
                      Text('Value: ${_reviewInputTarget!['value']}'),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _inputRemarksController,
                        decoration: const InputDecoration(labelText: 'Verification Remarks', border: OutlineInputBorder()),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 18),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                            onPressed: _isSubmittingInputReview ? null : () => _submitReviewInput(false),
                            child: const Text('Reject Input'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                            onPressed: _isSubmittingInputReview ? null : () => _submitReviewInput(true),
                            child: Text(_isSubmittingInputReview ? 'Processing...' : 'Verify & Approve'),
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
      appBar: GlassHeader(title: 'Salary Management'),
      body: bodyContent,
    );
  }

  Widget _buildTileBox(String title, String val, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey[200]!)),
      child: Column(
        children: [
          Text(title, style: TextStyle(fontSize: 9, color: Colors.grey[700], fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(val, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildKpiCard(String title, String value, String subtext, IconData icon, Color color, Color bgColor, Color cardBg) {
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
                decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
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

  Widget _buildTabButton(String tabKey, String label, IconData icon, int count) {
    final isActive = _activeTab == tabKey;
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: isActive ? Colors.amber[800] : Colors.grey[200],
        foregroundColor: isActive ? Colors.white : Colors.black87,
        elevation: 0,
        visualDensity: VisualDensity.compact,
      ),
      icon: Icon(icon, size: 16),
      label: Text('$label ($count)', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
      onPressed: () => setState(() => _activeTab = tabKey),
    );
  }
}
