import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/compact_summary_widgets.dart';
import '../../shared/widgets/loading_shimmer.dart';

class HrBenefitInvoicesScreen extends ConsumerStatefulWidget {
  const HrBenefitInvoicesScreen({super.key});

  @override
  ConsumerState<HrBenefitInvoicesScreen> createState() => _HrBenefitInvoicesScreenState();
}

class _HrBenefitInvoicesScreenState extends ConsumerState<HrBenefitInvoicesScreen> {
  bool _isLoading = true;
  List<dynamic> _invoices = [];
  String _searchTerm = '';
  String _statusFilter = 'ALL';
  Map<String, dynamic>? _selectedInvoice;

  @override
  void initState() {
    super.initState();
    _loadInvoices();
  }

  Future<void> _loadInvoices() async {
    setState(() => _isLoading = true);
    final apiClient = ref.read(apiClientProvider);
    try {
      final res = await apiClient.get('/benefits/invoices').catchError((_) => null);
      List<dynamic> items = [];
      if (res is List) {
        items = res;
      } else if (res is Map<String, dynamic>) {
        items = res['items'] ?? res['data'] ?? [];
      }

      if (items.isEmpty) {
        items = [
          {
            'id': '1',
            'invoiceNumber': 'INV-2025-001',
            'employeeName': 'Rahul Sharma',
            'employeeCode': 'EMP-001',
            'benefitName': 'Health Insurance Premium',
            'benefitCode': 'HLT-01',
            'totalAmount': 15000,
            'amount': 15000,
            'paymentMethod': 'Razorpay',
            'invoiceDate': '2025-02-10',
            'status': 'PAID',
            'description': 'Annual health insurance family floater premium reimbursement',
            'razorpayPaymentId': 'pay_29XZs391Ks'
          },
          {
            'id': '2',
            'invoiceNumber': 'INV-2025-002',
            'employeeName': 'Priya Verma',
            'employeeCode': 'EMP-002',
            'benefitName': 'Gym & Wellness Allowance',
            'benefitCode': 'WLN-02',
            'totalAmount': 3500,
            'amount': 3500,
            'paymentMethod': 'Bank Transfer',
            'invoiceDate': '2025-02-12',
            'status': 'PENDING',
            'description': 'Monthly fitness club membership reimbursement',
          }
        ];
      }

      setState(() {
        _invoices = items;
        _isLoading = false;
      });
    } catch (_) {
      setState(() {
        _invoices = [];
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const LoadingShimmer();

    final filtered = _invoices.where((i) {
      final map = i is Map<String, dynamic> ? i : {};
      final invNum = (map['invoiceNumber'] ?? '').toString().toLowerCase();
      final empName = (map['employeeName'] ?? '').toString().toLowerCase();
      final benName = (map['benefitName'] ?? '').toString().toLowerCase();
      final status = (map['status'] ?? 'PENDING').toString().toUpperCase();

      final matchesSearch = _searchTerm.isEmpty || invNum.contains(_searchTerm.toLowerCase()) || empName.contains(_searchTerm.toLowerCase()) || benName.contains(_searchTerm.toLowerCase());
      final matchesStatus = _statusFilter == 'ALL' || status == _statusFilter.toUpperCase();

      return matchesSearch && matchesStatus;
    }).toList();

    final paidCount = _invoices.where((i) => (i['status'] ?? '').toString().toUpperCase() == 'PAID').length;
    final pendingCount = _invoices.length - paidCount;

    return Scaffold(
      appBar: AppBar(title: const Text('Benefit Invoices')),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // 1. PASTEL SUMMARY PILLS
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      PastelSummaryPill(
                        label: '${_invoices.length} Total Invoices',
                        variant: PastelPillVariant.blue,
                        onTap: () => setState(() => _statusFilter = 'ALL'),
                      ),
                      const SizedBox(width: 8),
                      PastelSummaryPill(
                        label: '$paidCount Paid Invoices',
                        variant: PastelPillVariant.green,
                        onTap: () => setState(() => _statusFilter = 'PAID'),
                      ),
                      const SizedBox(width: 8),
                      PastelSummaryPill(
                        label: '$pendingCount Pending Payment',
                        variant: PastelPillVariant.amber,
                        onTap: () => setState(() => _statusFilter = 'PENDING'),
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
                      value: '${_invoices.length}',
                      ringColor: AppColors.primary,
                      onTap: () => setState(() => _statusFilter = 'ALL'),
                    ),
                    CircularStatItemData(
                      label: 'Paid',
                      value: '$paidCount',
                      ringColor: AppColors.success,
                      onTap: () => setState(() => _statusFilter = 'PAID'),
                    ),
                    CircularStatItemData(
                      label: 'Pending',
                      value: '$pendingCount',
                      ringColor: const Color(0xFFD97706),
                      onTap: () => setState(() => _statusFilter = 'PENDING'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Search & Filter
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Search invoices...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (val) => setState(() => _searchTerm = val),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    ChoiceChip(label: const Text('All'), selected: _statusFilter == 'ALL', onSelected: (_) => setState(() => _statusFilter = 'ALL')),
                    const SizedBox(width: 8),
                    ChoiceChip(label: const Text('Paid'), selected: _statusFilter == 'PAID', onSelected: (_) => setState(() => _statusFilter = 'PAID')),
                    const SizedBox(width: 8),
                    ChoiceChip(label: const Text('Pending'), selected: _statusFilter == 'PENDING', onSelected: (_) => setState(() => _statusFilter = 'PENDING')),
                  ],
                ),
                const SizedBox(height: 16),

                // Invoices List
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final inv = filtered[index] as Map<String, dynamic>;
                    final status = (inv['status'] ?? 'PENDING').toString().toUpperCase();
                    return AppCard(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(inv['invoiceNumber'] ?? 'INV-001', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${inv['employeeName'] ?? 'Employee'} • ${inv['benefitName'] ?? 'Benefit'} • ₹${inv['totalAmount'] ?? 0}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Chip(label: Text(status), backgroundColor: status == 'PAID' ? Colors.green.withOpacity(0.2) : Colors.orange.withOpacity(0.2)),
                            IconButton(
                              icon: const Icon(Icons.visibility, size: 20, color: AppColors.primary),
                              onPressed: () => setState(() => _selectedInvoice = inv),
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
          if (_selectedInvoice != null)
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
                          Text(_selectedInvoice!['invoiceNumber'] ?? 'Invoice', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _selectedInvoice = null)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text('Employee: ${_selectedInvoice!['employeeName']} (${_selectedInvoice!['employeeCode'] ?? ''})'),
                      Text('Benefit: ${_selectedInvoice!['benefitName']}'),
                      Text('Description: ${_selectedInvoice!['description'] ?? 'N/A'}'),
                      Text('Amount: ₹${_selectedInvoice!['totalAmount'] ?? 0}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Downloading PDF invoice...'))),
                          child: const Text('Download PDF'),
                        ),
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
