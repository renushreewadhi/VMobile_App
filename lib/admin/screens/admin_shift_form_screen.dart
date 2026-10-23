import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';

class AdminShiftFormScreen extends ConsumerStatefulWidget {
  final String? shiftId;
  final Map<String, dynamic>? initialData;

  const AdminShiftFormScreen({super.key, this.shiftId, this.initialData});

  @override
  ConsumerState<AdminShiftFormScreen> createState() => _AdminShiftFormScreenState();
}

class _AdminShiftFormScreenState extends ConsumerState<AdminShiftFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isSaving = false;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _startTimeController = TextEditingController(text: '09:00');
  final TextEditingController _endTimeController = TextEditingController(text: '18:00');
  final TextEditingController _breakController = TextEditingController(text: '60');
  final TextEditingController _graceController = TextEditingController(text: '15');
  final TextEditingController _halfDayController = TextEditingController(text: '4.5');
  final TextEditingController _overtimeController = TextEditingController(text: '1.0');
  final TextEditingController _descController = TextEditingController();

  String _category = 'Fixed';
  String _status = 'ACTIVE';
  final List<String> _daysList = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final List<String> _workingDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'];
  final List<String> _categories = ['Fixed', 'Rotational', 'Flexible', 'Split'];

  bool get _isEdit => widget.shiftId != null || widget.initialData != null;

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      _populateData(widget.initialData!);
    } else if (_isEdit && widget.shiftId != null) {
      _loadShiftDetail();
    }
  }

  void _populateData(Map<String, dynamic> data) {
    _nameController.text = data['name'] ?? '';
    _codeController.text = data['code'] ?? '';
    _startTimeController.text = data['startTime'] ?? '09:00';
    _endTimeController.text = data['endTime'] ?? '18:00';
    _breakController.text = '${data['breakDurationMinutes'] ?? data['breakMinutes'] ?? 60}';
    _graceController.text = '${data['lateGracePeriodMinutes'] ?? data['lateGraceMinutes'] ?? 15}';
    _halfDayController.text = '${data['halfDayHours'] ?? 4.5}';
    _overtimeController.text = '${data['overtimeThresholdHours'] ?? 1.0}';
    _category = data['category'] ?? 'Fixed';
    final allowedStatuses = ['ACTIVE', 'INACTIVE'];
    final rawStatus = data['status'] ?? 'ACTIVE';
    _status = allowedStatuses.firstWhere(
      (s) => s.toLowerCase() == rawStatus.toString().toLowerCase(),
      orElse: () => 'ACTIVE',
    );
    _descController.text = data['description'] ?? '';

    if (data['workingDays'] is List) {
      _workingDays.clear();
      _workingDays.addAll((data['workingDays'] as List).cast<String>());
    }
  }

  Future<void> _loadShiftDetail() async {
    setState(() => _isLoading = true);
    try {
      final res = await ref.read(apiClientProvider).get('/attendance/shifts/${widget.shiftId}');
      if (res is Map<String, dynamic>) {
        _populateData(res);
      }
    } catch (_) {
      if (widget.initialData != null) {
        _populateData(widget.initialData!);
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _toggleDay(String day) {
    setState(() {
      if (_workingDays.contains(day)) {
        _workingDays.remove(day);
      } else {
        _workingDays.add(day);
      }
    });
  }

  Future<void> _saveShift() async {
    if (!_formKey.currentState!.validate()) return;
    if (_workingDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select at least one working day')));
      return;
    }

    setState(() => _isSaving = true);

    final payload = {
      'name': _nameController.text.trim(),
      'code': _codeController.text.trim().isNotEmpty ? _codeController.text.trim() : 'SH-${_nameController.text.trim().substring(0, 3).toUpperCase()}',
      'startTime': _startTimeController.text.trim(),
      'endTime': _endTimeController.text.trim(),
      'breakDurationMinutes': int.tryParse(_breakController.text) ?? 60,
      'lateGracePeriodMinutes': int.tryParse(_graceController.text) ?? 15,
      'halfDayHours': double.tryParse(_halfDayController.text) ?? 4.5,
      'overtimeThresholdHours': double.tryParse(_overtimeController.text) ?? 1.0,
      'category': _category,
      'workingDays': _workingDays,
      'status': _status,
      'description': _descController.text.trim()
    };

    try {
      final apiClient = ref.read(apiClientProvider);
      if (_isEdit && widget.shiftId != null) {
        await apiClient.put('/attendance/shifts/${widget.shiftId}', data: payload);
      } else {
        await apiClient.post('/attendance/shifts', data: payload);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isEdit ? 'Shift updated successfully' : 'Shift created successfully')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving shift: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit Work Shift' : 'Create Work Shift'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Basic Shift Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Shift Name *', border: OutlineInputBorder()),
                validator: (val) => (val == null || val.trim().isEmpty) ? 'Shift name is required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _codeController,
                decoration: const InputDecoration(labelText: 'Shift Code (Optional)', border: OutlineInputBorder(), hintText: 'e.g. SH-GEN'),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _category,
                decoration: const InputDecoration(labelText: 'Shift Category', border: OutlineInputBorder()),
                items: _categories.map((c) => DropdownMenuItem(value: c, child: Text('$c Shift'))).toList(),
                onChanged: (val) => setState(() => _category = val ?? 'Fixed'),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _status,
                decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'ACTIVE', child: Text('Active')),
                  DropdownMenuItem(value: 'INACTIVE', child: Text('Inactive')),
                ],
                onChanged: (val) => setState(() => _status = val ?? 'ACTIVE'),
              ),
              const SizedBox(height: 24),

              const Text('Timings & Grace Period Thresholds', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _startTimeController,
                      decoration: const InputDecoration(labelText: 'Start Time (HH:mm) *', border: OutlineInputBorder()),
                      validator: (val) => (val == null || val.trim().isEmpty) ? 'Start time required' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _endTimeController,
                      decoration: const InputDecoration(labelText: 'End Time (HH:mm) *', border: OutlineInputBorder()),
                      validator: (val) => (val == null || val.trim().isEmpty) ? 'End time required' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _breakController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Break Duration (mins)', border: OutlineInputBorder(), suffixText: 'mins'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _graceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Late Grace (mins)', border: OutlineInputBorder(), suffixText: 'mins'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _halfDayController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Half Day (hrs)', border: OutlineInputBorder(), suffixText: 'hrs'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _overtimeController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Overtime Threshold (hrs)', border: OutlineInputBorder(), suffixText: 'hrs'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              const Text('Working Days Schedule', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: _daysList.map((day) {
                  final isSelected = _workingDays.contains(day);
                  return ChoiceChip(
                    label: Text(day),
                    selected: isSelected,
                    onSelected: (_) => _toggleDay(day),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              const Text('Description & Notes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Description / Guidelines', border: OutlineInputBorder(), hintText: 'Optional notes...'),
              ),
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveShift,
                  icon: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Icon(Icons.check),
                  label: Text(_isSaving ? 'Saving...' : (_isEdit ? 'Save Changes' : 'Create Shift'), style: const TextStyle(fontSize: 16)),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
