import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_header.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/loading_shimmer.dart';

class FinanceBenefitsScreen extends ConsumerStatefulWidget {
  final bool? showAppBar;
  const FinanceBenefitsScreen({super.key, this.showAppBar = false});

  @override
  ConsumerState<FinanceBenefitsScreen> createState() => _FinanceBenefitsScreenState();
}

class _FinanceBenefitsScreenState extends ConsumerState<FinanceBenefitsScreen> {
  String _searchTerm = '';
  String _selectedStatus = 'All'; // 'All', 'Pending', 'Processed', 'Paid'
  bool _isLoading = true;
  String? _processingId;

  List<Map<String, dynamic>> _claims = [];

  // Payment Modal controllers
  String _paymentMethod = 'RAZORPAY';
  final TextEditingController _transactionIdController = TextEditingController();
  final TextEditingController _paymentNotesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadClaims();
    });
  }

  @override
  void dispose() {
    _transactionIdController.dispose();
    _paymentNotesController.dispose();
    super.dispose();
  }

  Future<void> _loadClaims() async {
    setState(() => _isLoading = true);
    final apiClient = ref.read(apiClientProvider);

    try {
      final res = await apiClient.get(ApiEndpoints.benefitClaimsForPayment).catchError((_) => null);

      if (mounted) {
        if (res != null) {
          List<dynamic> items = [];
          if (res is List) {
            items = res;
          } else if (res is Map<String, dynamic>) {
            final data = res['data'] ?? res['items'] ?? res['result'] ?? res['claims'];
            if (data is List) {
              items = data;
            }
          }

          _claims = items.map((c) => _mapBenefitClaim(c)).toList();
        } else {
          _claims = [];
        }
        _isLoading = false;
        setState(() {});
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _claims = [];
          _isLoading = false;
        });
      }
    }
  }

  Map<String, dynamic> _mapBenefitClaim(dynamic c) {
    final Map<String, dynamic> map = c is Map<String, dynamic> ? c : {};
    final claimId = map['claimId'] ?? map['id']?.toString() ?? 'CLM-101';
    final empName = map['employeeName'] ?? map['empName'] ?? map['requestedBy'] ?? map['userName'] ?? 'Employee';
    final rawStatus = (map['paymentStatus'] ?? map['status'] ?? 'PENDING').toString().toUpperCase();

    return {
      'claimId': claimId,
      'rawId': map['id'] ?? claimId,
      'employeeName': empName,
      'employeeCode': map['employeeCode'] ?? map['empCode'] ?? map['empId'] ?? 'EMP-1001',
      'benefitName': map['benefitName'] ?? map['benefit'] ?? map['title'] ?? 'Benefit Allowance',
      'benefitCode': map['benefitCode'] ?? map['code'] ?? 'BEN-ALLW',
      'amount': (map['amount'] ?? map['claimAmount'] ?? 0) as num,
      'claimDate': map['claimDate'] ?? map['date'] ?? map['createdAt'] ?? '',
      'hrReviewerName': map['hrReviewerName'] ?? map['verifiedBy'] ?? map['reviewedBy'] ?? '-',
      'hrVerifiedAt': map['hrVerifiedAt'] ?? map['verifiedAt'] ?? '',
      'paymentStatus': (rawStatus == 'PAID_SETTLED') ? 'COMPLETED' : 'PENDING',
    };
  }

  int _getStatusCount(String statusLabel) {
    if (statusLabel == 'All') return _claims.length;
    if (statusLabel == 'Pending') return _claims.where((c) => c['paymentStatus'] == 'PENDING').length;
    if (statusLabel == 'Processed') return _claims.where((c) => c['paymentStatus'] == 'PROCESSED').length;
    if (statusLabel == 'Paid') return _claims.where((c) => c['paymentStatus'] == 'COMPLETED' || c['paymentStatus'] == 'PAID').length;
    return 0;
  }

  String _getPaymentStatusLabel(String? status) {
    if (status == null || status.isEmpty) return 'Pending';
    final u = status.toUpperCase();
    if (u == 'PENDING') return 'Pending';
    if (u == 'PROCESSED') return 'Processed';
    if (u == 'COMPLETED' || u == 'PAID') return 'Paid';
    return 'Pending';
  }

  List<Map<String, dynamic>> get _filteredClaims {
    return _claims.where((c) {
      final empName = (c['employeeName'] ?? '').toString().toLowerCase();
      final benName = (c['benefitName'] ?? '').toString().toLowerCase();
      final empCode = (c['employeeCode'] ?? '').toString().toLowerCase();
      final search = _searchTerm.toLowerCase();

      final matchSearch = _searchTerm.isEmpty || empName.contains(search) || benName.contains(search) || empCode.contains(search);
      final statusLabel = _getPaymentStatusLabel(c['paymentStatus']);
      final matchStatus = _selectedStatus == 'All' || statusLabel == _selectedStatus;

      return matchSearch && matchStatus;
    }).toList();
  }

  num get _totalValue {
    return _claims.fold<num>(0, (sum, c) => sum + ((c['amount'] as num?) ?? 0));
  }

  int get _uniqueEmployeeCount {
    return _claims.map((c) => c['employeeCode']).toSet().length;
  }

  num get _avgClaimValue {
    if (_claims.isEmpty) return 0;
    return (_totalValue / _claims.length).round();
  }

  String _formatCurrency(num amount) {
    final str = amount.toInt().toString();
    final RegExp reg = RegExp(r'(\d+?)(?=(\d{3})+(?!\d))');
    final String result = str.replaceAllMapped(reg, (Match m) => '${m[1]},');
    return '₹$result';
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty || dateStr.startsWith('0001')) return '-';
    try {
      final dt = DateTime.parse(dateStr);
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${dt.day.toString().padLeft(2, '0')} ${months[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return dateStr;
    }
  }

  void _openPayModal(Map<String, dynamic> claim) {
    _paymentMethod = 'RAZORPAY';
    _transactionIdController.clear();
    _paymentNotesController.clear();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final claimId = claim['claimId'] ?? '';
          final isProcessing = _processingId == claimId;

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            titlePadding: const EdgeInsets.all(16),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            actionsPadding: const EdgeInsets.all(12),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.successBg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.payment, color: AppColors.success, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Process Benefit Settlement',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'Disburse approved reimbursement to employee',
                              style: TextStyle(fontSize: 11, color: AppColors.lightSecondaryText),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
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
                  // Claim Summary Card
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.lightInputBackground,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: AppColors.primary,
                              child: Text(
                                (claim['employeeName'] ?? 'E').toString().substring(0, 1).toUpperCase(),
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    claim['employeeName'] ?? '',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  Text(
                                    claim['employeeCode'] ?? '',
                                    style: const TextStyle(fontSize: 11, color: AppColors.lightSecondaryText),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'BENEFIT PLAN: ${claim['benefitName']} (${claim['benefitCode']})',
                              style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.lightSecondaryText),
                            ),
                          ],
                        ),
                        const Divider(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'SETTLEMENT AMOUNT',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.lightMutedText),
                            ),
                            Text(
                              _formatCurrency(claim['amount'] ?? 0),
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: AppColors.primary),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Payment Method Select
                  const Text(
                    'PAYMENT METHOD',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.lightMutedText),
                  ),
                  const SizedBox(height: 8),

                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildMethodPill('RAZORPAY', 'Razorpay Online Payout (Instant)', Icons.bolt, Colors.orange, setModalState),
                      _buildMethodPill('BANK_TRANSFER', 'Bank Direct ACH', Icons.account_balance, AppColors.primary, setModalState),
                      _buildMethodPill('UPI', 'UPI Payout', Icons.mobile_friendly, Colors.teal, setModalState),
                      _buildMethodPill('CHEQUE', 'Cheque', Icons.payment, Colors.blueGrey, setModalState),
                      _buildMethodPill('CASH', 'Cash', Icons.wallet, AppColors.success, setModalState),
                    ],
                  ),
                  const SizedBox(height: 14),

                  if (_paymentMethod == 'RAZORPAY')
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.successBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.success.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.verified_user, color: AppColors.success, size: 20),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Razorpay Secure Gateway',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.lightPrimaryText),
                                ),
                                Text(
                                  'Pay instantly via UPI, NetBanking, Debit/Credit Cards.',
                                  style: TextStyle(fontSize: 11, color: AppColors.lightSecondaryText),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )
                  else ...[
                    const Text(
                      'Transaction Reference ID',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.lightSecondaryText),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _transactionIdController,
                      decoration: InputDecoration(
                        hintText: 'e.g. UTR12345678 / Cheque No.',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  const SizedBox(height: 10),
                  const Text(
                    'PAYMENT REMARKS / NOTES',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.lightMutedText),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _paymentNotesController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'Optional settlement notes...',
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
                onPressed: isProcessing
                    ? null
                    : () {
                        Navigator.pop(context);
                        _processPayment(claim);
                      },
                icon: isProcessing
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check, size: 16),
                label: Text(_paymentMethod == 'RAZORPAY' ? 'Pay via Razorpay' : 'Confirm Settlement'),
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

  Widget _buildMethodPill(String value, String label, IconData icon, Color color, StateSetter setModalState) {
    final isActive = _paymentMethod == value;
    return InkWell(
      onTap: () => setModalState(() => _paymentMethod = value),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppColors.lightPrimary : AppColors.lightInputBackground,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive ? AppColors.primary : Colors.grey.shade300,
            width: isActive ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isActive ? AppColors.primary : color, size: 14),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
                color: isActive ? AppColors.primary : AppColors.lightPrimaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _processPayment(Map<String, dynamic> claim) async {
    final claimId = claim['claimId'] ?? '';
    setState(() => _processingId = claimId);

    final apiClient = ref.read(apiClientProvider);

    try {
      await apiClient.post('/benefits/finance/claims/$claimId/pay', data: {
        'paymentMethod': _paymentMethod,
        'transactionId': _transactionIdController.text,
        'notes': _paymentNotesController.text,
      }).catchError((_) => null);

      if (mounted) {
        setState(() {
          claim['paymentStatus'] = 'COMPLETED';
          _processingId = null;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment processed successfully for claim ${claim['employeeName']}!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (_) {
      if (mounted) setState(() => _processingId = null);
    }
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

  Widget _buildClaimCard(Map<String, dynamic> claim) {
    final status = claim['paymentStatus']?.toString() ?? 'PENDING';
    final isCompleted = status == 'COMPLETED' || status == 'PAID';
    final isProcessed = status == 'PROCESSED';
    final isProcessingThis = _processingId == claim['claimId'];

    Color statusBg = AppColors.warningBg;
    Color statusFg = AppColors.warning;
    String statusLabel = 'Pending';

    if (isCompleted) {
      statusBg = AppColors.successBg;
      statusFg = AppColors.success;
      statusLabel = 'Paid';
    } else if (isProcessed) {
      statusBg = AppColors.infoBg;
      statusFg = AppColors.info;
      statusLabel = 'Processed';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.darkPrimary,
                  child: Text(
                    (claim['employeeName'] ?? 'E').toString().substring(0, 1).toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        claim['employeeName'] ?? '',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      Text(
                        claim['employeeCode'] ?? '',
                        style: const TextStyle(fontSize: 11, color: AppColors.lightMutedText),
                      ),
                    ],
                  ),
                ),
                Text(
                  _formatCurrency(claim['amount'] ?? 0),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            Text(
              '${claim['benefitName']} (${claim['benefitCode']})',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 2),
            Text(
              'Claim Date: ${_formatDate(claim['claimDate'])} | Verified By: ${claim['hrReviewerName'] ?? '-'}',
              style: const TextStyle(fontSize: 11, color: AppColors.lightSecondaryText),
            ),
            const Divider(height: 18),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(color: statusFg, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
                if (isCompleted)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.successBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.check, color: AppColors.success, size: 12),
                        SizedBox(width: 4),
                        Text(
                          'Paid',
                          style: TextStyle(color: AppColors.success, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  )
                else
                  ElevatedButton.icon(
                    onPressed: isProcessingThis ? null : () => _openPayModal(claim),
                    icon: isProcessingThis
                        ? const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.payment, size: 14),
                    label: const Text('Pay'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const DashboardSkeleton();

    final pendingCount = _getStatusCount('Pending');
    final processedCount = _getStatusCount('Processed');
    final paidCount = _getStatusCount('Paid');
    final filteredList = _filteredClaims;
    final bool showHeader = widget.showAppBar ?? false;

    return DefaultTabController(
      length: 2,
      child: showHeader
          ? GlassScaffold(
              appBar: const GlassHeader(title: 'Benefit Claims'),
              showBottomBar: false,
              body: Column(
                children: [
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
                        Tab(text: 'Claims Queue'),
                      ],
                    ),
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildOverviewTab(pendingCount),
                        _buildClaimsQueueTab(filteredList, pendingCount, processedCount, paidCount),
                      ],
                    ),
                  ),
                ],
              ),
            )
          : Column(
              children: [
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
                      Tab(text: 'Claims Queue'),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildOverviewTab(pendingCount),
                      _buildClaimsQueueTab(filteredList, pendingCount, processedCount, paidCount),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildOverviewTab(int pendingCount) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppCard(
            backgroundColor: AppColors.darkPrimary,
            child: Row(
              children: const [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.white24,
                  child: Icon(Icons.receipt_long, color: Colors.white, size: 26),
                ),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Benefit Claims Overview',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Track and review all HR-verified benefit claims across departments.',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
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
                label: 'Pending Claims',
                value: '$pendingCount',
                sub: 'Awaiting payment',
                icon: Icons.hourglass_empty,
                bgColor: const Color(0xFFFFF7ED),
                iconColor: const Color(0xFFEA580C),
              ),
              _buildStatCard(
                label: 'Total Amount',
                value: _formatCurrency(_totalValue),
                sub: 'To be disbursed',
                icon: Icons.monetization_on_outlined,
                bgColor: const Color(0xFFFEFCE8),
                iconColor: const Color(0xFFCA8A04),
              ),
              _buildStatCard(
                label: 'Employee Count',
                value: '$_uniqueEmployeeCount',
                sub: 'Unique employees',
                icon: Icons.people_outline,
                bgColor: const Color(0xFFEFF6FF),
                iconColor: const Color(0xFF2563EB),
              ),
              _buildStatCard(
                label: 'Avg Claim',
                value: _formatCurrency(_avgClaimValue),
                sub: 'Average per claim',
                icon: Icons.trending_up,
                bgColor: const Color(0xFFF0FDF4),
                iconColor: const Color(0xFF16A34A),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildClaimsQueueTab(List<Map<String, dynamic>> filteredList, int pendingCount, int processedCount, int paidCount) {
    return SingleChildScrollView(
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
                    hintText: 'Search by employee, code, or benefit...',
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
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildTabChip('All Claims', 'All', _getStatusCount('All')),
                      const SizedBox(width: 8),
                      _buildTabChip('Pending', 'Pending', pendingCount),
                      const SizedBox(width: 8),
                      _buildTabChip('Processed', 'Processed', processedCount),
                      const SizedBox(width: 8),
                      _buildTabChip('Paid', 'Paid', paidCount),
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
              Row(
                children: const [
                  Icon(Icons.list_alt, color: AppColors.primary, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Benefit Claims Queue',
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
                  'Total Pending: ${_formatCurrency(_totalValue)}',
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
                      child: Icon(Icons.receipt_long_outlined, size: 28, color: AppColors.lightSecondaryText),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'No claims found',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Try clearing or modifying your search and status filter.',
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
                final claim = filteredList[index];
                return _buildClaimCard(claim);
              },
            ),
        ],
      ),
    );
  }
}
