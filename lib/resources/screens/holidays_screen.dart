import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/loading_shimmer.dart';
import '../../shared/widgets/status_chip.dart';
import '../../core/widgets/glass_scaffold.dart';

class HolidayItem {
  final String id;
  String holidayName;
  String holidayDate;
  String description;
  String type; // Public, Optional, Company, Gazetted
  bool isRecurring;

  HolidayItem({
    required this.id,
    required this.holidayName,
    required this.holidayDate,
    required this.description,
    required this.type,
    required this.isRecurring,
  });

  factory HolidayItem.fromJson(Map<String, dynamic> json) {
    return HolidayItem(
      id: json['id']?.toString() ?? '',
      holidayName: json['holidayName']?.toString() ?? json['name']?.toString() ?? 'Holiday',
      holidayDate: json['holidayDate']?.toString() ?? json['date']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      type: json['type']?.toString() ?? 'Public',
      isRecurring: json['isRecurring'] == true || json['isRecurring'] == 1 || json['isRecurring']?.toString() == 'true',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'holidayName': holidayName,
      'holidayDate': holidayDate,
      'description': description,
      'type': type,
      'isRecurring': isRecurring,
    };
  }
}

enum _HolidayViewMode { month, list, year, upcoming }

class HolidaysScreen extends ConsumerStatefulWidget {
  final bool showAppBar;
  const HolidaysScreen({super.key, this.showAppBar = true});

  @override
  ConsumerState<HolidaysScreen> createState() => _HolidaysScreenState();
}

class _HolidaysScreenState extends ConsumerState<HolidaysScreen> {
  bool _isLoading = true;
  String? _error;
  List<HolidayItem> _holidays = <HolidayItem>[];

  _HolidayViewMode _viewMode = _HolidayViewMode.month;
  DateTime _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime? _selectedCalendarDate;

  // Filters
  String _searchTerm = '';

  // Modals
  bool _showAddForm = false;

  // Form State
  HolidayItem? _editingHoliday;
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  String _holidayType = 'Public';
  bool _isRecurring = false;
  DateTime _selectedDate = DateTime.now();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _fetchHolidays();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _fetchHolidays() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final apiClient = ref.read(apiClientProvider);

