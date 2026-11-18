import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/api/payroll_service.dart';
import '../../core/auth/auth_service.dart';
import '../../core/storage/storage_service.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/loading_shimmer.dart';
import '../../shared/widgets/status_chip.dart';
import '../../core/widgets/glass_scaffold.dart';

enum _PayrollTab { payslips, salary }

class MyPayslipsScreen extends ConsumerStatefulWidget {
  final bool showAppBar;
  const MyPayslipsScreen({super.key, this.showAppBar = false});

  @override
  ConsumerState<MyPayslipsScreen> createState() => _MyPayslipsScreenState();
}

class _MyPayslipsScreenState extends ConsumerState<MyPayslipsScreen> {
  _PayrollTab _activeTab = _PayrollTab.payslips;
  int _selectedYear = 2026;

  bool _loading = true;
  String? _error;

  Map<String, dynamic> _salaryWorkflow = {};
  List<Map<String, dynamic>> _salaryHistory = [];

  @override
  void initState() {
    super.initState();
    _loadPayrollData();
  }

  Future<dynamic> _tryFetch(PayrollService payrollService, List<String> endpoints) async {
    for (final ep in endpoints) {
      try {
        final res = await payrollService.rawGet(ep);
        if (res != null) return res;
      } catch (_) {}
    }
    return null;
  }

  Map<String, dynamic> _normalizeHistoryItem(dynamic raw) {
    if (raw is! Map) return {};
    final m = Map<String, dynamic>.from(raw);

    final basic = double.tryParse(m['basicSalary']?.toString() ?? m['basic']?.toString() ?? m['basicPay']?.toString() ?? m['baseSalary']?.toString() ?? '0') ?? 0.0;
    final allowances = double.tryParse(m['allowances']?.toString() ?? m['allowance']?.toString() ?? m['totalAllowances']?.toString() ?? '0') ?? 0.0;
    final gross = double.tryParse(m['grossPay']?.toString() ?? m['grossSalary']?.toString() ?? m['gross']?.toString() ?? m['totalEarnings']?.toString() ?? '0') ?? (basic + allowances);
    final deductions = double.tryParse(m['deductions']?.toString() ?? m['totalDeductions']?.toString() ?? m['deduction']?.toString() ?? '0') ?? 0.0;
    final net = double.tryParse(m['netPay']?.toString() ?? m['netSalary']?.toString() ?? m['net']?.toString() ?? m['takeHome']?.toString() ?? m['netAmount']?.toString() ?? '0') ?? (gross - deductions);

    final month = m['month']?.toString() ?? m['payrollMonth']?.toString() ?? m['payMonth']?.toString() ?? m['monthName']?.toString() ?? 'Current';
    final year = int.tryParse(m['year']?.toString() ?? m['payrollYear']?.toString() ?? m['payYear']?.toString() ?? '') ?? DateTime.now().year;

    return {
      ...m,
      'id': m['id']?.toString() ?? m['_id']?.toString() ?? m['payslipId']?.toString() ?? 'ps-$year-$month',
      'month': month,
      'year': year,
      'basicSalary': basic,
      'allowances': allowances,
      'grossPay': gross,
      'deductions': deductions,
      'netPay': net,
      'status': (m['status'] ?? m['paymentStatus'] ?? m['payrollStatus'] ?? 'PAID').toString().toUpperCase(),
      'paidDate': m['paidDate']?.toString() ?? m['paidOn']?.toString() ?? m['paymentDate']?.toString() ?? m['disbursementDate']?.toString() ?? '',
    };
  }

  Future<void> _loadPayrollData() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    final payrollService = ref.read(payrollServiceProvider);

