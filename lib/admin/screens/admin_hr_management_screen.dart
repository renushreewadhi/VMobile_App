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
import '../../core/widgets/glass_search_bar.dart';

class AdminHrManagementScreen extends ConsumerStatefulWidget {
  const AdminHrManagementScreen({super.key});

  @override
  ConsumerState<AdminHrManagementScreen> createState() => _AdminHrManagementScreenState();
}

class _AdminHrManagementScreenState extends ConsumerState<AdminHrManagementScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<dynamic> _hrMembers = [];
  List<dynamic> _candidates = [];
  String? _selectedEmployeeId;
  bool _assigning = false;
  String _searchTerm = '';

  // Pagination (matching Angular website table pagination specs)
  int _currentPage = 1;
  final int _pageSize = 10;

  // Request ID guard
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
    _requestId++; // Immediately invalidate pending requests
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

    _loadData();
  }

  void _resetState() {
    _hrMembers = [];
    _candidates = [];
    _selectedEmployeeId = null;
    _assigning = false;
    _searchTerm = '';
    _currentPage = 1;
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
      dynamic empRes;
      try {
        empRes = await apiClient.get(ApiEndpoints.employees);
      } catch (_) {
        try {
          empRes = await apiClient.get(ApiEndpoints.employeesAll);
        } catch (_) {
          empRes = null;
        }
      }
      if (!mounted || currentReq != _requestId) return;

      List<dynamic> empList = _parseList(empRes);

      // HR Members: Filter employees whose role is HR or designation indicates HR
      List<dynamic> hrList = empList.where((e) {
        if (e is! Map<String, dynamic>) return false;
        final role = (e['role'] ?? '').toString().toUpperCase();
        final desig = (e['designation'] ?? '').toString().toLowerCase();
        return role == 'HR' || desig.contains('hr manager') || desig.contains('hr executive') || desig.contains('hr specialist') || desig.contains('human resources');
      }).toList();

      // Candidates: active accounts, not already ADMIN, HR, or TL, and not inactive/terminated
      final candidateList = empList.where((e) {
        if (e is! Map<String, dynamic>) return false;
        final role = (e['role'] ?? '').toString().toUpperCase();
        if (role == 'ADMIN' || role == 'HR' || role == 'TL' || role == 'TEAM_LEAD') return false;

        final desig = (e['designation'] ?? '').toString().toLowerCase();
        if (desig.contains('hr manager') || desig.contains('hr executive') || desig.contains('hr specialist') || desig.contains('human resources')) return false;

        final status = (e['employmentStatus'] ?? e['status'] ?? 'Active').toString().toUpperCase();
        if (status.contains('INACTIVE') || status.contains('TERMINATED') || status.contains('RESIGNED') || status.contains('FALSE')) {
          return false;
        }

        return true;
      }).toList();

      if (!mounted || currentReq != _requestId) return;
      setState(() {
        _hrMembers = hrList;
        _candidates = candidateList;
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
        _errorMessage = 'Failed to load HR management data. Please check network connection.';
        _isLoading = false;
      });
    }
  }

  List<dynamic> _parseList(dynamic res) {
    if (res is List) return res;
    if (res is Map<String, dynamic>) {
      final val = res['items'] ?? res['data'] ?? res['result'] ?? res['content'] ?? [];
      if (val is List) return val;
    }
    return [];
  }

  List<dynamic> get _filteredHrMembers {
    return _hrMembers.where((hr) {
      final name = (hr['fullName'] ?? '${hr['firstName'] ?? ''} ${hr['lastName'] ?? ''}').toString().toLowerCase();
      final email = (hr['email'] ?? '').toString().toLowerCase();
      final empCode = (hr['employeeCode'] ?? hr['employeeId'] ?? hr['code'] ?? '').toString().toLowerCase();
      final dept = (hr['department'] ?? '').toString().toLowerCase();
      final desig = (hr['designation'] ?? '').toString().toLowerCase();
      final team = (hr['teamName'] ?? hr['team'] ?? '').toString().toLowerCase();

      final search = _searchTerm.trim().toLowerCase();

      return search.isEmpty ||
          name.contains(search) ||
          email.contains(search) ||
          empCode.contains(search) ||
          dept.contains(search) ||
          desig.contains(search) ||
          team.contains(search);
    }).toList();
  }

  List<dynamic> get _paginatedHrMembers {
    final filtered = _filteredHrMembers;
    if (filtered.isEmpty) return [];
    final startIndex = (_currentPage - 1) * _pageSize;
    if (startIndex >= filtered.length) return [];
    final endIndex = (startIndex + _pageSize < filtered.length) ? startIndex + _pageSize : filtered.length;
    return filtered.sublist(startIndex, endIndex);
  }

  int get _totalPages {
    final count = _filteredHrMembers.length;
    return (count / _pageSize).ceil() > 0 ? (count / _pageSize).ceil() : 1;
  }

  Future<void> _callAssignRoleApi(String employeeId, String role) async {
    final apiClient = ref.read(apiClientProvider);
    final payload = {'employeeId': employeeId, 'role': role};
    try {
      await apiClient.put(ApiEndpoints.assignRole, body: payload);
      return;
    } catch (_) {}

    try {
      await apiClient.put('/management/role', body: payload);
      return;
    } catch (_) {}

    try {
      await apiClient.post(ApiEndpoints.assignRole, body: payload);
      return;
    } catch (_) {}

    await apiClient.post('/management/role', body: payload);
  }

  Future<void> _assignAsHR() async {
    if (_selectedEmployeeId == null || _selectedEmployeeId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an eligible employee candidate.'), backgroundColor: Colors.red),
      );
      return;
    }

    if (_assigning) return;
    setState(() => _assigning = true);

    final currentReq = ++_requestId;

    try {
      await _callAssignRoleApi(_selectedEmployeeId!, 'HR');
      if (!mounted || currentReq != _requestId) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Employee assigned HR role successfully'),
          backgroundColor: Color(0xFF16A34A),
        ),
      );
      setState(() {
        _selectedEmployeeId = null;
        _assigning = false;
      });
      _loadData();
    } catch (e) {
      if (!mounted || currentReq != _requestId) return;
      setState(() => _assigning = false);
      final msg = e is ApiException ? e.message : 'Failed to assign HR role.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _revokeHR(Map<String, dynamic> hr) async {
    final hrName = hr['fullName']?.toString() ?? '${hr['firstName'] ?? ''} ${hr['lastName'] ?? ''}'.trim();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.delete_sweep_rounded, color: Color(0xFFEF4444), size: 24),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Revoke HR Role',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
            ),
          ],
        ),
        content: Text(
          'Remove $hrName from the HR role? They will become a regular Employee.',
          style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Revoke Role', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final currentReq = ++_requestId;
    final hrId = (hr['id'] ?? hr['employeeId'])?.toString();

    if (hrId == null || hrId.isEmpty) return;

    try {
      await _callAssignRoleApi(hrId, 'EMPLOYEE');
      if (!mounted || currentReq != _requestId) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('HR role revoked successfully'),
          backgroundColor: Color(0xFF16A34A),
        ),
      );
      _loadData();
    } catch (e) {
      if (!mounted || currentReq != _requestId) return;
      final msg = e is ApiException ? e.message : 'Failed to revoke HR role.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBgColor = isDark ? AppColors.darkMainSurface : Colors.white;

    // Account switching listener
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
                    Text('You do not have administrative permissions to manage HR privileges.', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: glass.textSecondary)),
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
        title: 'HR Management',
        actions: [
          if (isAuthorized)
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Refresh',
              onPressed: _loadData,
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
              Text('Unable to Load HR Management Data', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: glass.textPrimary)),
              const SizedBox(height: 8),
              Text(_errorMessage!, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: glass.textSecondary)),
              const SizedBox(height: 24),
              AppButton(label: 'Retry', icon: Icons.refresh_rounded, width: 140, onPressed: _loadData),
            ],
          ),
        ),
      );
    }

    final filtered = _filteredHrMembers;
    final paginated = _paginatedHrMembers;
    final startIndex = filtered.isEmpty ? 0 : (_currentPage - 1) * _pageSize + 1;
    final endIndex = (_currentPage * _pageSize < filtered.length) ? _currentPage * _pageSize : filtered.length;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Subtitle matching website header
          Text(
            'Assign, review, and manage HR team members',
            style: TextStyle(fontSize: 13, color: glass.textSecondary),
          ),
          const SizedBox(height: 16),

          // KPI Metric Cards (4 Executive Cards matching Angular website)
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  'Active HR Team',
                  '${_hrMembers.length}',
                  'HR Administrators',
                  Icons.supervised_user_circle_rounded,
                  const Color(0xFF2563EB),
                  dark ? const Color(0x332563EB) : const Color(0xFFE0EDFF),
                  dark,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetricCard(
                  'HR Status',
                  'Active',
                  'Full Access Granted',
                  Icons.check_circle_rounded,
                  const Color(0xFF10B981),
                  dark ? const Color(0x3310B981) : const Color(0xFFDCFCE7),
                  dark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  'Eligible Candidates',
                  '${_candidates.length}',
                  'Ready for HR Role',
                  Icons.person_add_rounded,
                  const Color(0xFF8B5CF6),
                  dark ? const Color(0x338B5CF6) : const Color(0xFFF3E8FF),
                  dark,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetricCard(
                  'Role Policy',
                  'Restricted',
                  'Admin Managed Only',
                  Icons.admin_panel_settings_rounded,
                  const Color(0xFFF59E0B),
                  dark ? const Color(0x33F59E0B) : const Color(0xFFFEF3C7),
                  dark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Assign New HR Role Card
          AppCard(
            backgroundColor: cardBgColor,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.person_add_rounded, size: 20, color: Color(0xFF2563EB)),
                    const SizedBox(width: 8),
                    Text('Assign New HR Role', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: glass.textPrimary)),
                  ],
                ),
                const SizedBox(height: 6),
                Text('Select an active employee account to grant HR administrative privileges.', style: TextStyle(fontSize: 12, color: glass.textSecondary)),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  value: _selectedEmployeeId,
                  hint: const Text('Select an employee to assign an HR role...', style: TextStyle(fontSize: 12)),
                  isExpanded: true,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  items: _candidates.map<DropdownMenuItem<String>>((c) {
                    final name = c['fullName'] ?? '${c['firstName'] ?? ''} ${c['lastName'] ?? ''}'.trim();
                    final code = c['employeeCode'] ?? c['employeeId'] ?? 'EMP';
                    final desig = c['designation'] ?? 'No designation';
                    return DropdownMenuItem<String>(
                      value: c['id']?.toString(),
                      child: Text('$name — $code ($desig)', style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: _assigning ? null : (val) => setState(() => _selectedEmployeeId = val),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: AppButton(
                    label: _assigning ? 'Assigning...' : 'Assign HR Role',
                    icon: _assigning ? null : Icons.verified_user_rounded,
                    isLoading: _assigning,
                    onPressed: _assigning || _selectedEmployeeId == null ? null : _assignAsHR,
                  ),
                ),
                if (_candidates.isEmpty) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, size: 14, color: Color(0xFFF59E0B)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'No eligible employees with active accounts available for HR role assignment.',
                          style: TextStyle(fontSize: 11, color: glass.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Current HR Team Members Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.list_alt_rounded, size: 20, color: Color(0xFF10B981)),
                  const SizedBox(width: 8),
                  Text('Current HR Team Members', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: glass.textPrimary)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('${_hrMembers.length} Members', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GlassSearchBar(
            controller: TextEditingController(text: _searchTerm),
            placeholder: 'Search HR members by name, code, email...',
            onChanged: (val) => setState(() {
              _searchTerm = val;
              _currentPage = 1;
            }),
          ),
          const SizedBox(height: 12),
          paginated.isEmpty
              ? AppCard(
                  backgroundColor: cardBgColor,
                  padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                  child: Column(
                    children: [
                      const Icon(Icons.supervised_user_circle_outlined, size: 48, color: Color(0xFF94A3B8)),
                      const SizedBox(height: 12),
                      Text('No HR members found', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: glass.textPrimary)),
                      const SizedBox(height: 6),
                      Text('Assign an employee above to give them an HR role.', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: glass.textSecondary)),
                    ],
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: paginated.length,
                  itemBuilder: (context, index) {
                    final hr = paginated[index];
                    final name = hr['fullName']?.toString() ?? '${hr['firstName'] ?? ''} ${hr['lastName'] ?? ''}'.trim();
                    final code = hr['employeeCode'] ?? hr['employeeId'] ?? 'EMP';
                    final email = hr['email'] ?? 'No email';
                    final desig = hr['designation'] ?? 'HR Manager';
                    final dept = hr['department'] ?? 'Human Resources';
                    final team = hr['teamName'] ?? hr['team'] ?? '';

                    return AppCard(
                      backgroundColor: cardBgColor,
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: const Color(0xFF10B981).withAlpha(30),
                            child: Text(
                              name.isNotEmpty ? name[0].toUpperCase() : 'H',
                              style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: glass.textPrimary)),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF2563EB).withAlpha(20),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(code, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.email_outlined, size: 12, color: Color(0xFF64748B)),
                                    const SizedBox(width: 4),
                                    Expanded(child: Text(email, style: TextStyle(fontSize: 12, color: glass.textSecondary))),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: [
                                    _buildChip(desig, Icons.badge_outlined, const Color(0xFF8B5CF6)),
                                    _buildChip(dept, Icons.apartment_outlined, const Color(0xFF0EA5E9)),
                                    if (team.isNotEmpty) _buildChip(team, Icons.group_outlined, const Color(0xFF10B981)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.person_remove_rounded, color: Color(0xFFEF4444), size: 20),
                            tooltip: 'Revoke HR',
                            onPressed: () => _revokeHR(hr),
                          ),
                        ],
                      ),
                    );
                  },
                ),
          if (filtered.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Showing $startIndex to $endIndex of ${filtered.length} entries',
                  style: TextStyle(fontSize: 12, color: glass.textSecondary),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left_rounded),
                      onPressed: _currentPage > 1 ? () => setState(() => _currentPage--) : null,
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withAlpha(20),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('$_currentPage / $_totalPages', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: glass.textPrimary)),
                    ),
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

  Widget _buildMetricCard(
    String label,
    String value,
    String sub,
    IconData icon,
    Color color,
    Color bgColor,
    bool isDark,
  ) {
    return AppCard(
      backgroundColor: isDark ? AppColors.darkMainSurface : Colors.white,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: context.glass.textSecondary)),
                const SizedBox(height: 2),
                Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: context.glass.textPrimary)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(Icons.info_outline_rounded, size: 10, color: color),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        sub,
                        style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 3),
          Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
