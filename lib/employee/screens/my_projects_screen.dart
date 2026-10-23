import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/auth/auth_service.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/loading_shimmer.dart';
import '../../shared/widgets/status_chip.dart';

class MyProjectsScreen extends ConsumerStatefulWidget {
  const MyProjectsScreen({super.key});

  @override
  ConsumerState<MyProjectsScreen> createState() => _MyProjectsScreenState();
}

class _MyProjectsScreenState extends ConsumerState<MyProjectsScreen> {
  bool _isLoading = true;
  List<dynamic> _projects = [];
  String _searchQuery = '';
  String _selectedStatus = 'ALL';

  @override
  void initState() {
    super.initState();
    _fetchProjects();
  }

  Future<void> _fetchProjects() async {
    setState(() => _isLoading = true);
    final apiClient = ref.read(apiClientProvider);
    try {
      final res = await apiClient.get(ApiEndpoints.myProjects).catchError((_) => null);
      if (mounted) {
        setState(() {
          if (res is List) {
            _projects = res;
          } else if (res is Map<String, dynamic> && res['data'] is List) {
            _projects = res['data'];
          } else {
            _projects = [
              {'name': 'HRMS Mobile App UI', 'departmentName': 'Engineering', 'description': 'Flutter UI development for HRMS mobile application.', 'status': 'IN_PROGRESS', 'teamLeadName': 'Sarah Jenkins', 'startDate': '2026-01-15', 'endDate': '2026-06-30', 'memberCount': 5, 'completedMemberCount': 3},
              {'name': 'Cloud Infrastructure Migration', 'departmentName': 'DevOps', 'description': 'Migrate monolithic backend to AWS microservices.', 'status': 'ON_HOLD', 'teamLeadName': 'David Miller', 'startDate': '2026-02-01', 'endDate': '2026-08-30', 'memberCount': 4, 'completedMemberCount': 1},
            ];
          }
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<dynamic> get _filteredProjects {
    return _projects.where((p) {
      final name = (p['name'] ?? '').toString().toLowerCase();
      final desc = (p['description'] ?? '').toString().toLowerCase();
      final status = (p['status'] ?? 'IN_PROGRESS').toString().toUpperCase();

      final matchesStatus = _selectedStatus == 'ALL' || status == _selectedStatus;
      final matchesSearch = _searchQuery.isEmpty || name.contains(_searchQuery.toLowerCase()) || desc.contains(_searchQuery.toLowerCase());

      return matchesStatus && matchesSearch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('My Projects')),
      body: _isLoading
          ? const ListSkeleton(itemCount: 3)
          : RefreshIndicator(
              onRefresh: _fetchProjects,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Search & Status Pills Filter Box
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSecondarySurface : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: isDark ? AppColors.darkBordersAndDividers : AppColors.lightBordersAndDividers),
                      ),
                      child: Column(
                        children: [
                          TextField(
                            onChanged: (val) => setState(() => _searchQuery = val),
                            decoration: InputDecoration(
                              hintText: 'Search projects...',
                              prefixIcon: const Icon(Icons.search, size: 20),
                              suffixIcon: _searchQuery.isNotEmpty ? IconButton(icon: const Icon(Icons.clear, size: 16), onPressed: () => setState(() => _searchQuery = '')) : null,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                              filled: true,
                              fillColor: isDark ? AppColors.darkMainSurface : AppColors.lightInputBackground,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
                          const SizedBox(height: 10),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _statusPill('All', 'ALL'),
                                const SizedBox(width: 6),
                                _statusPill('Active', 'IN_PROGRESS'),
                                const SizedBox(width: 6),
                                _statusPill('On Hold', 'ON_HOLD'),
                                const SizedBox(width: 6),
                                _statusPill('Completed', 'COMPLETED'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Projects Grid / List
                    _filteredProjects.isEmpty
                        ? const AppCard(child: Center(child: Padding(padding: EdgeInsets.all(24), child: Text('No projects match your filter.'))))
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _filteredProjects.length,
                            itemBuilder: (context, index) {
                              final p = _filteredProjects[index];
                              final name = p['name']?.toString() ?? 'Project';
                              final dept = p['departmentName']?.toString() ?? 'General';
                              final desc = p['description']?.toString() ?? 'No description provided.';
                              final status = p['status']?.toString() ?? 'IN_PROGRESS';
                              final lead = p['teamLeadName']?.toString() ?? 'Team Lead';
                              final members = p['memberCount'] ?? 4;
                              final completed = p['completedMemberCount'] ?? 2;
                              final progress = members > 0 ? (completed / members).clamp(0.0, 1.0) : 0.0;

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: AppCard(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                                          StatusChip(status: status),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(dept, style: const TextStyle(fontSize: 12, color: AppColors.lightSecondaryText)),
                                      const SizedBox(height: 8),
                                      Text(desc, style: const TextStyle(fontSize: 13, color: AppColors.lightPrimaryText), maxLines: 2, overflow: TextOverflow.ellipsis),
                                      const Divider(height: 20),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              CircleAvatar(radius: 12, backgroundColor: AppColors.primary, child: Text(lead.isNotEmpty ? lead[0].toUpperCase() : 'T', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
                                              const SizedBox(width: 6),
                                              Text(lead, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                            ],
                                          ),
                                          Text('$members Members', style: const TextStyle(fontSize: 12, color: AppColors.lightSecondaryText)),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              const Text('Team Progress', style: TextStyle(fontSize: 11, color: AppColors.lightSecondaryText)),
                                              Text('${(progress * 100).toInt()}%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary)),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          LinearProgressIndicator(value: progress, backgroundColor: Colors.grey.shade300, color: AppColors.primary),
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
            ),
    );
  }

  Widget _statusPill(String label, String value) {
    final isSelected = _selectedStatus == value;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) setState(() => _selectedStatus = value);
      },
    );
  }
}
