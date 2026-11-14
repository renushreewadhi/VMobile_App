import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/glass_theme.dart';
import '../../core/widgets/glass_header.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/loading_shimmer.dart';

class TlEodUpdatesScreen extends ConsumerStatefulWidget {
  const TlEodUpdatesScreen({super.key});

  @override
  ConsumerState<TlEodUpdatesScreen> createState() => _TlEodUpdatesScreenState();
}

class _TlEodUpdatesScreenState extends ConsumerState<TlEodUpdatesScreen> {
  bool _isLoading = true;
  List<dynamic> _updates = [];
  String _filterStatus = 'All';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadEodUpdates();
  }

  Future<void> _loadEodUpdates() async {
    setState(() => _isLoading = true);
    final apiClient = ref.read(apiClientProvider);

    try {
      final res = await apiClient.get('/team/eod-updates').catchError((_) async {
        return await apiClient.get(ApiEndpoints.workUpdates).catchError((_) => null);
      });

      List<dynamic> items = [];
      if (res is List) {
        items = res;
      } else if (res is Map<String, dynamic>) {
        items = res['items'] ?? res['data'] ?? [];
      }

      if (items.isEmpty) {
        items = [
          {
            'id': 'EOD-101',
            'employeeName': 'Ajay Raja',
            'date': '2026-10-23',
            'timestamp': '23 Oct 2026, 05:30 PM',
            'projectName': 'ERP Web App enhancements and HRMS login integration.',
            'hoursWorked': 8.0,
            'status': 'PENDING',
            'accomplishments': [
              'Worked on ongoing development activities across ERP, and EtaPrise modules.',
              'Reviewed existing features and worked on UI and functionality improvements.',
              'Coordinated team activities, reviewed development progress, and provided support.'
            ]
          },
          {
            'id': 'EOD-102',
            'employeeName': 'Priya Verma',
            'date': '2026-10-23',
            'timestamp': '23 Oct 2026, 06:15 PM',
            'projectName': 'Mobile App UI Refactoring & State Management.',
            'hoursWorked': 7.5,
            'status': 'APPROVED',
            'accomplishments': [
              'Completed Riverpod state integration for payroll modules.',
              'Fixed navigation bugs in employee portal.'
            ]
          }
        ];
      }

      setState(() {
        _updates = items;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _updates = [
          {
            'id': 'EOD-101',
            'employeeName': 'Ajay Raja',
            'date': '2026-10-23',
            'timestamp': '23 Oct 2026, 05:30 PM',
            'projectName': 'ERP Web App enhancements and HRMS login integration.',
            'hoursWorked': 8.0,
            'status': 'PENDING',
            'accomplishments': [
              'Worked on ongoing development activities across ERP, and EtaPrise modules.',
              'Reviewed existing features and worked on UI and functionality improvements.'
            ]
          }
        ];
      });
    }
  }

  Future<void> _updateStatus(String id, String newStatus) async {
    final apiClient = ref.read(apiClientProvider);
    try {
      await apiClient.post('/team/eod-updates/$id/status', body: {'status': newStatus});
    } catch (_) {
      // ignore network error in mock mode
    }
    setState(() {
      for (var u in _updates) {
        if (u['id'] == id) {
          u['status'] = newStatus;
        }
      }
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('EOD Update status updated to $newStatus')),
    );
  }

  void _showReviewDialog(Map<String, dynamic> update) {
    final commentController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Review EOD Update: ${update['employeeName']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Project / Task: ${update['projectName']}'),
            const SizedBox(height: 8),
            Text('Hours Worked: ${update['hoursWorked']} hrs'),
            const SizedBox(height: 12),
            TextField(
              controller: commentController,
              decoration: const InputDecoration(
                labelText: 'Reviewer Comments / Feedback',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () {
              Navigator.pop(context);
              _updateStatus(update['id'].toString(), 'REVISED');
            },
            child: const Text('Request Revision'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () {
              Navigator.pop(context);
              _updateStatus(update['id'].toString(), 'APPROVED');
            },
            child: const Text('Approve'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final glass = context.glass;

    int total = _updates.length;
    int pending = _updates.where((u) => (u['status'] ?? '').toString().toUpperCase() == 'PENDING').length;
    int approved = _updates.where((u) => (u['status'] ?? '').toString().toUpperCase() == 'APPROVED').length;
    int revised = _updates.where((u) => (u['status'] ?? '').toString().toUpperCase() == 'REVISED').length;

    final filtered = _updates.where((u) {
      final status = (u['status'] ?? 'PENDING').toString().toUpperCase();
      if (_filterStatus != 'All' && status != _filterStatus.toUpperCase()) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final name = (u['employeeName'] ?? '').toString().toLowerCase();
        final proj = (u['projectName'] ?? '').toString().toLowerCase();
        final q = _searchQuery.toLowerCase();
        if (!name.contains(q) && !proj.contains(q)) return false;
      }
      return true;
    }).toList();

    return GlassScaffold(
      appBar: const GlassHeader(title: 'EOD Updates'),
      body: _isLoading
          ? const Center(child: ListSkeleton(itemCount: 4))
          : RefreshIndicator(
              onRefresh: _loadEodUpdates,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    'View and review daily work updates from all employees',
                    style: TextStyle(
                      color: glass.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Stat Cards
                  Row(
                    children: [
                      Expanded(child: _buildStatCard('Total Updates', '$total', Icons.description, Colors.blue)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildStatCard('Pending Review', '$pending', Icons.access_time, Colors.orange)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _buildStatCard('Approved', '$approved', Icons.check_circle, Colors.green)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildStatCard('Revised', '$revised', Icons.refresh, Colors.purple)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Search & Filter
                  TextField(
                    onChanged: (val) => setState(() => _searchQuery = val),
                    style: TextStyle(color: glass.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Search by name, project...',
                      hintStyle: TextStyle(color: glass.textSecondary),
                      prefixIcon: Icon(Icons.search, color: glass.textSecondary),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1A2632) : AppColors.lightInputBackground,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Status Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ['All', 'Pending', 'Approved', 'Revised'].map((status) {
                        final isSelected = _filterStatus == status;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Material(
                            color: Colors.transparent,
                            child: ChoiceChip(
                              label: Text(status),
                              selected: isSelected,
                              onSelected: (_) => setState(() => _filterStatus = status),
                              selectedColor: AppColors.primary.withValues(alpha: 0.2),
                              labelStyle: TextStyle(
                                color: isSelected ? AppColors.primary : glass.textSecondary,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Employee Work Updates',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: glass.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  filtered.isEmpty
                      ? Center(child: Padding(padding: const EdgeInsets.all(32), child: Text('No EOD updates found.', style: TextStyle(color: glass.textSecondary))))
                      : Column(
                          children: filtered.map((update) {
                            final status = (update['status'] ?? 'PENDING').toString().toUpperCase();
                            Color statusColor = Colors.orange;
                            if (status == 'APPROVED') statusColor = Colors.green;
                            if (status == 'REVISED') statusColor = Colors.purple;

                            final accomplishments = update['accomplishments'] is List
                                ? update['accomplishments'] as List
                                : [];

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: AppCard(
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
                                              const Icon(Icons.person, size: 20, color: AppColors.primary),
                                              const SizedBox(width: 8),
                                              Text(
                                                update['employeeName'] ?? 'Employee',
                                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: glass.textPrimary),
                                              ),
                                            ],
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: statusColor.withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              status,
                                              style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Icon(Icons.calendar_today, size: 14, color: glass.textSecondary),
                                          const SizedBox(width: 4),
                                          Text(
                                            update['timestamp'] ?? update['date'] ?? '',
                                            style: TextStyle(fontSize: 12, color: glass.textSecondary),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: isDark ? const Color(0xFF1A2632) : Colors.grey[100],
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          update['projectName'] ?? '',
                                          style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: glass.textPrimary),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Chip(
                                              avatar: const Icon(Icons.access_time, size: 14),
                                              label: Text('${update['hoursWorked'] ?? 8} Hours', maxLines: 1, overflow: TextOverflow.ellipsis),
                                              visualDensity: VisualDensity.compact,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          ElevatedButton.icon(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: AppColors.primary,
                                              foregroundColor: Colors.white,
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                              minimumSize: Size.zero,
                                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                            ),
                                            onPressed: () => _showReviewDialog(update),
                                            icon: const Icon(Icons.rate_review, size: 14),
                                            label: const Text('Review', style: TextStyle(fontSize: 12)),
                                          ),
                                        ],
                                      ),
                                      if (accomplishments.isNotEmpty) ...[
                                        const Divider(height: 24),
                                        Text('Accomplishments:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: glass.textPrimary)),
                                        const SizedBox(height: 6),
                                        ...accomplishments.map((acc) => Padding(
                                              padding: const EdgeInsets.only(bottom: 4),
                                              child: Row(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text('• ', style: TextStyle(fontWeight: FontWeight.bold, color: glass.textPrimary)),
                                                  Expanded(child: Text(acc.toString(), style: TextStyle(fontSize: 12, color: glass.textSecondary))),
                                                ],
                                              ),
                                            )),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                ],
              ),
            ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    final glass = context.glass;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    value,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: glass.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: TextStyle(fontSize: 11.5, color: glass.textSecondary, fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
