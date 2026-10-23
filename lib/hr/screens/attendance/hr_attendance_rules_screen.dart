import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/loading_shimmer.dart';
import 'hr_attendance_rule_form_screen.dart';

class HrAttendanceRulesScreen extends ConsumerStatefulWidget {
  const HrAttendanceRulesScreen({super.key});

  @override
  ConsumerState<HrAttendanceRulesScreen> createState() => _HrAttendanceRulesScreenState();
}

class _HrAttendanceRulesScreenState extends ConsumerState<HrAttendanceRulesScreen> {
  bool _isLoading = true;
  List<dynamic> _rules = [];
  String _searchTerm = '';

  @override
  void initState() {
    super.initState();
    _loadRules();
  }

  Future<void> _loadRules() async {
    setState(() => _isLoading = true);
    final apiClient = ref.read(apiClientProvider);
    try {
      final res = await apiClient.get('/attendance/rules').catchError((_) => null);
      List<dynamic> items = [];
      if (res is List) {
        items = res;
      } else if (res is Map<String, dynamic>) {
        items = res['items'] ?? res['data'] ?? [];
      }
      setState(() {
        _rules = items;
        _isLoading = false;
      });
    } catch (_) {
      setState(() {
        _rules = [];
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteRule(String id) async {
    final apiClient = ref.read(apiClientProvider);
    try {
      await apiClient.delete('/attendance/rules/$id');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Attendance rule deleted')));
        _loadRules();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const LoadingShimmer();

    final filtered = _rules.where((r) {
      final map = r is Map<String, dynamic> ? r : {};
      final name = (map['name'] ?? '').toString().toLowerCase();
      return _searchTerm.isEmpty || name.contains(_searchTerm.toLowerCase());
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance Rules & Policies'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HrAttendanceRuleFormScreen()),
              );
              _loadRules();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(
                labelText: 'Search rule name...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (val) => setState(() => _searchTerm = val),
            ),
            const SizedBox(height: 16),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final r = filtered[index] as Map<String, dynamic>;
                return AppCard(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(r['name'] ?? 'Policy Rule', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Switch(
                            value: r['isActive'] ?? true,
                            onChanged: (val) {},
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(r['description'] ?? 'No description', style: const TextStyle(color: Colors.grey)),
                      const SizedBox(height: 8),
                      Text('Grace Period: ${r['graceMinutes'] ?? 0}m • Min Work Hours: ${r['minWorkHours'] ?? 8}h'),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: AppColors.primary),
                            onPressed: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => HrAttendanceRuleFormScreen(ruleId: r['id'], initialData: r)),
                              );
                              _loadRules();
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deleteRule(r['id']),
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
    );
  }
}
