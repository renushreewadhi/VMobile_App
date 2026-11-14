import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_header.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/loading_shimmer.dart';

class FinanceApprovalsScreen extends ConsumerStatefulWidget {
  final bool? showAppBar;
  const FinanceApprovalsScreen({super.key, this.showAppBar = false});

  @override
  ConsumerState<FinanceApprovalsScreen> createState() => _FinanceApprovalsScreenState();
}

class _FinanceApprovalsScreenState extends ConsumerState<FinanceApprovalsScreen> {
  String _searchTerm = '';
  String _selectedCategory = 'All';
  String _selectedStatus = 'All'; // 'All', 'Pending Review', 'Approved', 'Rejected'
  bool _isLoading = true;

  final List<String> _categories = [
    'All',
    'Travel & Expense',
    'Personal Loan',
    'IT Procurement',
    'Employee Benefits',
  ];

  final List<String> _statuses = [
    'All',
    'Pending Review',
    'Approved',
    'Rejected',
  ];

  List<Map<String, dynamic>> _approvals = [];

  final List<Map<String, String>> _policyLimits = [
    {
      'role': 'Department Manager',
      'limit': 'Up to ₹50,000',
      'desc': 'Standard Approval',
    },
    {
      'role': 'Finance Controller',
      'limit': 'Up to ₹2,50,000',
      'desc': 'Manager + Finance Sign-off',
    },
    {
      'role': 'VP of Finance / CFO',
      'limit': '₹2,50,000+',
      'desc': 'Executive Board Approval',
    },
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadApprovals();
    });
  }

  Future<void> _loadApprovals() async {
    setState(() => _isLoading = true);
    final apiClient = ref.read(apiClientProvider);

    try {
      final data = await apiClient.get(ApiEndpoints.financeApprovals).catchError((_) => null);

      if (mounted) {
        if (data != null) {
          List<dynamic> itemsList = [];
          if (data is List) {
            itemsList = data;
          } else if (data is Map<String, dynamic>) {
            final items = data['data'] ?? data['items'] ?? data['result'] ?? data['approvals'];
            if (items is List) {
              itemsList = items;
            }
          }

          _approvals = itemsList.map((a) => _mapApprovalItem(a)).toList();
        } else {
          _approvals = [];
        }
        _isLoading = false;
        setState(() {});
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _approvals = [];
          _isLoading = false;
        });
      }
    }
  }

  Map<String, dynamic> _mapApprovalItem(dynamic a) {
    final Map<String, dynamic> item = a is Map<String, dynamic> ? a : {};
    final requester = item['employeeName'] ?? item['requestedBy'] ?? item['userName'] ?? 'Staff Member';
    final parts = requester.toString().trim().split(' ');
    final initials = parts.length > 1
        ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
        : (requester.toString().length >= 2
            ? requester.toString().substring(0, 2).toUpperCase()
            : 'SM');

    String rawStatus = item['status']?.toString() ?? 'Pending Review';
    if (rawStatus.toLowerCase() == 'pending') {
      rawStatus = 'Pending Review';
    } else if (rawStatus.isNotEmpty) {
      rawStatus = rawStatus[0].toUpperCase() + rawStatus.substring(1).toLowerCase();
    }

    final rawAmt = (item['amount'] ?? 0) as num;

    return {
      'reqId': item['reqId'] ?? (item['id'] != null ? item['id'].toString().substring(0, 8).toUpperCase() : 'APR-901'),
      'rawId': item['id'] ?? item['reqId'],
      'type': item['title'] ?? item['approvalTitle'] ?? item['description'] ?? 'Expense Reimbursement Claim',
      'category': item['category'] ?? item['requestType'] ?? 'Travel & Expense',
      'requestedBy': requester,
      'department': item['department'] ?? item['dept'] ?? 'Engineering',
      'amount': _formatCurrency(rawAmt),
      'rawAmount': rawAmt,
      'date': item['date'] ?? item['createdAt'] ?? '15 Oct 2026',
      'status': rawStatus,
      'initials': initials,
    };
  }

  String _formatCurrency(num amount) {
    final str = amount.toInt().toString();
    final RegExp reg = RegExp(r'(\d+?)(?=(\d{3})+(?!\d))');
    final String result = str.replaceAllMapped(reg, (Match m) => '${m[1]},');
    return '₹$result';
  }

  List<Map<String, dynamic>> get _filteredApprovals {
    return _approvals.where((item) {
      final reqBy = (item['requestedBy'] ?? '').toString().toLowerCase();
      final type = (item['type'] ?? '').toString().toLowerCase();
      final reqId = (item['reqId'] ?? '').toString().toLowerCase();
      final dept = (item['department'] ?? '').toString().toLowerCase();
      final search = _searchTerm.toLowerCase();

      final matchesSearch = _searchTerm.isEmpty ||
          reqBy.contains(search) ||
          type.contains(search) ||
          reqId.contains(search) ||
          dept.contains(search);

      final cat = (item['category'] ?? '').toString().toLowerCase();
      final matchesCategory = _selectedCategory == 'All' ||
          cat.contains(_selectedCategory.toLowerCase());

      final status = item['status']?.toString() ?? '';
      final matchesStatus = _selectedStatus == 'All' ||
          status == _selectedStatus ||
          (_selectedStatus == 'Pending Review' && status == 'Pending');

      return matchesSearch && matchesCategory && matchesStatus;
    }).toList();
  }

  int get _pendingCount => _approvals.where((a) => a['status'] == 'Pending Review' || a['status'] == 'Pending').length;
  int get _approvedCount => _approvals.where((a) => a['status'] == 'Approved' || a['status'] == 'APPROVED').length;
  int get _rejectedCount => _approvals.where((a) => a['status'] == 'Rejected' || a['status'] == 'REJECTED').length;

  Future<void> _approve(Map<String, dynamic> item) async {
    setState(() {
      item['status'] = 'Approved';
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Request ${item['reqId']} has been Approved'),
          backgroundColor: AppColors.success,
        ),
      );
    }

    final apiClient = ref.read(apiClientProvider);
    try {
      await apiClient.put('${ApiEndpoints.financeApprovals}/${item['rawId'] ?? item['reqId']}', data: {'status': 'APPROVED'}).catchError((_) => null);
    } catch (_) {}
  }

  Future<void> _reject(Map<String, dynamic> item) async {
    setState(() {
      item['status'] = 'Rejected';
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Request ${item['reqId']} has been Rejected'),
          backgroundColor: AppColors.error,
        ),
      );
    }

    final apiClient = ref.read(apiClientProvider);
    try {
      await apiClient.put('${ApiEndpoints.financeApprovals}/${item['rawId'] ?? item['reqId']}', data: {'status': 'REJECTED'}).catchError((_) => null);
    } catch (_) {}
  }

  void _viewDetails(Map<String, dynamic> item) {
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
                Text('Approval Ref: ${item['reqId']}'),
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
            _buildDetailRow('Title / Type', item['type'] ?? '', isBold: true),
            _buildDetailRow('Category', item['category'] ?? ''),
            _buildDetailRow('Requested By', item['requestedBy'] ?? ''),
            _buildDetailRow('Department', item['department'] ?? ''),
            _buildDetailRow('Amount Requested', item['amount'] ?? '', isAmount: true),
            _buildDetailRow('Date', item['date'] ?? ''),
            _buildDetailRow('Status', item['status'] ?? '', isPrimary: true),
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
    if (isAmount) textColor = AppColors.primary;
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

  Widget _buildApprovalCard(Map<String, dynamic> item) {
    final status = item['status']?.toString() ?? 'Pending Review';
    final isPending = status == 'Pending Review' || status == 'Pending';

    Color statusBg = AppColors.warningBg;
    Color statusFg = AppColors.warning;
    if (status == 'Approved') {
      statusBg = AppColors.successBg;
      statusFg = AppColors.success;
    } else if (status == 'Rejected') {
      statusBg = AppColors.errorBg;
      statusFg = AppColors.error;
    }

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
                  item['reqId'] ?? '',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primary),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(status, style: TextStyle(color: statusFg, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(item['type'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 2),
          Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: AppColors.lightPrimary,
                child: Text(
                  item['initials'] as String,
                  style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 10),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${item['requestedBy']} • ${item['department']}',
                  style: const TextStyle(fontSize: 11, color: AppColors.lightSecondaryText),
                ),
              ),
              Text(
                item['amount'] as String,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Date: ${item['date']}', style: const TextStyle(fontSize: 11, color: AppColors.lightMutedText)),
              Row(
                children: [
                  if (isPending) ...[
                    OutlinedButton(
                      onPressed: () => _reject(item),
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
                      onPressed: () => _approve(item),
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
                  OutlinedButton.icon(
                    onPressed: () => _viewDetails(item),
                    icon: const Icon(Icons.visibility_outlined, size: 14),
                    label: const Text('Details'),
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
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const DashboardSkeleton();

    final filteredList = _filteredApprovals;
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
                Tab(text: 'Authorization Queue'),
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
                                  child: Icon(Icons.verified_user, color: Colors.white, size: 26),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: const [
                                      Text(
                                        'Finance Approvals & Queue',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        'Review and authorize high-value reimbursement claims, personal loans, IT procurement, and budget requests',
                                        style: TextStyle(color: Colors.white70, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(Icons.security, color: Colors.white, size: 14),
                                  SizedBox(width: 6),
                                  Text(
                                    'SLA Target: 24 Hours',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
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
                            label: 'Pending Approvals',
                            value: '$_pendingCount',
                            sub: 'Awaiting review',
                            icon: Icons.hourglass_empty,
                            bgColor: const Color(0xFFFFF7ED),
                            iconColor: const Color(0xFFEA580C),
                          ),
                          _buildStatCard(
                            label: 'Approved This Month',
                            value: '$_approvedCount',
                            sub: 'Disbursed successfully',
                            icon: Icons.check_circle_outline,
                            bgColor: const Color(0xFFF0FDF4),
                            iconColor: const Color(0xFF16A34A),
                          ),
                          _buildStatCard(
                            label: 'Rejected / Returned',
                            value: '$_rejectedCount',
                            sub: 'Returned claims',
                            icon: Icons.highlight_off,
                            bgColor: const Color(0xFFFEF2F2),
                            iconColor: const Color(0xFFDC2626),
                          ),
                          _buildStatCard(
                            label: 'Average Review SLA',
                            value: '4.2 hrs',
                            sub: '24hr SLA target',
                            icon: Icons.bolt,
                            bgColor: const Color(0xFFEFF6FF),
                            iconColor: const Color(0xFF2563EB),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Approval Threshold Matrix Card
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
                                      Icon(Icons.account_tree, color: AppColors.primary, size: 18),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Corporate Approval Threshold Matrix',
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(width: 8),
                                Text('Governance Policy', style: TextStyle(fontSize: 11, color: AppColors.lightSecondaryText)),
                              ],
                            ),
                            const Divider(height: 20),
                            ..._policyLimits.map((pol) {
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
                                          Text(pol['role'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                          const SizedBox(height: 2),
                                          Text(pol['desc'] ?? '', style: const TextStyle(fontSize: 11, color: AppColors.lightSecondaryText)),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      pol['limit'] ?? '',
                                      style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Audit & Compliance Card
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
                                      Icon(Icons.fact_check, color: AppColors.primary, size: 18),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Audit & Compliance Sign-off',
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(width: 8),
                                Text('100% Compliant', style: TextStyle(fontSize: 11, color: AppColors.success, fontWeight: FontWeight.bold)),
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
                                  Icon(Icons.verified, color: AppColors.primary, size: 20),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Vouched Expense Verification', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                        Text('Receipts above ₹1,000 must include tax invoice copy and manager signoff.', style: TextStyle(fontSize: 10.5, color: AppColors.lightSecondaryText)),
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
                                  Icon(Icons.history_toggle_off, color: AppColors.primary, size: 20),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Immutable Audit Trail', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                        Text('All decision timestamps and approver user IDs are permanently logged.', style: TextStyle(fontSize: 10.5, color: AppColors.lightSecondaryText)),
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

                // Tab 2: Authorization Queue
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
                                hintText: 'Search by ID, title, requester, or dept...',
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
                                            child: Text(c == 'All' ? 'All Categories' : c),
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
                                  _buildTabChip('All', 'All', _approvals.length),
                                  const SizedBox(width: 8),
                                  _buildTabChip('Pending', 'Pending Review', _pendingCount),
                                  const SizedBox(width: 8),
                                  _buildTabChip('Approved', 'Approved', _approvedCount),
                                  const SizedBox(width: 8),
                                  _buildTabChip('Rejected', 'Rejected', _rejectedCount),
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
                                    'Pending & Recent Authorization Requests',
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
                              '${filteredList.length} Requests Listed',
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
                                  child: Icon(Icons.how_to_reg_outlined, size: 28, color: AppColors.lightSecondaryText),
                                ),
                                SizedBox(height: 12),
                                Text(
                                  'No approval requests found',
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
                            return _buildApprovalCard(item);
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
      appBar: const GlassHeader(title: 'Finance Approvals'),
      showBottomBar: false,
      body: content,
    );
  }
}
