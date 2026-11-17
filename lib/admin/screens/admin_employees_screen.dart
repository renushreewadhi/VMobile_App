import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/auth/auth_service.dart';
import '../../core/errors/api_exception.dart';
import '../../core/models/user_model.dart';
import '../../core/theme/glass_theme.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/glass_header.dart';
import 'admin_employee_detail_screen.dart';
import 'admin_employee_form_screen.dart';

/// Strongly typed Employee Model
class EmployeeModel {
  final String id;
  final String employeeId;
  final String firstName;
  final String lastName;
  final String email;
  final String? phone;
  final String? department;
  final String? designation;
  final String? joiningDate;
  final String employmentStatus;

  EmployeeModel({
    required this.id,
    required this.employeeId,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.phone,
    this.department,
    this.designation,
    this.joiningDate,
    required this.employmentStatus,
  });

  String get fullName => '$firstName $lastName'.trim();

  bool get isActive {
    final s = employmentStatus.toUpperCase();
    return s == 'ACTIVE' || s == 'TRUE';
  }

  factory EmployeeModel.fromJson(Map<String, dynamic> json) {
    String fName = json['firstName']?.toString() ?? '';
    String lName = json['lastName']?.toString() ?? '';
    if (fName.isEmpty && lName.isEmpty) {
      final name = json['fullName']?.toString() ?? json['name']?.toString() ?? json['employeeName']?.toString() ?? json['username']?.toString() ?? '';
      if (name.isNotEmpty) {
        final parts = name.trim().split(' ');
        fName = parts.first;
        if (parts.length > 1) {
          lName = parts.sublist(1).join(' ');
        }
      }
    }

    String? dept;
    if (json['departmentName'] != null) {
      dept = json['departmentName'].toString();
    } else if (json['department'] != null) {
      if (json['department'] is Map) {
        dept = (json['department']['name'] ?? json['department']['departmentName'])?.toString();
      } else {
        dept = json['department'].toString();
      }
    }

    String? desig;
    if (json['designationTitle'] != null) {
      desig = json['designationTitle'].toString();
    } else if (json['designation'] != null) {
      if (json['designation'] is Map) {
        desig = (json['designation']['title'] ?? json['designation']['name'])?.toString();
      } else {
        desig = json['designation'].toString();
      }
    }

    final idStr = json['id']?.toString() ?? json['_id']?.toString() ?? json['userId']?.toString() ?? '';
    final code = json['employeeId']?.toString() ?? json['employeeCode']?.toString() ?? json['code']?.toString() ?? json['userCode']?.toString();
    final fallbackCode = idStr.isNotEmpty ? 'EMP-${idStr.length >= 4 ? idStr.substring(idStr.length - 4).toUpperCase() : idStr.toUpperCase()}' : 'EMP-000';

    final rawStatus = json['employmentStatus']?.toString() ?? json['status']?.toString();
    final status = rawStatus ?? (json['isActive'] == false ? 'Inactive' : 'Active');

    return EmployeeModel(
      id: idStr,
      employeeId: (code != null && code.isNotEmpty) ? code : fallbackCode,
      firstName: fName.isNotEmpty ? fName : 'Employee',
      lastName: lName,
      email: json['email']?.toString() ?? json['workEmail']?.toString() ?? '',
      phone: json['phone']?.toString() ?? json['phoneNumber']?.toString() ?? json['mobile']?.toString(),
      department: dept,
      designation: desig,
      joiningDate: json['joiningDate']?.toString() ?? json['startDate']?.toString() ?? json['dateOfJoining']?.toString() ?? json['createdAt']?.toString(),
      employmentStatus: status,
    );
  }
}

class AdminEmployeesScreen extends ConsumerStatefulWidget {
  const AdminEmployeesScreen({super.key});

  @override
  ConsumerState<AdminEmployeesScreen> createState() => _AdminEmployeesScreenState();
}

