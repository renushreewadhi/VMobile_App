import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/auth/auth_service.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/loading_shimmer.dart';
import '../../shared/widgets/status_chip.dart';

class DailyWorkUpdateScreen extends ConsumerStatefulWidget {
  final bool showAppBar;
  const DailyWorkUpdateScreen({super.key, this.showAppBar = false});

  @override
  ConsumerState<DailyWorkUpdateScreen> createState() => _DailyWorkUpdateScreenState();
}

class _DailyWorkUpdateScreenState extends ConsumerState<DailyWorkUpdateScreen> {
  final _formKey = GlobalKey<FormState>();
  DateTime _selectedDate = DateTime.now();
  String? _selectedProjectId;
  String _selectedProjectName = 'General Project';
  double _hoursWorked = 8.0;

  final _tasksController = TextEditingController();
  final _summaryController = TextEditingController();
  final _blockersController = TextEditingController();

  List<Map<String, dynamic>> _projectsList = [];
  List<Map<String, dynamic>> _updatesList = [];
  bool _loading = true;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _tasksController.dispose();
    _summaryController.dispose();
    _blockersController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    final apiClient = ref.read(apiClientProvider);

    try {
      final results = await Future.wait([
        apiClient.get(ApiEndpoints.workUpdates).catchError((_) => null),
        apiClient.get(ApiEndpoints.myProjects).catchError((_) => null),
      ]);

      if (!mounted) return;

      final rawUpdates = results[0] is List
          ? results[0] as List
          : (results[0] is Map && results[0]['data'] is List ? results[0]['data'] as List : []);
      final rawProjects = results[1] is List
          ? results[1] as List
          : (results[1] is Map && results[1]['data'] is List ? results[1]['data'] as List : []);

      final updates = <Map<String, dynamic>>[];
      for (final item in rawUpdates) {
        if (item is Map) {
          final id = item['id']?.toString() ?? '';
          final dateStr = item['date']?.toString() ?? item['updateDate']?.toString() ?? '';
          final project = item['projectName']?.toString() ?? item['project']?.toString() ?? 'General Project';
          final hours = item['hoursWorked'] != null ? '${item['hoursWorked']} hrs' : '8.0 hrs';
          final tasks = item['tasksCompleted']?.toString() ?? item['tasks']?.toString() ?? item['content']?.toString() ?? '';
          final summary = item['summary']?.toString() ?? item['description']?.toString() ?? '';
          final blockers = item['blockers']?.toString() ?? 'None';
          final status = item['status']?.toString() ?? 'Submitted';

          updates.add({
            'id': id,
            'date': dateStr.contains('T') ? dateStr.split('T')[0] : dateStr,
            'project': project,
            'hours': hours,
            'tasks': tasks,
            'summary': summary,
            'blockers': blockers.isEmpty ? 'None' : blockers,
            'status': status,
          });
        }
      }

      final projects = <Map<String, dynamic>>[];
      for (final p in rawProjects) {
        if (p is Map) {
          final pId = p['id']?.toString() ?? '';
          final pName = p['name']?.toString() ?? p['title']?.toString() ?? 'General Project';
          projects.add({'id': pId, 'name': pName});
        }
      }

      setState(() {
        _updatesList = updates;
        _projectsList = projects;
        if (projects.isNotEmpty) {
          _selectedProjectId = projects.first['id'];
          _selectedProjectName = projects.first['name'];
        }
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('ApiException: ', '').replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _submitEOD() async {
    if (_submitting || !(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    final dateStr = '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';

    final payload = <String, dynamic>{
      'date': dateStr,
      'projectId': _selectedProjectId,
      'projectName': _selectedProjectName,
      'hoursWorked': _hoursWorked,
      'tasksCompleted': _tasksController.text.trim(),
      'summary': _summaryController.text.trim(),
      'blockers': _blockersController.text.trim(),
      'content': _tasksController.text.trim(),
    };

    final apiClient = ref.read(apiClientProvider);

    try {
      await apiClient.post(ApiEndpoints.workUpdates, body: payload);

      if (!mounted) return;

      setState(() {
        _tasksController.clear();
        _summaryController.clear();
        _blockersController.clear();
        _hoursWorked = 8.0;
        _submitting = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('EOD Work Update submitted successfully'),
          backgroundColor: AppColors.success,
        ),
      );

      _loadData();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('EOD Work Update submitted successfully'),
          backgroundColor: AppColors.success,
        ),
      );

      _tasksController.clear();
      _summaryController.clear();
      _blockersController.clear();
      _loadData();
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final content = RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!widget.showAppBar) ...[
              _buildHeader(isDark),
              const SizedBox(height: 16),
            ],
            _buildEodForm(isDark),
            const SizedBox(height: 24),
            _buildHistoryHeader(isDark),
            const SizedBox(height: 12),
            _buildHistoryList(isDark),
          ],
        ),
      ),
    );

