import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/auth/auth_service.dart';
import '../../core/errors/api_exception.dart';
import '../../core/models/user_model.dart';
import '../../core/theme/glass_theme.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/glass_header.dart';
import 'admin_candidate_add_screen.dart';
import 'admin_candidate_detail_screen.dart';
import 'admin_candidate_edit_screen.dart';
import 'admin_job_add_screen.dart';
import 'admin_schedule_interview_screen.dart';

class AdminRecruitmentScreen extends ConsumerStatefulWidget {
  final bool? showAppBar;
  const AdminRecruitmentScreen({super.key, this.showAppBar = true});

  @override
  ConsumerState<AdminRecruitmentScreen> createState() => _AdminRecruitmentScreenState();
}

class _AdminRecruitmentScreenState extends ConsumerState<AdminRecruitmentScreen> {
  bool get _showAppBar => widget.showAppBar ?? true;
  bool _isLoading = true;
  String? _errorMessage;
  String _activeTab = 'openings'; // 'openings', 'candidates', 'interviews'

  List<dynamic> _jobs = [];
  List<dynamic> _candidates = [];
  List<dynamic> _interviews = [];

  String _searchTerm = '';
  String _jobStatusFilter = 'ALL'; // ALL, DRAFT, OPEN, ON_HOLD, CLOSED

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

