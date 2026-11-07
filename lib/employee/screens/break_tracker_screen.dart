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
  final String durationDisplay;
  final String status; // 'Completed' | 'In Progress'
  final DateTime? rawStartTime;

  BreakLogRow({
    this.id,
    required this.type,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.startTime,
    required this.endTime,
    required this.durationMins,
    required this.durationDisplay,
    required this.status,
    this.rawStartTime,
  });
}

class CalendarDayItem {
  final DateTime date;
  final String dateIso;
  final int dayNum;
  final bool isCurrentMonth;
  final bool isToday;
  final bool isSelected;

  CalendarDayItem({
    required this.date,
    required this.dateIso,
    required this.dayNum,
    required this.isCurrentMonth,
    required this.isToday,
    required this.isSelected,
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

  final List<BreakTypeOption> _breakTypes = const [
    BreakTypeOption(
      typeKey: 'tea',
      name: 'Tea Break',
      maxMinutes: 15,
      icon: Icons.coffee_rounded,
      bgColor: Color(0xFFFFF7ED),
      iconColor: Color(0xFFF59E0B),
      maxDisplay: 'Max 15 mins',
    ),
    BreakTypeOption(
      typeKey: 'lunch',
      name: 'Lunch Break',
      maxMinutes: 60,
      icon: Icons.restaurant_rounded,
      bgColor: Color(0xFFF0FDF4),
      iconColor: Color(0xFF10B981),
      maxDisplay: 'Max 60 mins',
    ),
    BreakTypeOption(
      typeKey: 'personal',
      name: 'Personal Break',
      maxMinutes: 30,
      icon: Icons.person_pin_rounded,
      bgColor: Color(0xFFFAF5FF),
      iconColor: Color(0xFF2563EB),
      maxDisplay: 'Max 30 mins',
    ),
    BreakTypeOption(
      typeKey: 'short',
      name: 'Short Break',
      maxMinutes: 10,
      icon: Icons.access_time_rounded,
      bgColor: Color(0xFFF0F9FF),
      iconColor: Color(0xFF0284C7),
      maxDisplay: 'Max 10 mins',
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

  String get _displaySelectedDate {
    if (_selectedDateIso.isEmpty) return _todayDisplayDate;
    final parts = _selectedDateIso.split('-');
    if (parts.length != 3) return _todayDisplayDate;
    final d = DateTime(int.parse(parts[0]), int.parse(parts[1]) - 1, int.parse(parts[2]));
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  String get _todayDisplayDate {
    final now = DateTime.now();
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${now.day} ${months[now.month - 1]} ${now.year}';
  }

  BreakTypeOption get _selectedTypeObj {
    return _breakTypes.firstWhere(
      (b) => b.name == _selectedBreakType,
      orElse: () => _breakTypes[0],
    );
  }

  String get _totalBreakFormatted {
    final total = _totalBreakMins.round();
    if (total >= 60) {
      final h = total ~/ 60;
      final m = total % 60;
      return '${h}h ${m < 10 ? '0$m' : m}m';
    }
    return '$total mins';
  }

  int get _remainingMins {
    return (_allowedBreakMins - _totalBreakMins).round().clamp(0, 999);
  }

  void _selectBreakType(String name) {
    if (_activeBreak != null) return;
    setState(() => _selectedBreakType = name);
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
      final startDt = startStr != null ? DateTime.tryParse(startStr) : null;
      final endDt = endStr != null ? DateTime.tryParse(endStr) : null;
      final isOngoing = endDt == null;

      if (isOngoing && _isTodaySelected) {
        activeItem = {'b': bMap, 'typeName': typeName, 'config': config, 'startDt': startDt ?? DateTime.now()};
      }

      double durMins = 0;
      if (bMap['durationMinutes'] != null) {
        durMins = double.tryParse(bMap['durationMinutes'].toString()) ?? 0;
      } else if (startDt != null && endDt != null) {
        durMins = endDt.difference(startDt).inMinutes.toDouble();
      }
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
        durationDisplay: '${durMins.round()} mins',
        status: isOngoing ? 'In Progress' : 'Completed',
        rawStartTime: startDt,
      ));
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

  String _formatTimer(int seconds) {
    final hrs = seconds ~/ 3600;
    final mins = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    return '${hrs.toString().padLeft(2, '0')}:${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
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

    final targetType = typeName ?? _selectedBreakType;
    final config = _breakTypes.firstWhere((b) => b.name == targetType, orElse: () => _breakTypes[0]);
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
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

    int startDayOfWeek = firstDayOfMonth.weekday - 2; // Mon = 0 ... Sun = 6
    if (startDayOfWeek < 0) startDayOfWeek = 6;

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
        isToday: dateIso == _getTodayIso(),
        isSelected: dateIso == _selectedDateIso,
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
        isToday: dateIso == _getTodayIso(),
        isSelected: dateIso == _selectedDateIso,
      ));
    }

    final totalCells = days.length > 35 ? 42 : 35;
    final remaining = totalCells - days.length;
    for (int dayNum = 1; dayNum <= remaining; dayNum++) {
      final d = DateTime(_calendarYear, _calendarMonth + 2, dayNum);
      final dateIso = _formatDateToIso(d);
      days.add(CalendarDayItem(
        date: d,
        dateIso: dateIso,
        dayNum: dayNum,
        isCurrentMonth: false,
        isToday: dateIso == _getTodayIso(),
        isSelected: dateIso == _selectedDateIso,
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
    setState(() {
      _selectedDateIso = dayItem.dateIso;
      _showCalendarModal = false;
    });
    _loadForSelectedDate();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      final skeleton = const ListSkeleton(itemCount: 3);
      if (!widget.showAppBar) return skeleton;
      return GlassScaffold(title: 'Break Tracker', body: skeleton);
    }

    final content = Stack(
      children: [
        RefreshIndicator(
          onRefresh: () => _loadForSelectedDate(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Break Type Selection Grid & Banners
                _buildBreakSelectionSection(isDark),
                const SizedBox(height: 20),
                // 2. Summary Grid (2x2)
                _buildSummaryGrid(isDark),
                const SizedBox(height: 24),
                // 3. Break Logs Table Card
                _buildBreakLogsCard(isDark),
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

  Widget _buildBreakSelectionSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Select Break Type Box
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select Break Type to Start',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText),
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final crossAxisCount = constraints.maxWidth > 600 ? 4 : 2;
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.5,
                    ),
                    itemCount: _breakTypes.length,
                    itemBuilder: (context, index) {
                      final b = _breakTypes[index];
                      final isSelected = _selectedBreakType == b.name;

                      return GestureDetector(
                        onTap: () => _selectBreakType(b.name),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFFEFF6FF) : (isDark ? AppColors.darkSecondarySurface : const Color(0xFFF8FAFC)),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected ? AppColors.primary : (isDark ? AppColors.darkBordersAndDividers : const Color(0xFFE2E8F0)),
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Stack(
                            children: [
                              if (isSelected)
                                Positioned(
                                  top: 0,
                                  right: 0,
                                  child: Container(
                                    width: 20,
                                    height: 20,
                                    decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                                    child: const Icon(Icons.check, size: 12, color: Colors.white),
                                  ),
                                ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(color: b.bgColor, borderRadius: BorderRadius.circular(10)),
                                    child: Icon(b.icon, color: b.iconColor, size: 20),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    b.name,
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    b.maxDisplay,
                                    style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Active Break Banner
        if (_activeBreak != null && _isTodaySelected)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFE0F2FE), Color(0xFFDBEAFE)]),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFBAE6FD)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      child: const Icon(Icons.coffee, color: Color(0xFF0284C7), size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_activeBreak!['type'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                          const SizedBox(height: 2),
                          Text('Started at ${_activeBreak!['startTimeDisplay']}', style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFDCFCE7))),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(Icons.circle, size: 8, color: Color(0xFF16A34A)),
                                SizedBox(width: 6),
                                Text('Break In Progress', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF16A34A))),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('ELAPSED', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                        const SizedBox(height: 2),
                        Text(_formatTimer(_elapsedSeconds), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                        Text('of ${_activeBreak!['maxMinutes']} mins', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _stopBreak,
                    icon: const Icon(Icons.stop, color: Colors.white),
                    label: const Text('End Break', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),

        // Historical Date View Warning
        if (!_isTodaySelected)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFDBEAFE))),
            child: Row(
              children: [
                const Icon(Icons.history, color: AppColors.primary, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Viewing Past Log ($_displaySelectedDate)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary)),
                      const SizedBox(height: 2),
                      const Text('Break controls are only active for today.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: _goToToday,
                  icon: const Icon(Icons.calendar_today, size: 14),
                  label: const Text('Today'),
                ),
              ],
            ),
          ),

        // Check-In Required Warning
        if (_isTodaySelected && (!_hasCheckedInToday || _isCheckedOut))
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFFDE68A))),
            child: Row(
              children: [
                Icon(_isCheckedOut ? Icons.check_circle : Icons.warning_amber_rounded, color: const Color(0xFFD97706), size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_isCheckedOut ? 'Shift Completed' : 'Check-In Required First', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF92400E))),
                      const SizedBox(height: 2),
                      Text(
                        _isCheckedOut ? 'You have checked out for today.' : 'You must check in on the Attendance page before taking breaks.',
                        style: const TextStyle(fontSize: 12, color: Color(0xFFB45309)),
                      ),
                    ],
                  ),
                ),
                if (!_isCheckedOut)
                  ElevatedButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PunchInOutScreen())),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD97706), foregroundColor: Colors.white),
                    child: const Text('Check-In'),
                  ),
              ],
            ),
          ),

        // Idle Start Break Banner
        if (_activeBreak == null && _isTodaySelected)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSecondarySurface : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? AppColors.darkBordersAndDividers : const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: _selectedTypeObj.bgColor, borderRadius: BorderRadius.circular(12)),
                  child: Icon(_selectedTypeObj.icon, color: _selectedTypeObj.iconColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Ready for $_selectedBreakType?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText)),
                      const SizedBox(height: 2),
                      Text('Max limit is ${_selectedTypeObj.maxMinutes} mins.', style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText)),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: (!_hasCheckedInToday || _isCheckedOut) ? null : () => _startBreak(),
                  icon: const Icon(Icons.play_arrow, size: 16),
                  label: Text('Start $_selectedBreakType'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildSummaryGrid(bool isDark) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.calendar_today, size: 16, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(_isTodaySelected ? "Today's Summary" : "Break Summary", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText)),
                ],
              ),
              InkWell(
                onTap: _toggleCalendarModal,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSecondarySurface : const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isDark ? AppColors.darkBordersAndDividers : const Color(0xFFDBEAFE)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_month, size: 14, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Text(_displaySelectedDate, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.6,
            children: [
              _summaryTile('Total Break Time', _totalBreakFormatted, Icons.access_time, const Color(0xFF2563EB), const Color(0xFFDBEAFE), isDark),
              _summaryTile('Daily Allowed Limit', '${_allowedBreakMins.round()} mins', Icons.hourglass_top, const Color(0xFF16A34A), const Color(0xFFDCFCE7), isDark),
              _summaryTile('Total Breaks', '${_todayBreaks.length}', Icons.layers, const Color(0xFF8B5CF6), const Color(0xFFEDE9FE), isDark),
              _summaryTile('Remaining', '$_remainingMins mins', Icons.timer_off, const Color(0xFFEA580C), const Color(0xFFFFEDD5), isDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryTile(String label, String value, IconData icon, Color color, Color bg, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSecondarySurface : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? AppColors.darkBordersAndDividers : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 16),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
              const SizedBox(height: 1),
              Text(label, style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBreakLogsCard(bool isDark) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.history, size: 16, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(_isTodaySelected ? "Today's Break Logs" : "Break Logs ($_displaySelectedDate)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText)),
                ],
              ),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _toggleCalendarModal,
                    icon: const Icon(Icons.calendar_month, size: 14),
                    label: const Text('Calendar', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
                  ),
                  if (!_isTodaySelected) ...[
                    const SizedBox(width: 6),
                    TextButton.icon(
                      onPressed: _goToToday,
                      icon: const Icon(Icons.refresh, size: 14),
                      label: const Text('Today', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          _todayBreaks.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Text('No break logs recorded for ${_isTodaySelected ? 'today' : _displaySelectedDate}.', style: TextStyle(color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText)),
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _todayBreaks.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final item = _todayBreaks[index];
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSecondarySurface : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isDark ? AppColors.darkBordersAndDividers : const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: item.iconBg, borderRadius: BorderRadius.circular(10)),
                            child: Icon(item.icon, color: item.iconColor, size: 18),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.type, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText)),
                                const SizedBox(height: 2),
                                Text('${item.startTime} - ${item.endTime}', style: TextStyle(fontSize: 11.5, color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText)),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(item.durationDisplay, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary)),
                              const SizedBox(height: 2),
                              StatusChip(status: item.status),
                            ],
                          ),
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
                  padding: const EdgeInsets.all(16),
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
                  padding: const EdgeInsets.all(16),
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
                      const SizedBox(height: 12),
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
                          return GestureDetector(
                            onTap: () => _selectCalendarDate(day),
                            child: Container(
                              decoration: BoxDecoration(
                                color: day.isSelected
                                    ? AppColors.primary
                                    : (day.isToday ? AppColors.primary.withOpacity(0.1) : Colors.transparent),
                                borderRadius: BorderRadius.circular(8),
                                border: day.isToday && !day.isSelected ? Border.all(color: AppColors.primary) : null,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '${day.dayNum}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: day.isToday || day.isSelected ? FontWeight.bold : FontWeight.normal,
                                  color: day.isSelected
                                      ? Colors.white
                                      : (!day.isCurrentMonth
                                          ? Colors.grey.withOpacity(0.5)
                                          : (isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText)),
                                ),
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
