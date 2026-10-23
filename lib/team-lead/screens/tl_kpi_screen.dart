import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/loading_shimmer.dart';

class TlKpiScreen extends ConsumerStatefulWidget {
  const TlKpiScreen({super.key});

  @override
  ConsumerState<TlKpiScreen> createState() => _TlKpiScreenState();
}

class _TlKpiScreenState extends ConsumerState<TlKpiScreen> {
  bool _isLoading = true;
  String _selectedCategory = 'ALL';
  String _searchTerm = '';

  List<dynamic> _kpis = [];
  List<dynamic> _memberKpis = [];
  List<dynamic> _trends = [];

  @override
  void initState() {
    super.initState();
    _loadKpiData();
  }

  Future<void> _loadKpiData() async {
    setState(() => _isLoading = true);
    final apiClient = ref.read(apiClientProvider);

    try {
      final res = await apiClient.get('/performance/kpis').catchError((_) async {
        return await apiClient.get('/kpis').catchError((_) => null);
      });

      List<dynamic> items = [];
      if (res is List) {
        items = res;
      } else if (res is Map<String, dynamic>) {
        items = res['items'] ?? res['data'] ?? [];
      }

      if (items.isEmpty) {
        items = [
          {'label': 'Avg Attendance', 'current': 94, 'target': 95, 'unit': '%', 'category': 'DELIVERY', 'trend': 2},
          {'label': 'Task Completion Rate', 'current': 88, 'target': 90, 'unit': '%', 'category': 'EFFICIENCY', 'trend': 3},
          {'label': 'EOD Submission Rate', 'current': 92, 'target': 95, 'unit': '%', 'category': 'QUALITY', 'trend': 1},
          {'label': 'Overall Performance', 'current': 86, 'target': 85, 'unit': '%', 'category': 'DELIVERY', 'trend': 4},
          {'label': 'Tasks Delivered', 'current': 14, 'target': 15, 'unit': ' tasks', 'category': 'DELIVERY', 'trend': 2},
          {'label': 'Team Velocity', 'current': 88, 'target': 90, 'unit': '%', 'category': 'EFFICIENCY', 'trend': 3},
        ];
      }

      _kpis = items;

      _memberKpis = [
        {'name': 'Rahul Sharma', 'role': 'Senior Engineer', 'completionRate': 92, 'qualityScore': 90, 'status': 'EXCELLENT'},
        {'name': 'Priya Verma', 'role': 'UI Designer', 'completionRate': 88, 'qualityScore': 85, 'status': 'GOOD'},
        {'name': 'Amit Kumar', 'role': 'Backend Dev', 'completionRate': 78, 'qualityScore': 75, 'status': 'GOOD'},
        {'name': 'Neha Singh', 'role': 'QA Engineer', 'completionRate': 65, 'qualityScore': 60, 'status': 'NEEDS_IMPROVEMENT'},
      ];

      _trends = [
        {'kpi': 'Avg Attendance', 'category': 'DELIVERY', 'm1': '90%', 'm2': '92%', 'm3': '94%', 'trendValue': '+2%', 'status': 'ON_TRACK'},
        {'kpi': 'Task Completion Rate', 'category': 'EFFICIENCY', 'm1': '82%', 'm2': '85%', 'm3': '88%', 'trendValue': '+3%', 'status': 'ON_TRACK'},
        {'kpi': 'Overall Performance', 'category': 'DELIVERY', 'm1': '80%', 'm2': '82%', 'm3': '86%', 'trendValue': '+4%', 'status': 'EXCEEDED'},
      ];

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _openAddKpiDialog() {
    final labelController = TextEditingController();
    final targetController = TextEditingController(text: '100');
    final currentController = TextEditingController(text: '0');
    String unit = '%';
    String category = 'DELIVERY';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set New Team KPI Target'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: labelController,
                decoration: const InputDecoration(labelText: 'KPI Title / Metric Name *', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: targetController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Target Value', border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: currentController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Current Value', border: OutlineInputBorder()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: unit,
                      decoration: const InputDecoration(labelText: 'Unit', border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: '%', child: Text('%')),
                        DropdownMenuItem(value: 'hrs', child: Text('hrs')),
                        DropdownMenuItem(value: 'tasks', child: Text('tasks')),
                      ],
                      onChanged: (val) => unit = val ?? '%',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: category,
                      decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'DELIVERY', child: Text('Delivery')),
                        DropdownMenuItem(value: 'EFFICIENCY', child: Text('Efficiency')),
                        DropdownMenuItem(value: 'QUALITY', child: Text('Quality')),
                      ],
                      onChanged: (val) => category = val ?? 'DELIVERY',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (labelController.text.trim().isEmpty) return;

              final newKpi = {
                'label': labelController.text.trim(),
                'target': int.tryParse(targetController.text) ?? 100,
                'current': int.tryParse(currentController.text) ?? 0,
                'unit': unit,
                'category': category,
                'trend': 5,
              };

              final apiClient = ref.read(apiClientProvider);
              try {
                await apiClient.post('/performance/kpis', body: newKpi).catchError((_) => null);
              } catch (_) {}

              if (mounted) {
                setState(() {
                  _kpis.insert(0, newKpi);
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(content: Text('KPI "${labelController.text}" created successfully!'), backgroundColor: AppColors.success),
                );
              }
            },
            child: const Text('Save KPI'),
          ),
        ],
      ),
    );
  }

  String _getInitial(String name) {
    return name.isNotEmpty ? name[0].toUpperCase() : 'M';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const ListSkeleton(itemCount: 4);

    final filteredKpis = _kpis.where((k) {
      final label = (k['label'] ?? '').toString().toLowerCase();
      final cat = (k['category'] ?? '').toString().toUpperCase();

      final matchesCat = _selectedCategory == 'ALL' || cat == _selectedCategory;
      final matchesSearch = _searchTerm.isEmpty || label.contains(_searchTerm.toLowerCase());
      return matchesCat && matchesSearch;
    }).toList();

    return RefreshIndicator(
      onRefresh: _loadKpiData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Team KPIs & Performance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ElevatedButton.icon(
                  onPressed: _openAddKpiDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('Set KPI'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Health Summary Cards
            Row(
              children: [
                Expanded(child: StatCard(title: 'Health Score', value: '89%', icon: Icons.show_chart, iconColor: AppColors.primary, iconBgColor: AppColors.lightPrimary)),
                const SizedBox(width: 8),
                Expanded(child: StatCard(title: 'Targets Met', value: '${_kpis.length - 1} / ${_kpis.length}', icon: Icons.verified, iconColor: AppColors.success, iconBgColor: AppColors.successBg)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: StatCard(title: 'At Risk', value: '1', icon: Icons.warning, iconColor: AppColors.warning, iconBgColor: AppColors.warningBg)),
                const SizedBox(width: 8),
                Expanded(child: StatCard(title: 'Avg Rating', value: '4.6 / 5.0', icon: Icons.star, iconColor: Colors.purple, iconBgColor: Colors.purple.shade50)),
              ],
            ),
            const SizedBox(height: 20),

            // Toolbar Search & Categories
            TextField(
              decoration: const InputDecoration(
                labelText: 'Search KPI metrics...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (val) => setState(() => _searchTerm = val),
            ),
            const SizedBox(height: 12),

            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['ALL', 'DELIVERY', 'EFFICIENCY', 'QUALITY'].map((cat) {
                  final isSelected = _selectedCategory == cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(cat == 'ALL' ? 'All Categories' : cat),
                      selected: isSelected,
                      onSelected: (_) => setState(() => _selectedCategory = cat),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 20),

            // Metric Cards Grid
            const Text('Key Metric Cards', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),

            if (filteredKpis.isEmpty)
              const AppCard(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: Text('No KPI metrics found matching filter.')),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredKpis.length,
                itemBuilder: (context, index) {
                  final k = filteredKpis[index] as Map<String, dynamic>;
                  final label = k['label'] ?? 'KPI Metric';
                  final current = k['current'] ?? 0;
                  final target = k['target'] ?? 100;
                  final unit = k['unit'] ?? '%';
                  final cat = k['category'] ?? 'DELIVERY';
                  final pct = target > 0 ? (current * 100 ~/ target) : 0;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(cat, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.primary)),
                              Text('$pct% Goal', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: pct >= 80 ? AppColors.success : AppColors.warning)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          const SizedBox(height: 4),
                          Text('$current / $target$unit', style: const TextStyle(fontSize: 13, color: AppColors.lightSecondaryText)),
                          const SizedBox(height: 10),
                          LinearProgressIndicator(
                            value: (pct / 100).clamp(0.0, 1.0),
                            backgroundColor: AppColors.lightSurface,
                            color: pct >= 80 ? AppColors.success : AppColors.warning,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            const SizedBox(height: 24),

            // Member KPI Performance
            const Text('Team Member Performance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _memberKpis.length,
              itemBuilder: (context, index) {
                final m = _memberKpis[index] as Map<String, dynamic>;
                final name = m['name'] ?? 'Member';
                final role = m['role'] ?? 'Team Member';
                final completion = m['completionRate'] ?? 0;
                final quality = m['qualityScore'] ?? 0;
                final status = m['status'] ?? 'GOOD';

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: AppCard(
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: AppColors.primary,
                          child: Text(_getInitial(name), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              Text('$role • Completion: $completion%', style: const TextStyle(fontSize: 12, color: AppColors.lightSecondaryText)),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('$quality/100', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary)),
                            Text(status, style: const TextStyle(fontSize: 10, color: AppColors.lightMutedText)),
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
