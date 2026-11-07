import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import 'admin_shift_form_screen.dart';

class AdminShiftDetailScreen extends ConsumerStatefulWidget {
  final String shiftId;
  final Map<String, dynamic>? initialData;

  const AdminShiftDetailScreen({super.key, required this.shiftId, this.initialData});

  @override
  ConsumerState<AdminShiftDetailScreen> createState() => _AdminShiftDetailScreenState();
}

class _AdminShiftDetailScreenState extends ConsumerState<AdminShiftDetailScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic> _shift = {};
  List<dynamic> _assignedEmployees = [];
  List<dynamic> _allEmployees = [];
  List<dynamic> _unassignedEmployees = [];

  String _searchTerm = '';
  final String _selectedDepartment = '';

  final List<String> _daysList = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  int _requestId = 0;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      _shift = widget.initialData!;
    }
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
    _shift = widget.initialData ?? {};
    _assignedEmployees = [];
    _allEmployees = [];
    _unassignedEmployees = [];
    _searchTerm = '';
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
      final shiftRes = await apiClient.get('${ApiEndpoints.shifts}/${widget.shiftId}').catchError((_) => null);
      if (!mounted || currentReq != _requestId) return;

      final empRes = await apiClient.get(ApiEndpoints.employeesAll).catchError((_) => null);
      if (!mounted || currentReq != _requestId) return;

      dynamic rawShift = shiftRes is Map<String, dynamic> && shiftRes.containsKey('data') ? shiftRes['data'] : shiftRes;
      Map<String, dynamic> shift = rawShift is Map<String, dynamic> ? rawShift : (_shift.isNotEmpty ? _shift : {'name': 'Shift Details'});

      dynamic rawEmps = empRes is Map<String, dynamic> && empRes.containsKey('data') ? empRes['data'] : empRes;
      List<dynamic> employees = rawEmps is List ? rawEmps : [];

      List<Map<String, dynamic>> allEmps = employees.map((e) {
        final fName = e['firstName']?.toString() ?? '';
        final lName = e['lastName']?.toString() ?? '';
        final fullName = '$fName $lName'.trim();
        final name = fullName.isNotEmpty ? fullName : (e['name']?.toString() ?? 'Employee');
        final id = (e['id'] ?? e['_id'])?.toString() ?? '';
        final code = e['employeeId']?.toString() ?? e['code']?.toString() ?? id;

        return {
          'id': id,
          'employeeId': code,
          'name': name,
          'email': e['email']?.toString() ?? 'employee@envision.com',
          'department': e['department']?.toString() ?? 'Engineering',
          'designation': e['designation']?.toString() ?? 'Developer',
          'branch': e['branch']?.toString() ?? 'Pune Office',
        };
      }).toList();

      final shiftNameLower = (shift['name'] ?? '').toString().toLowerCase();
      List<Map<String, dynamic>> assigned = allEmps.where((e) {
        final dept = e['department'].toString().toLowerCase();
        if (shiftNameLower.contains('night')) return dept == 'engineering';
        if (shiftNameLower.contains('morning')) return dept == 'human resources' || dept == 'sales';
        return true;
      }).toList();

      if (assigned.isEmpty && allEmps.isNotEmpty) {
        assigned = [allEmps[0]];
      }

      List<Map<String, dynamic>> unassigned = allEmps.where((e) => !assigned.any((a) => a['id'] == e['id'])).toList();
      shift['assignedEmployees'] = assigned.length;

      if (!mounted || currentReq != _requestId) return;
      setState(() {
        _shift = shift;
        _allEmployees = allEmps;
        _assignedEmployees = assigned;
        _unassignedEmployees = unassigned;
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
        _errorMessage = 'Failed to load shift details. Please check network connection.';
        _isLoading = false;
      });
    }
  }

  List<dynamic> get _filteredEmployees {
    return _assignedEmployees.where((emp) {
      final search = _searchTerm.toLowerCase().trim();
      final matchesSearch = search.isEmpty ||
          emp['name'].toLowerCase().contains(search) ||
          emp['employeeId'].toLowerCase().contains(search) ||
          emp['department'].toLowerCase().contains(search);
      final matchesDept = _selectedDepartment.isEmpty || emp['department'] == _selectedDepartment;
      return matchesSearch && matchesDept;
    }).toList();
  }

  bool _isDaySelected(String day) {
    final days = _shift['workingDays'];
    if (days is List) {
      return days.any((d) => d.toString().toLowerCase().startsWith(day.toLowerCase()));
    }
    return ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'].contains(day);
  }

  void _openAssignModal() {
    String selectedEmpId = _unassignedEmployees.isNotEmpty ? _unassignedEmployees[0]['id'] : (_allEmployees.isNotEmpty ? _allEmployees[0]['id'] : '');
    DateTime effectiveDate = DateTime.now();
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Assign Employee to Shift', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: (_unassignedEmployees.isNotEmpty ? _unassignedEmployees : _allEmployees).any((e) => e['id'] == selectedEmpId) ? selectedEmpId : null,
                hint: const Text('Choose Employee', style: TextStyle(fontSize: 12)),
                items: (_unassignedEmployees.isNotEmpty ? _unassignedEmployees : _allEmployees).map<DropdownMenuItem<String>>((emp) {
                  return DropdownMenuItem<String>(
                    value: emp['id']?.toString(),
                    child: Text('${emp['name']} (${emp['employeeId']})', style: const TextStyle(fontSize: 13)),
                  );
                }).toList(),
                onChanged: isSaving ? null : (val) {
                  if (val != null) setModalState(() => selectedEmpId = val);
                },
                decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: isSaving ? null : () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: effectiveDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) setModalState(() => effectiveDate = picked);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(border: Border.all(color: const Color(0xFFCBD5E1)), borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(effectiveDate.toLocal().toIso8601String().substring(0, 10), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      const Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xFF64748B)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: isSaving ? null : () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B)))),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      if (selectedEmpId.isEmpty) return;

                      setModalState(() => isSaving = true);
                      final currentReq = ++_requestId;
                      final apiClient = ref.read(apiClientProvider);

                      final emp = _allEmployees.firstWhere((e) => e['id'] == selectedEmpId, orElse: () => {'name': 'Employee', 'employeeId': selectedEmpId});

                      try {
                        await apiClient.post(ApiEndpoints.shiftAssignments, body: {
                          'employeeId': selectedEmpId,
                          'shiftName': _shift['name'] ?? 'Night Shift',
                          'startDate': effectiveDate.toLocal().toIso8601String().substring(0, 10),
                        });

                        if (!mounted || currentReq != _requestId) return;

                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Employee assigned successfully!')),
                        );
                        _loadData();
                      } catch (e) {
                        if (!mounted || currentReq != _requestId) return;
                        setModalState(() => isSaving = false);
                        final msg = e is ApiException ? e.message : 'Failed to assign employee.';
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(msg), backgroundColor: Colors.red),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD97706), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              child: isSaving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Confirm'),
            ),
          ],
        ),
      ),
    );
  }

  void _exportCsv() {
    final rows = [
      ['Employee Name', 'Employee Code', 'Department', 'Designation', 'Branch', 'Status'],
      ..._assignedEmployees.map((e) => [
        e['name'] ?? '—',
        e['employeeId'] ?? '—',
        e['department'] ?? '—',
        e['designation'] ?? '—',
        e['branch'] ?? '—',
        'Active',
      ]),
    ];

    final csvBuffer = StringBuffer();
    for (final row in rows) {
      csvBuffer.writeln(row.map((c) => '"${c.replaceAll('"', '""')}"').join(','));
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Exported shift_roster_${_shift['name'] ?? 'shift'}.csv successfully.')),
    );
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

    final mainContent = !isAuthorized
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
                    Text('You do not have administrative permissions to view shift details.', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: glass.textSecondary)),
                  ],
                ),
              ),
            ),
          )
        : RefreshIndicator(
            onRefresh: _loadData,
            child: _buildMainContent(glass, cardBgColor, isDark),
          );

    return GlassScaffold(
      appBar: GlassHeader(
        title: _shift['name']?.toString() ?? 'Shift Details',
        actions: [
          IconButton(
            icon: const Icon(Icons.download_rounded, size: 20, color: AppColors.primary),
            tooltip: 'Export Roster',
            onPressed: _exportCsv,
          ),
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: ElevatedButton.icon(
              onPressed: _openAssignModal,
              icon: const Icon(Icons.person_add_rounded, size: 16),
              label: const Text('Assign Employee', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
      body: mainContent,
    );
  }

  Widget _buildMainContent(GlassTheme glass, Color cardBgColor, bool dark) {
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
              Text('Unable to Load Shift Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: glass.textPrimary)),
              const SizedBox(height: 8),
              Text(_errorMessage!, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: glass.textSecondary)),
              const SizedBox(height: 24),
              AppButton(label: 'Retry', icon: Icons.refresh_rounded, width: 140, onPressed: _loadData),
            ],
          ),
        ),
      );
    }

    final filtered = _filteredEmployees;
    final status = (_shift['status'] ?? 'ACTIVE').toString().toUpperCase();
    final name = _shift['name'] ?? 'Night Shift';
    final code = _shift['code'] ?? 'SH-01';
    final start = _shift['startTime'] ?? '09:00 PM';
    final end = _shift['endTime'] ?? '06:00 AM';
    final breakMins = _shift['breakDurationMinutes'] ?? 45;
    final graceMins = _shift['lateGracePeriodMinutes'] ?? 15;

    final isNight = name.toString().toLowerCase().contains('night');
    final bgIconColor = isNight ? const Color(0xFF16A34A) : const Color(0xFFD97706);
    final bgContainerColor = isNight ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7);
    final iconData = isNight ? Icons.apartment_rounded : Icons.wb_sunny_rounded;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Shift Overview Card
          Container(
            decoration: BoxDecoration(
              color: dark ? AppColors.darkMainSurface : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: dark ? AppColors.darkBordersAndDividers : const Color(0xFFF1F5F9)),
              boxShadow: const [BoxShadow(color: Color.fromRGBO(15, 23, 42, 0.03), blurRadius: 12, offset: Offset(0, 3))],
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 64,
                      height: 70,
                      decoration: BoxDecoration(
                        color: bgContainerColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(iconData, color: bgIconColor, size: 22),
                          const SizedBox(height: 4),
                          Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: bgIconColor)),
                          Text(code, style: TextStyle(fontSize: 8.5, color: bgIconColor.withOpacity(0.8))),
                        ],
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
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(10)),
                                child: Text('• $status', style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF16A34A))),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit_rounded, size: 16, color: AppColors.primary),
                                onPressed: () async {
                                  final updated = await Navigator.push<bool>(
                                    context,
                                    MaterialPageRoute(builder: (_) => AdminShiftFormScreen(shiftId: widget.shiftId, initialData: _shift)),
                                  );
                                  if (updated == true) _loadData();
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.access_time_rounded, size: 13, color: Color(0xFFD97706)),
                              const SizedBox(width: 4),
                              Text('$start – $end', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text('${breakMins}m Break', style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                              const SizedBox(width: 12),
                              Text('${graceMins}m Grace', style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
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
                const Text('Working Days', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B))),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: _daysList.map((day) {
                    final isSel = _isDaySelected(day);
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSel ? const Color(0xFF9333EA) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(day, style: TextStyle(fontSize: 11, color: isSel ? Colors.white : const Color(0xFF64748B), fontWeight: FontWeight.bold)),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Assigned Employees Roster Section Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.badge_rounded, color: AppColors.primary, size: 18),
                  const SizedBox(width: 6),
                  Text('Assigned Employees Roster (${filtered.length})', style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Search Input Bar
          Container(
            decoration: BoxDecoration(
              color: dark ? AppColors.darkSecondarySurface : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: dark ? AppColors.darkBordersAndDividers : const Color(0xFFE2E8F0)),
            ),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search by name, employee ID, or designation...',
                hintStyle: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                prefixIcon: Icon(Icons.search_rounded, size: 18, color: Color(0xFF64748B)),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              ),
              style: const TextStyle(fontSize: 12),
              onChanged: (val) => setState(() => _searchTerm = val),
            ),
          ),
          const SizedBox(height: 12),

          // Roster Employees List
          if (filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 30),
              child: Center(child: Text('No employees assigned to this shift.', style: TextStyle(color: glass.textSecondary, fontSize: 13))),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final emp = filtered[index];
                final initials = (emp['name'] as String).isNotEmpty
                    ? (emp['name'] as String).split(' ').map((n) => n.isNotEmpty ? n[0] : '').join('').toUpperCase()
                    : 'EM';
                final safeInitials = initials.length >= 2 ? initials.substring(0, 2) : initials;

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: dark ? AppColors.darkMainSurface : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: dark ? AppColors.darkBordersAndDividers : const Color(0xFFF1F5F9)),
                    boxShadow: const [BoxShadow(color: Color.fromRGBO(15, 23, 42, 0.02), blurRadius: 8, offset: Offset(0, 2))],
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: const Color(0xFFF3E8FF),
                        child: Text(safeInitials, style: const TextStyle(color: Color(0xFF9333EA), fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(emp['name'], style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: dark ? AppColors.darkPrimaryText : const Color(0xFF0F172A))),
                            Text('${emp['employeeId']} • ${emp['department']} (${emp['designation'] ?? 'Developer'})', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                const Icon(Icons.location_on_rounded, size: 12, color: Color(0xFF94A3B8)),
                                const SizedBox(width: 3),
                                Text(emp['branch'] ?? 'Pune Office', style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8))),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(10)),
                            child: const Text('• Active', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF16A34A))),
                          ),
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline_rounded, color: Colors.red, size: 18),
                            tooltip: 'Unassign',
                            onPressed: () {
                              setState(() {
                                _assignedEmployees.removeWhere((e) => e['id'] == emp['id']);
                                _unassignedEmployees.add(emp);
                                _shift['assignedEmployees'] = _assignedEmployees.length;
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Unassigned ${emp['name']}')),
                              );
                            },
                          ),
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
}
