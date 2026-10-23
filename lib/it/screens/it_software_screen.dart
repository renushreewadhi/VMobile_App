import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/loading_shimmer.dart';
import '../../shared/widgets/status_chip.dart';

class ItSoftwareScreen extends ConsumerStatefulWidget {
  const ItSoftwareScreen({super.key});

  @override
  ConsumerState<ItSoftwareScreen> createState() => _ItSoftwareScreenState();
}

class _ItSoftwareScreenState extends ConsumerState<ItSoftwareScreen> {
  bool _isLoading = true;
  List<dynamic> _softwareList = [];
  String _searchTerm = '';

  @override
  void initState() {
    super.initState();
    _fetchSoftware();
  }

  Future<void> _fetchSoftware() async {
    setState(() => _isLoading = true);
    final apiClient = ref.read(apiClientProvider);
    try {
      final res = await apiClient.get(ApiEndpoints.itSoftware).catchError((_) => null);
      if (mounted) {
        setState(() {
          if (res is List) {
            _softwareList = res;
          } else if (res is Map<String, dynamic> && res['data'] is List) {
            _softwareList = res['data'];
          } else {
            _softwareList = [
              {'id': 'sw-1', 'name': 'GitHub Enterprise', 'vendor': 'GitHub', 'totalSeats': 50, 'allocatedSeats': 42, 'status': 'Active'},
              {'id': 'sw-2', 'name': 'Jira Software', 'vendor': 'Atlassian', 'totalSeats': 100, 'allocatedSeats': 85, 'status': 'Active'},
            ];
          }
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _softwareList = [
            {'id': 'sw-1', 'name': 'GitHub Enterprise', 'vendor': 'GitHub', 'totalSeats': 50, 'allocatedSeats': 42, 'status': 'Active'}
          ];
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const ListSkeleton(itemCount: 4);

    final totalSubs = _softwareList.length;
    final totalSeats = _softwareList.fold<int>(0, (sum, s) => sum + ((s['totalSeats'] ?? 0) as int));
    final allocatedSeats = _softwareList.fold<int>(0, (sum, s) => sum + ((s['allocatedSeats'] ?? 0) as int));
    final utilization = totalSeats > 0 ? ((allocatedSeats / totalSeats) * 100).toStringAsFixed(1) : '0';

    final filtered = _softwareList.where((s) {
      final name = (s['name'] ?? '').toString().toLowerCase();
      final vendor = (s['vendor'] ?? '').toString().toLowerCase();
      return name.contains(_searchTerm.toLowerCase()) || vendor.contains(_searchTerm.toLowerCase());
    }).toList();

    return RefreshIndicator(
      onRefresh: _fetchSoftware,
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
                    Text('Software & Licenses', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    SizedBox(height: 2),
                    Text('Manage SaaS subscriptions, seat allocations and renewals.', style: TextStyle(fontSize: 12, color: AppColors.lightMutedText)),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add License modal')));
                  },
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add License'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: StatCard(title: 'Subscriptions', value: '$totalSubs', icon: Icons.grid_view, iconColor: AppColors.primary, iconBgColor: AppColors.lightPrimary)),
                const SizedBox(width: 8),
                Expanded(child: StatCard(title: 'Allocated Seats', value: '$allocatedSeats / $totalSeats', icon: Icons.chair, iconColor: Colors.green, iconBgColor: Colors.green.withOpacity(0.1))),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: StatCard(title: 'Utilization Rate', value: '$utilization%', icon: Icons.trending_up, iconColor: Colors.purple, iconBgColor: Colors.purple.withOpacity(0.1))),
                const SizedBox(width: 8),
                Expanded(child: StatCard(title: 'Expiring Soon', value: '0', icon: Icons.warning, iconColor: Colors.orange, iconBgColor: Colors.orange.withOpacity(0.1))),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: InputDecoration(
                hintText: 'Search software or vendor...',
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
                  child: Center(child: Text('No software licenses recorded.')),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final sw = filtered[index];
                  final name = sw['name'] ?? 'Software License';
                  final vendor = sw['vendor'] ?? 'Vendor';
                  final seats = sw['totalSeats'] ?? 10;
                  final used = sw['allocatedSeats'] ?? 5;
                  final status = sw['status'] ?? 'Active';

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
                          Text('Vendor: $vendor  •  Seats: $used / $seats used', style: const TextStyle(fontSize: 12, color: AppColors.lightSecondaryText)),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              OutlinedButton.icon(
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Manage seat allocations for $name')));
                                },
                                icon: const Icon(Icons.person_add, size: 14),
                                label: const Text('Assign'),
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
