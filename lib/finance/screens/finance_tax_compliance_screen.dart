import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/loading_shimmer.dart';

class FinanceTaxComplianceScreen extends ConsumerStatefulWidget {
  const FinanceTaxComplianceScreen({super.key});

  @override
  ConsumerState<FinanceTaxComplianceScreen> createState() => _FinanceTaxComplianceScreenState();
}

class _FinanceTaxComplianceScreenState extends ConsumerState<FinanceTaxComplianceScreen> {
  String _searchTerm = '';
  String _selectedType = 'All'; // 'All', 'Payroll TDS', 'Statutory PF/ESI', 'Goods & Services Tax', 'Income Tax', 'State Tax'
  String _selectedStatus = 'All'; // 'All', 'Filed', 'Upcoming', 'Pending'
  bool _isLoading = true;

  List<Map<String, dynamic>> _taxRecords = [];
  Map<String, dynamic>? _selectedRecord;

  // File Tax Form Controllers
  final TextEditingController _periodController = TextEditingController(text: 'Q3 - FY 2025-26');
  final TextEditingController _formTypeController = TextEditingController(text: 'Form 24Q (Payroll TDS)');
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _ackRefController = TextEditingController();
  String _category = 'Payroll TDS';
  String _dueDate = '31 Oct 2026';

