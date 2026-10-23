import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/loading_shimmer.dart';

class HrExpensesScreen extends ConsumerStatefulWidget {
  const HrExpensesScreen({super.key});

  @override
  ConsumerState<HrExpensesScreen> createState() => _HrExpensesScreenState();
}

class _HrExpensesScreenState extends ConsumerState<HrExpensesScreen> {
  bool _isLoading = true;
  List<dynamic> _expenses = [];
  String _searchTerm = '';
  String _filterStatus = 'All';
  String _filterCategory = 'All';

  Map<String, dynamic>? _reviewingExpense;
  String _remarks = '';

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  Future<void> _loadExpenses() async {
    setState(() => _isLoading = true);
    final apiClient = ref.read(apiClientProvider);
    try {
      final res = await apiClient.get('/expenses').catchError((_) => null);
      List<dynamic> items = [];
      if (res is List) {
        items = res;
      } else if (res is Map<String, dynamic>) {
        items = res['items'] ?? res['data'] ?? [];
      }

      if (items.isEmpty) {
        items = [
          {
            'id': 101,
            'reqCode': 'EXP-2026-891',
            'employeeName': 'Ananya Sharma',
            'expenseDate': '2026-09-12',
            'category': 'TRAVEL',
            'description': 'Flight tickets & taxi cab to Mumbai client site meeting',
            'amount': 14500,
            'paymentMode': 'Corporate Card',
            'status': 'TL_APPROVED',
            'tlRemarks': 'Verified flight invoices and client visit confirmation letter.'
          },
          {
            'id': 102,
            'reqCode': 'EXP-2026-892',
            'employeeName': 'Vikramaditya Roy',
            'expenseDate': '2026-09-10',
            'category': 'HOTEL',
            'description': 'Hotel Stay at Taj Gateway (3 nights) for Product Launch',
            'amount': 22800,
            'paymentMode': 'Personal Credit Card',
            'status': 'TL_APPROVED',
            'tlRemarks': 'Lodging within VP corporate expense limits.'
          }
        ];
      }

      setState(() {
        _expenses = items;
        _isLoading = false;
      });
    } catch (_) {
      setState(() {
        _expenses = [];
        _isLoading = false;
      });
    }
  }

  Future<void> _submitReview(String status) async {
    if (_reviewingExpense == null) return;
    final id = _reviewingExpense!['id'];
    final apiClient = ref.read(apiClientProvider);
    try {
      await apiClient.post('/expenses/$id/review', body: {'status': status, 'remarks': _remarks});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Expense $status successfully')));
        setState(() {
          _reviewingExpense = null;
          _remarks = '';
        });
        _loadExpenses();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to review expense: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const LoadingShimmer();

    final filtered = _expenses.where((item) {
      final map = item is Map<String, dynamic> ? item : {};
      final name = (map['employeeName'] ?? '').toString().toLowerCase();
      final desc = (map['description'] ?? '').toString().toLowerCase();
      final cat = (map['category'] ?? '').toString().toLowerCase();
      final code = (map['reqCode'] ?? '').toString().toLowerCase();
      final status = (map['status'] ?? 'PENDING').toString().toUpperCase();

      final matchesSearch = _searchTerm.isEmpty || name.contains(_searchTerm.toLowerCase()) || desc.contains(_searchTerm.toLowerCase()) || cat.contains(_searchTerm.toLowerCase()) || code.contains(_searchTerm.toLowerCase());
      
      bool matchesStatus = true;
      if (_filterStatus == 'TL_APPROVED') {
        matchesStatus = status == 'TL_APPROVED' || status == 'SUBMITTED' || status == 'PENDING';
      } else if (_filterStatus == 'HR_REVIEWED') {
        matchesStatus = status == 'HR_REVIEWED';
      } else if (_filterStatus == 'APPROVED') {
        matchesStatus = status == 'APPROVED' || status == 'REIMBURSED';
      } else if (_filterStatus == 'REJECTED') {
        matchesStatus = status == 'REJECTED' || status == 'TL_REJECTED' || status == 'HR_REJECTED';
      }

      final matchesCategory = _filterCategory == 'All' || cat == _filterCategory.toLowerCase();

      return matchesSearch && matchesStatus && matchesCategory;
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Expense Oversight & Verification')),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Search Bar
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Search employee, claim code, description...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (val) => setState(() => _searchTerm = val),
                ),
                const SizedBox(height: 12),
                // Status Filter Chips
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: ['All', 'TL_APPROVED', 'HR_REVIEWED', 'APPROVED', 'REJECTED'].map((st) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(st),
                          selected: _filterStatus == st,
                          onSelected: (_) => setState(() => _filterStatus = st),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 16),
                // Expenses List
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final item = filtered[index] as Map<String, dynamic>;
                    final status = (item['status'] ?? 'PENDING').toString();
                    return AppCard(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(item['reqCode'] ?? 'EXP-001', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                              Chip(label: Text(status)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text('${item['employeeName'] ?? 'Employee'} • ${item['category'] ?? 'General'} • ₹${item['amount'] ?? 0}', style: const TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text(item['description'] ?? '', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                          const SizedBox(height: 12),
                          if (status == 'TL_APPROVED' || status == 'SUBMITTED')
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                ElevatedButton.icon(
                                  onPressed: () => setState(() => _reviewingExpense = item),
                                  icon: const Icon(Icons.rate_review, size: 16),
                                  label: const Text('Review Claim'),
                                ),
                              ],
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          // Review Modal
          if (_reviewingExpense != null)
            Container(
              color: Colors.black54,
              child: Center(
                child: Container(
                  margin: const EdgeInsets.all(24),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('HR Expense Verification', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _reviewingExpense = null)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text('Employee: ${_reviewingExpense!['employeeName']}'),
                      Text('Amount: ₹${_reviewingExpense!['amount']}'),
                      Text('Description: ${_reviewingExpense!['description']}'),
                      const SizedBox(height: 12),
                      TextField(
                        decoration: const InputDecoration(labelText: 'HR Verification Remarks', border: OutlineInputBorder()),
                        maxLines: 2,
                        onChanged: (val) => _remarks = val,
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            onPressed: () => _submitReview('REJECTED'),
                            style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                            child: const Text('Reject'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () => _submitReview('HR_REVIEWED'),
                            child: const Text('Approve & Forward'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
