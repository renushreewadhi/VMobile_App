import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_header.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/loading_shimmer.dart';

class FinancePaymentsScreen extends ConsumerStatefulWidget {
  final bool? showAppBar;
  const FinancePaymentsScreen({super.key, this.showAppBar = false});

  @override
  ConsumerState<FinancePaymentsScreen> createState() => _FinancePaymentsScreenState();
}

class _FinancePaymentsScreenState extends ConsumerState<FinancePaymentsScreen> {
  String _searchTerm = '';
  String _selectedMethod = 'All'; // 'All', 'ACH', 'Wire', 'NEFT', 'Card'
  String _selectedStatus = 'All'; // 'All', 'Success', 'Processing'
  bool _isLoading = true;

  List<Map<String, dynamic>> _payments = [];

  // Form Controllers for New Outgoing Payout
  final TextEditingController _recipientController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _refNoController = TextEditingController();
  String _category = 'Payroll Direct Deposit';
  String _method = 'Bank Direct ACH';

  final List<Map<String, String>> _categories = [
    {'value': 'Payroll Direct Deposit', 'label': 'Payroll Direct Deposit'},
    {'value': 'Vendor Payout', 'label': 'Vendor Payout'},
    {'value': 'Travel Reimbursement', 'label': 'Travel Reimbursement'},
    {'value': 'Salary Advance', 'label': 'Salary Advance'},
    {'value': 'Benefit Claim Payout', 'label': 'Benefit Claim Payout'},
  ];

  final List<Map<String, String>> _methods = [
    {'value': 'Bank Direct ACH', 'label': 'Bank Direct ACH'},
    {'value': 'Corporate Wire', 'label': 'Corporate Wire'},
    {'value': 'Batch NEFT', 'label': 'Batch NEFT'},
    {'value': 'Corporate Card', 'label': 'Corporate Card'},
  ];

