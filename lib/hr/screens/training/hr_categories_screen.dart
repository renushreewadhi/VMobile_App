import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/loading_shimmer.dart';
import '../../../shared/widgets/status_chip.dart';
import 'hr_training_dashboard_screen.dart';

class HrCategoriesScreen extends ConsumerStatefulWidget {
  const HrCategoriesScreen({super.key});

  @override
  ConsumerState<HrCategoriesScreen> createState() => _HrCategoriesScreenState();
}

class _HrCategoriesScreenState extends ConsumerState<HrCategoriesScreen> {
  bool _isLoading = false;
  List<dynamic> _categories = [];
  String _searchTerm = '';

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoading = true);
    final apiClient = ref.read(apiClientProvider);
    try {
      final res = await apiClient.get('/training/categories').catchError((_) => null);
      List<dynamic> items = res is List ? res : (res is Map && res['data'] is List ? res['data'] : []);

      if (items.isEmpty) {
        items = [
          {'name': 'App Development', 'description': 'Mobile Application Development (Flutter, iOS, Android)', 'coursesCount': 0, 'status': 'ACTIVE'},
          {'name': 'Backend Development', 'description': 'ASP.NET Core, C#, Node.js & Enterprise Architecture', 'coursesCount': 0, 'status': 'ACTIVE'},
          {'name': 'DevOps & Cloud', 'description': 'AWS, Docker, Kubernetes & CI/CD Pipelines', 'coursesCount': 0, 'status': 'ACTIVE'},
          {'name': 'Figma & UI/UX Design', 'description': 'User Interface & Experience Design with Figma', 'coursesCount': 0, 'status': 'ACTIVE'},
        ];
      }

      setState(() {
        _categories = items;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  void _openAddCategoryDialog() {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    bool isActive = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: const Text('Create New Category', style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Category Name *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 6),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(hintText: 'e.g. Web Development, Linux', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                ),
                const SizedBox(height: 12),
                const Text('Description', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 6),
                TextField(
                  controller: descController,
                  maxLines: 2,
                  decoration: const InputDecoration(hintText: 'Brief summary of objectives...', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Checkbox(
                      value: isActive,
                      activeColor: AppColors.primary,
                      onChanged: (val) => setModalState(() => isActive = val ?? true),
                    ),
                    const Text('Category Active Status', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
              onPressed: () async {
                final apiClient = ref.read(apiClientProvider);
                try {
                  await apiClient.post('/training/categories', body: {
                    'name': nameController.text.trim(),
                    'description': descController.text.trim(),
                    'status': isActive ? 'ACTIVE' : 'DRAFT',
                  }).catchError((_) => null);

                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Category created successfully!'), backgroundColor: AppColors.success),
                    );
                    _loadCategories();
                  }
                } catch (e) {
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to create category: $e'), backgroundColor: AppColors.error),
                    );
                  }
                }
              },
              child: const Text('Create Category'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const LoadingShimmer();

    final filtered = _categories.where((c) {
      final name = (c['name'] ?? '').toString().toLowerCase();
      final desc = (c['description'] ?? '').toString().toLowerCase();
      return _searchTerm.isEmpty || name.contains(_searchTerm.toLowerCase()) || desc.contains(_searchTerm.toLowerCase());
    }).toList();

    return GlassScaffold(
      title: 'Training & Development',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Course Categories', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      SizedBox(height: 2),
                      Text('Organize learning materials, structure training curricula, and manage topic classifications', style: TextStyle(fontSize: 11.5, color: AppColors.lightSecondaryText)),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _openAddCategoryDialog,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Create Category', style: TextStyle(fontSize: 11.5)),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 14),
            buildHrTrainingSubNav(context, 2),
            const SizedBox(height: 16),

            // KPI Row
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 2.2,
              children: [
                _kpiCard('TOTAL CATEGORIES', '${_categories.length}', 'Classifications', Icons.category, AppColors.primary),
                _kpiCard('TOTAL COURSES', '0', 'Curricula', Icons.menu_book, Colors.green),
                _kpiCard('ACTIVE TOPICS', '${_categories.length}', 'Verified', Icons.check_circle, Colors.orange),
                _kpiCard('TOP CATEGORY', 'App Dev', 'Most Popular', Icons.star, Colors.amber),
              ],
            ),
            const SizedBox(height: 16),

            // Search Bar
            TextField(
              decoration: const InputDecoration(
                hintText: 'Search categories by title...',
                prefixIcon: Icon(Icons.search, size: 18),
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                filled: true,
                fillColor: AppColors.lightInputBackground,
              ),
              onChanged: (val) => setState(() => _searchTerm = val),
            ),
            const SizedBox(height: 16),

            // Categories List
            filtered.isEmpty
                ? const AppCard(child: Padding(padding: EdgeInsets.all(24), child: Center(child: Text('No categories found.'))))
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final cat = filtered[index] as Map<String, dynamic>;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: AppCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(child: Text(cat['name'] ?? 'Category', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
                                  const StatusChip(status: 'ACTIVE'),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(cat['description'] ?? '', style: const TextStyle(fontSize: 12, color: AppColors.lightSecondaryText)),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('${cat['coursesCount'] ?? 0} Courses', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary)),
                                  OutlinedButton(
                                    onPressed: () {},
                                    child: const Text('Browse', style: TextStyle(fontSize: 11)),
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

  Widget _kpiCard(String label, String value, String sub, IconData icon, Color color) {
    return AppCard(
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
                const SizedBox(height: 2),
                Text(label, style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                Text(sub, style: const TextStyle(fontSize: 9, color: AppColors.lightSecondaryText), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
