import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/loading_shimmer.dart';
import '../../shared/widgets/status_chip.dart';
import 'break_logs_screen.dart';
import 'punch_in_out_screen.dart';

class BreakTypeOption {
  final String typeKey;
  final String name;
  final int maxMinutes;
  final IconData icon;
  final Color bgColor;
  final Color iconColor;
  final String maxDisplay;

  const BreakTypeOption({
    required this.typeKey,
    required this.name,
    required this.maxMinutes,
    required this.icon,
    required this.bgColor,
    required this.iconColor,
    required this.maxDisplay,
  });
}

class BreakLogRow {
  final String? id;
  final String type;
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String startTime;
  final String endTime;
  final int durationMins;
  final int durationSeconds;
  final String durationDisplay;
  final String status; // 'Completed' | 'In Progress'
  final DateTime? rawStartTime;
  final int maxMinutes;

  BreakLogRow({
    this.id,
    required this.type,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.startTime,
    required this.endTime,
    required this.durationMins,
    required this.durationSeconds,
    required this.durationDisplay,
    required this.status,
    this.rawStartTime,
    required this.maxMinutes,
  });
}

class CalendarDayItem {
  final DateTime date;
  final String dateIso;
  final int dayNum;
  final bool isCurrentMonth;
  final bool isToday;
  final bool isSelected;
  final bool isFuture;

  CalendarDayItem({
    required this.date,
    required this.dateIso,
    required this.dayNum,
    required this.isCurrentMonth,
    required this.isToday,
    required this.isSelected,
    required this.isFuture,
  });
}

class BreakTrackerScreen extends ConsumerStatefulWidget {
  final bool showAppBar;
  const BreakTrackerScreen({super.key, this.showAppBar = false});

  @override
  ConsumerState<BreakTrackerScreen> createState() => _BreakTrackerScreenState();
}

class _BreakTrackerScreenState extends ConsumerState<BreakTrackerScreen> {
  String _selectedBreakType = 'Tea Break';

  Map<String, dynamic>? _activeBreak;
  int _elapsedSeconds = 0;
  Timer? _timerInterval;

  List<BreakLogRow> _todayBreaks = [];
  final Set<String> _datesWithBreaks = {};

  final List<BreakTypeOption> _breakTypes = const [
    BreakTypeOption(
      typeKey: 'tea',
      name: 'Tea Break',
      maxMinutes: 15,
      icon: Icons.coffee_rounded,
      bgColor: Color(0xFFFFF7ED),
      iconColor: Color(0xFFF59E0B),
      maxDisplay: 'Max 15m',
    ),
    BreakTypeOption(
      typeKey: 'lunch',
      name: 'Lunch Break',
      maxMinutes: 60,
      icon: Icons.restaurant_rounded,
      bgColor: Color(0xFFF0FDF4),
      iconColor: Color(0xFF10B981),
      maxDisplay: 'Max 60m',
    ),
    BreakTypeOption(
      typeKey: 'personal',
      name: 'Personal Break',
      maxMinutes: 30,
      icon: Icons.person_pin_rounded,
      bgColor: Color(0xFFFAF5FF),
      iconColor: Color(0xFF2563EB),
      maxDisplay: 'Max 30m',
    ),
    BreakTypeOption(
      typeKey: 'short',
      name: 'Short Break',
      maxMinutes: 10,
      icon: Icons.access_time_rounded,
      bgColor: Color(0xFFF0F9FF),
      iconColor: Color(0xFF0284C7),
      maxDisplay: 'Max 10m',
    ),
  ];

  double _totalBreakMins = 0;
  double _allowedBreakMins = 60;

  String _selectedDateIso = '';
  bool _showCalendarModal = false;
  int _calendarYear = DateTime.now().year;
  int _calendarMonth = DateTime.now().month - 1;
  List<CalendarDayItem> _calendarDays = [];

