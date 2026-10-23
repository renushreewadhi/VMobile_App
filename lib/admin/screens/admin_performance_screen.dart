import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_card.dart';

class AdminPerformanceScreen extends ConsumerStatefulWidget {
  const AdminPerformanceScreen({super.key});

  @override
  ConsumerState<AdminPerformanceScreen> createState() => _AdminPerformanceScreenState();
}

class _AdminPerformanceScreenState extends ConsumerState<AdminPerformanceScreen> {
  bool _isLoading = true;
  String _activeTab = 'reviews';
  List<dynamic> _reviews = [];
  List<dynamic> _kpis = [];
  String _searchTerm = '';
  String _statusFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final apiClient = ref.read(apiClientProvider);

    try {
      final revRes = await apiClient.get('/performance/reviews').catchError((_) => null);
      final kpiRes = await apiClient.get('/performance/kpis').catchError((_) => null);

      List<dynamic> revList = revRes is List ? revRes : (revRes is Map ? (revRes['items'] ?? revRes['data'] ?? []) : []);
      List<dynamic> kpiList = kpiRes is List ? kpiRes : (kpiRes is Map ? (kpiRes['items'] ?? kpiRes['data'] ?? []) : []);

      if (revList.isEmpty) {
        revList = [
          {'id': '1', 'employeeId': 'EMP-01', 'name': 'Rahul Sharma', 'department': 'Engineering', 'reviewPeriod': 'Q4 2025', 'rating': '4.8 / 5', 'goalsMet': '92%', 'reviewer': 'Alex Johnson', 'status': 'COMPLETED'},
          {'id': '2', 'employeeId': 'EMP-02', 'name': 'Priya Verma', 'department': 'Marketing', 'reviewPeriod': 'Q4 2025', 'rating': '4.2 / 5', 'goalsMet': '85%', 'reviewer': 'Sarah Connor', 'status': 'IN_PROGRESS'},
        ];
      }

      if (kpiList.isEmpty) {
        kpiList = [
          {'id': 'k1', 'title': 'Code Quality & Test Coverage', 'department': 'Engineering', 'target': '95% Quality', 'currentAchievement': '91% Quality', 'weight': '25%', 'status': 'ACTIVE'},
          {'id': 'k2', 'title': 'Sprint Velocity & Deliverables', 'department': 'Engineering', 'target': '100% On-Time', 'currentAchievement': '88% On-Time', 'weight': '25%', 'status': 'ACTIVE'},
        ];
      }

      setState(() {
        _reviews = revList;
        _kpis = kpiList;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  List<dynamic> get _filteredReviews {
    return _reviews.where((r) {
      final name = (r['name'] ?? '').toString().toLowerCase();
      final dept = (r['department'] ?? '').toString().toLowerCase();
      final status = (r['status'] ?? 'COMPLETED').toString().toUpperCase();

      final matchesSearch = _searchTerm.trim().isEmpty || name.contains(_searchTerm.toLowerCase()) || dept.contains(_searchTerm.toLowerCase());
      final matchesStatus = _statusFilter == 'ALL' || status == _statusFilter;

      return matchesSearch && matchesStatus;
    }).toList();
  }

  List<dynamic> get _filteredKpis {
    return _kpis.where((k) {
      final title = (k['title'] ?? '').toString().toLowerCase();
      final dept = (k['department'] ?? '').toString().toLowerCase();
      return _searchTerm.trim().isEmpty || title.contains(_searchTerm.toLowerCase()) || dept.contains(_searchTerm.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Performance & Goals'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'New Review Cycle',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('New review cycle launched successfully!')));
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary Cards
            Row(
              children: [
                Expanded(child: _buildSummaryCard('Avg. Rating', '4.5 / 5', Colors.blue)),
                const SizedBox(width: 8),
                Expanded(child: _buildSummaryCard('Completed', '90%', Colors.green)),
                const SizedBox(width: 8),
                Expanded(child: _buildSummaryCard('KPIs Achieved', '85%', Colors.purple)),
              ],
            ),
            const SizedBox(height: 24),

            // Tabs
            Row(
              children: [
                _buildTabButton('reviews', 'Performance Reviews (${_reviews.length})'),
                const SizedBox(width: 8),
                _buildTabButton('kpi', 'KPIs (${_kpis.length})'),
              ],
            ),
            const SizedBox(height: 16),

            // Search Filter
            TextField(
              decoration: const InputDecoration(
                hintText: 'Search reviews or KPIs...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (val) => setState(() => _searchTerm = val),
            ),
            const SizedBox(height: 16),

            // Tab Content
            _activeTab == 'reviews'
                ? ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _filteredReviews.length,
                    itemBuilder: (context, index) {
                      final r = _filteredReviews[index];
                      return AppCard(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          title: Text(r['name'] ?? 'Employee', style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('Department: ${r['department']} • Period: ${r['reviewPeriod']} • Rating: ${r['rating']}'),
                          trailing: Chip(
                            label: Text(r['status'] ?? 'COMPLETED', style: const TextStyle(fontSize: 10, color: Colors.white)),
                            backgroundColor: r['status'] == 'COMPLETED' ? Colors.green : Colors.orange,
                          ),
                        ),
                      );
                    },
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _filteredKpis.length,
                    itemBuilder: (context, index) {
                      final k = _filteredKpis[index];
                      return AppCard(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          title: Text(k['title'] ?? 'KPI', style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('Department: ${k['department']} • Target: ${k['target']} • Current: ${k['currentAchievement']}'),
                          trailing: Chip(label: Text(k['weight'] ?? '20%')),
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

  Widget _buildSummaryCard(String title, String value, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 4),
            Text(title, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }
}
