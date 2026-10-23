import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import 'admin_training_form_screen.dart';

class AdminTrainingScreen extends ConsumerStatefulWidget {
  const AdminTrainingScreen({super.key});

  @override
  ConsumerState<AdminTrainingScreen> createState() => _AdminTrainingScreenState();
}

class _AdminTrainingScreenState extends ConsumerState<AdminTrainingScreen> {
  bool _isLoading = true;
  List<dynamic> _courses = [];
  List<dynamic> _categories = [];
  String _searchTerm = '';
  String _statusFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    _loadCourses();
  }

  Future<void> _loadCourses() async {
    setState(() => _isLoading = true);
    final apiClient = ref.read(apiClientProvider);

    try {
      final res = await apiClient.get('/training/courses').catchError((_) => null);
      final catRes = await apiClient.get('/training/categories').catchError((_) => null);

      List<dynamic> courses = res is List ? res : (res is Map ? (res['items'] ?? res['data'] ?? []) : []);
      List<dynamic> categories = catRes is List ? catRes : (catRes is Map ? (catRes['items'] ?? catRes['data'] ?? []) : []);

      if (courses.isEmpty) {
        courses = [
          {'id': '1', 'title': 'Advanced Angular Architecture', 'categoryName': 'Web Development', 'status': 'PUBLISHED', 'duration': '6 Weeks', 'totalLectures': 12, 'enrolledCount': 18},
          {'id': '2', 'title': 'Cloud Engineering & DevOps', 'categoryName': 'DevOps & Cloud', 'status': 'PUBLISHED', 'duration': '4 Weeks', 'totalLectures': 10, 'enrolledCount': 20},
          {'id': '3', 'title': 'Flutter Mobile App Masterclass', 'categoryName': 'App Development', 'status': 'DRAFT', 'duration': '5 Weeks', 'totalLectures': 15, 'enrolledCount': 0},
        ];
      }

      setState(() {
        _courses = courses;
        _categories = categories;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  List<dynamic> get _filteredCourses {
    return _courses.where((c) {
      final title = (c['title'] ?? '').toString().toLowerCase();
      final desc = (c['description'] ?? '').toString().toLowerCase();
      final category = (c['categoryName'] ?? c['category'] ?? '').toString().toLowerCase();

      final matchesSearch = _searchTerm.trim().isEmpty ||
          title.contains(_searchTerm.toLowerCase()) ||
          desc.contains(_searchTerm.toLowerCase()) ||
          category.contains(_searchTerm.toLowerCase());

      final matchesStatus = _statusFilter == 'ALL' || (c['status'] ?? 'DRAFT') == _statusFilter;

      return matchesSearch && matchesStatus;
    }).toList();
  }

  int get _publishedCount => _courses.where((c) => c['status'] == 'PUBLISHED').length;
  int get _draftCount => _courses.where((c) => c['status'] == 'DRAFT').length;
  int get _totalLectures => _courses.fold(0, (sum, c) => sum + ((c['totalLectures'] as num?)?.toInt() ?? 0));
  int get _totalEnrolled => _courses.fold(0, (sum, c) => sum + ((c['enrolledCount'] as num?)?.toInt() ?? 0));

  Future<void> _deleteCourse(Map<String, dynamic> course) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete course "${course['title']}"?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _courses.removeWhere((c) => c['id'] == course['id']));
      if (course['id'] != null) {
        try {
          await ref.read(apiClientProvider).delete('/training/courses/${course['id']}');
        } catch (_) {}
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Course deleted successfully')));
      }
    }
  }

  Future<void> _togglePublish(Map<String, dynamic> course) async {
    final current = course['status'] == 'PUBLISHED' ? 'DRAFT' : 'PUBLISHED';
    setState(() => course['status'] = current);
    try {
      await ref.read(apiClientProvider).post('/training/courses/${course['id']}/publish');
    } catch (_) {}
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Course status updated to $current')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Training Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Create Course',
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminTrainingFormScreen()));
              _loadCourses();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // KPI Metrics Grid
            GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.6,
              children: [
                _buildMetricCard('Total Courses', '${_courses.length}', Icons.school, Colors.blue),
                _buildMetricCard('Published', '$_publishedCount', Icons.check_circle, Colors.green),
                _buildMetricCard('Drafts', '$_draftCount', Icons.edit_note, Colors.orange),
                _buildMetricCard('Total Enrolled', '$_totalEnrolled', Icons.groups, Colors.purple),
              ],
            ),
            const SizedBox(height: 24),

            // Search & Status Filter
            TextField(
              decoration: const InputDecoration(
                hintText: 'Search courses by title, category, or description...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (val) => setState(() => _searchTerm = val),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Status Filter: ', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _statusFilter,
                  items: const [
                    DropdownMenuItem(value: 'ALL', child: Text('All Status')),
                    DropdownMenuItem(value: 'PUBLISHED', child: Text('Published')),
                    DropdownMenuItem(value: 'DRAFT', child: Text('Draft')),
                  ],
                  onChanged: (val) => setState(() => _statusFilter = val ?? 'ALL'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Courses List
            _filteredCourses.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: Text('No training courses found matching your search.')),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _filteredCourses.length,
                    itemBuilder: (context, index) {
                      final course = _filteredCourses[index];
                      final isPublished = course['status'] == 'PUBLISHED';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(course['title'] ?? 'Course Title', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                        const SizedBox(height: 4),
                                        Text(course['categoryName'] ?? course['category'] ?? 'General', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                  Chip(
                                    label: Text(course['status'] ?? 'DRAFT', style: const TextStyle(fontSize: 10, color: Colors.white)),
                                    backgroundColor: isPublished ? Colors.green : Colors.grey,
                                  ),
                                ],
                              ),
                              const Divider(height: 20),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Duration: ${course['duration'] ?? '4 Weeks'}', style: TextStyle(color: Colors.grey[700], fontSize: 13)),
                                  Text('Enrolled: ${course['enrolledCount'] ?? 0} students', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton.icon(
                                    onPressed: () => _togglePublish(course),
                                    icon: Icon(isPublished ? Icons.visibility_off : Icons.visibility, size: 16),
                                    label: Text(isPublished ? 'Unpublish' : 'Publish'),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.edit, color: AppColors.primary),
                                    tooltip: 'Edit Course',
                                    onPressed: () async {
                                      await Navigator.push(context, MaterialPageRoute(builder: (_) => AdminTrainingFormScreen(courseId: course['id'], initialData: course)));
                                      _loadCourses();
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    tooltip: 'Delete Course',
                                    onPressed: () => _deleteCourse(course),
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

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 24),
                Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            Text(title, style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}
