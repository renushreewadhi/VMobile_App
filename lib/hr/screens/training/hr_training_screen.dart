import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/loading_shimmer.dart';
import '../../../shared/widgets/status_chip.dart';
import '../../../admin/screens/admin_training_form_screen.dart';
import 'hr_training_dashboard_screen.dart';

class HrTrainingScreen extends ConsumerStatefulWidget {
  const HrTrainingScreen({super.key});

  @override
  ConsumerState<HrTrainingScreen> createState() => _HrTrainingScreenState();
}

class _HrTrainingScreenState extends ConsumerState<HrTrainingScreen> {
  bool _isLoading = true;
  List<dynamic> _programs = [];
  String _searchTerm = '';
  String _selectedCategory = 'All Categories';
  String _selectedStatus = 'All Status';

  @override
  void initState() {
    super.initState();
    _loadTrainings();
  }

  Future<void> _loadTrainings() async {
    setState(() => _isLoading = true);
    final apiClient = ref.read(apiClientProvider);
    try {
      final res = await apiClient.get('/training/courses').catchError((_) => null);
      List<dynamic> items = [];
      if (res is List) {
        items = res;
      } else if (res is Map<String, dynamic>) {
        items = res['items'] ?? res['data'] ?? [];
      }

      if (items.isEmpty) {
        items = [
          {'id': '1', 'title': 'Advanced Angular Architecture', 'trainer': 'Aarav Sharma', 'duration': '6 Weeks', 'category': 'Backend Development', 'enrolledCount': 18, 'status': 'ACTIVE'},
          {'id': '2', 'title': 'Cloud Engineering & DevOps', 'trainer': 'Vikram Malhotra', 'duration': '4 Weeks', 'category': 'DevOps & Cloud', 'enrolledCount': 20, 'status': 'ACTIVE'},
          {'id': '3', 'title': 'Mobile Application Development', 'trainer': 'Rahul Sharma', 'duration': '8 Weeks', 'category': 'App Development', 'enrolledCount': 15, 'status': 'ACTIVE'},
        ];
      }

      setState(() {
        _programs = items;
        _isLoading = false;
      });
    } catch (_) {
      setState(() {
        _programs = [];
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const LoadingShimmer();

    final filtered = _programs.where((p) {
      final map = p is Map<String, dynamic> ? p : {};
      final title = (map['title'] ?? '').toString().toLowerCase();
      final trainer = (map['trainer'] ?? '').toString().toLowerCase();
      final cat = (map['category'] ?? 'Backend Development').toString();
      final status = (map['status'] ?? 'ACTIVE').toString();

      final matchesSearch = _searchTerm.isEmpty || title.contains(_searchTerm.toLowerCase()) || trainer.contains(_searchTerm.toLowerCase());
      final matchesCat = _selectedCategory == 'All Categories' || cat == _selectedCategory;
      final matchesStatus = _selectedStatus == 'All Status' || status == _selectedStatus;

      return matchesSearch && matchesCat && matchesStatus;
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
                      Text('Courses', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      SizedBox(height: 2),
                      Text('Manage training programs, course modules, and learning tracks', style: TextStyle(fontSize: 11.5, color: AppColors.lightSecondaryText)),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    await Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminTrainingFormScreen()));
                    _loadTrainings();
                  },
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Create Course', style: TextStyle(fontSize: 11.5)),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 14),
            buildHrTrainingSubNav(context, 1),
            const SizedBox(height: 16),

            // Search and Filters Bar
            AppCard(
              child: Column(
                children: [
                  TextField(
                    decoration: const InputDecoration(
                      hintText: 'Search courses by title, instructor, or tags...',
                      prefixIcon: Icon(Icons.search, size: 18),
                      border: OutlineInputBorder(borderSide: BorderSide.none),
                      filled: true,
                      fillColor: AppColors.lightInputBackground,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    onChanged: (val) => setState(() => _searchTerm = val),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedCategory,
                          decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 6), isDense: true),
                          items: const [
                            DropdownMenuItem(value: 'All Categories', child: Text('All Categories')),
                            DropdownMenuItem(value: 'Backend Development', child: Text('Backend Development')),
                            DropdownMenuItem(value: 'DevOps & Cloud', child: Text('DevOps & Cloud')),
                            DropdownMenuItem(value: 'App Development', child: Text('App Development')),
                          ],
                          onChanged: (val) => setState(() => _selectedCategory = val ?? 'All Categories'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedStatus,
                          decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 6), isDense: true),
                          items: const [
                            DropdownMenuItem(value: 'All Status', child: Text('All Status')),
                            DropdownMenuItem(value: 'ACTIVE', child: Text('Active')),
                            DropdownMenuItem(value: 'DRAFT', child: Text('Draft')),
                          ],
                          onChanged: (val) => setState(() => _selectedStatus = val ?? 'All Status'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Courses List
            filtered.isEmpty
                ? const AppCard(child: Padding(padding: EdgeInsets.all(24), child: Center(child: Text('No courses found matching criteria.'))))
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final p = filtered[index] as Map<String, dynamic>;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: AppCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(child: Text(p['title'] ?? 'Program', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
                                  StatusChip(status: p['status'] ?? 'ACTIVE'),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text('Category: ${p['category'] ?? 'General'} • Trainer: ${p['trainer'] ?? 'Lead Trainer'}', style: const TextStyle(fontSize: 12, color: AppColors.lightSecondaryText)),
                              const SizedBox(height: 4),
                              Text('Duration: ${p['duration'] ?? '4 weeks'} • Enrolled: ${p['enrolledCount'] ?? 0} students', style: const TextStyle(fontSize: 11.5, color: AppColors.lightMutedText)),
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
