import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_card.dart';

class HrAttendanceRuleFormScreen extends ConsumerStatefulWidget {
  final String? ruleId;
  final Map<String, dynamic>? initialData;

  const HrAttendanceRuleFormScreen({super.key, this.ruleId, this.initialData});

  @override
  ConsumerState<HrAttendanceRuleFormScreen> createState() => _HrAttendanceRuleFormScreenState();
}

class _HrAttendanceRuleFormScreenState extends ConsumerState<HrAttendanceRuleFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descController;
  late TextEditingController _graceController;
  late TextEditingController _minHoursController;
  bool _isActive = true;
  bool _autoAbsent = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final d = widget.initialData ?? {};
    _nameController = TextEditingController(text: d['name'] ?? '');
    _descController = TextEditingController(text: d['description'] ?? '');
    _graceController = TextEditingController(text: (d['graceMinutes'] ?? 15).toString());
    _minHoursController = TextEditingController(text: (d['minWorkHours'] ?? 8).toString());
    _isActive = d['isActive'] ?? true;
    _autoAbsent = d['autoMarkAbsentOnNoCheckIn'] ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _graceController.dispose();
    _minHoursController.dispose();
    super.dispose();
  }

  Future<void> _saveRule() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    final apiClient = ref.read(apiClientProvider);

    final payload = {
      'name': _nameController.text.trim(),
      'description': _descController.text.trim(),
      'graceMinutes': int.tryParse(_graceController.text) ?? 15,
      'minWorkHours': double.tryParse(_minHoursController.text) ?? 8.0,
      'isActive': _isActive,
      'autoMarkAbsentOnNoCheckIn': _autoAbsent,
    };

    try {
      if (widget.ruleId != null) {
        await apiClient.put('/attendance/rules/${widget.ruleId}', body: payload);
      } else {
        await apiClient.post('/attendance/rules', body: payload);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Attendance policy saved successfully')));
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save policy: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.ruleId != null ? 'Edit Policy Rule' : 'New Policy Rule')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Policy Name *', border: OutlineInputBorder()),
                validator: (val) => val == null || val.isEmpty ? 'Policy name is required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descController,
                decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _graceController,
                decoration: const InputDecoration(labelText: 'Grace Period (Minutes)', border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _minHoursController,
                decoration: const InputDecoration(labelText: 'Minimum Daily Work Hours', border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Active Policy'),
                value: _isActive,
                onChanged: (val) => setState(() => _isActive = val),
              ),
              SwitchListTile(
                title: const Text('Auto Mark Absent on No Check-In'),
                value: _autoAbsent,
                onChanged: (val) => setState(() => _autoAbsent = val),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveRule,
                  child: Text(_isSaving ? 'Saving...' : 'Save Policy'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