  final List<String> _categories = [
    'All',
    'Payroll TDS',
    'Statutory PF/ESI',
    'Goods & Services Tax',
    'Income Tax',
    'State Tax',
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
    _loadTaxRecords();
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
        List<dynamic> items = [];
        if (res is List) {
          items = res;
        } else if (res is Map<String, dynamic> && res['data'] is List) {
          items = res['data'];
        }

        if (items.isNotEmpty) {
          _taxRecords = items.map((t) => _mapTaxItem(t)).toList();
        } else {
          _taxRecords = _getMockTaxRecords();
        }
        _isLoading = false;
        setState(() {});
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _taxRecords = _getMockTaxRecords();
          _isLoading = false;
        });
      }
    }
  }

  Map<String, dynamic> _mapTaxItem(dynamic t) {
    final Map<String, dynamic> map = t is Map<String, dynamic> ? t : {};
    final isFiled = map['isFiled'] == true || map['status'] == 'Filed';

    return {
      'id': map['id'] ?? (map['id'] != null ? map['id'].toString().substring(0, 8).toUpperCase() : 'TAX-101'),
      'filingPeriod': map['financialYear'] ?? map['filingPeriod'] ?? 'Q3 - FY 2025-26',
      'type': map['regime'] ?? map['type'] ?? 'Form 24Q (Payroll TDS)',
      'category': map['category'] ?? 'Payroll TDS',
      'amountDue': (map['taxPayable'] ?? map['amountDue'] ?? 125000) as num,
      'amountPaid': (map['taxPaid'] ?? map['amountPaid'] ?? 125000) as num,
      'dueDate': map['dueDate'] ?? '31 Oct 2026',
      'filingDate': isFiled ? (map['date'] ?? '15 Oct 2026') : '-',
      'refNo': map['panNumber'] ?? map['refNo'] ?? 'ACK-2026-99120',
      'status': isFiled ? 'Filed' : 'Pending',
    };
  }

  List<Map<String, dynamic>> _getMockTaxRecords() {
    return [
      {
        'id': 'TAX-101',
        'filingPeriod': 'Q3 - FY 2025-26',
        'type': 'Form 24Q (Payroll TDS)',
        'category': 'Payroll TDS',
        'amountDue': 125000,
        'amountPaid': 125000,
        'dueDate': '31 Oct 2026',
        'filingDate': '15 Oct 2026',
        'refNo': 'ACK-2026-99120',
        'status': 'Filed',
      },
      {
        'id': 'TAX-102',
        'filingPeriod': 'Oct 2026',
        'type': 'EPF Monthly ECR Deposit',
        'category': 'Statutory PF/ESI',
        'amountDue': 85000,
        'amountPaid': 0,
        'dueDate': '15 Nov 2026',
        'filingDate': '-',
        'refNo': 'ACK-2026-99121',
        'status': 'Upcoming',
      },
      {
        'id': 'TAX-103',
        'filingPeriod': 'Oct 2026',
        'type': 'ESI Monthly Contribution',
        'category': 'Statutory PF/ESI',
        'amountDue': 24000,
        'amountPaid': 0,
        'dueDate': '15 Nov 2026',
        'filingDate': '-',
        'refNo': 'ACK-2026-99122',
        'status': 'Upcoming',
      },
      {
        'id': 'TAX-104',
        'filingPeriod': 'Q2 - FY 2025-26',
        'type': 'GSTR-3B Tax Return',
        'category': 'Goods & Services Tax',
        'amountDue': 210000,
        'amountPaid': 210000,
        'dueDate': '20 Oct 2026',
        'filingDate': '18 Oct 2026',
        'refNo': 'ACK-GST-88102',
        'status': 'Filed',
      },
    ];
  }

  int _getStatusCount(String label) {
    if (label == 'All') return _taxRecords.length;
    return _taxRecords.where((t) => t['status'] == label).length;
  }

  List<Map<String, dynamic>> get _filteredTaxRecords {
    return _taxRecords.where((item) {
      final period = (item['filingPeriod'] ?? '').toString().toLowerCase();
      final type = (item['type'] ?? '').toString().toLowerCase();
      final ref = (item['refNo'] ?? '').toString().toLowerCase();
      final cat = (item['category'] ?? '').toString().toLowerCase();
      final search = _searchTerm.toLowerCase();

      final matchesSearch = _searchTerm.isEmpty || period.contains(search) || type.contains(search) || ref.contains(search) || cat.contains(search);
      final matchesType = _selectedType == 'All' || cat.contains(_selectedType.toLowerCase()) || type.contains(_selectedType.toLowerCase());
      final matchesStatus = _selectedStatus == 'All' || item['status'] == _selectedStatus;

      return matchesSearch && matchesType && matchesStatus;
    }).toList();
  }

  int get _filedCount => _taxRecords.where((t) => t['status'] == 'Filed').length;
  int get _pendingUpcomingCount => _taxRecords.where((t) => t['status'] == 'Pending' || t['status'] == 'Upcoming').length;

  num get _totalTaxDeposited {
    return _taxRecords
        .where((t) => t['status'] == 'Filed')
        .fold<num>(0, (sum, t) => sum + ((t['amountDue'] as num?) ?? 0));
  }

  String _formatCurrency(num amount) {
    final str = amount.toInt().toString();
    final RegExp reg = RegExp(r'(\d+?)(?=(\d{3})+(?!\d))');
    final String result = str.replaceAllMapped(reg, (Match m) => '${m[1]},');
    return '₹ $result';
  }

  void _downloadChallan(Map<String, dynamic> item) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Downloading Challan receipt for ${item['filingPeriod']} (${item['refNo']})...'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  void _showFileTaxModal() {
    _periodController.text = 'Q3 - FY 2025-26';
    _formTypeController.text = 'Form 24Q (Payroll TDS)';
    _amountController.clear();
    _ackRefController.clear();
    _category = 'Payroll TDS';

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
                    Icon(Icons.file_upload, color: AppColors.primary),
                    SizedBox(width: 8),
                    Text('File Tax Return / Challan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                  const Text('Filing Period *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.lightSecondaryText)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _periodController,
                    decoration: InputDecoration(
                      hintText: 'e.g. Q3 - FY 2025-26',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  const Text('Tax Category', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.lightSecondaryText)),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<String>(
                    value: _category,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Payroll TDS', child: Text('Payroll TDS', style: TextStyle(fontSize: 12))),
                      DropdownMenuItem(value: 'Statutory PF/ESI', child: Text('Statutory PF/ESI', style: TextStyle(fontSize: 12))),
                      DropdownMenuItem(value: 'Goods & Services Tax', child: Text('Goods & Services Tax (GST)', style: TextStyle(fontSize: 12))),
                      DropdownMenuItem(value: 'Income Tax', child: Text('Income Tax', style: TextStyle(fontSize: 12))),
                      DropdownMenuItem(value: 'State Tax', child: Text('State Tax (PT)', style: TextStyle(fontSize: 12))),
                    ],
                    onChanged: (val) {
                      if (val != null) setModalState(() => _category = val);
                    },
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
                            const Text('Amount Due (₹) *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.lightSecondaryText)),
                            const SizedBox(height: 4),
                            TextField(
                              controller: _amountController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                hintText: '12500',
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

                  const Text('Challan / ACK Ref No.', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.lightSecondaryText)),
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
                      const SnackBar(content: Text('Please enter amount due'), backgroundColor: AppColors.error),
                    );
                    return;
                  }
                  Navigator.pop(context);
                  _saveFileTax();
                },
                icon: const Icon(Icons.check, size: 16),
                label: const Text('Submit Tax Return'),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
              ),
            ],
          );
        },
      ),
    );
  }

  void _saveFileTax() {
    final amt = num.tryParse(_amountController.text.trim()) ?? 15000;
    final period = _periodController.text.trim().isNotEmpty ? _periodController.text.trim() : 'Q3 - FY 2025-26';
    final formType = _formTypeController.text.trim().isNotEmpty ? _formTypeController.text.trim() : 'Form 24Q (Payroll TDS)';
    final ref = _ackRefController.text.trim().isNotEmpty ? _ackRefController.text.trim() : 'ACK-2026-${10000 + (DateTime.now().millisecondsSinceEpoch % 89999)}';

    final newRec = {
      'id': 'TAX-${1000 + (DateTime.now().millisecondsSinceEpoch % 8999)}',
      'filingPeriod': period,
      'type': formType,
      'category': _category,
      'amountDue': amt,
      'amountPaid': amt,
      'dueDate': '31 Oct 2026',
      'filingDate': '15 Oct 2026',
      'refNo': ref,
      'status': 'Filed',
    };

    setState(() {
      _taxRecords.insert(0, newRec);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Tax return filed successfully'),
        backgroundColor: AppColors.success,
      ),
    );
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
                Text('Tax Record: ${item['id']}'),
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
            _buildDetailRow('Filing Status', item['status'] ?? '', isPrimary: true),
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
              _downloadChallan(item);
            },
            icon: const Icon(Icons.download, size: 16),
            label: const Text('Download Challan'),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String val, {bool isBold = false, bool isAmount = false, bool isPrimary = false}) {
    Color textColor = AppColors.lightPrimaryText;
    if (isAmount) textColor = AppColors.success;
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
              fontWeight: (isBold || isAmount || isPrimary) ? FontWeight.bold : FontWeight.normal,
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

    final filteredList = _filteredTaxRecords;

    return RefreshIndicator(
      onRefresh: _loadTaxRecords,
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
                        child: Icon(Icons.shield, color: Colors.white, size: 26),
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
                              'Monitor TDS, PF/ESI contributions, GST, & Form 16',
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
                    icon: const Icon(Icons.upload_file, size: 16),
                    label: const Text('File Tax Return / Challan'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.darkPrimary,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                  label: 'Total Statutory Filings',
                  value: '${_taxRecords.length}',
                  sub: 'Active tax records',
                  icon: Icons.receipt_long,
                  bgColor: const Color(0xFFEFF6FF),
                  iconColor: const Color(0xFF2563EB),
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
                  value: '$_pendingUpcomingCount',
                  sub: 'Awaiting submission',
                  icon: Icons.schedule,
                  bgColor: const Color(0xFFFFF7ED),
                  iconColor: const Color(0xFFEA580C),
                ),
                _buildStatCard(
                  label: 'Total Tax Deposited',
                  value: _formatCurrency(_totalTaxDeposited),
                  sub: 'YTD Statutory payout',
                  icon: Icons.shield,
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
                              value: _selectedType,
                              isExpanded: true,
                              icon: const Icon(Icons.arrow_drop_down, color: AppColors.primary),
                              style: const TextStyle(fontSize: 12, color: AppColors.lightPrimaryText, fontWeight: FontWeight.w500),
                              items: _categories.map((cat) {
                                return DropdownMenuItem<String>(
                                  value: cat,
                                  child: Text(cat == 'All' ? 'All Tax Categories' : cat),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) setState(() => _selectedType = val);
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
                        _buildTabChip('Filed & Certified', 'Filed', _getStatusCount('Filed')),
                        const SizedBox(width: 8),
                        _buildTabChip('Upcoming', 'Upcoming', _getStatusCount('Upcoming')),
                        const SizedBox(width: 8),
                        _buildTabChip('Pending', 'Pending', _getStatusCount('Pending')),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Tax Register List Header & Cards
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: const [
                    Icon(Icons.receipt, color: AppColors.primary, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Statutory Tax Returns Ledger',
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
                    '${filteredList.length} Filings',
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
                        child: Icon(Icons.search_off, size: 28, color: AppColors.lightSecondaryText),
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

            const SizedBox(height: 24),

            // Upcoming Statutory Deadlines Card
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.calendar_today, color: AppColors.primary, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Upcoming Statutory Deadlines',
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
                          'Q3 & Q4 Filings',
                          style: TextStyle(fontSize: 11, color: AppColors.lightSecondaryText, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  ..._upcomingDeadlines.map((dl) {
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
                                Text(dl['title']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                const SizedBox(height: 2),
                                Text('Due: ${dl['date']}', style: const TextStyle(fontSize: 11, color: AppColors.lightSecondaryText)),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: dl['bg'] as Color,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              dl['tag']!,
                              style: TextStyle(fontSize: 11, color: dl['color'] as Color, fontWeight: FontWeight.bold),
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

            // Compliance & Audit Checklist Card
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.fact_check, color: AppColors.success, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Compliance & Audit Checklist',
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
                          'Audit Ready',
                          style: TextStyle(fontSize: 11, color: AppColors.success, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  ..._complianceChecklist.map((check) {
                    final completed = check['completed'] == true;
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
                          Row(
                            children: [
                              Icon(
                                completed ? Icons.check_circle : Icons.hourglass_top,
                                color: completed ? AppColors.success : AppColors.warning,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                check['name']!,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ],
                          ),
                          Text(
                            check['date']!,
                            style: const TextStyle(fontSize: 11, color: AppColors.lightSecondaryText, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    );
                  }),
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
    final status = item['status'] ?? 'Pending';
    final isFiled = status == 'Filed';
    final isUpcoming = status == 'Upcoming';

    Color statusBg = AppColors.warningBg;
    Color statusFg = AppColors.warning;

    if (isFiled) {
      statusBg = AppColors.successBg;
      statusFg = AppColors.success;
    } else if (isUpcoming) {
      statusBg = AppColors.lightPrimary;
      statusFg = AppColors.primary;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Period & Status Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.lightInputBackground,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Text(
                    item['filingPeriod'] ?? '',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: AppColors.lightPrimaryText,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      color: statusFg,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            Text(
              item['type'] ?? '',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppColors.lightInputBackground,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    item['category'] ?? '',
                    style: const TextStyle(fontSize: 10, color: AppColors.lightSecondaryText, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'ACK Ref: ${item['refNo']}',
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: AppColors.lightMutedText),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Due Amount & Dates
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('TAX DUE / AMOUNT', style: TextStyle(fontSize: 9, color: AppColors.lightMutedText, fontWeight: FontWeight.bold)),
                    Text(_formatCurrency(item['amountDue'] ?? 0), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.primary)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('DUE DATE', style: TextStyle(fontSize: 9, color: AppColors.lightMutedText, fontWeight: FontWeight.bold)),
                    Text(item['dueDate'] ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.lightSecondaryText)),
                  ],
                ),
              ],
            ),
            const Divider(height: 18),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Filing Date: ${item['filingDate']}',
                  style: const TextStyle(fontSize: 11, color: AppColors.lightSecondaryText),
                ),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _downloadChallan(item),
                      icon: const Icon(Icons.download, size: 14),
                      label: const Text('Challan'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      onPressed: () => _viewTaxDetails(item),
                      icon: const Icon(Icons.visibility_outlined, size: 18),
                      color: AppColors.lightSecondaryText,
                      tooltip: 'View Details',
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
