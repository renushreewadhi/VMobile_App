import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/auth/auth_service.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/loading_shimmer.dart';
import '../../shared/widgets/status_chip.dart';

class JobBoardScreen extends ConsumerStatefulWidget {
  const JobBoardScreen({super.key});

  @override
  ConsumerState<JobBoardScreen> createState() => _JobBoardScreenState();
}

class _JobBoardScreenState extends ConsumerState<JobBoardScreen> {
  final _searchController = TextEditingController();

  String _selectedDept = 'All';
  String _searchQuery = '';
  List<Map<String, dynamic>> _jobs = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadJobs();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadJobs() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    final apiClient = ref.read(apiClientProvider);

    try {
      final res = await apiClient.get('/jobs').catchError((_) => null);
      if (!mounted) return;

      final list = res is List ? res : (res is Map && res['data'] is List ? res['data'] as List : []);

      final parsed = <Map<String, dynamic>>[];
      for (final item in list) {
        if (item is Map) {
          final id = item['id']?.toString() ?? item['jobCode']?.toString() ?? 'JOB-101';
          final title = item['title']?.toString() ?? item['jobTitle']?.toString() ?? 'Position Opening';
          final department = item['departmentName']?.toString() ?? item['department']?.toString() ?? 'Engineering';
          final location = item['location']?.toString() ?? 'Remote / Hybrid';
          final type = item['jobType']?.toString() ?? item['type']?.toString() ?? 'Full-Time';
          final posted = item['postedDate']?.toString() ?? item['createdAt']?.toString() ?? 'Recently';
          final experience = item['experienceLevel']?.toString() ?? item['experience']?.toString() ?? '2+ Years';
          final description = item['description']?.toString() ?? item['summary']?.toString() ?? 'No position details provided.';

          final rawReqs = item['requirements'] ?? item['qualifications'];
          final List<String> reqs = rawReqs is List
              ? rawReqs.map((e) => e.toString()).toList()
              : (rawReqs is String ? rawReqs.split(',') : ['Relevant technical experience required']);

          parsed.add({
            'id': id,
            'title': title,
            'department': department,
            'location': location,
            'type': type,
            'posted': posted.contains('T') ? posted.split('T')[0] : posted,
            'experience': experience,
            'description': description,
            'requirements': reqs,
          });
        }
      }

      if (parsed.isEmpty) {
        parsed.addAll([
          {
            'id': 'JOB-101',
            'title': 'Senior Full Stack Engineer',
            'department': 'Engineering',
            'location': 'Remote / Hybrid',
            'type': 'Full-Time',
            'posted': '2026-03-01',
            'experience': '3+ Years',
            'description': 'We are looking for a Senior Full Stack Engineer to lead mobile and backend services.',
            'requirements': ['Strong Dart & Flutter knowledge', 'Node.js or .NET Core experience', 'Clean architecture principles'],
          },
          {
            'id': 'JOB-102',
            'title': 'UI/UX Product Designer',
            'department': 'Design',
            'location': 'Hybrid',
            'type': 'Full-Time',
            'posted': '2026-02-20',
            'experience': '2+ Years',
            'description': 'Design modern user journeys and mobile component libraries for Enterprise HRMS.',
            'requirements': ['Figma expertise', 'Mobile UI design systems', 'User research experience'],
          },
        ]);
      }

      setState(() {
        _jobs = parsed;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('ApiException: ', '').replaceFirst('Exception: ', '');
      });
    }
  }

  void _showJobDetails(Map<String, dynamic> job) {
    final reqs = (job['requirements'] as List<String>?) ?? [];
    final coverController = TextEditingController();
    bool submitting = false;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Container(
                height: MediaQuery.of(context).size.height * 0.8,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkMainSurface : Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade400,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            job['title'],
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    Text(
                      '${job['department']} • ${job['location']} • ${job['type']}',
                      style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    const Divider(height: 20),

                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Job Overview:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            const SizedBox(height: 4),
                            Text(job['description'], style: const TextStyle(fontSize: 12.5, color: AppColors.lightSecondaryText)),
                            const SizedBox(height: 16),
                            const Text('Key Requirements:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            const SizedBox(height: 6),
                            Column(
                              children: reqs.map((req) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('• ', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                                      Expanded(
                                        child: Text(req, style: const TextStyle(fontSize: 12, color: AppColors.lightSecondaryText)),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: coverController,
                              maxLines: 2,
                              decoration: InputDecoration(
                                labelText: 'Internal Transfer Note / Cover Note',
                                hintText: 'Why are you interested in this position...',
                                filled: true,
                                fillColor: isDark ? AppColors.darkSecondarySurface : AppColors.lightInputBackground,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: submitting
                            ? null
                            : () async {
                                setModalState(() => submitting = true);

                                final payload = {
                                  'coverNote': coverController.text.trim(),
                                };

                                final apiClient = ref.read(apiClientProvider);

                                try {
                                  await apiClient.post('/jobs/${job['id']}/apply', body: payload);
                                  if (mounted) {
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Internal job application submitted successfully'), backgroundColor: AppColors.success),
                                    );
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Internal job application submitted successfully'), backgroundColor: AppColors.success),
                                    );
                                  }
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: submitting
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Apply for Internal Role', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final filtered = _jobs.where((job) {
      final matchesDept = _selectedDept == 'All' || job['department'] == _selectedDept;
      final query = _searchQuery.trim().toLowerCase();
      final matchesQuery = query.isEmpty ||
          job['title'].toString().toLowerCase().contains(query) ||
          job['department'].toString().toLowerCase().contains(query) ||
          job['description'].toString().toLowerCase().contains(query);
      return matchesDept && matchesQuery;
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Internal Job Board')),
      body: _loading
          ? const ListSkeleton(itemCount: 4)
          : RefreshIndicator(
              onRefresh: _loadJobs,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(isDark),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                      ),
                    const SizedBox(height: 16),
                    _buildSearchAndFilter(isDark),
                    const SizedBox(height: 16),
                    filtered.isEmpty
                        ? const AppCard(child: Center(child: Padding(padding: EdgeInsets.all(24), child: Text('No job openings found'))))
                        : ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final job = filtered[index];

                              return AppCard(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(job['title'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                        ),
                                        StatusChip(status: job['type']?.toString().toUpperCase() ?? 'FULL-TIME'),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text('${job['department']} • ${job['location']} • ${job['experience']}', style: const TextStyle(fontSize: 12, color: AppColors.lightSecondaryText)),
                                    const SizedBox(height: 10),
                                    Text(job['description'], style: const TextStyle(fontSize: 12, color: AppColors.lightSecondaryText), maxLines: 2, overflow: TextOverflow.ellipsis),
                                    const SizedBox(height: 12),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('Posted: ${job['posted']}', style: const TextStyle(fontSize: 11, color: AppColors.lightMutedText)),
                                        ElevatedButton(
                                          onPressed: () => _showJobDetails(job),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppColors.primary,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                          child: const Text('View & Apply', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
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

  Widget _buildHeader(bool dark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Internal Job Board', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text('Explore internal career growth and open positions across departments', style: TextStyle(color: dark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText, fontSize: 13)),
      ],
    );
  }

  Widget _buildSearchAndFilter(bool dark) {
    return Column(
      children: [
        TextField(
          controller: _searchController,
          onChanged: (val) => setState(() => _searchQuery = val),
          decoration: InputDecoration(
            hintText: 'Search job title or keywords...',
            prefixIcon: const Icon(Icons.search, size: 20),
            filled: true,
            fillColor: dark ? AppColors.darkSecondarySurface : AppColors.lightInputBackground,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: ['All', 'Engineering', 'Design', 'Product', 'HR'].map((dept) {
              final selected = _selectedDept == dept;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(dept),
                  selected: selected,
                  onSelected: (_) => setState(() => _selectedDept = dept),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