  bool _isCheckedIn = false;
  bool _isCheckedOut = false;
  bool _hasCheckedInToday = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedDateIso = _getTodayIso();
    _loadForSelectedDate();
  }

  @override
  void dispose() {
    _timerInterval?.cancel();
    super.dispose();
  }

  String _getTodayIso() {
    final d = DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  bool get _isTodaySelected => _selectedDateIso == _getTodayIso();

  String _formatDuration(int seconds) {
    if (seconds < 60) return '<1 min';
    final totalMins = seconds ~/ 60;
    if (totalMins < 60) return '$totalMins mins';
    final hours = totalMins ~/ 60;
    final mins = totalMins % 60;
    return '${hours}h ${mins}m';
  }

  String _formatDurationFromMins(double minutes) {
    final secs = (minutes * 60).round();
    return _formatDuration(secs);
  }

  String get _displaySelectedDate {
    if (_selectedDateIso.isEmpty || _isTodaySelected) return 'Today';
    final parts = _selectedDateIso.split('-');
    if (parts.length != 3) return 'Today';
    final y = int.tryParse(parts[0]) ?? DateTime.now().year;
    final m = int.tryParse(parts[1]) ?? DateTime.now().month;
    final d = int.tryParse(parts[2]) ?? DateTime.now().day;
    final dt = DateTime(y, m, d);
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  BreakTypeOption get _selectedTypeObj {
    return _breakTypes.firstWhere(
      (b) => b.name.toLowerCase() == _selectedBreakType.toLowerCase(),
      orElse: () => _breakTypes[0],
    );
  }

  String get _totalBreakFormatted {
    return _formatDurationFromMins(_totalBreakMins);
  }

  bool get _isOverLimit => _totalBreakMins > _allowedBreakMins;

  int get _remainingMins {
    return (_allowedBreakMins - _totalBreakMins).round().clamp(0, 999);
  }

  void _selectBreakType(String name) {
    if (_activeBreak != null) return;
    setState(() => _selectedBreakType = name);
  }

  int _countForType(String name) {
    return _todayBreaks.where((b) => b.type.toLowerCase() == name.toLowerCase()).length;
  }

  Future<void> _loadForSelectedDate([String? dateIso]) async {
    if (dateIso != null) {
      setState(() => _selectedDateIso = dateIso);
    }
    setState(() => _isLoading = true);

    final apiClient = ref.read(apiClientProvider);
    try {
      final record = await apiClient.get(ApiEndpoints.attendanceToday, queryParams: {'date': _selectedDateIso}).catchError((_) => null);

      if (!mounted) return;
      _applyTodayRecord(record is Map<String, dynamic> ? (record['data'] ?? record) : null);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _todayBreaks = [];
        _totalBreakMins = 0;
        _activeBreak = null;
        _hasCheckedInToday = false;
        _isCheckedIn = false;
        _isCheckedOut = false;
        _isLoading = false;
      });
    }
  }

  void _applyTodayRecord(dynamic record) {
    if (record is! Map || record.isEmpty) {
      setState(() {
        _todayBreaks = [];
        _totalBreakMins = 0;
        _activeBreak = null;
        _isCheckedIn = false;
        _isCheckedOut = false;
        _hasCheckedInToday = false;
        _isLoading = false;
      });
      return;
    }

    _hasCheckedInToday = record['checkIn'] != null;
    _isCheckedIn = record['checkIn'] != null && record['checkOut'] == null;
    _isCheckedOut = record['checkIn'] != null && record['checkOut'] != null;

    if (record['allowedBreakMinutes'] != null && (record['allowedBreakMinutes'] is num)) {
      _allowedBreakMins = (record['allowedBreakMinutes'] as num).toDouble();
    }

    final rawBreaks = record['breaks'] ?? record['breakLogs'] ?? record['breakHistory'];
    if (rawBreaks is! List || rawBreaks.isEmpty) {
      setState(() {
        _todayBreaks = [];
        _totalBreakMins = 0;
        _activeBreak = null;
        _isLoading = false;
      });
      return;
    }

    Map<String, dynamic>? activeItem;
    double totalMins = 0;

    final logs = <BreakLogRow>[];
    for (int i = 0; i < rawBreaks.length; i++) {
      final b = rawBreaks[i];
      if (b is! Map) continue;
      final bMap = Map<String, dynamic>.from(b);
      final typeName = bMap['breakType']?.toString() ?? bMap['type']?.toString() ?? 'Break';
      final config = _breakTypes.firstWhere(
        (t) => t.name.toLowerCase() == typeName.toLowerCase(),
        orElse: () => _breakTypes[0],
      );

      final startStr = bMap['startTime']?.toString();
      final endStr = bMap['endTime']?.toString();
      final startDt = startStr != null ? DateTime.tryParse(startStr)?.toLocal() : null;
      final endDt = endStr != null ? DateTime.tryParse(endStr)?.toLocal() : null;
      final isOngoing = endDt == null;

      if (isOngoing && _isTodaySelected) {
        activeItem = {'b': bMap, 'typeName': typeName, 'config': config, 'startDt': startDt ?? DateTime.now()};
      }

      int durSecs = 0;
      if (bMap['durationMinutes'] != null) {
        durSecs = ((double.tryParse(bMap['durationMinutes'].toString()) ?? 0) * 60).round();
      } else if (startDt != null) {
        final end = endDt ?? DateTime.now();
        durSecs = end.difference(startDt).inSeconds;
      }
      final double durMins = durSecs / 60.0;
      totalMins += durMins;

      logs.add(BreakLogRow(
        id: bMap['id']?.toString() ?? 'brk-$i',
        type: typeName,
        icon: config.icon,
        iconBg: config.bgColor,
        iconColor: config.iconColor,
        startTime: startDt != null ? _formatTimeOnly(startDt) : '--',
        endTime: endDt != null ? _formatTimeOnly(endDt) : '--',
        durationMins: durMins.round(),
        durationSeconds: durSecs,
        durationDisplay: _formatDuration(durSecs),
        status: isOngoing ? 'In Progress' : 'Completed',
        rawStartTime: startDt,
        maxMinutes: config.maxMinutes,
      ));
    }

    if (logs.isNotEmpty) {
      _datesWithBreaks.add(_selectedDateIso);
    }

    setState(() {
      _todayBreaks = logs;
      _totalBreakMins = totalMins;
      if (activeItem != null && _isTodaySelected) {
        _selectedBreakType = activeItem['typeName'];
        final startDt = activeItem['startDt'] as DateTime;
        final startMs = startDt.millisecondsSinceEpoch;
        final nowMs = DateTime.now().millisecondsSinceEpoch;
        final diffSecs = ((nowMs - startMs) / 1000).clamp(0, double.infinity).toInt();

        _activeBreak = {
          'type': activeItem['typeName'],
          'startTime': startDt,
          'startTimeDisplay': _formatTimeOnly(startDt),
          'maxMinutes': (activeItem['config'] as BreakTypeOption).maxMinutes,
        };
        _elapsedSeconds = diffSecs;
        _startTimer();
      } else {
        _activeBreak = null;
        _timerInterval?.cancel();
      }
      _isLoading = false;
    });
  }

  void _startTimer() {
    _timerInterval?.cancel();
    _timerInterval = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _elapsedSeconds++);
    });
  }

  String _formatTimeOnly(DateTime d) {
    final hour = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final minute = d.minute.toString().padLeft(2, '0');
    final ampm = d.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $ampm';
  }

  Future<void> _startBreak([String? typeName]) async {
    if (!_isTodaySelected) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Breaks can only be recorded for today.')));
      return;
    }
    if (!_hasCheckedInToday) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You cannot take a break without checking in first.')));
      return;
    }
    if (_isCheckedOut) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You have already checked out for today.')));
      return;
    }
    if (_todayBreaks.length >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Maximum 3 breaks per day allowed.')));
      return;
    }
    if (_totalBreakMins >= _allowedBreakMins) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Daily break limit reached.')));
      return;
    }

    final targetType = typeName ?? _selectedBreakType;
    final config = _breakTypes.firstWhere(
      (b) => b.name.toLowerCase() == targetType.toLowerCase(),
      orElse: () => _breakTypes[0],
    );
    final now = DateTime.now();

    setState(() {
      _activeBreak = {
        'type': targetType,
        'startTime': now,
        'startTimeDisplay': _formatTimeOnly(now),
        'maxMinutes': config.maxMinutes,
      };
      _elapsedSeconds = 0;
    });
    _startTimer();

    final apiClient = ref.read(apiClientProvider);
    try {
      await apiClient.post(ApiEndpoints.breakStart, body: {'breakType': targetType});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$targetType started. Enjoy your rest!')));
      _loadForSelectedDate();
    } catch (e) {
      if (!mounted) return;
      final err = e.toString().replaceFirst("ApiException: ", "").replaceFirst("Exception: ", "");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      _loadForSelectedDate();
    }
  }

  Future<void> _stopBreak() async {
    if (_activeBreak == null) return;
    _timerInterval?.cancel();

    final apiClient = ref.read(apiClientProvider);
    try {
      await apiClient.post(ApiEndpoints.breakEnd, body: {});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Welcome back! Break ended.')));
      setState(() {
        _activeBreak = null;
        _elapsedSeconds = 0;
      });
      _loadForSelectedDate();
    } catch (e) {
      if (!mounted) return;
      final err = e.toString().replaceFirst("ApiException: ", "").replaceFirst("Exception: ", "");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      _loadForSelectedDate();
    }
  }

  void _toggleCalendarModal() {
    setState(() {
      _showCalendarModal = !_showCalendarModal;
      if (_showCalendarModal) {
        if (_selectedDateIso.isNotEmpty) {
          final parts = _selectedDateIso.split('-');
          if (parts.length == 3) {
            _calendarYear = int.parse(parts[0]);
            _calendarMonth = int.parse(parts[1]) - 1;
          }
        }
        _generateCalendarGrid();
      }
    });
  }

  String get _monthYearHeader {
    final d = DateTime(_calendarYear, _calendarMonth + 1, 1);
    const months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    return '${months[d.month - 1]} ${d.year}';
  }

  void _generateCalendarGrid() {
    final firstDayOfMonth = DateTime(_calendarYear, _calendarMonth + 1, 1);
    final lastDayOfMonth = DateTime(_calendarYear, _calendarMonth + 2, 0);

    // Mon = 0 ... Sun = 6
    final startDayOfWeek = firstDayOfMonth.weekday - 1;
    final now = DateTime.now();
    final todayIso = _getTodayIso();

    final days = <CalendarDayItem>[];
    final prevMonthLastDay = DateTime(_calendarYear, _calendarMonth + 1, 0).day;
    for (int i = startDayOfWeek - 1; i >= 0; i--) {
      final dayNum = prevMonthLastDay - i;
      final d = DateTime(_calendarYear, _calendarMonth, dayNum);
      final dateIso = _formatDateToIso(d);
      days.add(CalendarDayItem(
        date: d,
        dateIso: dateIso,
        dayNum: dayNum,
        isCurrentMonth: false,
        isToday: dateIso == todayIso,
        isSelected: dateIso == _selectedDateIso,
        isFuture: d.isAfter(DateTime(now.year, now.month, now.day, 23, 59, 59)),
      ));
    }

    for (int dayNum = 1; dayNum <= lastDayOfMonth.day; dayNum++) {
      final d = DateTime(_calendarYear, _calendarMonth + 1, dayNum);
      final dateIso = _formatDateToIso(d);
      days.add(CalendarDayItem(
        date: d,
        dateIso: dateIso,
        dayNum: dayNum,
        isCurrentMonth: true,
        isToday: dateIso == todayIso,
        isSelected: dateIso == _selectedDateIso,
        isFuture: d.isAfter(DateTime(now.year, now.month, now.day, 23, 59, 59)),
      ));
    }

    final totalCells = (startDayOfWeek + lastDayOfMonth.day) > 35 ? 42 : 35;
    final remaining = totalCells - days.length;
    for (int dayNum = 1; dayNum <= remaining; dayNum++) {
      final d = DateTime(_calendarYear, _calendarMonth + 2, dayNum);
      final dateIso = _formatDateToIso(d);
      days.add(CalendarDayItem(
        date: d,
        dateIso: dateIso,
        dayNum: dayNum,
        isCurrentMonth: false,
        isToday: dateIso == todayIso,
        isSelected: dateIso == _selectedDateIso,
        isFuture: d.isAfter(DateTime(now.year, now.month, now.day, 23, 59, 59)),
      ));
    }

    setState(() => _calendarDays = days);
  }

  String _formatDateToIso(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  void _prevMonth() {
    if (_calendarMonth == 0) {
      _calendarMonth = 11;
      _calendarYear--;
    } else {
      _calendarMonth--;
    }
    _generateCalendarGrid();
  }

  void _nextMonth() {
    if (_calendarMonth == 11) {
      _calendarMonth = 0;
      _calendarYear++;
    } else {
      _calendarMonth++;
    }
    _generateCalendarGrid();
  }

  void _goToToday() {
    setState(() {
      _selectedDateIso = _getTodayIso();
      final now = DateTime.now();
      _calendarYear = now.year;
      _calendarMonth = now.month - 1;
      _showCalendarModal = false;
    });
    _loadForSelectedDate();
  }

  void _selectCalendarDate(CalendarDayItem dayItem) {
    if (dayItem.isFuture) return;
    setState(() {
      _selectedDateIso = dayItem.dateIso;
      _showCalendarModal = false;
    });
    _loadForSelectedDate();
  }

  void _openFullLogsScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BreakLogsScreen(
          dateIso: _selectedDateIso,
          displayDate: _displaySelectedDate,
          totalBreakMins: _totalBreakMins,
          allowedBreakMins: _allowedBreakMins,
          breaks: _todayBreaks,
          onRefresh: () => _loadForSelectedDate(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      final skeleton = const ListSkeleton(itemCount: 3);
      if (!widget.showAppBar) return skeleton;
      return GlassScaffold(title: 'Break Tracker', body: skeleton);
    }

    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    final content = Stack(
      children: [
        RefreshIndicator(
          onRefresh: () => _loadForSelectedDate(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            padding: EdgeInsets.fromLTRB(14, 12, 14, bottomPadding + 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Compact Break Type Picker & Action Banner
                _buildCompactBreakSelectionSection(isDark),
                const SizedBox(height: 12),
                // 2. Summary 4-Column Strip & Progress Bar
                _buildCompactSummaryStrip(isDark),
                const SizedBox(height: 14),
                // 3. Compact Logs Preview Card
                _buildCompactLogsPreviewCard(isDark),
              ],
            ),
          ),
        ),
        if (_showCalendarModal) _buildCalendarModal(isDark),
      ],
    );

    if (!widget.showAppBar) return content;

    return GlassScaffold(
      title: 'Break Tracker',
      body: content,
    );
  }

  Widget _buildCompactBreakSelectionSection(bool isDark) {
    final bool isLimitReached = _totalBreakMins >= _allowedBreakMins || _todayBreaks.length >= 3;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Horizontal Chip Row (40-44px high)
        SizedBox(
          height: 42,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: _breakTypes.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final b = _breakTypes[index];
              final isSelected = _selectedBreakType == b.name;
              final usedCount = _countForType(b.name);

              return GestureDetector(
                onTap: () => _selectBreakType(b.name),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFEFF6FF) : (isDark ? AppColors.darkSecondarySurface : const Color(0xFFF8FAFC)),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : (isDark ? AppColors.darkBordersAndDividers : const Color(0xFFE2E8F0)),
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(b.icon, color: isSelected ? AppColors.primary : b.iconColor, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        b.name,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                          color: isSelected ? AppColors.primary : (isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Max ${b.maxMinutes}m',
                        style: TextStyle(fontSize: 10, color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText),
                      ),
                      if (usedCount > 0) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '$usedCount',
                            style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: AppColors.primary),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),

        // 2. Active Break Banner Row (Slim ~54px)
        if (_activeBreak != null && _isTodaySelected)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFE0F2FE), Color(0xFFDBEAFE)]),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFBAE6FD)),
            ),
            child: Row(
              children: [
                const Icon(Icons.coffee, color: Color(0xFF0284C7), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${_activeBreak!['type']} in Progress',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      Text(
                        'Started ${_activeBreak!['startTimeDisplay']} · Elapsed: ${_formatDuration(_elapsedSeconds)}',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF475569)),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _stopBreak,
                  icon: const Icon(Icons.stop, color: Colors.white, size: 14),
                  label: const Text('End', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),

        // 3. Historical View Warning Banner
        if (!_isTodaySelected)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFDBEAFE))),
            child: Row(
              children: [
                const Icon(Icons.history, color: AppColors.primary, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Viewing Past Log ($_displaySelectedDate)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primary)),
                ),
                TextButton.icon(
                  onPressed: _goToToday,
                  icon: const Icon(Icons.calendar_today, size: 12),
                  label: const Text('Today', style: TextStyle(fontSize: 11)),
                  style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
                ),
              ],
            ),
          ),

        // 4. Check-In Warning Banner
        if (_isTodaySelected && (!_hasCheckedInToday || _isCheckedOut))
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFFDE68A))),
            child: Row(
              children: [
                Icon(_isCheckedOut ? Icons.check_circle : Icons.warning_amber_rounded, color: const Color(0xFFD97706), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _isCheckedOut ? 'Shift Completed for today.' : 'Check in on Attendance before taking breaks.',
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                  ),
                ),
                if (!_isCheckedOut)
                  ElevatedButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PunchInOutScreen())),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD97706),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      minimumSize: Size.zero,
                    ),
                    child: const Text('Check-In', style: TextStyle(fontSize: 11)),
                  ),
              ],
            ),
          ),

        // 5. Idle Slim Merged Banner & Start Row (~54px high)
        if (_activeBreak == null && _isTodaySelected && _hasCheckedInToday && !_isCheckedOut)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSecondarySurface : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: isDark ? AppColors.darkBordersAndDividers : const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(color: _selectedTypeObj.bgColor, borderRadius: BorderRadius.circular(10)),
                  child: Icon(_selectedTypeObj.icon, color: _selectedTypeObj.iconColor, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _selectedBreakType,
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText),
                      ),
                      Text(
                        _todayBreaks.length >= 3
                            ? '3/3 breaks used'
                            : _totalBreakMins >= _allowedBreakMins
                                ? 'Limit reached (${_totalBreakMins.round()}/${_allowedBreakMins.round()}m)'
                                : 'Max ${_selectedTypeObj.maxMinutes} mins',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: isLimitReached ? AppColors.error : (isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText),
                          fontWeight: isLimitReached ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: isLimitReached ? null : () => _startBreak(),
                  icon: Icon(isLimitReached ? Icons.block_rounded : Icons.play_arrow, size: 14),
                  label: Text(isLimitReached ? 'Limit reached' : 'Start $_selectedBreakType', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor: Colors.grey.withOpacity(0.3),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    minimumSize: Size.zero,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildCompactSummaryStrip(bool isDark) {
    final bool overLimit = _isOverLimit;
    final double overrunMins = overLimit ? (_totalBreakMins - _allowedBreakMins) : 0;
    final ratio = (_totalBreakMins / _allowedBreakMins).clamp(0.0, 1.0);

    final Color remainingColor = overLimit ? AppColors.error : const Color(0xFFEA580C);
    final String remainingValue = overLimit ? 'Over by ${_formatDurationFromMins(overrunMins)}' : '${_remainingMins}m';

    final Color progressColor = ratio < 0.8
        ? const Color(0xFF10B981)
        : (overLimit ? AppColors.error : Colors.amber.shade700);

    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Today's Summary",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText),
              ),
              InkWell(
                onTap: _toggleCalendarModal,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSecondarySurface : const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isDark ? AppColors.darkBordersAndDividers : const Color(0xFFDBEAFE)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_month, size: 12, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Text(_displaySelectedDate, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Single 4-column strip (~54px high)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSecondarySurface : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isDark ? AppColors.darkBordersAndDividers : const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                _compactSummaryCell('Total', _totalBreakFormatted, const Color(0xFF2563EB), isDark),
                _vDivider(isDark),
                _compactSummaryCell('Limit', '${_allowedBreakMins.round()}m', const Color(0xFF16A34A), isDark),
                _vDivider(isDark),
                _compactSummaryCell('Breaks', '${_todayBreaks.length}', const Color(0xFF8B5CF6), isDark),
                _vDivider(isDark),
                _compactSummaryCell('Remaining', remainingValue, remainingColor, isDark),
              ],
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 5,
              backgroundColor: isDark ? Colors.white12 : Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _compactSummaryCell(String label, String value, Color color, bool isDark) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 1),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText),
            maxLines: 1,
          ),
        ],
      ),
    );
  }

  Widget _vDivider(bool isDark) {
    return Container(
      width: 1,
      height: 24,
      color: isDark ? AppColors.darkBordersAndDividers : const Color(0xFFE2E8F0),
    );
  }

  Widget _buildCompactLogsPreviewCard(bool isDark) {
    final displayLogs = _todayBreaks.take(5).toList();

    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Break Logs",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText),
              ),
              InkWell(
                onTap: _openFullLogsScreen,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                  child: Text(
                    "View all (${_todayBreaks.length}) →",
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_todayBreaks.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.coffee_outlined, size: 16, color: Colors.grey.withOpacity(0.5)),
                  const SizedBox(width: 8),
                  Text(
                    'No breaks taken on this day',
                    style: TextStyle(fontSize: 11.5, color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: displayLogs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (context, index) {
                final item = displayLogs[index];
                final isOngoing = item.status == 'In Progress';
                final bool isOverrun = item.durationMins > item.maxMinutes;

                return Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSecondarySurface : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isDark ? AppColors.darkBordersAndDividers : const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Icon(item.icon, color: item.iconColor, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${item.type.toUpperCase()}  ${item.startTime} - ${item.endTime}',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      if (isOngoing)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: const Color(0xFFFFEDD5), borderRadius: BorderRadius.circular(6)),
                          child: Text(
                            _formatDuration(_elapsedSeconds),
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFC2410C)),
                          ),
                        )
                      else ...[
                        Text(
                          item.durationDisplay,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w900,
                            color: isOverrun ? AppColors.error : AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: isOverrun ? AppColors.error : const Color(0xFF10B981),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildCalendarModal(bool isDark) {
    return Positioned.fill(
      child: Material(
        color: Colors.black.withOpacity(0.5),
        child: Center(
          child: Container(
            width: 360,
            margin: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkMainSurface : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isDark ? AppColors.darkBordersAndDividers : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          IconButton(onPressed: _prevMonth, icon: const Icon(Icons.chevron_left, size: 20)),
                          Text(_monthYearHeader, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText)),
                          IconButton(onPressed: _nextMonth, icon: const Icon(Icons.chevron_right, size: 20)),
                        ],
                      ),
                      Row(
                        children: [
                          TextButton(onPressed: _goToToday, child: const Text('Today', style: TextStyle(fontSize: 12))),
                          IconButton(onPressed: _toggleCalendarModal, icon: const Icon(Icons.close, size: 18)),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                // Days Grid
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: const [
                          Text('Mon', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                          Text('Tue', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                          Text('Wed', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                          Text('Thu', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                          Text('Fri', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                          Text('Sat', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                          Text('Sun', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 7,
                          crossAxisSpacing: 4,
                          mainAxisSpacing: 4,
                        ),
                        itemCount: _calendarDays.length,
                        itemBuilder: (context, index) {
                          final day = _calendarDays[index];
                          final hasBreaks = _datesWithBreaks.contains(day.dateIso);

                          return GestureDetector(
                            onTap: day.isFuture ? null : () => _selectCalendarDate(day),
                            child: Container(
                              decoration: BoxDecoration(
                                color: day.isSelected
                                    ? AppColors.primary
                                    : (day.isToday ? AppColors.primary.withOpacity(0.12) : Colors.transparent),
                                borderRadius: BorderRadius.circular(8),
                                border: day.isToday
                                    ? Border.all(color: AppColors.primary, width: 1.5)
                                    : null,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    '${day.dayNum}',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: day.isToday || day.isSelected ? FontWeight.bold : FontWeight.normal,
                                      color: day.isSelected
                                          ? Colors.white
                                          : (day.isFuture || !day.isCurrentMonth
                                              ? Colors.grey.withOpacity(0.4)
                                              : (isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText)),
                                    ),
                                  ),
                                  if (hasBreaks && day.isCurrentMonth)
                                    Container(
                                      margin: const EdgeInsets.only(top: 2),
                                      width: 4,
                                      height: 4,
                                      decoration: BoxDecoration(
                                        color: day.isSelected ? Colors.white : AppColors.primary,
                                        shape: BoxShape.circle,
                                      ),
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
