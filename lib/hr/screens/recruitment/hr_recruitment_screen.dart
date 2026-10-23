import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/loading_shimmer.dart';
import 'hr_job_add_screen.dart';
import 'hr_candidate_add_screen.dart';
import 'hr_interview_schedule_screen.dart';

class HrRecruitmentScreen extends ConsumerStatefulWidget {
  const HrRecruitmentScreen({super.key});

  @override
  ConsumerState<HrRecruitmentScreen> createState() => _HrRecruitmentScreenState();
}

class _HrRecruitmentScreenState extends ConsumerState<HrRecruitmentScreen> {
  bool _isLoading = true;
  String _activeTab = 'openings';
  List<dynamic> _jobs = [];
  List<dynamic> _candidates = [];
  List<dynamic> _interviews = [];
  String _searchTerm = '';

  @override
  void initState() {
    super.initState();
    _loadRecruitmentData();
  }

  Future<void> _loadRecruitmentData() async {
    setState(() => _isLoading = true);
    final apiClient = ref.read(apiClientProvider);
    try {
      final jobRes = await apiClient.get('/recruitment/jobs').catchError((_) => null);
      final candRes = await apiClient.get('/recruitment/candidates').catchError((_) => null);
      final intRes = await apiClient.get('/recruitment/interviews').catchError((_) => null);

      List<dynamic> jobs = jobRes is List ? jobRes : (jobRes is Map ? (jobRes['items'] ?? jobRes['data'] ?? []) : []);
      List<dynamic> candidates = candRes is List ? candRes : (candRes is Map ? (candRes['items'] ?? candRes['data'] ?? []) : []);
      List<dynamic> interviews = intRes is List ? intRes : (intRes is Map ? (intRes['items'] ?? intRes['data'] ?? []) : []);

      if (jobs.isEmpty) {
        jobs = [
          {'id': 'JOB-101', 'title': 'Senior Full Stack Developer', 'departmentName': 'Engineering', 'location': 'Remote', 'status': 'OPEN', 'applicants': 14},
          {'id': 'JOB-102', 'title': 'UI/UX Product Designer', 'departmentName': 'Design', 'location': 'Mumbai', 'status': 'OPEN', 'applicants': 8},
        ];
      }

      setState(() {
        _jobs = jobs;
        _candidates = candidates;
        _interviews = interviews;
        _isLoading = false;
      });
    } catch (_) {
      setState(() {
        _jobs = [];
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const LoadingShimmer();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recruitment & Hiring'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              TextButton(onPressed: () => setState(() => _activeTab = 'openings'), child: Text('Job Openings', style: TextStyle(fontWeight: _activeTab == 'openings' ? FontWeight.bold : FontWeight.normal))),
              TextButton(onPressed: () => setState(() => _activeTab = 'candidates'), child: Text('Candidates', style: TextStyle(fontWeight: _activeTab == 'candidates' ? FontWeight.bold : FontWeight.normal))),
              TextButton(onPressed: () => setState(() => _activeTab = 'interviews'), child: Text('Interviews', style: TextStyle(fontWeight: _activeTab == 'interviews' ? FontWeight.bold : FontWeight.normal))),
            ],
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(
                labelText: 'Search recruitment data...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (val) => setState(() => _searchTerm = val),
            ),
            const SizedBox(height: 16),
            if (_activeTab == 'openings') ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton.icon(
                    onPressed: () async {
                      await Navigator.push(context, MaterialPageRoute(builder: (_) => const HrJobAddScreen()));
                      _loadRecruitmentData();
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Post Opening'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _jobs.length,
                itemBuilder: (context, index) {
                  final j = _jobs[index] as Map<String, dynamic>;
                  return AppCard(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(j['title'] ?? 'Job Opening', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('${j['departmentName'] ?? 'Engineering'} • ${j['location'] ?? 'Remote'} • ${j['applicants'] ?? 0} applicants'),
                      trailing: Chip(label: Text(j['status'] ?? 'OPEN')),
                    ),
                  );
                },
              ),
            ] else if (_activeTab == 'candidates') ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton.icon(
                    onPressed: () async {
                      await Navigator.push(context, MaterialPageRoute(builder: (_) => const HrCandidateAddScreen()));
                      _loadRecruitmentData();
                    },
                    icon: const Icon(Icons.person_add),
                    label: const Text('Add Candidate'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _candidates.length,
                itemBuilder: (context, index) {
                  final c = _candidates[index] as Map<String, dynamic>;
                  final name = '${c['firstName'] ?? ''} ${c['lastName'] ?? ''}'.trim();
                  return AppCard(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(name.isNotEmpty ? name : (c['name'] ?? 'Candidate'), style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('${c['jobTitle'] ?? 'Applicant'} • ${c['email'] ?? ''}'),
                      trailing: Chip(label: Text(c['status'] ?? 'NEW')),
                    ),
                  );
                },
              ),
            ] else ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton.icon(
                    onPressed: () async {
                      await Navigator.push(context, MaterialPageRoute(builder: (_) => const HrInterviewScheduleScreen()));
                      _loadRecruitmentData();
                    },
                    icon: const Icon(Icons.calendar_today),
                    label: const Text('Schedule Interview'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _interviews.length,
                itemBuilder: (context, index) {
                  final i = _interviews[index] as Map<String, dynamic>;
                  return AppCard(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(i['candidateName'] ?? 'Candidate', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('${i['jobTitle'] ?? ''} • Round: ${i['round'] ?? 'Screening'} • ${i['scheduledAt'] ?? ''}'),
                      trailing: Chip(label: Text(i['status'] ?? 'SCHEDULED')),
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
