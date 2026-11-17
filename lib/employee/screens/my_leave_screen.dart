import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/api/leave_service.dart';
import '../../core/auth/auth_service.dart';
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
  bool _isLoadingDetails = false;
  Map<String, dynamic>? _selectedLeaveDetail;
  bool _showLeaveDetailModal = false;

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

  Future<void> _confirmCancelLeave(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Leave Request?'),
        content: const Text('Are you sure you want to cancel this leave request? This action cannot be undone.'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Cancel Leave'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _cancelLeave(id);
    }
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
    final leaveService = ref.read(leaveServiceProvider);
    try {
      final myLeaves = await leaveService.getMyLeaves().catchError((_) => null);
      final balances = await leaveService.getLeaveBalances().catchError((_) => null);

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
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF1B2A38), const Color(0xFF0F2E2C)]
                      : [Colors.white, const Color(0xFFF0FDFB)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.primary.withOpacity(0.18)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.2 : 0.02),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Manage Your Leave',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          'Track balances and apply for time off',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    height: 38,
                    child: ElevatedButton.icon(
                      onPressed: _showApplyLeaveModal,
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: const Text('Apply Leave', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // 1. DYNAMIC KPI OVERVIEW CARDS (Single row of 4 compact cards)
            Row(
              children: [
                Expanded(child: _statCard('Total Days Available', '$_totalRemaining', Icons.event_available_rounded, const Color(0xFF2563EB), const Color(0xFFEFF6FF), isDark)),
                const SizedBox(width: 6),
                Expanded(child: _statCard('Pending Approval', '$_pendingCount', Icons.access_time_rounded, const Color(0xFFD97706), const Color(0xFFFFFBEB), isDark)),
                const SizedBox(width: 6),
                Expanded(child: _statCard('Approved Leaves', '$_approvedCount', Icons.check_circle_rounded, const Color(0xFF10B981), const Color(0xFFECFDF5), isDark)),
                const SizedBox(width: 6),
                Expanded(child: _statCard('Total Applications', '$_totalApplied', Icons.list_alt_rounded, const Color(0xFF7C3AED), const Color(0xFFF5F3FF), isDark)),
              ],
            ),
            const SizedBox(height: 10),

            // 2. SEGMENTED TAB BAR (Leave Balances vs Leave History & Status)
            _buildMainLeaveTabBar(isDark),
            const SizedBox(height: 10),

            // 3. TAB CONTENT
            if (_activeLeaveTab == 0) ...[
              // TAB 1: INTERACTIVE LEAVE BALANCE PANEL
              AppCard(
                padding: const EdgeInsets.all(12),
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
                            Text('Leave Balances', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: glass.textPrimary)),
                          ],
                        ),
                        Text('Interactive Exploration', style: TextStyle(fontSize: 11, color: glass.textSecondary, fontWeight: FontWeight.w500)),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // 1. Segmented Control Tabs (All Leaves, Used, Remaining)
                    Container(
                      height: 36,
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF131E29) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: isDark ? AppColors.darkBordersAndDividers : const Color(0xFFE5E7EB)),
                      ),
                      child: Row(
                        children: [
                          _balanceSegmentTab('ALL', 'All Leaves'),
                          _balanceSegmentTab('USED', 'Used'),
                          _balanceSegmentTab('REMAINING', 'Remaining'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // 2. Selectable Leave Category Chips
                    Text('Select Leave Type', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: glass.textSecondary)),
                    const SizedBox(height: 6),
                    ShaderMask(
                      shaderCallback: (Rect bounds) {
                        return const LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [Colors.black, Colors.transparent, Colors.transparent, Colors.black],
                          stops: [0.0, 0.0, 0.96, 1.0],
                        ).createShader(bounds);
                      },
                      blendMode: BlendMode.dstOut,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Padding(
                          padding: const EdgeInsets.only(right: 16),
                          child: Row(
                            children: _filteredBalances.map((b) {
                              final type = b['leaveType']?.toString() ?? b['type']?.toString() ?? 'Leave';
                              final shortName = type.replaceAll(' Leave', '');
                              final isSelected = (_currentSelectedBalance?['leaveType'] ?? '') == type;

                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () {
                                    setState(() => _selectedLeaveType = type);
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    height: 32,
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? AppColors.primary
                                          : (isDark ? const Color(0xFF1A2632) : Colors.white),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: isSelected
                                            ? AppColors.primary
                                            : (isDark ? AppColors.darkBordersAndDividers : const Color(0xFFE5E7EB)),
                                      ),
                                    ),
                                    child: Text(
                                      shortName,
                                      style: TextStyle(
                                        fontSize: 13,
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
                      ),
                    ),
                    const SizedBox(height: 12),

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
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1A2632) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(14),
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
                                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: glass.textPrimary),
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
                                const SizedBox(height: 8),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.baseline,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    Text(
                                      isShowingUsed ? '$used' : '$remaining',
                                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: AppColors.primary),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      isShowingUsed ? '/ $total days used' : '/ $total days remaining',
                                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: glass.textSecondary),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: progress,
                                    backgroundColor: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                                    color: AppColors.primary,
                                    minHeight: 6,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Used: $used days', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: glass.textSecondary)),
                                    Text('Entitled: $total days', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: glass.textSecondary)),
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
                padding: const EdgeInsets.all(12),
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
                            Text('Leave History & Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: glass.textPrimary)),
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
                    const SizedBox(height: 10),
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
                    const SizedBox(height: 10),
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
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? AppColors.darkBordersAndDividers : const Color(0xFFE5E7EB))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? AppColors.darkBordersAndDividers : const Color(0xFFE5E7EB))),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 10),
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
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1A2632) : Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: isDark ? AppColors.darkBordersAndDividers : const Color(0xFFE5E7EB)),
                                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.015), blurRadius: 4, offset: const Offset(0, 1))],
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
                                              padding: const EdgeInsets.all(6),
                                              decoration: BoxDecoration(
                                                color: AppColors.primary.withOpacity(0.12),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: const Icon(Icons.event_note_rounded, color: AppColors.primary, size: 15),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              type,
                                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: glass.textPrimary),
                                            ),
                                          ],
                                        ),
                                        StatusChip(status: status),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Icon(Icons.date_range_rounded, size: 13, color: glass.textSecondary),
                                        const SizedBox(width: 5),
                                        Text(
                                          '$startDate → $endDate',
                                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: glass.textPrimary),
                                        ),
                                        const Spacer(),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                                      const SizedBox(height: 4),
                                      Text(
                                        'Reason: $reason',
                                        style: TextStyle(fontSize: 11, color: glass.textSecondary),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                    const SizedBox(height: 6),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Reviewer: $reviewer',
                                          style: TextStyle(fontSize: 10.5, color: glass.textSecondary),
                                        ),
                                        Row(
                                          children: [
                                            OutlinedButton.icon(
                                              onPressed: () => _viewLeaveDetails(id, h),
                                              icon: const Icon(Icons.remove_red_eye_outlined, size: 13),
                                              label: const Text('View', style: TextStyle(fontSize: 10.5)),
                                              style: OutlinedButton.styleFrom(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                minimumSize: const Size(0, 22),
                                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                              ),
                                            ),
                                            if (canCancel) ...[
                                              const SizedBox(width: 6),
                                              TextButton.icon(
                                                onPressed: () => _confirmCancelLeave(id),
                                                icon: const Icon(Icons.close_rounded, size: 12, color: Colors.redAccent),
                                                label: const Text('Cancel', style: TextStyle(fontSize: 10.5, color: Colors.redAccent, fontWeight: FontWeight.bold)),
                                                style: TextButton.styleFrom(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  minimumSize: const Size(0, 22),
                                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                ),
                                              ),
                                            ],
                                          ],
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

    final stack = Stack(
      children: [
        content,
        if (_showLeaveDetailModal) _buildLeaveDetailModal(isDark, glass),
      ],
    );

    if (!widget.showAppBar) return stack;

    return GlassScaffold(
      title: 'My Leave',
      body: stack,
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color, Color bg, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A2632) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? AppColors.darkBordersAndDividers : const Color(0xFFE5E7EB)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.015), blurRadius: 4, offset: const Offset(0, 1))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(height: 1),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
          const SizedBox(height: 1),
          Text(
            label,
            style: TextStyle(fontSize: 8.5, color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText, fontWeight: FontWeight.w600),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Future<void> _viewLeaveDetails(String id, Map<String, dynamic> fallbackItem) async {
    setState(() {
      _isLoadingDetails = true;
      _selectedLeaveDetail = fallbackItem;
      _showLeaveDetailModal = true;
    });

    final apiClient = ref.read(apiClientProvider);
    try {
      final res = await apiClient.get('/leave/$id').catchError((_) => null);
      if (res != null && mounted) {
        setState(() {
          if (res is Map<String, dynamic>) {
            _selectedLeaveDetail = res;
          } else if (res is Map && res['data'] is Map) {
            _selectedLeaveDetail = Map<String, dynamic>.from(res['data']);
          }
        });
      }
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingDetails = false;
        });
      }
    }
  }

  Widget _buildLeaveDetailModal(bool isDark, GlassTheme glass) {
    if (!_showLeaveDetailModal || _selectedLeaveDetail == null) return const SizedBox.shrink();

    final h = _selectedLeaveDetail!;
    final rawType = h['leaveType']?.toString() ?? h['type']?.toString() ?? 'Leave';
    final type = _normalizeBalanceType(rawType);
    final startDate = _formatReadableDate(h['startDate']?.toString());
    final endDate = _formatReadableDate(h['endDate']?.toString());
    final status = h['status']?.toString() ?? 'PENDING';
    final reason = h['reason']?.toString() ?? h['description']?.toString() ?? '--';
    final days = h['totalDays'] ?? h['days'] ?? 1;
    final reviewer = h['approvedBy']?.toString() ?? h['reviewedBy']?.toString() ?? h['reviewerName']?.toString() ?? '--';
    final email = h['companyEmail']?.toString() ?? h['email']?.toString() ?? ref.read(authServiceProvider).user?.email ?? 'emp@hrm.com';

    return Container(
      color: Colors.black.withOpacity(0.45),
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.92,
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: isDark ? AppColors.darkBordersAndDividers : const Color(0xFFE5E7EB)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 20, offset: const Offset(0, 8))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.event_note_rounded, color: AppColors.primary, size: 20),
                      const SizedBox(width: 8),
                      Text('Leave Request Details', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 17, color: glass.textPrimary)),
                    ],
                  ),
                  SizedBox(
                    width: 36,
                    height: 36,
                    child: Material(
                      color: isDark ? Colors.white12 : const Color(0xFFF1F5F9),
                      shape: const CircleBorder(),
                      child: InkWell(
                        onTap: () => setState(() => _showLeaveDetailModal = false),
                        customBorder: const CircleBorder(),
                        child: Center(
                          child: Icon(Icons.close_rounded, size: 18, color: glass.textSecondary),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Divider(height: 1, color: isDark ? AppColors.darkBordersAndDividers : const Color(0xFFE5E7EB)),
              const SizedBox(height: 12),

              // Scrollable body
              Flexible(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top Row: Leave Type + Status
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'LEAVE TYPE',
                                  style: TextStyle(fontSize: 11, color: Colors.grey[500], letterSpacing: 0.4, fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  type,
                                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: glass.textPrimary),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'STATUS',
                                style: TextStyle(fontSize: 11, color: Colors.grey[500], letterSpacing: 0.4, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 4),
                              _buildPolishedStatusChip(status),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Detail Rows: Company Email ID
                      _detailRow(
                        isDark: isDark,
                        glass: glass,
                        icon: Icons.email_outlined,
                        label: 'Company Email ID',
                        value: email,
                        isEmail: true,
                      ),
                      const SizedBox(height: 14),

                      // Detail Rows: Total Duration
                      _detailRow(
                        isDark: isDark,
                        glass: glass,
                        icon: Icons.date_range_rounded,
                        label: 'Total Duration',
                        customValueWidget: Row(
                          children: [
                            Flexible(
                              child: Text(
                                '$startDate – $endDate',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: glass.textPrimary),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '($days Day${days > 1 ? 's' : ''})',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Detail Rows: Reviewed By
                      _detailRow(
                        isDark: isDark,
                        glass: glass,
                        icon: Icons.admin_panel_settings_rounded,
                        label: 'Reviewed By',
                        value: reviewer == '--' ? '--' : reviewer,
                        isValueMuted: reviewer == '--',
                      ),
                      const SizedBox(height: 14),

                      // Detail Rows: Reason Provided
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.message_outlined, size: 16, color: AppColors.primary),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Reason Provided',
                                style: TextStyle(fontSize: 11, color: Colors.grey[500], fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              reason.isNotEmpty ? reason : 'No reason provided',
                              style: TextStyle(fontSize: 14, height: 1.5, color: glass.textPrimary),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Close Button
              SizedBox(
                height: 44,
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => setState(() => _showLeaveDetailModal = false),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE6F2F0),
                    foregroundColor: AppColors.primary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Close', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primary)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow({
    required bool isDark,
    required GlassTheme glass,
    required IconData icon,
    required String label,
    String? value,
    Widget? customValueWidget,
    bool isEmail = false,
    bool isValueMuted = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 16, color: AppColors.primary),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 11, color: Colors.grey[500], fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              customValueWidget ??
                  Text(
                    value ?? '',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isValueMuted ? FontWeight.normal : FontWeight.w500,
                      color: isValueMuted ? (isDark ? Colors.grey[400] : Colors.grey[600]) : glass.textPrimary,
                    ),
                    maxLines: 2,
                    overflow: isEmail ? TextOverflow.ellipsis : TextOverflow.clip,
                  ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPolishedStatusChip(String status) {
    final upper = status.toUpperCase();
    Color bg;
    Color fg;
    Color dotColor;
    if (upper == 'APPROVED') {
      bg = const Color(0xFFECFDF5);
      fg = const Color(0xFF047857);
      dotColor = const Color(0xFF10B981);
    } else if (upper == 'REJECTED') {
      bg = const Color(0xFFFEE2E2);
      fg = const Color(0xFFB91C1C);
      dotColor = const Color(0xFFEF4444);
    } else if (upper == 'CANCELLED') {
      bg = const Color(0xFFF1F5F9);
      fg = const Color(0xFF475569);
      dotColor = const Color(0xFF94A3B8);
    } else {
      bg = const Color(0xFFFFFBEB);
      fg = const Color(0xFFB45309);
      dotColor = const Color(0xFFF59E0B);
    }

    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            upper,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg, letterSpacing: 0.3),
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
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _selectedStatusFilter = status),
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : (isDark ? const Color(0xFF1A2632) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? AppColors.primary : (isDark ? AppColors.darkBordersAndDividers : const Color(0xFFE5E7EB))),
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
      height: 40,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131E29) : const Color(0xFFEEF2F8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? AppColors.darkBordersAndDividers : const Color(0xFFE5E7EB)),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _activeLeaveTab = 0),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: _activeLeaveTab == 0 ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.pie_chart_rounded,
                      size: 15,
                      color: _activeLeaveTab == 0 ? Colors.white : (isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Leave Balances',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
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
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _activeLeaveTab = 1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: _activeLeaveTab == 1 ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.history_rounded,
                      size: 15,
                      color: _activeLeaveTab == 1 ? Colors.white : (isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Leave History',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
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
        behavior: HitTestBehavior.opaque,
        onTap: () {
          setState(() {
            _selectedBalanceSegment = value;
          });
        },
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? (isDark ? AppColors.primary : Colors.white) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected && !isDark
                ? [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4, offset: const Offset(0, 1))]
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
