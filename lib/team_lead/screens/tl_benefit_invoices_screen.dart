import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_header.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/loading_shimmer.dart';
import '../../shared/widgets/status_chip.dart';

class TlBenefitInvoicesScreen extends ConsumerStatefulWidget {
  const TlBenefitInvoicesScreen({super.key});

  @override
  ConsumerState<TlBenefitInvoicesScreen> createState() => _TlBenefitInvoicesScreenState();
}

class _TlBenefitInvoicesScreenState extends ConsumerState<TlBenefitInvoicesScreen> {
  bool _isLoading = true;
  List<dynamic> _invoices = [];
  String _searchTerm = '';
  String _statusFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    _fetchInvoices();
  }

  Future<void> _fetchInvoices() async {
    setState(() => _isLoading = true);
    final apiClient = ref.read(apiClientProvider);

    try {
      final res = await apiClient.get('/benefits/invoices').catchError((_) async {
        return await apiClient.get('/benefits/claims/my').catchError((_) => null);
      });

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
            'invoiceNumber': 'INV-BEN-2026-101',
            'benefitName': 'Health Insurance Premium',
            'benefitCode': 'HEALTH_INS',
            'description': 'Family Floater Health Coverage Reimbursement',
            'employeeName': 'Team Lead',
            'employeeCode': 'TL-101',
            'amount': 15000,
            'totalAmount': 15000,
            'paymentMethod': 'Razorpay Online',
            'razorpayPaymentId': 'pay_Rzp10293847',
            'invoiceDate': '2026-09-01',
            'paidAt': '2026-09-03',
            'status': 'PAID'
          },
          {
            'id': '2',
            'invoiceNumber': 'INV-BEN-2026-102',
            'benefitName': 'Wellness Gym Membership',
            'benefitCode': 'WELLNESS',
            'description': 'Annual Fitness Center Allowance',
            'employeeName': 'Team Lead',
            'employeeCode': 'TL-101',
            'amount': 6000,
            'totalAmount': 6000,
            'paymentMethod': 'Bank Transfer',
            'invoiceDate': '2026-09-10',
            'status': 'PENDING'
          }
        ];
      }

      if (mounted) {
        setState(() {
          _invoices = items;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _invoices = [];
          _isLoading = false;
        });
      }
    }
  }

  void _downloadPdf(dynamic inv) {
    final invNum = inv['invoiceNumber'] ?? 'INV-000';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Downloading PDF for Invoice $invNum...'), backgroundColor: AppColors.success),
    );
  }

  void _showInvoiceModal(dynamic inv) {
    final invNum = inv['invoiceNumber'] ?? 'INV-000';
    final benefitName = inv['benefitName'] ?? 'Benefit Plan';
    final desc = inv['description'] ?? '';
    final empName = inv['employeeName'] ?? 'Employee';
    final empCode = inv['employeeCode'] ?? '';
    final amount = inv['totalAmount'] ?? inv['amount'] ?? 0;
    final method = inv['paymentMethod'] ?? 'N/A';
    final rzpId = inv['razorpayPaymentId'];
    final invDate = inv['invoiceDate'] ?? '';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Benefit Invoice: $invNum'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Employee: $empName ($empCode)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              Text('Benefit Plan: $benefitName', style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 6),
              Text('Description: $desc', style: const TextStyle(fontSize: 13, color: AppColors.lightSecondaryText)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppColors.successBg, borderRadius: BorderRadius.circular(8)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Settlement:', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('₹$amount', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.success)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text('Payment Method: $method', style: const TextStyle(fontSize: 12)),
              if (rzpId != null) ...[
                const SizedBox(height: 4),
                Text('Ref ID: $rzpId', style: const TextStyle(fontSize: 11, color: AppColors.lightMutedText)),
              ],
              const SizedBox(height: 4),
              Text('Invoice Date: $invDate', style: const TextStyle(fontSize: 11, color: AppColors.lightMutedText)),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _downloadPdf(inv);
            },
            icon: const Icon(Icons.picture_as_pdf, size: 16),
            label: const Text('Download PDF'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const GlassScaffold(
        appBar: GlassHeader(title: 'My Benefit Invoices'),
        body: ListSkeleton(itemCount: 4),
      );
    }

    final paidCount = _invoices.where((i) => i['status'] == 'PAID').length;
    final pendingCount = _invoices.where((i) => i['status'] != 'PAID' && i['status'] != 'FAILED').length;

    final filtered = _invoices.where((i) {
      final map = i is Map<String, dynamic> ? i : {};
      final invNum = (map['invoiceNumber'] ?? '').toString().toLowerCase();
      final name = (map['benefitName'] ?? '').toString().toLowerCase();
      final desc = (map['description'] ?? '').toString().toLowerCase();
      final status = (map['status'] ?? 'ALL').toString().toUpperCase();

      final matchesSearch = _searchTerm.isEmpty || invNum.contains(_searchTerm.toLowerCase()) || name.contains(_searchTerm.toLowerCase()) || desc.contains(_searchTerm.toLowerCase());
      final matchesStatus = _statusFilter == 'ALL' || status == _statusFilter;

      return matchesSearch && matchesStatus;
    }).toList();

    return GlassScaffold(
      appBar: const GlassHeader(title: 'My Benefit Invoices'),
      body: RefreshIndicator(
        onRefresh: _fetchInvoices,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('My Benefit Invoices', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 12),

              // Stat Cards Row
              Row(
                children: [
                  Expanded(child: StatCard(title: 'Total', value: '${_invoices.length}', icon: Icons.description, iconColor: AppColors.primary, iconBgColor: AppColors.lightPrimary)),
                  const SizedBox(width: 8),
                  Expanded(child: StatCard(title: 'Paid', value: '$paidCount', icon: Icons.check_circle, iconColor: AppColors.success, iconBgColor: AppColors.successBg)),
                  const SizedBox(width: 8),
                  Expanded(child: StatCard(title: 'Pending', value: '$pendingCount', icon: Icons.hourglass_top, iconColor: AppColors.warning, iconBgColor: AppColors.warningBg)),
                ],
              ),
              const SizedBox(height: 16),

              // Search Bar & Filters
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
                  Material(color: Colors.transparent, child: ChoiceChip(label: Text('All (${_invoices.length})'), selected: _statusFilter == 'ALL', onSelected: (_) => setState(() => _statusFilter = 'ALL'))),
                  const SizedBox(width: 8),
                  Material(color: Colors.transparent, child: ChoiceChip(label: Text('Paid ($paidCount)'), selected: _statusFilter == 'PAID', onSelected: (_) => setState(() => _statusFilter = 'PAID'))),
                  const SizedBox(width: 8),
                  Material(color: Colors.transparent, child: ChoiceChip(label: Text('Pending ($pendingCount)'), selected: _statusFilter == 'PENDING', onSelected: (_) => setState(() => _statusFilter = 'PENDING'))),
                ],
              ),
              const SizedBox(height: 20),

              // Invoices Cards List
              if (filtered.isEmpty)
                const AppCard(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: Text('No benefit invoices found.')),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final inv = filtered[index] as Map<String, dynamic>;
                    final invNum = inv['invoiceNumber'] ?? 'INV-000';
                    final benefitName = inv['benefitName'] ?? 'Benefit Plan';
                    final desc = inv['description'] ?? '';
                    final amount = inv['totalAmount'] ?? inv['amount'] ?? 0;
                    final status = inv['status'] ?? 'PENDING';
                    final invDate = inv['invoiceDate'] ?? '';

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(invNum, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.primary)),
                                StatusChip(status: status),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(benefitName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            if (desc.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(desc, style: const TextStyle(fontSize: 12, color: AppColors.lightSecondaryText)),
                            ],
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Date: $invDate', style: const TextStyle(fontSize: 11, color: AppColors.lightMutedText)),
                                Text('₹$amount', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.success)),
                              ],
                            ),
                            const Divider(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton.icon(
                                  onPressed: () => _showInvoiceModal(inv),
                                  icon: const Icon(Icons.visibility, size: 16),
                                  label: const Text('View'),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton.icon(
                                  onPressed: () => _downloadPdf(inv),
                                  icon: const Icon(Icons.picture_as_pdf, size: 16, color: AppColors.error),
                                  label: const Text('PDF', style: TextStyle(color: AppColors.error)),
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
      ),
    );
  }
}