class _AdminEmployeesScreenState extends ConsumerState<AdminEmployeesScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<EmployeeModel> _employees = [];
  List<String> _departmentsList = [];
  List<String> _designationsList = [];

  // Filter state
  String _searchTerm = '';
  String _selectedDepartment = '';
  String _selectedDesignation = '';
  String _selectedStatus = '';

  // Pagination (7 records per page matching Angular spec)
  int _currentPage = 1;
  final int _pageSize = 7;

  // Selection state
  final Set<String> _selectedIds = {};

  // Sorting state
  String _sortColumn = 'name'; // 'employeeId', 'name', 'email', 'department', 'designation', 'joiningDate', 'status'
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
    _requestId++; // Immediately invalidate any in-flight requests
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

    // Role Guard Check: Must be ADMIN or HR
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

    _loadEmployees();
  }

  void _resetState() {
    _employees = [];
    _departmentsList = [];
    _designationsList = [];
    _selectedIds.clear();
    _resetFilters();
  }

  void _resetFilters() {
    setState(() {
      _searchTerm = '';
      _selectedDepartment = '';
      _selectedDesignation = '';
      _selectedStatus = '';
      _currentPage = 1;
      _selectedIds.clear();
    });
  }

  List<dynamic> _extractList(dynamic res) {
    if (res == null) return [];
    if (res is List) return res;
    if (res is Map) {
      for (final key in ['data', 'result', 'items', 'employees', 'users', 'content', 'list', 'value']) {
        if (res[key] is List) return res[key] as List;
        if (res[key] is Map) {
          final nested = _extractList(res[key]);
          if (nested.isNotEmpty) return nested;
        }
      }
    }
    return [];
  }

  Future<void> _loadEmployees() async {
    final currentReq = ++_requestId;
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final apiClient = ref.read(apiClientProvider);

    try {
      dynamic res;
      dynamic lastError;

      final endpoints = [
        ApiEndpoints.employeesAll,
        '/employees/all',
        ApiEndpoints.employees,
        '/employees',
        ApiEndpoints.managementEmployees,
        '/management/employees',
        ApiEndpoints.users,
        '/users',
      ];

      for (final ep in endpoints) {
        try {
          dynamic tempRes = await apiClient.get(ep).catchError((_) async {
            return await apiClient.get('$ep?limit=500').catchError((_) => null);
          });
          if (tempRes != null && _extractList(tempRes).isNotEmpty) {
            res = tempRes;
            break;
          } else if (res == null && tempRes != null) {
            res = tempRes;
          }
        } catch (e) {
          lastError = e;
        }
      }

      // Fetch departments & designations in parallel to populate dropdown options
      List<String> fetchedDepts = [];
      List<String> fetchedDesigs = [];
      try {
        final deptsRes = await apiClient.get(ApiEndpoints.departments).catchError((_) => null);
        final desigsRes = await apiClient.get(ApiEndpoints.designations).catchError((_) => null);

        final rawDepts = _extractList(deptsRes);
        final rawDesigs = _extractList(desigsRes);

        for (final d in rawDepts) {
          if (d is Map) {
            final name = (d['name'] ?? d['departmentName'] ?? d['title'])?.toString();
            if (name != null && name.trim().isNotEmpty) fetchedDepts.add(name.trim());
          }
        }
        for (final d in rawDesigs) {
          if (d is Map) {
            final title = (d['title'] ?? d['name'] ?? d['designationTitle'])?.toString();
            if (title != null && title.trim().isNotEmpty) fetchedDesigs.add(title.trim());
          }
        }
      } catch (_) {}

      if (!mounted || currentReq != _requestId) return;

      final rawData = _extractList(res);

      List<EmployeeModel> items = [];
      for (final item in rawData) {
        if (item is Map) {
          try {
            items.add(EmployeeModel.fromJson(Map<String, dynamic>.from(item)));
          } catch (e) {
            debugPrint('[AdminEmployees] Skipped invalid employee item: $e');
          }
        }
      }

      if (items.isEmpty && res == null && lastError != null) {
        final msg = lastError is ApiException ? lastError.message : lastError.toString();
        setState(() {
          _errorMessage = msg;
          _isLoading = false;
        });
        return;
      }

      final deptSet = Set<String>.from(fetchedDepts);
      final desigSet = Set<String>.from(fetchedDesigs);
      for (final e in items) {
        if (e.department != null && e.department!.trim().isNotEmpty) deptSet.add(e.department!);
        if (e.designation != null && e.designation!.trim().isNotEmpty) desigSet.add(e.designation!);
      }

      if (!mounted || currentReq != _requestId) return;
      setState(() {
        _employees = items;
        _departmentsList = deptSet.toList()..sort();
        _designationsList = desigSet.toList()..sort();
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
        _errorMessage = 'Failed to load employee directory. Please check network connection.';
        _isLoading = false;
      });
    }
  }

  List<EmployeeModel> get _filteredEmployees {
    var list = _employees.where((e) {
      final name = e.fullName.toLowerCase();
      final email = e.email.toLowerCase();
      final empId = e.employeeId.toLowerCase();
      final dept = (e.department ?? '').toLowerCase();
      final desig = (e.designation ?? '').toLowerCase();
      final status = e.employmentStatus.toLowerCase();

      final matchesSearch = _searchTerm.trim().isEmpty ||
          name.contains(_searchTerm.toLowerCase()) ||
          email.contains(_searchTerm.toLowerCase()) ||
          empId.contains(_searchTerm.toLowerCase());

      final matchesDept = _selectedDepartment.isEmpty || dept == _selectedDepartment.toLowerCase();
      final matchesDesig = _selectedDesignation.isEmpty || desig == _selectedDesignation.toLowerCase();
      final matchesStatus = _selectedStatus.isEmpty || status == _selectedStatus.toLowerCase();

      return matchesSearch && matchesDept && matchesDesig && matchesStatus;
    }).toList();

    // Apply Sorting
    list.sort((a, b) {
      int comparison = 0;
      switch (_sortColumn) {
        case 'employeeId':
          comparison = a.employeeId.toLowerCase().compareTo(b.employeeId.toLowerCase());
          break;
        case 'name':
          comparison = a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase());
          break;
        case 'email':
          comparison = a.email.toLowerCase().compareTo(b.email.toLowerCase());
          break;
        case 'department':
          comparison = (a.department ?? '').toLowerCase().compareTo((b.department ?? '').toLowerCase());
          break;
        case 'designation':
          comparison = (a.designation ?? '').toLowerCase().compareTo((b.designation ?? '').toLowerCase());
          break;
        case 'joiningDate':
          comparison = (a.joiningDate ?? '').compareTo(b.joiningDate ?? '');
          break;
        case 'status':
          comparison = a.employmentStatus.compareTo(b.employmentStatus);
          break;
      }
      return _sortAscending ? comparison : -comparison;
    });

    return list;
  }

  List<EmployeeModel> get _paginatedEmployees {
    final filtered = _filteredEmployees;
    if (filtered.isEmpty) return [];
    final startIndex = (_currentPage - 1) * _pageSize;
    if (startIndex >= filtered.length) return [];
    final endIndex = (startIndex + _pageSize < filtered.length) ? startIndex + _pageSize : filtered.length;
    return filtered.sublist(startIndex, endIndex);
  }

  int get _totalPages {
    final count = _filteredEmployees.length;
    return (count / _pageSize).ceil() > 0 ? (count / _pageSize).ceil() : 1;
  }

  int get _startItemIndex {
    if (_filteredEmployees.isEmpty) return 0;
    return (_currentPage - 1) * _pageSize + 1;
  }

  int get _endItemIndex {
    final filtered = _filteredEmployees;
    return (_currentPage * _pageSize < filtered.length) ? _currentPage * _pageSize : filtered.length;
  }

  int get _activeCount => _employees.where((e) => e.isActive).length;
  int get _inactiveCount => _employees.length - _activeCount;

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

  void _exportExcel() {
    final filtered = _filteredEmployees;
    if (filtered.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No employees available to export.')),
      );
      return;
    }

    final rows = [
      ['Employee ID', 'Full Name', 'Email', 'Department', 'Designation', 'Joining Date', 'Status'],
      ...filtered.map((e) => [
            e.employeeId,
            e.fullName,
            e.email,
            e.department ?? 'General',
            e.designation ?? 'Staff',
            e.joiningDate ?? '—',
            e.employmentStatus,
          ]),
    ];

    final csvBuffer = StringBuffer();
    for (final row in rows) {
      csvBuffer.writeln(row.map((c) => '"${c.replaceAll('"', '""')}"').join(','));
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Exported ${filtered.length} employees.')),
    );
  }

  Future<void> _deleteEmployee(EmployeeModel emp) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete employee "${emp.fullName}"?'),
        content: const Text('This action will permanently delete the employee record.'),
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
      await apiClient.delete(ApiEndpoints.employeeDelete(emp.id));
      if (!mounted || currentReq != _requestId) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Employee deleted successfully')),
      );
      _loadEmployees();
    } catch (e) {
      if (!mounted || currentReq != _requestId) return;
      final msg = e is ApiException ? e.message : 'Failed to delete employee.';
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

    // Account switching listener
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
        title: 'Employee Management',
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
                      Text('You do not have administrative permissions to view the employee directory.', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: glass.textSecondary)),
                    ],
                  ),
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadEmployees,
              child: _buildMainContent(glass, cardBgColor),
            ),
    );
  }

  Widget _buildMainContent(GlassTheme glass, Color cardBgColor) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authState = ref.watch(authServiceProvider);
    final userRole = authState.user?.role;
    final bool isAuthorized = userRole == UserRole.ADMIN || userRole == UserRole.HR;

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
              Text('Unable to Load Employees', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: glass.textPrimary)),
              const SizedBox(height: 8),
              Text(_errorMessage!, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: glass.textSecondary)),
              const SizedBox(height: 24),
              AppButton(label: 'Retry', icon: Icons.refresh_rounded, width: 140, onPressed: _loadEmployees),
            ],
          ),
        ),
      );
    }

    final filtered = _filteredEmployees;
    final paginated = _paginatedEmployees;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Header Banner with Export & Add Employee Actions
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cardBgColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: glass.cardBorder, width: 1),
              boxShadow: [
                BoxShadow(
                  color: isDark ? Colors.black12 : const Color(0x060F6B66),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Employee Directory',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: glass.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Manage employee profiles, directory records, and roles',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: glass.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isAuthorized) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.download_rounded, size: 20),
                    tooltip: 'Export Excel',
                    onPressed: _exportExcel,
                  ),
                  const SizedBox(width: 4),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final created = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(builder: (_) => const AdminEmployeeFormScreen()),
                      );
                      if (created == true) _loadEmployees();
                    },
                    icon: const Icon(Icons.person_add_rounded, size: 16, color: Colors.white),
                    label: const Text('Add', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F6B63),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),

          // KPI Metric Summary Cards (4 Cards Grid)
          Row(
            children: [
              Expanded(child: _buildStatTile(glass, cardBgColor, label: 'Total Employees', value: '${_employees.length}', icon: Icons.groups_rounded, iconColor: const Color(0xFF2563EB), iconBgColor: const Color(0xFFE0EDFF))),
              const SizedBox(width: 8),
              Expanded(child: _buildStatTile(glass, cardBgColor, label: 'Active Employees', value: '$_activeCount', icon: Icons.check_circle_outline_rounded, iconColor: const Color(0xFF16A34A), iconBgColor: const Color(0xFFDCFCE7))),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildStatTile(glass, cardBgColor, label: 'Inactive Employees', value: '$_inactiveCount', icon: Icons.pause_circle_outline_rounded, iconColor: const Color(0xFFDC2626), iconBgColor: const Color(0xFFFEE2E2))),
              const SizedBox(width: 8),
              Expanded(child: _buildStatTile(glass, cardBgColor, label: 'Departments', value: '${_departmentsList.length}', icon: Icons.corporate_fare_rounded, iconColor: const Color(0xFFEA580C), iconBgColor: const Color(0xFFFFEDD5))),
            ],
          ),
          const SizedBox(height: 16),

          // Search Input & Filters
          TextField(
            decoration: InputDecoration(
              hintText: 'Search by employee name, email, ID...',
              hintStyle: TextStyle(color: glass.textSecondary, fontSize: 13),
              prefixIcon: Icon(Icons.search_rounded, color: glass.textSecondary),
              filled: true,
              fillColor: cardBgColor,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: glass.cardBorder)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: glass.cardBorder)),
            ),
            style: TextStyle(color: glass.textPrimary),
            onChanged: (val) {
              setState(() {
                _searchTerm = val;
                _currentPage = 1;
              });
            },
          ),
          const SizedBox(height: 12),

          // Filter Dropdowns Row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                DropdownButton<String>(
                  value: _selectedDepartment.isEmpty ? null : _selectedDepartment,
                  hint: const Text('All Departments', style: TextStyle(fontSize: 12)),
                  underline: const SizedBox.shrink(),
                  items: [
                    const DropdownMenuItem(value: '', child: Text('All Departments', style: TextStyle(fontSize: 12))),
                    ..._departmentsList.map((d) => DropdownMenuItem(value: d, child: Text(d, style: const TextStyle(fontSize: 12)))),
                  ],
                  onChanged: (val) {
                    setState(() {
                      _selectedDepartment = val ?? '';
                      _currentPage = 1;
                    });
                  },
                ),
                const SizedBox(width: 12),
                DropdownButton<String>(
                  value: _selectedDesignation.isEmpty ? null : _selectedDesignation,
                  hint: const Text('All Designations', style: TextStyle(fontSize: 12)),
                  underline: const SizedBox.shrink(),
                  items: [
                    const DropdownMenuItem(value: '', child: Text('All Designations', style: TextStyle(fontSize: 12))),
                    ..._designationsList.map((d) => DropdownMenuItem(value: d, child: Text(d, style: const TextStyle(fontSize: 12)))),
                  ],
                  onChanged: (val) {
                    setState(() {
                      _selectedDesignation = val ?? '';
                      _currentPage = 1;
                    });
                  },
                ),
                const SizedBox(width: 12),
                DropdownButton<String>(
                  value: _selectedStatus.isEmpty ? null : _selectedStatus,
                  hint: const Text('All Status', style: TextStyle(fontSize: 12)),
                  underline: const SizedBox.shrink(),
                  items: [
                    const DropdownMenuItem(value: '', child: Text('All Status', style: TextStyle(fontSize: 12))),
                    const DropdownMenuItem(value: 'Active', child: Text('Active', style: TextStyle(fontSize: 12))),
                    const DropdownMenuItem(value: 'Inactive', child: Text('Inactive', style: TextStyle(fontSize: 12))),
                  ],
                  onChanged: (val) {
                    setState(() {
                      _selectedStatus = val ?? '';
                      _currentPage = 1;
                    });
                  },
                ),
                const SizedBox(width: 12),
                TextButton.icon(
                  icon: const Icon(Icons.rotate_left_rounded, size: 16),
                  label: const Text('Reset', style: TextStyle(fontSize: 12)),
                  onPressed: _resetFilters,
                ),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.sort_rounded, size: 20),
                  tooltip: 'Sort By',
                  onSelected: _onSort,
                  itemBuilder: (ctx) => const [
                    PopupMenuItem(value: 'employeeId', child: Text('Sort by Employee ID')),
                    PopupMenuItem(value: 'name', child: Text('Sort by Name')),
                    PopupMenuItem(value: 'email', child: Text('Sort by Email')),
                    PopupMenuItem(value: 'department', child: Text('Sort by Department')),
                    PopupMenuItem(value: 'designation', child: Text('Sort by Designation')),
                    PopupMenuItem(value: 'joiningDate', child: Text('Sort by Joining Date')),
                    PopupMenuItem(value: 'status', child: Text('Sort by Status')),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Employees Feed List
          if (filtered.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 16),
              alignment: Alignment.center,
              child: Column(
                children: [
                  Icon(Icons.groups_outlined, size: 56, color: glass.textSecondary.withAlpha(128)),
                  const SizedBox(height: 16),
                  Text('No Employees Found', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: glass.textPrimary)),
                  const SizedBox(height: 8),
                  Text('There are no employee records matching your search or filter criteria.', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: glass.textSecondary)),
                ],
              ),
            )
          else ...[

            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: paginated.length,
              itemBuilder: (context, index) {
                final emp = paginated[index];
                final isSelected = _selectedIds.contains(emp.id);
                return _buildEmployeeCard(glass, cardBgColor, emp, isSelected);
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

  Widget _buildStatTile(
    GlassTheme glass,
    Color cardBgColor, {
    required String label,
    required String value,
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: const [BoxShadow(color: Color.fromRGBO(15, 23, 42, 0.03), blurRadius: 12, offset: Offset(0, 3))],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: iconBgColor, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A), height: 1.1)),
                const SizedBox(height: 2),
                Text(label, style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeCard(GlassTheme glass, Color cardBgColor, EmployeeModel emp, bool isSelected) {
    final initials = emp.fullName.isNotEmpty
        ? emp.fullName.split(' ').map((n) => n.isNotEmpty ? n[0] : '').join('').toUpperCase()
        : 'EM';
    final safeInitials = initials.length >= 2 ? initials.substring(0, 2) : initials;

    return AppCard(
      backgroundColor: cardBgColor,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0EDFF),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  safeInitials,
                  style: const TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.w800, fontSize: 16),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(emp.fullName, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: glass.textPrimary)),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: emp.isActive ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            emp.employmentStatus.toUpperCase(),
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: emp.isActive ? const Color(0xFF16A34A) : const Color(0xFF64748B)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text('${emp.employeeId} • ${emp.department ?? 'General'}', style: TextStyle(fontSize: 12, color: glass.textSecondary, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(emp.designation ?? 'Staff', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: glass.textPrimary)),
                    if (emp.email.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(emp.email, style: TextStyle(fontSize: 11, color: glass.textSecondary)),
                    ],
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.calendar_today_rounded, size: 13, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 5),
                  Text(emp.joiningDate ?? 'Joined recently', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
                ],
              ),
              Row(
                children: [
                  InkWell(
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => AdminEmployeeDetailScreen(employeeId: emp.id)),
                      );
                      _loadEmployees();
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.remove_red_eye_rounded, size: 16, color: Color(0xFF2563EB)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () async {
                      final updated = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(builder: (_) => AdminEmployeeFormScreen(employeeId: emp.id)),
                      );
                      if (updated == true) _loadEmployees();
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.edit_rounded, size: 16, color: Color(0xFFD97706)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => _deleteEmployee(emp),
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
        ],
      ),
    );
  }
}
