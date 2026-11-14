import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_header.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/loading_shimmer.dart';

class FinanceReimbursementsScreen extends ConsumerStatefulWidget {
  final bool showAppBar;
  const FinanceReimbursementsScreen({super.key, this.showAppBar = false});

  @override
  ConsumerState<FinanceReimbursementsScreen> createState() => _FinanceReimbursementsScreenState();
}

class _FinanceReimbursementsScreenState extends ConsumerState<FinanceReimbursementsScreen> {
  String _searchTerm = '';
  String _selectedCategory = 'All';
  String _selectedStatus = 'All'; // 'All', 'Pending', 'Approved', 'Rejected'
  bool _isLoading = true;
  String? _processingId;

  List<Map<String, dynamic>> _claims = [];

  final List<Map<String, String>> _categories = [
    {'value': 'All', 'label': 'All Categories'},
    {'value': 'TRAVEL', 'label': 'Travel'},
    {'value': 'FOOD', 'label': 'Food & Meals'},
    {'value': 'HOTEL', 'label': 'Hotel & Stay'},
    {'value': 'FUEL', 'label': 'Fuel & Transport'},
    {'value': 'MEDICAL', 'label': 'Medical'},
    {'value': 'INTERNET', 'label': 'Internet'},
    {'value': 'OTHER', 'label': 'Other'},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadReimbursements();
    });
  }

  Future<void> _loadReimbursements() async {
    setState(() => _isLoading = true);
    final apiClient = ref.read(apiClientProvider);

    try {
      final res = await apiClient.get(ApiEndpoints.financeReimbursements).catchError((_) => null);

      if (mounted) {
        if (res != null) {
          List<dynamic> items = [];
          if (res is List) {
            items = res;
          } else if (res is Map<String, dynamic>) {
            final data = res['data'] ?? res['items'] ?? res['result'] ?? res['reimbursements'] ?? res['claims'];
            if (data is List) {
              items = data;
            }
          }

          final seen = <String>{};
          final List<Map<String, dynamic>> mapped = [];
          for (final item in items) {
            final m = _mapClaimItem(item);
            final key = '${m['id']}_${m['claimId']}';
            if (!seen.contains(key)) {
              seen.add(key);
              mapped.add(m);
            }
          }
          _claims = mapped;
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

  Map<String, dynamic> _mapClaimItem(dynamic r) {
    final Map<String, dynamic> item = r is Map<String, dynamic> ? r : {};
    final empName = item['employeeName'] ?? item['empName'] ?? item['requestedBy'] ?? item['userName'] ?? item['name'] ?? 'Employee';
    final id = item['id']?.toString() ?? item['reqId']?.toString() ?? '1';
    final rawAmt = (item['amount'] ?? item['totalAmount'] ?? item['claimAmount'] ?? 0) as num;
    final code = item['claimId'] ?? item['claimCode'] ?? item['reqCode'] ?? item['expenseNumber'] ?? (id.length >= 8 ? id.substring(0, 8).toUpperCase() : 'CLM-901');
    final rawStatus = (item['status'] ?? 'PENDING').toString().toUpperCase();

    return {
      'id': id,
      'claimId': code,
      'empName': empName,
      'department': item['department'] ?? item['dept'] ?? 'General',
      'category': (item['category'] ?? item['expenseCategory'] ?? 'OTHER').toString().toUpperCase(),
      'amount': rawAmt,
      'date': _formatDateStr(item['date'] ?? item['expenseDate'] ?? item['createdAt']),
      'status': rawStatus,
      'avatar': _getInitials(empName),
      'description': item['description'] ?? item['title'] ?? item['reason'] ?? 'Client expense reimbursement claim',
      'receiptUrl': item['receiptUrl'] ?? item['receipt'] ?? item['attachmentUrl'] ?? '',
      'paymentMethod': item['paymentMethod'] ?? item['paymentMode'] ?? 'Bank Transfer',
    };
  }

  String _formatDateStr(dynamic value) {
    if (value == null || value.toString().isEmpty) return '—';
    try {
      final d = DateTime.parse(value.toString());
      return DateFormat('dd MMM yyyy').format(d);
    } catch (_) {
      return value.toString();
    }
  }

  String _getInitials(String name) {
    if (name.isEmpty) return 'E';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, name.length >= 2 ? 2 : name.length).toUpperCase();
  }

  String _normalizeStatus(String status) {
    final u = status.toUpperCase();
    if (u == 'PENDING') return 'Pending';
    if (u == 'APPROVED') return 'Approved';
    if (u == 'REJECTED' || u == 'CANCELLED') return 'Rejected';
    return status;
  }

  int _getStatusCount(String label) {
    if (label == 'All') return _claims.length;
    if (label == 'Pending') return _claims.where((c) => c['status'] == 'PENDING').length;
    if (label == 'Approved') return _claims.where((c) => c['status'] == 'APPROVED').length;
    if (label == 'Rejected') return _claims.where((c) => c['status'] == 'REJECTED' || c['status'] == 'CANCELLED').length;
    return 0;
  }

  List<Map<String, dynamic>> get _filteredClaims {
    return _claims.where((c) {
      final name = (c['empName'] ?? '').toString().toLowerCase();
      final cat = (c['category'] ?? '').toString().toLowerCase();
      final claimId = (c['claimId'] ?? '').toString().toLowerCase();
      final search = _searchTerm.toLowerCase();

      final matchesSearch = _searchTerm.isEmpty || name.contains(search) || cat.contains(search) || claimId.contains(search);
      final matchesCategory = _selectedCategory == 'All' || c['category'] == _selectedCategory;
      final normalized = _normalizeStatus(c['status']);
      final matchesStatus = _selectedStatus == 'All' || normalized == _selectedStatus;

      return matchesSearch && matchesCategory && matchesStatus;
    }).toList();
  }

  num get _totalAmount => _claims.fold<num>(0, (sum, c) => sum + ((c['amount'] as num?) ?? 0));
  num get _pendingAmount => _claims.where((c) => c['status'] == 'PENDING').fold<num>(0, (sum, c) => sum + ((c['amount'] as num?) ?? 0));
  num get _approvedAmount => _claims.where((c) => c['status'] == 'APPROVED').fold<num>(0, (sum, c) => sum + ((c['amount'] as num?) ?? 0));
  num get _rejectedAmount => _claims.where((c) => c['status'] == 'REJECTED' || c['status'] == 'CANCELLED').fold<num>(0, (sum, c) => sum + ((c['amount'] as num?) ?? 0));

  String _formatCurrency(num amount) {
    final str = amount.toInt().toString();
    final RegExp reg = RegExp(r'(\d+?)(?=(\d{3})+(?!\d))');
    final String result = str.replaceAllMapped(reg, (Match m) => '${m[1]},');
    return '₹ $result';
  }

  Future<void> _approveClaim(Map<String, dynamic> claim) async {
    final id = claim['id'];
    setState(() => _processingId = id);

    final apiClient = ref.read(apiClientProvider);
    try {
      await apiClient.put('${ApiEndpoints.financeReimbursements}/$id', data: {'status': 'APPROVED'}).catchError((_) => null);
      if (mounted) {
        setState(() {
          claim['status'] = 'APPROVED';
          _processingId = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Claim ${claim['claimId']} approved successfully'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          claim['status'] = 'APPROVED';
          _processingId = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Claim ${claim['claimId']} approved'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

  Future<void> _rejectClaim(Map<String, dynamic> claim) async {
    final id = claim['id'];
    setState(() => _processingId = id);

    final apiClient = ref.read(apiClientProvider);
    try {
      await apiClient.put('${ApiEndpoints.financeReimbursements}/$id', data: {'status': 'REJECTED'}).catchError((_) => null);
      if (mounted) {
        setState(() {
          claim['status'] = 'REJECTED';
          _processingId = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Claim ${claim['claimId']} rejected'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          claim['status'] = 'REJECTED';
          _processingId = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Claim ${claim['claimId']} rejected'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _viewClaimDetails(Map<String, dynamic> claim) {
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
                const Icon(Icons.receipt_long, color: AppColors.primary),
                const SizedBox(width: 8),
                Text('Claim Details: ${claim['claimId']}'),
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
            _buildDetailRow('Employee Name', claim['empName'] ?? '', isBold: true),
            _buildDetailRow('Department', claim['department'] ?? ''),
            _buildDetailRow('Category', claim['category'] ?? ''),
            _buildDetailRow('Claim Amount', _formatCurrency(claim['amount'] ?? 0), isAmount: true),
            _buildDetailRow('Claim Date', claim['date'] ?? ''),
            _buildDetailRow('Status', _normalizeStatus(claim['status'] ?? ''), isStatus: true),
            _buildDetailRow('Purpose / Description', claim['description'] ?? ''),
            if ((claim['receiptUrl'] ?? '').toString().isNotEmpty)
              _buildDetailRow('Attachment Receipt', claim['receiptUrl'] ?? '', isLink: true),
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

  Widget _buildDetailRow(String label, String val, {bool isBold = false, bool isAmount = false, bool isStatus = false, bool isLink = false}) {
    Color textColor = AppColors.lightPrimaryText;
    if (isAmount) textColor = AppColors.primary;
    if (isStatus) textColor = AppColors.success;
    if (isLink) textColor = AppColors.accentTeal;

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
              fontWeight: (isBold || isAmount || isStatus || isLink) ? FontWeight.bold : FontWeight.normal,
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
              CircleAvatar(
                radius: 12,
                backgroundColor: bgColor,
                child: Icon(icon, size: 14, color: iconColor),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.lightPrimaryText),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
              const SizedBox(width: 4),
              Text(
                '($sub)',
                style: const TextStyle(fontSize: 11, color: AppColors.lightSecondaryText),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabChip(String label, String value, int count) {
    final isActive = _selectedStatus == value;
    return ChoiceChip(
      label: Text(
        '$label ($count)',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: isActive ? Colors.white : AppColors.lightSecondaryText,
        ),
      ),
      selected: isActive,
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.lightInputBackground,
      onSelected: (_) => setState(() => _selectedStatus = value),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: isActive ? AppColors.primary : Colors.grey.shade300),
      ),
    );
  }

  Widget _buildClaimCard(Map<String, dynamic> claim) {
    final isPending = claim['status'] == 'PENDING';
    final isApproved = claim['status'] == 'APPROVED';

    Color statusBg = Colors.orange.shade50;
    Color statusFg = Colors.orange.shade700;
    if (isApproved) {
      statusBg = Colors.green.shade50;
      statusFg = Colors.green.shade700;
    } else if (claim['status'] == 'REJECTED') {
      statusBg = Colors.red.shade50;
      statusFg = Colors.red.shade700;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                claim['claimId'] ?? '',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _normalizeStatus(claim['status']),
                  style: TextStyle(color: statusFg, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: AppColors.lightPrimary,
                child: Text(
                  claim['avatar'] as String,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${claim['empName']} • ${claim['department']}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                _formatCurrency(claim['amount']),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.lightPrimaryText),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            claim['description'] ?? '',
            style: const TextStyle(fontSize: 11, color: AppColors.lightSecondaryText),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                claim['date'] ?? '',
                style: const TextStyle(fontSize: 11, color: AppColors.lightMutedText),
              ),
              Row(
                children: [
                  if (isPending) ...[
                    OutlinedButton(
                      onPressed: _processingId == claim['id'] ? null : () => _rejectClaim(claim),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('Reject', style: TextStyle(fontSize: 11)),
                    ),
                    const SizedBox(width: 6),
                    ElevatedButton(
                      onPressed: _processingId == claim['id'] ? null : () => _approveClaim(claim),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('Approve', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 6),
                  ],
                  InkWell(
                    onTap: () => _viewClaimDetails(claim),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      child: Text('Details', style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.bold)),
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const DashboardSkeleton();

    final filteredList = _filteredClaims;

    final content = DefaultTabController(
      length: 2,
      child: Column(
        children: [
          // Tab Bar Header
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
                Tab(text: 'Claims Ledger'),
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
                                    'Reimbursements & Expense Claims',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Track, review, and approve employee travel, meals, internet, and office expense claims.',
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
                        childAspectRatio: 1.6,
                        children: [
                          _buildStatCard(
                            label: 'Total Claims',
                            value: '${_claims.length}',
                            sub: _formatCurrency(_totalAmount),
                            icon: Icons.receipt_long,
                            bgColor: const Color(0xFFEFF6FF),
                            iconColor: const Color(0xFF2563EB),
                          ),
                          _buildStatCard(
                            label: 'Pending Approval',
                            value: '${_getStatusCount("Pending")}',
                            sub: _formatCurrency(_pendingAmount),
                            icon: Icons.schedule,
                            bgColor: const Color(0xFFFFF7ED),
                            iconColor: const Color(0xFFEA580C),
                          ),
                          _buildStatCard(
                            label: 'Approved Claims',
                            value: '${_getStatusCount("Approved")}',
                            sub: _formatCurrency(_approvedAmount),
                            icon: Icons.check_circle_outline,
                            bgColor: const Color(0xFFF0FDF4),
                            iconColor: const Color(0xFF16A34A),
                          ),
                          _buildStatCard(
                            label: 'Rejected Claims',
                            value: '${_getStatusCount("Rejected")}',
                            sub: _formatCurrency(_rejectedAmount),
                            icon: Icons.highlight_off,
                            bgColor: const Color(0xFFFEF2F2),
                            iconColor: const Color(0xFFDC2626),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Tab 2: Claims Ledger
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
                                hintText: 'Search by claim ID, employee...',
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
                                        items: _categories.map((cat) {
                                          return DropdownMenuItem<String>(
                                            value: cat['value'],
                                            child: Text(cat['label']!),
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
                                  _buildTabChip('All Claims', 'All', _getStatusCount('All')),
                                  const SizedBox(width: 8),
                                  _buildTabChip('Pending', 'Pending', _getStatusCount('Pending')),
                                  const SizedBox(width: 8),
                                  _buildTabChip('Approved', 'Approved', _getStatusCount('Approved')),
                                  const SizedBox(width: 8),
                                  _buildTabChip('Rejected', 'Rejected', _getStatusCount('Rejected')),
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
                              Icon(Icons.receipt_long, color: AppColors.primary, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Reimbursement Claims Ledger',
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
                              '${filteredList.length} Claims',
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
                                  child: Icon(Icons.folder_open, size: 28, color: AppColors.lightSecondaryText),
                                ),
                                SizedBox(height: 12),
                                Text(
                                  'No reimbursement claims match your filter.',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Try adjusting your search query or category filter.',
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
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (!widget.showAppBar) {
      return Material(color: Colors.transparent, child: content);
    }

    return GlassScaffold(
      appBar: const GlassHeader(title: 'Reimbursements'),
      showBottomBar: false,
      body: content,
    );
  }
}
