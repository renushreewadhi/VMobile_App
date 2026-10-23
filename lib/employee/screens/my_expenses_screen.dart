import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/compact_summary_widgets.dart';
import '../../shared/widgets/loading_shimmer.dart';
import '../../shared/widgets/status_chip.dart';

class MyExpensesScreen extends ConsumerStatefulWidget {
  const MyExpensesScreen({super.key});

  @override
  ConsumerState<MyExpensesScreen> createState() => _MyExpensesScreenState();
}

class _MyExpensesScreenState extends ConsumerState<MyExpensesScreen> {
  bool _loading = true;
  List<dynamic> _expenses = [];
  String _filterStatus = '';
  bool _showAdd = false;

  final _formKey = GlobalKey<FormState>();
  String _category = 'TRAVEL';
  final _amountController = TextEditingController();
  final _descController = TextEditingController();
  final _locationController = TextEditingController();
  final _projectClientController = TextEditingController();
  final _receiptUrlController = TextEditingController();
  String _paymentMode = 'UPI';
  DateTime _expenseDate = DateTime.now();
  bool _submitting = false;

  String? _editingExpenseId;

  final List<String> _categories = [
    'TRAVEL',
    'MEALS',
    'OFFICE_SUPPLIES',
    'MEDICAL',
    'CLIENT_ENTERTAINMENT',
    'ACCOMMODATION',
    'OTHER',
  ];

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descController.dispose();
    _locationController.dispose();
    _projectClientController.dispose();
    _receiptUrlController.dispose();
    super.dispose();
  }

  Future<void> _loadExpenses() async {
    if (!mounted) return;
    setState(() => _loading = true);

    final apiClient = ref.read(apiClientProvider);

    try {
      String endpoint = '/expenses/my';
      if (_filterStatus.isNotEmpty) {
        endpoint += '?status=$_filterStatus';
      }
      final res = await apiClient.get(endpoint).catchError((_) => null);

      if (!mounted) return;

      final rawList = res is List ? res : (res is Map && res['data'] is List ? res['data'] as List : []);

      setState(() {
        _expenses = rawList;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _expenses = [];
        _loading = false;
      });
    }
  }

  void _resetForm() {
    _category = 'TRAVEL';
    _amountController.clear();
    _descController.clear();
    _locationController.clear();
    _projectClientController.clear();
    _receiptUrlController.clear();
    _paymentMode = 'UPI';
    _expenseDate = DateTime.now();
    _editingExpenseId = null;
  }

  void _openAddModal({Map<String, dynamic>? editItem}) {
    if (editItem != null) {
      _editingExpenseId = editItem['id']?.toString();
      _category = editItem['category']?.toString() ?? 'TRAVEL';
      _amountController.text = (editItem['amount'] ?? '').toString();
      _descController.text = editItem['description']?.toString() ?? editItem['title']?.toString() ?? '';
      _locationController.text = editItem['expenseLocation']?.toString() ?? '';
      _projectClientController.text = editItem['projectClient']?.toString() ?? '';
      _receiptUrlController.text = editItem['receiptUrl']?.toString() ?? '';
      _paymentMode = editItem['paymentMode']?.toString() ?? 'UPI';
      final dtStr = editItem['expenseDate']?.toString() ?? editItem['date']?.toString();
      if (dtStr != null) {
        try {
          _expenseDate = DateTime.parse(dtStr.contains('T') ? dtStr.split('T')[0] : dtStr);
        } catch (_) {
          _expenseDate = DateTime.now();
        }
      }
    } else {
      _resetForm();
    }

    setState(() => _showAdd = true);
  }

  Future<void> _saveExpense({bool andSubmit = false}) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);

    final apiClient = ref.read(apiClientProvider);
    final dateStr = DateFormat('yyyy-MM-dd').format(_expenseDate);
    final payload = {
      'category': _category,
      'amount': double.tryParse(_amountController.text.trim()) ?? 0,
      'expenseDate': dateStr,
      'paymentMode': _paymentMode,
      'description': _descController.text.trim(),
      'expenseLocation': _locationController.text.trim(),
      'projectClient': _projectClientController.text.trim(),
      'receiptUrl': _receiptUrlController.text.trim(),
    };

    try {
      if (_editingExpenseId != null) {
        await apiClient.put('/expenses/$_editingExpenseId', body: payload);
      } else {
        final res = await apiClient.post('/expenses/my', body: payload);
        if (andSubmit && res is Map && res['id'] != null) {
          await apiClient.post('/expenses/${res['id']}/submit', body: {});
        }
      }

      if (mounted) {
        setState(() {
          _showAdd = false;
          _submitting = false;
        });
        _resetForm();
        _loadExpenses();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  double get _totalAmount => _expenses.fold<double>(0, (sum, item) => sum + (_number(item['amount']) ?? 0));
  int get _pendingCount => _expenses.where((e) => ['SUBMITTED', 'PENDING', 'TL_APPROVED', 'HR_REVIEWED'].contains((e['status'] ?? '').toString().toUpperCase())).length;
  double get _approvedAmount => _expenses.where((e) => ['APPROVED', 'REIMBURSED'].contains((e['status'] ?? '').toString().toUpperCase())).fold<double>(0, (sum, item) => sum + (_number(item['amount']) ?? 0));
  int get _draftCount => _expenses.where((e) => (e['status'] ?? '').toString().toUpperCase() == 'DRAFT').length;

  double? _number(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Expenses & Claims'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Submit New Claim',
            onPressed: () => _openAddModal(),
          ),
        ],
      ),
      body: _loading
          ? const ListSkeleton(itemCount: 4)
          : RefreshIndicator(
              onRefresh: _loadExpenses,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. PASTEL SUMMARY PILLS
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: [
                          PastelSummaryPill(
                            label: '₹${_totalAmount.toStringAsFixed(0)} Total Claims',
                            variant: PastelPillVariant.blue,
                          ),
                          const SizedBox(width: 8),
                          PastelSummaryPill(
                            label: '$_pendingCount Pending Review',
                            variant: PastelPillVariant.amber,
                          ),
                          const SizedBox(width: 8),
                          PastelSummaryPill(
                            label: '₹${_approvedAmount.toStringAsFixed(0)} Approved',
                            variant: PastelPillVariant.green,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // 2. CIRCULAR STATISTIC INDICATOR GROUP
                    CircularStatGroup(
                      items: [
                        CircularStatItemData(
                          label: 'Total',
                          value: '${_expenses.length}',
                          ringColor: AppColors.primary,
                        ),
                        CircularStatItemData(
                          label: 'Pending',
                          value: '$_pendingCount',
                          ringColor: const Color(0xFFD97706),
                        ),
                        CircularStatItemData(
                          label: 'Approved',
                          value: '${_expenses.where((e) => e['status'] == 'APPROVED').length}',
                          ringColor: AppColors.success,
                        ),
                        CircularStatItemData(
                          label: 'Draft',
                          value: '$_draftCount',
                          ringColor: const Color(0xFF9333EA),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Quick Add Form
                    if (_showAdd) _buildQuickAddForm(isDark),

                    // Main List Card
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('${_expenses.length} Expense Claims', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                              DropdownButton<String>(
                                value: _filterStatus.isEmpty ? null : _filterStatus,
                                hint: const Text('All Statuses', style: TextStyle(fontSize: 12)),
                                underline: const SizedBox.shrink(),
                                items: const [
                                  DropdownMenuItem(value: '', child: Text('All Statuses', style: TextStyle(fontSize: 12))),
                                  DropdownMenuItem(value: 'DRAFT', child: Text('Draft', style: TextStyle(fontSize: 12))),
                                  DropdownMenuItem(value: 'SUBMITTED', child: Text('Submitted', style: TextStyle(fontSize: 12))),
                                  DropdownMenuItem(value: 'APPROVED', child: Text('Approved', style: TextStyle(fontSize: 12))),
                                  DropdownMenuItem(value: 'REJECTED', child: Text('Rejected', style: TextStyle(fontSize: 12))),
                                ],
                                onChanged: (val) {
                                  setState(() => _filterStatus = val ?? '');
                                  _loadExpenses();
                                },
                              ),
                            ],
                          ),
                          const Divider(height: 16),

                          _expenses.isEmpty
                              ? const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('No expense claims found.')))
                              : ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: _expenses.length,
                                  separatorBuilder: (_, __) => const Divider(height: 12),
                                  itemBuilder: (context, index) {
                                    final e = _expenses[index];
                                    final status = e['status']?.toString() ?? 'DRAFT';
                                    final amount = _number(e['amount']) ?? 0;

                                    return Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(e['category']?.toString() ?? 'Expense', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                                              const SizedBox(height: 2),
                                              Text(e['description']?.toString() ?? 'Claim detail', style: const TextStyle(fontSize: 11.5, color: AppColors.lightSecondaryText), maxLines: 1, overflow: TextOverflow.ellipsis),
                                            ],
                                          ),
                                        ),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Text('₹${amount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary)),
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
                  const Text('Submit Expense Claim', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () => setState(() => _showAdd = false)),
                ],
              ),
              const Divider(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _category,
                      decoration: const InputDecoration(labelText: 'Category'),
                      items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 12)))).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _category = val);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Amount (₹)'),
                      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _descController,
                decoration: const InputDecoration(labelText: 'Description'),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitting ? null : () => _saveExpense(andSubmit: true),
                  child: Text(_submitting ? 'Submitting...' : 'Submit Claim'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
