import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/glass_search_bar.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/loading_shimmer.dart';
import '../../shared/widgets/status_chip.dart';

class HrEmployeesScreen extends ConsumerStatefulWidget {
  const HrEmployeesScreen({super.key});

  @override
  ConsumerState<HrEmployeesScreen> createState() => _HrEmployeesScreenState();
}

class _HrEmployeesScreenState extends ConsumerState<HrEmployeesScreen> {
  bool _isLoading = true;
  List<dynamic> _employees = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchEmployees();
  }

  Future<void> _fetchEmployees() async {
    setState(() => _isLoading = true);
    final apiClient = ref.read(apiClientProvider);
    try {
      final res = await apiClient.get(ApiEndpoints.employees).catchError((_) => null);
      if (mounted) {
        setState(() {
          if (res is List) {
            _employees = res;
          } else if (res is Map<String, dynamic> && res['data'] is List) {
            _employees = res['data'];
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
    if (_isLoading) {
      return const GlassScaffold(
        title: 'Employee Directory',
        body: ListSkeleton(itemCount: 4),
      );
    }

    final filtered = _employees.where((emp) {
      final name = '${emp['firstName'] ?? ''} ${emp['lastName'] ?? ''}'.toLowerCase();
      final dept = (emp['department'] ?? '').toString().toLowerCase();
      return name.contains(_searchQuery.toLowerCase()) || dept.contains(_searchQuery.toLowerCase());
    }).toList();

    return GlassScaffold(
      title: 'Employee Directory',
      body: RefreshIndicator(
        onRefresh: _fetchEmployees,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GlassSearchBar(
                placeholder: 'Search employee by name or department...',
                onChanged: (val) => setState(() => _searchQuery = val),
              ),
              const SizedBox(height: 16),
              const Text('Company Employee Directory', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 12),
              if (filtered.isEmpty)
                const AppCard(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: Text('No employee records found.')),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final emp = filtered[index];
                    final name = '${emp['firstName'] ?? 'Employee'} ${emp['lastName'] ?? ''}'.trim();
                    final dept = emp['department'] ?? 'General';
                    final designation = emp['designation'] ?? 'Staff';

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: AppCard(
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: AppColors.primary,
                              child: Text(
                                name.isNotEmpty ? name[0].toUpperCase() : 'E',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                  const SizedBox(height: 2),
                                  Text('$designation • $dept', style: const TextStyle(fontSize: 12, color: AppColors.lightSecondaryText)),
                                ],
                              ),
                            ),
                            const StatusChip(status: 'ACTIVE'),
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
    );
  }
}
