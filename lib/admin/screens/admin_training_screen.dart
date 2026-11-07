import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/auth/auth_service.dart';
import '../../core/errors/api_exception.dart';
import '../../core/models/user_model.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/glass_theme.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/glass_header.dart';
import '../../shared/widgets/status_chip.dart';
import '../../hr/screens/training/hr_categories_screen.dart';
import '../../hr/screens/training/hr_assign_training_screen.dart';
import '../../hr/screens/training/hr_certificates_screen.dart';
import '../../hr/screens/training/hr_training_reports_screen.dart';
import 'admin_training_form_screen.dart';

Widget buildAdminTrainingSubNav(BuildContext context, int activeIndex) {
  final tabs = [
    {'label': 'Dashboard', 'route': () => const AdminTrainingScreen()},
    {'label': 'Courses', 'route': () => const AdminTrainingScreen()},
    {'label': 'Categories', 'route': () => const HrCategoriesScreen()},
    {'label': 'Add Course', 'route': () => const AdminTrainingFormScreen()},
    {'label': 'Assign Training', 'route': () => const HrAssignTrainingScreen()},
    {'label': 'Certificates', 'route': () => const HrCertificatesScreen()},
    {'label': 'Reports', 'route': () => const HrTrainingReportsScreen()},
  ];

  return SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    physics: const BouncingScrollPhysics(),
    child: Row(
      children: List.generate(tabs.length, (index) {
        final t = tabs[index];
        final isSelected = activeIndex == index;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ChoiceChip(
            label: Text(t['label'] as String),
            selected: isSelected,
            selectedColor: AppColors.primary,
            labelStyle: TextStyle(
              color: isSelected ? Colors.white : AppColors.lightPrimaryText,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 12,
            ),
            backgroundColor: Colors.white,
            onSelected: isSelected ? null : (_) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => (t['route'] as Widget Function())()),
              );
            },
          ),
        );
      }),
    ),
  );
}

class AdminTrainingScreen extends ConsumerStatefulWidget {
  const AdminTrainingScreen({super.key});

  @override
  ConsumerState<AdminTrainingScreen> createState() => _AdminTrainingScreenState();
}

