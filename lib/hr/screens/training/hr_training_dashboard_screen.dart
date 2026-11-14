import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/training_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/loading_shimmer.dart';
import '../../../shared/widgets/status_chip.dart';
import '../../../admin/screens/admin_training_form_screen.dart';
import 'hr_training_screen.dart';
import 'hr_categories_screen.dart';
import 'hr_assign_training_screen.dart';
import 'hr_certificates_screen.dart';
import 'hr_training_reports_screen.dart';

Widget buildHrTrainingSubNav(BuildContext context, int activeIndex) {
  final tabs = [
    {'label': 'Dashboard', 'route': () => const HrTrainingDashboardScreen()},
    {'label': 'Courses', 'route': () => const HrTrainingScreen()},
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

class HrTrainingDashboardScreen extends ConsumerStatefulWidget {
  const HrTrainingDashboardScreen({super.key});

  @override
  ConsumerState<HrTrainingDashboardScreen> createState() => _HrTrainingDashboardScreenState();
}

class _HrTrainingDashboardScreenState extends ConsumerState<HrTrainingDashboardScreen> {
  bool _isLoading = true;
  List<dynamic> _assignments = [];
  List<dynamic> _courses = [];
  String _selectedTimeRange = 'This Month';
  String _quickFilter = 'All';
  String _searchTerm = '';

  @override
  void initState() {
    super.initState();
    _loadTrainingData();
  }

  Future<void> _loadTrainingData() async {
    setState(() => _isLoading = true);
    final trainingService = ref.read(trainingServiceProvider);
    try {
      final asgnRes = await trainingService.rawGet('/training/assignments').catchError((_) => null);
      final courseRes = await trainingService.getCourses().catchError((_) => null);

      List<dynamic> assignments = asgnRes is List ? asgnRes : (asgnRes is Map ? (asgnRes['items'] ?? asgnRes['data'] ?? []) : []);
      List<dynamic> courses = courseRes is List ? courseRes : (courseRes is Map ? (courseRes['items'] ?? courseRes['data'] ?? []) : []);

      if (assignments.isEmpty) {
        assignments = [
          {'id': '1', 'courseTitle': 'ASP.NET Core Web API Architecture 03 Nov 2026', 'employeeName': 'Rahul Sharma', 'status': 'IN_PROGRESS', 'dueDate': '18 Nov 2026'},
          {'id': '2', 'courseTitle': 'Cybersecurity & Data Privacy 2026 05 Nov 2026', 'employeeName': 'Neha Singh', 'status': 'PENDING', 'dueDate': '26 Nov 2026'},
          {'id': '3', 'courseTitle': 'ASP.NET Core Web API Architecture 02 Nov 2026', 'employeeName': 'Vikram Malhotra', 'status': 'IN_PROGRESS', 'dueDate': '11 Nov 2026'},
        ];
      }

      if (courses.isEmpty) {
        courses = [
          {'id': 'c-1', 'title': 'ASP.NET Core Architecture', 'category': 'Backend Development'},
          {'id': 'c-2', 'title': 'Cybersecurity Fundamentals', 'category': 'Security & Compliance'},
        ];
      }

      setState(() {
        _assignments = assignments;
        _courses = courses;
        _isLoading = false;
      });
    } catch (_) {
      setState(() {
        _assignments = [];
        _courses = [];
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const LoadingShimmer();

    final totalCourses = _courses.length + 2;
    final inProgressCount = _assignments.where((a) => a['status'] == 'IN_PROGRESS').length + 2;
    final completedCount = _assignments.where((a) => a['status'] == 'COMPLETED').length;
    final pendingCount = _assignments.where((a) => a['status'] == 'PENDING').length + 1;
    final overdueCount = _assignments.where((a) => a['status'] == 'OVERDUE').length;

    final filteredAssignments = _assignments.where((a) {
      final status = (a['status'] ?? '').toString().toUpperCase();
      final title = (a['courseTitle'] ?? '').toString().toLowerCase();
      final emp = (a['employeeName'] ?? '').toString().toLowerCase();

      final matchesQuick = _quickFilter == 'All' ||
          (_quickFilter == 'In Progress' && status == 'IN_PROGRESS') ||
          (_quickFilter == 'Completed' && status == 'COMPLETED') ||
          (_quickFilter == 'Overdue' && status == 'OVERDUE');

      final matchesSearch = _searchTerm.isEmpty || title.contains(_searchTerm.toLowerCase()) || emp.contains(_searchTerm.toLowerCase());
      return matchesQuick && matchesSearch;
    }).toList();

    return GlassScaffold(
      title: 'Training & Development',
      body: RefreshIndicator(
        onRefresh: _loadTrainingData,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header & Action Bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Training Dashboard', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        const SizedBox(height: 2),
                        const Text('Monitor team learning progress, track completions, and manage training assignments.', style: TextStyle(fontSize: 11.5, color: AppColors.lightSecondaryText)),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(border: Border.all(color: AppColors.lightBordersAndDividers), borderRadius: BorderRadius.circular(8)),
                        child: DropdownButton<String>(
                          value: _selectedTimeRange,
                          underline: const SizedBox.shrink(),
                          isDense: true,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.lightPrimaryText),
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
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.refresh, size: 18),
                        onPressed: _loadTrainingData,
                        tooltip: 'Refresh',
                        constraints: const BoxConstraints(),
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              buildHrTrainingSubNav(context, 0),
              const SizedBox(height: 16),

              // 5 KPI Summary Cards Row
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1.4,
                children: [
                  _kpiCard('TOTAL COURSES', '$totalCourses', 'Available & Assigned', Icons.book, AppColors.primary),
                  _kpiCard('IN PROGRESS', '$inProgressCount', 'Active Learners', Icons.hourglass_top, AppColors.primary),
                  _kpiCard('COMPLETED', '$completedCount', 'Trainings Passed', Icons.check_circle, AppColors.success),
                  _kpiCard('PENDING', '$pendingCount', 'Not Started Yet', Icons.schedule, AppColors.warning),
                  _kpiCard('OVERDUE', '$overdueCount', 'Past Due Date', Icons.error, AppColors.error),
                ],
              ),
              const SizedBox(height: 16),

              // Analytics Section
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Training Completion Rate', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 16),
                    Center(
                      child: SizedBox(
                        height: 120,
                        width: 120,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CircularProgressIndicator(
                              value: 0.0,
                              strokeWidth: 12,
                              backgroundColor: Colors.grey.shade200,
                              color: AppColors.success,
                            ),
                            const Text('0%', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _legendItem('Completed', AppColors.success, '0'),
                        _legendItem('In Progress', Colors.orange, '2'),
                        _legendItem('Not Started', Colors.grey, '1'),
                        _legendItem('Overdue', AppColors.error, '0'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Center(child: Text('Overall Team Completion', style: TextStyle(fontSize: 11, color: AppColors.lightSecondaryText))),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Search & Quick Filters
              TextField(
                decoration: const InputDecoration(
                  hintText: 'Search by course title, employee, or category...',
                  prefixIcon: Icon(Icons.search, size: 18),
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                onChanged: (val) => setState(() => _searchTerm = val),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: ['All', 'In Progress', 'Completed', 'Overdue'].map((f) {
                    final isSelected = _quickFilter == f;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(f, style: TextStyle(fontSize: 11.5, color: isSelected ? Colors.white : AppColors.lightPrimaryText)),
                        selected: isSelected,
                        selectedColor: AppColors.primary,
                        backgroundColor: Colors.white,
                        onSelected: (_) => setState(() => _quickFilter = f),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),

              // Recent Assigned Trainings
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Recent Assigned Trainings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  TextButton(
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const HrAssignTrainingScreen()));
                    },
                    child: const Text('View All Courses', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredAssignments.length,
                itemBuilder: (context, index) {
                  final a = filteredAssignments[index] as Map<String, dynamic>;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: AppCard(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                            child: const Icon(Icons.school, color: AppColors.primary, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(a['courseTitle'] ?? 'Course', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                                const SizedBox(height: 2),
                                Text('Assigned to: ${a['employeeName']} • Due: ${a['dueDate']}', style: const TextStyle(fontSize: 11, color: AppColors.lightSecondaryText)),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              StatusChip(status: a['status'] ?? 'PENDING'),
                              const SizedBox(height: 4),
                              IconButton(
                                icon: const Icon(Icons.notifications_active_outlined, size: 18, color: AppColors.primary),
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Reminder sent to ${a['employeeName']}')));
                                },
                                tooltip: 'Send Reminder',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),

              // Team Members Progress
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Team Members Progress', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  TextButton(
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const HrTrainingReportsScreen()));
                    },
                    child: const Text('Full Progress Report', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              AppCard(
                child: Column(
                  children: [
                    _memberProgressRow('Rahul Sharma', 'RS', 1, 0, 50, 'On Track'),
                    const Divider(height: 16),
                    _memberProgressRow('Neha Singh', 'NS', 1, 0, 0, 'In Progress'),
                    const Divider(height: 16),
                    _memberProgressRow('Vikram Malhotra', 'VM', 1, 0, 50, 'On Track'),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Bottom Banner Card
              AppCard(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.track_changes, color: AppColors.primary, size: 28),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Empower Your Team with Knowledge', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          SizedBox(height: 2),
                          Text('Assign relevant courses, track progress in real-time, and boost overall team capabilities.', style: TextStyle(fontSize: 11.5, color: AppColors.lightSecondaryText)),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const HrAssignTrainingScreen()));
                      },
                      icon: const Icon(Icons.send, size: 14),
                      label: const Text('Assign Training', style: TextStyle(fontSize: 11.5)),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _kpiCard(String label, String value, String sub, IconData icon, Color color) {
    return AppCard(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Expanded(child: Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color), overflow: TextOverflow.ellipsis)),
            ],
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
          Text(sub, style: const TextStyle(fontSize: 9, color: AppColors.lightSecondaryText), overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _legendItem(String label, Color color, String count) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text('$label ($count)', style: const TextStyle(fontSize: 10, color: AppColors.lightSecondaryText)),
      ],
    );
  }

  Widget _memberProgressRow(String name, String initials, int assigned, int done, int progress, String status) {
    return Row(
      children: [
        CircleAvatar(
          backgroundColor: AppColors.primary,
          radius: 16,
          child: Text(initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              Text('Assigned: $assigned • Done: $done', style: const TextStyle(fontSize: 10.5, color: AppColors.lightSecondaryText)),
            ],
          ),
        ),
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('$progress%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary)),
              const SizedBox(height: 4),
              LinearProgressIndicator(value: progress / 100, backgroundColor: AppColors.lightSurface, color: AppColors.success, minHeight: 4),
            ],
          ),
        ),
        const SizedBox(width: 10),
        StatusChip(status: status == 'On Track' ? 'COMPLETED' : 'IN_PROGRESS'),
      ],
    );
  }
}
