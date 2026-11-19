import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/api/leave_service.dart';
import '../../core/auth/auth_service.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/loading_shimmer.dart';
import '../../core/widgets/glass_scaffold.dart';

class ApplyLeaveScreen extends ConsumerStatefulWidget {
  const ApplyLeaveScreen({super.key});

  @override
  ConsumerState<ApplyLeaveScreen> createState() => _ApplyLeaveScreenState();
}

class _ApplyLeaveScreenState extends ConsumerState<ApplyLeaveScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _companyEmailController = TextEditingController();
  final _contactPhoneController = TextEditingController();
  final _reasonController = TextEditingController();

  String _selectedLeaveTypeKey = 'Sick Leave';
  String _selectedDuration = 'Full Day(s)';
  DateTime? _startDate;
  DateTime? _endDate;

  bool _loadingBalances = true;
  bool _submitting = false;
  String? _error;

  Map<String, String> _leaveTypeOptions = {};

  static const List<String> _durationOptions = [
    'Full Day(s)',
    'Half Day (First Half)',
    'Half Day (Second Half)',
  ];

  late final AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    final user = ref.read(authServiceProvider).user;
    if (user != null) {
      _companyEmailController.text = user.email;
    }
    _loadBalances();
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _companyEmailController.dispose();
    _contactPhoneController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  String _normalizeBalanceType(String rawType) {
    if (rawType.isEmpty) return 'Leave';
    final clean = rawType.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '_');
    if (clean.contains('PAID_HOLIDAY') || clean == 'PAID') return 'Paid Leave';
    if (clean.contains('EARNED')) return 'Earned Leave';
    if (clean.contains('COMPENSATORY') || clean.contains('COMP')) return 'Compensatory Leave';
    if (clean.contains('CASUAL')) return 'Casual Leave';
    if (clean.contains('SICK')) return 'Sick Leave';
    if (clean.contains('UNPAID')) return 'Unpaid Leave';
    if (clean.contains('PERSONAL')) return 'Personal Leave';
    return rawType.replaceAll('_', ' ');
  }

  bool _isExcludedBalanceType(String rawType) {
    if (rawType.isEmpty) return false;
    final clean = rawType.trim().toUpperCase();
    return clean.contains('BEREAVEMENT') || clean.contains('MATERNITY') || clean.contains('PATERNITY');
  }

  Future<void> _loadBalances() async {
    setState(() {
      _loadingBalances = true;
      _error = null;
    });
    final leaveService = ref.read(leaveServiceProvider);
    final mappedBalances = <String, Map<String, dynamic>>{};

    try {
      final res = await leaveService.getLeaveBalances();
      if (mounted && res != null) {
        List<dynamic> rawBalances = [];
        if (res is List) {
          rawBalances = res;
        } else if (res is Map<String, dynamic> && res['data'] is List) {
          rawBalances = res['data'];
        }

        for (final b in rawBalances) {
          if (b is Map) {
            final rawType = (b['leaveType'] ?? b['type'] ?? '').toString();
            if (_isExcludedBalanceType(rawType)) continue;

            final normName = _normalizeBalanceType(rawType);
            final total = int.tryParse(b['entitled']?.toString() ?? b['total']?.toString() ?? '0') ?? 0;
            final used = int.tryParse(b['taken']?.toString() ?? b['used']?.toString() ?? '0') ?? 0;
            final rem = (b['remaining'] != null)
                ? (int.tryParse(b['remaining'].toString()) ?? 0)
                : (total - used).clamp(0, 9999);

            mappedBalances[normName] = {
              'key': normName,
              'rawType': rawType.isNotEmpty ? rawType : normName,
              'remaining': rem < 0 ? 0 : rem,
              'display': '$normName ($rem days remaining)',
            };
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load leave balances: $e';
        });
      }
    }

    // Fallback & standard HR leave types to ensure dropdown is always populated
    final standardTypes = [
      'Sick Leave',
      'Casual Leave',
      'Paid Leave',
      'Earned Leave',
      'Compensatory Leave',
      'Unpaid Leave',
      'Personal Leave',
    ];

    final updatedOptions = <String, String>{};
    for (final st in standardTypes) {
      if (mappedBalances.containsKey(st)) {
        updatedOptions[st] = mappedBalances[st]!['display'] as String;
      } else {
        updatedOptions[st] = st;
      }
    }

    for (final entry in mappedBalances.entries) {
      if (!updatedOptions.containsKey(entry.key)) {
        updatedOptions[entry.key] = entry.value['display'] as String;
      }
    }

    if (mounted) {
      setState(() {
        _leaveTypeOptions = updatedOptions;
        if (_leaveTypeOptions.isNotEmpty && !_leaveTypeOptions.containsKey(_selectedLeaveTypeKey)) {
          _selectedLeaveTypeKey = _leaveTypeOptions.keys.first;
        }
        _loadingBalances = false;
      });
    }
  }

  double get _calculatedTotalDays {
    if (_startDate == null) return 0;
    if (_selectedDuration != 'Full Day(s)') return 0.5;
    if (_endDate == null) return 1;
    final diff = _endDate!.difference(_startDate!).inDays + 1;
    return diff < 1 ? 0 : diff.toDouble();
  }

  String get _totalDaysFormatted {
    final days = _calculatedTotalDays;
    if (days == 0) return '0 Days';
    if (days == 0.5) return '0.5 Day';
    if (days == 1) return '1 Day';
    return '${days.toInt()} Days';
  }

  String _formatMmDdYyyy(DateTime? date) {
    if (date == null) return 'mm/dd/yyyy';
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$month/$day/${date.year}';
  }

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final initial = isStart ? (_startDate ?? now) : (_endDate ?? _startDate ?? now);
    final first = isStart ? DateTime(now.year - 1) : (_startDate ?? DateTime(now.year - 1));

    final selected = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(first) ? first : initial,
      firstDate: first,
      lastDate: DateTime(now.year + 2),
    );

    if (selected == null || !mounted) return;

    setState(() {
      if (isStart) {
        _startDate = selected;
        if (_endDate != null && _endDate!.isBefore(selected)) {
          _endDate = selected;
        }
      } else {
        _endDate = selected;
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_startDate == null) {
      _message('Please select a Start Date.');
      return;
    }
    if (_selectedDuration == 'Full Day(s)' && _endDate == null) {
      _message('Please select an End Date.');
      return;
    }
    if (_selectedDuration == 'Full Day(s)' && _endDate!.isBefore(_startDate!)) {
      _message('End Date cannot be before Start Date.');
      return;
    }
    if (_leaveTypeOptions.isEmpty || !_leaveTypeOptions.containsKey(_selectedLeaveTypeKey)) {
      _message('Leave balances are unavailable or selected leave type is invalid.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    final summaryDays = _totalDaysFormatted;
    final effectiveEndDate = _selectedDuration != 'Full Day(s)' ? _startDate! : _endDate!;
    final email = _companyEmailController.text.trim();
    final contact = _contactPhoneController.text.trim();
    final rawReason = _reasonController.text.trim();

    final normalizedType = _selectedLeaveTypeKey.toUpperCase().replaceAll(' ', '_');

    final payload = <String, dynamic>{
      'leaveType': _selectedLeaveTypeKey,
      'type': normalizedType,
      'duration': _selectedDuration,
      'startDate': _startDate!.toIso8601String(),
      'endDate': effectiveEndDate.toIso8601String(),
      'companyEmail': email,
      'contactPhone': contact,
      'reason': rawReason,
    };

    final leaveService = ref.read(leaveServiceProvider);

    try {
      await leaveService.applyLeave(payload);

      if (!mounted) return;

      setState(() {
        _submitting = false;
        _startDate = null;
        _endDate = null;
        _reasonController.clear();
      });

      _showSuccessDialog(summaryDays);
    } catch (e) {
      if (!mounted) return;

      final err = e.toString().replaceFirst('ApiException: ', '').replaceFirst('Exception: ', '');
      setState(() {
        _submitting = false;
        _error = err;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to submit leave request: $err'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  void _showSuccessDialog(String totalDays) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkMainSurface : AppColors.lightMainSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Row(
          children: [
            Icon(
              Icons.check_circle_rounded,
              color: AppColors.success,
              size: 28,
            ),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Leave Request Submitted!',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'Your request for $_selectedLeaveTypeKey ($totalDays) has been submitted successfully for manager approval.',
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.lightSecondaryText,
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'OK',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _message(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
      );
  }

  Widget _label(bool dark, String label, {bool isMandatory = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              color: dark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (isMandatory)
            const Text(
              ' *',
              style: TextStyle(
                color: Colors.redAccent,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(bool dark, String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: dark ? AppColors.darkMutedText : const Color(0xFF94A3B8), fontSize: 13),
      filled: true,
      fillColor: dark ? AppColors.darkMainSurface : Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: dark ? AppColors.darkBordersAndDividers : const Color(0xFFE5E7EB), width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: dark ? AppColors.darkBordersAndDividers : const Color(0xFFE5E7EB), width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      errorStyle: const TextStyle(fontSize: 11),
    );
  }

  Widget _datePickerTile(bool dark, DateTime? date, VoidCallback onTap) {
    final isSelected = date != null;
    return Material(
      color: dark ? AppColors.darkMainSurface : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: dark ? AppColors.darkBordersAndDividers : const Color(0xFFE5E7EB), width: 1),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _formatMmDdYyyy(date),
                  style: TextStyle(
                    color: isSelected ? (dark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText) : (dark ? AppColors.darkMutedText : const Color(0xFF94A3B8)),
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
                  ),
                ),
              ),
              const Icon(
                Icons.calendar_today_rounded,
                size: 18,
                color: AppColors.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final formContent = Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (_loadingBalances)
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      ),
                  ],
                ),
                const Text(
                  '* Mandatory fields',
                  style: TextStyle(
                    color: Color.fromRGBO(220, 38, 38, 0.8),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 14),

                // Group 1: Leave Type & Duration
                _label(isDark, 'Leave Type', isMandatory: true),
                Builder(
                  builder: (context) {
                    if (_loadingBalances) {
                      return Container(
                        height: 48,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: darkBorder(isDark)),
                        ),
                        child: const Row(
                          children: [
                            SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                            SizedBox(width: 12),
                            Text('Loading available leave balances...', style: TextStyle(fontSize: 13)),
                          ],
                        ),
                      );
                    }

                    if (_leaveTypeOptions.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'No leave balances available or server unavailable.',
                              style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 8),
                            TextButton.icon(
                              onPressed: _loadBalances,
                              icon: const Icon(Icons.refresh_rounded, size: 16),
                              label: const Text('Retry Loading Balances'),
                            ),
                          ],
                        ),
                      );
                    }

                    final validLeaveTypeValue = _leaveTypeOptions.containsKey(_selectedLeaveTypeKey)
                        ? _selectedLeaveTypeKey
                        : _leaveTypeOptions.keys.first;

                    return SizedBox(
                      height: 48,
                      child: DropdownButtonFormField<String>(
                        value: validLeaveTypeValue,
                        isExpanded: true,
                        dropdownColor: isDark ? AppColors.darkMainSurface : Colors.white,
                        style: TextStyle(
                          color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: _inputDecoration(isDark, 'Select leave type').copyWith(
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: isDark ? AppColors.darkBordersAndDividers : const Color(0xFFE5E7EB), width: 1),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                          ),
                        ),
                        icon: const Icon(Icons.arrow_drop_down_rounded, color: AppColors.primary, size: 20),
                        items: _leaveTypeOptions.entries
                            .map(
                              (entry) => DropdownMenuItem<String>(
                                value: entry.key,
                                child: Text(
                                  entry.value,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedLeaveTypeKey = val);
                          }
                        },
                      ),
                    );
                  },
                ),
                const SizedBox(height: 14),

                _label(isDark, 'Duration', isMandatory: true),
                SizedBox(
                  height: 48,
                  child: DropdownButtonFormField<String>(
                    value: _selectedDuration,
                    dropdownColor: isDark ? AppColors.darkMainSurface : Colors.white,
                    style: TextStyle(
                      color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: _inputDecoration(isDark, 'Select duration'),
                    icon: const Icon(Icons.arrow_drop_down_rounded, color: AppColors.primary, size: 20),
                    items: _durationOptions
                        .map(
                          (opt) => DropdownMenuItem(
                            value: opt,
                            child: Text(opt),
                          ),
                        )
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedDuration = val);
                      }
                    },
                  ),
                ),
                const SizedBox(height: 22),

                // Group 2: Start Date & End Date side by side + Total Days
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label(isDark, 'Start Date', isMandatory: true),
                          _datePickerTile(
                            isDark,
                            _startDate,
                            () => _pickDate(isStart: true),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label(isDark, 'End Date', isMandatory: true),
                          _datePickerTile(
                            isDark,
                            _selectedDuration != 'Full Day(s)' ? _startDate : _endDate,
                            _selectedDuration != 'Full Day(s)' ? () {} : () => _pickDate(isStart: false),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                _label(isDark, 'Total Days'),
                TweenAnimationBuilder<double>(
                  key: ValueKey(_totalDaysFormatted),
                  tween: Tween(begin: 0.92, end: 1.0),
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutBack,
                  builder: (context, scale, child) => Transform.scale(
                    scale: scale,
                    child: child,
                  ),
                  child: Container(
                    height: 46,
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    alignment: Alignment.centerLeft,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE6F4F1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0x260D6E64), width: 1),
                    ),
                    child: Text(
                      _totalDaysFormatted,
                      style: TextStyle(
                        color: _calculatedTotalDays > 0 ? const Color(0xFF0F5F57) : const Color(0xFF0F5F57).withOpacity(0.7),
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 22),

                // Group 3: Contact Details
                _label(isDark, 'Company Mail ID', isMandatory: true),
                SizedBox(
                  height: 48,
                  child: TextFormField(
                    controller: _companyEmailController,
                    keyboardType: TextInputType.emailAddress,
                    style: TextStyle(
                      color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: _inputDecoration(isDark, 'emp@company.com'),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Company Mail ID is required';
                      }
                      if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(val.trim())) {
                        return 'Enter a valid email address';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 14),

                _label(isDark, 'Contact During Leave'),
                SizedBox(
                  height: 48,
                  child: TextFormField(
                    controller: _contactPhoneController,
                    keyboardType: TextInputType.phone,
                    style: TextStyle(
                      color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: _inputDecoration(isDark, '+91 98765 43210'),
                  ),
                ),
                const SizedBox(height: 22),

                // Group 4: Reason for Leave
                _label(isDark, 'Reason for Leave', isMandatory: true),
                TextFormField(
                  controller: _reasonController,
                  minLines: 3,
                  maxLines: 4,
                  style: TextStyle(
                    color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText,
                    fontSize: 14,
                    height: 1.5,
                  ),
                  decoration: _inputDecoration(isDark, 'Provide context or description for your manager...'),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter a reason for your leave';
                    }
                    return null;
                  },
                ),

                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    final scrollContent = SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: formContent,
    );

    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final stickyBottomBar = Positioned(
      left: 0,
      right: 0,
      bottom: bottomInset,
      child: Container(
        padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.paddingOf(context).bottom + 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              (isDark ? AppColors.darkAppBackground : AppColors.lightAppBackground).withOpacity(0.0),
              (isDark ? AppColors.darkAppBackground : AppColors.lightAppBackground).withOpacity(0.95),
              (isDark ? AppColors.darkAppBackground : AppColors.lightAppBackground),
            ],
            stops: const [0.0, 0.4, 1.0],
          ),
        ),
        child: SizedBox(
          height: 50,
          width: double.infinity,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(14),
              boxShadow: const [
                BoxShadow(
                  color: Color.fromRGBO(13, 110, 100, 0.22),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              onPressed: (_loadingBalances || _leaveTypeOptions.isEmpty || _submitting) ? null : _submit,
              icon: _submitting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check_circle_outline_rounded, size: 18, color: Colors.white),
              label: Text(
                _submitting ? 'Submitting...' : 'Submit Leave Request',
                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ),
      ),
    );

    return GlassScaffold(
      title: 'Leave Request Form',
      body: SafeArea(
        child: Stack(
          children: [
            scrollContent,
            stickyBottomBar,
          ],
        ),
      ),
    );
  }

  Color darkBorder(bool isDark) => isDark ? AppColors.darkBordersAndDividers : const Color(0xFFE5E7EB);
}
