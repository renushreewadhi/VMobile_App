import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/compact_summary_widgets.dart';
import '../../shared/widgets/loading_shimmer.dart';
import '../../shared/widgets/status_chip.dart';
import 'apply_leave_screen.dart';

class MyLeaveScreen extends ConsumerStatefulWidget {
  final bool showAppBar;
  const MyLeaveScreen({super.key, this.showAppBar = false});

  @override
  ConsumerState<MyLeaveScreen> createState() => _MyLeaveScreenState();
}

class _MyLeaveScreenState extends ConsumerState<MyLeaveScreen> {
  bool _isLoading = true;
  List<dynamic> _leaveRequests = [];
  List<dynamic> _balances = [];
  String _selectedStatusFilter = 'ALL';
  String _searchTerm = '';

  @override
  void initState() {
    super.initState();
    _fetchLeaveData();
  }

  Future<void> _fetchLeaveData() async {
    setState(() => _isLoading = true);
    final apiClient = ref.read(apiClientProvider);
    try {
      final myLeaves = await apiClient.get(ApiEndpoints.leaveMy).catchError((_) => null);
      final balances = await apiClient.get(ApiEndpoints.leaveBalances).catchError((_) => null);

      if (mounted) {
        setState(() {
          if (myLeaves is List) {
            _leaveRequests = myLeaves;
          } else if (myLeaves is Map<String, dynamic> && myLeaves['data'] is List) {
            _leaveRequests = myLeaves['data'];
          }

          if (balances is List) {
            _balances = balances;
          } else if (balances is Map<String, dynamic> && balances['data'] is List) {
            _balances = balances['data'];
          } else {
            _balances = [
              {'leaveType': 'Casual Leave', 'remaining': 12, 'entitled': 12, 'taken': 0},
              {'leaveType': 'Sick Leave', 'remaining': 10, 'entitled': 10, 'taken': 0},
              {'leaveType': 'Paid Leave', 'remaining': 15, 'entitled': 15, 'taken': 0},
              {'leaveType': 'Earned Leave', 'remaining': 15, 'entitled': 15, 'taken': 0},
            ];
          }
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<dynamic> get _filteredHistory {
    return _leaveRequests.where((l) {
      final status = (l['status'] ?? 'PENDING').toString().toUpperCase();
      final type = (l['leaveType'] ?? l['type'] ?? 'Leave').toString().toLowerCase();
      final reason = (l['reason'] ?? '').toString().toLowerCase();

      final matchesStatus = _selectedStatusFilter == 'ALL' || status == _selectedStatusFilter;
      final matchesSearch = _searchTerm.isEmpty || type.contains(_searchTerm.toLowerCase()) || reason.contains(_searchTerm.toLowerCase());

      return matchesStatus && matchesSearch;
    }).toList();
  }

  int get _pendingCount => _leaveRequests.where((l) => (l['status'] ?? '').toUpperCase() == 'PENDING').length;
  int get _approvedCount => _leaveRequests.where((l) => (l['status'] ?? '').toUpperCase() == 'APPROVED').length;
  int get _totalRemaining => _balances.fold(0, (sum, b) => sum + (int.tryParse(b['remaining']?.toString() ?? '0') ?? 0));

  void _showApplyLeaveModal() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ApplyLeaveScreen()),
    ).then((_) => _fetchLeaveData());
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      if (widget.showAppBar) {
        return Scaffold(
          appBar: AppBar(title: const Text('My Leave')),
          body: const ListSkeleton(itemCount: 4),
        );
      }
      return const ListSkeleton(itemCount: 4);
    }

    final content = RefreshIndicator(
      onRefresh: _fetchLeaveData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Page Header Actions
            if (widget.showAppBar) ...[
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: _showApplyLeaveModal,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Apply'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ] else ...[
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: _showApplyLeaveModal,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Apply Leave'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],

            // 1. PASTEL SUMMARY PILLS
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  PastelSummaryPill(
                    label: '$_totalRemaining days available',
                    variant: PastelPillVariant.green,
                  ),
                  const SizedBox(width: 8),
                  PastelSummaryPill(
                    label: '$_pendingCount pending approval',
                    variant: PastelPillVariant.amber,
                  ),
                  const SizedBox(width: 8),
                  PastelSummaryPill(
                    label: '$_approvedCount approved',
                    variant: PastelPillVariant.blue,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 2. CIRCULAR STATISTIC INDICATOR GROUP
            CircularStatGroup(
              items: [
                CircularStatItemData(
                  label: 'Available',
                  value: '$_totalRemaining',
                  ringColor: AppColors.primary,
                ),
                CircularStatItemData(
                  label: 'Pending',
                  value: '$_pendingCount',
                  ringColor: const Color(0xFFD97706),
                ),
                CircularStatItemData(
                  label: 'Approved',
                  value: '$_approvedCount',
                  ringColor: AppColors.success,
                ),
                CircularStatItemData(
                  label: 'Requests',
                  value: '${_leaveRequests.length}',
                  ringColor: const Color(0xFF2563EB),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Leave Balances Section (Option 9: Two-Row Summary + Details)
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Summary Row (Emerald Teal Banner)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0F6B66), Color(0xFF0A4F4C)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: _balances.map((b) {
                          final type = b['leaveType']?.toString() ?? b['type']?.toString() ?? 'Leave';
                          final remaining = b['remaining'] ?? 0;
                          IconData iconData = Icons.calendar_today;
                          if (type.toLowerCase().contains('sick')) iconData = Icons.healing;
                          if (type.toLowerCase().contains('paid')) iconData = Icons.work;
                          if (type.toLowerCase().contains('earned')) iconData = Icons.star;

                          return Padding(
                            padding: const EdgeInsets.only(right: 20),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(iconData, color: Colors.white, size: 16),
                                ),
                                const SizedBox(width: 10),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '$remaining',
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                                    Text(
                                      type.replaceAll(' Leave', ''),
                                      style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 11, fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Leave Balances Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      Text('As of ${DateTime.now().year}', style: const TextStyle(fontSize: 11, color: AppColors.lightSecondaryText)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _balances.length,
                    itemBuilder: (context, index) {
                      final b = _balances[index];
                      final type = b['leaveType']?.toString() ?? b['type']?.toString() ?? 'Leave';
                      final remaining = b['remaining'] ?? 0;
                      final total = b['entitled'] ?? b['total'] ?? 12;
                      final used = b['taken'] ?? (total - remaining);

                      const dotColors = [Color(0xFF10B981), Color(0xFFEF4444), Color(0xFF8B5CF6), Color(0xFFF59E0B)];
                      final dotColor = dotColors[index % dotColors.length];

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkSecondarySurface : AppColors.lightInputBackground,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: isDark ? AppColors.darkBordersAndDividers : AppColors.lightBordersAndDividers),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(type, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              ),
                              Text('$remaining days', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary)),
                              const SizedBox(width: 16),
                              Text('Used: $used', style: const TextStyle(fontSize: 11.5, color: AppColors.lightSecondaryText)),
                              const SizedBox(width: 8),
                              const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Leave History Section
            AppCard(
              child: Material(
                color: Colors.transparent,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Leave History & Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: AppColors.lightPrimary, borderRadius: BorderRadius.circular(12)),
                          child: Text('${_filteredHistory.length} Records', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Filter Pills
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _filterPill('ALL'),
                          const SizedBox(width: 6),
                          _filterPill('PENDING'),
                          const SizedBox(width: 6),
                          _filterPill('APPROVED'),
                          const SizedBox(width: 6),
                          _filterPill('REJECTED'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Search Box
                    TextField(
                      onChanged: (val) => setState(() => _searchTerm = val),
                      decoration: InputDecoration(
                        hintText: 'Search leave requests...',
                        prefixIcon: const Icon(Icons.search, size: 18),
                        filled: true,
                        fillColor: isDark ? AppColors.darkMainSurface : AppColors.lightInputBackground,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _filteredHistory.isEmpty
                        ? const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('No leave records match your filter.')))
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _filteredHistory.length,
                            itemBuilder: (context, index) {
                              final h = _filteredHistory[index];
                              final type = h['leaveType']?.toString() ?? h['type']?.toString() ?? 'Casual Leave';
                              final startDate = h['startDate']?.toString() ?? '';
                              final endDate = h['endDate']?.toString() ?? '';
                              final status = h['status']?.toString() ?? 'PENDING';
                              final reason = h['reason']?.toString() ?? '';

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: isDark ? AppColors.darkSecondarySurface : AppColors.lightInputBackground,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: isDark ? AppColors.darkBordersAndDividers : AppColors.lightBordersAndDividers),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(type, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                                            const SizedBox(height: 2),
                                            Text('$startDate  →  $endDate', style: const TextStyle(fontSize: 11.5, color: AppColors.lightSecondaryText)),
                                            if (reason.isNotEmpty) ...[
                                              const SizedBox(height: 2),
                                              Text(reason, style: const TextStyle(fontSize: 11, color: AppColors.lightMutedText), maxLines: 1, overflow: TextOverflow.ellipsis),
                                            ],
                                          ],
                                        ),
                                      ),
                                      StatusChip(status: status),
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
          ],
        ),
      ),
    );

    if (!widget.showAppBar) return content;

    return GlassScaffold(
      title: 'My Leave',
      body: content,
    );
  }

  Widget _filterPill(String status) {
    final isSelected = _selectedStatusFilter == status;
    return ChoiceChip(
      label: Text(status, style: TextStyle(fontSize: 11.5, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) setState(() => _selectedStatusFilter = status);
      },
    );
  }
}
