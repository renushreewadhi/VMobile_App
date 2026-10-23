import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/compact_summary_widgets.dart';
import '../../shared/widgets/loading_shimmer.dart';
import '../../shared/widgets/status_chip.dart';

class MyTasksScreen extends ConsumerStatefulWidget {
  const MyTasksScreen({super.key});

  @override
  ConsumerState<MyTasksScreen> createState() => _MyTasksScreenState();
}

class _MyTasksScreenState extends ConsumerState<MyTasksScreen> {
  bool _isLoading = true;
  List<dynamic> _tasks = [];
  String _searchQuery = '';
  String _selectedStatus = 'All Status';

  @override
  void initState() {
    super.initState();
    _fetchTasks();
  }

  Future<void> _fetchTasks() async {
    setState(() => _isLoading = true);
    final apiClient = ref.read(apiClientProvider);
    try {
      final res = await apiClient.get(ApiEndpoints.myTasks).catchError((_) => null);
      if (mounted) {
        setState(() {
          if (res is List) {
            _tasks = res;
          } else if (res is Map<String, dynamic> && res['data'] is List) {
            _tasks = res['data'];
          } else {
            _tasks = [
              {'title': 'Create New Module AI Studio', 'department': 'AI & Research', 'description': 'Build integration and prompt modules for Gemini Nano.', 'status': 'Active', 'leadName': 'Vikram Mehta', 'startDate': 'Sep 17, 2026', 'endDate': 'Dec 17, 2026', 'reportsCount': 1, 'membersCount': 1},
              {'title': 'Create New Login Page', 'department': 'Engineering', 'description': 'Responsive login and authentication flow with Credential Manager.', 'status': 'Completed', 'leadName': 'Sarah Jenkins', 'startDate': 'Sep 01, 2026', 'endDate': 'Sep 15, 2026', 'reportsCount': 2, 'membersCount': 2},
            ];
          }
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<dynamic> get _filteredTasks {
    return _tasks.where((t) {
      final title = (t['title'] ?? '').toString().toLowerCase();
      final desc = (t['description'] ?? '').toString().toLowerCase();
      final status = (t['status'] ?? 'Active').toString();

      final matchesStatus = _selectedStatus == 'All Status' || status == _selectedStatus;
      final matchesSearch = _searchQuery.isEmpty || title.contains(_searchQuery.toLowerCase()) || desc.contains(_searchQuery.toLowerCase());

      return matchesStatus && matchesSearch;
    }).toList();
  }

  int get _totalCount => _tasks.length;
  int get _activeCount => _tasks.where((t) => (t['status'] ?? '') == 'Active').length;
  int get _completedCount => _tasks.where((t) => (t['status'] ?? '') == 'Completed').length;
  int get _onHoldCount => _tasks.where((t) => (t['status'] ?? '') == 'On Hold').length;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('My Tasks & Deliverables')),
      body: _isLoading
          ? const ListSkeleton(itemCount: 4)
          : RefreshIndicator(
              onRefresh: _fetchTasks,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. PASTEL SUMMARY PILLS
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: [
                          PastelSummaryPill(
                            label: '$_totalCount Total Assigned',
                            variant: PastelPillVariant.blue,
                            onTap: () => setState(() => _selectedStatus = 'All Status'),
                          ),
                          const SizedBox(width: 8),
                          PastelSummaryPill(
                            label: '$_activeCount Active',
                            variant: PastelPillVariant.purple,
                            onTap: () => setState(() => _selectedStatus = 'Active'),
                          ),
                          const SizedBox(width: 8),
                          PastelSummaryPill(
                            label: '$_completedCount Completed',
                            variant: PastelPillVariant.green,
                            onTap: () => setState(() => _selectedStatus = 'Completed'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // 2. CIRCULAR STATISTIC INDICATOR GROUP
                    CircularStatGroup(
                      items: [
                        CircularStatItemData(
                          label: 'Assigned',
                          value: '$_totalCount',
                          ringColor: AppColors.primary,
                          onTap: () => setState(() => _selectedStatus = 'All Status'),
                        ),
                        CircularStatItemData(
                          label: 'Active',
                          value: '$_activeCount',
                          ringColor: const Color(0xFF2563EB),
                          onTap: () => setState(() => _selectedStatus = 'Active'),
                        ),
                        CircularStatItemData(
                          label: 'Done',
                          value: '$_completedCount',
                          ringColor: AppColors.success,
                          onTap: () => setState(() => _selectedStatus = 'Completed'),
                        ),
                        CircularStatItemData(
                          label: 'On Hold',
                          value: '$_onHoldCount',
                          ringColor: const Color(0xFFD97706),
                          onTap: () => setState(() => _selectedStatus = 'On Hold'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Filter & Search Card
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
                              hintText: 'Search tasks by title, description...',
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
                                _statusPill('All Status'),
                                const SizedBox(width: 6),
                                _statusPill('Active'),
                                const SizedBox(width: 6),
                                _statusPill('Completed'),
                                const SizedBox(width: 6),
                                _statusPill('On Hold'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Tasks Grid / List
                    _filteredTasks.isEmpty
                        ? const AppCard(child: Center(child: Padding(padding: EdgeInsets.all(24), child: Text('No tasks match your filter.'))))
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _filteredTasks.length,
                            itemBuilder: (context, index) {
                              final t = _filteredTasks[index];
                              final title = t['title']?.toString() ?? 'Task title';
                              final dept = t['department']?.toString() ?? 'Engineering';
                              final desc = t['description']?.toString() ?? '';
                              final status = t['status']?.toString() ?? 'Active';
                              final lead = t['leadName']?.toString() ?? 'Team Lead';

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: AppCard(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
                                          StatusChip(status: status.toUpperCase()),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(dept, style: const TextStyle(fontSize: 12, color: AppColors.lightSecondaryText)),
                                      if (desc.isNotEmpty) ...[
                                        const SizedBox(height: 6),
                                        Text(desc, style: const TextStyle(fontSize: 13, color: AppColors.lightPrimaryText), maxLines: 2, overflow: TextOverflow.ellipsis),
                                      ],
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
                                          Text(t['endDate'] ?? 'No Due Date', style: const TextStyle(fontSize: 11.5, color: AppColors.lightSecondaryText)),
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

  Widget _statusPill(String status) {
    final isSelected = _selectedStatus == status;
    return ChoiceChip(
      label: Text(status, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) setState(() => _selectedStatus = status);
      },
    );
  }
}