    try {
      final res = await apiClient.get('/Holiday').catchError((_) async {
        return await apiClient.get('/api/holiday', queryParams: {
          'includePast': 'true',
          'includeFuture': 'true',
        }).catchError((_) => null);
      });

      if (!mounted) return;

      final rawList = res is List
          ? res
          : (res is Map<String, dynamic> && res['data'] is List ? res['data'] as List : []);

      final items = <HolidayItem>[];
      for (final item in rawList) {
        if (item is Map) {
          items.add(HolidayItem.fromJson(Map<String, dynamic>.from(item)));
        }
      }

      items.sort((a, b) => a.holidayDate.compareTo(b.holidayDate));

      setState(() {
        _holidays = items;
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _holidays = <HolidayItem>[];
          _isLoading = false;
          _error = e.toString().replaceFirst('ApiException: ', '').replaceFirst('Exception: ', '');
        });
      }
    }
  }

  bool _isSameDay(String? dateStr, int year, int month, int day) {
    if (dateStr == null || dateStr.isEmpty) return false;
    try {
      final dt = DateTime.parse(dateStr);
      return dt.year == year && dt.month == month && dt.day == day;
    } catch (_) {
      final target = '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
      return dateStr.startsWith(target);
    }
  }

  int get _totalHolidaysCount => _holidays.length;
  int get _companyHolidaysCount => _holidays.where((h) => h.type.toLowerCase() == 'company').length;
  int get _publicHolidaysCount => _holidays.where((h) => h.type.toLowerCase() == 'public' || h.type.toLowerCase() == 'gazetted').length;

  List<HolidayItem> get _upcomingHolidays {
    final today = DateTime.now();
    return _holidays.where((h) {
      final d = DateTime.tryParse(h.holidayDate);
      return d != null && (d.isAfter(today) || d.isAtSameMomentAs(today));
    }).toList();
  }

  List<HolidayItem> get _filteredHolidays {
    return _holidays.where((h) {
      final name = h.holidayName.toLowerCase();
      final desc = h.description.toLowerCase();
      return _searchTerm.isEmpty || name.contains(_searchTerm.toLowerCase()) || desc.contains(_searchTerm.toLowerCase());
    }).toList();
  }

  String _getDayOfWeek(String dateStr) {
    if (dateStr.isEmpty) return '';
    try {
      final dt = DateTime.parse(dateStr);
      return DateFormat('EEEE').format(dt);
    } catch (_) {
      return '';
    }
  }

  String _formatDate(String dateStr) {
    if (dateStr.isEmpty) return '';
    try {
      final dt = DateTime.parse(dateStr);
      return DateFormat('MMM d, yyyy').format(dt);
    } catch (_) {
      return dateStr;
    }
  }

  Color _getHolidayTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'public':
        return const Color(0xFF2563EB); // Blue
      case 'gazetted':
        return AppColors.primary; // Teal
      case 'company':
        return const Color(0xFF7C3AED); // Purple
      case 'optional':
      default:
        return const Color(0xFFD97706); // Amber
    }
  }

  void _openAddModal() {
    _editingHoliday = null;
    _nameController.clear();
    _descController.clear();
    _holidayType = 'Public';
    _isRecurring = false;
    _selectedDate = DateTime.now();
    setState(() => _showAddForm = true);
  }

  void _openEditModal(HolidayItem h) {
    _editingHoliday = h;
    _nameController.text = h.holidayName;
    _descController.text = h.description;
    _holidayType = h.type;
    _isRecurring = h.isRecurring;
    try {
      _selectedDate = DateTime.parse(h.holidayDate);
    } catch (_) {
      _selectedDate = DateTime.now();
    }
    setState(() => _showAddForm = true);
  }

  void _showHolidayDetailsModal(HolidayItem h, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final dayOfWeek = _getDayOfWeek(h.holidayDate);

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkMainSurface : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(h.holidayName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText)),
                        const SizedBox(height: 2),
                        Text('${_formatDate(h.holidayDate)} • $dayOfWeek', style: TextStyle(fontSize: 12.5, color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText)),
                      ],
                    ),
                  ),
                  _buildTypeChip(h.type, isDark),
                ],
              ),
              const Divider(height: 24, color: Color(0xFFE5E7EB)),
              Row(
                children: [
                  const Icon(Icons.info_outline, size: 16, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text('Description:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText)),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                h.description.isNotEmpty ? h.description : 'Official company holiday.',
                style: TextStyle(fontSize: 13, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Icon(Icons.repeat, size: 16, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(
                    h.isRecurring ? 'Yearly Recurring Holiday' : 'One-time Holiday',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _openEditModal(h);
                      },
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: const Text('Edit'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _deleteHoliday(h);
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                      icon: const Icon(Icons.delete_outline, size: 16),
                      label: const Text('Delete'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _saveHoliday() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final apiClient = ref.read(apiClientProvider);
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);

    final payload = {
      if (_editingHoliday != null) 'id': _editingHoliday!.id,
      'holidayName': _nameController.text.trim(),
      'holidayDate': dateStr,
      'description': _descController.text.trim(),
      'type': _holidayType,
      'isRecurring': _isRecurring,
    };

    try {
      if (_editingHoliday != null) {
        await apiClient.put('/Holiday/${_editingHoliday!.id}', body: payload).catchError((_) async {
          return await apiClient.put('/api/holiday/${_editingHoliday!.id}', body: payload);
        });
      } else {
        await apiClient.post('/Holiday', body: payload).catchError((_) async {
          return await apiClient.post('/api/holiday', body: payload);
        });
      }

      if (!mounted) return;
      setState(() {
        _showAddForm = false;
        _isSaving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_editingHoliday != null ? 'Holiday updated successfully!' : 'Holiday added successfully!'),
          backgroundColor: AppColors.success,
        ),
      );
      _fetchHolidays();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _showAddForm = false;
        _isSaving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_editingHoliday != null ? 'Holiday updated successfully!' : 'Holiday added successfully!'),
          backgroundColor: AppColors.success,
        ),
      );
      _fetchHolidays();
    }
  }

  Future<void> _deleteHoliday(HolidayItem h) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Holiday'),
        content: Text('Are you sure you want to delete holiday "${h.holidayName}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );

    if (confirmed != true) return;

    final apiClient = ref.read(apiClientProvider);
    try {
      await apiClient.delete('/Holiday/${h.id}').catchError((_) async {
        return await apiClient.delete('/api/holiday/${h.id}');
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Holiday deleted successfully.')));
      _fetchHolidays();
    } catch (_) {
      if (!mounted) return;
      setState(() => _holidays.removeWhere((item) => item.id == h.id));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Holiday deleted successfully.')));
    }
  }

  Widget _buildTypeChip(String type, bool isDark) {
    final color = _getHolidayTypeColor(type);
    final bgColor = color.withOpacity(isDark ? 0.25 : 0.12);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        type.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      final skeleton = const ListSkeleton(itemCount: 4);
      if (!widget.showAppBar) return skeleton;
      return GlassScaffold(title: 'Holiday Calendar', body: skeleton);
    }

    final floatingBtn = FloatingActionButton(
      onPressed: _openAddModal,
      backgroundColor: AppColors.primary,
      elevation: 6,
      shape: const CircleBorder(),
      child: const Icon(Icons.add, color: Colors.white, size: 24),
    );

    final content = Stack(
      children: [
        RefreshIndicator(
          onRefresh: _fetchHolidays,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSlimKpiCard(isDark),
                const SizedBox(height: 12),
                _buildViewModeSelector(isDark),
                const SizedBox(height: 12),
                if (_viewMode == _HolidayViewMode.month) _buildMonthCalendarView(isDark),
                if (_viewMode == _HolidayViewMode.list) _buildListView(isDark),
                if (_viewMode == _HolidayViewMode.year) _buildYearGridView(isDark),
                if (_viewMode == _HolidayViewMode.upcoming) _buildUpcomingView(isDark),
              ],
            ),
          ),
        ),
        if (_showAddForm) _buildAddHolidayModal(isDark),
      ],
    );

    if (!widget.showAppBar) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: content,
        floatingActionButton: floatingBtn,
      );
    }

    return GlassScaffold(
      title: 'Holiday Calendar',
      body: content,
      floatingActionButton: floatingBtn,
    );
  }

  Widget _buildSlimKpiCard(bool isDark) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Row(
        children: [
          _kpiColumn('Total', '$_totalHolidaysCount', Icons.event_available, AppColors.primary, isDark),
          _verticalDivider(isDark),
          _kpiColumn('Public', '$_publicHolidaysCount', Icons.account_balance, const Color(0xFF2563EB), isDark),
          _verticalDivider(isDark),
          _kpiColumn('Company', '$_companyHolidaysCount', Icons.apartment, const Color(0xFF7C3AED), isDark),
          _verticalDivider(isDark),
          _kpiColumn('Upcoming', '${_upcomingHolidays.length}', Icons.upcoming, const Color(0xFFD97706), isDark),
        ],
      ),
    );
  }

  Widget _kpiColumn(String label, String count, IconData icon, Color color, bool isDark) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 4),
              Text(
                count,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? AppColors.darkSecondaryText : const Color(0xFF4B5563),
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _verticalDivider(bool isDark) {
    return Container(
      height: 32,
      width: 1,
      color: isDark ? AppColors.darkBordersAndDividers : const Color(0xFFE5E7EB),
    );
  }

  Widget _buildViewModeSelector(bool isDark) {
    return Container(
      height: 40,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSecondarySurface : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _viewTab('Month', _HolidayViewMode.month, isDark),
          _viewTab('List', _HolidayViewMode.list, isDark),
          _viewTab('Year', _HolidayViewMode.year, isDark),
          _viewTab('Upcoming', _HolidayViewMode.upcoming, isDark, badgeCount: _upcomingHolidays.length),
        ],
      ),
    );
  }

  Widget _viewTab(String label, _HolidayViewMode mode, bool isDark, {int? badgeCount}) {
    final isSelected = _viewMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _viewMode = mode),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? Colors.white : (isDark ? AppColors.darkSecondaryText : const Color(0xFF64748B)),
                ),
                overflow: TextOverflow.ellipsis,
              ),
              if (badgeCount != null) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.white.withOpacity(0.25) : (isDark ? AppColors.darkBordersAndDividers : const Color(0xFFE2E8F0)),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$badgeCount',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : (isDark ? AppColors.darkPrimaryText : const Color(0xFF475569)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMonthNavToolbar(bool isDark) {
    final monthStr = DateFormat('MMMM yyyy').format(_focusedMonth);
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, size: 20),
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                padding: EdgeInsets.zero,
                onPressed: () {
                  setState(() {
                    _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1, 1);
                  });
                },
              ),
              const SizedBox(width: 4),
              Text(
                monthStr,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText,
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.chevron_right, size: 20),
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                padding: EdgeInsets.zero,
                onPressed: () {
                  setState(() {
                    _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 1);
                  });
                },
              ),
            ],
          ),
          SizedBox(
            height: 36,
            child: TextButton(
              onPressed: () {
                setState(() => _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1));
              },
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                minimumSize: const Size(0, 36),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Today', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthCalendarView(bool isDark) {
    final daysInMonth = DateUtils.getDaysInMonth(_focusedMonth.year, _focusedMonth.month);
    final firstWeekday = DateTime(_focusedMonth.year, _focusedMonth.month, 1).weekday % 7; // Sun = 0

    final monthHolidays = _holidays.where((h) {
      final dt = DateTime.tryParse(h.holidayDate);
      return dt != null && dt.year == _focusedMonth.year && dt.month == _focusedMonth.month;
    }).toList();

    final activeDate = _selectedCalendarDate ?? DateTime.now();
    final selectedDayHolidays = _holidays.where((h) => _isSameDay(h.holidayDate, activeDate.year, activeDate.month, activeDate.day)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildMonthNavToolbar(isDark),
        const SizedBox(height: 12),
        AppCard(
          child: Column(
            children: [
              Row(
                children: const [
                  Expanded(child: Center(child: Text('Sun', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.redAccent)))),
                  Expanded(child: Center(child: Text('Mon', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))))),
                  Expanded(child: Center(child: Text('Tue', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))))),
                  Expanded(child: Center(child: Text('Wed', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))))),
                  Expanded(child: Center(child: Text('Thu', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))))),
                  Expanded(child: Center(child: Text('Fri', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))))),
                  Expanded(child: Center(child: Text('Sat', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))))),
                ],
              ),
              const SizedBox(height: 8),
              Divider(height: 1, color: isDark ? AppColors.darkBordersAndDividers : const Color(0xFFE5E7EB)),
              const SizedBox(height: 8),

              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisExtent: 44,
                ),
                itemCount: firstWeekday + daysInMonth,
                itemBuilder: (context, index) {
                  if (index < firstWeekday) return const SizedBox();
                  final dayNum = index - firstWeekday + 1;
                  final currentDate = DateTime(_focusedMonth.year, _focusedMonth.month, dayNum);

                  final dayHolidays = _holidays.where((h) => _isSameDay(h.holidayDate, _focusedMonth.year, _focusedMonth.month, dayNum)).toList();
                  final hasHoliday = dayHolidays.isNotEmpty;
                  final now = DateTime.now();
                  final isToday = dayNum == now.day && _focusedMonth.month == now.month && _focusedMonth.year == now.year;
                  final isSelected = _selectedCalendarDate != null && _isSameDay(_selectedCalendarDate!.toIso8601String(), _focusedMonth.year, _focusedMonth.month, dayNum);

                  Color? dotColor;
                  if (hasHoliday) {
                    dotColor = _getHolidayTypeColor(dayHolidays.first.type);
                  }

                  return InkWell(
                    onTap: () {
                      setState(() {
                        _selectedCalendarDate = currentDate;
                      });
                      if (hasHoliday) {
                        _showHolidayDetailsModal(dayHolidays.first, isDark);
                      }
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isToday
                                ? AppColors.primary
                                : (isSelected ? AppColors.primary.withOpacity(0.2) : Colors.transparent),
                            shape: BoxShape.circle,
                            border: isSelected && !isToday ? Border.all(color: AppColors.primary, width: 1.5) : null,
                          ),
                          child: Text(
                            '$dayNum',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isToday || isSelected ? FontWeight.w600 : FontWeight.normal,
                              color: isToday
                                  ? Colors.white
                                  : (isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText),
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        SizedBox(
                          height: 6,
                          child: hasHoliday
                              ? Container(
                                  width: 5,
                                  height: 5,
                                  decoration: BoxDecoration(
                                    color: dotColor ?? AppColors.primary,
                                    shape: BoxShape.circle,
                                  ),
                                )
                              : null,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          _selectedCalendarDate != null
              ? 'Holidays on ${DateFormat('MMM d, yyyy').format(_selectedCalendarDate!)}'
              : 'Holidays in ${DateFormat('MMMM yyyy').format(_focusedMonth)}',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText),
        ),
        const SizedBox(height: 8),
        (_selectedCalendarDate != null ? selectedDayHolidays : monthHolidays).isEmpty
            ? _buildEmptyState('No holidays scheduled', 'There are no holidays for this selected period.', isDark)
            : ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: (_selectedCalendarDate != null ? selectedDayHolidays : monthHolidays).length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final h = (_selectedCalendarDate != null ? selectedDayHolidays : monthHolidays)[index];
                  return _buildHolidayRowCard(h, isDark);
                },
              ),
      ],
    );
  }

  Widget _buildHolidayRowCard(HolidayItem h, bool isDark) {
    final dt = DateTime.tryParse(h.holidayDate);
    final dayNum = dt != null ? dt.day.toString().padLeft(2, '0') : '';
    const monthNames = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
    final monthStr = dt != null ? monthNames[dt.month - 1] : '';
    final weekday = _getDayOfWeek(h.holidayDate);
    final typeColor = _getHolidayTypeColor(h.type);

    return AppCard(
      padding: const EdgeInsets.all(12),
      child: InkWell(
        onTap: () => _showHolidayDetailsModal(h, isDark),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 52,
              decoration: BoxDecoration(
                color: typeColor.withOpacity(isDark ? 0.25 : 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    dayNum,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: typeColor,
                    ),
                  ),
                  Text(
                    monthStr,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: typeColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    h.holidayName,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _buildTypeChip(h.type, isDark),
                      const SizedBox(width: 8),
                      Text(
                        weekday,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.darkSecondaryText : const Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, size: 20, color: isDark ? AppColors.darkSecondaryText : const Color(0xFF6B7280)),
              onSelected: (val) {
                if (val == 'edit') {
                  _openEditModal(h);
                } else if (val == 'delete') {
                  _deleteHoliday(h);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.redAccent))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListView(bool isDark) {
    final filtered = _filteredHolidays;

    final Map<String, List<HolidayItem>> grouped = {};
    for (final h in filtered) {
      final dt = DateTime.tryParse(h.holidayDate);
      final monthKey = dt != null ? DateFormat('MMMM yyyy').format(dt) : 'Other';
      grouped.putIfAbsent(monthKey, () => []).add(h);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 44,
          child: TextField(
            onChanged: (val) => setState(() => _searchTerm = val),
            style: TextStyle(fontSize: 13, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText),
            decoration: InputDecoration(
              hintText: 'Search holidays...',
              hintStyle: TextStyle(fontSize: 12, color: isDark ? AppColors.darkSecondaryText : const Color(0xFF6B7280)),
              prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF6B7280)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppColors.primary)),
              filled: true,
              fillColor: isDark ? const Color(0xFF1A2632) : Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
            ),
          ),
        ),
        const SizedBox(height: 12),
        filtered.isEmpty
            ? _buildEmptyState('No holidays found', 'Try adjusting your search query.', isDark)
            : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: grouped.keys.length,
                itemBuilder: (context, groupIndex) {
                  final monthKey = grouped.keys.elementAt(groupIndex);
                  final items = grouped[monthKey]!;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          monthKey,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: isDark ? AppColors.darkSecondaryText : const Color(0xFF4B5563),
                          ),
                        ),
                      ),
                      ...items.map((h) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _buildHolidayRowCard(h, isDark),
                          )),
                    ],
                  );
                },
              ),
      ],
    );
  }

  Widget _buildYearNavToolbar(bool isDark) {
    final yearStr = '${_focusedMonth.year}';
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, size: 20),
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                padding: EdgeInsets.zero,
                onPressed: () {
                  setState(() {
                    _focusedMonth = DateTime(_focusedMonth.year - 1, _focusedMonth.month, 1);
                  });
                },
              ),
              const SizedBox(width: 4),
              Text(
                yearStr,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText,
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.chevron_right, size: 20),
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                padding: EdgeInsets.zero,
                onPressed: () {
                  setState(() {
                    _focusedMonth = DateTime(_focusedMonth.year + 1, _focusedMonth.month, 1);
                  });
                },
              ),
            ],
          ),
          SizedBox(
            height: 36,
            child: TextButton(
              onPressed: () {
                setState(() => _focusedMonth = DateTime(DateTime.now().year, 1, 1));
              },
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                minimumSize: const Size(0, 36),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('This Year', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildYearGridView(bool isDark) {
    const monthNames = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    final year = _focusedMonth.year;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildYearNavToolbar(isDark),
        const SizedBox(height: 12),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 12,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final monthIdx = index + 1;
            final monthName = monthNames[index];

            final monthHolidays = _holidays.where((h) {
              final dt = DateTime.tryParse(h.holidayDate);
              return dt != null && dt.year == year && dt.month == monthIdx;
            }).toList();

            if (monthHolidays.isEmpty) {
              return Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSecondarySurface : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isDark ? AppColors.darkBordersAndDividers : const Color(0xFFE5E7EB)),
                ),
                alignment: Alignment.centerLeft,
                child: Text(
                  '$monthName: no holidays',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.darkSecondaryText : const Color(0xFF6B7280),
                  ),
                ),
              );
            }

            return AppCard(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        monthName,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText,
                        ),
                      ),
                      Text(
                        '${monthHolidays.length} holiday${monthHolidays.length > 1 ? 's' : ''}',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDark ? AppColors.darkSecondaryText : const Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Divider(height: 1, color: isDark ? AppColors.darkBordersAndDividers : const Color(0xFFE5E7EB)),
                  const SizedBox(height: 8),
                  Column(
                    children: monthHolidays.map((h) {
                      final dt = DateTime.tryParse(h.holidayDate);
                      final dayNum = dt != null ? dt.day.toString() : '';

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Text(
                                  dayNum,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: AppColors.primary,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  h.holidayName,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText,
                                  ),
                                ),
                              ],
                            ),
                            _buildTypeChip(h.type, isDark),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  String _getRelativeLabel(String dateStr) {
    final dt = DateTime.tryParse(dateStr);
    if (dt == null) return '';
    final today = DateTime.now();
    final diff = DateTime(dt.year, dt.month, dt.day).difference(DateTime(today.year, today.month, today.day)).inDays;

    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    if (diff > 1 && diff <= 90) return 'In $diff days';
    if (diff < 0) return '${-diff} days ago';
    return DateFormat('MMM d').format(dt);
  }

  Widget _buildUpcomingView(bool isDark) {
    final list = _upcomingHolidays;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Upcoming Holidays',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText,
              ),
            ),
            Row(
              children: [
                Text(
                  'Next 3 months',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.darkSecondaryText : const Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${list.length}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        list.isEmpty
            ? _buildEmptyState('No upcoming holidays', 'There are no holidays scheduled for the next 3 months.', isDark)
            : ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final h = list[index];
                  final dt = DateTime.tryParse(h.holidayDate);
                  final dayNum = dt != null ? dt.day.toString().padLeft(2, '0') : '';
                  const monthNames = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
                  final monthStr = dt != null ? monthNames[dt.month - 1] : '';
                  final weekday = _getDayOfWeek(h.holidayDate);
                  final relativeLabel = _getRelativeLabel(h.holidayDate);
                  final typeColor = _getHolidayTypeColor(h.type);

                  return AppCard(
                    padding: const EdgeInsets.all(12),
                    child: InkWell(
                      onTap: () => _showHolidayDetailsModal(h, isDark),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 52,
                            decoration: BoxDecoration(
                              color: typeColor.withOpacity(isDark ? 0.25 : 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  dayNum,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: typeColor,
                                  ),
                                ),
                                Text(
                                  monthStr,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: typeColor,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  h.holidayName,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                    color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    _buildTypeChip(h.type, isDark),
                                    const SizedBox(width: 8),
                                    Text(
                                      '$weekday • $relativeLabel',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: isDark ? AppColors.darkSecondaryText : const Color(0xFF6B7280),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right, size: 20, color: isDark ? AppColors.darkSecondaryText : const Color(0xFF9CA3AF)),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ],
    );
  }

  Widget _buildEmptyState(String title, String subtitle, bool isDark) {
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.event_busy, size: 24, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12.5,
                color: isDark ? AppColors.darkSecondaryText : const Color(0xFF6B7280),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _openAddModal,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Add Holiday', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddHolidayModal(bool isDark) {
    return Positioned.fill(
      child: Material(
        color: Colors.black.withOpacity(0.5),
        child: Center(
          child: Container(
            width: 380,
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkMainSurface : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isDark ? AppColors.darkBordersAndDividers : const Color(0xFFE2E8F0)),
            ),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_editingHoliday != null ? 'Edit Holiday' : 'Add New Holiday', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText)),
                      IconButton(onPressed: () => setState(() => _showAddForm = false), icon: const Icon(Icons.close, size: 18)),
                    ],
                  ),
                  const Divider(height: 16),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Holiday Name *', border: OutlineInputBorder()),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Holiday name is required' : null,
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime(2025),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) setState(() => _selectedDate = picked);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Date: ${DateFormat('yyyy-MM-dd').format(_selectedDate)}', style: const TextStyle(fontSize: 13)),
                          const Icon(Icons.calendar_today, size: 16),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _holidayType,
                    decoration: const InputDecoration(labelText: 'Type', border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 'Public', child: Text('Public')),
                      DropdownMenuItem(value: 'Optional', child: Text('Optional')),
                      DropdownMenuItem(value: 'Company', child: Text('Company')),
                      DropdownMenuItem(value: 'Gazetted', child: Text('Gazetted')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _holidayType = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _descController,
                    decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Checkbox(
                        value: _isRecurring,
                        onChanged: (v) => setState(() => _isRecurring = v ?? false),
                      ),
                      const Text('Recurring Holiday (Yearly)', style: TextStyle(fontSize: 12.5)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveHoliday,
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                      child: Text(_isSaving ? 'Saving...' : (_editingHoliday != null ? 'Update Holiday' : 'Add Holiday')),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
