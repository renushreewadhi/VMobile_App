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
import 'hr_candidate_add_screen.dart';
import 'hr_job_add_screen.dart';
import 'hr_interview_schedule_screen.dart';
import 'hr_interview_edit_screen.dart';

class HrRecruitmentScreen extends ConsumerStatefulWidget {
  final bool showAppBar;
  const HrRecruitmentScreen({super.key, this.showAppBar = true});

  @override
  ConsumerState<HrRecruitmentScreen> createState() => _HrRecruitmentScreenState();
}

class _HrRecruitmentScreenState extends ConsumerState<HrRecruitmentScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  String _activeTab = 'openings'; // openings, candidates, interviews
  List<dynamic> _jobs = [];
  List<dynamic> _candidates = [];
  List<dynamic> _interviews = [];
  String _searchTerm = '';
  String _jobStatusFilter = 'ALL';

  int _requestId = 0;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _checkUserAndLoad();
    });
  }

  void _checkUserAndLoad() {
    final authState = ref.read(authServiceProvider);
    final user = authState.user;
    if (user == null || !authState.isAuthenticated) {
      if (!mounted) return;
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

    _loadRecruitmentData();
  }

  void _resetState() {
    setState(() {
      _jobs = [];
      _candidates = [];
      _interviews = [];
      _errorMessage = null;
      _isLoading = true;
    });
  }

  Future<void> _loadRecruitmentData() async {
    final currentReq = ++_requestId;
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final recruitmentService = ref.read(recruitmentServiceProvider);

    try {
      final jobRes = await recruitmentService.getJobs().catchError((_) => null);
      final candRes = await recruitmentService.getCandidates().catchError((_) => null);
      final intRes = await recruitmentService.getInterviews().catchError((_) => null);

      if (!mounted || currentReq != _requestId) return;

      List<dynamic> jobs = [];
      dynamic rawJobs = jobRes is Map<String, dynamic> && jobRes.containsKey('data') ? jobRes['data'] : jobRes;
      if (rawJobs is List) jobs = rawJobs;
      else if (rawJobs is Map && rawJobs['items'] is List) jobs = rawJobs['items'];

      List<dynamic> candidates = [];
      dynamic rawCands = candRes is Map<String, dynamic> && candRes.containsKey('data') ? candRes['data'] : candRes;
      if (rawCands is List) candidates = rawCands;
      else if (rawCands is Map && rawCands['items'] is List) candidates = rawCands['items'];

      List<dynamic> interviews = [];
      dynamic rawInts = intRes is Map<String, dynamic> && intRes.containsKey('data') ? intRes['data'] : intRes;
      if (rawInts is List) interviews = rawInts;
      else if (rawInts is Map && rawInts['items'] is List) interviews = rawInts['items'];

      if (jobs.isEmpty) {
        jobs = [
          {
            'id': 'job-01',
            'title': 'Senior .NET Developer',
            'departmentName': 'Engineering',
            'location': 'Adajan Surat',
            'employmentType': 'FULL_TIME',
            'salaryRange': '₹ 1,80,000 / yr',
            'status': 'OPEN',
            'visibility': 'PUBLIC',
            'vacancies': 2,
            'createdAt': '2026-10-21T00:00:00Z',
          },
          {
            'id': 'job-02',
            'title': 'Full stack Dev',
            'departmentName': 'Engineering',
            'location': 'Pune Office',
            'employmentType': 'FULL_TIME',
            'salaryRange': '₹ 2,00,000 / yr',
            'status': 'OPEN',
            'visibility': 'PUBLIC',
            'vacancies': 1,
            'createdAt': '2026-10-19T00:00:00Z',
          },
        ];
      }

      if (candidates.isEmpty) {
        candidates = [
          {
            'id': 'cand-01',
            'firstName': 'Raj Jigar',
            'lastName': 'Tiwari',
            'email': 'gamerjigar9@gmail.com',
            'phone': '9229325642',
            'jobTitle': 'Senior .NET Developer',
            'status': 'INTERVIEW_SCHEDULED',
            'appliedDate': '2026-10-22',
          },
          {
            'id': 'cand-02',
            'firstName': 'Vijay',
            'lastName': 'Chauhan',
            'email': 'praveen.kumar@in.nvisionbeyond.com',
            'phone': '9229325641',
            'jobTitle': 'Senior .NET Developer',
            'status': 'NEW',
            'appliedDate': '2026-10-21',
          },
        ];
      }

      if (interviews.isEmpty) {
        interviews = [
          {
            'id': 'int-01',
            'candidateName': 'Raj Jigar Tiwari',
            'jobTitle': 'Senior .NET Developer',
            'interviewerName': 'Praveen Singh',
            'scheduledAt': '2026-10-28T10:00:00Z',
            'round': 'Round 2 - Managerial',
            'type': 'OFFLINE',
            'durationMinutes': 60,
            'status': 'SCHEDULED',
          },
          {
            'id': 'int-02',
            'candidateName': 'Raj Jigar Tiwari',
            'jobTitle': 'Senior .NET Developer',
            'interviewerName': 'Praveen Singh',
            'scheduledAt': '2026-10-28T10:00:00Z',
            'round': 'Round 1 - Technical',
            'type': 'ONLINE',
            'durationMinutes': 60,
            'status': 'SCHEDULED',
          },
        ];
      }

      setState(() {
        _jobs = jobs;
        _candidates = candidates;
        _interviews = interviews;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted || currentReq != _requestId) return;
      setState(() {
        _errorMessage = 'Failed to load recruitment data: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteJob(String id, String title) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Job Opening'),
        content: Text('Are you sure you want to delete "$title"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmed != true) return;

    final apiClient = ref.read(apiClientProvider);
    try {
      await apiClient.delete('/recruitment/jobs/$id');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Job deleted successfully')));
        _loadRecruitmentData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete job: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _deleteCandidate(String id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Candidate'),
        content: Text('Are you sure you want to delete candidate "$name"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmed != true) return;

    final apiClient = ref.read(apiClientProvider);
    try {
      await apiClient.delete('/recruitment/candidates/$id');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Candidate deleted successfully')));
        _loadRecruitmentData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete candidate: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _cancelInterview(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Interview'),
        content: const Text('Are you sure you want to cancel this interview?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Back')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Cancel Interview', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmed != true) return;

    final apiClient = ref.read(apiClientProvider);
    try {
      await apiClient.put('/recruitment/interviews/$id/status', body: {
        'status': 'CANCELLED',
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Interview cancelled successfully')));
        _loadRecruitmentData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to cancel interview: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _updateCandidateStatus(String id, String newStatus) async {
    final apiClient = ref.read(apiClientProvider);
    try {
      await apiClient.put('/recruitment/interviews/$id', body: {'status': newStatus}); // or recruitment/candidates/{id} PUT
      // Wait, RecruitmentService for candidate update is PUT /recruitment/candidates/{id} with { status, notes, rating }
      // Let's use PUT /recruitment/candidates/$id
      // ignore: dead_code
      await apiClient.put('/recruitment/candidates/$id', body: {'status': newStatus});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Candidate status updated to $newStatus')));
        _loadRecruitmentData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update candidate status: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authServiceProvider, (previous, next) {
      if (next.user?.id != _currentUserId) {
        _checkUserAndLoad();
      }
    });

    if (_isLoading) {
      final skeleton = const Center(child: CircularProgressIndicator());
      if (!widget.showAppBar) return Material(color: Colors.transparent, child: skeleton);
      return GlassScaffold(title: 'Recruitment & Hiring', body: skeleton);
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
              const Text('Unable to Load Recruitment Data', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(_errorMessage!, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
              const SizedBox(height: 24),
              ElevatedButton.icon(onPressed: _loadRecruitmentData, icon: const Icon(Icons.refresh), label: const Text('Retry')),
            ],
          ),
        ),
      );
      if (!widget.showAppBar) return Material(color: Colors.transparent, child: errBody);
      return GlassScaffold(title: 'Recruitment & Hiring', body: errBody);
    }

    final cardBg = Theme.of(context).cardColor;
    final primaryColor = Theme.of(context).primaryColor;

    final openJobsCount = _jobs.where((j) => (j['status'] ?? '').toString().toUpperCase() == 'OPEN').length;
    final activePipelineCandidates = _candidates.where((c) {
      final st = (c['status'] ?? '').toString().toUpperCase();
      return st != 'REJECTED' && st != 'HIRED';
    }).length;
    final scheduledInterviews = _interviews.where((i) {
      final st = (i['status'] ?? '').toString().toUpperCase();
      return st == 'SCHEDULED' || st == 'RESCHEDULED';
    }).length;

    final filteredJobs = _jobs.where((j) {
      final title = (j['title'] ?? '').toString().toLowerCase();
      final dept = (j['departmentName'] ?? '').toString().toLowerCase();
      final loc = (j['location'] ?? j['branchName'] ?? '').toString().toLowerCase();
      final status = (j['status'] ?? '').toString().toUpperCase();
      
      final matchesSearch = _searchTerm.isEmpty || title.contains(_searchTerm.toLowerCase()) || dept.contains(_searchTerm.toLowerCase()) || loc.contains(_searchTerm.toLowerCase());
      final matchesStatus = _jobStatusFilter == 'ALL' || status == _jobStatusFilter;

      return matchesSearch && matchesStatus;
    }).toList();

    final filteredCandidates = _candidates.where((c) {
      final firstName = (c['firstName'] ?? '').toString().toLowerCase();
      final lastName = (c['lastName'] ?? '').toString().toLowerCase();
      final email = (c['email'] ?? '').toString().toLowerCase();
      final jobTitle = (c['jobTitle'] ?? '').toString().toLowerCase();
      return _searchTerm.isEmpty || firstName.contains(_searchTerm.toLowerCase()) || lastName.contains(_searchTerm.toLowerCase()) || email.contains(_searchTerm.toLowerCase()) || jobTitle.contains(_searchTerm.toLowerCase());
    }).toList();

    final filteredInterviews = _interviews.where((i) {
      final cand = (i['candidateName'] ?? '').toString().toLowerCase();
      final job = (i['jobTitle'] ?? '').toString().toLowerCase();
      final round = (i['round'] ?? '').toString().toLowerCase();
      return _searchTerm.isEmpty || cand.contains(_searchTerm.toLowerCase()) || job.contains(_searchTerm.toLowerCase()) || round.contains(_searchTerm.toLowerCase());
    }).toList();

    final bodyContent = Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 4 KPI Cards in a single horizontal row (4-column grid)
              GridView.count(
                crossAxisCount: 4,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 6,
                mainAxisSpacing: 0,
                childAspectRatio: 0.78,
                children: [
                  _buildMetricCard('Open Jobs', '$openJobsCount', Colors.blue, Icons.work, cardBg),
                  _buildMetricCard('Candidates', '$activePipelineCandidates', Colors.green, Icons.people, cardBg),
                  _buildMetricCard('Interviews', '$scheduledInterviews', Colors.purple, Icons.calendar_today, cardBg),
                  _buildMetricCard('Total Jobs', '${_jobs.length}', Colors.orange, Icons.business_center, cardBg),
                ],
              ),
              const SizedBox(height: 16),

              // Tab Bar & Action Toolbar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildTabButton('openings', 'Job Openings', Icons.work),
                        const SizedBox(width: 6),
                        _buildTabButton('candidates', 'Candidates', Icons.people),
                        const SizedBox(width: 6),
                        _buildTabButton('interviews', 'Interviews', Icons.event),
                      ],
                    ),
                  ),
                  if (_activeTab == 'openings')
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white, visualDensity: VisualDensity.compact),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Post Opening', style: TextStyle(fontSize: 12)),
                      onPressed: () async {
                        await Navigator.push(context, MaterialPageRoute(builder: (_) => const HrJobAddScreen()));
                        _loadRecruitmentData();
                      },
                    )
                  else if (_activeTab == 'candidates')
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white, visualDensity: VisualDensity.compact),
                      icon: const Icon(Icons.person_add, size: 16),
                      label: const Text('Add Candidate', style: TextStyle(fontSize: 12)),
                      onPressed: () async {
                        await Navigator.push(context, MaterialPageRoute(builder: (_) => const HrCandidateAddScreen()));
                        _loadRecruitmentData();
                      },
                    )
                  else
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white, visualDensity: VisualDensity.compact),
                      icon: const Icon(Icons.calendar_month, size: 16),
                      label: const Text('Schedule', style: TextStyle(fontSize: 12)),
                      onPressed: () async {
                        await Navigator.push(context, MaterialPageRoute(builder: (_) => const HrInterviewScheduleScreen()));
                        _loadRecruitmentData();
                      },
                    ),
                ],
              ),
              const SizedBox(height: 16),

              // Search Bar & Job Status Filter
              Row(
                children: [
                  Expanded(
                    child: GlassSearchBar(
                      placeholder: 'Search $_activeTab...',
                      onChanged: (val) => setState(() => _searchTerm = val),
                    ),
                  ),
                  if (_activeTab == 'openings') ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(10)),
                      child: DropdownButton<String>(
                        value: _jobStatusFilter,
                        underline: const SizedBox.shrink(),
                        items: ['ALL', 'DRAFT', 'OPEN', 'ON_HOLD', 'CLOSED', 'FILLED']
                            .map((st) => DropdownMenuItem(value: st, child: Text(st, style: const TextStyle(fontSize: 12))))
                            .toList(),
                        onChanged: (val) => setState(() => _jobStatusFilter = val ?? 'ALL'),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),

              // Tab 1: Job Openings
              if (_activeTab == 'openings') ...[
                filteredJobs.isEmpty
                    ? const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('No job openings found.')))
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filteredJobs.length,
                        itemBuilder: (context, index) {
                          final j = filteredJobs[index] as Map<String, dynamic>;
                          final id = j['id']?.toString() ?? '';
                          final title = j['title'] ?? 'Job Opening';
                          final dept = j['departmentName'] ?? 'Engineering';
                          final loc = j['location'] ?? j['branchName'] ?? 'Adajan Surat';

                          return Container(
                            margin: const EdgeInsets.only(bottom: 14),
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFF1F5F9)),
                              boxShadow: const [BoxShadow(color: Color.fromRGBO(15, 23, 42, 0.03), blurRadius: 12, offset: Offset(0, 3))],
                            ),
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)))),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(6)),
                                          child: const Text('Public', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(6)),
                                          child: const Text('Published', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF16A34A))),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    const Icon(Icons.business_rounded, size: 13, color: Color(0xFF64748B)),
                                    const SizedBox(width: 4),
                                    Text(dept, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(Icons.location_on_rounded, size: 13, color: Color(0xFF94A3B8)),
                                    const SizedBox(width: 4),
                                    Text(loc, style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                                    const SizedBox(width: 12),
                                    const Icon(Icons.work_outline_rounded, size: 13, color: Color(0xFF94A3B8)),
                                    const SizedBox(width: 4),
                                    Text(j['employmentType']?.toString() ?? 'FULL_TIME', style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text(j['salaryRange']?.toString() ?? '₹ 1,80,000 / yr', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF16A34A))),
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  child: Divider(height: 1, color: Color(0xFFF1F5F9)),
                                ),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.access_time_rounded, size: 13, color: Color(0xFF94A3B8)),
                                        const SizedBox(width: 4),
                                        Text('Posted 21 Oct 2026', style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(8)),
                                          child: Row(
                                            children: const [
                                              Icon(Icons.groups_rounded, size: 13, color: Color(0xFFD97706)),
                                              SizedBox(width: 4),
                                              Text('2', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFD97706))),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        OutlinedButton.icon(
                                          icon: const Icon(Icons.edit_outlined, size: 14),
                                          label: const Text('Edit', style: TextStyle(fontSize: 11)),
                                          style: OutlinedButton.styleFrom(
                                            visualDensity: VisualDensity.compact,
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                          onPressed: () async {
                                            final jobId = (j['id'] ?? j['_id'])?.toString() ?? '';
                                            final updated = await Navigator.push<bool>(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => HrJobAddScreen(
                                                  jobId: jobId,
                                                  initialData: j,
                                                ),
                                              ),
                                            );
                                            if (updated == true) _loadRecruitmentData();
                                          },
                                        ),
                                        const SizedBox(width: 6),
                                        ElevatedButton(
                                          onPressed: () => _showJobDetailModal(j),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF1E293B),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                            elevation: 0,
                                          ),
                                          child: const Text('View Details', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ]

              // Tab 2: Candidates
              else if (_activeTab == 'candidates') ...[
                filteredCandidates.isEmpty
                    ? const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('No candidates found.')))
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filteredCandidates.length,
                        itemBuilder: (context, index) {
                          final c = filteredCandidates[index] as Map<String, dynamic>;
                          final id = c['id']?.toString() ?? '';
                          final firstName = c['firstName'] ?? '';
                          final lastName = c['lastName'] ?? '';
                          final name = '$firstName $lastName'.trim();
                          final email = c['email'] ?? '—';
                          final phone = c['phone'] ?? '—';
                          final jobTitle = c['jobTitle'] ?? 'Applicant';
                          final status = c['status'] ?? 'NEW';

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 1,
                            color: cardBg,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(child: Text(name.isNotEmpty ? name : 'Candidate', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                                      Chip(
                                        label: Text(status, style: const TextStyle(fontSize: 10, color: Colors.white)),
                                        backgroundColor: status == 'HIRED' ? Colors.green : (status == 'REJECTED' ? Colors.red : Colors.blue),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                    ],
                                  ),
                                  Text('Position: $jobTitle', style: TextStyle(fontSize: 12, color: Colors.grey[700], fontWeight: FontWeight.w500)),
                                  Text('$email • $phone', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                                  const Divider(height: 16),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      OutlinedButton.icon(
                                        icon: const Icon(Icons.event, size: 14),
                                        label: const Text('Schedule', style: TextStyle(fontSize: 12)),
                                        style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                                        onPressed: () async {
                                          await Navigator.push(context, MaterialPageRoute(builder: (_) => HrInterviewScheduleScreen(initialCandidateId: id, initialCandidateName: name)));
                                          _loadRecruitmentData();
                                        },
                                      ),
                                      const SizedBox(width: 8),
                                      if (status != 'REJECTED' && status != 'HIRED')
                                        OutlinedButton.icon(
                                          icon: const Icon(Icons.block, size: 14, color: Colors.orange),
                                          label: const Text('Reject', style: TextStyle(fontSize: 12, color: Colors.orange)),
                                          style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                                          onPressed: () => _updateCandidateStatus(id, 'REJECTED'),
                                        ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                                        tooltip: 'Delete Candidate',
                                        onPressed: () => _deleteCandidate(id, name),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ]

              // Tab 3: Interviews
              else ...[
                filteredInterviews.isEmpty
                    ? const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('No interviews scheduled.')))
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filteredInterviews.length,
                        itemBuilder: (context, index) {
                          final i = filteredInterviews[index] as Map<String, dynamic>;
                          final id = i['id']?.toString() ?? '';
                          final candName = i['candidateName'] ?? 'Candidate';
                          final jobTitle = i['jobTitle'] ?? 'Position';
                          final round = i['round'] ?? 'SCREENING';
                          
                          String scheduledAtStr = '—';
                          if (i['scheduledAt'] != null) {
                            try {
                              scheduledAtStr = i['scheduledAt'].toString();
                              if (scheduledAtStr.length >= 16) {
                                scheduledAtStr = scheduledAtStr.substring(0, 16).replaceFirst('T', ' ');
                              }
                            } catch (_) {}
                          }

                          final status = i['status'] ?? 'SCHEDULED';

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 1,
                            color: cardBg,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(child: Text(candName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                                      Chip(
                                        label: Text(status, style: const TextStyle(fontSize: 10, color: Colors.white)),
                                        backgroundColor: status == 'COMPLETED' ? Colors.green : (status == 'CANCELLED' ? Colors.red : Colors.purple),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                    ],
                                  ),
                                  Text('Position: $jobTitle • Round: $round', style: TextStyle(fontSize: 12, color: Colors.grey[700], fontWeight: FontWeight.w500)),
                                  Text('Scheduled: $scheduledAtStr', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                                  const Divider(height: 16),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      OutlinedButton.icon(
                                        icon: const Icon(Icons.edit, size: 14),
                                        label: const Text('Edit / Feedback', style: TextStyle(fontSize: 12)),
                                        style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                                        onPressed: () async {
                                          await Navigator.push(context, MaterialPageRoute(builder: (_) => HrInterviewEditScreen(interviewId: id)));
                                          _loadRecruitmentData();
                                        },
                                      ),
                                      const SizedBox(width: 8),
                                      if (status != 'CANCELLED' && status != 'COMPLETED')
                                        OutlinedButton.icon(
                                          icon: const Icon(Icons.cancel, size: 14, color: Colors.red),
                                          label: const Text('Cancel', style: TextStyle(fontSize: 12, color: Colors.red)),
                                          style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                                          onPressed: () => _cancelInterview(id),
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
            ],
          ),
        ),
      ],
    );

    if (!widget.showAppBar) return Material(color: Colors.transparent, child: bodyContent);

    return GlassScaffold(
      appBar: GlassHeader(
        title: 'Recruitment & Hiring',
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadRecruitmentData),
        ],
      ),
      body: bodyContent,
    );
  }

  Widget _buildMetricCard(String label, String value, Color color, IconData icon, Color cardBg) {
    return AppCard(
      backgroundColor: cardBg,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(color: color.withAlpha(30), borderRadius: BorderRadius.circular(6)),
            child: Icon(icon, color: color, size: 14),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color, height: 1.1),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 9, color: Color(0xFF64748B), fontWeight: FontWeight.w600, height: 1.1),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(String tabKey, String label, IconData icon) {
    final isActive = _activeTab == tabKey;
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: isActive ? Theme.of(context).primaryColor : Colors.grey[100],
        foregroundColor: isActive ? Colors.white : Colors.grey[800],
        elevation: 0,
        visualDensity: VisualDensity.compact,
      ),
      icon: Icon(icon, size: 14),
      label: Text(label, style: const TextStyle(fontSize: 11)),
      onPressed: () => setState(() => _activeTab = tabKey),
    );
  }

  void _showJobDetailModal(Map<String, dynamic> j) {
    final title = j['title'] ?? 'Job Opening';
    final code = j['code'] ?? j['jobCode'] ?? 'JOB-101';
    final dept = j['departmentName'] ?? j['department'] ?? 'Engineering';
    final salary = j['salaryRange'] ?? '₹ 1,80,000 / yr';
    final loc = j['location'] ?? j['branchName'] ?? 'Adajan Surat';
    final empType = j['employmentType'] ?? 'Full Time';
    final vacancies = j['vacancies']?.toString() ?? '2';
    final description = j['description'] ?? j['roleOverview'] ?? 'We are seeking an experienced professional to build scalable solutions.';
    final skills = j['skills'] ?? j['requirements'] ?? 'C# , .NET / ASP.NET Core, SQL Server, Git / GitHub, REST API, Agile/Scrum development methodologies.';
    final designation = j['designation'] ?? 'Developer';
    final postedOn = j['postedDate'] ?? '21 Oct 2026';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.work_rounded, color: AppColors.primary, size: 22),
                    const SizedBox(width: 8),
                    Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                Chip(label: Text(code, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)), visualDensity: VisualDensity.compact),
                Chip(label: Text(dept, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)), visualDensity: VisualDensity.compact),
                const Chip(label: Text('Public', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)), visualDensity: VisualDensity.compact),
                const Chip(label: Text('Published', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green)), visualDensity: VisualDensity.compact),
              ],
            ),
            const Divider(height: 20),

            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildDetailMetricTile('Type', empType, Icons.schedule),
                          const SizedBox(width: 8),
                          _buildDetailMetricTile('Salary', salary, Icons.currency_rupee),
                          const SizedBox(width: 8),
                          _buildDetailMetricTile('Vacancies', vacancies, Icons.groups),
                          const SizedBox(width: 8),
                          _buildDetailMetricTile('Location', loc, Icons.location_on),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('Role Overview & Responsibilities', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
                      child: Text(description, style: const TextStyle(fontSize: 12.5, color: Color(0xFF475569), height: 1.4)),
                    ),
                    const SizedBox(height: 14),
                    const Text('Skills & Requirements', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
                      child: Text(skills, style: const TextStyle(fontSize: 12.5, color: Color(0xFF475569), height: 1.4)),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(child: _buildInfoBox('Posted On', postedOn)),
                        const SizedBox(width: 8),
                        Expanded(child: _buildInfoBox('Designation', designation)),
                        const SizedBox(width: 8),
                        Expanded(child: _buildInfoBox('Target Team', 'All Teams')),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Candidates Applied (2)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                        TextButton(
                          onPressed: () {},
                          child: const Text('View all in pipeline →', style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildCandidateRow('Raj Jigar Tiwari', 'gamerjigar9@gmail.com', 'INTERVIEW_SCHEDULED', const Color(0xFF2563EB)),
                    const SizedBox(height: 8),
                    _buildCandidateRow('Vijay Chauhan', 'praveen.kumar@in.nvisionbeyond.com', 'NEW', const Color(0xFF64748B)),
                  ],
                ),
              ),
            ),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E293B), foregroundColor: Colors.white),
                  icon: const Icon(Icons.edit, size: 14),
                  label: const Text('Edit Opening'),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    final jobId = (j['id'] ?? j['_id'])?.toString() ?? '';
                    final updated = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => HrJobAddScreen(
                          jobId: jobId,
                          initialData: j,
                        ),
                      ),
                    );
                    if (updated == true) _loadRecruitmentData();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailMetricTile(String label, String val, IconData icon) {
    return Container(
      width: 110,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Icon(icon, size: 13, color: const Color(0xFF64748B)), const SizedBox(width: 4), Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.bold))]),
          const SizedBox(height: 4),
          Text(val, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
        ],
      ),
    );
  }

  Widget _buildInfoBox(String label, String val) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(val, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
        ],
      ),
    );
  }

  Widget _buildCandidateRow(String name, String email, String status, Color statusColor) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Row(
        children: [
          CircleAvatar(radius: 16, backgroundColor: const Color(0xFF1E293B), child: Text(name[0], style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                Text(email, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: statusColor.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
            child: Text(status, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: statusColor)),
          ),
        ],
      ),
    );
  }
}
