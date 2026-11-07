import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/auth/auth_service.dart';
import '../../core/errors/api_exception.dart';
import '../../core/models/user_model.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/glass_theme.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/glass_header.dart';
import '../../core/widgets/glass_scaffold.dart';
import 'admin_designation_form_screen.dart';

/// Strongly typed Designation Model
class DesignationModel {
  final String id;
  final String title;
  final String? code;
  final String? level;
  final String? departmentId;
  final String? departmentName;
  final double? minSalary;
  final double? maxSalary;
  final int employeeCount;
  final String status;

  DesignationModel({
    required this.id,
    required this.title,
    this.code,
    this.level,
    this.departmentId,
    this.departmentName,
    this.minSalary,
    this.maxSalary,
    required this.employeeCount,
    required this.status,
  });

  bool get isActive {
    final s = status.toUpperCase();
    return s == 'ACTIVE' || s == 'TRUE';
  }

  factory DesignationModel.fromJson(Map<String, dynamic> json) {
    String? deptName = json['departmentName']?.toString() ?? json['department']?.toString();
    if (deptName == null || deptName.isEmpty) {
      if (json['departmentObj'] is Map<String, dynamic>) {
        deptName = json['departmentObj']['name']?.toString();
      }
    }

    final rawStatus = json['status']?.toString() ?? 'Active';
    final isAct = rawStatus.toUpperCase() == 'ACTIVE' || rawStatus.toUpperCase() == 'TRUE';

    return DesignationModel(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      title: json['title']?.toString() ?? json['name']?.toString() ?? 'Designation Title',
      code: json['code']?.toString(),
      level: json['level']?.toString() ?? json['band']?.toString(),
      departmentId: json['departmentId']?.toString(),
      departmentName: deptName,
      minSalary: (json['minSalary'] as num?)?.toDouble() ?? (double.tryParse(json['minSalary']?.toString() ?? '')),
      maxSalary: (json['maxSalary'] as num?)?.toDouble() ?? (double.tryParse(json['maxSalary']?.toString() ?? '')),
      employeeCount: json['employeeCount'] is int ? json['employeeCount'] as int : (int.tryParse(json['employeeCount']?.toString() ?? '0') ?? 0),
      status: isAct ? 'Active' : 'Inactive',
    );
  }
}

class AdminDesignationsScreen extends ConsumerStatefulWidget {
  const AdminDesignationsScreen({super.key});

  @override
  ConsumerState<AdminDesignationsScreen> createState() => _AdminDesignationsScreenState();
}

