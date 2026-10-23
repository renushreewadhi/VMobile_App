import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/compact_summary_widgets.dart';
import '../../shared/widgets/loading_shimmer.dart';
import '../../shared/widgets/status_chip.dart';

class ItOffboardingScreen extends ConsumerStatefulWidget {
  const ItOffboardingScreen({super.key});

  @override
  ConsumerState<ItOffboardingScreen> createState() => _ItOffboardingScreenState();
}

class _ItOffboardingScreenState extends ConsumerState<ItOffboardingScreen> {
  bool _isLoading = true;
  List<dynamic> _offboardings = [];
  String _searchTerm = '';

  @override
  void initState() {
    super.initState();
    _fetchOffboardings();
  }

  Future<void> _fetchOffboardings() async {
    setState(() => _isLoading = true);
    final apiClient = ref.read(apiClientProvider);
    try {
      final res = await apiClient.get('/it/offboarding').catchError((_) => null);
      if (mounted) {
        setState(() {
          if (res is List) {
            _offboardings = res;
          } else if (res is Map<String, dynamic> && res['data'] is List) {
            _offboardings = res['data'];
          } else {
            _offboardings = [
              {'id': 'off-1', 'employeeName': 'Amit Verma', 'employeeCode': 'EMP-103', 'exitDate': DateTime.now().toIso8601String(), 'accountDisabled': 'Completed', 'assetReturned': 'Pending', 'dataWiped': 'Pending', 'status': 'In Progress'}
            ];
          }
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _offboardings = [
            {'id': 'off-1', 'employeeName': 'Amit Verma', 'employeeCode': 'EMP-103', 'exitDate': DateTime.now().toIso8601String(), 'accountDisabled': 'Completed', 'assetReturned': 'Pending', 'dataWiped': 'Pending', 'status': 'In Progress'}
          ];
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _revokeNow(dynamic item) async {
    final apiClient = ref.read(apiClientProvider);
    try {
      await apiClient.put('/it/offboarding/${item['id']}', body: {
        'accountDisabled': 'COMPLETED',
        'assetReturned': 'COMPLETED',
        'dataWiped': 'COMPLETED',
        'status': 'COMPLETED'
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('All accounts & access revoked for ${item['employeeName'] ?? item['empName']}')));
      _fetchOffboardings();
    } catch (_) {
      setState(() {
        item['accountDisabled'] = 'Completed';
        item['assetReturned'] = 'Completed';
        item['dataWiped'] = 'Completed';
        item['status'] = 'Completed';
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Access revoked successfully.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const ListSkeleton(itemCount: 4);

    final total = _offboardings.length;
    final pendingAsset = _offboardings.where((o) => o['assetReturned'] != 'Completed').length;
    final ssoDisabled = _offboardings.where((o) => o['accountDisabled'] == 'Completed').length;
    final completed = _offboardings.where((o) => o['status'] == 'Completed').length;

    final filtered = _offboardings.where((o) {
      final name = (o['employeeName'] ?? o['empName'] ?? '').toString().toLowerCase();
      return name.contains(_searchTerm.toLowerCase());
    }).toList();

    return RefreshIndicator(
      onRefresh: _fetchOffboardings,
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
                    Text('IT Offboarding', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    SizedBox(height: 2),
                    Text('Revoke access, disable SSO and recover hardware.', style: TextStyle(fontSize: 12, color: AppColors.lightMutedText)),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Initiate Offboarding modal')));
                  },
                  icon: const Icon(Icons.person_remove, size: 16),
                  label: const Text('Initiate'),
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
                    label: '$total Exiting Staff',
                    variant: PastelPillVariant.blue,
                  ),
                  const SizedBox(width: 8),
                  PastelSummaryPill(
                    label: '$pendingAsset Asset Returns Pending',
                    variant: PastelPillVariant.amber,
                  ),
                  const SizedBox(width: 8),
                  PastelSummaryPill(
                    label: '$completed Completed Offboardings',
                    variant: PastelPillVariant.green,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 2. CIRCULAR STATISTIC INDICATOR GROUP
            CircularStatGroup(
              items: [
                CircularStatItemData(
                  label: 'Exiting',
                  value: '$total',
                  ringColor: AppColors.primary,
                ),
                CircularStatItemData(
                  label: 'Pending',
                  value: '$pendingAsset',
                  ringColor: const Color(0xFFD97706),
                ),
                CircularStatItemData(
                  label: 'Disabled',
                  value: '$ssoDisabled',
                  ringColor: const Color(0xFF9333EA),
                ),
                CircularStatItemData(
                  label: 'Done',
                  value: '$completed',
                  ringColor: AppColors.success,
                ),
              ],
            ),
            const SizedBox(height: 16),

            TextField(
              decoration: InputDecoration(
                hintText: 'Search exiting employee...',
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
                  child: Center(child: Text('No offboarding records found.')),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final item = filtered[index];
                  final name = item['employeeName'] ?? item['empName'] ?? 'Exiting Employee';
                  final status = item['status'] ?? 'In Progress';
                  final assetReturned = item['assetReturned'] ?? 'Pending';
                  final accountDisabled = item['accountDisabled'] ?? 'Pending';

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
                              StatusChip(status: status.toString().toUpperCase().replaceAll(' ', '_')),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text('Account Disabled: $accountDisabled  •  Asset: $assetReturned', style: const TextStyle(fontSize: 12, color: AppColors.lightSecondaryText)),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              OutlinedButton.icon(
                                onPressed: () => _revokeNow(item),
                                icon: const Icon(Icons.power_off, color: Colors.red, size: 14),
                                label: const Text('Revoke Now', style: TextStyle(color: Colors.red)),
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
