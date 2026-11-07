import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/glass_theme.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../shared/widgets/app_card.dart';
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
  String _selectedBalanceSegment = 'ALL';
  String _selectedLeaveType = 'Sick Leave';
  int _activeLeaveTab = 0; // 0 = Leave Balances, 1 = Leave History & Status

  List<dynamic> get _filteredBalances {
    if (_selectedBalanceSegment == 'USED') {
      final list = _balances.where((b) {
        final remaining = b['remaining'] ?? 0;
        final total = b['entitled'] ?? b['total'] ?? 0;
        final used = b['taken'] ?? b['used'] ?? (total - remaining);
        return used > 0;
      }).toList();
      return list.isNotEmpty ? list : _balances;
    } else if (_selectedBalanceSegment == 'REMAINING') {
      final list = _balances.where((b) {
        final remaining = b['remaining'] ?? 0;
        return remaining > 0;
      }).toList();
      return list.isNotEmpty ? list : _balances;
    }
    return _balances;
  }

  Map<String, dynamic>? get _currentSelectedBalance {
    final list = _filteredBalances;
    if (list.isEmpty) return null;
    final match = list.firstWhere(
      (b) => (b['leaveType'] ?? b['type'] ?? '') == _selectedLeaveType,
      orElse: () => list.first,
    );
    return Map<String, dynamic>.from(match);
  }

  @override
  void initState() {
    super.initState();
    _fetchLeaveData();
  }

  Future<void> _cancelLeave(String id) async {
    final apiClient = ref.read(apiClientProvider);
    try {
      await apiClient.post('/leave/$id/cancel', body: {});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Leave request cancelled successfully.')));
      _fetchLeaveData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to cancel leave request: $e')));
    }
  }

  String _normalizeBalanceType(String rawType) {
    if (rawType.isEmpty) return 'Leave';
    final clean = rawType.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '_');
    if (clean.contains('PAID_HOLIDAY') || clean == 'PAID') return 'Paid Leave';
    if (clean.contains('EARNED')) return 'Earned Leave';
    if (clean.contains('COMPENSATORY') || clean.contains('COMP')) return 'Compensatory Leave';
    if (clean.contains('CASUAL')) return 'Casual Leave';
    if (clean.contains('SICK')) return 'Sick Leave';
    if (clean.contains('UNPAID')) return 'Unpaid Leave';
    if (clean.contains('PERSONAL')) return 'Personal Leave';
    return rawType.replaceAll('_', ' ');
  }

  bool _isExcludedBalanceType(String rawType) {
    if (rawType.isEmpty) return false;
    final clean = rawType.trim().toUpperCase();
    return clean.contains('BEREAVEMENT') || clean.contains('MATERNITY') || clean.contains('PATERNITY');
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
          } else {
            _leaveRequests = [];
          }

          List<dynamic> rawBalances = [];
          if (balances is List) {
            rawBalances = balances;
          } else if (balances is Map<String, dynamic> && balances['data'] is List) {
            rawBalances = balances['data'];
          }

          final mappedBalances = <String, Map<String, dynamic>>{};

          for (final b in rawBalances) {
            if (b is Map) {
              final rawType = (b['leaveType'] ?? b['type'] ?? '').toString();
              if (_isExcludedBalanceType(rawType)) continue;

              final normName = _normalizeBalanceType(rawType);
              final total = int.tryParse(b['entitled']?.toString() ?? b['total']?.toString() ?? '0') ?? 0;
              final used = int.tryParse(b['taken']?.toString() ?? b['used']?.toString() ?? '0') ?? 0;
              final rem = (b['remaining'] != null)
                  ? (int.tryParse(b['remaining'].toString()) ?? 0)
                  : (total - used).clamp(0, 9999);

              mappedBalances[normName] = {
                'leaveType': normName,
                'entitled': total,
                'taken': used,
                'remaining': rem < 0 ? 0 : rem,
              };
            }
          }

          final requiredDefaults = [
            {'type': 'Earned Leave', 'defaultTotal': 15},
            {'type': 'Sick Leave', 'defaultTotal': 10},
            {'type': 'Paid Leave', 'defaultTotal': 15},
            {'type': 'Casual Leave', 'defaultTotal': 12},
            {'type': 'Compensatory Leave', 'defaultTotal': 5},
            {'type': 'Unpaid Leave', 'defaultTotal': 0},
            {'type': 'Personal Leave', 'defaultTotal': 5},
          ];

          for (final req in requiredDefaults) {
            final t = req['type'] as String;
            if (!mappedBalances.containsKey(t)) {
              mappedBalances[t] = {
                'leaveType': t,
                'entitled': req['defaultTotal'],
                'taken': 0,
                'remaining': req['defaultTotal'],
              };
            }
          }

          final order = ['Earned Leave', 'Sick Leave', 'Paid Leave', 'Casual Leave', 'Compensatory Leave', 'Unpaid Leave', 'Personal Leave'];
          _balances = [];
          for (final name in order) {
            if (mappedBalances.containsKey(name)) {
              _balances.add(mappedBalances[name]!);
            }
          }
          for (final entry in mappedBalances.entries) {
            if (!order.contains(entry.key)) {
              _balances.add(entry.value);
            }
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
      final email = (l['companyEmail'] ?? l['email'] ?? '').toString().toLowerCase();

      final matchesStatus = _selectedStatusFilter == 'ALL' || status == _selectedStatusFilter;
      final matchesSearch = _searchTerm.isEmpty ||
          type.contains(_searchTerm.toLowerCase()) ||
          reason.contains(_searchTerm.toLowerCase()) ||
          email.contains(_searchTerm.toLowerCase());

      return matchesStatus && matchesSearch;
    }).toList();
  }

  int get _pendingCount => _leaveRequests.where((l) => (l['status'] ?? '').toUpperCase() == 'PENDING').length;
  int get _approvedCount => _leaveRequests.where((l) => (l['status'] ?? '').toUpperCase() == 'APPROVED').length;
  int get _totalRemaining => _balances.fold(0, (sum, b) => sum + (int.tryParse(b['remaining']?.toString() ?? '0') ?? 0));
  int get _totalApplied => _leaveRequests.length;

  void _showApplyLeaveModal() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ApplyLeaveScreen()),
    ).then((_) => _fetchLeaveData());
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final glass = context.glass;

    if (_isLoading) {
      final skeleton = const Padding(
        padding: EdgeInsets.all(16),
        child: ListSkeleton(itemCount: 4),
      );
      if (widget.showAppBar) {
        return GlassScaffold(
          title: 'My Leave',
          body: skeleton,
        );
      }
      return skeleton;
    }

    final content = RefreshIndicator(
      onRefresh: _fetchLeaveData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Compact Action Header Section
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF1B2A38), const Color(0xFF0F2E2C)]
                      : [Colors.white, const Color(0xFFF0FDFB)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary.withOpacity(0.18)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Manage Your Leave',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Track balances and apply for time off',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: _showApplyLeaveModal,
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('Apply Leave', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // 1. DYNAMIC KPI OVERVIEW CARDS (Compact 2x2 Grid)
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 2.3,
              children: [
                _statCard('Total Days Available', '$_totalRemaining', Icons.event_available_rounded, const Color(0xFF2563EB), const Color(0xFFEFF6FF), isDark),
                _statCard('Pending Approval', '$_pendingCount', Icons.access_time_rounded, const Color(0xFFD97706), const Color(0xFFFFFBEB), isDark),
                _statCard('Approved Leaves', '$_approvedCount', Icons.check_circle_rounded, const Color(0xFF10B981), const Color(0xFFECFDF5), isDark),
                _statCard('Total Applications', '$_totalApplied', Icons.list_alt_rounded, const Color(0xFF7C3AED), const Color(0xFFF5F3FF), isDark),
              ],
            ),
            const SizedBox(height: 16),

            // 2. SEGMENTED TAB BAR (Leave Balances vs Leave History & Status)
            _buildMainLeaveTabBar(isDark),
            const SizedBox(height: 16),

            // 3. TAB CONTENT
            if (_activeLeaveTab == 0) ...[
              // TAB 1: INTERACTIVE LEAVE BALANCE PANEL
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.pie_chart_rounded, size: 18, color: AppColors.primary),
                            const SizedBox(width: 8),
                            Text('Leave Balances', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: glass.textPrimary)),
                          ],
                        ),
                        Text('Interactive Exploration', style: TextStyle(fontSize: 11, color: glass.textSecondary, fontWeight: FontWeight.w500)),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // 1. Segmented Control Tabs (All Leaves, Used, Remaining)
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF131E29) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isDark ? AppColors.darkBordersAndDividers : const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          _balanceSegmentTab('ALL', 'All Leaves'),
                          _balanceSegmentTab('USED', 'Used'),
                          _balanceSegmentTab('REMAINING', 'Remaining'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 2. Selectable Leave Category Chips
                    Text('Select Leave Type', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: glass.textSecondary)),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: _filteredBalances.map((b) {
                          final type = b['leaveType']?.toString() ?? b['type']?.toString() ?? 'Leave';
                          final shortName = type.replaceAll(' Leave', '');
                          final isSelected = (_currentSelectedBalance?['leaveType'] ?? '') == type;

                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: GestureDetector(
                              onTap: () {
                                setState(() => _selectedLeaveType = type);
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.primary
                                      : (isDark ? const Color(0xFF1A2632) : Colors.white),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isSelected
                                        ? AppColors.primary
                                        : (isDark ? AppColors.darkBordersAndDividers : const Color(0xFFCBD5E1)),
                                  ),
                                ),
                                child: Text(
                                  shortName,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                    color: isSelected
                                        ? Colors.white
                                        : (isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // 3. Dynamic Selected Category Balance Details Card
                    if (_currentSelectedBalance != null) ...[
                      Builder(builder: (context) {
                        final curr = _currentSelectedBalance!;
                        final name = curr['leaveType']?.toString() ?? curr['type']?.toString() ?? 'Leave';
                        final remaining = curr['remaining'] ?? 0;
                        final total = curr['entitled'] ?? curr['total'] ?? 0;
                        final used = curr['taken'] ?? curr['used'] ?? (total - remaining);
                        final progress = total > 0 ? (used / total).clamp(0.0, 1.0) : 0.0;

                        final isShowingUsed = _selectedBalanceSegment == 'USED';

                        return AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          child: Container(
                            key: ValueKey('${name}_$_selectedBalanceSegment'),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1A2632) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.primary.withOpacity(0.25)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      name,
                                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: glass.textPrimary),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Text(
                                        'Selected',
                                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.primary),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.baseline,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    Text(
                                      isShowingUsed ? '$used' : '$remaining',
                                      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: AppColors.primary),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      isShowingUsed ? '/ $total days used' : '/ $total days remaining',
                                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: glass.textSecondary),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: progress,
                                    backgroundColor: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                                    color: AppColors.primary,
                                    minHeight: 6,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Used: $used days', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: glass.textSecondary)),
                                    Text('Entitled: $total days', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: glass.textSecondary)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  ],
                ),
              ),
            ] else ...[
              // TAB 2: LEAVE HISTORY & STATUS SECTION
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.history_rounded, size: 18, color: AppColors.primary),
                            const SizedBox(width: 8),
                            Text('Leave History & Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: glass.textPrimary)),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${_filteredHistory.length} Records',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    // Modern Segmented Filter Tabs
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: [
                          _filterTab('ALL', 'All'),
                          const SizedBox(width: 8),
                          _filterTab('PENDING', 'Pending'),
                          const SizedBox(width: 8),
                          _filterTab('APPROVED', 'Approved'),
                          const SizedBox(width: 8),
                          _filterTab('REJECTED', 'Rejected'),
                          const SizedBox(width: 8),
                          _filterTab('CANCELLED', 'Cancelled'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Modern Search Field
                    TextField(
                      onChanged: (val) => setState(() => _searchTerm = val),
                      style: TextStyle(color: glass.textPrimary, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Search by leave type, reason...',
                        hintStyle: TextStyle(color: glass.textSecondary, fontSize: 13),
                        prefixIcon: Icon(Icons.search_rounded, size: 18, color: glass.textSecondary),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF1A2632) : AppColors.lightInputBackground,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? AppColors.darkBordersAndDividers : const Color(0xFFE2E8F0))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? AppColors.darkBordersAndDividers : const Color(0xFFE2E8F0))),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _filteredHistory.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                'No leave records match your filter.',
                                style: TextStyle(color: glass.textSecondary, fontSize: 13),
                              ),
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _filteredHistory.length,
                            itemBuilder: (context, index) {
                              final h = _filteredHistory[index];
                              final type = h['leaveType']?.toString() ?? h['type']?.toString() ?? 'Casual Leave';
                              final startDate = _formatReadableDate(h['startDate']?.toString());
                              final endDate = _formatReadableDate(h['endDate']?.toString());
                              final status = h['status']?.toString() ?? 'PENDING';
                              final reason = h['reason']?.toString() ?? '--';
                              final id = h['id']?.toString() ?? '';
                              final canCancel = status.toUpperCase() == 'PENDING';
                              final days = h['totalDays'] ?? h['days'] ?? 1;
                              final reviewer = h['approvedBy'] ?? h['reviewedBy'] ?? '--';

                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1A2632) : Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: isDark ? AppColors.darkBordersAndDividers : const Color(0xFFE2E8F0)),
                                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.02), blurRadius: 6, offset: const Offset(0, 2))],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: AppColors.primary.withOpacity(0.12),
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              child: const Icon(Icons.event_note_rounded, color: AppColors.primary, size: 16),
                                            ),
                                            const SizedBox(width: 10),
                                            Text(
                                              type,
                                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: glass.textPrimary),
                                            ),
                                          ],
                                        ),
                                        StatusChip(status: status),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        Icon(Icons.date_range_rounded, size: 14, color: glass.textSecondary),
                                        const SizedBox(width: 6),
                                        Text(
                                          '$startDate → $endDate',
                                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: glass.textPrimary),
                                        ),
                                        const Spacer(),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary.withOpacity(0.08),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            '$days day${days > 1 ? 's' : ''}',
                                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (reason.isNotEmpty && reason != '--') ...[
                                      const SizedBox(height: 6),
                                      Text(
                                        'Reason: $reason',
                                        style: TextStyle(fontSize: 11.5, color: glass.textSecondary),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Reviewer: $reviewer',
                                          style: TextStyle(fontSize: 11, color: glass.textSecondary),
                                        ),
                                        if (canCancel)
                                          TextButton.icon(
                                            onPressed: () => _cancelLeave(id),
                                            icon: const Icon(Icons.close_rounded, size: 13, color: Colors.redAccent),
                                            label: const Text('Cancel', style: TextStyle(fontSize: 11, color: Colors.redAccent, fontWeight: FontWeight.bold)),
                                            style: TextButton.styleFrom(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              minimumSize: const Size(0, 24),
                                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ],
                ),
              ),
            ],
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

  Widget _statCard(String label, String value, IconData icon, Color color, Color bg, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A2632) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? AppColors.darkBordersAndDividers : const Color(0xFFE2E8F0)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.02), blurRadius: 6, offset: const Offset(0, 2))],
      ),
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
                Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
                const SizedBox(height: 1),
                Text(label, style: TextStyle(fontSize: 10.5, color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatReadableDate(String? isoStr) {
    if (isoStr == null || isoStr.trim().isEmpty || isoStr == '--') return '--';
    try {
      final dt = DateTime.parse(isoStr);
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${dt.day.toString().padLeft(2, '0')} ${months[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return isoStr;
    }
  }

  Widget _filterTab(String status, String label) {
    final isSelected = _selectedStatusFilter == status;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () => setState(() => _selectedStatusFilter = status),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : (isDark ? const Color(0xFF1A2632) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? AppColors.primary : (isDark ? AppColors.darkBordersAndDividers : const Color(0xFFE2E8F0))),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            color: isSelected ? Colors.white : (isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText),
          ),
        ),
      ),
    );
  }

  Widget _buildMainLeaveTabBar(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131E29) : const Color(0xFFEEF2F8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? AppColors.darkBordersAndDividers : const Color(0xFFDCE8E7)),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _activeLeaveTab = 0),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _activeLeaveTab == 0 ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.pie_chart_rounded,
                      size: 16,
                      color: _activeLeaveTab == 0 ? Colors.white : (isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Leave Balances',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12.5,
                        color: _activeLeaveTab == 0 ? Colors.white : (isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _activeLeaveTab = 1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _activeLeaveTab == 1 ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.history_rounded,
                      size: 16,
                      color: _activeLeaveTab == 1 ? Colors.white : (isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Leave History',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12.5,
                        color: _activeLeaveTab == 1 ? Colors.white : (isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText),
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

  Widget _balanceSegmentTab(String value, String label) {
    final isSelected = _selectedBalanceSegment == value;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedBalanceSegment = value;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? (isDark ? AppColors.primary : Colors.white) : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: isSelected && !isDark
                ? [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4, offset: const Offset(0, 2))]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
              color: isSelected
                  ? (isDark ? Colors.white : AppColors.primary)
                  : (isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText),
            ),
          ),
        ),
      ),
    );
  }
}