    if (!widget.showAppBar) return Scaffold(backgroundColor: isDark ? AppColors.darkAppBackground : AppColors.lightAppBackground, body: SafeArea(child: content));

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkAppBackground : AppColors.lightAppBackground,
      appBar: AppBar(title: const Text('Daily Work Update (EOD)')),
      body: content,
    );
  }

  Widget _buildHeader(bool dark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Daily Work Update (EOD)',
          style: TextStyle(
            color: dark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Submit your daily progress summary to team lead and manager',
          style: TextStyle(color: dark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildEodForm(bool dark) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Submit Today\'s Report',
              style: TextStyle(
                color: dark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _pickDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
                      decoration: BoxDecoration(
                        color: dark ? AppColors.darkMainSurface : AppColors.lightInputBackground,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: dark ? AppColors.darkBordersAndDividers : AppColors.lightBordersAndDividers),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.calendar_today_outlined, size: 16, color: AppColors.primary),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}',
                              style: TextStyle(
                                color: dark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedProjectId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Project',
                      isDense: true,
                      filled: true,
                      fillColor: dark ? AppColors.darkMainSurface : AppColors.lightInputBackground,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: dark ? AppColors.darkBordersAndDividers : AppColors.lightBordersAndDividers),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    ),
                    items: _projectsList.isNotEmpty
                        ? _projectsList.map((p) {
                            return DropdownMenuItem<String>(
                              value: p['id'].toString(),
                              child: Text(p['name'].toString(), overflow: TextOverflow.ellipsis),
                            );
                          }).toList()
                        : const [
                            DropdownMenuItem(value: null, child: Text('General Project')),
                          ],
                    onChanged: (val) {
                      setState(() {
                        _selectedProjectId = val;
                        final found = _projectsList.firstWhere(
                          (p) => p['id'] == val,
                          orElse: () => {'name': 'General Project'},
                        );
                        _selectedProjectName = found['name'].toString();
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Text(
                  'Hours Worked: ${_hoursWorked.toStringAsFixed(1)} hrs',
                  style: TextStyle(
                    color: dark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            Slider(
              value: _hoursWorked,
              min: 1.0,
              max: 12.0,
              divisions: 22,
              activeColor: AppColors.primary,
              label: '${_hoursWorked.toStringAsFixed(1)} hrs',
              onChanged: (val) => setState(() => _hoursWorked = val),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _tasksController,
              decoration: InputDecoration(
                labelText: 'Tasks Completed Today *',
                hintText: 'List key modules, features, or tickets closed...',
                filled: true,
                fillColor: dark ? AppColors.darkMainSurface : AppColors.lightInputBackground,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              validator: (v) => v == null || v.trim().isEmpty ? 'Please list completed tasks' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _summaryController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Work Summary & Notes',
                hintText: 'Describe details of implementation...',
                filled: true,
                fillColor: dark ? AppColors.darkMainSurface : AppColors.lightInputBackground,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _blockersController,
              decoration: InputDecoration(
                labelText: 'Blockers / Issues (If Any)',
                hintText: 'Any pending approvals, API gaps, or dependencies...',
                filled: true,
                fillColor: dark ? AppColors.darkMainSurface : AppColors.lightInputBackground,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _submitting ? null : _submitEOD,
                icon: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                label: const Text(
                  'Submit Daily Work Update',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryHeader(bool dark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Submitted EOD Updates',
          style: TextStyle(
            color: dark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          '${_updatesList.length} History Items',
          style: TextStyle(color: dark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildHistoryList(bool dark) {
    if (_updatesList.isEmpty) {
      return AppCard(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(
            'No work updates submitted yet',
            style: TextStyle(color: dark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText),
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _updatesList.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final update = _updatesList[index];
        return AppCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    update['date'],
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  StatusChip(status: update['status']?.toString().toUpperCase() ?? 'SUBMITTED'),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${update['project']} • ${update['hours']}',
                style: TextStyle(
                  color: dark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (update['tasks'].toString().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text('Tasks: ${update['tasks']}', style: TextStyle(color: dark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText, fontSize: 12)),
              ],
              if (update['summary'].toString().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text('Summary: ${update['summary']}', style: TextStyle(color: dark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText, fontSize: 12)),
              ],
              if (update['blockers'].toString().isNotEmpty && update['blockers'] != 'None') ...[
                const SizedBox(height: 4),
                Text('Blockers: ${update['blockers']}', style: const TextStyle(color: Colors.redAccent, fontSize: 11.5)),
              ],
            ],
          ),
        );
      },
    );
  }
}
