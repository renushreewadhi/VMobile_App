import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/errors/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/glass_theme.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/glass_header.dart';
import '../../core/widgets/glass_scaffold.dart';

class AdminShiftFormScreen extends ConsumerStatefulWidget {
  final String? shiftId;
  final Map<String, dynamic>? initialData;

  const AdminShiftFormScreen({super.key, this.shiftId, this.initialData});

  @override
  ConsumerState<AdminShiftFormScreen> createState() => _AdminShiftFormScreenState();
}

class _AdminShiftFormScreenState extends ConsumerState<AdminShiftFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _codeController;
  late TextEditingController _breakController;
  late TextEditingController _graceController;
  late TextEditingController _halfDayController;
  late TextEditingController _overtimeController;
  late TextEditingController _descController;

  String _status = 'ACTIVE';
  String _category = 'Fixed Shift';
  String _startTimeHour = '07';
  String _startTimeMinute = '00';
  String _startTimeAmPm = 'AM';

  String _endTimeHour = '04';
  String _endTimeMinute = '00';
  String _endTimeAmPm = 'PM';

  final List<String> _daysList = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final List<String> _workingDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'];

  bool _isSaving = false;

  bool get _isEdit => widget.shiftId != null || widget.initialData != null;

  @override
  void initState() {
    super.initState();
    final d = widget.initialData ?? {};
    _nameController = TextEditingController(text: d['name']?.toString() ?? '');
    _codeController = TextEditingController(text: d['code']?.toString() ?? 'SH-${(DateTime.now().millisecond % 900 + 100)}');
    _breakController = TextEditingController(text: (d['breakDurationMinutes'] ?? 60).toString());
    _graceController = TextEditingController(text: (d['lateGracePeriodMinutes'] ?? 15).toString());
    _halfDayController = TextEditingController(text: (d['halfDayHours'] ?? 4.5).toString());
    _overtimeController = TextEditingController(text: (d['overtimeThresholdHours'] ?? 1.0).toString());
    _descController = TextEditingController(text: d['description']?.toString() ?? '');

    _status = (d['status'] ?? 'ACTIVE').toString().toUpperCase();
    _category = d['category']?.toString() ?? 'Fixed Shift';

    if (d['startTime'] != null) {
      final parsed = _parseTime12h(d['startTime'].toString());
      _startTimeHour = parsed['hour']!;
      _startTimeMinute = parsed['minute']!;
      _startTimeAmPm = parsed['ampm']!;
    }
    if (d['endTime'] != null) {
      final parsed = _parseTime12h(d['endTime'].toString());
      _endTimeHour = parsed['hour']!;
      _endTimeMinute = parsed['minute']!;
      _endTimeAmPm = parsed['ampm']!;
    }

    if (d['workingDays'] is List) {
      _workingDays.clear();
      _workingDays.addAll((d['workingDays'] as List).map((e) => e.toString()));
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _breakController.dispose();
    _graceController.dispose();
    _halfDayController.dispose();
    _overtimeController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Map<String, String> _parseTime12h(String timeStr) {
    try {
      final str = timeStr.trim().toUpperCase();
      String ampm = str.contains('PM') ? 'PM' : 'AM';
      final clean = str.replaceAll(RegExp(r'AM|PM', caseSensitive: false), '').trim();
      final parts = clean.split(':');
      int h = int.parse(parts[0]);
      int m = parts.length > 1 ? int.parse(parts[1].substring(0, 2)) : 0;
      return {
        'hour': h.toString().padLeft(2, '0'),
        'minute': m.toString().padLeft(2, '0'),
        'ampm': ampm,
      };
    } catch (_) {
      return {'hour': '07', 'minute': '00', 'ampm': 'AM'};
    }
  }

  void _toggleDay(String day) {
    setState(() {
      if (_workingDays.contains(day)) {
        if (_workingDays.length > 1) _workingDays.remove(day);
      } else {
        _workingDays.add(day);
      }
    });
  }

  Future<void> _saveShift() async {
    if (!_formKey.currentState!.validate() || _isSaving) return;
    if (_workingDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select at least one working day.'), backgroundColor: Colors.red));
      return;
    }

    setState(() => _isSaving = true);
    final apiClient = ref.read(apiClientProvider);

    final startTime = '$_startTimeHour:$_startTimeMinute $_startTimeAmPm';
    final endTime = '$_endTimeHour:$_endTimeMinute $_endTimeAmPm';

    final payload = {
      'name': _nameController.text.trim(),
      'code': _codeController.text.trim(),
      'startTime': startTime,
      'endTime': endTime,
      'breakDurationMinutes': int.tryParse(_breakController.text.trim()) ?? 60,
      'lateGracePeriodMinutes': int.tryParse(_graceController.text.trim()) ?? 15,
      'halfDayHours': double.tryParse(_halfDayController.text.trim()) ?? 4.5,
      'overtimeThresholdHours': double.tryParse(_overtimeController.text.trim()) ?? 1.0,
      'category': _category,
      'workingDays': [..._workingDays],
      'status': _status,
      'description': _descController.text.trim(),
    };

    try {
      if (widget.shiftId != null) {
        await apiClient.put('${ApiEndpoints.shifts}/${widget.shiftId}', body: payload);
      } else {
        await apiClient.post(ApiEndpoints.shifts, body: payload);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isEdit ? 'Shift updated successfully' : 'Shift created successfully')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        final msg = e is ApiException ? e.message : 'Failed to save shift.';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final cardBgColor = dark ? AppColors.darkMainSurface : Colors.white;

    return GlassScaffold(
      appBar: GlassHeader(
        title: _isEdit ? 'Edit Work Shift' : 'Create New Work Shift',
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Top Hero Header Banner
              _buildHeroHeaderBanner(),
              const SizedBox(height: 18),

              // Section 1: Basic Shift Details
              _buildCardSection(
                cardBgColor: cardBgColor,
                icon: Icons.tune_rounded,
                iconBg: const Color(0xFFE0EDFF),
                iconColor: const Color(0xFF2563EB),
                title: 'Basic Shift Details',
                subtitle: 'Define shift name, identification code, and category',
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildInputField('Shift Name *', _nameController, Icons.badge_outlined, 'e.g. Morning Shift', validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildInputField('Shift Code *', _codeController, Icons.code_rounded, 'e.g. SH-01', validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildDropdownField('Shift Category', _category, ['Fixed Shift', 'Rotational', 'Flexible', 'Split'], (val) => setState(() => _category = val ?? 'Fixed Shift'), Icons.category_outlined),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildDropdownField('Status', _status, ['ACTIVE', 'INACTIVE'], (val) => setState(() => _status = val ?? 'ACTIVE'), Icons.toggle_on_outlined, isStatus: true),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Section 2: Timings & Grace Period Thresholds
              _buildCardSection(
                cardBgColor: cardBgColor,
                icon: Icons.access_time_rounded,
                iconBg: const Color(0xFFFEF3C7),
                iconColor: const Color(0xFFD97706),
                title: 'Timings & Grace Period Thresholds',
                subtitle: 'Set clock-in / clock-out times, break durations, and late grace rules',
                children: [
                  const Text('Clock In / Start Time *', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTimeDropdown(_startTimeHour, List.generate(12, (i) => (i + 1).toString().padLeft(2, '0')), (val) => setState(() => _startTimeHour = val ?? '07')),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _buildTimeDropdown(_startTimeMinute, ['00', '15', '30', '45'], (val) => setState(() => _startTimeMinute = val ?? '00')),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _buildTimeDropdown(_startTimeAmPm, ['AM', 'PM'], (val) => setState(() => _startTimeAmPm = val ?? 'AM')),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('Start Time: $_startTimeHour:$_startTimeMinute $_startTimeAmPm', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF9333EA))),
                  const SizedBox(height: 16),

                  const Text('Clock Out / End Time *', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTimeDropdown(_endTimeHour, List.generate(12, (i) => (i + 1).toString().padLeft(2, '0')), (val) => setState(() => _endTimeHour = val ?? '04')),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _buildTimeDropdown(_endTimeMinute, ['00', '15', '30', '45'], (val) => setState(() => _endTimeMinute = val ?? '00')),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _buildTimeDropdown(_endTimeAmPm, ['AM', 'PM'], (val) => setState(() => _endTimeAmPm = val ?? 'PM')),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('End Time: $_endTimeHour:$_endTimeMinute $_endTimeAmPm', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF9333EA))),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: _buildInputField('Break Duration (Minutes)', _breakController, Icons.coffee_outlined, '60', isNumber: true, suffixText: 'mins'),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildInputField('Late Grace Period (Mins)', _graceController, Icons.timer_outlined, '15', isNumber: true, suffixText: 'mins'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: _buildInputField('Half Day Threshold (Hrs)', _halfDayController, Icons.hourglass_bottom_rounded, '4.5', isNumber: true, suffixText: 'hrs'),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildInputField('Overtime Min Threshold', _overtimeController, Icons.more_time_rounded, '1.0', isNumber: true, suffixText: 'hrs'),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Section 3: Working Days Schedule
              _buildCardSection(
                cardBgColor: cardBgColor,
                icon: Icons.calendar_month_rounded,
                iconBg: const Color(0xFFDCFCE7),
                iconColor: const Color(0xFF16A34A),
                title: 'Working Days Schedule',
                subtitle: 'Select active working days for this shift',
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _daysList.map((day) {
                      final isSelected = _workingDays.contains(day);
                      return InkWell(
                        onTap: _isSaving ? null : () => _toggleDay(day),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFFDCFCE7) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: isSelected ? const Color(0xFF16A34A) : const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                size: 16,
                                color: isSelected ? const Color(0xFF16A34A) : const Color(0xFF94A3B8),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                day,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                  color: isSelected ? const Color(0xFF16A34A) : const Color(0xFF334155),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Section 4: Description & Notes
              _buildCardSection(
                cardBgColor: cardBgColor,
                icon: Icons.description_outlined,
                iconBg: const Color(0xFFF3E8FF),
                iconColor: const Color(0xFF9333EA),
                title: 'Description & Notes',
                subtitle: 'Provide optional guidelines for employees assigned to this shift',
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: TextFormField(
                      controller: _descController,
                      enabled: !_isSaving,
                      maxLines: 3,
                      style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A), fontWeight: FontWeight.w500),
                      decoration: const InputDecoration(
                        hintText: 'e.g. Standard morning shift from 07:00 AM to 04:00 PM with 1 hour lunch break...',
                        hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Bottom Actions Navigation Bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: _isSaving ? null : () => Navigator.pop(context),
                    child: const Text('Cancel', style: TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
                  ),
                  ElevatedButton.icon(
                    onPressed: _isSaving ? null : _saveShift,
                    icon: _isSaving
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.check_rounded, size: 18),
                    label: Text(_isEdit ? 'Update Shift' : 'Create Shift'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroHeaderBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF2FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E7FF)),
        boxShadow: const [BoxShadow(color: Color.fromRGBO(99, 102, 241, 0.05), blurRadius: 20, offset: Offset(0, 4))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0EDFF),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'SHIFT CONFIGURATION',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF2563EB), letterSpacing: 0.5),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _isEdit ? 'Edit Work Shift' : 'Create New Work Shift',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF0F172A), letterSpacing: -0.5),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Define working hours, grace periods, half-day thresholds, and shift schedules.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: const [BoxShadow(color: Color.fromRGBO(37, 99, 235, 0.06), blurRadius: 10, offset: Offset(0, 2))],
            ),
            child: Column(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.access_time_rounded, color: Color(0xFFD97706), size: 20),
                ),
                const SizedBox(height: 6),
                const Text('Schedule & Rules', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                const SizedBox(height: 2),
                Container(width: 32, height: 3, decoration: BoxDecoration(color: const Color(0xFFD97706), borderRadius: BorderRadius.circular(2))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardSection({
    required Color cardBgColor,
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: const [BoxShadow(color: Color.fromRGBO(15, 23, 42, 0.03), blurRadius: 16, offset: Offset(0, 4))],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInputField(String label, TextEditingController controller, IconData icon, String hint, {bool isNumber = false, String? suffixText, FormFieldValidator<String>? validator}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Icon(icon, size: 18, color: const Color(0xFF64748B)),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: controller,
                  enabled: !_isSaving,
                  keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
                  style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A), fontWeight: FontWeight.w500),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                    suffixText: suffixText,
                    suffixStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                    border: InputBorder.none,
                  ),
                  validator: validator,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField(String label, String selectedValue, List<String> options, ValueChanged<String?> onChanged, IconData icon, {bool isStatus = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Icon(icon, size: 18, color: const Color(0xFF64748B)),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: options.contains(selectedValue) ? selectedValue : (options.isNotEmpty ? options.first : null),
                    isExpanded: true,
                    style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A), fontWeight: FontWeight.w500),
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B)),
                    items: options.map((opt) {
                      final displayLabel = isStatus ? (opt == 'ACTIVE' ? 'Active' : 'Inactive') : opt;
                      return DropdownMenuItem<String>(value: opt, child: Text(displayLabel));
                    }).toList(),
                    onChanged: _isSaving ? null : onChanged,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTimeDropdown(String selectedValue, List<String> options, ValueChanged<String?> onChanged) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: options.contains(selectedValue) ? selectedValue : options.first,
          isExpanded: true,
          style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A), fontWeight: FontWeight.bold),
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF64748B)),
          items: options.map((opt) => DropdownMenuItem(value: opt, child: Text(opt))).toList(),
          onChanged: _isSaving ? null : onChanged,
        ),
      ),
    );
  }
}
