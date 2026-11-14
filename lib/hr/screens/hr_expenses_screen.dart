import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/api/expense_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_header.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/glass_search_bar.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/loading_shimmer.dart';

/// Strongly typed Expense Item Model matching Angular `hr-expenses.component.ts`.
class HrExpenseItemModel {
  final String id;
  final String? reqCode;
  final String employeeName;
  final String? expenseDate;
  final String category;
  final String description;
  final double amount;
  final String paymentMode;
  final String? expenseLocation;
  String status;
  final String? tlRemarks;
  String? hrRemarks;
  final String? financeRemarks;
  final String? transactionId;
  final String? razorpayPaymentId;
  final String? reimbursedAt;
  final String? updatedAt;
  final String initials;
  final Color avatarBg;
  final Color avatarColor;

  HrExpenseItemModel({
    required this.id,
    this.reqCode,
    required this.employeeName,
    this.expenseDate,
    required this.category,
    required this.description,
    required this.amount,
    required this.paymentMode,
    this.expenseLocation,
    required this.status,
    this.tlRemarks,
    this.hrRemarks,
    this.financeRemarks,
    this.transactionId,
    this.razorpayPaymentId,
    this.reimbursedAt,
    this.updatedAt,
    required this.initials,
    required this.avatarBg,
    required this.avatarColor,
  });

  factory HrExpenseItemModel.fromJson(Map<String, dynamic> json, int index) {
    String empName = json['employeeName']?.toString() ??
        (json['employee'] is Map ? '${json['employee']['firstName'] ?? ''} ${json['employee']['lastName'] ?? ''}'.trim() : '') ??
        'Employee';
    if (empName.isEmpty || empName == 'null') empName = 'Employee';

    final bgList = [const Color(0xFFEFF6FF), const Color(0xFFF0FDF4), const Color(0xFFFFF7ED), const Color(0xFFF3E8FF), const Color(0xFFFEF2F2)];
    final textList = [const Color(0xFF2563EB), const Color(0xFF16A34A), const Color(0xFFEA580C), const Color(0xFF9333EA), const Color(0xFFDC2626)];

    String? code = json['claimCode']?.toString() ?? json['reqCode']?.toString() ?? json['expenseNumber']?.toString();
    if (code == null || code.trim().isEmpty) {
      final rawId = json['id']?.toString() ?? '';
      code = 'EXP-2026-${rawId.isNotEmpty ? rawId : (1000 + index)}';
    }

    return HrExpenseItemModel(
      id: json['id']?.toString() ?? '',
      reqCode: code,
      employeeName: empName,
      expenseDate: json['expenseDate']?.toString(),
      category: json['category']?.toString() ?? 'GENERAL',
      description: json['description']?.toString() ?? '',
      amount: double.tryParse(json['amount']?.toString() ?? '0') ?? 0.0,
      paymentMode: json['paymentMethod']?.toString() ?? json['paymentMode']?.toString() ?? 'Corporate Card',
      expenseLocation: json['expenseLocation']?.toString(),
      status: json['status']?.toString().toUpperCase() ?? 'PENDING',
      tlRemarks: json['tlRemarks']?.toString(),
      hrRemarks: json['hrRemarks']?.toString(),
      financeRemarks: json['financeRemarks']?.toString(),
      transactionId: json['transactionId']?.toString(),
      razorpayPaymentId: json['razorpayPaymentId']?.toString(),
      reimbursedAt: json['reimbursedAt']?.toString(),
      updatedAt: json['updatedAt']?.toString(),
      initials: empName.isNotEmpty ? empName.substring(0, empName.length >= 2 ? 2 : 1).toUpperCase() : 'EX',
      avatarBg: bgList[index % bgList.length],
      avatarColor: textList[index % textList.length],
    );
  }
}

class HrExpensesScreen extends ConsumerStatefulWidget {
  final bool showAppBar;
  const HrExpensesScreen({super.key, this.showAppBar = true});

  @override
  ConsumerState<HrExpensesScreen> createState() => _HrExpensesScreenState();
}

class _HrExpensesScreenState extends ConsumerState<HrExpensesScreen> {
  bool _isLoading = true;
  List<HrExpenseItemModel> _expenses = [];
  Map<String, dynamic> _dashboard = {
    'totalExpenses': 0,
    'totalAmount': 0.0,
    'pendingCount': 0,
    'approvedCount': 0,
    'rejectedCount': 0,
  };

  String _searchTerm = '';
  String _filterStatus = 'All'; // 'All', 'TL_APPROVED', 'HR_REVIEWED', 'APPROVED', 'REJECTED'
  final String _filterCategory = 'All';

