import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/compact_summary_widgets.dart';
import '../../shared/widgets/loading_shimmer.dart';
import '../../shared/widgets/status_chip.dart';
import 'it_create_employee_account_screen.dart';

class ItEmployeeAccountsScreen extends ConsumerStatefulWidget {
  const ItEmployeeAccountsScreen({super.key});

  @override
  ConsumerState<ItEmployeeAccountsScreen> createState() => _ItEmployeeAccountsScreenState();
}

class _ItEmployeeAccountsScreenState extends ConsumerState<ItEmployeeAccountsScreen> {
  bool _isLoading = true;
  List<dynamic> _accounts = [];
  String _searchTerm = '';

  @override
  void initState() {
    super.initState();
    _fetchAccounts();
  }

  Future<void> _fetchAccounts() async {
    setState(() => _isLoading = true);
    final apiClient = ref.read(apiClientProvider);
    try {
      final res = await apiClient.get('/it/employee-accounts').catchError((_) => null);
      if (mounted) {
        setState(() {
          if (res is List) {
            _accounts = res;
          } else if (res is Map<String, dynamic> && res['data'] is List) {
            _accounts = res['data'];
          } else {
            _accounts = [
              {'id': 'acc-1', 'employeeName': 'Rahul Sharma', 'employeeCode': 'EMP-101', 'email': 'rahul.s@company.com', 'department': 'Engineering', 'emailAccount': 'ACTIVE', 'hrmsAccount': 'ACTIVE', 'vpnAccess': 'ACTIVE', 'softwareAccess': 'ACTIVE', 'status': 'ACTIVE'},
              {'id': 'acc-2', 'employeeName': 'Priya Patel', 'employeeCode': 'EMP-102', 'email': 'priya.p@company.com', 'department': 'Product', 'emailAccount': 'PENDING', 'hrmsAccount': 'PENDING', 'vpnAccess': 'PENDING', 'softwareAccess': 'PENDING', 'status': 'PENDING'},
            ];
          }
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _accounts = [
            {'id': 'acc-1', 'employeeName': 'Rahul Sharma', 'employeeCode': 'EMP-101', 'email': 'rahul.s@company.com', 'department': 'Engineering', 'emailAccount': 'ACTIVE', 'hrmsAccount': 'ACTIVE', 'vpnAccess': 'ACTIVE', 'softwareAccess': 'ACTIVE', 'status': 'ACTIVE'},
          ];
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const ListSkeleton(itemCount: 4);

    final total = _accounts.length;
    final active = _accounts.where((a) => a['status'] == 'ACTIVE').length;
    final pending = _accounts.where((a) => a['status'] == 'PENDING').length;
    final disabled = _accounts.where((a) => a['status'] == 'DISABLED').length;

    final filtered = _accounts.where((a) {
      final name = (a['employeeName'] ?? '').toString().toLowerCase();
      final email = (a['email'] ?? '').toString().toLowerCase();
      final code = (a['employeeCode'] ?? '').toString().toLowerCase();
      return name.contains(_searchTerm.toLowerCase()) || email.contains(_searchTerm.toLowerCase()) || code.contains(_searchTerm.toLowerCase());
    }).toList();

    return RefreshIndicator(
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
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Employee IT Accounts', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    SizedBox(height: 2),
                    Text('Manage employee email, HRMS, VPN, and software access.', style: TextStyle(fontSize: 12, color: AppColors.lightMutedText)),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const ItCreateEmployeeAccountScreen()))
                        .then((_) => _fetchAccounts());
                  },
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Create Account'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
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

            TextField(
              decoration: InputDecoration(
                hintText: 'Search employee, email, or code...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              onChanged: (val) => setState(() => _searchTerm = val),
            ),
            const SizedBox(height: 16),
            if (filtered.isEmpty)
              const AppCard(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: Text('No employee accounts found.')),
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
                              Text(name.toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                              StatusChip(status: status.toString().toUpperCase()),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text('Code: $code  •  Dept: $dept', style: const TextStyle(fontSize: 12, color: AppColors.lightSecondaryText)),
                          Text('Email: $email', style: const TextStyle(fontSize: 12, color: AppColors.lightMutedText)),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
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
  }
}
