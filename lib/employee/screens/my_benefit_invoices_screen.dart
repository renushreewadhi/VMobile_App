import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/auth/auth_service.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/loading_shimmer.dart';
import '../../shared/widgets/status_chip.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/glass_header.dart';

class MyBenefitInvoicesScreen extends ConsumerStatefulWidget {
  final bool showAppBar;
  const MyBenefitInvoicesScreen({super.key, this.showAppBar = false});

  @override
  ConsumerState<MyBenefitInvoicesScreen> createState() => _MyBenefitInvoicesScreenState();
}

class _MyBenefitInvoicesScreenState extends ConsumerState<MyBenefitInvoicesScreen> {
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
      final res = await apiClient.get('/benefits/invoices').catchError((_) => null);
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
    if (_isLoading) {
      const skeleton = ListSkeleton(itemCount: 4);
      if (!widget.showAppBar) return Material(color: Colors.transparent, child: skeleton);
      return const GlassScaffold(title: 'My Benefit Invoices', body: ListSkeleton(itemCount: 4));
    }

    final content = RefreshIndicator(
      onRefresh: _fetchInvoices,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!widget.showAppBar) ...[
              const Text('Benefit Payment Invoices', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
            ],
            _invoices.isEmpty
                ? const AppCard(child: Center(child: Padding(padding: EdgeInsets.all(24), child: Text('No benefit invoices found.'))))
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
                                  Text(inv['invoiceNumber'] ?? 'INV-2026-001', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                  const SizedBox(height: 4),
                                  Text(inv['benefitName'] ?? 'Insurance Claim', style: const TextStyle(fontSize: 12, color: AppColors.lightSecondaryText)),
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
    );

    if (!widget.showAppBar) return Material(color: Colors.transparent, child: content);

    return GlassScaffold(
      title: 'My Benefit Invoices',
      body: content,
    );
  }
}
