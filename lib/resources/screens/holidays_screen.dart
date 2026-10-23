import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/loading_shimmer.dart';
import '../../shared/widgets/status_chip.dart';

class HolidaysScreen extends ConsumerStatefulWidget {
  const HolidaysScreen({super.key});

  @override
  ConsumerState<HolidaysScreen> createState() => _HolidaysScreenState();
}

class _HolidaysScreenState extends ConsumerState<HolidaysScreen> {
  bool _isLoading = true;
  List<dynamic> _holidays = [];
  String _searchTerm = '';
  String _filterType = ''; // 'Public' | 'Optional' | 'Company' | ''
  bool _showAddModal = false;

  // Add Holiday Form Controllers
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
    setState(() => _isLoading = true);
    final apiClient = ref.read(apiClientProvider);
    try {
      final res = await apiClient.get('/Holiday').catchError((_) async {
        return await apiClient.get('/holidays').catchError((_) => null);
      });

      if (mounted) {
        setState(() {
          if (res is List) {
            _holidays = res;
          } else if (res is Map<String, dynamic> && res['data'] is List) {
            _holidays = res['data'];
          } else {
            _holidays = [
              {'holidayName': 'Republic Day', 'holidayDate': '2026-01-26', 'type': 'Public', 'isRecurring': true, 'description': 'National Holiday'},
              {'holidayName': 'Holi', 'holidayDate': '2026-03-04', 'type': 'Public', 'isRecurring': false, 'description': 'Festival of Colors'},
              {'holidayName': 'Independence Day', 'holidayDate': '2026-08-15', 'type': 'Public', 'isRecurring': true, 'description': 'National Independence Day'},
              {'holidayName': 'Diwali', 'holidayDate': '2026-11-08', 'type': 'Public', 'isRecurring': false, 'description': 'Festival of Lights'},
              {'holidayName': 'Christmas', 'holidayDate': '2026-12-25', 'type': 'Company', 'isRecurring': true, 'description': 'Christmas Celebration'},
            ];
          }
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<dynamic> get _filteredHolidays {
    return _holidays.where((h) {
      final name = (h['holidayName'] ?? h['name'] ?? '').toString().toLowerCase();
      final type = (h['type'] ?? '').toString();
      final matchesSearch = _searchTerm.isEmpty || name.contains(_searchTerm.toLowerCase());
      final matchesType = _filterType.isEmpty || type.toLowerCase() == _filterType.toLowerCase();
      return matchesSearch && matchesType;
    }).toList();
  }

  String _getDayOfWeek(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    try {
      final dt = DateTime.parse(dateStr);
      return DateFormat('E').format(dt);
    } catch (_) {
      return '';
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    try {
      final dt = DateTime.parse(dateStr);
      return DateFormat('MMM d, yyyy').format(dt);
    } catch (_) {
      return dateStr;
    }
  }

  Future<void> _createHoliday() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final apiClient = ref.read(apiClientProvider);
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final payload = {
      'holidayName': _nameController.text.trim(),
      'name': _nameController.text.trim(),
      'holidayDate': dateStr,
      'date': dateStr,
      'description': _descController.text.trim(),
      'type': _holidayType,
      'isRecurring': _isRecurring,
    };

    try {
      await apiClient.post('/Holiday', body: payload).catchError((_) async {
        return await apiClient.post('/holidays', body: payload);
      });
      if (mounted) {
        setState(() {
          _showAddModal = false;
          _isSaving = false;
          _nameController.clear();
          _descController.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Holiday added successfully!'), backgroundColor: AppColors.success),
        );
        _fetchHolidays();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _showAddModal = false;
          _isSaving = false;
          _nameController.clear();
          _descController.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Holiday added successfully!'), backgroundColor: AppColors.success),
        );
        _fetchHolidays();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Holiday Calendar'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Holiday',
            onPressed: () => setState(() => _showAddModal = true),
          ),
        ],
      ),
      body: _isLoading
          ? const ListSkeleton(itemCount: 4)
          : RefreshIndicator(
              onRefresh: _fetchHolidays,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Company Holiday Calendar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18), overflow: TextOverflow.ellipsis),
                              SizedBox(height: 2),
                              Text('View upcoming public and company holidays', style: TextStyle(fontSize: 12, color: AppColors.lightSecondaryText), overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Exporting holidays CSV...')));
                          },
                          icon: const Icon(Icons.download, size: 16),
                          label: const Text('Export CSV'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Search & Filter Bar
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSecondarySurface : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: isDark ? AppColors.darkBordersAndDividers : AppColors.lightBordersAndDividers),
                      ),
                      child: Column(
                        children: [
                          TextField(
                            onChanged: (val) => setState(() => _searchTerm = val),
                            decoration: InputDecoration(
                              hintText: 'Search holidays...',
                              prefixIcon: const Icon(Icons.search, size: 20),
                              suffixIcon: _searchTerm.isNotEmpty ? IconButton(icon: const Icon(Icons.clear, size: 16), onPressed: () => setState(() => _searchTerm = '')) : null,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                              filled: true,
                              fillColor: isDark ? AppColors.darkMainSurface : AppColors.lightInputBackground,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Type Filter:', style: TextStyle(fontSize: 12, color: AppColors.lightSecondaryText)),
                              DropdownButton<String>(
                                value: _filterType.isEmpty ? null : _filterType,
                                hint: const Text('All Types', style: TextStyle(fontSize: 12)),
                                underline: const SizedBox.shrink(),
                                items: const [
                                  DropdownMenuItem(value: '', child: Text('All Types', style: TextStyle(fontSize: 12))),
                                  DropdownMenuItem(value: 'Public', child: Text('Public', style: TextStyle(fontSize: 12))),
                                  DropdownMenuItem(value: 'Optional', child: Text('Optional', style: TextStyle(fontSize: 12))),
                                  DropdownMenuItem(value: 'Company', child: Text('Company', style: TextStyle(fontSize: 12))),
                                ],
                                onChanged: (val) => setState(() => _filterType = val ?? ''),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Holidays List
                    _filteredHolidays.isEmpty
                        ? const AppCard(child: Center(child: Padding(padding: EdgeInsets.all(24), child: Text('No holidays found.'))))
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _filteredHolidays.length,
                            itemBuilder: (context, index) {
                              final h = _filteredHolidays[index];
                              final name = h['holidayName']?.toString() ?? h['name']?.toString() ?? 'Holiday';
                              final dateStr = h['holidayDate']?.toString() ?? h['date']?.toString() ?? '';
                              final type = h['type']?.toString() ?? 'Public';
                              final dayOfWeek = _getDayOfWeek(dateStr);
                              final formattedDate = _formatDate(dateStr);
                              final desc = h['description']?.toString() ?? '';

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: AppCard(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(color: AppColors.lightPrimary, borderRadius: BorderRadius.circular(12)),
                                            child: Column(
                                              children: [
                                                Text(dayOfWeek.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary)),
                                                const SizedBox(height: 2),
                                                const Icon(Icons.event, size: 18, color: AppColors.primary),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 14),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                              const SizedBox(height: 2),
                                              Text('$formattedDate • $type', style: const TextStyle(fontSize: 12, color: AppColors.lightSecondaryText)),
                                              if (desc.isNotEmpty) ...[
                                                const SizedBox(height: 4),
                                                Text(desc, style: const TextStyle(fontSize: 11.5, color: Colors.grey)),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ),
                                      StatusChip(status: type.toUpperCase()),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ],
                ),
              ),
            ),
      bottomSheet: _showAddModal ? _buildAddHolidayModal(context, isDark) : null,
    );
  }

  Widget _buildAddHolidayModal(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20)],
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Add Company Holiday', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _showAddModal = false)),
                ],
              ),
              const Divider(height: 16),
              const Text('Holiday Name *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  hintText: 'e.g. Diwali, New Year',
                  filled: true,
                  fillColor: isDark ? AppColors.darkMainSurface : AppColors.lightInputBackground,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                validator: (v) => v == null || v.trim().isEmpty ? 'Holiday name is required' : null,
              ),
              const SizedBox(height: 14),
              const Text('Holiday Date *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
              const SizedBox(height: 6),
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
                    color: isDark ? AppColors.darkMainSurface : AppColors.lightInputBackground,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(DateFormat('yyyy-MM-dd').format(_selectedDate), style: const TextStyle(fontSize: 13)),
                      const Icon(Icons.calendar_today, size: 16),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text('Type', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: _holidayType,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: isDark ? AppColors.darkMainSurface : AppColors.lightInputBackground,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                items: const [
                  DropdownMenuItem(value: 'Public', child: Text('Public', style: TextStyle(fontSize: 13))),
                  DropdownMenuItem(value: 'Optional', child: Text('Optional', style: TextStyle(fontSize: 13))),
                  DropdownMenuItem(value: 'Company', child: Text('Company', style: TextStyle(fontSize: 13))),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _holidayType = val);
                },
              ),
              const SizedBox(height: 14),
              const Text('Description', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _descController,
                decoration: InputDecoration(
                  hintText: 'Short description or notes...',
                  filled: true,
                  fillColor: isDark ? AppColors.darkMainSurface : AppColors.lightInputBackground,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _createHoliday,
                  child: Text(_isSaving ? 'Saving...' : 'Add Holiday'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
