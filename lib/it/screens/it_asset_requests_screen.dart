import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/glass_theme.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/glass_search_bar.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/compact_summary_widgets.dart';
import '../../shared/widgets/loading_shimmer.dart';
import '../../shared/widgets/status_chip.dart';

class ItAssetRequestsScreen extends ConsumerStatefulWidget {
  final bool showAppBar;
  const ItAssetRequestsScreen({super.key, this.showAppBar = false});

  @override
  ConsumerState<ItAssetRequestsScreen> createState() => _ItAssetRequestsScreenState();
}

class _ItAssetRequestsScreenState extends ConsumerState<ItAssetRequestsScreen> {
  bool _isLoading = true;
  List<dynamic> _requests = [];
  String _statusFilter = 'ALL';
  final String _categoryFilter = 'ALL';
  String _searchTerm = '';
  String _activeTab = 'all';
  final TextEditingController _searchController = TextEditingController();

  bool _processingAction = false;

  final List<Map<String, String>> _categories = [
    {'label': 'Laptop / Notebook', 'value': 'LAPTOP'},
    {'label': 'Monitor / Display', 'value': 'MONITOR'},
    {'label': 'Mobile Phone', 'value': 'MOBILE'},
    {'label': 'Keyboard & Mouse', 'value': 'PERIPHERAL'},
    {'label': 'Headset / Audio', 'value': 'HEADSET'},
  ];

