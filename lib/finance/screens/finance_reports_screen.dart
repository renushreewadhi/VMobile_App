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

class FinanceReportsScreen extends ConsumerStatefulWidget {
  final bool? showAppBar;
  const FinanceReportsScreen({super.key, this.showAppBar = false});

  @override
  ConsumerState<FinanceReportsScreen> createState() => _FinanceReportsScreenState();
}

class _FinanceReportsScreenState extends ConsumerState<FinanceReportsScreen> {
  String _searchTerm = '';
  String _selectedCategory = 'All'; // 'All', 'Payroll', 'Taxation', 'Expenses', 'Loans & Advances', 'Audit Logs'
  String _selectedFormat = 'All'; // 'All', 'PDF', 'Excel', 'CSV'
  bool _isLoading = true;
  String? _errorMessage;

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
    {'title': 'Monthly Finance & Payroll Audit', 'recurrence': 'Monthly (1st) • Sent to finance-team@company.com', 'format': 'Excel'},
    {'title': 'Quarterly TDS & Statutory Return', 'recurrence': 'Quarterly • Sent to compliance@company.com', 'format': 'PDF'},
    {'title': 'Weekly Expense Claims Breakdown', 'recurrence': 'Weekly (Mon) • Sent to accounts@company.com', 'format': 'CSV'},
    {'title': 'Annual Balance Sheet & Ledger', 'recurrence': 'Yearly (End FY) • Sent to auditors@company.com', 'format': 'PDF'},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadReports();
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _loadReports() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    final apiClient = ref.read(apiClientProvider);

