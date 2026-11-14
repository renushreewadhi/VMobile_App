import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/recruitment_service.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/glass_header.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../core/widgets/glass_search_bar.dart';
import '../../../shared/widgets/app_card.dart';
import 'hr_onboarding_add_screen.dart';
import 'hr_onboarding_detail_screen.dart';
import 'hr_onboarding_edit_screen.dart';

class HrOnboardingScreen extends ConsumerStatefulWidget {
  final bool showAppBar;
  const HrOnboardingScreen({super.key, this.showAppBar = true});

  @override
  ConsumerState<HrOnboardingScreen> createState() => _HrOnboardingScreenState();
}

class _HrOnboardingScreenState extends ConsumerState<HrOnboardingScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<dynamic> _onboardings = [];
  String _searchTerm = '';
  String _deptFilter = 'ALL';
  String _statusFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    _loadOnboardings();
  }

  Future<void> _loadOnboardings() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final recruitmentService = ref.read(recruitmentServiceProvider);

    try {
      final res = await recruitmentService.getOnboardingList().catchError((_) => null);
      if (!mounted) return;

      List<dynamic> items = [];
      dynamic rawItems = res is Map<String, dynamic> && res.containsKey('data') ? res['data'] : res;
      if (rawItems is List) {
        items = rawItems;
      } else if (rawItems is Map && rawItems['items'] is List) {
        items = rawItems['items'];
      }

      // No fallback mock data needed, matching website 0 records when unseeded

      setState(() {
        _onboardings = items;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to load onboarding candidates: $e';
        _isLoading = false;
      });
    }
  }

  int get _inProgressCount => _onboardings.where((o) => (o['status'] ?? '').toString().toLowerCase().contains('progress')).length;
  int get _completedCount => _onboardings.where((o) => (o['status'] ?? '').toString().toLowerCase().contains('completed')).length;
  int get _upcomingCount => _onboardings.where((o) => (o['status'] ?? '').toString().toLowerCase().contains('upcoming')).length;
  
  double get _avgCompletion {
    if (_onboardings.isEmpty) return 0.0;
    final total = _onboardings.fold<double>(0.0, (acc, o) => acc + (double.tryParse(o['progress']?.toString() ?? '0') ?? 0.0));
    return total / _onboardings.length;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      final skeleton = const Center(child: CircularProgressIndicator());
      if (!widget.showAppBar) return Material(color: Colors.transparent, child: skeleton);
      return GlassScaffold(title: 'Onboarding Management', body: skeleton);
    }

    if (_errorMessage != null) {
      final errBody = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, size: 54, color: Colors.red),
              const SizedBox(height: 16),
              const Text('Unable to Load Onboarding Candidates', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(_errorMessage!, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
              const SizedBox(height: 24),
              ElevatedButton.icon(onPressed: _loadOnboardings, icon: const Icon(Icons.refresh), label: const Text('Retry')),
            ],
          ),
        ),
      );
      if (!widget.showAppBar) return Material(color: Colors.transparent, child: errBody);
      return GlassScaffold(title: 'Onboarding Management', body: errBody);
    }

    final filtered = _onboardings.where((o) {
      final map = o is Map<String, dynamic> ? o : {};
      final name = (map['employeeName'] ?? map['name'] ?? '').toString().toLowerCase();
      final pos = (map['position'] ?? '').toString().toLowerCase();
      final dept = (map['department'] ?? '').toString().toLowerCase();
      final mentor = (map['mentorName'] ?? map['mentor'] ?? '').toString().toLowerCase();
      final status = (map['status'] ?? 'In Progress').toString().toLowerCase();

      final matchesSearch = _searchTerm.isEmpty ||
          name.contains(_searchTerm.toLowerCase()) ||
          pos.contains(_searchTerm.toLowerCase()) ||
          dept.contains(_searchTerm.toLowerCase()) ||
          mentor.contains(_searchTerm.toLowerCase());

      final matchesDept = _deptFilter == 'ALL' || dept == _deptFilter.toLowerCase();
      final matchesStatus = _statusFilter == 'ALL' || status.contains(_statusFilter.toLowerCase());

      return matchesSearch && matchesDept && matchesStatus;
    }).toList();

    final cardBg = Theme.of(context).cardColor;

    final bodyContent = SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Dynamic KPI Cards
          Row(
            children: [
              Expanded(child: _buildKpiCard('IN PROGRESS', '$_inProgressCount', 'Active joiners', Icons.hourglass_top, const Color(0xFFD97706), const Color(0xFFFEFCE8), cardBg)),
              const SizedBox(width: 8),
              Expanded(child: _buildKpiCard('COMPLETED', '$_completedCount', 'Finished setup', Icons.check_circle, const Color(0xFF10B981), const Color(0xFFF0FDF4), cardBg)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildKpiCard('UPCOMING', '$_upcomingCount', 'Scheduled', Icons.upcoming, const Color(0xFF2563EB), const Color(0xFFF5F3FF), cardBg)),
              const SizedBox(width: 8),
              Expanded(child: _buildKpiCard('AVG COMPLETION', '${_avgCompletion.toStringAsFixed(0)}%', 'Task rate', Icons.analytics, const Color(0xFF8B5CF6), const Color(0xFFFAF5FF), cardBg)),
            ],
          ),
          const SizedBox(height: 16),

          // Search & Filter Toolbar
          GlassSearchBar(
            placeholder: 'Search candidate, position, department, mentor...',
            onChanged: (val) => setState(() => _searchTerm = val),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _deptFilter,
                  decoration: InputDecoration(labelText: 'Department', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                  items: ['ALL', 'Engineering', 'Marketing', 'Sales', 'Design', 'Finance', 'Human Resources']
                      .map((d) => DropdownMenuItem(value: d, child: Text(d, style: const TextStyle(fontSize: 12))))
                      .toList(),
                  onChanged: (val) => setState(() => _deptFilter = val ?? 'ALL'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _statusFilter,
                  decoration: InputDecoration(labelText: 'Status', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                  items: ['ALL', 'In Progress', 'Completed', 'Upcoming']
                      .map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 12))))
                      .toList(),
                  onChanged: (val) => setState(() => _statusFilter = val ?? 'ALL'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Candidate List
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Onboarding Candidates', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, visualDensity: VisualDensity.compact),
                icon: const Icon(Icons.person_add, size: 16),
                label: const Text('New Candidate'),
                onPressed: () async {
                  await Navigator.push(context, MaterialPageRoute(builder: (_) => const HrOnboardingAddScreen()));
                  _loadOnboardings();
                },
              ),
            ],
          ),
          const SizedBox(height: 12),

          filtered.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: Text('No onboarding candidates found matching filter criteria.')),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final o = filtered[index] as Map<String, dynamic>;
                    final name = o['employeeName'] ?? o['name'] ?? 'Candidate';
                    final pos = o['position'] ?? 'Position';
                    final dept = o['department'] ?? 'General';
                    final mentor = o['mentorName'] ?? o['mentor'] ?? 'Unassigned';
                    final status = o['status'] ?? 'In Progress';
                    final progress = double.tryParse(o['progress']?.toString() ?? '0') ?? 0.0;
                    final joinDate = o['startDate'] != null ? o['startDate'].toString().substring(0, 10) : '—';
                    final id = o['id']?.toString() ?? '';

                    return AppCard(
                      backgroundColor: cardBg,
                      margin: const EdgeInsets.only(bottom: 12),
                      child: InkWell(
                        onTap: () async {
                          await Navigator.push(context, MaterialPageRoute(builder: (_) => HrOnboardingDetailScreen(candidateId: id)));
                          _loadOnboardings();
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          backgroundColor: AppColors.primary.withAlpha(30),
                                          child: Text(name.isNotEmpty ? name[0] : 'C', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), overflow: TextOverflow.ellipsis),
                                              Text('$pos • $dept', style: TextStyle(fontSize: 12, color: Colors.grey[600]), overflow: TextOverflow.ellipsis),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Chip(
                                    label: Text(status, style: const TextStyle(fontSize: 10, color: Colors.white)),
                                    backgroundColor: status.toLowerCase().contains('complete') ? Colors.green : Colors.orange,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Joining: $joinDate', style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                                  Text('Mentor: $mentor', style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(value: progress / 100, minHeight: 6, backgroundColor: Colors.grey[200], valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary)),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text('${progress.toStringAsFixed(0)}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              const Divider(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  OutlinedButton.icon(
                                    icon: const Icon(Icons.edit, size: 14),
                                    label: const Text('Edit', style: TextStyle(fontSize: 12)),
                                    style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                                    onPressed: () async {
                                      await Navigator.push(context, MaterialPageRoute(builder: (_) => HrOnboardingEditScreen(candidateId: id)));
                                      _loadOnboardings();
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ],
      ),
    );

    if (!widget.showAppBar) return Material(color: Colors.transparent, child: bodyContent);

    return GlassScaffold(
      appBar: GlassHeader(
        title: 'Onboarding Management',
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadOnboardings,
          ),
        ],
      ),
      body: bodyContent,
    );
  }

  Widget _buildKpiCard(String title, String value, String subtext, IconData icon, Color color, Color bgColor, Color cardBg) {
    return AppCard(
      backgroundColor: cardBg,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 10, color: Colors.grey[600], fontWeight: FontWeight.bold)),
                  Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
                  Text(subtext, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