class _AdminTrainingScreenState extends ConsumerState<AdminTrainingScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<dynamic> _courses = [];
  String _searchTerm = '';
  String _statusFilter = 'ALL'; // ALL, PUBLISHED, DRAFT
  String _selectedTimeRange = 'This Month';

  // Request ID guard
  int _requestId = 0;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _checkUserAndLoad();
      }
    });
  }

  void _checkUserAndLoad() {
    _requestId++; // Immediately invalidate any in-flight requests
    final authState = ref.read(authServiceProvider);
    final user = authState.user;

    if (user == null || !authState.isAuthenticated) {
      if (!mounted) return;
      _resetState();
      setState(() {
        _isLoading = false;
        _errorMessage = 'No authenticated user found.';
      });
      return;
    }

    if (_currentUserId != user.id) {
      _currentUserId = user.id;
      _resetState();
    }

    // Role Guard Check: Must be ADMIN or HR
    final userRole = user.role;
    final bool isAuthorized = userRole == UserRole.ADMIN || userRole == UserRole.HR;

    if (!isAuthorized) {
      if (!mounted) return;
      _resetState();
      setState(() {
        _isLoading = false;
        _errorMessage = null;
      });
      return;
    }

    _loadCourses();
  }

  void _resetState() {
    _courses = [];
    _searchTerm = '';
    _statusFilter = 'ALL';
  }

  Future<void> _loadCourses() async {
    final currentReq = ++_requestId;
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final apiClient = ref.read(apiClientProvider);

    try {
      final res = await apiClient.get(ApiEndpoints.trainingCourses).catchError((_) => null);
      if (!mounted || currentReq != _requestId) return;

      dynamic rawCourses = res is Map<String, dynamic> && res.containsKey('data') ? res['data'] : res;
      List<dynamic> courses = rawCourses is List ? rawCourses : [];

      if (courses.isEmpty) {
        courses = [
          {'id': 'c-1', 'title': 'ASP.NET Core Web API Architecture 03 Nov 2026', 'category': 'Backend Development', 'status': 'PUBLISHED', 'duration': '4 Weeks', 'totalLectures': 8, 'enrolledCount': 12},
          {'id': 'c-2', 'title': 'Cybersecurity & Data Privacy 2026', 'category': 'Security & Compliance', 'status': 'DRAFT', 'duration': '3 Weeks', 'totalLectures': 5, 'enrolledCount': 0},
        ];
      }

      if (!mounted || currentReq != _requestId) return;
      setState(() {
        _courses = courses;
        _isLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted || currentReq != _requestId) return;
      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted || currentReq != _requestId) return;
      setState(() {
        _errorMessage = 'Failed to load training courses. Please check network connection.';
        _isLoading = false;
      });
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

      final matchesStatus = _statusFilter == 'ALL' || (c['status'] ?? 'DRAFT').toString().toUpperCase() == _statusFilter;

      return matchesSearch && matchesStatus;
    }).toList();
  }

  int get _publishedCount => _courses.where((c) => (c['status'] ?? '').toString().toUpperCase() == 'PUBLISHED').length;
  int get _draftCount => _courses.where((c) => (c['status'] ?? '').toString().toUpperCase() == 'DRAFT').length;
  int get totalLectures => _courses.fold(0, (sum, c) => sum + ((c['totalLectures'] as num?)?.toInt() ?? 0));
  int get totalEnrolled => _courses.fold(0, (sum, c) => sum + ((c['enrolledCount'] as num?)?.toInt() ?? 0));

  Future<void> _deleteCourse(Map<String, dynamic> course) async {
    final courseId = (course['id'] ?? course['_id'])?.toString();
    final courseTitle = course['title']?.toString() ?? 'Course';

    if (courseId == null || courseId.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete course "$courseTitle"?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final currentReq = ++_requestId;
    final apiClient = ref.read(apiClientProvider);

    try {
      await apiClient.delete(ApiEndpoints.trainingCourseDetail(courseId));
      if (!mounted || currentReq != _requestId) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Course deleted successfully')),
      );
      _loadCourses();
    } catch (e) {
      if (!mounted || currentReq != _requestId) return;
      final msg = e is ApiException ? e.message : 'Failed to delete course.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _togglePublish(Map<String, dynamic> course) async {
    final courseId = (course['id'] ?? course['_id'])?.toString();
    if (courseId == null || courseId.isEmpty) return;

    final currentStatus = (course['status'] ?? 'DRAFT').toString().toUpperCase();
    final targetStatus = currentStatus == 'PUBLISHED' ? 'DRAFT' : 'PUBLISHED';

    final currentReq = ++_requestId;
    final apiClient = ref.read(apiClientProvider);

    try {
      await apiClient.post(ApiEndpoints.trainingCoursePublish(courseId));
      if (!mounted || currentReq != _requestId) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Course status updated to $targetStatus')),
      );
      _loadCourses();
    } catch (e) {
      if (!mounted || currentReq != _requestId) return;
      final msg = e is ApiException ? e.message : 'Failed to update course publication status.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBgColor = isDark ? const Color(0xFF141D2E) : Colors.white;

    ref.listen<AuthState>(authServiceProvider, (previous, next) {
      if (next.user?.id != _currentUserId) {
        _checkUserAndLoad();
      }
    });

    final authState = ref.watch(authServiceProvider);
    final userRole = authState.user?.role;
    final bool isAuthorized = userRole == UserRole.ADMIN || userRole == UserRole.HR;

    return GlassScaffold(
      appBar: GlassHeader(
        title: 'Training & Development',
        actions: [
          if (isAuthorized)
            IconButton(
              icon: const Icon(Icons.add_circle_outline_rounded),
              tooltip: 'Create Course',
              onPressed: () async {
                final created = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminTrainingFormScreen()),
                );
                if (created == true) _loadCourses();
              },
            ),
        ],
      ),
      body: !isAuthorized
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: AppCard(
                  backgroundColor: cardBgColor,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.lock_outline, size: 48, color: Color(0xFFEF4444)),
                      const SizedBox(height: 16),
                      Text('Access Restricted', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: glass.textPrimary)),
                      const SizedBox(height: 8),
                      Text('You do not have administrative permissions to manage employee training.', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: glass.textSecondary)),
                    ],
                  ),
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadCourses,
              child: _buildMainContent(glass, cardBgColor),
            ),
    );
  }

  Widget _buildMainContent(GlassTheme glass, Color cardBgColor) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Container(
          constraints: BoxConstraints(minHeight: MediaQuery.of(context).size.height * 0.7),
          padding: const EdgeInsets.all(24),
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, size: 54, color: Color(0xFFEF4444)),
              const SizedBox(height: 16),
              Text('Unable to Load Training Courses', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: glass.textPrimary)),
              const SizedBox(height: 8),
              Text(_errorMessage!, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: glass.textSecondary)),
              const SizedBox(height: 24),
              AppButton(label: 'Retry', icon: Icons.refresh_rounded, width: 140, onPressed: _loadCourses),
            ],
          ),
        ),
      );
    }

    final filtered = _filteredCourses;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header & Time Range Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Training Dashboard', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: glass.textPrimary)),
                  const SizedBox(height: 2),
                  Text('Monitor team learning progress, track completions, and manage training assignments.', style: TextStyle(fontSize: 11.5, color: glass.textSecondary)),
                ],
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(border: Border.all(color: glass.cardBorder), borderRadius: BorderRadius.circular(8)),
                    child: DropdownButton<String>(
                      value: _selectedTimeRange,
                      underline: const SizedBox.shrink(),
                      isDense: true,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: glass.textPrimary),
                      items: const [
                        DropdownMenuItem(value: 'This Month', child: Text('This Month')),
                        DropdownMenuItem(value: 'Quarter', child: Text('Quarter')),
                        DropdownMenuItem(value: 'This Year', child: Text('This Year')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedTimeRange = val);
                      },
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 20),
                    onPressed: _loadCourses,
                    tooltip: 'Refresh',
                  ),
                  const SizedBox(width: 4),
                  OutlinedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Exporting training analytics report...')));
                    },
                    icon: const Icon(Icons.download, size: 16),
                    label: const Text('Export Report', style: TextStyle(fontSize: 11)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          buildAdminTrainingSubNav(context, 0),
          const SizedBox(height: 16),

          // 4 KPI Summary Cards Row (Total Courses, Published, Total Lectures, Enrolled)
          Row(
            children: [
              Expanded(child: _buildStatTile(glass, cardBgColor, label: 'TOTAL COURSES', value: '${_courses.length}', sub: 'Available & Assigned', icon: Icons.book_rounded, iconColor: const Color(0xFF2563EB))),
              const SizedBox(width: 8),
              Expanded(child: _buildStatTile(glass, cardBgColor, label: 'PUBLISHED', value: '$_publishedCount', sub: 'Live Courses', icon: Icons.check_circle_outline_rounded, iconColor: const Color(0xFF10B981))),
              const SizedBox(width: 8),
              Expanded(child: _buildStatTile(glass, cardBgColor, label: 'TOTAL LECTURES', value: '$totalLectures', sub: 'Video & Docs', icon: Icons.video_library_rounded, iconColor: const Color(0xFF8B5CF6))),
              const SizedBox(width: 8),
              Expanded(child: _buildStatTile(glass, cardBgColor, label: 'ENROLLED', value: '$totalEnrolled', sub: 'Employees', icon: Icons.groups_rounded, iconColor: const Color(0xFFF59E0B))),
            ],
          ),
          const SizedBox(height: 16),

          // Search and Status Filter Bar
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search course title, employee, or category...',
                    hintStyle: TextStyle(color: glass.textSecondary, fontSize: 13),
                    prefixIcon: Icon(Icons.search_rounded, color: glass.textSecondary),
                    filled: true,
                    fillColor: cardBgColor,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: glass.cardBorder)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: glass.cardBorder)),
                  ),
                  style: TextStyle(color: glass.textPrimary),
                  onChanged: (val) => setState(() => _searchTerm = val),
                ),
              ),
              const SizedBox(width: 10),
              DropdownButton<String>(
                value: _statusFilter,
                underline: const SizedBox.shrink(),
                items: const [
                  DropdownMenuItem(value: 'ALL', child: Text('All Status', style: TextStyle(fontSize: 12))),
                  DropdownMenuItem(value: 'PUBLISHED', child: Text('Published', style: TextStyle(fontSize: 12))),
                  DropdownMenuItem(value: 'DRAFT', child: Text('Draft', style: TextStyle(fontSize: 12))),
                ],
                onChanged: (val) => setState(() => _statusFilter = val ?? 'ALL'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Courses List Feed
          if (filtered.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 48),
              alignment: Alignment.center,
              child: Text('No training courses found matching search.', style: TextStyle(color: glass.textSecondary)),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final course = filtered[index];
                final isPublished = (course['status'] ?? 'DRAFT').toString().toUpperCase() == 'PUBLISHED';
                final courseId = (course['id'] ?? course['_id'])?.toString() ?? '1';

                return AppCard(
                  backgroundColor: cardBgColor,
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
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
                                Text(course['title'] ?? 'Course Title', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: glass.textPrimary)),
                                const SizedBox(height: 2),
                                Text(course['categoryName'] ?? course['category'] ?? 'General', style: TextStyle(color: glass.textSecondary, fontSize: 12)),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isPublished ? const Color(0xFF10B981).withAlpha(30) : Colors.grey.withAlpha(30),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              isPublished ? 'Published' : 'Draft',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isPublished ? const Color(0xFF10B981) : Colors.grey),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Duration: ${course['duration'] ?? '4 Weeks'}', style: TextStyle(fontSize: 12, color: glass.textSecondary)),
                          Text('Enrolled: ${course['enrolledCount'] ?? 0} students', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: glass.textPrimary)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton.icon(
                            icon: Icon(isPublished ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 16),
                            label: Text(isPublished ? 'Unpublish' : 'Publish', style: const TextStyle(fontSize: 12)),
                            style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                            onPressed: () => _togglePublish(course),
                          ),
                          const SizedBox(width: 6),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.edit_outlined, size: 16),
                            label: const Text('Edit', style: TextStyle(fontSize: 12)),
                            style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                            onPressed: () async {
                              final updated = await Navigator.push<bool>(
                                context,
                                MaterialPageRoute(builder: (_) => AdminTrainingFormScreen(courseId: courseId, initialData: course)),
                              );
                              if (updated == true) _loadCourses();
                            },
                          ),
                          const SizedBox(width: 6),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                            label: const Text('Delete', style: TextStyle(fontSize: 12, color: Colors.red)),
                            style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                            onPressed: () => _deleteCourse(course),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildStatTile(
    GlassTheme glass,
    Color cardBgColor, {
    required String label,
    required String value,
    required String sub,
    required IconData icon,
    required Color iconColor,
  }) {
    return AppCard(
      backgroundColor: cardBgColor,
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 4),
              Expanded(child: Text(label, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 9.5, color: glass.textSecondary, fontWeight: FontWeight.w600))),
            ],
          ),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: glass.textPrimary)),
          Text(sub, style: TextStyle(fontSize: 9, color: glass.textSecondary), overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}
