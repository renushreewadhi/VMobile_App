import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/training_service.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/loading_shimmer.dart';
import '../../shared/widgets/status_chip.dart';
import '../../core/widgets/glass_scaffold.dart';

Widget buildTrainingSubNav(BuildContext context, int activeIndex) {
  final tabs = [
    {'label': 'Dashboard', 'route': () => const TrainingDashboardScreen()},
    {'label': 'My Courses', 'route': () => const MyCoursesScreen()},
    {'label': 'In Progress', 'route': () => const TrainingInProgressScreen()},
    {'label': 'Completed', 'route': () => const TrainingCompletedScreen()},
    {'label': 'Certificates', 'route': () => const MyCertificatesScreen()},
    {'label': 'History', 'route': () => const TrainingHistoryScreen()},
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

class TrainingDashboardScreen extends ConsumerStatefulWidget {
  const TrainingDashboardScreen({super.key});

  @override
  ConsumerState<TrainingDashboardScreen> createState() => _TrainingDashboardScreenState();
}

class _TrainingDashboardScreenState extends ConsumerState<TrainingDashboardScreen> {
  bool _isLoading = true;
  String? _error;
  List<dynamic> _courses = [];
  String _searchTerm = '';
  String _selectedCategory = 'ALL';

  @override
  void initState() {
    super.initState();
    _fetchTraining();
  }

  Future<void> _fetchTraining() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final trainingService = ref.read(trainingServiceProvider);
    try {
      final res = await trainingService.rawGet('/training/my-courses').catchError((_) => null);
      if (!mounted) return;
      final rawList = res is List
          ? res
          : (res is Map<String, dynamic> && res['data'] is List ? res['data'] as List : []);

      setState(() {
        _courses = rawList;
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _courses = [];
          _isLoading = false;
          _error = e.toString().replaceFirst('ApiException: ', '').replaceFirst('Exception: ', '');
        });
      }
    }
  }

  List<dynamic> get _filteredCourses {
    return _courses.where((c) {
      final title = (c['title'] ?? c['courseTitle'] ?? '').toString().toLowerCase();
      final category = (c['categoryName'] ?? c['category'] ?? 'Software Development').toString();
      final instructor = (c['createdByName'] ?? c['instructor'] ?? '').toString().toLowerCase();

      final matchesSearch = _searchTerm.isEmpty || title.contains(_searchTerm.toLowerCase()) || instructor.contains(_searchTerm.toLowerCase());
      final matchesCat = _selectedCategory == 'ALL' || category == _selectedCategory;
      return matchesSearch && matchesCat;
    }).toList();
  }

  int get _activeCount => _courses.where((c) => _getProgress(c) < 1.0 && c['status'] != 'COMPLETED').length;
  int get _completedCount => _courses.where((c) => _getProgress(c) >= 1.0 || c['status'] == 'COMPLETED').length;
  int get _completionRate {
    if (_courses.isEmpty) return 0;
    final total = _courses.fold<double>(0, (sum, c) => sum + _getProgress(c));
    return ((total / _courses.length) * 100).round();
  }

  double _getProgress(dynamic c) {
    final prog = c['progressPercentage'] ?? c['progress'] ?? 0.0;
    if (prog is num) {
      return prog > 1.0 ? prog / 100.0 : prog.toDouble();
    }
    return double.tryParse(prog.toString()) ?? 0.0;
  }

  List<String> get _categories {
    final set = <String>{};
    for (final c in _courses) {
      final cat = c['categoryName']?.toString() ?? c['category']?.toString();
      if (cat != null && cat.isNotEmpty) set.add(cat);
    }
    return set.toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GlassScaffold(
      title: 'Training & Development',
      body: _isLoading
          ? const DashboardSkeleton()
          : RefreshIndicator(
              onRefresh: _fetchTraining,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                physics: const AlwaysScrollableScrollPhysics(),
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
                              Text('Training & Development', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText)),
                              const SizedBox(height: 2),
                              Text('Organize employee training courses, track enrollments, and evaluate completion rates', style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText)),
                            ],
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const MyCertificatesScreen()));
                          },
                          icon: const Icon(Icons.workspace_premium, size: 16),
                          label: const Text('My Certificates (0)', style: TextStyle(fontSize: 11.5)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.primary),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    buildTrainingSubNav(context, 0),
                    const SizedBox(height: 16),
                    _buildKpiGrid(isDark),
                    const SizedBox(height: 16),
                    _buildFilterToolbar(isDark),
                    const SizedBox(height: 16),
                    Text('All Assigned Courses', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText)),
                    const SizedBox(height: 2),
                    Text('List view of courses assigned by your Team Lead', style: TextStyle(fontSize: 11.5, color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText)),
                    const SizedBox(height: 12),

                    if (_error != null)
                      AppCard(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [
                              const Icon(Icons.error_outline, size: 36, color: Colors.redAccent),
                              const SizedBox(height: 8),
                              Text('Failed to load courses', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText)),
                              const SizedBox(height: 4),
                              Text(_error!, style: const TextStyle(fontSize: 12, color: Colors.grey), textAlign: TextAlign.center),
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                onPressed: _fetchTraining,
                                icon: const Icon(Icons.refresh, size: 16),
                                label: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      )
                    else if (_filteredCourses.isEmpty)
                      AppCard(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Center(
                            child: Column(
                              children: const [
                                Icon(Icons.school_outlined, size: 40, color: Colors.grey),
                                SizedBox(height: 8),
                                Text('No active training courses found.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                SizedBox(height: 4),
                                Text('You are not currently enrolled in any matching courses.', style: TextStyle(fontSize: 12, color: Colors.grey), textAlign: TextAlign.center),
                              ],
                            ),
                          ),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _filteredCourses.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final c = _filteredCourses[index];
                          final title = c['title']?.toString() ?? c['courseTitle']?.toString() ?? 'Course Title';
                          final instructor = c['createdByName']?.toString() ?? c['instructor']?.toString() ?? 'Etaprise Technical Academy';
                          final category = c['categoryName']?.toString() ?? c['category']?.toString() ?? 'Software Development';
                          final dueDate = c['dueDate']?.toString() ?? '30 Oct 2026';
                          final progress = _getProgress(c);
                          final isCompleted = progress >= 1.0 || c['status'] == 'COMPLETED';

                          return AppCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(child: Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText))),
                                    StatusChip(status: isCompleted ? 'COMPLETED' : 'ACTIVE'),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text('Category: $category • Instructor: $instructor • Due: $dueDate', style: TextStyle(fontSize: 11.5, color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText)),
                                const SizedBox(height: 10),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('${(progress * 100).toInt()}% completed', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary)),
                                    ElevatedButton(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => CoursePlayerScreen(
                                              courseId: c['id']?.toString() ?? 'c-1',
                                              courseTitle: title,
                                              instructor: instructor,
                                              description: c['description']?.toString() ?? '',
                                              initialProgress: progress,
                                            ),
                                          ),
                                        );
                                      },
                                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6)),
                                      child: Text(isCompleted ? 'Review' : 'Open', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                LinearProgressIndicator(
                                  value: progress.clamp(0.0, 1.0),
                                  backgroundColor: isDark ? Colors.white12 : Colors.grey.shade300,
                                  color: isCompleted ? AppColors.success : AppColors.primary,
                                  minHeight: 6,
                                ),
                              ],
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

  Widget _buildKpiGrid(bool isDark) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.8,
      children: [
        _kpiCard('ACTIVE PROGRAMS', '$_activeCount', 'Current Quarter', Icons.school, AppColors.primary, isDark),
        _kpiCard('TOTAL COURSES', '${_courses.length}', 'Assigned Modules', Icons.book, Colors.green, isDark),
        _kpiCard('COMPLETION RATE', '$_completionRate%', 'Progress Tracked', Icons.trending_up, Colors.purple, isDark),
        _kpiCard('COMPLETED COURSES', '$_completedCount', 'Finished Modules', Icons.star, const Color(0xFFF59E0B), isDark),
      ],
    );
  }

  Widget _kpiCard(String label, String value, String sub, IconData icon, Color color, bool isDark) {
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
                const SizedBox(height: 2),
                Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText), overflow: TextOverflow.ellipsis),
                Text(sub, style: TextStyle(fontSize: 9.5, color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterToolbar(bool isDark) {
    return AppCard(
      child: Column(
        children: [
          TextField(
            onChanged: (val) => setState(() => _searchTerm = val),
            style: TextStyle(fontSize: 13, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText),
            decoration: InputDecoration(
              hintText: 'Search training programs, instructors...',
              hintStyle: TextStyle(fontSize: 12, color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText),
              prefixIcon: const Icon(Icons.search, size: 18),
              suffixIcon: _searchTerm.isNotEmpty
                  ? IconButton(icon: const Icon(Icons.clear, size: 16), onPressed: () => setState(() => _searchTerm = ''))
                  : null,
              filled: true,
              fillColor: isDark ? const Color(0xFF1A2632) : AppColors.lightInputBackground,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Category:', style: TextStyle(fontSize: 12, color: AppColors.lightSecondaryText)),
              DropdownButton<String>(
                value: _selectedCategory,
                underline: const SizedBox.shrink(),
                dropdownColor: isDark ? AppColors.darkMainSurface : Colors.white,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText),
                items: [
                  const DropdownMenuItem(value: 'ALL', child: Text('All Categories')),
                  ..._categories.map((cat) => DropdownMenuItem(value: cat, child: Text(cat))),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _selectedCategory = val);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class CoursePlayerScreen extends StatefulWidget {
  final String courseId;
  final String courseTitle;
  final String instructor;
  final String description;
  final double initialProgress;

  const CoursePlayerScreen({
    super.key,
    this.courseId = '',
    this.courseTitle = 'Course Player',
    this.instructor = 'Etaprise Technical Academy',
    this.description = '',
    this.initialProgress = 0.0,
  });

  @override
  State<CoursePlayerScreen> createState() => _CoursePlayerScreenState();
}

class _CoursePlayerScreenState extends State<CoursePlayerScreen> {
  int _activeLessonIndex = 0;
  List<Map<String, dynamic>> _lessons = [];

  @override
  void initState() {
    super.initState();
    _lessons = [
      {'id': '1', 'title': '1. Module Overview & Introduction', 'duration': '10 mins', 'completed': true, 'content': 'Introduction to architecture and state management concepts.'},
      {'id': '2', 'title': '2. Clean Architecture & Layering', 'duration': '25 mins', 'completed': true, 'content': 'Structuring data, domain, and UI layers.'},
      {'id': '3', 'title': '3. State Management with Riverpod', 'duration': '30 mins', 'completed': false, 'content': 'Implementing Providers, StateNotifier, and AsyncValue.'},
      {'id': '4', 'title': '4. Performance Optimization', 'duration': '20 mins', 'completed': false, 'content': 'Optimizing rebuilds, const constructors, and memory profiling.'},
    ];
  }

  double get _progress {
    if (_lessons.isEmpty) return widget.initialProgress;
    final completedCount = _lessons.where((l) => l['completed'] == true).length;
    return completedCount / _lessons.length;
  }

  void _toggleLessonComplete(int idx) {
    setState(() {
      _lessons[idx]['completed'] = !(_lessons[idx]['completed'] as bool);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeLesson = _lessons.isNotEmpty && _activeLessonIndex < _lessons.length ? _lessons[_activeLessonIndex] : null;

    return GlassScaffold(
      title: widget.courseTitle,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 200,
              width: double.infinity,
              color: Colors.black,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.play_circle_fill_rounded,
                        size: 56,
                        color: AppColors.primary.withOpacity(0.9),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        activeLesson?['title'] ?? 'Playing Lecture',
                        style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.courseTitle, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('Instructor: ${widget.instructor}', style: const TextStyle(fontSize: 12.5, color: AppColors.lightSecondaryText)),
                  if (widget.description.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(widget.description, style: const TextStyle(fontSize: 12, color: AppColors.lightSecondaryText, height: 1.35)),
                  ],
                  const SizedBox(height: 16),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Course Progress', style: TextStyle(fontSize: 12, color: AppColors.lightSecondaryText)),
                      Text('${(_progress * 100).toInt()}% Completed', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primary)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: _progress,
                    backgroundColor: Colors.grey.shade300,
                    color: _progress == 1.0 ? AppColors.success : AppColors.primary,
                    minHeight: 8,
                  ),

                  if (_progress == 1.0) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Downloading Certificate PDF...')));
                        },
                        icon: const Icon(Icons.workspace_premium, color: Colors.white),
                        label: const Text('View Certificate of Completion'),
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  if (activeLesson != null)
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(child: Text(activeLesson['title'].toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                              Text(activeLesson['duration'].toString(), style: const TextStyle(fontSize: 11, color: AppColors.lightSecondaryText)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(activeLesson['content'].toString(), style: const TextStyle(fontSize: 12, color: AppColors.lightSecondaryText)),
                        ],
                      ),
                    ),

                  const SizedBox(height: 20),
                  const Text('Course Modules & Lessons', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),

                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _lessons.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final lesson = _lessons[index];
                      final isSelected = _activeLessonIndex == index;
                      final isDone = lesson['completed'] as bool;

                      return InkWell(
                        onTap: () => setState(() => _activeLessonIndex = index),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.primary.withOpacity(0.12) : (isDark ? AppColors.darkSecondarySurface : Colors.white),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: isSelected ? AppColors.primary : (isDark ? AppColors.darkBordersAndDividers : AppColors.lightBordersAndDividers)),
                          ),
                          child: Row(
                            children: [
                              Checkbox(
                                value: isDone,
                                activeColor: AppColors.primary,
                                onChanged: (_) => _toggleLessonComplete(index),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(lesson['title'].toString(), style: TextStyle(fontSize: 13, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                                    Text(lesson['duration'].toString(), style: const TextStyle(fontSize: 11, color: AppColors.lightSecondaryText)),
                                  ],
                                ),
                              ),
                              if (isSelected) const Icon(Icons.play_circle_outline, color: AppColors.primary, size: 20),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MyCoursesScreen extends ConsumerStatefulWidget {
  const MyCoursesScreen({super.key});

  @override
  ConsumerState<MyCoursesScreen> createState() => _MyCoursesScreenState();
}

class _MyCoursesScreenState extends ConsumerState<MyCoursesScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;
  String _filter = 'All Status';
  String _query = '';
  List<Map<String, dynamic>> _courses = [];

  @override
  void initState() {
    super.initState();
    _loadCourses();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCourses() async {
    setState(() => _isLoading = true);
    final trainingService = ref.read(trainingServiceProvider);
    try {
      final res = await trainingService.getMyCourses().catchError((_) => null);
      if (mounted) {
        final list = res is List ? res : (res is Map && res['data'] is List ? res['data'] as List : []);

        final loadedList = <Map<String, dynamic>>[];
        for (final item in list) {
          if (item is Map) {
            final id = item['id']?.toString() ?? 'c-1';
            final title = item['title']?.toString() ?? item['courseTitle']?.toString() ?? 'Untitled Course';
            final provider = item['createdByName']?.toString() ?? item['instructor']?.toString() ?? 'ETAPRISE Learning';
            final category = item['categoryName']?.toString() ?? item['category']?.toString() ?? 'General';
            final duration = item['duration']?.toString() ?? 'Self-paced';
            final description = item['description']?.toString() ?? 'No course description available.';
            final progress = (double.tryParse(item['progressPercentage']?.toString() ?? '0.5') ?? 0.5);

            loadedList.add({
              'id': id,
              'title': title,
              'provider': provider,
              'category': category,
              'duration': duration,
              'progress': progress,
              'status': progress >= 1.0 ? 'Completed' : (progress > 0 ? 'In Progress' : 'Not Started'),
              'description': description,
            });
          }
        }

        setState(() {
          _courses = loadedList;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _visibleCourses {
    return _courses.where((course) {
      final matchesFilter = _filter == 'All Status' ||
          (_filter == 'In Progress' && course['status'] == 'In Progress') ||
          (_filter == 'Completed' && course['status'] == 'Completed') ||
          (_filter == 'Not Started' && course['status'] == 'Not Started');
      final q = _query.trim().toLowerCase();
      final matchesQuery = q.isEmpty ||
          course['title'].toString().toLowerCase().contains(q) ||
          course['provider'].toString().toLowerCase().contains(q) ||
          course['category'].toString().toLowerCase().contains(q);
      return matchesFilter && matchesQuery;
    }).toList();
  }

  void _openCoursePlayer(Map<String, dynamic> course) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CoursePlayerScreen(
          courseId: course['id']?.toString() ?? 'c-101',
          courseTitle: course['title']?.toString() ?? 'Course',
          instructor: course['provider']?.toString() ?? 'Etaprise Technical Academy',
          description: course['description']?.toString() ?? '',
          initialProgress: (course['progress'] as double? ?? 0.5),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GlassScaffold(
      title: 'My Courses',
      body: _isLoading
          ? const ListSkeleton(itemCount: 4)
          : RefreshIndicator(
              onRefresh: _loadCourses,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
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
                              Text('My Enrolled Courses', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText)),
                              const SizedBox(height: 2),
                              Text('View and access all courses assigned to you by your Team Lead or HR.', style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText)),
                            ],
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back, size: 16),
                          label: const Text('Back', style: TextStyle(fontSize: 11.5)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    buildTrainingSubNav(context, 1),
                    const SizedBox(height: 16),
                    _buildMyCoursesKpiGrid(isDark),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _searchController,
                      onChanged: (val) => setState(() => _query = val),
                      decoration: InputDecoration(
                        hintText: 'Search training programs, instructors...',
                        prefixIcon: const Icon(Icons.search, size: 18),
                        filled: true,
                        fillColor: isDark ? AppColors.darkSecondarySurface : AppColors.lightInputBackground,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 10),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Status Filter:', style: TextStyle(fontSize: 12, color: AppColors.lightSecondaryText)),
                        DropdownButton<String>(
                          value: _filter,
                          underline: const SizedBox.shrink(),
                          items: const [
                            DropdownMenuItem(value: 'All Status', child: Text('All Status')),
                            DropdownMenuItem(value: 'In Progress', child: Text('In Progress')),
                            DropdownMenuItem(value: 'Completed', child: Text('Completed')),
                            DropdownMenuItem(value: 'Not Started', child: Text('Not Started')),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _filter = val);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    Text('Enrolled Courses Summary', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText)),
                    const SizedBox(height: 2),
                    Text('Showing ${_visibleCourses.length} of ${_courses.length} courses', style: TextStyle(fontSize: 11.5, color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText)),
                    const SizedBox(height: 12),

                    // Courses List
                    _visibleCourses.isEmpty
                        ? AppCard(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Center(
                                child: Column(
                                  children: [
                                    const Icon(Icons.search_off, size: 40, color: Colors.grey),
                                    const SizedBox(height: 8),
                                    const Text('No courses match your filter', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                    const SizedBox(height: 4),
                                    const Text('Try resetting filters or clear your search query.', style: TextStyle(fontSize: 12, color: Colors.grey), textAlign: TextAlign.center),
                                    const SizedBox(height: 12),
                                    OutlinedButton(
                                      onPressed: () => setState(() {
                                        _filter = 'All Status';
                                        _query = '';
                                        _searchController.clear();
                                      }),
                                      child: const Text('Clear Filters'),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _visibleCourses.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final course = _visibleCourses[index];
                              final progress = (course['progress'] as double? ?? 0.0);

                              return InkWell(
                                onTap: () => _openCoursePlayer(course),
                                borderRadius: BorderRadius.circular(16),
                                child: AppCard(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(course['title'], style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText)),
                                          ),
                                          StatusChip(status: course['status']?.toString().toUpperCase() ?? 'IN_PROGRESS'),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text('${course['provider']} • ${course['category']} • ${course['duration']}', style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText)),
                                      const SizedBox(height: 10),
                                      LinearProgressIndicator(
                                        value: progress,
                                        backgroundColor: isDark ? Colors.white12 : Colors.grey.shade300,
                                        color: progress >= 1.0 ? AppColors.success : AppColors.primary,
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text('${(progress * 100).toInt()}% completed', style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkMutedText : Colors.grey)),
                                          ElevatedButton(
                                            onPressed: () => _openCoursePlayer(course),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: AppColors.primary,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                            ),
                                            child: Text(course['status'] == 'Completed' ? 'Review Course' : 'Continue', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
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
            ),
    );
  }

  Widget _buildMyCoursesKpiGrid(bool isDark) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.8,
      children: [
        _kpiCard('ACTIVE PROGRAMS', '${_courses.where((c) => c['progress'] < 1.0).length}', 'Current Quarter', Icons.school, AppColors.primary, isDark),
        _kpiCard('ENROLLED EMPLOYEES', '74', 'Across Batches', Icons.groups, Colors.green, isDark),
        _kpiCard('COMPLETION RATE', '${_courses.isNotEmpty ? (_courses.fold<double>(0, (s, c) => s + (c['progress'] as double)) / _courses.length * 100).round() : 0}%', 'Certified Candidates', Icons.trending_up, Colors.purple, isDark),
        _kpiCard('AVG. FEEDBACK SCORE', '4.8 / 5', 'Trainee Reviews', Icons.star, const Color(0xFFF59E0B), isDark),
      ],
    );
  }

  Widget _kpiCard(String label, String value, String sub, IconData icon, Color color, bool isDark) {
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
                const SizedBox(height: 2),
                Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText), overflow: TextOverflow.ellipsis),
                Text(sub, style: TextStyle(fontSize: 9.5, color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class TrainingInProgressScreen extends StatelessWidget {
  const TrainingInProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GlassScaffold(
      title: 'In Progress Training',
      body: SingleChildScrollView(
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
                      Text('In-Progress Training', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText)),
                      const SizedBox(height: 2),
                      Text('Track and resume courses and modules you are actively working on.', style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText)),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back, size: 16),
                  label: const Text('Back', style: TextStyle(fontSize: 11.5)),
                ),
              ],
            ),
            const SizedBox(height: 14),
            buildTrainingSubNav(context, 2),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.8,
              children: [
                _kpiCard('ACTIVE COURSES', '0', 'Currently Studying', Icons.hourglass_top, AppColors.primary, isDark),
                _kpiCard('FINISHED LECTURES', '0', 'Out of 0 Total', Icons.play_circle_filled, Colors.blue, isDark),
                _kpiCard('AVG PROGRESS', '0%', 'Completion Rate', Icons.trending_up, Colors.orange, isDark),
                _kpiCard('SCHEDULE STATUS', 'On Track', 'Deadlines Healthy', Icons.check_circle, Colors.green, isDark),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: InputDecoration(
                hintText: 'Search active courses...',
                prefixIcon: const Icon(Icons.search, size: 18),
                filled: true,
                fillColor: isDark ? AppColors.darkSecondarySurface : AppColors.lightInputBackground,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 16),
            Text('In-Progress Modules', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText)),
            const SizedBox(height: 2),
            Text('Showing 0 active training items', style: TextStyle(fontSize: 11.5, color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText)),
            const SizedBox(height: 12),
            AppCard(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Column(
                    children: const [
                      Icon(Icons.hourglass_empty, size: 40, color: Colors.grey),
                      SizedBox(height: 8),
                      Text('No in-progress training found', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      SizedBox(height: 4),
                      Text('You have finished all active modules or haven\'t started one yet.', style: TextStyle(fontSize: 12, color: Colors.grey), textAlign: TextAlign.center),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kpiCard(String label, String value, String sub, IconData icon, Color color, bool isDark) {
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
                const SizedBox(height: 2),
                Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText), overflow: TextOverflow.ellipsis),
                Text(sub, style: TextStyle(fontSize: 9.5, color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class TrainingCompletedScreen extends StatelessWidget {
  const TrainingCompletedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GlassScaffold(
      title: 'Completed Training',
      body: SingleChildScrollView(
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
                      Text('Completed Training', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText)),
                      const SizedBox(height: 2),
                      Text('View finished courses, scores, and downloadable certificates.', style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText)),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back, size: 16),
                  label: const Text('Back', style: TextStyle(fontSize: 11.5)),
                ),
              ],
            ),
            const SizedBox(height: 14),
            buildTrainingSubNav(context, 3),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.8,
              children: [
                _kpiCard('COMPLETED COURSES', '0', '100% Finished', Icons.check_circle, Colors.green, isDark),
                _kpiCard('CERTIFICATES', '0', 'Official Badges', Icons.workspace_premium, Colors.amber, isDark),
                _kpiCard('AVG ASSESSMENT', '100%', 'Score Standard', Icons.star, Colors.blue, isDark),
                _kpiCard('LEARNING TIME', '0 hrs', 'Total Invested', Icons.timer, Colors.purple, isDark),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: InputDecoration(
                hintText: 'Search completed courses...',
                prefixIcon: const Icon(Icons.search, size: 18),
                filled: true,
                fillColor: isDark ? AppColors.darkSecondarySurface : AppColors.lightInputBackground,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 16),
            Text('Completed Courses Archive', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText)),
            const SizedBox(height: 2),
            Text('Showing 0 completed items', style: TextStyle(fontSize: 11.5, color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText)),
            const SizedBox(height: 12),
            AppCard(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Column(
                    children: const [
                      Icon(Icons.emoji_events_outlined, size: 40, color: Colors.grey),
                      SizedBox(height: 8),
                      Text('No completed training courses found', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      SizedBox(height: 4),
                      Text('Keep progressing in active courses to earn certificates here.', style: TextStyle(fontSize: 12, color: Colors.grey), textAlign: TextAlign.center),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kpiCard(String label, String value, String sub, IconData icon, Color color, bool isDark) {
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
                const SizedBox(height: 2),
                Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText), overflow: TextOverflow.ellipsis),
                Text(sub, style: TextStyle(fontSize: 9.5, color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class MyCertificatesScreen extends ConsumerStatefulWidget {
  const MyCertificatesScreen({super.key});

  @override
  ConsumerState<MyCertificatesScreen> createState() => _MyCertificatesScreenState();
}

class _MyCertificatesScreenState extends ConsumerState<MyCertificatesScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;
  String _filter = 'All';
  String _query = '';
  List<Map<String, dynamic>> _certifications = [];

  @override
  void initState() {
    super.initState();
    _loadCertificates();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCertificates() async {
    setState(() => _isLoading = true);
    final trainingService = ref.read(trainingServiceProvider);
    try {
      final res = await trainingService.getCertificates().catchError((_) => null);
      if (mounted) {
        final list = res is List ? res : (res is Map && res['data'] is List ? res['data'] as List : []);

        final loadedList = <Map<String, dynamic>>[];
        for (final item in list) {
          if (item is Map) {
            final title = item['title']?.toString() ?? item['certificateTitle']?.toString() ?? item['courseTitle']?.toString() ?? 'Certificate of Completion';
            final issuer = item['issuer']?.toString() ?? item['issuedBy']?.toString() ?? 'ETAPRISE HRMS';
            final category = item['categoryName']?.toString() ?? item['category']?.toString() ?? 'Professional';
            final credentialId = item['certificateNumber']?.toString() ?? item['id']?.toString() ?? 'CERT-000';
            final status = item['status']?.toString().toUpperCase() ?? 'COMPLETED';

            loadedList.add({
              'title': title,
              'issuer': issuer,
              'category': category,
              'issued': 'Sept 12, 2026',
              'credentialId': credentialId,
              'status': status.contains('EXPIRE') ? 'Expired' : 'Completed',
              'description': 'Official verified completion certificate.',
            });
          }
        }

        setState(() {
          _certifications = loadedList;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _visibleCertifications {
    return _certifications.where((cert) {
      final matchesFilter = _filter == 'All' || (_filter == 'Completed' && cert['status'] == 'Completed') || (_filter == 'Expired' && cert['status'] == 'Expired');
      final q = _query.trim().toLowerCase();
      final matchesQuery = q.isEmpty ||
          cert['title'].toString().toLowerCase().contains(q) ||
          cert['issuer'].toString().toLowerCase().contains(q) ||
          cert['credentialId'].toString().toLowerCase().contains(q);
      return matchesFilter && matchesQuery;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GlassScaffold(
      title: 'Earned Certificates',
      body: _isLoading
          ? const ListSkeleton(itemCount: 3)
          : RefreshIndicator(
              onRefresh: _loadCertificates,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
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
                              Text('Earned Certificates', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText)),
                              const SizedBox(height: 2),
                              Text('Verify, download, and export official credentials and compliance badges.', style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText)),
                            ],
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back, size: 16),
                          label: const Text('Back', style: TextStyle(fontSize: 11.5)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    buildTrainingSubNav(context, 4),
                    const SizedBox(height: 16),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 1.8,
                      children: [
                        _kpiCard('TOTAL CERTIFICATES', '${_certifications.length}', 'Official Badges', Icons.workspace_premium, Colors.amber, isDark),
                        _kpiCard('ACTIVE BADGES', '${_certifications.where((c) => c['status'] == 'Completed').length}', 'Valid & Verified', Icons.verified, Colors.green, isDark),
                        _kpiCard('EXPIRING SOON', '0', 'Next 90 Days', Icons.timer, Colors.orange, isDark),
                        _kpiCard('COMPLIANCE LEVEL', '0%', 'ISO Verified', Icons.security, AppColors.primary, isDark),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _searchController,
                      onChanged: (val) => setState(() => _query = val),
                      decoration: InputDecoration(
                        hintText: 'Search certificates by title, issuer, or ID...',
                        prefixIcon: const Icon(Icons.search, size: 18),
                        filled: true,
                        fillColor: isDark ? AppColors.darkSecondarySurface : AppColors.lightInputBackground,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('My Credentials & Certificates', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText)),
                    const SizedBox(height: 2),
                    Text('Showing ${_visibleCertifications.length} issued certificates', style: TextStyle(fontSize: 11.5, color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText)),
                    const SizedBox(height: 12),

                    _visibleCertifications.isEmpty
                        ? AppCard(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Center(
                                child: Column(
                                  children: const [
                                    Icon(Icons.workspace_premium_outlined, size: 40, color: Colors.grey),
                                    SizedBox(height: 8),
                                    Text('No certificates found', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                    SizedBox(height: 4),
                                    Text('Complete courses with assessments to earn certificates here.', style: TextStyle(fontSize: 12, color: Colors.grey), textAlign: TextAlign.center),
                                  ],
                                ),
                              ),
                            ),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _visibleCertifications.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final cert = _visibleCertifications[index];

                              return AppCard(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(cert['title'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                        ),
                                        StatusChip(status: cert['status']?.toString().toUpperCase() ?? 'COMPLETED'),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text('Issuer: ${cert['issuer']} • ID: ${cert['credentialId']}', style: const TextStyle(fontSize: 12, color: AppColors.lightSecondaryText)),
                                    const SizedBox(height: 8),
                                    Text(cert['description'], style: const TextStyle(fontSize: 12, color: AppColors.lightSecondaryText)),
                                    const Divider(height: 20),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('Issued: ${cert['issued']}', style: const TextStyle(fontSize: 11, color: AppColors.lightMutedText)),
                                        IconButton(
                                          icon: const Icon(Icons.download, color: AppColors.primary, size: 20),
                                          onPressed: () {
                                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Downloading Certificate PDF...')));
                                          },
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
              ),
            ),
    );
  }

  Widget _kpiCard(String label, String value, String sub, IconData icon, Color color, bool isDark) {
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
                const SizedBox(height: 2),
                Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText), overflow: TextOverflow.ellipsis),
                Text(sub, style: TextStyle(fontSize: 9.5, color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class TrainingHistoryScreen extends StatelessWidget {
  const TrainingHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GlassScaffold(
      title: 'Training Activity History',
      body: SingleChildScrollView(
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
                      Text('Training Activity History', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText)),
                      const SizedBox(height: 2),
                      Text('Historical audit trail of course enrollments, completions, and compliance certifications.', style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText)),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back, size: 16),
                  label: const Text('Back', style: TextStyle(fontSize: 11.5)),
                ),
              ],
            ),
            const SizedBox(height: 14),
            buildTrainingSubNav(context, 5),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.8,
              children: [
                _kpiCard('AUDIT LOGS', '0', 'Total History Events', Icons.history, AppColors.primary, isDark),
                _kpiCard('COMPLETIONS', '0', 'Courses Finished', Icons.check_circle, Colors.green, isDark),
                _kpiCard('ENROLLMENTS', '0', 'Active & Pending', Icons.assignment, Colors.blue, isDark),
                _kpiCard('CERTIFICATES', '0', 'Credentials Issued', Icons.workspace_premium, Colors.amber, isDark),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: InputDecoration(
                hintText: 'Search history by course...',
                prefixIcon: const Icon(Icons.search, size: 18),
                filled: true,
                fillColor: isDark ? AppColors.darkSecondarySurface : AppColors.lightInputBackground,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 16),
            Text('Activity Audit Trail', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText)),
            const SizedBox(height: 2),
            Text('Showing 0 recorded logs', style: TextStyle(fontSize: 11.5, color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText)),
            const SizedBox(height: 12),
            AppCard(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Column(
                    children: const [
                      Icon(Icons.history_toggle_off, size: 40, color: Colors.grey),
                      SizedBox(height: 8),
                      Text('No training history logs found', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      SizedBox(height: 4),
                      Text('Activity history will automatically record as you complete modules.', style: TextStyle(fontSize: 12, color: Colors.grey), textAlign: TextAlign.center),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kpiCard(String label, String value, String sub, IconData icon, Color color, bool isDark) {
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
                const SizedBox(height: 2),
                Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText), overflow: TextOverflow.ellipsis),
                Text(sub, style: TextStyle(fontSize: 9.5, color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
