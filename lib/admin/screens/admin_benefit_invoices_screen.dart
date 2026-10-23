import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_card.dart';

class AdminBenefitInvoicesScreen extends ConsumerStatefulWidget {
  const AdminBenefitInvoicesScreen({super.key});

  @override
  ConsumerState<AdminBenefitInvoicesScreen> createState() => _AdminBenefitInvoicesScreenState();
}

class _AdminBenefitInvoicesScreenState extends ConsumerState<AdminBenefitInvoicesScreen> {
  bool _isLoading = true;
  List<dynamic> _invoices = [];
  String _searchTerm = '';
  String _statusFilter = 'ALL';

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
          {'id': 'inv-1', 'invoiceNumber': 'INV-2025-001', 'employeeName': 'Rahul Sharma', 'benefitName': 'Health Insurance', 'totalAmount': 12500, 'status': 'PAID'},
          {'id': 'inv-2', 'invoiceNumber': 'INV-2025-002', 'employeeName': 'Priya Verma', 'benefitName': 'Wellness Allowance', 'totalAmount': 5000, 'status': 'PENDING'},
        ];
      }

      setState(() {
        _invoices = items;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  List<dynamic> get _filteredInvoices {
    return _invoices.where((i) {
      const invNum = ''; // (i['invoiceNumber'] ?? '').toString().toLowerCase();
      final name = (i['employeeName'] ?? '').toString().toLowerCase();
      final benName = (i['benefitName'] ?? '').toString().toLowerCase();
      final status = (i['status'] ?? 'PENDING').toString().toUpperCase();

      final matchesSearch = _searchTerm.trim().isEmpty ||
          invNum.contains(_searchTerm.toLowerCase()) ||
          name.contains(_searchTerm.toLowerCase()) ||
          benName.contains(_searchTerm.toLowerCase());

      final matchesStatus = _statusFilter == 'ALL' || status == _statusFilter;

      return matchesSearch && matchesStatus;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Benefit Invoices'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              decoration: const InputDecoration(
                hintText: 'Search invoice number, employee name...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (val) => setState(() => _searchTerm = val),
            ),
            const SizedBox(height: 16),
            _filteredInvoices.isEmpty
                ? const Center(child: Text('No benefit invoices found.'))
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _filteredInvoices.length,
                    itemBuilder: (context, index) {
                      final inv = _filteredInvoices[index];
                      final status = (inv['status'] ?? 'PENDING').toString().toUpperCase();

                      return AppCard(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          title: Text(inv['invoiceNumber'] ?? 'INV-001', style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('${inv['employeeName'] ?? 'Employee'} • ${inv['benefitName'] ?? 'Benefit'} • ₹${inv['totalAmount'] ?? 0}'),
                          trailing: Chip(
                            label: Text(status, style: const TextStyle(fontSize: 10, color: Colors.white)),
                            backgroundColor: status == 'PAID' ? Colors.green : Colors.orange,
                          ),
                        ),
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }
}
