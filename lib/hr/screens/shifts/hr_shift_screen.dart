import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/loading_shimmer.dart';
import 'hr_shift_form_screen.dart';

class HrShiftScreen extends ConsumerStatefulWidget {
  const HrShiftScreen({super.key});

  @override
  ConsumerState<HrShiftScreen> createState() => _HrShiftScreenState();
}

class _HrShiftScreenState extends ConsumerState<HrShiftScreen> {
  bool _isLoading = true;
  List<dynamic> _shifts = [];
  List<dynamic> _assignments = [];
  String _searchTerm = '';

  @override
  void initState() {
    super.initState();
    _loadShiftData();
  }

  Future<void> _loadShiftData() async {
    setState(() => _isLoading = true);
    final apiClient = ref.read(apiClientProvider);
    try {
      final shiftRes = await apiClient.get('/attendance/shifts').catchError((_) => null);
      final assignRes = await apiClient.get('/attendance/assignments').catchError((_) => null);

      List<dynamic> shifts = shiftRes is List ? shiftRes : (shiftRes is Map ? (shiftRes['items'] ?? shiftRes['data'] ?? []) : []);
      List<dynamic> assignments = assignRes is List ? assignRes : (assignRes is Map ? (assignRes['items'] ?? assignRes['data'] ?? []) : []);

      if (shifts.isEmpty) {
        shifts = [
          {'id': '1', 'name': 'General Shift', 'code': 'SH-01', 'startTime': '09:00 AM', 'endTime': '06:00 PM', 'breakDurationMinutes': 60, 'status': 'ACTIVE'},
          {'id': '2', 'name': 'Morning Shift', 'code': 'SH-02', 'startTime': '07:00 AM', 'endTime': '04:00 PM', 'breakDurationMinutes': 60, 'status': 'ACTIVE'},
        ];
      }

      setState(() {
        _shifts = shifts;
        _assignments = assignments;
        _isLoading = false;
      });
    } catch (_) {
      setState(() {
        _shifts = [];
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const LoadingShimmer();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shift Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const HrShiftFormScreen()));
              _loadShiftData();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Work Shift Templates', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _shifts.length,
              itemBuilder: (context, index) {
                final s = _shifts[index] as Map<String, dynamic>;
                return AppCard(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(s['name'] ?? 'Shift', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('${s['code'] ?? ''} • ${s['startTime'] ?? ''} to ${s['endTime'] ?? ''}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Chip(label: Text(s['status'] ?? 'ACTIVE')),
                        IconButton(
                          icon: const Icon(Icons.edit, size: 20, color: AppColors.primary),
                          onPressed: () async {
                            await Navigator.push(context, MaterialPageRoute(builder: (_) => HrShiftFormScreen(shiftId: s['id'], initialData: s)));
                            _loadShiftData();
                          },
                        ),
                      ],
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
}