    _loadRecruitmentData();
  }

  void _resetState() {
    _jobs = [];
    _candidates = [];
    _interviews = [];
    _searchTerm = '';
    _jobStatusFilter = 'ALL';
    _activeTab = 'openings';
  }

  Future<void> _loadRecruitmentData() async {
    final currentReq = ++_requestId;
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final apiClient = ref.read(apiClientProvider);

    List<dynamic> jobsList = [];
    List<dynamic> candList = [];
    List<dynamic> intList = [];

    try {
      final jobRes = await apiClient.get(ApiEndpoints.jobs).catchError((_) => null);
      if (!mounted || currentReq != _requestId) return;

      final candRes = await apiClient.get(ApiEndpoints.candidates).catchError((_) => null);
      if (!mounted || currentReq != _requestId) return;

      final intRes = await apiClient.get(ApiEndpoints.interviews).catchError((_) => null);
      if (!mounted || currentReq != _requestId) return;

      if (jobRes != null) {
        if (jobRes is List) {
          jobsList = jobRes;
        } else if (jobRes is Map<String, dynamic>) {
          if (jobRes['data'] is List) jobsList = jobRes['data'];
          else if (jobRes['items'] is List) jobsList = jobRes['items'];
          else if (jobRes['jobs'] is List) jobsList = jobRes['jobs'];
        }
      }

      if (candRes != null) {
        if (candRes is List) {
          candList = candRes;
        } else if (candRes is Map<String, dynamic>) {
          if (candRes['data'] is List) candList = candRes['data'];
          else if (candRes['items'] is List) candList = candRes['items'];
          else if (candRes['candidates'] is List) candList = candRes['candidates'];
        }
      }

      if (intRes != null) {
        if (intRes is List) {
          intList = intRes;
        } else if (intRes is Map<String, dynamic>) {
          if (intRes['data'] is List) intList = intRes['data'];
          else if (intRes['items'] is List) intList = intRes['items'];
          else if (intRes['interviews'] is List) intList = intRes['interviews'];
        }
      }
    } catch (_) {}

    if (!mounted || currentReq != _requestId) return;
    setState(() {
      _jobs = jobsList;
      _candidates = candList;
      _interviews = intList;
      _isLoading = false;
      _errorMessage = null;
    });
  }

  List<dynamic> get _filteredJobs {
    return _jobs.where((j) {
      final title = (j['title'] ?? j['jobTitle'] ?? '').toString().toLowerCase();
      final dept = (j['departmentName'] ?? j['department'] ?? '').toString().toLowerCase();
      final loc = (j['location'] ?? j['branch'] ?? '').toString().toLowerCase();
      final status = (j['status'] ?? 'OPEN').toString().toUpperCase();

      final matchesSearch = _searchTerm.trim().isEmpty ||
          title.contains(_searchTerm.toLowerCase()) ||
          dept.contains(_searchTerm.toLowerCase()) ||
          loc.contains(_searchTerm.toLowerCase());

      final matchesStatus = _jobStatusFilter == 'ALL' || status == _jobStatusFilter;

      return matchesSearch && matchesStatus;
    }).toList();
  }

  List<dynamic> get _filteredCandidates {
    return _candidates.where((c) {
      final name = (c['fullName'] ?? '${c['firstName'] ?? ''} ${c['lastName'] ?? ''}').toString().toLowerCase();
      final email = (c['email'] ?? '').toString().toLowerCase();
      final pos = (c['jobTitle'] ?? c['position'] ?? '').toString().toLowerCase();

      return _searchTerm.trim().isEmpty ||
          name.contains(_searchTerm.toLowerCase()) ||
          email.contains(_searchTerm.toLowerCase()) ||
          pos.contains(_searchTerm.toLowerCase());
    }).toList();
  }

  List<dynamic> get _filteredInterviews {
    return _interviews.where((i) {
      final name = (i['candidateName'] ?? i['candidate']?['name'] ?? '').toString().toLowerCase();
      final title = (i['jobTitle'] ?? i['round'] ?? '').toString().toLowerCase();

      return _searchTerm.trim().isEmpty ||
          name.contains(_searchTerm.toLowerCase()) ||
          title.contains(_searchTerm.toLowerCase());
    }).toList();
  }

  int get _openJobsCount => _jobs.where((j) => (j['status'] ?? 'OPEN').toString().toUpperCase() == 'OPEN').length;
  int get _totalApplicantsCount => _candidates.length;
  int get _scheduledInterviewsCount => _interviews.where((i) => (i['status'] ?? 'SCHEDULED').toString().toUpperCase() == 'SCHEDULED').length;
  int get _offersExtendedCount => _candidates.where((c) => (c['status'] ?? '').toString().toUpperCase() == 'OFFER_EXTENDED').length;

  Future<void> _rejectCandidate(Map<String, dynamic> candidate) async {
    final candId = (candidate['id'] ?? candidate['_id'])?.toString();
    final name = candidate['fullName'] ?? '${candidate['firstName'] ?? ''} ${candidate['lastName'] ?? ''}'.trim();

    if (candId == null || candId.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Reject candidate "$name"?'),
        content: const Text('This will set the candidate status to REJECTED.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final currentReq = ++_requestId;
    final apiClient = ref.read(apiClientProvider);

    try {
      await apiClient.put(ApiEndpoints.candidateDetail(candId), body: {
        'status': 'REJECTED',
      });
      if (!mounted || currentReq != _requestId) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Candidate rejected successfully')),
      );
      _loadRecruitmentData();
    } catch (e) {
      if (!mounted || currentReq != _requestId) return;
      final msg = e is ApiException ? e.message : 'Failed to reject candidate.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red),
      );
    }
  }

  void _showJobDetailsModal(Map<String, dynamic> j) {
    final title = j['title'] ?? 'Job Opening';
    final jobCode = j['jobCode'] ?? j['code'] ?? 'JOB-101';
    final dept = j['departmentName'] ?? j['department'] ?? 'Engineering';
    final type = j['employmentType'] ?? 'FULL_TIME';
    final salary = j['salaryRange'] ?? 'Competitive';
    final vacancies = j['vacancies'] ?? '1 Position';
    final location = j['location'] ?? 'Remote';
    final postedOn = j['postedOn'] ?? j['postedDate'] ?? '21 Oct 2026';
    final deadline = j['deadline'] ?? 'Open until filled';
    final designation = j['designation'] ?? 'Developer';
    final team = j['team'] ?? 'All Teams';
    final description = j['description'] ?? j['jobDescription'] ?? 'No description provided.';
    final requirements = j['requirements'] ?? j['skills'] ?? 'No requirements specified.';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  const Icon(Icons.work_rounded, color: Color(0xFF2563EB), size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        Row(
                          children: [
                            Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4)), child: Text(jobCode, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold))),
                            const SizedBox(width: 4),
                            Text('$dept • Public', style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () => Navigator.pop(ctx)),
          ],
        ),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.9,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _infoPill(Icons.schedule, 'Type', type),
                    _infoPill(Icons.currency_rupee, 'Salary', salary),
                    _infoPill(Icons.people, 'Vacancies', vacancies.toString()),
                    _infoPill(Icons.location_on, 'Location', location),
                  ],
                ),
                const SizedBox(height: 14),

                const Text('Role Overview & Responsibilities', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                const SizedBox(height: 4),
                Text(description, style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569), height: 1.35)),
                const SizedBox(height: 14),

                const Text('Skills & Requirements', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                const SizedBox(height: 4),
                Text(requirements, style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569), height: 1.35)),
                const SizedBox(height: 14),

                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE2E8F0))),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: _metaCol('Posted On', postedOn)),
                          Expanded(child: _metaCol('Deadline', deadline)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(child: _metaCol('Designation', designation)),
                          Expanded(child: _metaCol('Target Team', team)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                const Text('Candidates Applied (2)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                const SizedBox(height: 8),
                _candidateAppliedTile('Raj Jigar Tiwari', 'INTERVIEW_SCHEDULED', 'gamerjigar9@gmail.com • 9229325642'),
                const SizedBox(height: 6),
                _candidateAppliedTile('Vijay Chauhan', 'NEW', 'praveen.kumar@in.nvisionbeyond.com • 9229325641'),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close', style: TextStyle(color: Color(0xFF64748B)))),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F6B66), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            icon: const Icon(Icons.edit, size: 14),
            label: const Text('Edit Opening', style: TextStyle(fontSize: 12)),
            onPressed: () async {
              Navigator.pop(ctx);
              final jobId = (j['id'] ?? j['_id'])?.toString() ?? '';
              final updated = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) => AdminJobAddScreen(
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
    );
  }

  Widget _infoPill(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: const Color(0xFF2563EB)),
          const SizedBox(width: 4),
          Text('$label: $value', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
        ],
      ),
    );
  }

  Widget _metaCol(String label, String val) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 9.5, color: Color(0xFF94A3B8))),
        const SizedBox(height: 2),
        Text(val, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
      ],
    );
  }

  Widget _candidateAppliedTile(String name, String status, String sub) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                const SizedBox(height: 2),
                Text(sub, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: status == 'INTERVIEW_SCHEDULED' ? Colors.purple.withAlpha(30) : Colors.blue.withAlpha(30), borderRadius: BorderRadius.circular(6)),
            child: Text(status, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: status == 'INTERVIEW_SCHEDULED' ? Colors.purple : Colors.blue)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBgColor = isDark ? const Color(0xFF141D2E) : Colors.white;

    // Account switching listener
    ref.listen<AuthState>(authServiceProvider, (previous, next) {
      if (next.user?.id != _currentUserId) {
        _checkUserAndLoad();
      }
    });

    final authState = ref.watch(authServiceProvider);
    final userRole = authState.user?.role;
    final bool isAuthorized = userRole == UserRole.ADMIN || userRole == UserRole.HR;

    final mainContent = !isAuthorized
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
                    Text('You do not have administrative permissions to view recruitment pipelines.', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: glass.textSecondary)),
                  ],
                ),
              ),
            ),
          )
        : RefreshIndicator(
            onRefresh: _loadRecruitmentData,
            child: _buildMainContent(glass, cardBgColor),
          );

    if (!_showAppBar) return mainContent;

    return GlassScaffold(
      appBar: GlassHeader(
        title: 'Recruitment & Hiring',
        actions: [
          if (isAuthorized) ...[
            IconButton(
              icon: const Icon(Icons.person_add_alt_1_rounded, size: 20),
              tooltip: 'Add Candidate',
              onPressed: () async {
                final created = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminCandidateAddScreen()),
                );
                if (created == true) _loadRecruitmentData();
              },
            ),
            IconButton(
              icon: const Icon(Icons.work_history_outlined, size: 20),
              tooltip: 'Post New Opening',
              onPressed: () async {
                final created = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminJobAddScreen()),
                );
                if (created == true) _loadRecruitmentData();
              },
            ),
          ],
        ],
      ),
      body: mainContent,
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
              Text('Unable to Load Recruitment Data', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: glass.textPrimary)),
              const SizedBox(height: 8),
              Text(_errorMessage!, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: glass.textSecondary)),
              const SizedBox(height: 24),
              AppButton(label: 'Retry', icon: Icons.refresh_rounded, width: 140, onPressed: _loadRecruitmentData),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // KPI Metric Summary Cards Row (4 Cards)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                SizedBox(width: 120, child: _buildStatTile(glass, cardBgColor, label: 'Openings', value: '$_openJobsCount', icon: Icons.work_outline_rounded, iconColor: const Color(0xFF2563EB))),
                const SizedBox(width: 8),
                SizedBox(width: 120, child: _buildStatTile(glass, cardBgColor, label: 'Applicants', value: '$_totalApplicantsCount', icon: Icons.groups_rounded, iconColor: const Color(0xFF10B981))),
                const SizedBox(width: 8),
                SizedBox(width: 120, child: _buildStatTile(glass, cardBgColor, label: 'Interviews', value: '$_scheduledInterviewsCount', icon: Icons.event_available_rounded, iconColor: const Color(0xFF8B5CF6))),
                const SizedBox(width: 8),
                SizedBox(width: 120, child: _buildStatTile(glass, cardBgColor, label: 'Offers', value: '$_offersExtendedCount', icon: Icons.verified_rounded, iconColor: const Color(0xFFF59E0B))),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Tabs Row
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: _activeTab == 'openings' ? const Color(0xFF0F6B66) : Colors.transparent,
                    foregroundColor: _activeTab == 'openings' ? Colors.white : glass.textPrimary,
                    side: BorderSide(color: _activeTab == 'openings' ? const Color(0xFF0F6B66) : glass.cardBorder),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => setState(() => _activeTab = 'openings'),
                  child: Text('Job Openings (${_jobs.length})', style: const TextStyle(fontSize: 11.5)),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: _activeTab == 'candidates' ? const Color(0xFF0F6B66) : Colors.transparent,
                    foregroundColor: _activeTab == 'candidates' ? Colors.white : glass.textPrimary,
                    side: BorderSide(color: _activeTab == 'candidates' ? const Color(0xFF0F6B66) : glass.cardBorder),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => setState(() => _activeTab = 'candidates'),
                  child: Text('Candidates (${_candidates.length})', style: const TextStyle(fontSize: 11.5)),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: _activeTab == 'interviews' ? const Color(0xFF0F6B66) : Colors.transparent,
                    foregroundColor: _activeTab == 'interviews' ? Colors.white : glass.textPrimary,
                    side: BorderSide(color: _activeTab == 'interviews' ? const Color(0xFF0F6B66) : glass.cardBorder),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => setState(() => _activeTab = 'interviews'),
                  child: Text('Interviews (${_interviews.length})', style: const TextStyle(fontSize: 11.5)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Search and Filters Bar
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: _activeTab == 'openings' ? 'Search job title, dept, location...' : 'Search candidates or interviews...',
                    hintStyle: TextStyle(color: glass.textSecondary, fontSize: 12),
                    prefixIcon: Icon(Icons.search_rounded, color: glass.textSecondary, size: 18),
                    filled: true,
                    fillColor: cardBgColor,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: glass.cardBorder)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: glass.cardBorder)),
                  ),
                  style: TextStyle(color: glass.textPrimary, fontSize: 13),
                  onChanged: (val) => setState(() => _searchTerm = val),
                ),
              ),
              if (_activeTab == 'openings') ...[
                const SizedBox(width: 6),
                DropdownButton<String>(
                  value: _jobStatusFilter,
                  underline: const SizedBox.shrink(),
                  items: const [
                    DropdownMenuItem(value: 'ALL', child: Text('All Status', style: TextStyle(fontSize: 11))),
                    DropdownMenuItem(value: 'OPEN', child: Text('Open', style: TextStyle(fontSize: 11))),
                    DropdownMenuItem(value: 'DRAFT', child: Text('Draft', style: TextStyle(fontSize: 11))),
                    DropdownMenuItem(value: 'CLOSED', child: Text('Closed', style: TextStyle(fontSize: 11))),
                  ],
                  onChanged: (val) => setState(() => _jobStatusFilter = val ?? 'ALL'),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),

          // Feed Lists
          if (_activeTab == 'openings') ...[
            if (_filteredJobs.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 48),
                alignment: Alignment.center,
                child: Text('No job openings found.', style: TextStyle(color: glass.textSecondary)),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _filteredJobs.length,
                itemBuilder: (context, index) {
                  final j = _filteredJobs[index];
                  final status = (j['status'] ?? 'OPEN').toString().toUpperCase();

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
                              child: Text(j['title'] ?? 'Job Title', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: glass.textPrimary)),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: status == 'OPEN' ? const Color(0xFF10B981).withAlpha(30) : Colors.grey.withAlpha(30),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                status == 'OPEN' ? 'PUBLISHED' : status,
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: status == 'OPEN' ? const Color(0xFF10B981) : Colors.grey),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text('${j['departmentName'] ?? 'Engineering'} • ${j['location'] ?? 'Remote'} • ${j['employmentType'] ?? 'FULL_TIME'}', style: TextStyle(fontSize: 12, color: glass.textSecondary)),
                        const SizedBox(height: 4),
                        Text('Salary: ${j['salaryRange'] ?? 'Competitive'} • Posted: ${j['postedDate'] ?? '21 Oct 2026'}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF16A34A))),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            OutlinedButton.icon(
                              icon: const Icon(Icons.edit_outlined, size: 14),
                              label: const Text('Edit', style: TextStyle(fontSize: 11)),
                              style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                              onPressed: () async {
                                final jobId = (j['id'] ?? j['_id'])?.toString() ?? '';
                                final updated = await Navigator.push<bool>(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => AdminJobAddScreen(
                                      jobId: jobId,
                                      initialData: j,
                                    ),
                                  ),
                                );
                                if (updated == true) _loadRecruitmentData();
                              },
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              icon: const Icon(Icons.remove_red_eye_outlined, size: 14),
                              label: const Text('View Details', style: TextStyle(fontSize: 11)),
                              style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                              onPressed: () => _showJobDetailsModal(j),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
          ] else if (_activeTab == 'candidates') ...[
            if (_filteredCandidates.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 48),
                alignment: Alignment.center,
                child: Text('No candidates found.', style: TextStyle(color: glass.textSecondary)),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _filteredCandidates.length,
                itemBuilder: (context, index) {
                  final c = _filteredCandidates[index];
                  final name = c['fullName'] ?? '${c['firstName'] ?? ''} ${c['lastName'] ?? ''}'.trim();
                  final candId = (c['id'] ?? c['_id'])?.toString() ?? '';
                  final status = (c['status'] ?? 'NEW').toString().toUpperCase();

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
                              child: Text(name.isNotEmpty ? name : 'Candidate', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: glass.textPrimary)),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: status == 'HIRED' ? const Color(0xFF10B981).withAlpha(30) : (status == 'REJECTED' ? const Color(0xFFEF4444).withAlpha(30) : const Color(0xFF2563EB).withAlpha(30)),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                status,
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: status == 'HIRED' ? const Color(0xFF10B981) : (status == 'REJECTED' ? const Color(0xFFEF4444) : const Color(0xFF2563EB))),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text('${c['jobTitle'] ?? 'Applicant'} • ${c['email'] ?? ''}', style: TextStyle(fontSize: 12, color: glass.textSecondary)),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          alignment: WrapAlignment.end,
                          children: [
                            OutlinedButton.icon(
                              icon: const Icon(Icons.remove_red_eye_outlined, size: 14),
                              label: const Text('View', style: TextStyle(fontSize: 11)),
                              style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                              onPressed: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => AdminCandidateDetailScreen(candidateId: candId)),
                                );
                                _loadRecruitmentData();
                              },
                            ),
                            OutlinedButton.icon(
                              icon: const Icon(Icons.edit_outlined, size: 14),
                              label: const Text('Edit', style: TextStyle(fontSize: 11)),
                              style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                              onPressed: () async {
                                final updated = await Navigator.push<bool>(
                                  context,
                                  MaterialPageRoute(builder: (_) => AdminCandidateEditScreen(candidateId: candId, initialData: c)),
                                );
                                if (updated == true) _loadRecruitmentData();
                              },
                            ),
                            OutlinedButton.icon(
                              icon: const Icon(Icons.event_outlined, size: 14),
                              label: const Text('Schedule', style: TextStyle(fontSize: 11)),
                              style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                              onPressed: () async {
                                final scheduled = await Navigator.push<bool>(
                                  context,
                                  MaterialPageRoute(builder: (_) => AdminScheduleInterviewScreen(candidateId: candId)),
                                );
                                if (scheduled == true) _loadRecruitmentData();
                              },
                            ),
                            OutlinedButton.icon(
                              icon: const Icon(Icons.cancel_outlined, size: 14, color: Colors.red),
                              label: const Text('Reject', style: TextStyle(fontSize: 11, color: Colors.red)),
                              style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                              onPressed: () => _rejectCandidate(c),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
          ] else ...[
            if (_filteredInterviews.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 48),
                alignment: Alignment.center,
                child: Text('No scheduled interviews found.', style: TextStyle(color: glass.textSecondary)),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _filteredInterviews.length,
                itemBuilder: (context, index) {
                  final i = _filteredInterviews[index];
                  final candName = i['candidateName'] ?? i['candidate']?['name'] ?? 'Candidate';

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
                            Text(candName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: glass.textPrimary)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: const Color(0xFF8B5CF6).withAlpha(30), borderRadius: BorderRadius.circular(8)),
                              child: Text(i['status']?.toString().toUpperCase() ?? 'SCHEDULED', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF8B5CF6))),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text('${i['round'] ?? 'Round 1'} • Mode: ${i['interviewMode'] ?? 'ONLINE'}', style: TextStyle(fontSize: 12, color: glass.textSecondary)),
                        Text('Scheduled: ${i['scheduledAt'] ?? 'Upcoming'}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: glass.textPrimary)),
                      ],
                    ),
                  );
                },
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatTile(
    GlassTheme glass,
    Color cardBgColor, {
    required String label,
    required String value,
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
              Expanded(child: Text(label, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10, color: glass.textSecondary, fontWeight: FontWeight.w600))),
            ],
          ),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: glass.textPrimary)),
        ],
      ),
    );
  }
}
