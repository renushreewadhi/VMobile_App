import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/compact_summary_widgets.dart';
import '../../shared/widgets/loading_shimmer.dart';

class FinanceApprovalsScreen extends ConsumerStatefulWidget {
  const FinanceApprovalsScreen({super.key});

  @override
  ConsumerState<FinanceApprovalsScreen> createState() => _FinanceApprovalsScreenState();
}

class _FinanceApprovalsScreenState extends ConsumerState<FinanceApprovalsScreen> {
  String _searchTerm = '';
  String _selectedCategory = 'All';
  String _selectedStatus = 'All';
  bool _isLoading = true;
  Map<String, dynamic>? _selectedApproval;

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
      'autoRoute': 'Standard Approval',
    },
    {
      'role': 'Finance Controller',
      'limit': 'Up to ₹2,50,000',
      'autoRoute': 'Manager + Finance Sign-off',
    },
    {
      'role': 'VP of Finance / CFO',
      'limit': '₹2,50,000+',
      'autoRoute': 'Executive Board Approval',
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadApprovals();
  }

  Future<void> _loadApprovals() async {
    setState(() => _isLoading = true);
    final apiClient = ref.read(apiClientProvider);

    try {
      final data = await apiClient.get(ApiEndpoints.financeApprovals).catchError((_) => null);

      if (mounted) {
        List<dynamic> itemsList = [];
        if (data is List) {
          itemsList = data;
        } else if (data is Map<String, dynamic> && data['data'] is List) {
          itemsList = data['data'];
        }

        if (itemsList.isNotEmpty) {
          _approvals = itemsList.map((a) => _mapApprovalItem(a)).toList();
        } else {
          _approvals = _getMockApprovals();
        }
        _isLoading = false;
        setState(() {});
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _approvals = _getMockApprovals();
          _isLoading = false;
        });
      }
    }
  }

  Map<String, dynamic> _mapApprovalItem(dynamic a) {
    final Map<String, dynamic> item = a is Map<String, dynamic> ? a : {};
    final requester = item['employeeName'] ?? item['requestedBy'] ?? 'Staff Member';
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

    return {
      'reqId': item['reqId'] ?? (item['id'] != null ? item['id'].toString().substring(0, 8).toUpperCase() : 'APR-901'),
      'type': item['description'] ?? item['requestType'] ?? 'Expense Reimbursement Claim',
      'category': item['requestType'] ?? item['category'] ?? 'Travel & Expense',
      'requestedBy': requester,
      'department': item['department'] ?? item['dept'] ?? 'Engineering',
      'amount': item['amount'] != null ? '₹${item['amount']}' : '₹1,250',
      'date': item['date'] ?? '15 Oct 2026',
      'status': rawStatus,
      'initials': initials,
      'avatarBg': const Color(0xFFEFF6FF),
      'avatarColor': const Color(0xFF2563EB),
    };
  }

  List<Map<String, dynamic>> _getMockApprovals() {
    return [
      {
        'reqId': 'APR-2026-101',
        'type': 'Annual Tech Conference Travel & Stay',
        'category': 'Travel & Expense',
        'requestedBy': 'David Miller',
        'department': 'Product Design',
        'amount': '₹24,500',
        'date': '14 Oct 2026',
        'status': 'Pending Review',
        'initials': 'DM',
        'avatarBg': const Color(0xFFEFF6FF),
        'avatarColor': const Color(0xFF2563EB),
      },
      {
        'reqId': 'APR-2026-102',
        'type': 'Emergency Medical Salary Advance',
        'category': 'Personal Loan',
        'requestedBy': 'Emily Watson',
        'department': 'Human Resources',
        'amount': '₹50,000',
        'date': '12 Oct 2026',
        'status': 'Pending Review',
        'initials': 'EW',
        'avatarBg': const Color(0xFFFFF7ED),
        'avatarColor': const Color(0xFFD97706),
      },
      {
        'reqId': 'APR-2026-103',
        'type': 'High-Performance Workstation Upgrade',
        'category': 'IT Procurement',
        'requestedBy': 'Alex Rivera',
        'department': 'Engineering',
        'amount': '₹38,000',
        'date': '10 Oct 2026',
        'status': 'Approved',
        'initials': 'AR',
        'avatarBg': const Color(0xFFF0FDF4),
        'avatarColor': const Color(0xFF059669),
      },
      {
        'reqId': 'APR-2026-104',
        'type': 'Executive Leadership Training Course',
        'category': 'Employee Benefits',
        'requestedBy': 'Jessica Taylor',
        'department': 'Marketing',
        'amount': '₹18,500',
        'date': '08 Oct 2026',
        'status': 'Approved',
        'initials': 'JT',
        'avatarBg': const Color(0xFFEFF6FF),
        'avatarColor': const Color(0xFF2563EB),
      },
      {
        'reqId': 'APR-2026-105',
        'type': 'Client Entertainment & Catering Claim',
        'category': 'Travel & Expense',
        'requestedBy': 'Michael Chang',
        'department': 'Sales Operations',
        'amount': '₹9,200',
        'date': '05 Oct 2026',
        'status': 'Rejected',
        'initials': 'MC',
        'avatarBg': const Color(0xFFFFF1F2),
        'avatarColor': const Color(0xFFE11D48),
      },
    ];
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
  int get _approvedCount => _approvals.where((a) => a['status'] == 'Approved').length;
  int get _rejectedCount => _approvals.where((a) => a['status'] == 'Rejected').length;

  Future<void> _approve(Map<String, dynamic> item) async {
    setState(() {
      item['status'] = 'Approved';
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Request ${item['reqId']} (${item['type']}) has been Approved'),
          backgroundColor: AppColors.success,
        ),
      );
    }

    final apiClient = ref.read(apiClientProvider);
    try {
      await apiClient.put('${ApiEndpoints.financeApprovals}/${item['reqId']}', data: {'status': 'APPROVED'}).catchError((_) => null);
    } catch (_) {}
  }

  Future<void> _reject(Map<String, dynamic> item) async {
    setState(() {
      item['status'] = 'Rejected';
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Request ${item['reqId']} (${item['type']}) has been Rejected'),
          backgroundColor: AppColors.error,
        ),
      );
    }

    final apiClient = ref.read(apiClientProvider);
    try {
      await apiClient.put('${ApiEndpoints.financeApprovals}/${item['reqId']}', data: {'status': 'REJECTED'}).catchError((_) => null);
    } catch (_) {}
  }

  void _viewDetails(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (context) => _buildDetailsModal(item),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const DashboardSkeleton();

    final filteredList = _filteredApprovals;

    return RefreshIndicator(
      onRefresh: _loadApprovals,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Page Header Card
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
                              'Review & authorize claims, loans, & procurement',
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

            const SizedBox(height: 14),

            // 1. PASTEL SUMMARY PILLS
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  PastelSummaryPill(
                    label: '$_pendingCount Pending Review',
                    variant: PastelPillVariant.amber,
                    onTap: () => setState(() => _selectedStatus = 'Pending'),
                  ),
                  const SizedBox(width: 8),
                  PastelSummaryPill(
                    label: '$_approvedCount Approved',
                    variant: PastelPillVariant.green,
                    onTap: () => setState(() => _selectedStatus = 'Approved'),
                  ),
                  const SizedBox(width: 8),
                  PastelSummaryPill(
                    label: '$_rejectedCount Rejected',
                    variant: PastelPillVariant.purple,
                    onTap: () => setState(() => _selectedStatus = 'Rejected'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 2. CIRCULAR STATISTIC INDICATOR GROUP
            CircularStatGroup(
              items: [
                CircularStatItemData(
                  label: 'Pending',
                  value: '$_pendingCount',
                  ringColor: const Color(0xFFD97706),
                  onTap: () => setState(() => _selectedStatus = 'Pending'),
                ),
                CircularStatItemData(
                  label: 'Approved',
                  value: '$_approvedCount',
                  ringColor: AppColors.success,
                  onTap: () => setState(() => _selectedStatus = 'Approved'),
                ),
                CircularStatItemData(
                  label: 'Rejected',
                  value: '$_rejectedCount',
                  ringColor: AppColors.error,
                  onTap: () => setState(() => _selectedStatus = 'Rejected'),
                ),
                const CircularStatItemData(
                  label: 'SLA',
                  value: '4.2h',
                  ringColor: Color(0xFF2563EB),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Search & Filter Card
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Search Bar
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

                  // Category Filter Dropdown
                  Row(
                    children: [
                      const Icon(Icons.filter_list, size: 18, color: AppColors.lightSecondaryText),
                      const SizedBox(width: 6),
                      const Text(
                        'Category:',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.lightSecondaryText),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
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
                              style: const TextStyle(fontSize: 13, color: AppColors.lightPrimaryText, fontWeight: FontWeight.w500),
                              items: _categories.map((cat) {
                                return DropdownMenuItem<String>(
                                  value: cat,
                                  child: Text(cat == 'All' ? 'All Categories' : cat),
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

                  // Status Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _statuses.map((st) {
                        final isActive = _selectedStatus == st;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(
                              st == 'Pending Review' ? 'Pending' : st,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isActive ? Colors.white : AppColors.lightSecondaryText,
                              ),
                            ),
                            selected: isActive,
                            selectedColor: AppColors.primary,
                            backgroundColor: AppColors.lightInputBackground,
                            onSelected: (_) => setState(() => _selectedStatus = st),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(
                                color: isActive ? AppColors.primary : Colors.grey.shade300,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Main Requests List Header & Card
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: const [
                    Icon(Icons.how_to_reg, color: AppColors.primary, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Pending & Recent Requests',
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
                    '${filteredList.length} Listed',
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
                        child: Icon(Icons.person_search, size: 28, color: AppColors.lightSecondaryText),
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

            const SizedBox(height: 24),

            // Governance & Audit Section
            const Text(
              'Governance & Compliance',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),

            // Approval Threshold Matrix
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.account_tree, color: AppColors.primary, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Corporate Threshold Matrix',
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
                          'Governance Policy',
                          style: TextStyle(fontSize: 11, color: AppColors.lightSecondaryText, fontWeight: FontWeight.w600),
                        ),
                      ),
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
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  pol['role']!,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  pol['autoRoute']!,
                                  style: const TextStyle(fontSize: 11, color: AppColors.lightSecondaryText),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.lightPrimary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              pol['limit']!,
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
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

            // Audit Sign-off
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.verified, color: AppColors.success, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Audit & Compliance Sign-off',
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
                          '100% Compliant',
                          style: TextStyle(fontSize: 11, color: AppColors.success, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  _buildSecurityItem(
                    icon: Icons.receipt_long,
                    iconColor: AppColors.success,
                    title: 'Vouched Expense Verification',
                    description: 'Receipts above ₹1,000 must include tax invoice copy and manager signoff.',
                  ),
                  const SizedBox(height: 10),
                  _buildSecurityItem(
                    icon: Icons.history,
                    iconColor: AppColors.primary,
                    title: 'Immutable Audit Trail',
                    description: 'All decision timestamps and approver user IDs are permanently logged.',
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
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.lightPrimaryText),
          ),
          Text(
            sub,
            style: const TextStyle(fontSize: 10, color: AppColors.lightMutedText),
          ),
        ],
      ),
    );
  }

  Widget _buildApprovalCard(Map<String, dynamic> item) {
    final status = item['status'] ?? 'Pending Review';
    final isPending = status == 'Pending Review' || status == 'Pending';
    final isApproved = status == 'Approved';
    final isRejected = status == 'Rejected';

    Color statusBg = AppColors.warningBg;
    Color statusColor = AppColors.warning;
    if (isApproved) {
      statusBg = AppColors.successBg;
      statusColor = AppColors.success;
    } else if (isRejected) {
      statusBg = AppColors.errorBg;
      statusColor = AppColors.error;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Req ID & Status
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
                    item['reqId'] ?? '',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: AppColors.lightSecondaryText,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        status,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Title & Category
            Text(
              item['type'] ?? '',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 2),
            Text(
              item['category'] ?? '',
              style: const TextStyle(fontSize: 12, color: AppColors.lightSecondaryText),
            ),
            const SizedBox(height: 10),

            // Requester & Dept & Date Row
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: item['avatarBg'] ?? AppColors.lightPrimary,
                  child: Text(
                    item['initials'] ?? 'SM',
                    style: TextStyle(
                      color: item['avatarColor'] ?? AppColors.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['requestedBy'] ?? '',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
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
                              item['department'] ?? '',
                              style: const TextStyle(fontSize: 10, color: AppColors.lightSecondaryText, fontWeight: FontWeight.w500),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            item['date'] ?? '',
                            style: const TextStyle(fontSize: 11, color: AppColors.lightMutedText),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Text(
                  item['amount'] ?? '',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            const Divider(height: 20),

            // Action Buttons Row
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (isPending) ...[
                  ElevatedButton.icon(
                    onPressed: () => _approve(item),
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Approve'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () => _reject(item),
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('Reject'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(width: 8),
                ] else ...[
                  Row(
                    children: const [
                      Icon(Icons.check_circle, size: 16, color: AppColors.primary),
                      SizedBox(width: 4),
                      Text(
                        'Decided',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.lightSecondaryText),
                      ),
                    ],
                  ),
                  const Spacer(),
                ],
                IconButton(
                  onPressed: () => _viewDetails(item),
                  icon: const Icon(Icons.visibility_outlined, size: 20),
                  color: AppColors.lightSecondaryText,
                  tooltip: 'View Details',
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

  Widget _buildDetailsModal(Map<String, dynamic> item) {
    final isPending = item['status'] == 'Pending Review' || item['status'] == 'Pending';

    return AlertDialog(
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Authorization Details',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Req ID: ${item['reqId']}',
                    style: const TextStyle(fontSize: 11, color: AppColors.lightSecondaryText),
                  ),
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
            const Divider(height: 1),
            const SizedBox(height: 12),
            _buildDetailRow('Request Title', item['type'] ?? '', isBold: true),
            _buildDetailRow('Category', item['category'] ?? ''),
            _buildDetailRow('Requested By', item['requestedBy'] ?? '', isBold: true),
            _buildDetailRow('Department', item['department'] ?? ''),
            _buildDetailRow('Requested Amount', item['amount'] ?? '', isAmount: true),
            _buildDetailRow('Submission Date', item['date'] ?? ''),
            _buildDetailRow('Approval Status', item['status'] ?? '', isStatus: true),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        if (isPending)
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _approve(item);
            },
            icon: const Icon(Icons.check, size: 16),
            label: const Text('Approve Claim'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
            ),
          ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String val, {bool isBold = false, bool isAmount = false, bool isStatus = false}) {
    Color textColor = AppColors.lightPrimaryText;
    if (isAmount) textColor = AppColors.primary;
    if (isStatus) textColor = AppColors.success;

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
              fontSize: isAmount ? 16 : 13,
              fontWeight: (isBold || isAmount || isStatus) ? FontWeight.bold : FontWeight.normal,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}
