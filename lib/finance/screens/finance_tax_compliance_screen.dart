import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_header.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/loading_shimmer.dart';

class FinanceTaxComplianceScreen extends ConsumerStatefulWidget {
  final bool? showAppBar;
  const FinanceTaxComplianceScreen({super.key, this.showAppBar = false});

  @override
  ConsumerState<FinanceTaxComplianceScreen> createState() => _FinanceTaxComplianceScreenState();
}

class _FinanceTaxComplianceScreenState extends ConsumerState<FinanceTaxComplianceScreen> {
  String _searchTerm = '';
  String _selectedCategory = 'All'; // 'All', 'Payroll TDS', 'Statutory PF/ESI', 'GST', 'Income Tax'
  String _selectedStatus = 'All'; // 'All', 'Filed & Certified', 'Upcoming', 'Pending Clearance'
  bool _isLoading = true;

  List<Map<String, dynamic>> _taxRecords = [];

  // File Tax Form Controllers
  final TextEditingController _periodController = TextEditingController(text: 'Q3 - FY 2025-26');
  final TextEditingController _formTypeController = TextEditingController(text: 'Form 24Q (Payroll TDS)');
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _ackRefController = TextEditingController();
  String _category = 'Payroll TDS';
  String _dueDate = '2026-11-11';

  final List<String> _categories = [
    'All',
    'Payroll TDS',
    'Statutory PF/ESI',
    'GST',
    'Income Tax',
  ];

  final List<Map<String, dynamic>> _upcomingDeadlines = [
    {
      'title': 'Form 24Q Quarterly TDS Return',
      'date': 'Oct 31, 2026',
      'tag': 'Statutory',
      'color': const Color(0xFFD97706),
      'bg': const Color(0x1FF59E0B),
    },
    {
      'title': 'EPF & ESI Monthly Deposit',
      'date': 'Nov 15, 2026',
      'tag': 'Monthly',
      'color': const Color(0xFF2563EB),
      'bg': const Color(0x1F2563EB),
    },
    {
      'title': 'GST-3B Monthly Return Filing',
      'date': 'Nov 20, 2026',
      'tag': 'Tax Deposit',
      'color': const Color(0xFF2563EB),
      'bg': const Color(0x1F2563EB),
    },
    {
      'title': 'Form 16 Part A & B Issuance',
      'date': 'Dec 15, 2026',
      'tag': 'Annual',
      'color': const Color(0xFF059669),
      'bg': const Color(0x1F10B981),
    },
  ];

