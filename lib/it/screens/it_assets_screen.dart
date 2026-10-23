import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/compact_summary_widgets.dart';
import '../../shared/widgets/loading_shimmer.dart';
import '../../shared/widgets/status_chip.dart';

class ItAssetsScreen extends ConsumerStatefulWidget {
  const ItAssetsScreen({super.key});

  @override
  ConsumerState<ItAssetsScreen> createState() => _ItAssetsScreenState();
}

class _ItAssetsScreenState extends ConsumerState<ItAssetsScreen> {
  bool _isLoading = true;
  List<dynamic> _assets = [];
  Map<String, dynamic> _stats = {'total': 0, 'assigned': 0, 'available': 0, 'underRepair': 0};
  String _searchQuery = '';
  String _statusFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    _fetchAssetsData();
  }

  Future<void> _fetchAssetsData() async {
    setState(() => _isLoading = true);
    final apiClient = ref.read(apiClientProvider);
    try {
      final res = await apiClient.get(ApiEndpoints.itAssets).catchError((_) => null);
      final statsRes = await apiClient.get('/assets/stats').catchError((_) => null);

      if (mounted) {
        setState(() {
          if (res is List) {
            _assets = res;
          } else if (res is Map<String, dynamic> && res['data'] is List) {
            _assets = res['data'];
          }

          if (statsRes is Map<String, dynamic>) {
            _stats = statsRes;
          } else {
            _stats = {
              'total': _assets.length,
              'assigned': _assets.where((a) => a['status'] == 'ASSIGNED').length,
              'available': _assets.where((a) => a['status'] == 'AVAILABLE').length,
              'underRepair': _assets.where((a) => a['status'] == 'UNDER_REPAIR').length,
            };
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
    if (_isLoading) return const ListSkeleton(itemCount: 4);

    final totalCount = _stats['total'] ?? _assets.length;
    final assignedCount = _stats['assigned'] ?? 0;
    final availableCount = _stats['available'] ?? 0;
    final repairCount = _stats['underRepair'] ?? 0;

    final filtered = _assets.where((a) {
      final name = (a['name'] ?? a['assetName'] ?? '').toString().toLowerCase();
      final tag = (a['assetCode'] ?? a['assetTag'] ?? '').toString().toLowerCase();
      final status = (a['status'] ?? 'AVAILABLE').toString();

      final matchesSearch = name.contains(_searchQuery.toLowerCase()) || tag.contains(_searchQuery.toLowerCase());
      final matchesStatus = _statusFilter == 'ALL' || status == _statusFilter;
      return matchesSearch && matchesStatus;
    }).toList();

    return RefreshIndicator(
      onRefresh: _fetchAssetsData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('IT Asset Management', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 14),

            // 1. PASTEL SUMMARY PILLS
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  PastelSummaryPill(
                    label: '$totalCount Total Hardware Assets',
                    variant: PastelPillVariant.blue,
                  ),
                  const SizedBox(width: 8),
                  PastelSummaryPill(
                    label: '$assignedCount Assigned',
                    variant: PastelPillVariant.green,
                  ),
                  const SizedBox(width: 8),
                  PastelSummaryPill(
                    label: '$availableCount Available',
                    variant: PastelPillVariant.purple,
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
                  value: '$totalCount',
                  ringColor: AppColors.primary,
                ),
                CircularStatItemData(
                  label: 'Assigned',
                  value: '$assignedCount',
                  ringColor: AppColors.success,
                ),
                CircularStatItemData(
                  label: 'Available',
                  value: '$availableCount',
                  ringColor: const Color(0xFF2563EB),
                ),
                CircularStatItemData(
                  label: 'Repair',
                  value: '$repairCount',
                  ringColor: const Color(0xFFD97706),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Search Bar
            TextField(
              decoration: InputDecoration(
                hintText: 'Search asset tag or device name...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
            const SizedBox(height: 12),

            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['ALL', 'AVAILABLE', 'ASSIGNED', 'UNDER_REPAIR'].map((status) {
                  final isSelected = _statusFilter == status;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(status.replaceAll('_', ' ')),
                      selected: isSelected,
                      selectedColor: AppColors.primary,
                      labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black87),
                      onSelected: (_) => setState(() => _statusFilter = status),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),

            if (filtered.isEmpty)
              const AppCard(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: Text('No asset records in inventory.')),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final asset = filtered[index];
                  final name = asset['name'] ?? asset['assetName'] ?? 'MacBook Pro';
                  final category = asset['category'] ?? 'Laptop';
                  final tag = asset['assetCode'] ?? asset['assetTag'] ?? 'AST-2026';
                  final status = asset['status'] ?? 'AVAILABLE';

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: AppCard(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.lightPrimary,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.laptop, color: AppColors.primary, size: 22),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name.toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                const SizedBox(height: 2),
                                Text('Tag: $tag  •  $category', style: const TextStyle(fontSize: 12, color: AppColors.lightSecondaryText)),
                              ],
                            ),
                          ),
                          StatusChip(status: status.toString()),
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
