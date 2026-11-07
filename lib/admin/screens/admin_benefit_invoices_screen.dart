import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/auth/auth_service.dart';
import '../../core/errors/api_exception.dart';
import '../../core/models/user_model.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/glass_theme.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/glass_header.dart';

/// Invoice as returned by GET /benefits/invoices/all.
/// Missing values stay null (shown as "—"); nothing is invented.
/// TODO: verify field names against the Angular BenefitInvoice interface.
class BenefitInvoiceModel {
  final String id;
  final String? invoiceNumber;
  final String? employeeName;
  final String? employeeCode;
  final String? benefitName;
  final String? benefitCode;
  final double? amount;
  final double? totalAmount;
  final String? paymentMethod;
  final String? invoiceDate;
  final String status; // upper-case; '' when the API sends none
  final String? razorpayPaymentId;
  final String? description;

  BenefitInvoiceModel({
    required this.id,
    this.invoiceNumber,
    this.employeeName,
    this.employeeCode,
    this.benefitName,
    this.benefitCode,
    this.amount,
    this.totalAmount,
    this.paymentMethod,
    this.invoiceDate,
    required this.status,
    this.razorpayPaymentId,
    this.description,
  });

  factory BenefitInvoiceModel.fromJson(Map<String, dynamic> json) {
    String? s(dynamic v) {
      final t = v?.toString().trim();
      return (t == null || t.isEmpty || t == 'null') ? null : t;
    }

    double? n(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    final amount = n(json['amount']);
    final total = n(json['totalAmount']);

    return BenefitInvoiceModel(
      id: s(json['id']) ?? '',
      invoiceNumber: s(json['invoiceNumber']),
      employeeName: s(json['employeeName']),
      employeeCode: s(json['employeeCode']),
      benefitName: s(json['benefitName']),
      benefitCode: s(json['benefitCode']),
      amount: amount ?? total,
      totalAmount: total ?? amount,
      paymentMethod: s(json['paymentMethod']),
      invoiceDate: s(json['invoiceDate']),
      status: s(json['status'])?.toUpperCase() ?? '',
      razorpayPaymentId: s(json['razorpayPaymentId']),
      description: s(json['description']),
    );
  }
}

class AdminBenefitInvoicesScreen extends ConsumerStatefulWidget {
  final bool showAppBar;
  const AdminBenefitInvoicesScreen({super.key, this.showAppBar = true});

  @override
  ConsumerState<AdminBenefitInvoicesScreen> createState() => _AdminBenefitInvoicesScreenState();
}

class _AdminBenefitInvoicesScreenState extends ConsumerState<AdminBenefitInvoicesScreen> {
  // TODO: must match the Angular route guard for this page.
  static const Set<UserRole> _allowedRoles = {UserRole.ADMIN};

  // Matches Angular: `₹${Number(n).toLocaleString('en-IN')}` (Indian grouping, no forced decimals).
  static final NumberFormat _inr = NumberFormat.decimalPattern('en_IN');

  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;
  String? _error;
  List<BenefitInvoiceModel> _invoices = [];
  String _searchTerm = '';
  String _statusFilter = 'ALL';
  int _requestId = 0; // drops responses that belong to a previous user / request

  bool get _canAccess {
    final role = ref.read(authServiceProvider).user?.role;
    return role != null && _allowedRoles.contains(role);
  }

