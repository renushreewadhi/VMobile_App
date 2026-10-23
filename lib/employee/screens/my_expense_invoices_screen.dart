import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/auth/auth_service.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/loading_shimmer.dart';
import '../../shared/widgets/status_chip.dart';

class MyExpenseInvoicesScreen extends ConsumerStatefulWidget {
  const MyExpenseInvoicesScreen({super.key});

  @override
  ConsumerState<MyExpenseInvoicesScreen> createState() => _MyExpenseInvoicesScreenState();
}

class _MyExpenseInvoicesScreenState extends ConsumerState<MyExpenseInvoicesScreen> {
  bool _isLoading = true;
  List<dynamic> _invoices = [];

  @override
  void initState() {
    super.initState();
    _fetchInvoices();
  }

  Future<void> _fetchInvoices() async {
    setState(() => _isLoading = true);
    final apiClient = ref.read(apiClientProvider);
    try {
      final res = await apiClient.get('/expenses/invoices').catchError((_) => null);
      if (mounted) {
        setState(() {
          if (res is List) {
            _invoices = res;
          } else if (res is Map<String, dynamic> && res['data'] is List) {
            _invoices = res['data'];
          }
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Expense Invoices')),
      body: _isLoading
          ? const ListSkeleton(itemCount: 4)
          : RefreshIndicator(
              onRefresh: _fetchInvoices,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Expense Reimbursement Invoices', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 12),
                    _invoices.isEmpty
                        ? const AppCard(child: Center(child: Padding(padding: EdgeInsets.all(24), child: Text('No expense invoices found.'))))
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _invoices.length,
                            itemBuilder: (context, index) {
                              final inv = _invoices[index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: AppCard(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(inv['invoiceNumber'] ?? 'INV-EXP-001', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                          const SizedBox(height: 4),
                                          Text(inv['description'] ?? 'Expense Settlement', style: const TextStyle(fontSize: 12, color: AppColors.lightSecondaryText)),
                                        ],
                                      ),
                                      StatusChip(status: inv['status'] ?? 'PAID'),
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
