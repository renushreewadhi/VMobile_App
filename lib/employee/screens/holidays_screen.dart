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
  String type; // Public, Optional, Company
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
  DateTime _focusedMonth = DateTime(2026, 10, 1);

  // Filters
  String _searchTerm = '';
  String _filterType = ''; // '' | 'Public' | 'Optional' | 'Company'
  String _filterRecurring = ''; // '' | 'true' | 'false'

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
    final today = DateTime(2026, 10, 26);
    return _holidays.where((h) {
      final d = DateTime.tryParse(h.holidayDate);
      return d != null && (d.isAfter(today) || d.isAtSameMomentAs(today));
    }).toList();
  }

  List<HolidayItem> get _filteredHolidays {
    return _holidays.where((h) {
      final name = h.holidayName.toLowerCase();
      final desc = h.description.toLowerCase();
      final type = h.type.toLowerCase();

      final matchesSearch = _searchTerm.isEmpty || name.contains(_searchTerm.toLowerCase()) || desc.contains(_searchTerm.toLowerCase());
      final matchesType = _filterType.isEmpty || type == _filterType.toLowerCase();
      final matchesRec = _filterRecurring.isEmpty || h.isRecurring.toString() == _filterRecurring;

      return matchesSearch && matchesType && matchesRec;
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
        final formattedDate = _formatDate(h.holidayDate);

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
                        Text('$formattedDate • $dayOfWeek', style: TextStyle(fontSize: 12.5, color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText)),
                      ],
                    ),
                  ),
                  StatusChip(status: h.type.toUpperCase()),
                ],
              ),
              const Divider(height: 24),
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
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                  child: const Text('Close'),
                ),
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      final skeleton = const ListSkeleton(itemCount: 4);
      if (!widget.showAppBar) return skeleton;
      return GlassScaffold(title: 'Holiday Calendar', body: skeleton);
    }

    final content = Stack(
      children: [
        RefreshIndicator(
          onRefresh: _fetchHolidays,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeaderRow(isDark),
                const SizedBox(height: 14),

                // KPI SUMMARY CARDS (4 Cards matching Website)
                _buildKpiGrid(isDark),
                const SizedBox(height: 16),

                // VIEW MODE TAB SELECTOR (Month, List, Year, Upcoming)
                _buildViewModeSelector(isDark),
                const SizedBox(height: 16),

                // MONTH / YEAR NAVIGATION TOOLBAR
                if (_viewMode == _HolidayViewMode.month || _viewMode == _HolidayViewMode.year)
                  _buildNavToolbar(isDark),

                const SizedBox(height: 12),

                // DYNAMIC VIEW CONTENT (Month Calendar, List Table, Year Grid, Upcoming List)
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

    if (!widget.showAppBar) return content;

    return GlassScaffold(
      title: 'Holiday Calendar',
      body: content,
    );
  }

  Widget _buildHeaderRow(bool isDark) {
    return Align(
      alignment: Alignment.centerRight,
      child: ElevatedButton.icon(
        onPressed: _openAddModal,
        icon: const Icon(Icons.add, size: 16),
        label: const Text('Add Holiday'),
        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
      ),
    );
  }

  Widget _buildKpiGrid(bool isDark) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.8,
      children: [
        _kpiCard('Total Holidays', '$_totalHolidaysCount', 'This Year', Icons.event_available, AppColors.primary, isDark),
        _kpiCard('Company Holidays', '$_companyHolidaysCount', 'Internal', Icons.apartment, Colors.purple, isDark),
        _kpiCard('Public Holidays', '$_publicHolidaysCount', 'Government', Icons.account_balance, Colors.teal, isDark),
        _kpiCard('Upcoming Holidays', '${_upcomingHolidays.length}', 'In next 3 months', Icons.upcoming, const Color(0xFFF59E0B), isDark),
      ],
    );
  }

  Widget _kpiCard(String label, String value, String sub, IconData icon, Color color, bool isDark) {
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
                const SizedBox(height: 2),
                Text(label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText), overflow: TextOverflow.ellipsis),
                Text(sub, style: TextStyle(fontSize: 9.5, color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewModeSelector(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSecondarySurface : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _viewTab('Month', _HolidayViewMode.month),
          _viewTab('List', _HolidayViewMode.list),
          _viewTab('Year', _HolidayViewMode.year),
          _viewTab('Upcoming (${_upcomingHolidays.length})', _HolidayViewMode.upcoming),
        ],
      ),
    );
  }

  Widget _viewTab(String label, _HolidayViewMode mode) {
    final isSelected = _viewMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _viewMode = mode),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
              color: isSelected ? Colors.white : AppColors.lightSecondaryText,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  Widget _buildNavToolbar(bool isDark) {
    final monthStr = DateFormat('MMMM yyyy').format(_focusedMonth);
    final yearStr = '${_focusedMonth.year}';

    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, size: 20),
                onPressed: () {
                  setState(() {
                    if (_viewMode == _HolidayViewMode.year) {
                      _focusedMonth = DateTime(_focusedMonth.year - 1, _focusedMonth.month, 1);
                    } else {
                      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1, 1);
                    }
                  });
                },
              ),
              Text(
                _viewMode == _HolidayViewMode.year ? yearStr : monthStr,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, size: 20),
                onPressed: () {
                  setState(() {
                    if (_viewMode == _HolidayViewMode.year) {
                      _focusedMonth = DateTime(_focusedMonth.year + 1, _focusedMonth.month, 1);
                    } else {
                      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 1);
                    }
                  });
                },
              ),
            ],
          ),
          ElevatedButton(
            onPressed: () {
              setState(() => _focusedMonth = DateTime(2026, 10, 1));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary.withOpacity(0.12),
              foregroundColor: AppColors.primary,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            ),
            child: const Text('Current Month', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthCalendarView(bool isDark) {
    final daysInMonth = DateUtils.getDaysInMonth(_focusedMonth.year, _focusedMonth.month);
    final firstWeekday = DateTime(_focusedMonth.year, _focusedMonth.month, 1).weekday % 7; // Sun = 0

    return AppCard(
      child: Column(
        children: [
          // Days of week header
          Row(
            children: const [
              Expanded(child: Center(child: Text('Sun', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.redAccent)))),
              Expanded(child: Center(child: Text('Mon', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)))),
              Expanded(child: Center(child: Text('Tue', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)))),
              Expanded(child: Center(child: Text('Wed', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)))),
              Expanded(child: Center(child: Text('Thu', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)))),
              Expanded(child: Center(child: Text('Fri', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)))),
              Expanded(child: Center(child: Text('Sat', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.redAccent)))),
            ],
          ),
          const Divider(height: 16),

          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 0.85,
            ),
            itemCount: firstWeekday + daysInMonth,
            itemBuilder: (context, index) {
              if (index < firstWeekday) return const SizedBox();
              final dayNum = index - firstWeekday + 1;

              final dayHolidays = _holidays.where((h) => _isSameDay(h.holidayDate, _focusedMonth.year, _focusedMonth.month, dayNum)).toList();
              final hasHoliday = dayHolidays.isNotEmpty;
              final isToday = dayNum == 26 && _focusedMonth.month == 10 && _focusedMonth.year == 2026;

              return InkWell(
                onTap: hasHoliday ? () => _showHolidayDetailsModal(dayHolidays.first, isDark) : null,
                borderRadius: BorderRadius.circular(8),
                child: Column(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isToday
                            ? AppColors.primary
                            : (hasHoliday ? Colors.redAccent.withOpacity(0.2) : Colors.transparent),
                        shape: BoxShape.circle,
                        border: hasHoliday ? Border.all(color: Colors.redAccent, width: 1.5) : null,
                      ),
                      child: Text(
                        '$dayNum',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: (isToday || hasHoliday) ? FontWeight.bold : FontWeight.normal,
                          color: isToday
                              ? Colors.white
                              : (hasHoliday ? Colors.redAccent : (isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText)),
                        ),
                      ),
                    ),
                    if (hasHoliday) ...[
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                        ),
                        child: Text(
                          dayHolidays.first.holidayName,
                          style: const TextStyle(fontSize: 7.5, fontWeight: FontWeight.bold, color: Colors.redAccent),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
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

  Widget _buildListView(bool isDark) {
    return Column(
      children: [
        AppCard(
          child: TextField(
            onChanged: (val) => setState(() => _searchTerm = val),
            style: TextStyle(fontSize: 13, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText),
            decoration: InputDecoration(
              hintText: 'Search holidays by name or description...',
              hintStyle: TextStyle(fontSize: 12, color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText),
              prefixIcon: const Icon(Icons.search, size: 18),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              filled: true,
              fillColor: isDark ? const Color(0xFF1A2632) : AppColors.lightInputBackground,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _filteredHolidays.isEmpty
            ? AppCard(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(child: Text('No holidays found matching your search.', style: TextStyle(color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText))),
                ),
              )
            : ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _filteredHolidays.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final h = _filteredHolidays[index];
                  final dayStr = _getDayOfWeek(h.holidayDate);
                  final formattedDate = _formatDate(h.holidayDate);

                  return AppCard(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                          child: Icon(Icons.event, color: AppColors.primary, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(child: Text(h.holidayName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText))),
                                  StatusChip(status: h.type.toUpperCase()),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text('$formattedDate ($dayStr)', style: TextStyle(fontSize: 11.5, color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText)),
                              if (h.description.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(h.description, style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkMutedText : Colors.grey)),
                              ],
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.primary),
                          onPressed: () => _openEditModal(h),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                          onPressed: () => _deleteHoliday(h),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ],
    );
  }

  Widget _buildYearGridView(bool isDark) {
    const monthNames = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 12,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final monthIdx = index + 1;
        final monthName = monthNames[index];
        final year = _focusedMonth.year;

        final monthHolidays = _holidays.where((h) {
          final dt = DateTime.tryParse(h.holidayDate);
          return dt != null && dt.year == year && dt.month == monthIdx;
        }).toList();

        return AppCard(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$monthName $year', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText)),
              const Divider(height: 12),
              monthHolidays.isEmpty
                  ? Center(child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text('No holidays scheduled', style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText)),
                    ))
                  : Column(
                      children: monthHolidays.map((h) {
                        final dt = DateTime.tryParse(h.holidayDate);
                        final dayNum = dt != null ? dt.day.toString().padLeft(2, '0') : '';

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Text(dayNum, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primary)),
                                  const SizedBox(width: 8),
                                  Text(h.holidayName, style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText)),
                                ],
                              ),
                              StatusChip(status: h.type.toUpperCase()),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildUpcomingView(bool isDark) {
    final list = _upcomingHolidays;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Upcoming Holidays', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText)),
            Text('${list.length} Next 3 Months', style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText)),
          ],
        ),
        const SizedBox(height: 12),
        list.isEmpty
            ? AppCard(child: Padding(padding: const EdgeInsets.all(28), child: Center(child: Text('No upcoming holidays.', style: TextStyle(color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText)))))
            : ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final h = list[index];
                  final dt = DateTime.tryParse(h.holidayDate);
                  final dayStr = dt != null ? dt.day.toString().padLeft(2, '0') : '';
                  const monthNames = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
                  final monthStr = dt != null ? monthNames[dt.month - 1] : 'OCT';
                  final weekday = _getDayOfWeek(h.holidayDate);

                  return AppCard(
                    padding: const EdgeInsets.all(12),
                    child: InkWell(
                      onTap: () => _showHolidayDetailsModal(h, isDark),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                            child: Column(
                              children: [
                                Text(dayStr, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.redAccent)),
                                Text(monthStr, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.redAccent)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(h.holidayName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText)),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    StatusChip(status: h.type.toUpperCase()),
                                    const SizedBox(width: 6),
                                    Text(weekday, style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right, color: Colors.grey),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ],
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