  final List<Map<String, String>> _channels = [
    {'name': 'Corporate ACH Direct Debit', 'type': 'Primary Channel • Limit: No Daily Limit', 'status': 'Active (Online)'},
    {'name': 'FedWire International Transfer', 'type': 'Wire Transfer • Limit: ₹5,00,000 / Day', 'status': 'Active (Online)'},
    {'name': 'SWIFT Overseas Remittance', 'type': 'Cross-Border • Limit: ₹2,50,000 / Day', 'status': 'Active (Online)'},
    {'name': 'Corporate Virtual Credit Card', 'type': 'Instant Payout • Limit: ₹50,000 / Day', 'status': 'Active (Online)'},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadPayments();
    });
  }

  @override
  void dispose() {
    _recipientController.dispose();
    _amountController.dispose();
    _refNoController.dispose();
    super.dispose();
  }

  Future<void> _loadPayments() async {
    setState(() => _isLoading = true);
    final apiClient = ref.read(apiClientProvider);

    try {
      final res = await apiClient.get(ApiEndpoints.financePayments).catchError((_) => null);

      if (mounted) {
        if (res != null) {
          List<dynamic> items = [];
          if (res is List) {
            items = res;
          } else if (res is Map<String, dynamic>) {
            final data = res['data'] ?? res['items'] ?? res['result'] ?? res['payments'];
            if (data is List) {
              items = data;
            }
          }

          _payments = items.map((p) => _mapPaymentItem(p)).toList();
        } else {
          _payments = [];
        }
        _isLoading = false;
        setState(() {});
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _payments = [];
          _isLoading = false;
        });
      }
    }
  }

  Map<String, dynamic> _mapPaymentItem(dynamic p) {
    final Map<String, dynamic> map = p is Map<String, dynamic> ? p : {};
    final recipient = map['recipient'] ?? map['payee'] ?? map['employeeName'] ?? 'Vendor Payee';
    final rawAmt = (map['rawAmount'] ?? map['amount'] ?? 0) as num;
    final statusStr = (map['status'] ?? 'Success').toString();

    return {
      'ref': map['ref'] ?? map['reference'] ?? map['transactionId'] ?? (map['id'] != null ? map['id'].toString().substring(0, 8).toUpperCase() : 'PAY-9910'),
      'recipient': recipient,
      'category': map['category'] ?? map['paymentType'] ?? 'Vendor Payout',
      'amount': _formatCurrency(rawAmt),
      'rawAmount': rawAmt,
      'method': map['method'] ?? map['paymentMethod'] ?? 'Bank Direct ACH',
      'date': map['date'] ?? map['paidOn'] ?? map['createdAt'] ?? '15 Oct 2026',
      'status': statusStr.toLowerCase() == 'completed' ? 'Success' : (statusStr.isEmpty ? 'Success' : statusStr),
      'initials': _getInitials(recipient),
    };
  }

  String _getInitials(String name) {
    if (name.isEmpty) return 'PY';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, name.length >= 2 ? 2 : name.length).toUpperCase();
  }

  int _getStatusCount(String label) {
    if (label == 'All') return _payments.length;
    if (label == 'Success') return _payments.where((p) => p['status'] == 'Success' || p['status'] == 'Completed').length;
    if (label == 'Processing') return _payments.where((p) => p['status'] == 'Processing' || p['status'] == 'Pending').length;
    return 0;
  }

  List<Map<String, dynamic>> get _filteredPayments {
    return _payments.where((item) {
      final rec = (item['recipient'] ?? '').toString().toLowerCase();
      final cat = (item['category'] ?? '').toString().toLowerCase();
      final ref = (item['ref'] ?? '').toString().toLowerCase();
      final search = _searchTerm.toLowerCase();

      final matchesSearch = _searchTerm.isEmpty || rec.contains(search) || cat.contains(search) || ref.contains(search);
      final methodStr = (item['method'] ?? '').toString().toLowerCase();
      final matchesMethod = _selectedMethod == 'All' || methodStr.contains(_selectedMethod.toLowerCase());

      final status = item['status']?.toString() ?? '';
      final matchesStatus = _selectedStatus == 'All' ||
          status == _selectedStatus ||
          (_selectedStatus == 'Success' && status == 'Completed') ||
          (_selectedStatus == 'Processing' && status == 'Pending');

      return matchesSearch && matchesMethod && matchesStatus;
    }).toList();
  }

  num get _totalCompletedAmount {
    return _payments
        .where((p) => p['status'] == 'Success' || p['status'] == 'Completed')
        .fold<num>(0, (sum, p) => sum + ((p['rawAmount'] as num?) ?? 0));
  }

  int get _processingCount => _payments.where((p) => p['status'] == 'Processing' || p['status'] == 'Pending').length;

  String _formatCurrency(num amount) {
    final str = amount.toInt().toString();
    final RegExp reg = RegExp(r'(\d+?)(?=(\d{3})+(?!\d))');
    final String result = str.replaceAllMapped(reg, (Match m) => '${m[1]},');
    return '₹$result';
  }

  void _exportReceipt(Map<String, dynamic> item) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Downloading Payment Receipt for ${item['ref']} (${item['recipient']})...'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  void _showNewPaymentModal() {
    _recipientController.clear();
    _amountController.clear();
    _refNoController.clear();
    _category = 'Payroll Direct Deposit';
    _method = 'Bank Direct ACH';

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
                    Icon(Icons.payment, color: AppColors.primary),
                    SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Record Outgoing Disbursement', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                        Text('Log new vendor payment, salary transfer, or payout', style: TextStyle(fontSize: 11, color: AppColors.lightSecondaryText)),
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
                  const Text('Payee / Recipient Name *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.lightSecondaryText)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _recipientController,
                    decoration: InputDecoration(
                      hintText: 'e.g. Sarah Jenkins or Acme Corp',
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
                            const Text('Disbursement Category', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.lightSecondaryText)),
                            const SizedBox(height: 4),
                            DropdownButtonFormField<String>(
                              value: _category,
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              items: _categories.map((c) {
                                return DropdownMenuItem<String>(value: c['value'], child: Text(c['label']!, style: const TextStyle(fontSize: 11)));
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) setModalState(() => _category = val);
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
                            const Text('Payment Method', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.lightSecondaryText)),
                            const SizedBox(height: 4),
                            DropdownButtonFormField<String>(
                              value: _method,
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              items: _methods.map((m) {
                                return DropdownMenuItem<String>(value: m['value'], child: Text(m['label']!, style: const TextStyle(fontSize: 11)));
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) setModalState(() => _method = val);
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Amount (₹) *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.lightSecondaryText)),
                            const SizedBox(height: 4),
                            TextField(
                              controller: _amountController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                hintText: '48500',
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
                            const Text('Payment Ref / Transaction ID', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.lightSecondaryText)),
                            const SizedBox(height: 4),
                            TextField(
                              controller: _refNoController,
                              decoration: InputDecoration(
                                hintText: 'e.g. PAY-2026-991',
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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
                  if (_recipientController.text.trim().isEmpty || _amountController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please fill in recipient and amount fields'),
                        backgroundColor: AppColors.error,
                      ),
                    );
                    return;
                  }
                  Navigator.pop(context);
                  _saveNewPayment();
                },
                icon: const Icon(Icons.check, size: 16),
                label: const Text('Submit Disbursement'),
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

  Future<void> _saveNewPayment() async {
    final amt = num.tryParse(_amountController.text.trim()) ?? 0;
    final refNo = _refNoController.text.trim().isNotEmpty
        ? _refNoController.text.trim()
        : 'PAY-${100000 + (DateTime.now().millisecondsSinceEpoch % 899999)}';
    final recipient = _recipientController.text.trim();

    final apiClient = ref.read(apiClientProvider);

    try {
      await apiClient.post(ApiEndpoints.financePayments, data: {
        'recipient': recipient,
        'category': _category,
        'amount': amt,
        'method': _method,
        'reference': refNo,
      }).catchError((_) => null);

      if (mounted) {
        _loadPayments();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Disbursement of ${_formatCurrency(amt)} to $recipient recorded successfully'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (_) {}
  }

  void _viewPaymentDetails(Map<String, dynamic> item) {
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
                Text('Transfer Ref: ${item['ref']}'),
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
            _buildDetailRow('Recipient', item['recipient'] ?? '', isBold: true),
            _buildDetailRow('Category', item['category'] ?? ''),
            _buildDetailRow('Amount Paid', item['amount'] ?? '', isAmount: true),
            _buildDetailRow('Payment Method', item['method'] ?? ''),
            _buildDetailRow('Transfer Date', item['date'] ?? ''),
            _buildDetailRow('Status', item['status'] ?? '', isPrimary: true),
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
              _exportReceipt(item);
            },
            icon: const Icon(Icons.download, size: 16),
            label: const Text('Download Receipt'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
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

  Widget _buildPaymentCard(Map<String, dynamic> item) {
    final status = item['status']?.toString() ?? 'Success';
    final isSuccess = status == 'Success' || status == 'Completed';

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
                  item['ref'] ?? '',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primary),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isSuccess ? AppColors.successBg : AppColors.warningBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isSuccess ? 'Completed' : 'Pending Clearance',
                  style: TextStyle(color: isSuccess ? AppColors.success : AppColors.warning, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.lightPrimary,
                child: Text(
                  item['initials'] as String,
                  style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item['recipient'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text('${item['category']} • ${item['method']}', style: const TextStyle(fontSize: 11, color: AppColors.lightSecondaryText)),
                  ],
                ),
              ),
              Text(
                item['amount'] as String,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.success),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Transfer Date: ${item['date']}', style: const TextStyle(fontSize: 11, color: AppColors.lightMutedText)),
              OutlinedButton.icon(
                onPressed: () => _viewPaymentDetails(item),
                icon: const Icon(Icons.download, size: 14),
                label: const Text('Receipt'),
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const DashboardSkeleton();

    final filteredList = _filteredPayments;
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
                Tab(text: 'Disbursement Ledger'),
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
                                  child: Icon(Icons.account_balance, color: Colors.white, size: 26),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: const [
                                      Text(
                                        'Payments, Wire Transfers & ACH',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        'Track outgoing vendor payments, ACH salary transfers, benefit payouts, & receipts',
                                        style: TextStyle(color: Colors.white70, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Exporting Disbursement & Transfer Ledger to Excel...'),
                                        backgroundColor: AppColors.primary,
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.table_chart_outlined, size: 16),
                                  label: const Text('Export Excel'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    side: const BorderSide(color: Colors.white54),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton.icon(
                                  onPressed: _showNewPaymentModal,
                                  icon: const Icon(Icons.add, size: 16),
                                  label: const Text('Record Payout'),
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
                            label: 'TOTAL PAYMENTS LOGGED',
                            value: '${_payments.length}',
                            sub: 'All disbursements',
                            icon: Icons.receipt_long,
                            bgColor: const Color(0xFFEFF6FF),
                            iconColor: const Color(0xFF2563EB),
                          ),
                          _buildStatCard(
                            label: 'COMPLETED TRANSFERS',
                            value: _formatCurrency(_totalCompletedAmount),
                            sub: 'Successfully settled',
                            icon: Icons.check_circle_outline,
                            bgColor: const Color(0xFFF0FDF4),
                            iconColor: const Color(0xFF16A34A),
                          ),
                          _buildStatCard(
                            label: 'PENDING CLEARANCE',
                            value: '$_processingCount',
                            sub: 'Awaiting bank release',
                            icon: Icons.sync,
                            bgColor: const Color(0xFFFFF7ED),
                            iconColor: const Color(0xFFEA580C),
                          ),
                          _buildStatCard(
                            label: 'ACTIVE GATEWAYS',
                            value: '4 Active',
                            sub: 'Corporate channels',
                            icon: Icons.account_balance,
                            bgColor: const Color(0xFFEFF6FF),
                            iconColor: const Color(0xFF2563EB),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Connected Banking Gateways Card
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
                                      Icon(Icons.account_balance, color: AppColors.primary, size: 18),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Connected Banking & Payment Gateways',
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(width: 8),
                                Text('Corporate Accounts', style: TextStyle(fontSize: 11, color: AppColors.lightSecondaryText)),
                              ],
                            ),
                            const Divider(height: 20),
                            ..._channels.map((ch) {
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
                                          Text(ch['name']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                          const SizedBox(height: 2),
                                          Text(ch['type']!, style: const TextStyle(fontSize: 11, color: AppColors.lightSecondaryText)),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: AppColors.successBg,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        ch['status']!,
                                        style: const TextStyle(color: AppColors.success, fontSize: 10, fontWeight: FontWeight.bold),
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

                      // Security Controls Card
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
                                      Icon(Icons.security, color: AppColors.primary, size: 18),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Disbursement Security Controls',
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(width: 8),
                                Text('2FA Verified', style: TextStyle(fontSize: 11, color: AppColors.lightSecondaryText)),
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
                                  Icon(Icons.verified_user, color: AppColors.primary, size: 20),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Dual-Authorization Payout Policy', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                        Text('Transfers over ₹10,00,000 require VP Finance dual multi-factor approval.', style: TextStyle(fontSize: 10.5, color: AppColors.lightSecondaryText)),
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
                                  Icon(Icons.lock, color: AppColors.primary, size: 20),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Encrypted ACH Batch Remittance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                        Text('256-bit SSL encrypted bank file generation & NACHA protocol compliance.', style: TextStyle(fontSize: 10.5, color: AppColors.lightSecondaryText)),
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

                // Tab 2: Disbursement Ledger
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
                                hintText: 'Search payment ref, recipient, or category...',
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
                                const Icon(Icons.credit_card, size: 18, color: AppColors.lightSecondaryText),
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
                                        value: _selectedMethod,
                                        isExpanded: true,
                                        icon: const Icon(Icons.arrow_drop_down, color: AppColors.primary),
                                        style: const TextStyle(fontSize: 12, color: AppColors.lightPrimaryText, fontWeight: FontWeight.w500),
                                        items: const [
                                          DropdownMenuItem(value: 'All', child: Text('All Payment Methods')),
                                          DropdownMenuItem(value: 'ACH', child: Text('Bank Direct ACH')),
                                          DropdownMenuItem(value: 'Wire', child: Text('Corporate Wire')),
                                          DropdownMenuItem(value: 'NEFT', child: Text('Batch NEFT')),
                                          DropdownMenuItem(value: 'Card', child: Text('Corporate Card')),
                                        ],
                                        onChanged: (val) {
                                          if (val != null) setState(() => _selectedMethod = val);
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
                                  _buildTabChip('All Payments', 'All', _getStatusCount('All')),
                                  const SizedBox(width: 8),
                                  _buildTabChip('Completed & Success', 'Success', _getStatusCount('Success')),
                                  const SizedBox(width: 8),
                                  _buildTabChip('Pending Clearance', 'Processing', _getStatusCount('Processing')),
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
                                Icon(Icons.receipt_long, color: AppColors.primary, size: 18),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Disbursement & Transfer Ledger',
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
                              '${filteredList.length} Payments Logged',
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
                                  child: Icon(Icons.request_quote_outlined, size: 28, color: AppColors.lightSecondaryText),
                                ),
                                SizedBox(height: 12),
                                Text(
                                  'No payment records found',
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
                            return _buildPaymentCard(item);
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
      appBar: const GlassHeader(title: 'Payments'),
      showBottomBar: false,
      body: content,
    );
  }
}