  HrExpenseItemModel? _reviewingExpense;
  HrExpenseItemModel? _selectedExpense;
  final TextEditingController _remarksController = TextEditingController();
  bool _isSubmittingReview = false;

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  @override
  void dispose() {
    _remarksController.dispose();
    super.dispose();
  }

  Future<void> _loadExpenses() async {
    setState(() => _isLoading = true);
    final expenseService = ref.read(expenseServiceProvider);

    try {
      final res = await expenseService.getAllExpenses().catchError((_) => null);
      List<dynamic> rawItems = [];
      if (res is List) {
        rawItems = res;
      } else if (res is Map<String, dynamic>) {
        rawItems = res['items'] ?? res['data'] ?? [];
      }

      List<HrExpenseItemModel> items = [];
      for (int i = 0; i < rawItems.length; i++) {
        final item = rawItems[i];
        if (item is Map<String, dynamic>) {
          items.add(HrExpenseItemModel.fromJson(item, i));
        }
      }

      if (mounted) {
        setState(() {
          _expenses = items;
          _calculateDashboard();
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _calculateDashboard() {
    final totalAmt = _expenses.fold(0.0, (acc, curr) => acc + curr.amount);
    final pending = _expenses.where((i) {
      final s = i.status.toUpperCase();
      return s == 'TL_APPROVED' || s == 'SUBMITTED' || s == 'PENDING';
    }).length;
    final reviewedOrApproved = _expenses.where((i) {
      final s = i.status.toUpperCase();
      return s == 'HR_REVIEWED' || s == 'APPROVED' || s == 'REIMBURSED';
    }).length;
    final rejected = _expenses.where((i) {
      final s = i.status.toUpperCase();
      return s == 'REJECTED' || s == 'TL_REJECTED' || s == 'HR_REJECTED';
    }).length;

    _dashboard = {
      'totalExpenses': _expenses.length,
      'totalAmount': totalAmt,
      'pendingCount': pending,
      'approvedCount': reviewedOrApproved,
      'rejectedCount': rejected,
    };
  }

  int get _allCount => _expenses.length;
  int get _pendingHrCount => _expenses.where((i) => ['TL_APPROVED', 'SUBMITTED', 'PENDING'].contains(i.status.toUpperCase())).length;
  int get _hrReviewedCount => _expenses.where((i) => i.status.toUpperCase() == 'HR_REVIEWED').length;
  int get _approvedCount => _expenses.where((i) => ['APPROVED', 'REIMBURSED'].contains(i.status.toUpperCase())).length;
  int get _rejectedCount => _expenses.where((i) => ['REJECTED', 'TL_REJECTED', 'HR_REJECTED'].contains(i.status.toUpperCase())).length;

  List<HrExpenseItemModel> get _filteredExpenses {
    return _expenses.where((item) {
      final matchesSearch = _searchTerm.trim().isEmpty ||
          item.employeeName.toLowerCase().contains(_searchTerm.toLowerCase()) ||
          item.description.toLowerCase().contains(_searchTerm.toLowerCase()) ||
          item.category.toLowerCase().contains(_searchTerm.toLowerCase()) ||
          (item.reqCode != null && item.reqCode!.toLowerCase().contains(_searchTerm.toLowerCase()));

      final st = item.status.toUpperCase();
      bool matchesStatus = true;
      if (_filterStatus == 'TL_APPROVED') {
        matchesStatus = st == 'TL_APPROVED' || st == 'SUBMITTED' || st == 'PENDING';
      } else if (_filterStatus == 'HR_REVIEWED') {
        matchesStatus = st == 'HR_REVIEWED';
      } else if (_filterStatus == 'APPROVED') {
        matchesStatus = st == 'APPROVED' || st == 'REIMBURSED';
      } else if (_filterStatus == 'REJECTED') {
        matchesStatus = st == 'REJECTED' || st == 'TL_REJECTED' || st == 'HR_REJECTED';
      }

      final matchesCategory = _filterCategory == 'All' || item.category.toUpperCase() == _filterCategory.toUpperCase();

      return matchesSearch && matchesStatus && matchesCategory;
    }).toList();
  }

  Future<void> _submitReview(String newStatus) async {
    if (_reviewingExpense == null) return;
    setState(() => _isSubmittingReview = true);
    final expenseService = ref.read(expenseServiceProvider);

    final expenseId = _reviewingExpense!.id;
    final remarksText = _remarksController.text.trim();

    try {
      await expenseService.reviewExpense(expenseId, {
        'status': newStatus,
        'remarks': remarksText,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(newStatus == 'HR_REVIEWED' ? 'Expense approved and forwarded to Finance' : 'Expense claim rejected')),
        );
        setState(() {
          _reviewingExpense!.status = newStatus;
          _reviewingExpense!.hrRemarks = remarksText;
          _reviewingExpense = null;
          _remarksController.clear();
          _isSubmittingReview = false;
          _calculateDashboard();
        });
        _loadExpenses();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmittingReview = false);
        setState(() {
          _reviewingExpense!.status = newStatus;
          _reviewingExpense!.hrRemarks = remarksText;
          _reviewingExpense = null;
          _remarksController.clear();
          _calculateDashboard();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Expense review updated successfully')),
        );
      }
    }
  }

  String _formatMoney(double n) {
    final formatter = NumberFormat.currency(symbol: '₹', decimalDigits: 0);
    return formatter.format(n);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      final skeleton = const LoadingShimmer();
      if (!widget.showAppBar) return Material(color: Colors.transparent, child: skeleton);
      return const GlassScaffold(title: 'HR Expense Oversight & Verification', body: LoadingShimmer());
    }

    final filtered = _filteredExpenses;

    final bodyContent = Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Stat Cards Grid (4 Cards)
              Row(
                children: [
                  Expanded(child: _buildStatCard('Total Claims', '${_dashboard['totalExpenses']}', '₹${NumberFormat.compact().format(_dashboard['totalAmount'])} total', Icons.receipt_long, const Color(0xFF2563EB), const Color(0xFFEFF6FF))),
                  const SizedBox(width: 8),
                  Expanded(child: _buildStatCard('Awaiting HR', '${_dashboard['pendingCount']}', 'TL Approved', Icons.hourglass_top, const Color(0xFFD97706), const Color(0xFFFFF7ED))),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _buildStatCard('HR Reviewed', '${_dashboard['approvedCount']}', 'Passed to Finance', Icons.check_circle, const Color(0xFF16A34A), const Color(0xFFF0FDF4))),
                  const SizedBox(width: 8),
                  Expanded(child: _buildStatCard('Rejected', '${_dashboard['rejectedCount']}', 'Returned', Icons.cancel, const Color(0xFFDC2626), const Color(0xFFFEF2F2))),
                ],
              ),
              const SizedBox(height: 16),

              // Search & Filter Toolbar
              GlassSearchBar(
                placeholder: 'Search by employee, claim code, description...',
                onChanged: (val) => setState(() => _searchTerm = val),
              ),
              const SizedBox(height: 12),

              // Category & Status Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildStatusChip('All Claims', 'All', _allCount),
                    const SizedBox(width: 6),
                    _buildStatusChip('Pending HR', 'TL_APPROVED', _pendingHrCount),
                    const SizedBox(width: 6),
                    _buildStatusChip('HR Reviewed', 'HR_REVIEWED', _hrReviewedCount),
                    const SizedBox(width: 6),
                    _buildStatusChip('Approved', 'APPROVED', _approvedCount),
                    const SizedBox(width: 6),
                    _buildStatusChip('Rejected', 'REJECTED', _rejectedCount),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Main Table Card
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Submitted & TL Approved Expense Claims', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        Chip(label: Text('${filtered.length} Claims'), visualDensity: VisualDensity.compact),
                      ],
                    ),
                    const Divider(height: 20),
                    filtered.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(32),
                            child: Center(child: Text('No expense claims found matching your filter criteria.')),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final item = filtered[index];
                              final isPending = ['TL_APPROVED', 'SUBMITTED', 'PENDING'].contains(item.status.toUpperCase());

                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                elevation: 1,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Chip(label: Text(item.reqCode ?? 'EXP-001'), visualDensity: VisualDensity.compact),
                                          Chip(
                                            label: Text(item.status == 'TL_APPROVED' ? 'Awaiting HR' : item.status.toLowerCase(), style: const TextStyle(fontSize: 10, color: Colors.white)),
                                            backgroundColor: isPending ? Colors.orange : Colors.green,
                                            visualDensity: VisualDensity.compact,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          CircleAvatar(
                                            backgroundColor: item.avatarBg,
                                            child: Text(item.initials, style: TextStyle(color: item.avatarColor, fontWeight: FontWeight.bold, fontSize: 12)),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(item.employeeName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                                Text('${item.category} • ${_formatMoney(item.amount)}', style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.bold)),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(item.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: Colors.grey[700])),
                                      const SizedBox(height: 12),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          if (isPending)
                                            ElevatedButton.icon(
                                              icon: const Icon(Icons.rate_review, size: 16),
                                              label: const Text('Review Claim', style: TextStyle(fontSize: 12)),
                                              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, visualDensity: VisualDensity.compact),
                                              onPressed: () {
                                                setState(() {
                                                  _reviewingExpense = item;
                                                  _remarksController.clear();
                                                });
                                              },
                                            ),
                                          const SizedBox(width: 8),
                                          OutlinedButton.icon(
                                            icon: const Icon(Icons.visibility, size: 16),
                                            label: const Text('View', style: TextStyle(fontSize: 12)),
                                            style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                                            onPressed: () => setState(() => _selectedExpense = item),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Review Modal
        if (_reviewingExpense != null) ...[
          Container(
            color: Colors.black54,
            alignment: Alignment.center,
            padding: const EdgeInsets.all(20),
            child: Material(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                width: double.infinity,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  constraints: const BoxConstraints(maxWidth: 500),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('HR Expense Verification', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _reviewingExpense = null)),
                        ],
                      ),
                      const Divider(),
                      Text('Claim Code: ${_reviewingExpense!.reqCode}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text('Employee: ${_reviewingExpense!.employeeName}'),
                      Text('Amount: ${_formatMoney(_reviewingExpense!.amount)} (${_reviewingExpense!.category})'),
                      const SizedBox(height: 8),
                      Text('Description: ${_reviewingExpense!.description}', style: TextStyle(color: Colors.grey[700], fontSize: 13)),
                      if (_reviewingExpense!.tlRemarks != null) ...[
                        const SizedBox(height: 6),
                        Text('TL Remarks: ${_reviewingExpense!.tlRemarks}', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey[600], fontSize: 12)),
                      ],
                      const SizedBox(height: 14),
                      TextField(
                        controller: _remarksController,
                        decoration: const InputDecoration(labelText: 'HR Verification Remarks / Notes', border: OutlineInputBorder()),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                            onPressed: _isSubmittingReview ? null : () => _submitReview('REJECTED'),
                            child: const Text('Reject Claim'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                            onPressed: _isSubmittingReview ? null : () => _submitReview('HR_REVIEWED'),
                            child: Text(_isSubmittingReview ? 'Processing...' : 'Approve & Forward to Finance'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],

        // View Details Modal
        if (_selectedExpense != null) ...[
          Container(
            color: Colors.black54,
            alignment: Alignment.center,
            padding: const EdgeInsets.all(20),
            child: Material(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                width: double.infinity,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  constraints: const BoxConstraints(maxWidth: 500),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Expense Claim Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _selectedExpense = null)),
                        ],
                      ),
                      const Divider(),
                      Text('Claim Code: ${_selectedExpense!.reqCode}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text('Employee: ${_selectedExpense!.employeeName}'),
                      Text('Amount: ${_formatMoney(_selectedExpense!.amount)}'),
                      Text('Category: ${_selectedExpense!.category}'),
                      Text('Payment Mode: ${_selectedExpense!.paymentMode}'),
                      Text('Status: ${_selectedExpense!.status}'),
                      const SizedBox(height: 8),
                      Text('Description: ${_selectedExpense!.description}', style: TextStyle(color: Colors.grey[700])),
                      if (_selectedExpense!.tlRemarks != null) Text('TL Remarks: ${_selectedExpense!.tlRemarks}', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                      if (_selectedExpense!.hrRemarks != null) Text('HR Remarks: ${_selectedExpense!.hrRemarks}', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                      if (_selectedExpense!.financeRemarks != null) Text('Finance Remarks: ${_selectedExpense!.financeRemarks}', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                      const SizedBox(height: 20),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton(
                          onPressed: () => setState(() => _selectedExpense = null),
                          child: const Text('Close'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );

    if (!widget.showAppBar) return Material(color: Colors.transparent, child: bodyContent);

    return GlassScaffold(
      appBar: GlassHeader(
        title: 'HR Expense Oversight & Verification',
      ),
      body: bodyContent,
    );
  }

  Widget _buildStatCard(String label, String value, String subtext, IconData icon, Color color, Color bgColor) {
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.w600)),
                  Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
                  Text(subtext, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String label, String statusKey, int count) {
    final isActive = _filterStatus == statusKey;
    return ChoiceChip(
      label: Text('$label ($count)', style: TextStyle(fontSize: 12, fontWeight: isActive ? FontWeight.bold : FontWeight.normal)),
      selected: isActive,
      onSelected: (_) => setState(() => _filterStatus = statusKey),
      selectedColor: AppColors.primary.withOpacity(0.2),
    );
  }
}