class _AdminDesignationsScreenState extends ConsumerState<AdminDesignationsScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<DesignationModel> _designations = [];
  List<Map<String, String>> _departments = [];

  // Filter state
  String _searchTerm = '';
  String _selectedDepartment = '';
  String _selectedLevel = '';
  String _selectedStatus = '';

  // Pagination state (5 per page, matching Angular source)
  int _currentPage = 1;
  final int _pageSize = 5;

  // Selection state
  final Set<String> _selectedIds = {};
  bool _selectAllChecked = false;

  // Sorting state
  String _sortColumn = 'title';
  bool _sortAscending = true;

  // Request ID guard against stale session responses
  int _requestId = 0;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _checkUserAndLoad();
      }
    });
  }

  void _checkUserAndLoad() {
    _requestId++;
    final authState = ref.read(authServiceProvider);
    final user = authState.user;

    if (user == null || !authState.isAuthenticated) {
      if (!mounted) return;
      _resetState();
      setState(() {
        _isLoading = false;
        _errorMessage = 'No authenticated user found.';
      });
      return;
    }

    if (_currentUserId != user.id) {
      _currentUserId = user.id;
      _resetState();
    }

    final userRole = user.role;
    final bool isAuthorized = userRole == UserRole.ADMIN || userRole == UserRole.HR;

    if (!isAuthorized) {
      if (!mounted) return;
      _resetState();
      setState(() {
        _isLoading = false;
        _errorMessage = null;
      });
      return;
    }

    _loadData();
  }

  void _resetState() {
    _designations = [];
    _departments = [];
    _selectedIds.clear();
    _selectAllChecked = false;
    _resetFilters();
  }

  void _resetFilters() {
    setState(() {
      _searchTerm = '';
      _selectedDepartment = '';
      _selectedLevel = '';
      _selectedStatus = '';
      _currentPage = 1;
      _selectedIds.clear();
      _selectAllChecked = false;
    });
  }

  Future<void> _loadData() async {
    final currentReq = ++_requestId;
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final apiClient = ref.read(apiClientProvider);

    try {
      List<Map<String, String>> depts = [];
      try {
        final deptRes = await apiClient.get(ApiEndpoints.departments);
        if (!mounted || currentReq != _requestId) return;
        dynamic rawDepts = deptRes is Map<String, dynamic> && deptRes.containsKey('data') ? deptRes['data'] : deptRes;
        if (rawDepts is List) {
          for (final d in rawDepts) {
            if (d is Map<String, dynamic>) {
              final id = (d['id'] ?? d['_id'])?.toString() ?? '';
              final name = (d['name'] ?? d['departmentName'])?.toString() ?? 'Department';
              if (id.isNotEmpty) depts.add({'id': id, 'name': name});
            }
          }
        }
      } catch (e) {
        debugPrint('[AdminDesignations] Departments fetch warning: $e');
      }

      final res = await apiClient.get(ApiEndpoints.designations);
      if (!mounted || currentReq != _requestId) return;

      dynamic rawData = res;
      if (res is Map<String, dynamic> && res.containsKey('data')) {
        rawData = res['data'];
      }

      if (rawData is! List) {
        if (!mounted || currentReq != _requestId) return;
        setState(() {
          _errorMessage = 'Invalid response format received from server.';
          _isLoading = false;
        });
        return;
      }

      List<DesignationModel> items = [];
      for (final item in rawData) {
        if (item is Map<String, dynamic>) {
          try {
            items.add(DesignationModel.fromJson(item));
          } catch (e) {
            debugPrint('[AdminDesignations] Skipped invalid designation item: $e');
          }
        }
      }

      if (!mounted || currentReq != _requestId) return;
      setState(() {
        _departments = depts;
        _designations = items;
        _isLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted || currentReq != _requestId) return;
      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted || currentReq != _requestId) return;
      setState(() {
        _errorMessage = 'Failed to load designation records. Please check network connection.';
        _isLoading = false;
      });
    }
  }

  List<DesignationModel> get _filteredDesignations {
    var list = _designations.where((d) {
      final matchesSearch = _searchTerm.trim().isEmpty ||
          d.title.toLowerCase().contains(_searchTerm.toLowerCase()) ||
          (d.departmentName != null && d.departmentName!.toLowerCase().contains(_searchTerm.toLowerCase()));

      final matchesDept = _selectedDepartment.isEmpty || d.departmentName == _selectedDepartment || d.departmentId == _selectedDepartment;

      final matchesLevel = _selectedLevel.isEmpty || (() {
        if (d.level == null) return false;
        final l = d.level!.toLowerCase();
        final sel = _selectedLevel.toLowerCase();
        if (sel.contains('level 1')) return l.contains('1') || l.contains('exec') || l.contains('director');
        if (sel.contains('level 2')) return l.contains('2') || l.contains('senior') || l.contains('sr') || l.contains('lead') || l.contains('manager');
        if (sel.contains('level 3')) return l.contains('3') || l.contains('mid');
        if (sel.contains('level 4')) return l.contains('4') || l.contains('entry') || l.contains('jr') || l.contains('junior');
        return l.contains(sel);
      })();

      final matchesStatus = _selectedStatus.isEmpty || d.status.toLowerCase() == _selectedStatus.toLowerCase();

      return matchesSearch && matchesDept && matchesLevel && matchesStatus;
    }).toList();

    list.sort((a, b) {
      int comparison = 0;
      switch (_sortColumn) {
        case 'title':
          comparison = a.title.toLowerCase().compareTo(b.title.toLowerCase());
          break;
        case 'department':
          comparison = (a.departmentName ?? '').toLowerCase().compareTo((b.departmentName ?? '').toLowerCase());
          break;
        case 'level':
          comparison = (a.level ?? '').toLowerCase().compareTo((b.level ?? '').toLowerCase());
          break;
        case 'salary':
          comparison = (a.minSalary ?? 0.0).compareTo(b.minSalary ?? 0.0);
          break;
        case 'employeeCount':
          comparison = a.employeeCount.compareTo(b.employeeCount);
          break;
        case 'status':
          comparison = a.status.compareTo(b.status);
          break;
      }
      return _sortAscending ? comparison : -comparison;
    });

    return list;
  }

  List<DesignationModel> get _paginatedDesignations {
    final filtered = _filteredDesignations;
    if (filtered.isEmpty) return [];
    final startIndex = (_currentPage - 1) * _pageSize;
    if (startIndex >= filtered.length) return [];
    final endIndex = (startIndex + _pageSize < filtered.length) ? startIndex + _pageSize : filtered.length;
    return filtered.sublist(startIndex, endIndex);
  }

  int get _totalPages {
    final count = _filteredDesignations.length;
    return (count / _pageSize).ceil() > 0 ? (count / _pageSize).ceil() : 1;
  }

  int get _startItemIndex {
    if (_filteredDesignations.isEmpty) return 0;
    return (_currentPage - 1) * _pageSize + 1;
  }

  int get _endItemIndex {
    final filtered = _filteredDesignations;
    return (_currentPage * _pageSize < filtered.length) ? _currentPage * _pageSize : filtered.length;
  }

  int get _totalDesignationsCount => _designations.length;

  int get _executiveCount {
    return _designations.where((d) {
      final lvl = (d.level ?? '').toLowerCase();
      final title = d.title.toLowerCase();
      return lvl.contains('level 1') || lvl.contains('level 2') || lvl.contains('executive') || lvl.contains('senior') || lvl.contains('lead') || lvl.contains('manager') ||
          title.contains('architect') || title.contains('manager') || title.contains('lead') || title.contains('executive');
    }).length;
  }

  int get _totalEmployeesAssigned {
    return _designations.fold(0, (sum, d) => sum + d.employeeCount);
  }

  String get _avgSalaryFormatted {
    final validSalaries = _designations.map((d) => d.minSalary).where((s) => s != null && s > 0).map((s) => s!).toList();
    if (validSalaries.isEmpty) return '₹0';
    final totalMin = validSalaries.reduce((sum, s) => sum + s);
    final avg = (totalMin / validSalaries.length).round();
    final fmt = NumberFormat.currency(symbol: '₹', decimalDigits: 0);
    return fmt.format(avg);
  }

  void _onSort(String column) {
    setState(() {
      if (_sortColumn == column) {
        _sortAscending = !_sortAscending;
      } else {
        _sortColumn = column;
        _sortAscending = true;
      }
    });
  }

  void _toggleSelectAll(bool? val) {
    setState(() {
      _selectAllChecked = val ?? false;
      if (_selectAllChecked) {
        _selectedIds.addAll(_paginatedDesignations.map((d) => d.id));
      } else {
        _selectedIds.removeAll(_paginatedDesignations.map((d) => d.id));
      }
    });
  }

  void _toggleSelectRow(String id, bool? val) {
    setState(() {
      if (val == true) {
        _selectedIds.add(id);
      } else {
        _selectedIds.remove(id);
      }
    });
  }

  void _exportExcel() {
    final filtered = _filteredDesignations;
    if (filtered.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No designations available to export.')),
      );
      return;
    }

    final currencyFmt = NumberFormat.currency(symbol: '₹', decimalDigits: 0);
    final rows = [
      ['Designation Title', 'Code', 'Department', 'Level', 'Min Salary', 'Max Salary', 'Employees Assigned', 'Status'],
      ...filtered.map((d) => [
            d.title,
            d.code ?? '—',
            d.departmentName ?? 'General',
            d.level ?? 'Mid Level',
            d.minSalary != null ? currencyFmt.format(d.minSalary) : 'N/A',
            d.maxSalary != null ? currencyFmt.format(d.maxSalary) : 'N/A',
            '${d.employeeCount}',
            d.status,
          ]),
    ];

    final csvBuffer = StringBuffer();
    for (final row in rows) {
      csvBuffer.writeln(row.map((c) => '"${c.replaceAll('"', '""')}"').join(','));
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Exported ${filtered.length} designations.')),
    );
  }

  Future<void> _deleteDesignation(DesignationModel desig) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete designation "${desig.title}"?'),
        content: Text(desig.employeeCount > 0
            ? 'This designation currently has ${desig.employeeCount} assigned employee(s). Are you sure you want to proceed?'
            : 'Are you sure you want to delete this designation?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final currentReq = ++_requestId;
    final apiClient = ref.read(apiClientProvider);

    try {
      await apiClient.delete('${ApiEndpoints.designations}/${desig.id}');
      if (!mounted || currentReq != _requestId) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Designation deleted successfully')),
      );
      _loadData();
    } catch (e) {
      if (!mounted || currentReq != _requestId) return;
      final msg = e is ApiException ? e.message : 'Failed to delete designation.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBgColor = isDark ? const Color(0xFF141D2E) : Colors.white;

    ref.listen<AuthState>(authServiceProvider, (previous, next) {
      if (next.user?.id != _currentUserId) {
        _checkUserAndLoad();
      }
    });

    final authState = ref.watch(authServiceProvider);
    final userRole = authState.user?.role;
    final bool isAuthorized = userRole == UserRole.ADMIN || userRole == UserRole.HR;

    return GlassScaffold(
      appBar: const GlassHeader(
        title: 'Designation Management',
      ),
      body: !isAuthorized
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: AppCard(
                  backgroundColor: cardBgColor,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.lock_outline, size: 48, color: Color(0xFFEF4444)),
                      const SizedBox(height: 16),
                      Text('Access Restricted', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: glass.textPrimary)),
                      const SizedBox(height: 8),
                      Text('You do not have administrative permissions to view designation hierarchy.', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: glass.textSecondary)),
                    ],
                  ),
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadData,
              child: _buildMainContent(glass, cardBgColor),
            ),
    );
  }

  Widget _buildMainContent(GlassTheme glass, Color cardBgColor) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Container(
          constraints: BoxConstraints(minHeight: MediaQuery.of(context).size.height * 0.7),
          padding: const EdgeInsets.all(24),
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, size: 54, color: Color(0xFFEF4444)),
              const SizedBox(height: 16),
              Text('Unable to Load Designations', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: glass.textPrimary)),
              const SizedBox(height: 8),
              Text(_errorMessage!, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: glass.textSecondary)),
              const SizedBox(height: 24),
              AppButton(label: 'Retry', icon: Icons.refresh_rounded, width: 140, onPressed: _loadData),
            ],
          ),
        ),
      );
    }

    final filtered = _filteredDesignations;
    final paginated = _paginatedDesignations;
    final dark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 4 Compact KPI Metric Cards (Matching Departments Management style)
          Row(
            children: [
              Expanded(child: _buildMetricCard('Total', '$_totalDesignationsCount', Icons.badge_outlined, const Color(0xFF2563EB), const Color(0xFFE0EDFF))),
              const SizedBox(width: 8),
              Expanded(child: _buildMetricCard('Executive', '$_executiveCount', Icons.person_pin_outlined, const Color(0xFF8B5CF6), const Color(0xFFEFF6FF))),
              const SizedBox(width: 8),
              Expanded(child: _buildMetricCard('Employees', '$_totalEmployeesAssigned', Icons.groups_rounded, const Color(0xFF16A34A), const Color(0xFFDCFCE7))),
              const SizedBox(width: 8),
              Expanded(child: _buildMetricCard('Avg Salary', _avgSalaryFormatted, Icons.currency_rupee_rounded, const Color(0xFFD97706), const Color(0xFFFEF3C7))),
            ],
          ),
          const SizedBox(height: 16),

          // Search Input & Filter Chips
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: dark ? AppColors.darkSecondarySurface : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: dark ? AppColors.darkBordersAndDividers : const Color(0xFFE2E8F0)),
                    boxShadow: const [BoxShadow(color: Color.fromRGBO(15, 23, 42, 0.03), blurRadius: 10, offset: Offset(0, 2))],
                  ),
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Search title, department...',
                      hintStyle: TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                      prefixIcon: Icon(Icons.search_rounded, size: 20, color: Color(0xFF64748B)),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    style: TextStyle(color: dark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText, fontSize: 13),
                    onChanged: (val) {
                      setState(() {
                        _searchTerm = val;
                        _currentPage = 1;
                      });
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: dark ? AppColors.darkSecondarySurface : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: dark ? AppColors.darkBordersAndDividers : const Color(0xFFE2E8F0)),
                  ),
                  child: DropdownButton<String>(
                    value: _selectedDepartment.isEmpty ? null : _selectedDepartment,
                    hint: const Text('All Departments', style: TextStyle(fontSize: 12)),
                    underline: const SizedBox.shrink(),
                    items: [
                      const DropdownMenuItem(value: '', child: Text('All Departments', style: TextStyle(fontSize: 12))),
                      ..._departments.map((d) => DropdownMenuItem(value: d['name']!, child: Text(d['name']!, style: const TextStyle(fontSize: 12)))),
                    ],
                    onChanged: (val) {
                      setState(() {
                        _selectedDepartment = val ?? '';
                        _currentPage = 1;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: dark ? AppColors.darkSecondarySurface : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: dark ? AppColors.darkBordersAndDividers : const Color(0xFFE2E8F0)),
                  ),
                  child: DropdownButton<String>(
                    value: _selectedLevel.isEmpty ? null : _selectedLevel,
                    hint: const Text('All Levels', style: TextStyle(fontSize: 12)),
                    underline: const SizedBox.shrink(),
                    items: const [
                      DropdownMenuItem(value: '', child: Text('All Levels', style: TextStyle(fontSize: 12))),
                      DropdownMenuItem(value: 'Level 1', child: Text('Level 1 - Exec', style: TextStyle(fontSize: 12))),
                      DropdownMenuItem(value: 'Level 2', child: Text('Level 2 - Senior', style: TextStyle(fontSize: 12))),
                      DropdownMenuItem(value: 'Level 3', child: Text('Level 3 - Mid', style: TextStyle(fontSize: 12))),
                      DropdownMenuItem(value: 'Level 4', child: Text('Level 4 - Entry', style: TextStyle(fontSize: 12))),
                    ],
                    onChanged: (val) {
                      setState(() {
                        _selectedLevel = val ?? '';
                        _currentPage = 1;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: dark ? AppColors.darkSecondarySurface : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: dark ? AppColors.darkBordersAndDividers : const Color(0xFFE2E8F0)),
                  ),
                  child: DropdownButton<String>(
                    value: _selectedStatus.isEmpty ? null : _selectedStatus,
                    hint: const Text('All Status', style: TextStyle(fontSize: 12)),
                    underline: const SizedBox.shrink(),
                    items: const [
                      DropdownMenuItem(value: '', child: Text('All Status', style: TextStyle(fontSize: 12))),
                      DropdownMenuItem(value: 'Active', child: Text('Active', style: TextStyle(fontSize: 12))),
                      DropdownMenuItem(value: 'Inactive', child: Text('Inactive', style: TextStyle(fontSize: 12))),
                    ],
                    onChanged: (val) {
                      setState(() {
                        _selectedStatus = val ?? '';
                        _currentPage = 1;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  icon: const Icon(Icons.rotate_left_rounded, size: 14),
                  label: const Text('Reset', style: TextStyle(fontSize: 12)),
                  onPressed: _resetFilters,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Action Bar: Designations List Count + Download & Add Designation (+) buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        'Designations List',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: dark ? AppColors.darkPrimaryText : const Color(0xFF0F172A)),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(color: const Color(0xFFE0EDFF), borderRadius: BorderRadius.circular(12)),
                      child: Text('${filtered.length}', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Download button
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: dark ? AppColors.darkSecondarySurface : const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.download_rounded, size: 17, color: Color(0xFF2563EB)),
                      tooltip: 'Export / Download Excel',
                      padding: EdgeInsets.zero,
                      onPressed: _exportExcel,
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Add Designation (+) button
                  ElevatedButton.icon(
                    onPressed: () async {
                      final created = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(builder: (_) => const AdminDesignationFormScreen()),
                      );
                      if (created == true) _loadData();
                    },
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('Add Designation', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Designations Feed List
          if (filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: Text('No designations found', style: TextStyle(color: glass.textSecondary, fontSize: 14, fontWeight: FontWeight.w600)),
              ),
            )
          else ...[
            // Select All Toolbar
            Row(
              children: [
                Checkbox(
                  value: _selectAllChecked,
                  onChanged: _toggleSelectAll,
                ),
                Text('Select Page (${_selectedIds.length} selected)', style: TextStyle(fontSize: 12, color: glass.textSecondary, fontWeight: FontWeight.bold)),
                const Spacer(),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.sort_rounded, size: 20),
                  tooltip: 'Sort By',
                  onSelected: _onSort,
                  itemBuilder: (ctx) => const [
                    PopupMenuItem(value: 'title', child: Text('Sort by Title')),
                    PopupMenuItem(value: 'department', child: Text('Sort by Department')),
                    PopupMenuItem(value: 'level', child: Text('Sort by Level')),
                    PopupMenuItem(value: 'salary', child: Text('Sort by Min Salary')),
                    PopupMenuItem(value: 'employeeCount', child: Text('Sort by Employees Assigned')),
                    PopupMenuItem(value: 'status', child: Text('Sort by Status')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),

            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: paginated.length,
              itemBuilder: (context, index) {
                final d = paginated[index];
                final isSelected = _selectedIds.contains(d.id);
                return _buildDesignationCard(glass, cardBgColor, d, isSelected, dark);
              },
            ),

            // Pagination Controls Footer
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Showing $_startItemIndex to $_endItemIndex of ${filtered.length}', style: TextStyle(fontSize: 12, color: glass.textSecondary)),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left_rounded),
                      onPressed: _currentPage > 1 ? () => setState(() => _currentPage--) : null,
                    ),
                    Text('Page $_currentPage of $_totalPages', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: glass.textPrimary)),
                    IconButton(
                      icon: const Icon(Icons.chevron_right_rounded),
                      onPressed: _currentPage < _totalPages ? () => setState(() => _currentPage++) : null,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  value,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: color, height: 1.1),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(title, style: const TextStyle(fontSize: 10, color: Color(0xFF475569), fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildDesignationCard(GlassTheme glass, Color cardBgColor, DesignationModel d, bool isSelected, bool dark) {
    final currencyFmt = NumberFormat.currency(symbol: '₹', decimalDigits: 0);
    final salaryText = (d.minSalary != null && d.maxSalary != null)
        ? '${currencyFmt.format(d.minSalary)} - ${currencyFmt.format(d.maxSalary)}'
        : (d.minSalary != null ? 'From ${currencyFmt.format(d.minSalary)}' : 'N/A');

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: dark ? AppColors.darkMainSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: dark ? AppColors.darkBordersAndDividers : const Color(0xFFF1F5F9)),
        boxShadow: const [BoxShadow(color: Color.fromRGBO(15, 23, 42, 0.04), blurRadius: 16, offset: Offset(0, 4))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: isSelected,
                  onChanged: (val) => _toggleSelectRow(d.id, val),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(d.title, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: dark ? AppColors.darkPrimaryText : const Color(0xFF0F172A))),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: d.isActive ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              d.status.toUpperCase(),
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: d.isActive ? const Color(0xFF16A34A) : const Color(0xFF64748B)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text('${d.departmentName ?? 'General Department'} • ${d.level ?? 'Mid Level'}', style: TextStyle(fontSize: 12, color: glass.textSecondary, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.currency_rupee_rounded, size: 13, color: Color(0xFF94A3B8)),
                          const SizedBox(width: 4),
                          Text(salaryText, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: dark ? AppColors.darkPrimaryText : const Color(0xFF0F172A))),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(Icons.groups_outlined, size: 13, color: Color(0xFF94A3B8)),
                          const SizedBox(width: 4),
                          Text('${d.employeeCount} Assigned Employees', style: TextStyle(fontSize: 11.5, color: glass.textSecondary)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1, color: Color(0xFFF1F5F9)),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                InkWell(
                  onTap: () async {
                    final updated = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(builder: (_) => AdminDesignationFormScreen(designationId: d.id, initialData: {
                        'id': d.id,
                        'title': d.title,
                        'level': d.level,
                        'departmentId': d.departmentId,
                        'minSalary': d.minSalary,
                        'maxSalary': d.maxSalary,
                        'status': d.status,
                      })),
                    );
                    if (updated == true) _loadData();
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.edit_rounded, size: 16, color: Color(0xFF2563EB)),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => _deleteDesignation(d),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.delete_rounded, size: 16, color: Color(0xFFDC2626)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
