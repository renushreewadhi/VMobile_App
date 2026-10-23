import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import 'admin_onboarding_form_screen.dart';
import 'admin_onboarding_detail_screen.dart';

class AdminOnboardingScreen extends ConsumerStatefulWidget {
  const AdminOnboardingScreen({super.key});

  @override
  ConsumerState<AdminOnboardingScreen> createState() => _AdminOnboardingScreenState();
}

class _AdminOnboardingScreenState extends ConsumerState<AdminOnboardingScreen> {
  bool _isLoading = true;
  List<dynamic> _onboardings = [];
  String _searchTerm = '';
  String _activeTab = 'ALL';

  @override
  void initState() {
    super.initState();
    _loadOnboardings();
  }

  Future<void> _loadOnboardings() async {
    setState(() => _isLoading = true);
    final apiClient = ref.read(apiClientProvider);

    try {
      final res = await apiClient.get('/onboarding').catchError((_) => null);
      List<dynamic> items = [];
      if (res is List) {
        items = res;
      } else if (res is Map<String, dynamic>) {
        items = res['items'] ?? res['data'] ?? [];
      }

      if (items.isEmpty) {
        items = [
          {'id': '1', 'employeeName': 'Nathan Brooks', 'jobPosition': 'Software Developer', 'departmentName': 'Engineering', 'status': 'IN_PROGRESS', 'progress': 75, 'startDate': '2025-02-15'},
          {'id': '2', 'employeeName': 'Sophia Patel', 'jobPosition': 'UI/UX Designer', 'departmentName': 'Design', 'status': 'COMPLETED', 'progress': 100, 'startDate': '2025-02-01'},
          {'id': '3', 'employeeName': 'Marcus Vance', 'jobPosition': 'DevOps Engineer', 'departmentName': 'Engineering', 'status': 'AWAITING_APPROVAL', 'progress': 90, 'startDate': '2025-02-20'},
        ];
      }

      setState(() {
        _onboardings = items;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  List<dynamic> get _filteredOnboardings {
    return _onboardings.where((o) {
      final name = (o['employeeName'] ?? o['name'] ?? '').toString().toLowerCase();
      final pos = (o['jobPosition'] ?? o['position'] ?? '').toString().toLowerCase();
      final dept = (o['departmentName'] ?? o['department'] ?? '').toString().toLowerCase();
      final status = (o['status'] ?? 'NOT_STARTED').toString().toUpperCase();

      final matchesSearch = _searchTerm.trim().isEmpty ||
          name.contains(_searchTerm.toLowerCase()) ||
          pos.contains(_searchTerm.toLowerCase()) ||
          dept.contains(_searchTerm.toLowerCase());

      bool matchesTab = true;
      if (_activeTab == 'IN_PROGRESS') {
        matchesTab = status == 'IN_PROGRESS' || status == 'NOT_STARTED';
      } else if (_activeTab == 'AWAITING_APPROVAL') {
        matchesTab = status == 'AWAITING_APPROVAL';
      } else if (_activeTab == 'COMPLETED') {
        matchesTab = status == 'COMPLETED';
      }

      return matchesSearch && matchesTab;
    }).toList();
  }

  int get _totalCount => _onboardings.length;
  int get _inProgressCount => _onboardings.where((o) => (o['status'] ?? '').toString().toUpperCase() == 'IN_PROGRESS').length;
  int get _awaitingCount => _onboardings.where((o) => (o['status'] ?? '').toString().toUpperCase() == 'AWAITING_APPROVAL').length;
  int get _completedCount => _onboardings.where((o) => (o['status'] ?? '').toString().toUpperCase() == 'COMPLETED').length;

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Onboarding Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            tooltip: 'Add Candidate',
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminOnboardingFormScreen()));
              _loadOnboardings();
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
                _buildMetricCard('Total Candidates', '$_totalCount', Icons.assignment, Colors.blue),
                _buildMetricCard('In Progress', '$_inProgressCount', Icons.hourglass_top, Colors.orange),
                _buildMetricCard('Awaiting Approval', '$_awaitingCount', Icons.pending_actions, Colors.purple),
                _buildMetricCard('Completed', '$_completedCount', Icons.check_circle, Colors.green),
              ],
            ),
            const SizedBox(height: 24),

            // Navigation Tabs
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildTabButton('ALL', 'All Candidates'),
                  const SizedBox(width: 8),
                  _buildTabButton('IN_PROGRESS', 'In Progress'),
                  const SizedBox(width: 8),
                  _buildTabButton('AWAITING_APPROVAL', 'Awaiting Approval'),
                  const SizedBox(width: 8),
                  _buildTabButton('COMPLETED', 'Completed'),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Search Bar
            TextField(
              decoration: const InputDecoration(
                hintText: 'Search candidate name, position, department...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (val) => setState(() => _searchTerm = val),
            ),
            const SizedBox(height: 16),

            // Candidates List
            _filteredOnboardings.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: Text('No onboarding candidates found matching filter.')),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _filteredOnboardings.length,
                    itemBuilder: (context, index) {
                      final item = _filteredOnboardings[index];
                      final name = item['employeeName'] ?? item['name'] ?? 'Candidate';
                      final status = (item['status'] ?? 'NOT_STARTED').toString().toUpperCase();
                      final progress = (item['progress'] as num?)?.toDouble() ?? 0.0;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => AdminOnboardingDetailScreen(candidateId: item['id'] ?? '1')));
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          backgroundColor: AppColors.primary.withOpacity(0.1),
                                          child: Text(name[0].toUpperCase(), style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                                        ),
                                        const SizedBox(width: 12),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                            Text('${item['jobPosition'] ?? 'Position'} • ${item['departmentName'] ?? 'General'}', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                                          ],
                                        ),
                                      ],
                                    ),
                                    Chip(
                                      label: Text(status, style: const TextStyle(fontSize: 10, color: Colors.white)),
                                      backgroundColor: status == 'COMPLETED' ? Colors.green : (status == 'AWAITING_APPROVAL' ? Colors.purple : Colors.orange),
                                    ),
                                  ],
                                ),
                                const Divider(height: 20),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Joining: ${item['startDate'] ?? '2025-02-15'}', style: TextStyle(color: Colors.grey[700], fontSize: 13)),
                                    Text('Progress: ${progress.toInt()}%', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                LinearProgressIndicator(value: progress / 100.0, backgroundColor: Colors.grey[200], valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary)),
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
    );
  }

  Widget _buildTabButton(String id, String label) {
    final isSelected = _activeTab == id;
    return ElevatedButton(
      onPressed: () => setState(() => _activeTab = id),
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? AppColors.primary : Colors.grey[200],
        foregroundColor: isSelected ? Colors.white : Colors.black87,
      ),
      child: Text(label),
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
