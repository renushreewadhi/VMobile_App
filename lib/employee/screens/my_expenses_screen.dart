import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/loading_shimmer.dart';
import '../../shared/widgets/status_chip.dart';
import '../../core/widgets/glass_scaffold.dart';

class MyExpensesScreen extends ConsumerStatefulWidget {
  final bool showAppBar;
  const MyExpensesScreen({super.key, this.showAppBar = true});

  @override
  ConsumerState<MyExpensesScreen> createState() => _MyExpensesScreenState();
}

class _MyExpensesScreenState extends ConsumerState<MyExpensesScreen> {
  bool get _showAppBar => widget.showAppBar;
  bool _isLoading = true;
  String? _error;
  List<dynamic> _expenses = [];
  String _filterStatus = 'ALL';
  bool _showAdd = false;

  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _merchantController = TextEditingController();
  final _amountController = TextEditingController();
  final _descController = TextEditingController();
  final _receiptUrlController = TextEditingController();
  String _category = 'TRAVEL';
  String _currency = 'INR';
  String _paymentMode = 'Personal Credit / Debit Card (Reimbursable)';
  DateTime _expenseDate = DateTime.now();
  bool _isBillable = false;
  bool _submitting = false;

  String? _editingExpenseId;

  final List<String> _categories = [
    'TRAVEL',
    'MEALS',
    'OFFICE_SUPPLIES',
    'MEDICAL',
    'CLIENT_ENTERTAINMENT',
    'ACCOMMODATION',
    'SOFTWARE/SUBSCRIPTIONS',
    'INTERNET',
    'HOTEL',
    'FOOD',
    'OTHER',
  ];

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _merchantController.dispose();
    _amountController.dispose();
    _descController.dispose();
    _receiptUrlController.dispose();
    super.dispose();
  }

  Future<void> _loadExpenses() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final apiClient = ref.read(apiClientProvider);

    try {
      dynamic res;
      try {
        res = await apiClient.get(ApiEndpoints.myExpenses).timeout(const Duration(seconds: 5));
      } catch (_) {
        try {
          res = await apiClient.get(ApiEndpoints.expenses).timeout(const Duration(seconds: 5));
        } catch (_) {
          res = null;
        }
      }

      if (!mounted) return;

      List<dynamic> rawList = [];
      if (res != null) {
        if (res is List) {
          rawList = res;
        } else if (res is Map<String, dynamic>) {
          if (res['data'] is List) {
            rawList = res['data'] as List;
          } else if (res['result'] is List) {
            rawList = res['result'] as List;
          } else if (res['items'] is List) {
            rawList = res['items'] as List;
          } else if (res['claims'] is List) {
            rawList = res['claims'] as List;
          }
        }
      }

      setState(() {
        _expenses = rawList;
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _resetForm() {
    _titleController.clear();
    _category = 'TRAVEL';
    _currency = 'INR';
    _amountController.clear();
    _expenseDate = DateTime.now();
    _merchantController.clear();
    _paymentMode = 'Personal Credit / Debit Card (Reimbursable)';
    _isBillable = false;
    _descController.clear();
    _receiptUrlController.clear();
    _editingExpenseId = null;
  }

  void _openAddModal() {
    _resetForm();
    setState(() => _showAdd = true);
  }

  Future<void> _saveExpense({bool asDraft = false, bool andSubmit = false}) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);

    final apiClient = ref.read(apiClientProvider);
    final dateStr = DateFormat('yyyy-MM-dd').format(_expenseDate);
    final payload = {
      'title': _titleController.text.trim().isNotEmpty ? _titleController.text.trim() : 'Expense Claim',
      'category': _category,
      'amount': double.tryParse(_amountController.text.trim()) ?? 0,
      'currency': _currency,
      'expenseDate': dateStr,
      'merchant': _merchantController.text.trim(),
      'paymentMethod': _paymentMode,
      'isBillable': _isBillable,
      'description': _descController.text.trim(),
      'receiptUrl': _receiptUrlController.text.trim(),
      if (asDraft) 'status': 'DRAFT',
    };

    try {
      if (_editingExpenseId != null) {
        await apiClient.put('${ApiEndpoints.expenses}/$_editingExpenseId', body: payload);
      } else {
        final res = await apiClient.post(ApiEndpoints.expenses, body: payload);
        if (andSubmit && res is Map && res['id'] != null) {
          final newId = res['id'].toString();
          await apiClient.post('${ApiEndpoints.expenses}/$newId/submit', body: {});
        }
      }

      if (!mounted) return;
      setState(() {
        _showAdd = false;
        _submitting = false;
      });
      _resetForm();
      _loadExpenses();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(asDraft ? 'Expense saved as draft successfully!' : 'Expense claim submitted successfully!'), backgroundColor: AppColors.success),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[MyExpensesScreen] Error saving expense: $e');
      }
      if (!mounted) return;
      setState(() => _submitting = false);
      final errMsg = e.toString().replaceFirst('ApiException: ', '').replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save expense: $errMsg'), backgroundColor: AppColors.error),
      );
    }
  }

  double? _number(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '');
  }

  double get _totalAmount => _expenses.fold<double>(0, (sum, item) => sum + (_number(item['amount']) ?? 0));
  int get _pendingCount => _expenses.where((e) {
    final st = (e['status'] ?? '').toString().toUpperCase();
    return st == 'SUBMITTED' || st == 'PENDING' || st == 'TL_APPROVED' || st == 'HR_REVIEWED';
  }).length;
  double get _approvedPaidAmount => _expenses.where((e) {
    final st = (e['status'] ?? '').toString().toUpperCase();
    return st == 'APPROVED' || st == 'REIMBURSED';
  }).fold<double>(0, (sum, item) => sum + (_number(item['amount']) ?? 0));
  int get _draftCount => _expenses.where((e) => (e['status'] ?? '').toString().toUpperCase() == 'DRAFT').length;

  List<dynamic> get _filteredExpenses {
    return _expenses.where((e) {
      if (_filterStatus == 'ALL' || _filterStatus.isEmpty) return true;
      final st = (e['status'] ?? '').toString().toUpperCase();
      return st == _filterStatus.toUpperCase();
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      final skeleton = const ListSkeleton(itemCount: 4);
      if (!_showAppBar) return skeleton;
      return GlassScaffold(title: 'My Expenses & Reimbursements', body: skeleton);
    }

    final content = RefreshIndicator(
      onRefresh: _loadExpenses,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'My Expenses & Reimbursements',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Track your business spendings, submit claim requests, and monitor approval progress',
                        style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _openAddModal,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Submit New Claim'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 1. TOP SUMMARY CARDS (4 Cards Grid)
            _buildStatsGrid(isDark),
            const SizedBox(height: 16),

            // Quick Add Form
            if (_showAdd) _buildQuickAddForm(isDark),

            // 2. MAIN CLAIM RECORDS CARD
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'My Claim Records (${_filteredExpenses.length})',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText),
                      ),
                      DropdownButton<String>(
                        value: _filterStatus,
                        underline: const SizedBox.shrink(),
                        dropdownColor: isDark ? AppColors.darkMainSurface : Colors.white,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText),
                        items: const [
                          DropdownMenuItem(value: 'ALL', child: Text('All Statuses')),
                          DropdownMenuItem(value: 'DRAFT', child: Text('Draft')),
                          DropdownMenuItem(value: 'SUBMITTED', child: Text('Submitted')),
                          DropdownMenuItem(value: 'TL_APPROVED', child: Text('TL Approved')),
                          DropdownMenuItem(value: 'APPROVED', child: Text('Approved')),
                          DropdownMenuItem(value: 'REJECTED', child: Text('Rejected')),
                          DropdownMenuItem(value: 'REIMBURSED', child: Text('Reimbursed')),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _filterStatus = val);
                        },
                      ),
                    ],
                  ),
                  const Divider(height: 16),

                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          const Icon(Icons.error_outline, size: 36, color: Colors.redAccent),
                          const SizedBox(height: 8),
                          Text('Failed to load expenses', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText)),
                          const SizedBox(height: 4),
                          Text(_error!, style: const TextStyle(fontSize: 12, color: Colors.grey), textAlign: TextAlign.center),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: _loadExpenses,
                            icon: const Icon(Icons.refresh, size: 16),
                            label: const Text('Retry'),
                          ),
                        ],
                      ),
                    )
                  else if (_filteredExpenses.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(32),
                      child: Center(
                        child: Column(
                          children: const [
                            Icon(Icons.receipt_long_outlined, size: 40, color: Colors.grey),
                            SizedBox(height: 8),
                            Text('No expense claims found.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            SizedBox(height: 4),
                            Text('Try resetting your status filter.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _filteredExpenses.length,
                      separatorBuilder: (_, __) => const Divider(height: 12),
                      itemBuilder: (context, index) {
                        final e = _filteredExpenses[index];
                        final status = e['status']?.toString() ?? 'DRAFT';
                        final amount = _number(e['amount']) ?? 0;
                        final dateStr = e['expenseDate']?.toString() ?? e['date']?.toString() ?? '';

                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(e['category']?.toString() ?? 'Expense', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText), maxLines: 1, overflow: TextOverflow.ellipsis),
                                      ),
                                      if (dateStr.isNotEmpty) ...[
                                        const SizedBox(width: 8),
                                        Text(dateStr.split('T')[0], style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkMutedText : Colors.grey)),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(e['description']?.toString() ?? 'Claim detail', style: TextStyle(fontSize: 11.5, color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText), maxLines: 1, overflow: TextOverflow.ellipsis),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('₹${amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary)),
                                const SizedBox(height: 2),
                                StatusChip(status: status),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (!_showAppBar) return content;

    return GlassScaffold(
      title: 'My Expenses & Reimbursements',
      body: content,
    );
  }

  Widget _buildStatsGrid(bool isDark) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.8,
      children: [
        _statCard('TOTAL CLAIMS', '₹${_totalAmount.toStringAsFixed(2)}', Icons.account_balance_wallet, const Color(0xFF0066FF), const Color(0xFFEFF6FF), isDark),
        _statCard('PENDING REVIEW', '$_pendingCount Claims', Icons.hourglass_top, const Color(0xFFD97706), const Color(0xFFFEF3C7), isDark),
        _statCard('APPROVED & PAID', '₹${_approvedPaidAmount.toStringAsFixed(2)}', Icons.check_circle_rounded, const Color(0xFF16A34A), const Color(0xFFDCFCE7), isDark),
        _statCard('DRAFT EXPENSES', '$_draftCount', Icons.description_outlined, const Color(0xFF9333EA), const Color(0xFFF3E8FF), isDark),
      ],
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color, Color bg, bool isDark) {
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color), overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAddForm(bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: AppCard(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Submit New Expense Claim', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText)),
                  IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () => setState(() => _showAdd = false)),
                ],
              ),
              const Text('Submit business expenses, upload receipts, and request reimbursement approval.', style: TextStyle(fontSize: 11.5, color: Colors.grey)),
              const Divider(height: 16),

              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Expense Title / Title of Spend *', hintText: 'e.g. Client Dinner - Tech Conference 2026', border: OutlineInputBorder(), isDense: true),
                validator: (v) => v == null || v.trim().isEmpty ? 'Title is required' : null,
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      initialValue: _category,
                      decoration: const InputDecoration(labelText: 'Category *', border: OutlineInputBorder(), isDense: true),
                      items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 12)))).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _category = val);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 1,
                    child: TextFormField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Amount *', hintText: '0.00', border: OutlineInputBorder(), isDense: true),
                      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 1,
                    child: DropdownButtonFormField<String>(
                      initialValue: _currency,
                      decoration: const InputDecoration(labelText: 'Currency', border: OutlineInputBorder(), isDense: true),
                      items: const [
                        DropdownMenuItem(value: 'INR', child: Text('INR (₹)', style: TextStyle(fontSize: 12))),
                        DropdownMenuItem(value: 'USD', child: Text('USD (\$)', style: TextStyle(fontSize: 12))),
                        DropdownMenuItem(value: 'EUR', child: Text('EUR (€)', style: TextStyle(fontSize: 12))),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _currency = val);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _expenseDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) setState(() => _expenseDate = picked);
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(labelText: 'Expense Date *', border: OutlineInputBorder(), isDense: true),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(DateFormat('yyyy-MM-dd').format(_expenseDate), style: const TextStyle(fontSize: 13)),
                            const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _merchantController,
                      decoration: const InputDecoration(labelText: 'Merchant / Vendor Name', hintText: 'e.g. Uber, Marriott', border: OutlineInputBorder(), isDense: true),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              DropdownButtonFormField<String>(
                initialValue: _paymentMode,
                decoration: const InputDecoration(labelText: 'Payment Method *', border: OutlineInputBorder(), isDense: true),
                items: const [
                  DropdownMenuItem(value: 'Personal Credit / Debit Card (Reimbursable)', child: Text('Personal Credit / Debit Card (Reimbursable)', style: TextStyle(fontSize: 12))),
                  DropdownMenuItem(value: 'Company Credit Card', child: Text('Company Credit Card', style: TextStyle(fontSize: 12))),
                  DropdownMenuItem(value: 'UPI / Digital', child: Text('UPI / Digital', style: TextStyle(fontSize: 12))),
                  DropdownMenuItem(value: 'Cash', child: Text('Cash', style: TextStyle(fontSize: 12))),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _paymentMode = val);
                },
              ),
              const SizedBox(height: 4),

              CheckboxListTile(
                title: const Text('This expense is billable to a client / project', style: TextStyle(fontSize: 12.5)),
                value: _isBillable,
                onChanged: (val) => setState(() => _isBillable = val ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
              const SizedBox(height: 4),

              TextFormField(
                controller: _descController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Business Purpose & Description *', hintText: 'Explain why this expense was incurred...', border: OutlineInputBorder()),
                validator: (v) => v == null || v.trim().isEmpty ? 'Description is required' : null,
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _receiptUrlController,
                decoration: const InputDecoration(labelText: 'Receipt & Supporting Documents (URL / File Link)', hintText: 'https://...', border: OutlineInputBorder(), isDense: true),
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  OutlinedButton(
                    onPressed: () => setState(() => _showAdd = false),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _submitting ? null : () => _saveExpense(asDraft: true),
                      child: const Text('Save as Draft'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _submitting ? null : () => _saveExpense(andSubmit: true),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                      child: Text(_submitting ? 'Submitting...' : 'Submit Claim'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