  @override
  void initState() {
    super.initState();
    if (_canAccess) {
      _load();
    } else {
      _isLoading = false;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final requestId = ++_requestId;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final res = await ref.read(apiClientProvider).get(ApiEndpoints.benefitInvoicesAll);
      final parsed = _parse(res);
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _invoices = parsed;
        _isLoading = false;
      });
    } catch (e, st) {
      debugPrint('[AdminBenefitInvoices] load failed: $e\n$st');
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _error = e is ApiException ? e.message : 'The server response could not be read. Please try again.';
        _isLoading = false;
      });
    }
  }

  List<BenefitInvoiceModel> _parse(dynamic res) {
    if (res == null) return [];
    dynamic payload = res;
    if (payload is Map<String, dynamic>) {
      payload = payload['items'] ?? payload['data'];
    }
    if (payload == null) return [];
    if (payload is! List) {
      throw const FormatException('Unexpected invoices response shape');
    }
    return payload.map((e) {
      if (e is! Map<String, dynamic>) throw const FormatException('Invalid invoice entry');
      return BenefitInvoiceModel.fromJson(e);
    }).toList();
  }

  List<BenefitInvoiceModel> get _filtered {
    final q = _searchTerm.trim().toLowerCase();
    return _invoices.where((i) {
      final matchSearch = q.isEmpty ||
          (i.invoiceNumber ?? '').toLowerCase().contains(q) ||
          (i.employeeName ?? '').toLowerCase().contains(q) ||
          (i.benefitName ?? '').toLowerCase().contains(q);
      final matchStatus = _statusFilter == 'ALL' || i.status == _statusFilter;
      return matchSearch && matchStatus;
    }).toList();
  }

  String _money(double? v) => v == null ? '—' : '₹${_inr.format(v)}';
  String _v(String? v) => (v == null || v.isEmpty) ? '—' : v;

  String _date(String? raw) {
    if (raw == null || raw.isEmpty) return '—';
    final dt = DateTime.tryParse(raw);
    return dt == null ? raw : DateFormat('dd MMM yyyy').format(dt.toLocal());
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'PAID':
        return Colors.green;
      case 'CREATED':
        return Colors.blue;
      case 'PENDING':
        return Colors.amber.shade700;
      case 'FAILED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'PAID':
        return 'Paid';
      case 'CREATED':
        return 'Order Created';
      case 'PENDING':
        return 'Pending';
      case 'FAILED':
        return 'Failed';
      case '':
        return '—';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Drop the previous user's data immediately and reload for the new user.
    ref.listen<String?>(authServiceProvider.select((s) => s.user?.id), (prev, next) {
      if (prev == next) return;
      _requestId++; // invalidate in-flight requests of the previous user
      _searchController.clear();
      setState(() {
        _invoices = [];
        _error = null;
        _searchTerm = '';
        _statusFilter = 'ALL';
        _isLoading = next != null && _canAccess;
      });
      if (next != null && _canAccess) _load();
    });

    final glass = context.glass;
    final content = !_canAccess
        ? _centerMessage(glass, Icons.lock_outline, 'Access restricted', 'You do not have permission to view benefit invoices.')
        : _body(glass);

    if (!widget.showAppBar) return Material(color: Colors.transparent, child: content);

    return GlassScaffold(
      title: 'Benefit Invoices',
      body: content,
    );
  }

  Widget _body(dynamic glass) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(_error!, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: glass.textPrimary)),
              const SizedBox(height: 16),
              AppButton(label: 'Retry', icon: Icons.refresh, width: 160, height: 44, onPressed: _load),
            ],
          ),
        ),
      );
    }

    final filtered = _filtered;
    final paid = _invoices.where((i) => i.status == 'PAID').length;
    // TODO: verify against Angular's definition of "pending".
    final pending = _invoices.where((i) => i.status != 'PAID' && i.status != 'FAILED').length;
    final filteredTotal = filtered.fold<double>(0, (sum, i) => sum + (i.totalAmount ?? 0));

    return RefreshIndicator(
      onRefresh: _load,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('All benefit payment invoices across the organization', style: TextStyle(color: glass.textSecondary, fontSize: 13)),
                  const SizedBox(height: 16),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _statPill(glass, Icons.description_outlined, Colors.indigo, '${_invoices.length}', 'Total'),
                        const SizedBox(width: 8),
                        _statPill(glass, Icons.check_circle_outline, Colors.green, '$paid', 'Paid'),
                        const SizedBox(width: 8),
                        _statPill(glass, Icons.hourglass_top, Colors.amber.shade700, '$pending', 'Pending'),
                        const SizedBox(width: 8),
                        _statPill(glass, Icons.account_balance_wallet_outlined, Colors.green.shade700, _money(filteredTotal), 'Total Amount'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _searchController,
                    style: TextStyle(color: glass.textPrimary, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Search by invoice, employee or benefit',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onChanged: (val) => setState(() => _searchTerm = val),
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _chip(glass, 'All', 'ALL'),
                        const SizedBox(width: 8),
                        _chip(glass, 'Paid', 'PAID'),
                        const SizedBox(width: 8),
                        _chip(glass, 'Pending', 'PENDING'),
                        const SizedBox(width: 8),
                        _chip(glass, 'Order Created', 'CREATED'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          if (filtered.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _centerMessage(
                glass,
                Icons.receipt_long,
                'No Invoices',
                _invoices.isEmpty ? 'No benefit invoices found.' : 'No invoices match your search or filter.',
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              sliver: SliverList.builder(
                itemCount: filtered.length,
                itemBuilder: (context, index) => _invoiceCard(glass, filtered[index]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _centerMessage(dynamic glass, IconData icon, String title, String subtitle) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: glass.textSecondary),
            const SizedBox(height: 12),
            Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: glass.textPrimary)),
            const SizedBox(height: 4),
            Text(subtitle, textAlign: TextAlign.center, style: TextStyle(color: glass.textSecondary, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _invoiceCard(dynamic glass, BenefitInvoiceModel inv) {
    final color = _statusColor(inv.status);
    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      onTap: () => _showInvoiceSheet(inv),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(_v(inv.invoiceNumber),
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: glass.textPrimary)),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withOpacity(0.35)),
                ),
                child: Text(_statusLabel(inv.status), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text('${_v(inv.employeeName)}${inv.employeeCode != null ? ' (${inv.employeeCode})' : ''}',
              style: TextStyle(fontSize: 13, color: glass.textPrimary)),
          Text('${_v(inv.benefitName)}${inv.benefitCode != null ? ' (${inv.benefitCode})' : ''}',
              style: TextStyle(fontSize: 12, color: glass.textSecondary)),
          const SizedBox(height: 2),
          Text('Payment: ${_v(inv.paymentMethod)}', style: TextStyle(fontSize: 12, color: glass.textSecondary)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_money(inv.totalAmount), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.green)),
              Text(_date(inv.invoiceDate), style: TextStyle(fontSize: 12, color: glass.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statPill(dynamic glass, IconData icon, Color color, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: glass.cardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text('$label: ', style: TextStyle(fontSize: 12, color: glass.textSecondary)),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: glass.textPrimary)),
        ],
      ),
    );
  }

  Widget _chip(dynamic glass, String label, String value) {
    final active = _statusFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: active,
      onSelected: (selected) {
        if (selected) setState(() => _statusFilter = value);
      },
      selectedColor: AppColors.primary.withOpacity(0.2),
      labelStyle: TextStyle(
        color: active ? AppColors.primary : glass.textPrimary,
        fontWeight: active ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
    );
  }

  void _showInvoiceSheet(BenefitInvoiceModel inv) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final glass = context.glass;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.85,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF141D2E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('BENEFIT PAYMENT INVOICE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary)),
                      const SizedBox(height: 4),
                      Text('Invoice #: ${_v(inv.invoiceNumber)}', style: TextStyle(color: glass.textSecondary, fontSize: 13)),
                    ],
                  ),
                ),
                IconButton(icon: Icon(Icons.close, color: glass.textPrimary), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            const Divider(height: 24),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Invoice Date', style: TextStyle(color: glass.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
                        Text(_date(inv.invoiceDate), style: TextStyle(fontWeight: FontWeight.bold, color: glass.textPrimary)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _detailBlock(glass, 'EMPLOYEE DETAILS', _v(inv.employeeName), _v(inv.employeeCode))),
                        Expanded(child: _detailBlock(glass, 'BENEFIT PLAN', _v(inv.benefitName), _v(inv.benefitCode))),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: glass.cardBorder),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: glass.cardBorder.withOpacity(0.25),
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Description', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: glass.textPrimary)),
                                Text('Amount', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: glass.textPrimary)),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(child: Text(_v(inv.description), style: TextStyle(fontSize: 13, color: glass.textPrimary))),
                                Text(_money(inv.amount), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: glass.textPrimary)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        border: Border.all(color: Colors.green.withOpacity(0.3)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Text('TOTAL SETTLEMENT AMOUNT', style: TextStyle(color: glass.textSecondary, fontSize: 11, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          Text(_money(inv.totalAmount), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text('Status: ${_statusLabel(inv.status)}', style: TextStyle(color: glass.textSecondary, fontSize: 12)),
                    const SizedBox(height: 6),
                    Text('Payment Method: ${_v(inv.paymentMethod)}', style: TextStyle(color: glass.textSecondary, fontSize: 12)),
                    if (inv.razorpayPaymentId != null) ...[
                      const SizedBox(height: 6),
                      Text('Ref ID: ${inv.razorpayPaymentId}', style: TextStyle(color: glass.textPrimary, fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            // PDF download/print is intentionally not offered until a real export is approved.
            AppButton(label: 'Close', onPressed: () => Navigator.pop(ctx)),
          ],
        ),
      ),
    );
  }

  Widget _detailBlock(dynamic glass, String heading, String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(heading, style: TextStyle(color: glass.textSecondary, fontSize: 11, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: glass.textPrimary)),
        Text(subtitle, style: TextStyle(color: glass.textSecondary, fontSize: 12)),
      ],
    );
  }
}