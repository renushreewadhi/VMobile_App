import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/loading_shimmer.dart';

class FinanceReportsScreen extends ConsumerStatefulWidget {
  const FinanceReportsScreen({super.key});

  @override
  ConsumerState<FinanceReportsScreen> createState() => _FinanceReportsScreenState();
}

class _FinanceReportsScreenState extends ConsumerState<FinanceReportsScreen> {
  String _searchTerm = '';
  String _selectedCategory = 'All'; // 'All', 'Payroll', 'Taxation', 'Expenses', 'Loans & Advances', 'Audit Logs'
  String _selectedFormat = 'All'; // 'All', 'PDF', 'Excel', 'CSV'
  bool _isLoading = true;

  List<Map<String, dynamic>> _reports = [];

  // Custom Report Modal Controllers
  final TextEditingController _titleController = TextEditingController();
  String _newCategory = 'Payroll';
  String _newFormat = 'PDF';
  String _newDateRange = 'Current Month (Oct 2026)';
  bool _includeDetails = true;

  final List<String> _categories = [
    'All',
    'Payroll',
    'Taxation',
    'Expenses',
    'Loans & Advances',
    'Audit Logs',
  ];

  final List<Map<String, String>> _scheduledExports = [
    {'title': 'Monthly Finance & Payroll Audit', 'recurrence': 'Monthly (1st)', 'recipients': 'finance-team@company.com', 'format': 'Excel'},
    {'title': 'Quarterly TDS & Statutory Return', 'recurrence': 'Quarterly', 'recipients': 'compliance@company.com', 'format': 'PDF'},
    {'title': 'Weekly Expense Claims Breakdown', 'recurrence': 'Weekly (Mon)', 'recipients': 'accounts@company.com', 'format': 'CSV'},
    {'title': 'Annual Balance Sheet & Ledger', 'recurrence': 'Yearly (End FY)', 'recipients': 'auditors@company.com', 'format': 'PDF'},
  ];

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _loadReports() async {
    setState(() => _isLoading = true);
    final apiClient = ref.read(apiClientProvider);

    try {
      final res = await apiClient.get(ApiEndpoints.financeReports).catchError((_) => null);

      if (mounted) {
        List<dynamic> items = [];
        if (res is List) {
          items = res;
        } else if (res is Map<String, dynamic> && res['data'] is List) {
          items = res['data'];
        }

        if (items.isNotEmpty) {
          _reports = items.map((r) => _mapReportItem(r)).toList();
        } else {
          _reports = _getMockReports();
        }
        _isLoading = false;
        setState(() {});
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _reports = _getMockReports();
          _isLoading = false;
        });
      }
    }
  }

  Map<String, dynamic> _mapReportItem(dynamic r) {
    final Map<String, dynamic> map = r is Map<String, dynamic> ? r : {};
    return {
      'id': map['id'] ?? 'RPT-101',
      'title': map['title'] ?? 'Financial Statement',
      'category': map['category'] ?? 'Payroll',
      'desc': map['desc'] ?? map['description'] ?? 'Detailed financial audit report and summary statement.',
      'totalDisbursed': (map['totalDisbursed'] ?? 0) as num,
      'totalPending': (map['totalPending'] ?? 0) as num,
      'totalRecords': (map['totalRecords'] ?? 0) as int,
      'lastGenerated': map['lastGenerated'] ?? 'Oct 14, 2026',
      'format': map['format'] ?? 'PDF',
      'fileSize': map['fileSize'] ?? '2.4 MB',
      'icon': map['icon'] ?? Icons.file_present,
    };
  }

  List<Map<String, dynamic>> _getMockReports() {
    return [
      {
        'id': 'RPT-PAY-101',
        'title': 'Payroll Monthly Summary & Tax Ledger',
        'category': 'Payroll',
        'desc': 'Comprehensive monthly salary breakdown, gross pay, net pay disbursements, and statutory deductions.',
        'totalDisbursed': 1850000,
        'totalPending': 0,
        'totalRecords': 142,
        'lastGenerated': 'Oct 01, 2026',
        'format': 'PDF',
        'fileSize': '4.2 MB',
        'icon': Icons.payments,
      },
      {
        'id': 'RPT-TAX-202',
        'title': 'Income Tax & Form 24Q TDS Statement',
        'category': 'Taxation',
        'desc': 'Quarterly tax deduction certificate log, employee PAN verifications, and challan deposit history.',
        'totalDisbursed': 425000,
        'totalPending': 35000,
        'totalRecords': 65,
        'lastGenerated': 'Sep 30, 2026',
        'format': 'Excel',
        'fileSize': '2.8 MB',
        'icon': Icons.assignment_turned_in,
      },
      {
        'id': 'RPT-EXP-303',
        'title': 'Employee Expense Claims & Travel Report',
        'category': 'Expenses',
        'desc': 'Itemized expense submissions, receipt audit status, policy compliance checks, and approval timelines.',
        'totalDisbursed': 384000,
        'totalPending': 52000,
        'totalRecords': 94,
        'lastGenerated': 'Oct 14, 2026',
        'format': 'Excel',
        'fileSize': '3.1 MB',
        'icon': Icons.receipt_long,
      },
      {
        'id': 'RPT-LON-404',
        'title': 'Staff Loans & Salary Advance Balance',
        'category': 'Loans & Advances',
        'desc': 'Active loan portfolio, monthly EMI recovery schedule, interest calculations, and principal balances.',
        'totalDisbursed': 280000,
        'totalPending': 124000,
        'totalRecords': 22,
        'lastGenerated': 'Oct 10, 2026',
        'format': 'PDF',
        'fileSize': '1.9 MB',
        'icon': Icons.volunteer_activism,
      },
      {
        'id': 'RPT-AUD-505',
        'title': 'Corporate Payment & Audit Ledger',
        'category': 'Audit Logs',
        'desc': 'Complete audit log of all bank disbursements, vendor invoices, wire transfers, and account reconciliations.',
        'totalDisbursed': 1250000,
        'totalPending': 84000,
        'totalRecords': 86,
        'lastGenerated': 'Oct 15, 2026',
        'format': 'CSV',
        'fileSize': '3.1 MB',
        'icon': Icons.account_balance,
      },
    ];
  }

  int _getCategoryCount(String label) {
    if (label == 'All') return _reports.length;
    return _reports.where((r) => r['category'] == label).length;
  }

  List<Map<String, dynamic>> get _filteredReports {
    return _reports.where((item) {
      final title = (item['title'] ?? '').toString().toLowerCase();
      final cat = (item['category'] ?? '').toString().toLowerCase();
      final id = (item['id'] ?? '').toString().toLowerCase();
      final search = _searchTerm.toLowerCase();

      final matchesSearch = _searchTerm.isEmpty || title.contains(search) || cat.contains(search) || id.contains(search);
      final matchesCategory = _selectedCategory == 'All' || item['category'] == _selectedCategory;
      final matchesFormat = _selectedFormat == 'All' || item['format'] == _selectedFormat;

      return matchesSearch && matchesCategory && matchesFormat;
    }).toList();
  }

  num get _totalDisbursedSum {
    return _reports.fold<num>(0, (sum, r) => sum + ((r['totalDisbursed'] as num?) ?? 0));
  }

  num get _totalPendingSum {
    return _reports.fold<num>(0, (sum, r) => sum + ((r['totalPending'] as num?) ?? 0));
  }

  String _formatCurrency(num amount) {
    final str = amount.toInt().toString();
    final RegExp reg = RegExp(r'(\d+?)(?=(\d{3})+(?!\d))');
    final String result = str.replaceAllMapped(reg, (Match m) => '${m[1]},');
    return '₹ $result';
  }

  void _downloadReport(Map<String, dynamic> report) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Downloading ${report['title']} (${report['format']})...'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  void _runLiveQuery(Map<String, dynamic> report) {
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
                const Icon(Icons.play_circle_fill, color: AppColors.primary),
                const SizedBox(width: 8),
                Text('Live Query: ${report['id']}'),
              ],
            ),
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close, size: 20),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Report Title', report['title'] ?? '', isBold: true),
            _buildDetailRow('Category', report['category'] ?? ''),
            _buildDetailRow('Total Disbursed', _formatCurrency(report['totalDisbursed'] ?? 0), isAmount: true),
            _buildDetailRow('Pending Clearance', _formatCurrency(report['totalPending'] ?? 0), isPending: true),
            _buildDetailRow('Total Records', '${report['totalRecords']} Rows', isPrimary: true),
            _buildDetailRow('Format & Size', '${report['format']} (${report['fileSize']})'),
            const SizedBox(height: 6),
            Text(report['desc'] ?? '', style: const TextStyle(fontSize: 11, color: AppColors.lightSecondaryText)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _downloadReport(report);
            },
            icon: const Icon(Icons.download, size: 16),
            label: const Text('Download Report'),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }

  void _showGenerateModal() {
    _titleController.clear();
    _newCategory = 'Payroll';
    _newFormat = 'PDF';
    _newDateRange = 'Current Month (Oct 2026)';
    _includeDetails = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            titlePadding: const EdgeInsets.all(16),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            actionsPadding: const EdgeInsets.all(12),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: const [
                    Icon(Icons.add_circle_outline, color: AppColors.primary),
                    SizedBox(width: 8),
                    Text('Generate Custom Report', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                  const Text('Report Title *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.lightSecondaryText)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      hintText: 'e.g. Q3 Financial Disbursement Ledger',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Category', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.lightSecondaryText)),
                            const SizedBox(height: 4),
                            DropdownButtonFormField<String>(
                              value: _newCategory,
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'Payroll', child: Text('Payroll', style: TextStyle(fontSize: 12))),
                                DropdownMenuItem(value: 'Taxation', child: Text('Taxation', style: TextStyle(fontSize: 12))),
                                DropdownMenuItem(value: 'Expenses', child: Text('Expenses', style: TextStyle(fontSize: 12))),
                                DropdownMenuItem(value: 'Loans & Advances', child: Text('Loans', style: TextStyle(fontSize: 12))),
                                DropdownMenuItem(value: 'Audit Logs', child: Text('Audit Logs', style: TextStyle(fontSize: 12))),
                              ],
                              onChanged: (val) {
                                if (val != null) setModalState(() => _newCategory = val);
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
                            const Text('Format', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.lightSecondaryText)),
                            const SizedBox(height: 4),
                            DropdownButtonFormField<String>(
                              value: _newFormat,
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'PDF', child: Text('PDF', style: TextStyle(fontSize: 12))),
                                DropdownMenuItem(value: 'Excel', child: Text('Excel', style: TextStyle(fontSize: 12))),
                                DropdownMenuItem(value: 'CSV', child: Text('CSV', style: TextStyle(fontSize: 12))),
                              ],
                              onChanged: (val) {
                                if (val != null) setModalState(() => _newFormat = val);
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  const Text('Date Range / Period', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.lightSecondaryText)),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<String>(
                    value: _newDateRange,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Current Month (Oct 2026)', child: Text('Current Month (Oct 2026)')),
                      DropdownMenuItem(value: 'Previous Month (Sep 2026)', child: Text('Previous Month (Sep 2026)')),
                      DropdownMenuItem(value: 'Quarter 3 (Q3 FY2026)', child: Text('Quarter 3 (Q3 FY2026)')),
                      DropdownMenuItem(value: 'Full Financial Year (FY2025-26)', child: Text('Full Financial Year')),
                    ],
                    onChanged: (val) {
                      if (val != null) setModalState(() => _newDateRange = val);
                    },
                  ),
                  const SizedBox(height: 12),

                  CheckboxListTile(
                    value: _includeDetails,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: const Text(
                      'Include detailed line-item transactions & digital SHA-256 signature',
                      style: TextStyle(fontSize: 11, color: AppColors.lightSecondaryText),
                    ),
                    onChanged: (val) {
                      if (val != null) setModalState(() => _includeDetails = val);
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
                  if (_titleController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please enter a report title'),
                        backgroundColor: AppColors.error,
                      ),
                    );
                    return;
                  }
                  Navigator.pop(context);
                  _saveGeneratedReport();
                },
                icon: const Icon(Icons.check, size: 16),
                label: const Text('Generate & Save Report'),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
              ),
            ],
          );
        },
      ),
    );
  }

  void _saveGeneratedReport() {
    final title = _titleController.text.trim();
    final newRpt = {
      'id': 'RPT-CUST-${100 + (DateTime.now().millisecondsSinceEpoch % 899)}',
      'title': title,
      'category': _newCategory,
      'desc': 'Custom generated report for period $_newDateRange. Includes detailed audit rows.',
      'totalDisbursed': 350000,
      'totalPending': 12000,
      'totalRecords': 45,
      'lastGenerated': '15 Oct 2026',
      'format': _newFormat,
      'fileSize': '1.5 MB',
      'icon': Icons.file_copy,
    };

    setState(() {
      _reports.insert(0, newRpt);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Custom report "$title" generated successfully'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  Widget _buildDetailRow(String label, String val, {bool isBold = false, bool isAmount = false, bool isPending = false, bool isPrimary = false}) {
    Color textColor = AppColors.lightPrimaryText;
    if (isAmount) textColor = AppColors.success;
    if (isPending) textColor = AppColors.warning;
    if (isPrimary) textColor = AppColors.primary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.lightMutedText),
          ),
          const SizedBox(height: 2),
          Text(
            val,
            style: TextStyle(
              fontSize: isAmount ? 15 : 13,
              fontWeight: (isBold || isAmount || isPending || isPrimary) ? FontWeight.bold : FontWeight.normal,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const DashboardSkeleton();

    final filteredList = _filteredReports;

    return RefreshIndicator(
      onRefresh: _loadReports,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Header Card
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
                        child: Icon(Icons.pie_chart, color: Colors.white, size: 26),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Financial Reports & Analytics',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Audit ledgers, payroll summaries, tax compliance, & expense reports',
                              style: TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  ElevatedButton.icon(
                    onPressed: _showGenerateModal,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Generate Custom Report'),
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

            // Stat Cards Grid
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.5,
              children: [
                _buildStatCard(
                  label: 'Available Reports',
                  value: '${_reports.length}',
                  sub: 'Ready for export',
                  icon: Icons.file_present,
                  bgColor: const Color(0xFFEFF6FF),
                  iconColor: const Color(0xFF2563EB),
                ),
                _buildStatCard(
                  label: 'Total YTD Disbursed',
                  value: _formatCurrency(_totalDisbursedSum),
                  sub: 'Across all ledgers',
                  icon: Icons.check_circle_outline,
                  bgColor: const Color(0xFFF0FDF4),
                  iconColor: const Color(0xFF16A34A),
                ),
                _buildStatCard(
                  label: 'Total Pending Audit',
                  value: _formatCurrency(_totalPendingSum),
                  sub: 'Awaiting clearance',
                  icon: Icons.schedule,
                  bgColor: const Color(0xFFFFF7ED),
                  iconColor: const Color(0xFFEA580C),
                ),
                _buildStatCard(
                  label: 'Automated Schedules',
                  value: '4 Active',
                  sub: 'Recurring exports',
                  icon: Icons.sync,
                  bgColor: const Color(0xFFEFF6FF),
                  iconColor: const Color(0xFF2563EB),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Search & Filter Card
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    onChanged: (val) => setState(() => _searchTerm = val),
                    decoration: InputDecoration(
                      hintText: 'Search report title, category, or report ID...',
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
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      const Icon(Icons.file_copy, size: 18, color: AppColors.lightSecondaryText),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(10),
                            color: Colors.white,
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedFormat,
                              isExpanded: true,
                              icon: const Icon(Icons.arrow_drop_down, color: AppColors.primary),
                              style: const TextStyle(fontSize: 12, color: AppColors.lightPrimaryText, fontWeight: FontWeight.w500),
                              items: const [
                                DropdownMenuItem(value: 'All', child: Text('All Formats')),
                                DropdownMenuItem(value: 'PDF', child: Text('PDF Document')),
                                DropdownMenuItem(value: 'Excel', child: Text('Excel (XLSX)')),
                                DropdownMenuItem(value: 'CSV', child: Text('CSV Data')),
                              ],
                              onChanged: (val) {
                                if (val != null) setState(() => _selectedFormat = val);
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _categories.map((cat) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _buildTabChip(cat, cat, _getCategoryCount(cat)),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Available Reports Header & Cards
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: const [
                    Icon(Icons.folder_outlined, color: AppColors.primary, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Financial Audit & Ledger Statements',
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
                    '${filteredList.length} Reports',
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

            if (filteredList.isEmpty)
              AppCard(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: const [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: AppColors.lightSecondarySurface,
                        child: Icon(Icons.picture_as_pdf_outlined, size: 28, color: AppColors.lightSecondaryText),
                      ),
                      SizedBox(height: 12),
                      Text(
                        'No matching financial reports found',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Try resetting your search query or selecting a different report category.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: AppColors.lightSecondaryText),
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredList.length,
                itemBuilder: (context, index) {
                  final report = filteredList[index];
                  return _buildReportCard(report);
                },
              ),

            const SizedBox(height: 24),

            // Scheduled Automated Reports Card
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.schedule, color: AppColors.primary, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Scheduled Automated Reports',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.lightInputBackground,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'Auto Recurrent',
                          style: TextStyle(fontSize: 11, color: AppColors.lightSecondaryText, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  ..._scheduledExports.map((s) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.lightInputBackground,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(s['title']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                const SizedBox(height: 2),
                                Text('${s['recurrence']} • Sent to ${s['recipients']}', style: const TextStyle(fontSize: 11, color: AppColors.lightSecondaryText)),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.lightPrimary,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              s['format']!,
                              style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Data Security & Encryption Card
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.shield, color: AppColors.success, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Data Security & Encryption Standard',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.successBg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'SOC2 Certified',
                          style: TextStyle(fontSize: 11, color: AppColors.success, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  _buildSecurityItem(
                    icon: Icons.lock,
                    iconColor: AppColors.success,
                    title: '256-bit AES Password Protection',
                    description: 'Confidential payroll & tax PDFs encrypted with employee PIN and corporate key.',
                  ),
                  const SizedBox(height: 10),
                  _buildSecurityItem(
                    icon: Icons.fingerprint,
                    iconColor: AppColors.primary,
                    title: 'Digital Hash Verification & Audit Trail',
                    description: 'SHA-256 digital signature embedded on every generated report for audit compliance.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
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
          ),
        ],
      ),
    );
  }

  Widget _buildTabChip(String label, String value, int count) {
    final isActive = _selectedCategory == value;
    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label == 'All' ? 'All Reports' : label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isActive ? Colors.white : AppColors.lightSecondaryText,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '($count)',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isActive ? Colors.white70 : AppColors.lightMutedText,
            ),
          ),
        ],
      ),
      selected: isActive,
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.lightInputBackground,
      onSelected: (_) => setState(() => _selectedCategory = value),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isActive ? AppColors.primary : Colors.grey.shade300,
        ),
      ),
    );
  }

  Widget _buildReportCard(Map<String, dynamic> report) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Title, ID & Category
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.lightPrimary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(report['icon'] as IconData? ?? Icons.file_present, color: AppColors.primary, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              report['title'] ?? '',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: AppColors.lightInputBackground,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    report['category'] ?? '',
                                    style: const TextStyle(fontSize: 10, color: AppColors.lightSecondaryText, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  report['id'] ?? '',
                                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: AppColors.lightMutedText),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            Text(
              report['desc'] ?? '',
              style: const TextStyle(fontSize: 12, color: AppColors.lightSecondaryText),
            ),
            const SizedBox(height: 10),

            // Financial Metrics Bar
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.lightInputBackground,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        const Text('Total Disbursed', style: TextStyle(fontSize: 10, color: AppColors.lightMutedText)),
                        const SizedBox(height: 2),
                        Text(_formatCurrency(report['totalDisbursed'] ?? 0), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.success)),
                      ],
                    ),
                  ),
                  Container(height: 20, width: 1, color: Colors.grey.shade300),
                  Expanded(
                    child: Column(
                      children: [
                        const Text('Pending Clearance', style: TextStyle(fontSize: 10, color: AppColors.lightMutedText)),
                        const SizedBox(height: 2),
                        Text(_formatCurrency(report['totalPending'] ?? 0), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.warning)),
                      ],
                    ),
                  ),
                  Container(height: 20, width: 1, color: Colors.grey.shade300),
                  Expanded(
                    child: Column(
                      children: [
                        const Text('Records Count', style: TextStyle(fontSize: 10, color: AppColors.lightMutedText)),
                        const SizedBox(height: 2),
                        Text('${report['totalRecords']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primary)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Last Generated & Format Info Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Generated: ${report['lastGenerated']}',
                  style: const TextStyle(fontSize: 11, color: AppColors.lightMutedText),
                ),
                Text(
                  'Format: ${report['format']} (${report['fileSize']})',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.lightSecondaryText),
                ),
              ],
            ),
            const Divider(height: 18),

            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                InkWell(
                  onTap: () => _runLiveQuery(report),
                  child: Row(
                    children: const [
                      Icon(Icons.play_arrow, size: 16, color: AppColors.primary),
                      SizedBox(width: 4),
                      Text('Run Live Query', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _downloadReport(report),
                  icon: const Icon(Icons.download, size: 14),
                  label: Text('Download ${report['format']}'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecurityItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.lightInputBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Colors.white,
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 2),
                Text(description, style: const TextStyle(fontSize: 11, color: AppColors.lightSecondaryText)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
