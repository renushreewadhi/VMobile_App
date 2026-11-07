import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/glass_theme.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/glass_search_bar.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/compact_summary_widgets.dart';
import '../../shared/widgets/loading_shimmer.dart';
import '../../shared/widgets/status_chip.dart';
import 'it_create_employee_account_screen.dart';

class ItEmployeeAccountsScreen extends ConsumerStatefulWidget {
  final bool showAppBar;
  const ItEmployeeAccountsScreen({super.key, this.showAppBar = false});

  @override
  ConsumerState<ItEmployeeAccountsScreen> createState() => _ItEmployeeAccountsScreenState();
}

class _ItEmployeeAccountsScreenState extends ConsumerState<ItEmployeeAccountsScreen> {
  bool _isLoading = true;
  List<dynamic> _accounts = [];
  String _searchTerm = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchAccounts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchAccounts() async {
    setState(() => _isLoading = true);
    final apiClient = ref.read(apiClientProvider);
    try {
      final res = await apiClient.get('/it/employee-accounts');
      if (kDebugMode) {
        debugPrint('[ItEmployeeAccounts] Response: $res');
      }
      if (mounted) {
        setState(() {
          if (res is List) {
            _accounts = res;
          } else if (res is Map<String, dynamic>) {
            if (res['data'] is List) {
              _accounts = res['data'];
            } else if (res['result'] is List) {
              _accounts = res['result'];
            } else {
              _accounts = [];
            }
          } else {
            _accounts = [];
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ItEmployeeAccounts] Error fetching accounts: $e');
      }
      if (mounted) {
        setState(() {
          _accounts = [];
          _isLoading = false;
        });
      }
    }
  }

  void _showViewModal(dynamic acc) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final glass = context.glass;

    final name = acc['employeeName'] ?? 'Employee';
    final email = acc['email'] ?? 'N/A';
    final code = acc['employeeCode'] ?? 'EMP';
    final dept = acc['department'] ?? 'General';
    final emailAcc = acc['emailAccount'] ?? 'PENDING';
    final hrmsAcc = acc['hrmsAccount'] ?? 'PENDING';
    final vpnAcc = acc['vpnAccess'] ?? 'PENDING';
    final softwareAcc = acc['softwareAccess'] ?? 'PENDING';
    final status = acc['status'] ?? 'ACTIVE';
    final notes = acc['notes'] ?? 'No provisioning remarks.';

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
                      Text('IT Account Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: glass.textPrimary)),
                      IconButton(
                        icon: Icon(Icons.close, color: glass.textSecondary),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

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
                              Text(name.toString(), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: glass.textPrimary)),
                              const SizedBox(height: 2),
                              Text('Code: $code • Dept: $dept', style: TextStyle(fontSize: 12, color: glass.textSecondary)),
                              Text('Email: $email', style: TextStyle(fontSize: 12, color: glass.textSecondary)),
                            ],
                          ),
                        ),
                        StatusChip(status: status.toString().toUpperCase()),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  Text('Access Provisioning Status', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: glass.textSecondary)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: _buildStatusTile('Email', emailAcc)),
                      const SizedBox(width: 8),
                      Expanded(child: _buildStatusTile('HRMS', hrmsAcc)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: _buildStatusTile('VPN', vpnAcc)),
                      const SizedBox(width: 8),
                      Expanded(child: _buildStatusTile('Software', softwareAcc)),
                    ],
                  ),
                  const SizedBox(height: 16),

                  Text('Provisioning Notes', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: glass.textSecondary)),
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
                      notes.toString(),
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
                        ),
                        child: Text('Close', style: TextStyle(color: glass.textPrimary)),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => ItCreateEmployeeAccountScreen(accountId: acc['id'])),
                          ).then((_) => _fetchAccounts());
                        },
                        icon: const Icon(Icons.edit, size: 16),
                        label: const Text('Edit Account'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
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

  Widget _buildStatusTile(String label, String state) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkSecondarySurface : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
          const SizedBox(height: 4),
          StatusChip(status: state.toString().toUpperCase(), showDot: true),
        ],
      ),
    );
  }

  void _confirmDelete(String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: const Text('Are you sure you want to delete this employee IT account? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              final apiClient = ref.read(apiClientProvider);
              try {
                await apiClient.delete('/it/employee-accounts/$id');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Employee IT account deleted.')));
                  _fetchAccounts();
                }
              } catch (_) {
                if (mounted) {
                  setState(() => _accounts.removeWhere((a) => a['id'] == id));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Employee IT account deleted.')));
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
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
          title: 'Employee IT Accounts',
          showBottomBar: false,
          body: skeleton,
        );
      }
      return skeleton;
    }

    final glass = context.glass;

    final total = _accounts.length;
    final active = _accounts.where((a) => (a['status'] ?? '').toString().toUpperCase() == 'ACTIVE').length;
    final pending = _accounts.where((a) => (a['status'] ?? '').toString().toUpperCase() == 'PENDING').length;
    final disabled = _accounts.where((a) => (a['status'] ?? '').toString().toUpperCase() == 'DISABLED').length;

    final filtered = _accounts.where((a) {
      final name = (a['employeeName'] ?? '').toString().toLowerCase();
      final email = (a['email'] ?? '').toString().toLowerCase();
      final code = (a['employeeCode'] ?? '').toString().toLowerCase();
      return name.contains(_searchTerm.toLowerCase()) || email.contains(_searchTerm.toLowerCase()) || code.contains(_searchTerm.toLowerCase());
    }).toList();

    final Widget mainContent = RefreshIndicator(
      onRefresh: _fetchAccounts,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Employee IT Accounts', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: glass.textPrimary)),
                      const SizedBox(height: 2),
                      Text('Manage employee email, HRMS, VPN, and software access.', style: TextStyle(fontSize: 12, color: glass.textSecondary)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const ItCreateEmployeeAccountScreen()))
                        .then((_) => _fetchAccounts());
                  },
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Create Account'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // 1. PASTEL SUMMARY PILLS
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  PastelSummaryPill(
                    label: '$total Total Accounts',
                    variant: PastelPillVariant.blue,
                  ),
                  const SizedBox(width: 8),
                  PastelSummaryPill(
                    label: '$active Active Accounts',
                    variant: PastelPillVariant.green,
                  ),
                  const SizedBox(width: 8),
                  PastelSummaryPill(
                    label: '$pending Pending Provisioning',
                    variant: PastelPillVariant.amber,
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
                  value: '$total',
                  ringColor: AppColors.primary,
                ),
                CircularStatItemData(
                  label: 'Active',
                  value: '$active',
                  ringColor: AppColors.success,
                ),
                CircularStatItemData(
                  label: 'Pending',
                  value: '$pending',
                  ringColor: const Color(0xFFD97706),
                ),
                CircularStatItemData(
                  label: 'Disabled',
                  value: '$disabled',
                  ringColor: AppColors.error,
                ),
              ],
            ),
            const SizedBox(height: 16),

            GlassSearchBar(
              controller: _searchController,
              placeholder: 'Search employee, email, or code...',
              onChanged: (val) => setState(() => _searchTerm = val),
              onClear: () => setState(() => _searchTerm = ''),
            ),
            const SizedBox(height: 16),
            if (filtered.isEmpty)
              AppCard(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(child: Text('No employee accounts found.', style: TextStyle(color: glass.textSecondary))),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final acc = filtered[index];
                  final name = acc['employeeName'] ?? 'Employee';
                  final email = acc['email'] ?? 'employee@company.com';
                  final code = acc['employeeCode'] ?? 'EMP';
                  final dept = acc['department'] ?? 'General';
                  final status = acc['status'] ?? 'ACTIVE';

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(name.toString(), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: glass.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                              ),
                              const SizedBox(width: 8),
                              StatusChip(status: status.toString().toUpperCase()),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text('Code: $code  •  Dept: $dept', style: TextStyle(fontSize: 12, color: glass.textSecondary)),
                          Text('Email: $email', style: TextStyle(fontSize: 12, color: glass.textSecondary)),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              OutlinedButton.icon(
                                onPressed: () => _showViewModal(acc),
                                icon: const Icon(Icons.visibility, size: 14),
                                label: const Text('View'),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => ItCreateEmployeeAccountScreen(accountId: acc['id'])),
                                  ).then((_) => _fetchAccounts());
                                },
                                icon: const Icon(Icons.edit, size: 14),
                                label: const Text('Edit'),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton.icon(
                                onPressed: () => _confirmDelete(acc['id']),
                                icon: const Icon(Icons.delete, color: Colors.red, size: 14),
                                label: const Text('Delete', style: TextStyle(color: Colors.red)),
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
        title: 'Employee IT Accounts',
        showBottomBar: false,
        body: mainContent,
      );
    }

    return mainContent;
  }
}