    try {
      final salaryRes = await _tryFetch(payrollService, [
        ApiEndpoints.mySalary,
        '/salary/my',
        '/payroll/salary/my',
        '/salary/structure/my',
      ]);

      final historyRes = await _tryFetch(payrollService, [
        ApiEndpoints.mySalaryHistory,
        '/salary/my/history',
        ApiEndpoints.myPayslips,
        '/payroll/payslips/my',
      ]);

      if (!mounted) return;

      Map<String, dynamic> workflowMap = {};
      if (salaryRes is Map) {
        workflowMap = Map<String, dynamic>.from(salaryRes['data'] is Map ? salaryRes['data'] : salaryRes);
      }

      List<dynamic> rawHistory = [];
      if (historyRes is List) {
        rawHistory = historyRes;
      } else if (historyRes is Map) {
        rawHistory = historyRes['data'] ?? historyRes['items'] ?? historyRes['history'] ?? historyRes['payslips'] ?? [];
      }

      final historyList = <Map<String, dynamic>>[];
      for (final item in rawHistory) {
        if (item is Map) {
          historyList.add(_normalizeHistoryItem(item));
        }
      }

      setState(() {
        _salaryWorkflow = workflowMap;
        _salaryHistory = historyList;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('ApiException: ', '').replaceFirst('Exception: ', '');
      });
    }
  }

  String _formatRupees(dynamic amount, {bool isDeduction = false, bool isAddition = false}) {
    if (amount == null) return '₹0.00';
    final val = double.tryParse(amount.toString().replaceAll('₹', '').replaceAll(',', '')) ?? 0.0;
    final absVal = val.abs();

    final parts = absVal.toStringAsFixed(2).split('.');
    final integerPart = parts[0];
    final decimalPart = parts[1];

    String formattedInt = '';
    int count = 0;
    for (int i = integerPart.length - 1; i >= 0; i--) {
      if (count == 3 || (count > 3 && (count - 3) % 2 == 0)) {
        formattedInt = ',$formattedInt';
      }
      formattedInt = integerPart[i] + formattedInt;
      count++;
    }

    final formattedNumber = '₹$formattedInt.$decimalPart';
    if (val < 0 || isDeduction) return '-$formattedNumber';
    if (isAddition && val > 0) return '+$formattedNumber';
    return formattedNumber;
  }

  String _formatMonthYear(dynamic month, dynamic year) {
    if (month == null) return 'Recent Period';
    final mStr = month.toString();
    final yStr = year?.toString() ?? '';
    if (mStr.contains(' ') || RegExp(r'[a-zA-Z]').hasMatch(mStr)) {
      return yStr.isNotEmpty && !mStr.contains(yStr) ? '$mStr $yStr' : mStr;
    }
    final mNum = int.tryParse(mStr);
    const months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    if (mNum != null && mNum >= 1 && mNum <= 12) {
      return yStr.isNotEmpty ? '${months[mNum - 1]} $yStr' : months[mNum - 1];
    }
    return yStr.isNotEmpty ? '$mStr $yStr' : mStr;
  }

  double get _monthlyGross {
    final v = double.tryParse(_salaryWorkflow['grossPay']?.toString() ?? _salaryWorkflow['monthlyGross']?.toString() ?? _salaryWorkflow['gross']?.toString() ?? _salaryWorkflow['totalEarnings']?.toString() ?? '');
    if (v != null) return v;
    if (_salaryHistory.isNotEmpty) {
      return double.tryParse(_salaryHistory.first['grossPay']?.toString() ?? '0') ?? 0.0;
    }
    return 0.0;
  }

  double get _totalDeductions {
    final v = double.tryParse(_salaryWorkflow['totalDeductions']?.toString() ?? _salaryWorkflow['deductions']?.toString() ?? '');
    if (v != null) return v;
    if (_salaryHistory.isNotEmpty) {
      return double.tryParse(_salaryHistory.first['deductions']?.toString() ?? '0') ?? 0.0;
    }
    return 0.0;
  }

  double get _netTakeHome {
    final v = double.tryParse(_salaryWorkflow['netPay']?.toString() ?? _salaryWorkflow['takeHome']?.toString() ?? _salaryWorkflow['net']?.toString() ?? '');
    if (v != null) return v;
    if (_salaryHistory.isNotEmpty) {
      return double.tryParse(_salaryHistory.first['netPay']?.toString() ?? '0') ?? 0.0;
    }
    return _monthlyGross - _totalDeductions;
  }

  double get _ytdTotal {
    double total = 0.0;
    for (final p in _salaryHistory) {
      final y = int.tryParse(p['year']?.toString() ?? '');
      if (y == _selectedYear) {
        final net = double.tryParse(p['netPay']?.toString() ?? '0') ?? 0;
        total += net;
      }
    }
    return total;
  }

  Future<void> _downloadPayslipPdf(Map<String, dynamic> record) async {
    final payrollId = (record['id'] ?? record['payrollId'] ?? '').toString();
    final period = _formatMonthYear(record['month'], record['year']);

    if (payrollId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to download: Invalid payslip ID.')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Downloading payslip for $period...')),
    );

    final apiClient = ref.read(apiClientProvider);
    final storageService = ref.read(storageServiceProvider);
    final user = ref.read(authServiceProvider).user;

    try {
      final tempDir = Directory.systemTemp;
      final tempFile = File('${tempDir.path}/temp_payslip_$payrollId.pdf');

      final downloadedPdf = await apiClient.getBinaryStreamToFile(
        '/payroll/payslip/$payrollId',
        targetFile: tempFile,
      );

      if (user != null) {
        final pdfBytes = await downloadedPdf.readAsBytes();
        await storageService.encryptAndSavePayslipBytes(
          pdfBytes: pdfBytes,
          userId: user.id,
          payrollId: payrollId,
          targetDirectoryPath: tempDir.path,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payslip for $period downloaded and encrypted in secure vault.'),
          backgroundColor: Colors.green.shade700,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to download payslip: ${e.toString().replaceFirst("ApiException: ", "")}'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  void _showPayslipModal(Map<String, dynamic> record) {
    final user = ref.read(authServiceProvider).user;
    final period = _formatMonthYear(record['month'], record['year']);
    final basic = record['basicSalary'] ?? 0.0;
    final allowances = record['allowances'] ?? 0.0;
    final deductions = record['deductions'] ?? 0.0;
    final gross = record['grossPay'] ?? 0.0;
    final net = record['netPay'] ?? 0.0;
    final status = record['status']?.toString().toUpperCase() ?? 'PENDING';
    final payDate = record['paidDate']?.toString() ?? record['paymentDate']?.toString() ?? record['payDate']?.toString() ?? '--';
    final employeeName = user?.fullName.isNotEmpty == true ? user!.fullName : 'Employee';
    final employeeId = (user?.employeeId != null && user!.employeeId!.isNotEmpty) ? user.employeeId! : '--';
    final designation = user?.designation?.isNotEmpty == true ? user!.designation! : '--';
    final department = user?.department?.isNotEmpty == true ? user!.department! : '--';
    final slipNo = 'SLIP #${period.toUpperCase()}';

    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.88,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkMainSurface : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Envision Beyond India Pvt Ltd',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Official Salary Statement & Tax Breakdown',
                          style: TextStyle(fontSize: 10.5, color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          slipNo,
                          style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.amber),
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, size: 20),
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(height: 24),
              Expanded(
                child: ListView(
                  children: [
                    _statusBadge(status),
                    const SizedBox(height: 16),
                    // Metadata Box matching website view modal
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSecondarySurface : AppColors.lightSecondarySurface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isDark ? AppColors.darkBordersAndDividers : AppColors.lightBordersAndDividers),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(child: _metaItem(isDark, Icons.person_outline, 'Employee Name', employeeName)),
                              Expanded(child: _metaItem(isDark, Icons.badge_outlined, 'Employee ID', employeeId)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(child: _metaItem(isDark, Icons.work_outline, 'Designation', designation)),
                              Expanded(child: _metaItem(isDark, Icons.apartment_outlined, 'Department', department)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(child: _metaItem(isDark, Icons.calendar_today_outlined, 'Pay Period', period)),
                              Expanded(child: _metaItem(isDark, Icons.event_available_outlined, 'Pay Date', payDate)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(child: _metaItem(isDark, Icons.account_balance_outlined, 'Bank Account', 'Direct Bank Transfer')),
                              Expanded(child: _metaItem(isDark, Icons.verified_outlined, 'Tax ID', 'PAN / Statutory Validated')),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text('Gross Earnings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 8),
                    _modalRow(isDark, 'Basic Salary', _formatRupees(basic)),
                    _modalRow(isDark, 'Allowances', _formatRupees(allowances, isAddition: true)),
                    _modalRow(isDark, 'Total Gross Earnings', _formatRupees(gross), isBold: true),
                    const Divider(height: 24),
                    const Text('Deductions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 8),
                    _modalRow(isDark, 'Total Statutory Deductions', _formatRupees(deductions, isDeduction: true)),
                    _modalRow(isDark, 'Total Deductions', _formatRupees(deductions, isDeduction: true), isBold: true),
                    const Divider(height: 24),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Net Take-Home Pay', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                          Text(_formatRupees(net), style: const TextStyle(color: AppColors.primary, fontSize: 18, fontWeight: FontWeight.w900)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.security, size: 16, color: Colors.orange),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'This is a system-generated electronic payslip statement verified by Envision Beyond India Pvt Ltd. No physical signature required.',
                              style: TextStyle(fontSize: 10, color: AppColors.lightSecondaryText),
                            ),
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
      },
    );
  }

  Widget _metaItem(bool dark, IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: AppColors.primary),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 9.5, color: dark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText)),
              const SizedBox(height: 2),
              Text(value, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: dark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _modalRow(bool dark, String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: isBold ? (dark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText) : AppColors.lightSecondaryText, fontSize: 12.5, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: isBold ? FontWeight.bold : FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _statusBadge(String status) {
    final isProcessing = status == 'PROCESSING';
    final color = isProcessing ? Colors.amber : AppColors.success;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 6, color: color),
          const SizedBox(width: 5),
          Text(status, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final content = RefreshIndicator(
      onRefresh: _loadPayrollData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!widget.showAppBar) ...[
              _buildHeader(isDark),
              const SizedBox(height: 14),
            ],
            _buildNavigationTabs(isDark),
            const SizedBox(height: 16),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
              )
            else if (_error != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                child: Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
              )
            else if (_activeTab == _PayrollTab.payslips)
              _buildPayslipsTabContent(isDark)
            else
              _buildSalaryTabContent(isDark),
          ],
        ),
      ),
    );

    if (!widget.showAppBar) return Material(color: Colors.transparent, child: content);

    return GlassScaffold(
      title: 'My Payslips & Salary',
      body: content,
    );
  }

  Widget _buildHeader(bool dark) {
    final title = _activeTab == _PayrollTab.payslips ? 'My Payslips' : 'My Salary';
    final subtitle = _activeTab == _PayrollTab.payslips
        ? 'View and download your monthly salary slips and tax statements'
        : 'View your salary structure, monthly breakdown and payslip history';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(color: dark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText, fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(subtitle, style: TextStyle(color: dark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText, fontSize: 13)),
      ],
    );
  }

  Widget _buildNavigationTabs(bool dark) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: dark ? AppColors.darkSecondarySurface : AppColors.lightSecondarySurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: dark ? AppColors.darkBordersAndDividers : AppColors.lightBordersAndDividers),
      ),
      child: Row(
        children: [
          Expanded(
            child: _tabButton(
              dark,
              title: 'My Payslips',
              icon: Icons.payments_outlined,
              isSelected: _activeTab == _PayrollTab.payslips,
              onTap: () => setState(() => _activeTab = _PayrollTab.payslips),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _tabButton(
              dark,
              title: 'My Salary',
              icon: Icons.account_balance_wallet_outlined,
              isSelected: _activeTab == _PayrollTab.salary,
              onTap: () => setState(() => _activeTab = _PayrollTab.salary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabButton(bool dark, {required String title, required IconData icon, required bool isSelected, required VoidCallback onTap}) {
    return Material(
      color: isSelected ? AppColors.primary : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: isSelected ? Colors.white : (dark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText)),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  color: isSelected ? Colors.white : (dark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText),
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPayslipsTabContent(bool dark) {
    final gross = _monthlyGross;
    final deductions = _totalDeductions;
    final net = _netTakeHome;
    final ytd = _ytdTotal;

    final filteredHistory = _salaryHistory.where((item) {
      final y = int.tryParse(item['year']?.toString() ?? '');
      return y == _selectedYear || y == null;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.55,
          children: [
            _summaryCard(dark, title: 'MONTHLY GROSS', value: _formatRupees(gross), subtitle: 'Base + Allowances', icon: Icons.wallet, color: AppColors.primary),
            _summaryCard(dark, title: 'TOTAL DEDUCTIONS', value: _formatRupees(deductions, isDeduction: true), subtitle: 'Taxes & PF', icon: Icons.remove_circle, color: Colors.red),
            _summaryCard(dark, title: 'NET TAKE-HOME', value: _formatRupees(net), subtitle: 'Transferred', icon: Icons.check_circle, color: AppColors.success),
            _summaryCard(dark, title: 'YTD EARNINGS', value: _formatRupees(ytd), subtitle: 'Cumulative ($_selectedYear)', icon: Icons.trending_up, color: Colors.purple),
          ],
        ),
        const SizedBox(height: 20),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Salary Slips History', style: TextStyle(color: dark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText, fontSize: 16, fontWeight: FontWeight.bold)),
            _yearFilterDropdown(dark),
          ],
        ),
        const SizedBox(height: 12),

        filteredHistory.isEmpty
            ? AppCard(child: Center(child: Padding(padding: const EdgeInsets.all(28), child: Text('No salary slips found for $_selectedYear.'))))
            : ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredHistory.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final record = filteredHistory[index];
                  final period = _formatMonthYear(record['month'], record['year']);
                  final basic = record['basicSalary'] ?? 0.0;
                  final allowances = record['allowances'] ?? 0.0;
                  final deduct = record['deductions'] ?? 0.0;
                  final netPay = record['netPay'] ?? 0.0;
                  final status = record['status']?.toString().toUpperCase() ?? 'PENDING';

                  return AppCard(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(period, style: TextStyle(color: dark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText, fontSize: 14, fontWeight: FontWeight.bold)),
                            ),
                            _statusBadge(status),
                            const SizedBox(width: 8),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              onPressed: () => _showPayslipModal(record),
                              icon: const Icon(Icons.visibility_outlined, size: 18, color: AppColors.primary),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              onPressed: () => _downloadPayslipPdf(record),
                              icon: const Icon(Icons.download_rounded, size: 18, color: AppColors.lightSecondaryText),
                            ),
                          ],
                        ),
                        const Divider(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _tableCell(dark, 'Basic', _formatRupees(basic)),
                            _tableCell(dark, 'Allowances', _formatRupees(allowances, isAddition: true)),
                            _tableCell(dark, 'Deductions', _formatRupees(deduct, isDeduction: true)),
                            _tableCell(dark, 'Net Pay', _formatRupees(netPay), isBold: true),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
      ],
    );
  }

  Widget _buildSalaryTabContent(bool dark) {
    final structureMap = _salaryWorkflow['structure'] is Map
        ? Map<String, dynamic>.from(_salaryWorkflow['structure'] as Map)
        : <String, dynamic>{};

    final basic = structureMap['basicSalary'] ?? 0.0;
    final hra = structureMap['hra'] ?? 0.0;
    final conveyance = structureMap['conveyance'] ?? 0.0;
    final medical = structureMap['medicalAllowance'] ?? 0.0;
    final special = structureMap['specialAllowance'] ?? 0.0;
    final gross = structureMap['totalEarnings'] ?? 0.0;

    final pf = structureMap['pfAmount'] ?? 0.0;
    final pt = structureMap['professionalTax'] ?? 0.0;
    final deductions = structureMap['totalDeductions'] ?? 0.0;
    final net = structureMap['netSalary'] ?? 0.0;

    final filteredHistory = _salaryHistory.where((item) {
      final y = int.tryParse(item['year']?.toString() ?? '');
      return y == _selectedYear || y == null;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.55,
          children: [
            _summaryCard(dark, title: 'BASIC SALARY', value: _formatRupees(basic), subtitle: 'Monthly base', icon: Icons.work, color: AppColors.primary),
            _summaryCard(dark, title: 'GROSS PAY', value: _formatRupees(gross), subtitle: 'Before deductions', icon: Icons.receipt, color: Colors.purple),
            _summaryCard(dark, title: 'DEDUCTIONS', value: _formatRupees(deductions, isDeduction: true), subtitle: 'Tax & PF', icon: Icons.remove_circle, color: Colors.red),
            _summaryCard(dark, title: 'NET TAKE-HOME', value: _formatRupees(net), subtitle: 'Estimated', icon: Icons.check_circle, color: AppColors.success),
          ],
        ),
        const SizedBox(height: 20),

        const Text('Salary Structure Breakdown', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 12),

        _breakdownBox(
          dark,
          title: 'Earnings',
          icon: Icons.add_circle_outline_rounded,
          themeColor: AppColors.success,
          items: [
            _BreakdownItem('Basic Salary', _formatRupees(basic)),
            _BreakdownItem('House Rent Allowance (HRA)', _formatRupees(hra)),
            _BreakdownItem('Conveyance Allowance', _formatRupees(conveyance)),
            _BreakdownItem('Medical Allowance', _formatRupees(medical)),
            _BreakdownItem('Special Allowance', _formatRupees(special)),
          ],
          totalLabel: 'Total Earnings',
          totalValue: _formatRupees(gross),
        ),
        const SizedBox(height: 14),

        _breakdownBox(
          dark,
          title: 'Deductions',
          icon: Icons.remove_circle_outline_rounded,
          themeColor: Colors.red,
          items: [
            _BreakdownItem('Provident Fund (PF)', _formatRupees(pf, isDeduction: true)),
            _BreakdownItem('Professional Tax', _formatRupees(pt, isDeduction: true)),
          ],
          totalLabel: 'Total Deductions',
          totalValue: _formatRupees(deductions, isDeduction: true),
        ),
        const SizedBox(height: 20),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Salary & Payslip History', style: TextStyle(color: dark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText, fontSize: 16, fontWeight: FontWeight.bold)),
            _yearFilterDropdown(dark),
          ],
        ),
        const SizedBox(height: 12),

        filteredHistory.isEmpty
            ? AppCard(child: Center(child: Padding(padding: const EdgeInsets.all(28), child: Text('No salary records found for $_selectedYear.'))))
            : ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredHistory.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final record = filteredHistory[index];
                  final period = _formatMonthYear(record['month'], record['year']);
                  final gPay = record['grossPay'] ?? gross;
                  final dPay = record['deductions'] ?? deductions;
                  final nPay = record['netPay'] ?? net;
                  final status = record['status']?.toString().toUpperCase() ?? 'PAID';
                  final tlApproval = record['tlApproval']?.toString() ?? 'Approved';
                  final hrStatus = record['hrStatus']?.toString() ?? 'Approved';

                  return AppCard(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(period, style: TextStyle(color: dark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText, fontSize: 14, fontWeight: FontWeight.bold)),
                            ),
                            _statusBadge(status),
                            const SizedBox(width: 8),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              onPressed: () => _showPayslipModal(record),
                              icon: const Icon(Icons.visibility_outlined, size: 18, color: AppColors.primary),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              onPressed: () => _downloadPayslipPdf(record),
                              icon: const Icon(Icons.download_rounded, size: 18, color: AppColors.lightSecondaryText),
                            ),
                          ],
                        ),
                        const Divider(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _tableCell(dark, 'Gross Pay', _formatRupees(gPay)),
                            _tableCell(dark, 'Deductions', _formatRupees(dPay, isDeduction: true)),
                            _tableCell(dark, 'Net Pay', _formatRupees(nPay), isBold: true),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('TL Approval: $tlApproval', style: TextStyle(fontSize: 10, color: dark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText)),
                            Text('HR Status: $hrStatus', style: TextStyle(fontSize: 10, color: dark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText)),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
      ],
    );
  }

  Widget _summaryCard(bool dark, {required String title, required String value, required String subtitle, required IconData icon, required Color color}) {
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: dark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText, fontSize: 9.5, fontWeight: FontWeight.w800)),
              ),
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: color, size: 16),
              ),
            ],
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: TextStyle(color: dark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText, fontSize: 17, fontWeight: FontWeight.w900)),
          ),
          Text(subtitle, style: TextStyle(color: dark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText, fontSize: 9.5)),
        ],
      ),
    );
  }

  Widget _breakdownBox(bool dark, {required String title, required IconData icon, required Color themeColor, required List<_BreakdownItem> items, required String totalLabel, required String totalValue}) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: themeColor, size: 18),
              const SizedBox(width: 8),
              Text(title, style: TextStyle(color: dark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText, fontSize: 14, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(item.label, style: TextStyle(color: dark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText, fontSize: 12)),
                  Text(item.value, style: TextStyle(color: dark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText, fontSize: 12.5, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          const Divider(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(color: themeColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(totalLabel, style: TextStyle(color: themeColor, fontSize: 12.5, fontWeight: FontWeight.bold)),
                Text(totalValue, style: TextStyle(color: themeColor, fontSize: 14, fontWeight: FontWeight.w900)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tableCell(bool dark, String label, String value, {bool isBold = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: dark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText, fontSize: 10)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(color: isBold ? AppColors.primary : (dark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText), fontSize: 12, fontWeight: isBold ? FontWeight.bold : FontWeight.w600)),
      ],
    );
  }

  Widget _yearFilterDropdown(bool dark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: dark ? AppColors.darkSecondarySurface : AppColors.lightInputBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: dark ? AppColors.darkBordersAndDividers : AppColors.lightBordersAndDividers),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _selectedYear,
          dropdownColor: dark ? AppColors.darkMainSurface : Colors.white,
          style: TextStyle(color: dark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText, fontSize: 12, fontWeight: FontWeight.bold),
          items: const [
            DropdownMenuItem(value: 2026, child: Text('Filter Year: 2026')),
            DropdownMenuItem(value: 2025, child: Text('Filter Year: 2025')),
            DropdownMenuItem(value: 2024, child: Text('Filter Year: 2024')),
          ],
          onChanged: (val) {
            if (val != null) setState(() => _selectedYear = val);
          },
        ),
      ),
    );
  }
}

class _BreakdownItem {
  final String label;
  final String value;
  _BreakdownItem(this.label, this.value);
}
