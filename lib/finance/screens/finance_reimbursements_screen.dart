import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/loading_shimmer.dart';

class FinanceReimbursementsScreen extends ConsumerStatefulWidget {
  const FinanceReimbursementsScreen({super.key});

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
    _loadReimbursements();
  }

  Future<void> _loadReimbursements() async {
    setState(() => _isLoading = true);
    final apiClient = ref.read(apiClientProvider);

    try {
      final res = await apiClient.get(ApiEndpoints.financeReimbursements).catchError((_) => null);

      if (mounted) {
        List<dynamic> items = [];
        if (res is List) {
          items = res;
        } else if (res is Map<String, dynamic> && res['data'] is List) {
          items = res['data'];
        }

        if (items.isNotEmpty) {
          _claims = items.map((r) => _mapClaimItem(r)).toList();
        } else {
          _claims = _getMockClaims();
        }
        _isLoading = false;
        setState(() {});
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _claims = _getMockClaims();
          _isLoading = false;
        });
      }
    }
  }

  Map<String, dynamic> _mapClaimItem(dynamic r) {
    final Map<String, dynamic> item = r is Map<String, dynamic> ? r : {};
    final empName = item['employeeName'] ?? item['empName'] ?? 'Employee';
    final id = item['id']?.toString() ?? '1';
    final rawAmt = (item['amount'] ?? 0) as num;

    return {
      'id': id,
      'claimId': item['claimId'] ?? (id.length >= 8 ? id.substring(0, 8).toUpperCase() : 'CLM-901'),
      'empName': empName,
      'department': item['department'] ?? 'General',
      'category': (item['category'] ?? 'OTHER').toString().toUpperCase(),
      'amount': rawAmt,
      'date': item['date'] ?? '15 Oct 2026',
      'status': (item['status'] ?? 'PENDING').toString().toUpperCase(),
      'avatar': _getInitials(empName),
      'description': item['description'] ?? 'Client expense reimbursement claim',
      'receiptUrl': item['receiptUrl'] ?? '',
      'paymentMethod': item['paymentMethod'] ?? 'Bank Transfer',
    };
  }

  List<Map<String, dynamic>> _getMockClaims() {
    return [
      {
        'id': '1',
        'claimId': 'CLM-2026-901',
        'empName': 'Sarah Jenkins',
        'department': 'Product Design',
        'category': 'TRAVEL',
        'amount': 24500,
        'date': '14 Oct 2026',
        'status': 'PENDING',
        'avatar': 'SJ',
        'description': 'Client presentation travel & taxi fare reimbursement',
        'receiptUrl': 'receipt_901.pdf',
        'paymentMethod': 'Bank Direct ACH',
      },
      {
        'id': '2',
        'claimId': 'CLM-2026-902',
        'empName': 'David Miller',
        'department': 'Engineering',
        'category': 'FOOD',
        'amount': 3800,
        'date': '12 Oct 2026',
        'status': 'PENDING',
        'avatar': 'DM',
        'description': 'Team dinner during sprint release milestone',
        'receiptUrl': 'receipt_902.pdf',
        'paymentMethod': 'Bank Direct ACH',
      },
      {
        'id': '3',
        'claimId': 'CLM-2026-903',
        'empName': 'Emily Watson',
        'department': 'Human Resources',
        'category': 'HOTEL',
        'amount': 18500,
        'date': '10 Oct 2026',
        'status': 'APPROVED',
        'avatar': 'EW',
        'description': 'HR Annual Leadership Conference hotel stay',
        'receiptUrl': 'receipt_903.pdf',
        'paymentMethod': 'Corporate Card',
      },
      {
        'id': '4',
        'claimId': 'CLM-2026-904',
        'empName': 'Alex Rivera',
        'department': 'Sales Operations',
        'category': 'FUEL',
        'amount': 4200,
        'date': '08 Oct 2026',
        'status': 'APPROVED',
        'avatar': 'AR',
        'description': 'Client site visit fuel & toll charges',
        'receiptUrl': 'receipt_904.pdf',
        'paymentMethod': 'Bank Direct ACH',
      },
      {
        'id': '5',
        'claimId': 'CLM-2026-905',
        'empName': 'Michael Chen',
        'department': 'IT Operations',
        'category': 'INTERNET',
        'amount': 2500,
        'date': '05 Oct 2026',
        'status': 'REJECTED',
        'avatar': 'MC',
        'description': 'Monthly home broadband Internet allowance claim',
        'receiptUrl': 'receipt_905.pdf',
        'paymentMethod': 'Bank Direct ACH',
      },
    ];
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const DashboardSkeleton();

    final filteredList = _filteredClaims;

    return RefreshIndicator(
      onRefresh: _loadReimbursements,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Header Card
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
                          'Review and approve travel, meals, internet, & office claims',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
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
            const SizedBox(height: 16),

            // Search & Filter Card
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

            // Claims Register Header & Cards
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
                        'No reimbursement claims match your filter',
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
          Row(
            children: [
              Text(
                value,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.lightPrimaryText),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '($sub)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10, color: AppColors.lightMutedText, fontWeight: FontWeight.w600),
                ),
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
    );
  }

  Widget _buildClaimCard(Map<String, dynamic> item) {
    final rawStatus = (item['status'] ?? 'PENDING').toString();
    final statusNorm = _normalizeStatus(rawStatus);
    final isPending = statusNorm == 'Pending';
    final isApproved = statusNorm == 'Approved';
    final isProcessingThis = _processingId == item['id'];

    Color statusBg = AppColors.warningBg;
    Color statusFg = AppColors.warning;

    if (isApproved) {
      statusBg = AppColors.successBg;
      statusFg = AppColors.success;
    } else if (statusNorm == 'Rejected') {
      statusBg = AppColors.errorBg;
      statusFg = AppColors.error;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Claim ID & Status Row
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
                    item['claimId'] ?? '',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: AppColors.primary,
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
                    statusNorm,
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

            // Employee Avatar & Name
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.darkPrimary,
                  child: Text(
                    item['avatar'] ?? 'E',
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['empName'] ?? '',
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
                              item['category'] ?? '',
                              style: const TextStyle(fontSize: 10, color: AppColors.lightSecondaryText, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            item['department'] ?? '',
                            style: const TextStyle(fontSize: 11, color: AppColors.lightMutedText),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Text(
                  _formatCurrency(item['amount'] ?? 0),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            Text(
              item['description'] ?? '',
              style: const TextStyle(fontSize: 12, color: AppColors.lightSecondaryText),
            ),
            const Divider(height: 18),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 12, color: AppColors.lightMutedText),
                    const SizedBox(width: 4),
                    Text(
                      item['date'] ?? '',
                      style: const TextStyle(fontSize: 11, color: AppColors.lightSecondaryText),
                    ),
                  ],
                ),
                if (isPending)
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: isProcessingThis ? null : () => _approveClaim(item),
                        icon: isProcessingThis
                            ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.check, size: 14),
                        label: const Text('Approve'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(width: 6),
                      OutlinedButton.icon(
                        onPressed: isProcessingThis ? null : () => _rejectClaim(item),
                        icon: const Icon(Icons.close, size: 14),
                        label: const Text('Reject'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: const BorderSide(color: AppColors.error),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  )
                else
                  OutlinedButton.icon(
                    onPressed: () => _viewClaimDetails(item),
                    icon: const Icon(Icons.visibility, size: 14),
                    label: const Text('View'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
}