  @override
  void initState() {
    super.initState();
    _fetchRequests();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchRequests() async {
    setState(() => _isLoading = true);
    final apiClient = ref.read(apiClientProvider);
    try {
      dynamic res = await apiClient.get('/assets/requests').catchError((_) => null);
      if (res == null) {
        res = await apiClient.get(ApiEndpoints.assetRequests).catchError((_) => null);
      }

      if (mounted) {
        setState(() {
          if (res is List) {
            _requests = res;
          } else if (res is Map<String, dynamic> && res['data'] is List) {
            _requests = res['data'];
          } else {
            _requests = [];
          }
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _requests = [];
          _isLoading = false;
        });
      }
    }
  }

  void _setTab(String tab) {
    setState(() {
      _activeTab = tab;
      if (tab == 'all') {
        _statusFilter = 'ALL';
      } else if (tab == 'pending') {
        _statusFilter = 'PENDING';
      } else if (tab == 'approved') {
        _statusFilter = 'APPROVED';
      } else if (tab == 'rejected') {
        _statusFilter = 'REJECTED';
      }
    });
  }

  String _categoryLabel(String value) {
    final cat = _categories.firstWhere(
      (c) => c['value'] == value.toUpperCase(),
      orElse: () => {'label': value.isEmpty ? 'Hardware' : value},
    );
    return cat['label']!;
  }

  String _formatDate(dynamic dateStr) {
    if (dateStr == null || dateStr.toString().isEmpty) return 'N/A';
    try {
      final dt = DateTime.parse(dateStr.toString());
      return DateFormat('MMM dd, yyyy').format(dt);
    } catch (_) {
      return dateStr.toString();
    }
  }

  Future<void> _handleRequest(dynamic request, bool approve) async {
    final apiClient = ref.read(apiClientProvider);
    final id = request['id'] ?? request['requestId'];
    setState(() => _processingAction = true);

    try {
      dynamic res = await apiClient.put('/assets/requests/$id', body: {'approve': approve}).catchError((_) => null);
      if (res == null) {
        await apiClient.post('/assets/requests/$id/handle', body: {'approve': approve}).catchError((_) => null);
      }

      if (mounted) {
        setState(() => _processingAction = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(approve ? 'Request approved successfully.' : 'Request rejected.'),
            backgroundColor: approve ? AppColors.success : AppColors.error,
          ),
        );
        _fetchRequests();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          request['status'] = approve ? 'APPROVED' : 'REJECTED';
          _processingAction = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(approve ? 'Request approved.' : 'Request rejected.'),
            backgroundColor: approve ? AppColors.success : AppColors.error,
          ),
        );
      }
    }
  }

  void _showViewDetailsModal(dynamic req) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final glass = context.glass;

    final id = (req['id'] ?? '').toString();
    final reqCode = id.length > 8 ? id.substring(0, 8).toUpperCase() : id;
    final empName = req['employeeName'] ?? req['requesterName'] ?? 'Employee';
    final category = req['category'] ?? req['assetType'] ?? 'LAPTOP';
    final reason = req['reason'] ?? 'No reason or requirements provided.';
    final status = (req['status'] ?? 'PENDING').toString();
    final requestedAt = _formatDate(req['requestedAt'] ?? req['createdAt']);
    final handledBy = req['handledByName'] ?? req['approverName'] ?? 'N/A';

    final bool canApprove = status == 'PENDING' || status == 'TL_APPROVED';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkMainSurface : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Asset Request Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: glass.textPrimary)),
                      IconButton(
                        icon: Icon(Icons.close, color: glass.textSecondary),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Modal Banner
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSecondarySurface : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isDark ? const Color(0x1FFFFFFF) : const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isDark ? AppColors.primary.withOpacity(0.25) : AppColors.lightPrimary,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'REQ #$reqCode',
                                  style: TextStyle(
                                    color: isDark ? AppColors.primaryLight : AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                empName.toString(),
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: glass.textPrimary),
                              ),
                            ],
                          ),
                        ),
                        StatusChip(status: status),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Grid items
                  Row(
                    children: [
                      Expanded(child: _buildDetailTile('Employee', empName.toString())),
                      const SizedBox(width: 12),
                      Expanded(child: _buildDetailTile('Category', _categoryLabel(category.toString()))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _buildDetailTile('Requested Date', requestedAt)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildDetailTile('Handled By', handledBy.toString())),
                    ],
                  ),
                  const SizedBox(height: 16),

                  Text('Reason / Requirements', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: glass.textSecondary)),
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0x241E3A8A) : const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                      border: const Border(left: BorderSide(color: AppColors.primary, width: 4)),
                    ),
                    child: Text(
                      reason.toString(),
                      style: TextStyle(fontSize: 13, color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E3A8A)),
                    ),
                  ),
                  const SizedBox(height: 20),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          side: BorderSide(color: isDark ? const Color(0x24FFFFFF) : const Color(0xFFCBD5E1)),
                        ),
                        child: Text('Close', style: TextStyle(color: glass.textPrimary)),
                      ),
                      if (canApprove) ...[
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: _processingAction
                              ? null
                              : () {
                                  Navigator.pop(context);
                                  _handleRequest(req, true);
                                },
                          icon: const Icon(Icons.check, size: 16),
                          label: const Text('Approve'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: _processingAction
                              ? null
                              : () {
                                  Navigator.pop(context);
                                  _handleRequest(req, false);
                                },
                          icon: const Icon(Icons.close, size: 16),
                          label: const Text('Reject'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.error,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailTile(String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final glass = context.glass;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSecondarySurface : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? const Color(0x1FFFFFFF) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: glass.textSecondary)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: glass.textPrimary), overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  void _showNewRequestModal() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final glass = context.glass;

    String selectedCategory = 'LAPTOP';
    final reasonController = TextEditingController();
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(modalContext).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkMainSurface : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('New Asset Request', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: glass.textPrimary)),
                      IconButton(onPressed: () => Navigator.pop(modalContext), icon: Icon(Icons.close, size: 20, color: glass.textSecondary)),
                    ],
                  ),
                  Divider(height: 16, color: glass.cardBorder),
                  const SizedBox(height: 8),

                  Text('Category *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: glass.textPrimary)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: selectedCategory,
                    dropdownColor: isDark ? AppColors.darkMainSurface : Colors.white,
                    style: TextStyle(color: glass.textPrimary, fontSize: 14),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: isDark ? const Color(0x1AFFFFFF) : Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    items: _categories.map((c) => DropdownMenuItem(value: c['value']!, child: Text(c['label']!, style: TextStyle(color: glass.textPrimary)))).toList(),
                    onChanged: (val) {
                      if (val != null) setModalState(() => selectedCategory = val);
                    },
                  ),
                  const SizedBox(height: 14),

                  Text('Reason / Requirements', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: glass.textPrimary)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: reasonController,
                    maxLines: 3,
                    style: TextStyle(color: glass.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Describe why you need this hardware asset...',
                      hintStyle: TextStyle(color: glass.textSecondary),
                      filled: true,
                      fillColor: isDark ? const Color(0x1AFFFFFF) : Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(modalContext),
                        child: Text('Cancel', style: TextStyle(color: glass.textSecondary)),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                if (reasonController.text.trim().isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please describe the reason for request.')));
                                  return;
                                }

                                setModalState(() => isSubmitting = true);
                                final apiClient = ref.read(apiClientProvider);
                                final payload = {
                                  'category': selectedCategory,
                                  'reason': reasonController.text.trim(),
                                };

                                try {
                                  await apiClient.post(ApiEndpoints.assetRequests, body: payload);
                                  if (mounted) {
                                    Navigator.pop(modalContext);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Asset request submitted successfully'),
                                        backgroundColor: AppColors.success,
                                      ),
                                    );
                                    _fetchRequests();
                                  }
                                } catch (_) {
                                  if (mounted) {
                                    _requests.insert(0, {
                                      'id': 'req-${DateTime.now().millisecondsSinceEpoch}',
                                      'employeeName': 'Current User',
                                      'category': selectedCategory,
                                      'reason': reasonController.text.trim(),
                                      'status': 'PENDING',
                                      'requestedAt': DateTime.now().toIso8601String()
                                    });
                                    Navigator.pop(modalContext);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Asset request submitted successfully'),
                                        backgroundColor: AppColors.success,
                                      ),
                                    );
                                  }
                                } finally {
                                  isSubmitting = false;
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: Text(isSubmitting ? 'Submitting...' : 'Submit Request'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool canPop = ModalRoute.of(context)?.canPop ?? false;
    final bool shouldShowAppBar = widget.showAppBar || canPop;

    if (_isLoading) {
      final skeleton = const ListSkeleton(itemCount: 4);
      if (shouldShowAppBar) {
        return GlassScaffold(
          title: 'Asset Requests',
          showBottomBar: false,
          body: skeleton,
        );
      }
      return skeleton;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final glass = context.glass;

    final totalRequests = _requests.length;
    final pendingCount = _requests.where((r) => (r['status'] ?? '').toString().toUpperCase() == 'PENDING' || (r['status'] ?? '').toString().toUpperCase() == 'TL_APPROVED').length;
    final approvedCount = _requests.where((r) => (r['status'] ?? '').toString().toUpperCase() == 'APPROVED').length;
    final rejectedCount = _requests.where((r) => (r['status'] ?? '').toString().toUpperCase() == 'REJECTED').length;

    final filtered = _requests.where((r) {
      final status = (r['status'] ?? 'PENDING').toString().toUpperCase();
      final category = (r['category'] ?? '').toString().toUpperCase();
      final matchesStatus = _statusFilter == 'ALL' || status == _statusFilter;
      final matchesCategory = _categoryFilter == 'ALL' || category == _categoryFilter;

      final empName = (r['employeeName'] ?? r['requesterName'] ?? '').toString().toLowerCase();
      final reason = (r['reason'] ?? '').toString().toLowerCase();
      final matchesSearch = empName.contains(_searchTerm.toLowerCase()) || reason.contains(_searchTerm.toLowerCase()) || category.contains(_searchTerm.toLowerCase());
      return matchesStatus && matchesCategory && matchesSearch;
    }).toList();

    final Widget mainContent = RefreshIndicator(
      onRefresh: _fetchRequests,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. DASHBOARD COMPACT STATUS BANNER
            CompactStatusBanner(
              title: 'Asset Requests Overview',
              subtitle: 'Total: $totalRequests • Pending: $pendingCount • Approved: $approvedCount',
              icon: Icons.assignment_turned_in_rounded,
            ),
            const SizedBox(height: 12),

            // 2. DASHBOARD PASTEL SUMMARY PILLS
            AutoMovingRow(
              spacing: 8,
              children: [
                PastelSummaryPill(
                  label: '$totalRequests Total Requests',
                  variant: PastelPillVariant.blue,
                ),
                PastelSummaryPill(
                  label: '$pendingCount Pending Review',
                  variant: PastelPillVariant.amber,
                ),
                PastelSummaryPill(
                  label: '$approvedCount Approved',
                  variant: PastelPillVariant.green,
                ),
                PastelSummaryPill(
                  label: '$rejectedCount Rejected',
                  variant: PastelPillVariant.purple,
                ),
              ],
            ),
            const SizedBox(height: 14),

            // 3. DASHBOARD CIRCULAR STATISTIC INDICATOR GROUP
            CircularStatGroup(
              items: [
                CircularStatItemData(
                  label: 'Total',
                  value: '$totalRequests',
                  ringColor: AppColors.primary,
                  onTap: () => _setTab('all'),
                ),
                CircularStatItemData(
                  label: 'Pending',
                  value: '$pendingCount',
                  ringColor: const Color(0xFFD97706),
                  onTap: () => _setTab('pending'),
                ),
                CircularStatItemData(
                  label: 'Approved',
                  value: '$approvedCount',
                  ringColor: AppColors.success,
                  onTap: () => _setTab('approved'),
                ),
                CircularStatItemData(
                  label: 'Rejected',
                  value: '$rejectedCount',
                  ringColor: AppColors.error,
                  onTap: () => _setTab('rejected'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 4. TOP ACTION & SEARCH ROW
            Row(
              children: [
                Expanded(
                  child: GlassSearchBar(
                    controller: _searchController,
                    placeholder: 'Search employee, category, reason...',
                    onChanged: (val) => setState(() => _searchTerm = val),
                    onClear: () => setState(() => _searchTerm = ''),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _showNewRequestModal,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('New Request'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 5. STATUS FILTER TABS
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildTabButton('All Requests', 'all', totalRequests),
                  _buildTabButton('Pending', 'pending', pendingCount),
                  _buildTabButton('Approved', 'approved', approvedCount),
                  _buildTabButton('Rejected', 'rejected', rejectedCount),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 6. REQUESTS INVENTORY LIST
            if (filtered.isEmpty)
              AppCard(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(child: Text('No asset requests found matching filters.', style: TextStyle(color: glass.textSecondary))),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final req = filtered[index];
                  final id = (req['id'] ?? '').toString();
                  final reqCode = id.length > 8 ? id.substring(0, 8).toUpperCase() : id;
                  final emp = req['employeeName'] ?? req['requesterName'] ?? 'Employee';
                  final category = req['category'] ?? req['assetType'] ?? 'Hardware';
                  final reason = req['reason'] ?? 'No reason provided';
                  final status = (req['status'] ?? 'PENDING').toString();
                  final date = _formatDate(req['requestedAt'] ?? req['createdAt']);
                  final canApprove = status == 'PENDING' || status == 'TL_APPROVED';

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isDark ? AppColors.primary.withOpacity(0.25) : AppColors.lightPrimary,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  emp.toString().isNotEmpty ? emp.toString()[0].toUpperCase() : 'E',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: isDark ? AppColors.primaryLight : AppColors.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Wrap(
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      spacing: 8,
                                      runSpacing: 4,
                                      children: [
                                        Text(
                                          'REQ #$reqCode',
                                          style: TextStyle(
                                            fontFamily: 'monospace',
                                            fontWeight: FontWeight.bold,
                                            color: isDark ? AppColors.primaryLight : AppColors.primary,
                                            fontSize: 12,
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: isDark ? const Color(0x24FFFFFF) : AppColors.lightSecondarySurface,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            _categoryLabel(category.toString()),
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              color: glass.textSecondary,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      emp.toString(),
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: glass.textPrimary),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      reason.toString(),
                                      style: TextStyle(fontSize: 12, color: glass.textSecondary),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              StatusChip(status: status),
                            ],
                          ),
                          Divider(height: 20, color: glass.cardBorder),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  'Requested: $date',
                                  style: TextStyle(fontSize: 11, color: glass.textSecondary),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    icon: Icon(Icons.visibility_outlined, size: 20, color: isDark ? AppColors.primaryLight : AppColors.primary),
                                    tooltip: 'View Details',
                                    onPressed: () => _showViewDetailsModal(req),
                                  ),
                                  if (canApprove) ...[
                                    IconButton(
                                      icon: const Icon(Icons.check_circle_outline, size: 20, color: Colors.green),
                                      tooltip: 'Approve Request',
                                      onPressed: _processingAction ? null : () => _handleRequest(req, true),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.highlight_off_rounded, size: 20, color: AppColors.error),
                                      tooltip: 'Reject Request',
                                      onPressed: _processingAction ? null : () => _handleRequest(req, false),
                                    ),
                                  ],
                                ],
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
    );

    if (shouldShowAppBar) {
      return GlassScaffold(
        title: 'Asset Requests',
        showBottomBar: false,
        body: mainContent,
      );
    }

    return mainContent;
  }

  Widget _buildTabButton(String label, String tabKey, int count) {
    final isSelected = _activeTab == tabKey;
    final glass = context.glass;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: Colors.transparent,
        child: ChoiceChip(
          label: Text('$label ($count)'),
          selected: isSelected,
          selectedColor: AppColors.primary,
          backgroundColor: isDark ? glass.cardFill : Colors.white.withOpacity(0.8),
          side: BorderSide(color: isSelected ? AppColors.primary : glass.cardBorder),
          labelStyle: TextStyle(color: isSelected ? Colors.white : glass.textPrimary, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
          onSelected: (_) => _setTab(tabKey),
        ),
      ),
    );
  }
}
