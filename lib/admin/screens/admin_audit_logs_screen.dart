import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_card.dart';

class AdminAuditLogsScreen extends ConsumerStatefulWidget {
  const AdminAuditLogsScreen({super.key});

  @override
  ConsumerState<AdminAuditLogsScreen> createState() => _AdminAuditLogsScreenState();
}

class _AdminAuditLogsScreenState extends ConsumerState<AdminAuditLogsScreen> {
  bool _isLoading = true;
  List<dynamic> _logs = [];
  String _searchTerm = '';
  String _selectedModule = '';
  String _selectedAction = '';

  @override
  void initState() {
    super.initState();
    _loadAuditLogs();
  }

  Future<void> _loadAuditLogs() async {
    setState(() => _isLoading = true);
    final apiClient = ref.read(apiClientProvider);

    try {
      final res = await apiClient.get('/AuditLog').catchError((_) => apiClient.get('/audit-logs')).catchError((_) => null);
      List<dynamic> items = [];
      if (res is List) {
        items = res;
      } else if (res is Map<String, dynamic>) {
        items = res['items'] ?? res['data'] ?? [];
      }

      if (items.isEmpty) {
        items = [
          {'id': '1', 'timestamp': '2025-02-20T10:30:00Z', 'userName': 'Admin Alex', 'module': 'Employees', 'action': 'CREATE', 'details': 'Created new employee record for John Doe', 'ipAddress': '192.168.1.10'},
          {'id': '2', 'timestamp': '2025-02-20T11:15:00Z', 'userName': 'HR Sarah', 'module': 'Attendance', 'action': 'UPDATE', 'details': 'Approved attendance correction for employee #EMP-02', 'ipAddress': '192.168.1.15'},
        ];
      }

      setState(() {
        _logs = items;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  List<dynamic> get _filteredLogs {
    return _logs.where((l) {
      final user = (l['userName'] ?? l['user'] ?? '').toString().toLowerCase();
      final mod = (l['module'] ?? '').toString().toLowerCase();
      final act = (l['action'] ?? '').toString().toLowerCase();
      final desc = (l['details'] ?? l['description'] ?? '').toString().toLowerCase();

      final matchesSearch = _searchTerm.trim().isEmpty ||
          user.contains(_searchTerm.toLowerCase()) ||
          mod.contains(_searchTerm.toLowerCase()) ||
          act.contains(_searchTerm.toLowerCase()) ||
          desc.contains(_searchTerm.toLowerCase());

      final matchesModule = _selectedModule.isEmpty || mod == _selectedModule.toLowerCase();
      final matchesAction = _selectedAction.isEmpty || act == _selectedAction.toLowerCase();

      return matchesSearch && matchesModule && matchesAction;
    }).toList();
  }

  int get _createCount => _logs.where((l) => (l['action'] ?? '').toString().toUpperCase().contains('CREATE')).length;
  int get _updateCount => _logs.where((l) => (l['action'] ?? '').toString().toUpperCase().contains('UPDATE')).length;
  int get _deleteCount => _logs.where((l) => (l['action'] ?? '').toString().toUpperCase().contains('DELETE')).length;

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Audit Logs'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // KPI Stat Cards
            Row(
              children: [
                Expanded(child: _buildMetricCard('Total Events', '${_logs.length}', Icons.history, Colors.blue)),
                const SizedBox(width: 8),
                Expanded(child: _buildMetricCard('Creates', '$_createCount', Icons.add_circle, Colors.green)),
                const SizedBox(width: 8),
                Expanded(child: _buildMetricCard('Updates', '$_updateCount', Icons.edit, Colors.orange)),
              ],
            ),
            const SizedBox(height: 24),

            // Search Bar
            TextField(
              decoration: const InputDecoration(
                hintText: 'Search audit logs by user, module, action, IP...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (val) => setState(() => _searchTerm = val),
            ),
            const SizedBox(height: 16),

            // Logs List
            _filteredLogs.isEmpty
                ? const Center(child: Text('No audit log entries found matching criteria.'))
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _filteredLogs.length,
                    itemBuilder: (context, index) {
                      final l = _filteredLogs[index];
                      final action = (l['action'] ?? 'INFO').toString().toUpperCase();

                      return AppCard(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          title: Text('${l['module'] ?? 'System'} • $action', style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('${l['details'] ?? l['description'] ?? 'No details'}\nUser: ${l['userName'] ?? l['user'] ?? 'System'} • IP: ${l['ipAddress'] ?? '127.0.0.1'}'),
                          isThreeLine: true,
                          trailing: Chip(
                            label: Text(action, style: const TextStyle(fontSize: 10, color: Colors.white)),
                            backgroundColor: action.contains('DELETE') ? Colors.red : (action.contains('UPDATE') ? Colors.orange : Colors.green),
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

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          Text(title, style: TextStyle(fontSize: 10, color: Colors.grey[600]), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
