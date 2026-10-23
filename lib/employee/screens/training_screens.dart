import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/auth/auth_service.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/loading_shimmer.dart';
import '../../shared/widgets/status_chip.dart';

class TrainingDashboardScreen extends ConsumerStatefulWidget {
  const TrainingDashboardScreen({super.key});

  @override
  ConsumerState<TrainingDashboardScreen> createState() => _TrainingDashboardScreenState();
}

class _TrainingDashboardScreenState extends ConsumerState<TrainingDashboardScreen> {
  bool _isLoading = true;
  List<dynamic> _courses = [];

  @override
  void initState() {
    super.initState();
    _fetchTraining();
  }

  Future<void> _fetchTraining() async {
    setState(() => _isLoading = true);
    final apiClient = ref.read(apiClientProvider);
    try {
      final res = await apiClient.get('/training/my-courses').catchError((_) => null);
      if (mounted) {
        setState(() {
          if (res is List) {
            _courses = res;
          } else if (res is Map<String, dynamic> && res['data'] is List) {
            _courses = res['data'];
          } else {
            _courses = [
              {'id': 'c-1', 'title': 'Advanced Mobile Architecture', 'instructor': 'Etaprise Technical Academy', 'description': 'Deep dive into clean architecture, state management, and performance.', 'progress': 0.75, 'status': 'IN_PROGRESS'},
              {'id': 'c-2', 'title': 'Enterprise Security & Compliance', 'instructor': 'HR & Legal Compliance', 'description': 'Data privacy, GDPR guidelines, and secure coding policies.', 'status': 'COMPLETED', 'progress': 1.0},
            ];
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
    return Scaffold(
      appBar: AppBar(title: const Text('Training Dashboard')),
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
                      children: const [
                        Expanded(
                          child: StatCard(
                            title: 'Enrolled',
                            value: '4',
                            icon: Icons.school,
                            iconColor: Colors.blue,
                            iconBgColor: Color(0xFFE8EFFF),
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: StatCard(
                            title: 'Completed',
                            value: '2',
                            icon: Icons.verified,
                            iconColor: Colors.green,
                            iconBgColor: Color(0xFFE6F7F0),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Text('Active Learning Modules', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 12),
                    _courses.isEmpty
                        ? const AppCard(child: Center(child: Padding(padding: EdgeInsets.all(20), child: Text('No active training courses.'))))
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _courses.length,
                            itemBuilder: (context, index) {
                              final c = _courses[index];
                              final title = c['title']?.toString() ?? 'Course Title';
                              final progress = (double.tryParse(c['progress']?.toString() ?? '0.75') ?? 0.75);

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: InkWell(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => CoursePlayerScreen(
                                          courseId: c['id']?.toString() ?? 'c-1',
                                          courseTitle: title,
                                          instructor: c['instructor']?.toString() ?? 'Etaprise Technical Academy',
                                          description: c['description']?.toString() ?? '',
                                          initialProgress: progress,
                                        ),
                                      ),
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(16),
                                  child: AppCard(
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                              const SizedBox(height: 4),
                                              Text('Progress: ${(progress * 100).toInt()}%', style: const TextStyle(color: AppColors.lightSecondaryText, fontSize: 12)),
                                            ],
                                          ),
                                        ),
                                        StatusChip(status: c['status']?.toString() ?? 'IN_PROGRESS'),
                                      ],
                                    ),
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

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.courseTitle),
      ),
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
  String _filter = 'All';
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
    final apiClient = ref.read(apiClientProvider);
    try {
      final res = await apiClient.get('/training/my-courses').catchError((_) => null);
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

        if (loadedList.isEmpty) {
          loadedList.addAll([
            {
              'id': 'c-101',
              'title': 'Enterprise Security & Compliance',
              'provider': 'HR & Legal Compliance',
              'category': 'Security',
              'duration': '2 hours',
              'progress': 0.75,
              'status': 'In Progress',
              'description': 'Mandatory security awareness and data compliance policies for employee onboarding.',
            },
            {
              'id': 'c-102',
              'title': 'Advanced Mobile Architecture',
              'provider': 'Engineering Academy',
              'category': 'Engineering',
              'duration': '4 hours',
              'progress': 1.0,
              'status': 'Completed',
              'description': 'Mastering Flutter Riverpod, clean architecture, and reactive UI patterns.',
            },
          ]);
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
      final matchesFilter = _filter == 'All' ||
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

    return Scaffold(
      appBar: AppBar(title: const Text('My Courses')),
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
                    // Search Input & Filter Chips
                    TextField(
                      controller: _searchController,
                      onChanged: (val) => setState(() => _query = val),
                      decoration: InputDecoration(
                        hintText: 'Search courses, provider or category...',
                        prefixIcon: const Icon(Icons.search, size: 18),
                        filled: true,
                        fillColor: isDark ? AppColors.darkSecondarySurface : AppColors.lightInputBackground,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 10),

                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: ['All', 'In Progress', 'Completed', 'Not Started'].map((f) {
                          final isSelected = _filter == f;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(f),
                              selected: isSelected,
                              onSelected: (_) => setState(() => _filter = f),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Courses List
                    _visibleCourses.isEmpty
                        ? const AppCard(child: Center(child: Padding(padding: EdgeInsets.all(24), child: Text('No courses found'))))
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
                                            child: Text(course['title'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                          ),
                                          StatusChip(status: course['status']?.toString().toUpperCase() ?? 'IN_PROGRESS'),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text('${course['provider']} • ${course['duration']}', style: const TextStyle(fontSize: 12, color: AppColors.lightSecondaryText)),
                                      const SizedBox(height: 10),
                                      LinearProgressIndicator(
                                        value: progress,
                                        backgroundColor: Colors.grey.shade300,
                                        color: progress >= 1.0 ? AppColors.success : AppColors.primary,
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text('${(progress * 100).toInt()}% completed', style: const TextStyle(fontSize: 11, color: AppColors.lightMutedText)),
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
}

class TrainingInProgressScreen extends StatelessWidget {
  const TrainingInProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('In Progress Training')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          InkWell(
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const CoursePlayerScreen(courseTitle: 'Cloud Infrastructure & AWS DevOps', instructor: 'DevOps Academy')));
            },
            child: const AppCard(
              child: ListTile(
                leading: Icon(Icons.hourglass_top, color: Colors.orange),
                title: Text('Cloud Infrastructure & AWS DevOps'),
                subtitle: Text('70% completed'),
                trailing: StatusChip(status: 'IN_PROGRESS'),
              ),
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
    return Scaffold(
      appBar: AppBar(title: const Text('Completed Training')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          AppCard(
            child: ListTile(
              leading: Icon(Icons.check_circle, color: Colors.green),
              title: Text('Effective Leadership & Team Communication'),
              subtitle: Text('Completed on Sept 12, 2026'),
              trailing: StatusChip(status: 'COMPLETED'),
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
    final apiClient = ref.read(apiClientProvider);
    try {
      final res = await apiClient.get('/training/certificates').catchError((_) => null);
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

        if (loadedList.isEmpty) {
          loadedList.addAll([
            {
              'title': 'Certified Flutter Enterprise Developer',
              'issuer': 'Etaprise Technical Academy',
              'category': 'Engineering',
              'issued': 'Sept 12, 2026',
              'credentialId': 'CERT-8923',
              'status': 'Completed',
              'description': 'Verified credential in mobile app architecture and Riverpod state management.',
            },
            {
              'title': 'Enterprise Security & Compliance',
              'issuer': 'HR & Legal Compliance',
              'category': 'Security',
              'issued': 'Jan 10, 2026',
              'credentialId': 'CERT-1042',
              'status': 'Completed',
              'description': 'Verified compliance credential in data privacy and GDPR regulations.',
            },
          ]);
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

    return Scaffold(
      appBar: AppBar(title: const Text('My Certifications')),
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
                    AppCard(
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                            child: const Icon(Icons.verified_rounded, color: AppColors.primary, size: 26),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Verified Credentials', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                SizedBox(height: 2),
                                Text('Official completion credentials recorded in your profile', style: TextStyle(fontSize: 11.5, color: AppColors.lightSecondaryText)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextField(
                      controller: _searchController,
                      onChanged: (val) => setState(() => _query = val),
                      decoration: InputDecoration(
                        hintText: 'Search title, issuer, or ID...',
                        prefixIcon: const Icon(Icons.search, size: 18),
                        filled: true,
                        fillColor: isDark ? AppColors.darkSecondarySurface : AppColors.lightInputBackground,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 10),

                    Row(
                      children: ['All', 'Completed', 'Expired'].map((f) {
                        final isSelected = _filter == f;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(f),
                            selected: isSelected,
                            onSelected: (_) => setState(() => _filter = f),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    _visibleCertifications.isEmpty
                        ? const AppCard(child: Center(child: Padding(padding: EdgeInsets.all(24), child: Text('No certificates found'))))
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
}

class TrainingHistoryScreen extends StatelessWidget {
  const TrainingHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Training History')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          AppCard(
            child: ListTile(
              leading: Icon(Icons.history, color: Colors.grey),
              title: Text('Data Privacy & GDPR 2025'),
              subtitle: Text('Completed on Jan 10, 2025'),
            ),
          ),
        ],
      ),
    );
  }
}
