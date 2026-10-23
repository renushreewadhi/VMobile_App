import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';

class HrShiftFormScreen extends ConsumerStatefulWidget {
  final String? shiftId;
  final Map<String, dynamic>? initialData;

  const HrShiftFormScreen({super.key, this.shiftId, this.initialData});

  @override
  ConsumerState<HrShiftFormScreen> createState() => _HrShiftFormScreenState();
}

class _HrShiftFormScreenState extends ConsumerState<HrShiftFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _codeController;
  late TextEditingController _startTimeController;
  late TextEditingController _endTimeController;
  String _status = 'ACTIVE';
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final d = widget.initialData ?? {};
    _nameController = TextEditingController(text: d['name'] ?? '');
    _codeController = TextEditingController(text: d['code'] ?? 'SH-03');
    _startTimeController = TextEditingController(text: d['startTime'] ?? '09:00 AM');
    _endTimeController = TextEditingController(text: d['endTime'] ?? '06:00 PM');
    final allowedStatuses = ['ACTIVE', 'INACTIVE'];
    final rawStatus = d['status'] ?? 'ACTIVE';
    _status = allowedStatuses.firstWhere(
      (s) => s.toLowerCase() == rawStatus.toString().toLowerCase(),
      orElse: () => 'ACTIVE',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _startTimeController.dispose();
    _endTimeController.dispose();
    super.dispose();
  }

  Future<void> _saveShift() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    final apiClient = ref.read(apiClientProvider);

    final payload = {
      'name': _nameController.text.trim(),
      'code': _codeController.text.trim(),
      'startTime': _startTimeController.text.trim(),
      'endTime': _endTimeController.text.trim(),
      'breakDurationMinutes': 60,
      'lateGracePeriodMinutes': 15,
      'status': _status,
    };

    try {
      if (widget.shiftId != null) {
        await apiClient.put('/attendance/shifts/${widget.shiftId}', body: payload);
      } else {
        await apiClient.post('/attendance/shifts', body: payload);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Shift saved successfully')));
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save shift: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.shiftId != null;
    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'Edit Work Shift' : 'Create Work Shift')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Shift Name *', border: OutlineInputBorder()),
                validator: (val) => val == null || val.isEmpty ? 'Shift name is required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _codeController,
                decoration: const InputDecoration(labelText: 'Shift Code *', border: OutlineInputBorder()),
                validator: (val) => val == null || val.isEmpty ? 'Shift code is required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _startTimeController,
                decoration: const InputDecoration(labelText: 'Start Time *', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _endTimeController,
                decoration: const InputDecoration(labelText: 'End Time *', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _status,
                decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
                items: ['ACTIVE', 'INACTIVE'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                onChanged: (val) => setState(() => _status = val ?? 'ACTIVE'),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveShift,
                  child: Text(_isSaving ? 'Saving...' : (isEdit ? 'Update Shift' : 'Create Shift')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