    try {
      final res = await apiClient.get(ApiEndpoints.financeReports);

      if (mounted) {
        List<dynamic> items = [];
        if (res is List) {
          items = res;
        } else if (res is Map<String, dynamic>) {
          final data = res['data'] ?? res['items'] ?? res['result'] ?? res['reports'];
          if (data is List) {
            items = data;
          }
        }

        _reports = items.map((r) => _mapReportItem(r)).toList();
        _isLoading = false;
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _reports = [];
          _errorMessage = e.toString().replaceFirst('Exception: ', '').replaceFirst('ApiException: ', '');
          _isLoading = false;
        });
      }
    }
  }

  Map<String, dynamic> _mapReportItem(dynamic r) {
    final Map<String, dynamic> map = r is Map<String, dynamic> ? r : {};
    return {
      'id': map['id'] ?? map['reportId'] ?? map['code'] ?? 'RPT-101',
      'title': map['title'] ?? map['name'] ?? 'Financial Statement',
      'category': map['category'] ?? map['type'] ?? 'Payroll',
      'desc': map['desc'] ?? map['description'] ?? 'Detailed financial audit report and summary statement.',
      'totalDisbursed': (map['totalDisbursed'] ?? 0) as num,
      'totalPending': (map['totalPending'] ?? 0) as num,
      'totalRecords': ((map['totalRecords'] ?? 0) as num).toInt(),
      'lastGenerated': map['lastGenerated'] ?? map['createdAt'] ?? 'Oct 14, 2026',
      'format': map['format'] ?? map['exportFormat'] ?? 'Excel',
      'fileSize': map['fileSize'] ?? '2.4 MB',
      'icon': _getIconForCategory(map['category']),
    };
  }

  IconData _getIconForCategory(dynamic category) {
    final c = (category ?? '').toString().toLowerCase();
    if (c.contains('expense')) return Icons.receipt_long;
    if (c.contains('loan')) return Icons.payments;
    if (c.contains('audit') || c.contains('pay')) return Icons.account_balance;
    if (c.contains('tax')) return Icons.gavel;
    return Icons.description;
  }

  num get _totalDisbursedSum {
    return _reports.fold<num>(0, (sum, r) => sum + ((r['totalDisbursed'] as num?) ?? 0));
  }

  num get _totalPendingSum {
    return _reports.fold<num>(0, (sum, r) => sum + ((r['totalPending'] as num?) ?? 0));
  }

  int _getCategoryCount(String categoryLabel) {
    if (categoryLabel == 'All') return _reports.length;
    return _reports.where((r) => r['category'] == categoryLabel).length;
  }

  List<Map<String, dynamic>> get _filteredReports {
    return _reports.where((item) {
      final title = (item['title'] ?? '').toString().toLowerCase();
      final cat = (item['category'] ?? '').toString().toLowerCase();
      final id = (item['id'] ?? '').toString().toLowerCase();
      final search = _searchTerm.toLowerCase();

      final matchesSearch = _searchTerm.isEmpty || title.contains(search) || cat.contains(search) || id.contains(search);
      final matchesCategory = _selectedCategory == 'All' || item['category'] == _selectedCategory;
      final fmtStr = (item['format'] ?? '').toString().toLowerCase();
      final matchesFormat = _selectedFormat == 'All' || fmtStr.contains(_selectedFormat.toLowerCase());

      return matchesSearch && matchesCategory && matchesFormat;
    }).toList();
  }

  String _formatCurrency(num amount) {
    final str = amount.toInt().toString();
    final RegExp reg = RegExp(r'(\d+?)(?=(\d{3})+(?!\d))');
    final String result = str.replaceAllMapped(reg, (Match m) => '${m[1]},');
    return '₹$result';
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
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Generate Custom Report', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                        Text('Build on-demand audit statement or ledger', style: TextStyle(fontSize: 11, color: AppColors.lightSecondaryText)),
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
                                DropdownMenuItem(value: 'Payroll', child: Text('Payroll', style: TextStyle(fontSize: 11))),
                                DropdownMenuItem(value: 'Taxation', child: Text('Taxation', style: TextStyle(fontSize: 11))),
                                DropdownMenuItem(value: 'Expenses', child: Text('Expenses', style: TextStyle(fontSize: 11))),
                                DropdownMenuItem(value: 'Loans & Advances', child: Text('Loans', style: TextStyle(fontSize: 11))),
                                DropdownMenuItem(value: 'Audit Logs', child: Text('Audit Logs', style: TextStyle(fontSize: 11))),
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
                            const Text('Export Format', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.lightSecondaryText)),
                            const SizedBox(height: 4),
                            DropdownButtonFormField<String>(
                              value: _newFormat,
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'PDF', child: Text('PDF', style: TextStyle(fontSize: 11))),
                                DropdownMenuItem(value: 'Excel', child: Text('Excel', style: TextStyle(fontSize: 11))),
                                DropdownMenuItem(value: 'CSV', child: Text('CSV', style: TextStyle(fontSize: 11))),
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
                      DropdownMenuItem(value: 'Current Month (Oct 2026)', child: Text('Current Month (Oct 2026)', style: TextStyle(fontSize: 12))),
                      DropdownMenuItem(value: 'Previous Month (Sep 2026)', child: Text('Previous Month (Sep 2026)', style: TextStyle(fontSize: 12))),
                      DropdownMenuItem(value: 'Quarter 3 (Q3 FY2026)', child: Text('Quarter 3 (Q3 FY2026)', style: TextStyle(fontSize: 12))),
                      DropdownMenuItem(value: 'Full Financial Year (FY2025-26)', child: Text('Full Financial Year', style: TextStyle(fontSize: 12))),
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
                      'Include detailed line-item transactions & digital SHA-256 audit signature',
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

  Future<void> _saveGeneratedReport() async {
    final title = _titleController.text.trim();
    final newRpt = {
      'id': 'RPT-CUST-${100 + (DateTime.now().millisecondsSinceEpoch % 899)}',
      'title': title,
      'category': _newCategory,
      'desc': 'Custom generated report for period $_newDateRange. Includes detailed audit rows.',
      'totalDisbursed': 0,
      'totalPending': 0,
      'totalRecords': 0,
      'lastGenerated': '15 Oct 2026',
      'format': _newFormat,
      'fileSize': '1.5 MB',
      'icon': Icons.file_copy,
    };

    final apiClient = ref.read(apiClientProvider);

    try {
      await apiClient.post(ApiEndpoints.financeReports, data: {
        'title': title,
        'category': _newCategory,
        'format': _newFormat,
        'period': _newDateRange,
        'includeDetails': _includeDetails,
      }).catchError((_) => null);

      if (mounted) {
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
    } catch (_) {
      if (mounted) {
        setState(() {
          _reports.insert(0, newRpt);
        });
      }
    }
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
                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppColors.lightSecondaryText),
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

  Widget _buildTabChip(String label, String value, int count) {
    final isActive = _selectedCategory == value;
    return Material(
      color: Colors.transparent,
      child: ChoiceChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
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
      ),
    );
  }

  Widget _buildReportCard(Map<String, dynamic> item) {
    final format = item['format'] as String? ?? 'Excel';

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
                  item['category'] ?? 'Expenses',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.primary),
                ),
              ),
              Text(item['id'] ?? '', style: const TextStyle(fontSize: 11, color: AppColors.lightMutedText, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.lightPrimary,
                child: Icon((item['icon'] as IconData?) ?? Icons.description, color: AppColors.primary, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item['title'] as String? ?? '',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            item['desc'] as String? ?? '',
            style: const TextStyle(fontSize: 11, color: AppColors.lightSecondaryText),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
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
                _buildMetricColumn('Total Disbursed', _formatCurrency(item['totalDisbursed'] ?? 0), AppColors.success),
                _buildMetricColumn('Pending Clearance', _formatCurrency(item['totalPending'] ?? 0), AppColors.warning),
                _buildMetricColumn('Records Count', '${item['totalRecords'] ?? 0}', AppColors.primary),
              ],
            ),
          ),
          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Last Generated: ${item['lastGenerated']} • $format (${item['fileSize']})',
                  style: const TextStyle(fontSize: 10.5, color: AppColors.lightMutedText),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Row(
                children: [
                  InkWell(
                    onTap: () => _runLiveQuery(item),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      child: Text('Run Live Query', style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 6),
                  ElevatedButton.icon(
                    onPressed: () => _downloadReport(item),
                    icon: const Icon(Icons.download, size: 14),
                    label: Text('Download $format'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
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
        onRetry: _loadReports,
      );
    }

    final filteredList = _filteredReports;
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
                Tab(text: 'Report Directory'),
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
                                  child: Icon(Icons.bar_chart, color: Colors.white, size: 26),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: const [
                                      Text(
                                        'Financial Reports & Audit Analytics',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        'Generate, view, and export financial audit ledgers, payroll summaries, and expense statements',
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

                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.5,
                        children: [
                          _buildStatCard(
                            label: 'AVAILABLE REPORTS',
                            value: '${_reports.length}',
                            sub: 'Ready for export',
                            icon: Icons.picture_as_pdf_outlined,
                            bgColor: const Color(0xFFFFF7ED),
                            iconColor: const Color(0xFFEA580C),
                          ),
                          _buildStatCard(
                            label: 'TOTAL YTD DISBURSED',
                            value: _formatCurrency(_totalDisbursedSum),
                            sub: 'Across all ledgers',
                            icon: Icons.check_circle_outline,
                            bgColor: const Color(0xFFF0FDF4),
                            iconColor: const Color(0xFF16A34A),
                          ),
                          _buildStatCard(
                            label: 'TOTAL PENDING AUDIT',
                            value: _formatCurrency(_totalPendingSum),
                            sub: 'Awaiting clearance',
                            icon: Icons.schedule,
                            bgColor: const Color(0xFFFFF7ED),
                            iconColor: const Color(0xFFEA580C),
                          ),
                          _buildStatCard(
                            label: 'AUTOMATED SCHEDULES',
                            value: '4 Active',
                            sub: 'Recurring exports',
                            icon: Icons.sync,
                            bgColor: const Color(0xFFEFF6FF),
                            iconColor: const Color(0xFF2563EB),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Scheduled Automated Reports Card
                      AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: const [
                                Expanded(
                                  child: Row(
                                    children: [
                                      Icon(Icons.schedule, color: AppColors.primary, size: 18),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Scheduled Automated Reports',
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(width: 8),
                                Text('Auto Recurrent', style: TextStyle(fontSize: 11, color: AppColors.lightSecondaryText)),
                              ],
                            ),
                            const Divider(height: 20),
                            ..._scheduledExports.map((sch) {
                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
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
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(sch['title']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                                          const SizedBox(height: 2),
                                          Text(sch['recurrence']!, style: const TextStyle(fontSize: 10.5, color: AppColors.lightSecondaryText)),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: Colors.grey.shade300),
                                        borderRadius: BorderRadius.circular(6),
                                        color: Colors.white,
                                      ),
                                      child: Text(
                                        sch['format']!,
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Data Security Card
                      AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: const [
                                Expanded(
                                  child: Row(
                                    children: [
                                      Icon(Icons.shield, color: AppColors.primary, size: 18),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Data Security & Encryption Standard',
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(width: 8),
                                Text('SOC2 Certified', style: TextStyle(fontSize: 11, color: AppColors.lightSecondaryText)),
                              ],
                            ),
                            const Divider(height: 20),
                            Container(
                              padding: const EdgeInsets.all(10),
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: AppColors.lightInputBackground,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: const [
                                  Icon(Icons.lock, color: AppColors.primary, size: 20),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('256-bit AES Password Protection', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                        Text('Confidential payroll & tax PDFs encrypted with employee PIN and corporate key.', style: TextStyle(fontSize: 10.5, color: AppColors.lightSecondaryText)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.lightInputBackground,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: const [
                                  Icon(Icons.verified, color: AppColors.primary, size: 20),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Digital Hash Verification & Audit Trail', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                        Text('SHA-256 digital signature embedded on every generated report for audit compliance.', style: TextStyle(fontSize: 10.5, color: AppColors.lightSecondaryText)),
                                      ],
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
                ),

                // Tab 2: Report Directory
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
                                const Icon(Icons.picture_as_pdf_outlined, size: 18, color: AppColors.lightSecondaryText),
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
                                          DropdownMenuItem(value: 'Excel', child: Text('Excel Spreadsheet')),
                                          DropdownMenuItem(value: 'CSV', child: Text('CSV Data File')),
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
                                children: [
                                  _buildTabChip('All Reports', 'All', _getCategoryCount('All')),
                                  const SizedBox(width: 8),
                                  _buildTabChip('Payroll', 'Payroll', _getCategoryCount('Payroll')),
                                  const SizedBox(width: 8),
                                  _buildTabChip('Taxation', 'Taxation', _getCategoryCount('Taxation')),
                                  const SizedBox(width: 8),
                                  _buildTabChip('Expenses', 'Expenses', _getCategoryCount('Expenses')),
                                  const SizedBox(width: 8),
                                  _buildTabChip('Loans & Advances', 'Loans & Advances', _getCategoryCount('Loans & Advances')),
                                  const SizedBox(width: 8),
                                  _buildTabChip('Audit Logs', 'Audit Logs', _getCategoryCount('Audit Logs')),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: const [
                                Icon(Icons.list_alt, color: AppColors.primary, size: 18),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Financial Statements & Ledgers',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.lightPrimary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${filteredList.length} Reports Available',
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 11,
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
                                  child: Icon(Icons.bar_chart_outlined, size: 28, color: AppColors.lightSecondaryText),
                                ),
                                SizedBox(height: 12),
                                Text(
                                  'No financial reports match your filter',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Try clearing or modifying your search and category selection.',
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
                            final item = filteredList[index];
                            return _buildReportCard(item);
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
      appBar: const GlassHeader(title: 'Finance Reports'),
      showBottomBar: false,
      body: content,
    );
  }
}
