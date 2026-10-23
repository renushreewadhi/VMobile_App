import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/loading_shimmer.dart';

class HrAttendanceSummaryScreen extends ConsumerStatefulWidget {
  const HrAttendanceSummaryScreen({super.key});

  @override
  ConsumerState<HrAttendanceSummaryScreen> createState() => _HrAttendanceSummaryScreenState();
}

class _HrAttendanceSummaryScreenState extends ConsumerState<HrAttendanceSummaryScreen> {
  bool _isLoading = true;
  List<dynamic> _summaryList = [];
  List<dynamic> _lateArrivals = [];
  String _activeTab = 'summary';
  String _searchTerm = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final apiClient = ref.read(apiClientProvider);
    try {
      final summaryRes = await apiClient.get(ApiEndpoints.attendanceSummary).catchError((_) => null);
      final lateRes = await apiClient.get('/attendance/late-arrivals').catchError((_) => null);

      List<dynamic> sumItems = [];
      if (summaryRes is List) {
        sumItems = summaryRes;
      } else if (summaryRes is Map<String, dynamic>) {
        sumItems = summaryRes['items'] ?? summaryRes['data'] ?? [];
      }

      List<dynamic> lateItems = [];
      if (lateRes is List) {
        lateItems = lateRes;
      } else if (lateRes is Map<String, dynamic>) {
        lateItems = lateRes['items'] ?? lateRes['data'] ?? [];
      }

      setState(() {
        _summaryList = sumItems;
        _lateArrivals = lateItems;
        _isLoading = false;
      });
    } catch (_) {
      setState(() {
        _summaryList = [];
        _lateArrivals = [];
        _isLoading = false;
      });
    }
  }

  Future<void> _approveLate(String id) async {
    final apiClient = ref.read(apiClientProvider);
    try {
      await apiClient.post('/attendance/verification/$id/approve', body: {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Late arrival approved & marked Present')));
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const LoadingShimmer();

    return Scaffold(
      appBar: AppBar(title: const Text('Attendance Summary & Analytics')),
      body: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              TextButton(
                onPressed: () => setState(() => _activeTab = 'summary'),
                child: Text('Summary', style: TextStyle(fontWeight: _activeTab == 'summary' ? FontWeight.bold : FontWeight.normal)),
              ),
              TextButton(
                onPressed: () => setState(() => _activeTab = 'late'),
                child: Text('Late Arrivals', style: TextStyle(fontWeight: _activeTab == 'late' ? FontWeight.bold : FontWeight.normal)),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Search employee...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (val) => setState(() => _searchTerm = val),
            ),
          ),
          Expanded(
            child: _activeTab == 'summary' ? _buildSummaryList() : _buildLateList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryList() {
    final filtered = _summaryList.where((s) {
      final map = s is Map<String, dynamic> ? s : {};
      final name = (map['employeeName'] ?? '').toString().toLowerCase();
      return _searchTerm.isEmpty || name.contains(_searchTerm.toLowerCase());
    }).toList();

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final s = filtered[index] as Map<String, dynamic>;
        return AppCard(
          margin: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s['employeeName'] ?? 'Employee', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 4),
              Text('Code: ${s['employeeCode'] ?? ''} • Dept: ${s['department'] ?? 'General'}'),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Present: ${s['presentDays'] ?? 0}'),
                  Text('Absent: ${s['absentDays'] ?? 0}'),
                  Text('Late: ${s['lateDays'] ?? 0}'),
                  Text('Rate: ${s['attendancePercent'] ?? 0}%', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLateList() {
    final filtered = _lateArrivals.where((l) {
      final map = l is Map<String, dynamic> ? l : {};
      final name = (map['employeeName'] ?? '').toString().toLowerCase();
      return _searchTerm.isEmpty || name.contains(_searchTerm.toLowerCase());
    }).toList();

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final l = filtered[index] as Map<String, dynamic>;
        final isApproved = l['isApproved'] == true || l['verificationStatus'] == 'APPROVED';
        return AppCard(
          margin: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(l['employeeName'] ?? 'Employee', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Chip(label: Text('${l['delayMins'] ?? 0}m late')),
                ],
              ),
              const SizedBox(height: 4),
              Text('Date: ${l['date'] ?? ''} • Shift: ${l['scheduledTime'] ?? ''} • Check-in: ${l['actualCheckIn'] ?? ''}'),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (isApproved)
                    const Text('Approved', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))
                  else
                    ElevatedButton(
                      onPressed: () => _approveLate(l['attendanceId'] ?? l['id']),
                      child: const Text('Approve Late'),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
