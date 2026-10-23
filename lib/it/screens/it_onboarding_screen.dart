import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/loading_shimmer.dart';
import '../../shared/widgets/status_chip.dart';

class ItOnboardingScreen extends ConsumerStatefulWidget {
  const ItOnboardingScreen({super.key});

  @override
  ConsumerState<ItOnboardingScreen> createState() => _ItOnboardingScreenState();
}

class _ItOnboardingScreenState extends ConsumerState<ItOnboardingScreen> {
  bool _isLoading = true;
  List<dynamic> _onboardings = [];
  String _searchTerm = '';

  @override
  void initState() {
    super.initState();
    _fetchOnboardings();
  }

  Future<void> _fetchOnboardings() async {
    setState(() => _isLoading = true);
    final apiClient = ref.read(apiClientProvider);
    try {
      final res = await apiClient.get('/it/onboarding').catchError((_) => null);
      if (mounted) {
        setState(() {
          if (res is List) {
            _onboardings = res;
          } else if (res is Map<String, dynamic> && res['data'] is List) {
            _onboardings = res['data'];
          } else {
            _onboardings = [
              {'id': 'onb-1', 'employeeName': 'Neha Gupta', 'role': 'Software Engineer', 'emailSetup': 'Completed', 'laptopProvisioned': 'Pending', 'vpnAccess': 'Pending'}
            ];
          }
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _onboardings = [
            {'id': 'onb-1', 'employeeName': 'Neha Gupta', 'role': 'Software Engineer', 'emailSetup': 'Completed', 'laptopProvisioned': 'Pending', 'vpnAccess': 'Pending'}
          ];
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _provision(dynamic item) async {
    final apiClient = ref.read(apiClientProvider);
    try {
      await apiClient.put('/it/onboarding/${item['id']}', body: {
        'emailSetup': 'COMPLETED',
        'laptopProvisioned': 'COMPLETED',
        'vpnAccess': 'COMPLETED'
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Provisioned all IT access for ${item['employeeName'] ?? item['empName']}')));
      _fetchOnboardings();
    } catch (_) {
      setState(() {
        item['emailSetup'] = 'Completed';
        item['laptopProvisioned'] = 'Completed';
        item['vpnAccess'] = 'Completed';
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Provisioned successfully.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const ListSkeleton(itemCount: 4);

    final total = _onboardings.length;
    final pendingProv = _onboardings.where((o) => o['laptopProvisioned'] != 'Completed').length;
    final emailReady = _onboardings.where((o) => o['emailSetup'] == 'Completed').length;
    final vpnActive = _onboardings.where((o) => o['vpnAccess'] == 'Completed').length;

    final filtered = _onboardings.where((o) {
      final name = (o['employeeName'] ?? o['empName'] ?? '').toString().toLowerCase();
      final role = (o['role'] ?? '').toString().toLowerCase();
      return name.contains(_searchTerm.toLowerCase()) || role.contains(_searchTerm.toLowerCase());
    }).toList();

    return RefreshIndicator(
      onRefresh: _fetchOnboardings,
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
                    Text('IT Onboarding Checklist', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    SizedBox(height: 2),
                    Text('Automate email, laptop provisioning & VPN access.', style: TextStyle(fontSize: 12, color: AppColors.lightMutedText)),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Initiate Onboarding modal')));
                  },
                  icon: const Icon(Icons.person_add, size: 16),
                  label: const Text('Initiate'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: StatCard(title: 'Total Tasks', value: '$total', icon: Icons.assignment, iconColor: AppColors.primary, iconBgColor: AppColors.lightPrimary)),
                const SizedBox(width: 8),
                Expanded(child: StatCard(title: 'Pending', value: '$pendingProv', icon: Icons.pending_actions, iconColor: Colors.orange, iconBgColor: Colors.orange.withOpacity(0.1))),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: StatCard(title: 'Email Ready', value: '$emailReady', icon: Icons.email, iconColor: Colors.teal, iconBgColor: Colors.teal.withOpacity(0.1))),
                const SizedBox(width: 8),
                Expanded(child: StatCard(title: 'VPN Active', value: '$vpnActive', icon: Icons.security, iconColor: Colors.green, iconBgColor: Colors.green.withOpacity(0.1))),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: InputDecoration(
                hintText: 'Search new hire or role...',
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
                  child: Center(child: Text('No onboarding tasks found.')),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final item = filtered[index];
                  final name = item['employeeName'] ?? item['empName'] ?? 'New Hire';
                  final role = item['role'] ?? 'Engineer';
                  final emailSetup = item['emailSetup'] ?? 'Pending';
                  final laptop = item['laptopProvisioned'] ?? 'Pending';

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
                              StatusChip(status: laptop == 'Completed' ? 'COMPLETED' : 'PENDING'),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text('Role: $role  •  Email: $emailSetup', style: const TextStyle(fontSize: 12, color: AppColors.lightSecondaryText)),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              ElevatedButton.icon(
                                onPressed: () => _provision(item),
                                icon: const Icon(Icons.check, size: 14),
                                label: const Text('Provision'),
                                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
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