  final List<Map<String, dynamic>> _complianceChecklist = [
    {'name': 'Payroll TDS Form 24Q (Q2)', 'completed': true, 'date': 'Filed Oct 14'},
    {'name': 'PF Monthly ECR & Challan Submission', 'completed': true, 'date': 'Filed Oct 10'},
    {'name': 'ESI Monthly Return & Challan Payment', 'completed': true, 'date': 'Filed Oct 12'},
    {'name': 'Form 16 Part A & B Certificates', 'completed': true, 'date': 'Active FY2026'},
    {'name': 'GSTR-3B Tax Filing Audit', 'completed': false, 'date': 'Due Nov 20'},
    {'name': 'Professional Tax (PT) Deposit', 'completed': false, 'date': 'Due Nov 30'},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadTaxRecords();
    });
  }

  @override
  void dispose() {
    _periodController.dispose();
    _formTypeController.dispose();
    _amountController.dispose();
    _ackRefController.dispose();
    super.dispose();
  }

  Future<void> _loadTaxRecords() async {
    setState(() => _isLoading = true);
    final apiClient = ref.read(apiClientProvider);

    try {
      final res = await apiClient.get(ApiEndpoints.financeTax).catchError((_) => null);

      if (mounted) {
        if (res != null) {
          List<dynamic> items = [];
          if (res is List) {
            items = res;
          } else if (res is Map<String, dynamic>) {
            final data = res['data'] ?? res['items'] ?? res['result'] ?? res['tax'];
            if (data is List) {
              items = data;
            }
          }

          _taxRecords = items.map((t) => _mapTaxItem(t)).toList();
        } else {
          _taxRecords = [];
        }
        _isLoading = false;
        setState(() {});
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _taxRecords = [];
          _isLoading = false;
        });
      }
    }
  }

  Map<String, dynamic> _mapTaxItem(dynamic t) {
    final Map<String, dynamic> map = t is Map<String, dynamic> ? t : {};
    final rawStatus = (map['status'] ?? 'Pending').toString();
    final isFiled = rawStatus.toUpperCase() == 'FILED' || rawStatus.toUpperCase() == 'FILED & CERTIFIED' || rawStatus.toUpperCase() == 'PAID';

    return {
      'id': map['id']?.toString() ?? 'TAX-8222',
      'filingPeriod': map['filingPeriod'] ?? map['financialYear'] ?? 'Q3 - FY 2025-26',
      'type': map['formName'] ?? map['type'] ?? map['regime'] ?? 'Form 24Q (Payroll TDS)',
      'category': map['category'] ?? 'Statutory PF/ESI',
      'amountDue': (map['amountTaxDue'] ?? map['taxPayable'] ?? map['amountDue'] ?? 0) as num,
      'amountPaid': (map['amountPaid'] ?? map['taxPaid'] ?? map['amountTaxDue'] ?? 0) as num,
      'dueDate': map['dueDate'] ?? '2026-11-11',
      'filingDate': map['filingDate'] ?? map['date'] ?? '-',
      'refNo': map['challanAckRef'] ?? map['refNo'] ?? map['panNumber'] ?? '-',
      'status': isFiled ? 'Filed & Certified' : 'Pending Clearance',
    };
  }

  int get _filedCount => _taxRecords.where((t) => t['status'] == 'Filed & Certified').length;
  int get _pendingCount => _taxRecords.where((t) => t['status'] != 'Filed & Certified').length;

  num get _totalDeposited {
    return _taxRecords.fold<num>(0, (sum, t) => sum + ((t['amountPaid'] as num?) ?? 0));
  }

  int _getStatusCount(String label) {
    if (label == 'All') return _taxRecords.length;
    if (label == 'Filed & Certified') return _filedCount;
    if (label == 'Pending Clearance') return _pendingCount;
    if (label == 'Upcoming') return 0;
    return 0;
  }

  List<Map<String, dynamic>> get _filteredRecords {
    return _taxRecords.where((item) {
      final period = (item['filingPeriod'] ?? '').toString().toLowerCase();
      final type = (item['type'] ?? '').toString().toLowerCase();
      final refNo = (item['refNo'] ?? '').toString().toLowerCase();
      final search = _searchTerm.toLowerCase();

      final matchesSearch = _searchTerm.isEmpty || period.contains(search) || type.contains(search) || refNo.contains(search);
      final matchesCategory = _selectedCategory == 'All' || item['category'].toString().toLowerCase().contains(_selectedCategory.toLowerCase());
      final matchesStatus = _selectedStatus == 'All' || item['status'] == _selectedStatus;

      return matchesSearch && matchesCategory && matchesStatus;
    }).toList();
  }

  String _formatCurrency(num amount) {
    final str = amount.toInt().toString();
    final RegExp reg = RegExp(r'(\d+?)(?=(\d{3})+(?!\d))');
    final String result = str.replaceAllMapped(reg, (Match m) => '${m[1]},');
    return '₹$result';
  }

  void _showFileTaxModal() {
    _amountController.clear();
    _ackRefController.clear();

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
                    Icon(Icons.gavel, color: AppColors.primary),
                    SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('File Tax Return / Challan', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                        Text('Record new statutory tax return or challan deposit', style: TextStyle(fontSize: 11, color: AppColors.lightSecondaryText)),
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
                            const Text('Filing Period *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.lightSecondaryText)),
                            const SizedBox(height: 4),
                            TextField(
                              controller: _periodController,
                              decoration: InputDecoration(
                                hintText: 'Q3 - FY 2025-26',
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                            const Text('Tax Category', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.lightSecondaryText)),
                            const SizedBox(height: 4),
                            DropdownButtonFormField<String>(
                              value: _category,
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'Payroll TDS', child: Text('Payroll TDS', style: TextStyle(fontSize: 11))),
                                DropdownMenuItem(value: 'Statutory PF/ESI', child: Text('PF / ESI', style: TextStyle(fontSize: 11))),
                                DropdownMenuItem(value: 'GST', child: Text('GST', style: TextStyle(fontSize: 11))),
                                DropdownMenuItem(value: 'Income Tax', child: Text('Income Tax', style: TextStyle(fontSize: 11))),
                              ],
                              onChanged: (val) {
                                if (val != null) setModalState(() => _category = val);
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  const Text('Form / Component Name', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.lightSecondaryText)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _formTypeController,
                    decoration: InputDecoration(
                      hintText: 'e.g. Form 24Q (Payroll TDS)',
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
                            const Text('Amount Tax Due (₹) *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.lightSecondaryText)),
                            const SizedBox(height: 4),
                            TextField(
                              controller: _amountController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                hintText: '5025',
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                            const Text('Due Date *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.lightSecondaryText)),
                            const SizedBox(height: 4),
                            TextField(
                              controller: TextEditingController(text: _dueDate),
                              onChanged: (v) => _dueDate = v,
                              decoration: InputDecoration(
                                hintText: '2026-11-11',
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

                  const Text('Challan / Acknowledgement Ref No.', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.lightSecondaryText)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _ackRefController,
                    decoration: InputDecoration(
                      hintText: 'e.g. ACK-2026-99120',
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
                  if (_amountController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please enter amount tax due'),
                        backgroundColor: AppColors.error,
                      ),
                    );
                    return;
                  }
                  Navigator.pop(context);
                  _submitTaxReturn();
                },
                icon: const Icon(Icons.check, size: 16),
                label: const Text('Submit Tax Return'),
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

  Future<void> _submitTaxReturn() async {
    final amount = num.tryParse(_amountController.text.trim()) ?? 0;

    final apiClient = ref.read(apiClientProvider);

    try {
      await apiClient.post(ApiEndpoints.financeTax, data: {
        'filingPeriod': _periodController.text.trim(),
        'category': _category,
        'formName': _formTypeController.text.trim(),
        'amountTaxDue': amount,
        'dueDate': _dueDate,
        'challanAckRef': _ackRefController.text.trim(),
      }).catchError((_) => null);

      if (mounted) {
        _loadTaxRecords();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tax Return / Challan submitted successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (_) {}
  }

  void _viewTaxDetails(Map<String, dynamic> item) {
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
                const Icon(Icons.info_outline, color: AppColors.primary),
                const SizedBox(width: 8),
                Text('Tax Record Details: ${item['id']}'),
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
            _buildDetailRow('Filing Period', item['filingPeriod'] ?? '', isBold: true),
            _buildDetailRow('Form / Component', item['type'] ?? ''),
            _buildDetailRow('Category', item['category'] ?? ''),
            _buildDetailRow('Amount Tax Due', _formatCurrency(item['amountDue'] ?? 0), isAmount: true),
            _buildDetailRow('Amount Paid', _formatCurrency(item['amountPaid'] ?? 0), isPrimary: true),
            _buildDetailRow('Due Date', item['dueDate'] ?? ''),
            _buildDetailRow('Filing Date', item['filingDate'] ?? ''),
            _buildDetailRow('Challan ACK Ref', item['refNo'] ?? ''),
            _buildDetailRow('Filing Status', item['status'] ?? ''),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String val, {bool isBold = false, bool isAmount = false, bool isPrimary = false}) {
    Color textColor = AppColors.lightPrimaryText;
    if (isAmount) textColor = AppColors.error;
    if (isPrimary) textColor = AppColors.success;

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
              fontWeight: (isBold || isAmount || isPrimary) ? FontWeight.bold : FontWeight.normal,
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

  Widget _buildTabChip(String label, String value, int count) {
    final isActive = _selectedStatus == value;
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
        onSelected: (_) => setState(() => _selectedStatus = value),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isActive ? AppColors.primary : Colors.grey.shade300,
          ),
        ),
      ),
    );
  }

  Widget _buildTaxCard(Map<String, dynamic> item) {
    final isFiled = item['status'] == 'Filed & Certified';

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
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.lightInputBackground,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    item['filingPeriod'] ?? '',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isFiled ? AppColors.successBg : AppColors.warningBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isFiled ? 'Filed & Certified' : 'Pending Clearance',
                  style: TextStyle(color: isFiled ? AppColors.success : AppColors.warning, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(item['type'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 2),
          Text('Category: ${item['category']}', style: const TextStyle(fontSize: 11, color: AppColors.lightSecondaryText)),
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
                _buildMetricColumn('Tax Due', _formatCurrency(item['amountDue'] ?? 0), AppColors.primary),
                _buildMetricColumn('Filing Date', item['filingDate'] ?? '-', Colors.black87),
                _buildMetricColumn('Challan Ref', item['refNo'] ?? '-', AppColors.success),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Due Date: ${item['dueDate']}',
                  style: const TextStyle(fontSize: 11, color: AppColors.lightMutedText),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _viewTaxDetails(item),
                icon: const Icon(Icons.visibility_outlined, size: 14),
                label: const Text('Challan'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  textStyle: const TextStyle(fontSize: 11),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
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
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: AppColors.lightSecondaryText),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
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

    final filteredList = _filteredRecords;
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
                Tab(text: 'Tax Returns Ledger'),
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
                                  child: Icon(Icons.gavel, color: Colors.white, size: 26),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: const [
                                      Text(
                                        'Tax & Statutory Compliance',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        'Monitor Income Tax (TDS), PF/ESI statutory contributions, GST filings, & Form 16',
                                        style: TextStyle(color: Colors.white70, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _showFileTaxModal,
                              icon: const Icon(Icons.description, size: 16),
                              label: const Text('File Tax Return / Challan'),
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
                            label: 'Total Statutory Filings',
                            value: '${_taxRecords.length}',
                            sub: 'Active tax records',
                            icon: Icons.assignment_outlined,
                            bgColor: const Color(0xFFFFF7ED),
                            iconColor: const Color(0xFFEA580C),
                          ),
                          _buildStatCard(
                            label: 'Filed & Certified',
                            value: '$_filedCount',
                            sub: 'Successfully filed',
                            icon: Icons.check_circle_outline,
                            bgColor: const Color(0xFFF0FDF4),
                            iconColor: const Color(0xFF16A34A),
                          ),
                          _buildStatCard(
                            label: 'Pending / Upcoming',
                            value: '$_pendingCount',
                            sub: 'Awaiting submission',
                            icon: Icons.error_outline,
                            bgColor: const Color(0xFFFFF7ED),
                            iconColor: const Color(0xFFEA580C),
                          ),
                          _buildStatCard(
                            label: 'Total Tax Deposited',
                            value: _formatCurrency(_totalDeposited),
                            sub: 'YTD Statutory payout',
                            icon: Icons.shield_outlined,
                            bgColor: const Color(0xFFEFF6FF),
                            iconColor: const Color(0xFF2563EB),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Upcoming Deadlines Card
                      AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: const [
                                    Icon(Icons.calendar_month, color: AppColors.primary, size: 18),
                                    SizedBox(width: 8),
                                    Text('Upcoming Statutory Deadlines', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  ],
                                ),
                                const Text('Q3 & Q4 Filings', style: TextStyle(fontSize: 11, color: AppColors.lightSecondaryText)),
                              ],
                            ),
                            const Divider(height: 20),
                            ..._upcomingDeadlines.map((item) {
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
                                          Text(item['title'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                          const SizedBox(height: 2),
                                          Row(
                                            children: [
                                              const Icon(Icons.schedule, size: 12, color: AppColors.lightSecondaryText),
                                              const SizedBox(width: 4),
                                              Text('Due: ${item['date']}', style: const TextStyle(fontSize: 11, color: AppColors.lightSecondaryText)),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: item['bg'] as Color,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        item['tag'] as String,
                                        style: TextStyle(color: item['color'] as Color, fontSize: 10, fontWeight: FontWeight.bold),
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

                      // Audit Checklist Card
                      AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: const [
                                    Icon(Icons.playlist_add_check_circle, color: AppColors.primary, size: 18),
                                    SizedBox(width: 8),
                                    Text('Compliance & Form 16 Audit Checklist', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppColors.successBg,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text('Audit Ready', style: TextStyle(color: AppColors.success, fontSize: 10, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                            const Divider(height: 20),
                            ..._complianceChecklist.map((chk) {
                              final bool done = chk['completed'] as bool;
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                child: Row(
                                  children: [
                                    Icon(
                                      done ? Icons.check_circle : Icons.hourglass_top,
                                      size: 16,
                                      color: done ? AppColors.primary : AppColors.warning,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        chk['name'] as String,
                                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                                      ),
                                    ),
                                    Text(
                                      chk['date'] as String,
                                      style: TextStyle(fontSize: 11, color: done ? AppColors.lightSecondaryText : AppColors.warning, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Tab 2: Tax Returns Ledger
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
                                hintText: 'Search filing period, tax component, or ACK ref...',
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
                                const Icon(Icons.filter_list, size: 18, color: AppColors.lightSecondaryText),
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
                                        value: _selectedCategory,
                                        isExpanded: true,
                                        icon: const Icon(Icons.arrow_drop_down, color: AppColors.primary),
                                        style: const TextStyle(fontSize: 12, color: AppColors.lightPrimaryText, fontWeight: FontWeight.w500),
                                        items: _categories.map((c) {
                                          return DropdownMenuItem<String>(
                                            value: c,
                                            child: Text(c == 'All' ? 'All Tax Categories' : c),
                                          );
                                        }).toList(),
                                        onChanged: (val) {
                                          if (val != null) setState(() => _selectedCategory = val);
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
                                  _buildTabChip('All Returns', 'All', _getStatusCount('All')),
                                  const SizedBox(width: 8),
                                  _buildTabChip('Filed & Certified', 'Filed & Certified', _filedCount),
                                  const SizedBox(width: 8),
                                  _buildTabChip('Upcoming', 'Upcoming', 0),
                                  const SizedBox(width: 8),
                                  _buildTabChip('Pending Clearance', 'Pending Clearance', _pendingCount),
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
                                    'Statutory Tax Returns & Challan History',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
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
                              '${filteredList.length} Filings',
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
                                  child: Icon(Icons.assignment_outlined, size: 28, color: AppColors.lightSecondaryText),
                                ),
                                SizedBox(height: 12),
                                Text(
                                  'No tax filing records found',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Try clearing or modifying your search and filter parameters.',
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
                            return _buildTaxCard(item);
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
      appBar: const GlassHeader(title: 'Tax & Compliance'),
      showBottomBar: false,
      body: content,
    );
  }
}
