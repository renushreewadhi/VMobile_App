import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
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
import 'admin_employee_form_screen.dart';

class AdminEmployeeDetailScreen extends ConsumerStatefulWidget {
  final String employeeId;

  const AdminEmployeeDetailScreen({super.key, required this.employeeId});

  @override
  ConsumerState<AdminEmployeeDetailScreen> createState() => _AdminEmployeeDetailScreenState();
}

class _AdminEmployeeDetailScreenState extends ConsumerState<AdminEmployeeDetailScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic> _employee = {};
  String _activeTab = 'personal'; // personal, contact, job, documents, attendance, leave, salary, performance, activity

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
    _requestId++; // Immediately invalidate any pending requests
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

    _loadEmployeeDetails();
  }

  void _resetState() {
    _employee = {};
    _activeTab = 'personal';
  }

  Future<void> _loadEmployeeDetails() async {
    final currentReq = ++_requestId;
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final apiClient = ref.read(apiClientProvider);

    try {
      final res = await apiClient.get(ApiEndpoints.employeeDetail(widget.employeeId));
      if (!mounted || currentReq != _requestId) return;

      dynamic rawData = res is Map<String, dynamic> && res.containsKey('data') ? res['data'] : res;
      if (rawData is Map<String, dynamic>) {
        setState(() {
          _employee = rawData;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Employee record not found.';
          _isLoading = false;
        });
      }
    } on ApiException catch (e) {
      if (!mounted || currentReq != _requestId) return;
      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted || currentReq != _requestId) return;
      setState(() {
        _errorMessage = 'Failed to load employee details. Please check network connection.';
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleStatus() async {
    final rawStatus = (_employee['employmentStatus'] ?? _employee['status'] ?? 'Active').toString().toLowerCase();
    final isActive = rawStatus != 'inactive' && rawStatus != 'false';
    final newStatus = isActive ? 'INACTIVE' : 'ACTIVE';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isActive ? 'Deactivate Employee?' : 'Reactivate Employee?'),
        content: Text(isActive ? 'This will set the employee status to Inactive.' : 'This will reactivate the employee record.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: isActive ? Colors.orange : Colors.green),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isActive ? 'Deactivate' : 'Reactivate'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final currentReq = ++_requestId;
    final apiClient = ref.read(apiClientProvider);

    try {
      await apiClient.post(ApiEndpoints.employeeStatus(widget.employeeId), body: {'status': newStatus});
      if (!mounted || currentReq != _requestId) return;

      setState(() {
        _employee['employmentStatus'] = newStatus == 'ACTIVE' ? 'Active' : 'Inactive';
        _employee['status'] = _employee['employmentStatus'];
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Employee status updated to $newStatus')),
        );
      }
    } catch (e) {
      if (!mounted || currentReq != _requestId) return;
      final msg = e is ApiException ? e.message : 'Failed to update employee status.';
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

    final rawStatus = (_employee['employmentStatus'] ?? _employee['status'] ?? 'Active').toString().toLowerCase();
    final isActive = rawStatus != 'inactive' && rawStatus != 'false';

    final firstName = _employee['firstName']?.toString() ?? '';
    final lastName = _employee['lastName']?.toString() ?? '';
    final name = firstName.isNotEmpty || lastName.isNotEmpty ? '$firstName $lastName'.trim() : (_employee['name']?.toString() ?? 'Employee');

    return GlassScaffold(
      appBar: GlassHeader(
        title: name,
        actions: [
          if (isAuthorized && _errorMessage == null && !_isLoading) ...[
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit Employee',
              onPressed: () async {
                final updated = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(builder: (_) => AdminEmployeeFormScreen(employeeId: widget.employeeId, initialData: _employee)),
                );
                if (updated == true) _loadEmployeeDetails();
              },
            ),
            IconButton(
              icon: Icon(isActive ? Icons.block_rounded : Icons.check_circle_outline_rounded, color: isActive ? Colors.orange : Colors.green),
              tooltip: isActive ? 'Deactivate' : 'Reactivate',
              onPressed: _toggleStatus,
            ),
          ],
        ],
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
                      Text('You do not have administrative permissions to view employee details.', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: glass.textSecondary)),
                    ],
                  ),
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadEmployeeDetails,
              child: _buildMainContent(glass, cardBgColor, name, isActive),
            ),
    );
  }

  Widget _buildMainContent(GlassTheme glass, Color cardBgColor, String name, bool isActive) {
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
              Text('Unable to Load Employee Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: glass.textPrimary)),
              const SizedBox(height: 8),
              Text(_errorMessage!, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: glass.textSecondary)),
              const SizedBox(height: 24),
              AppButton(label: 'Retry', icon: Icons.refresh_rounded, width: 140, onPressed: _loadEmployeeDetails),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile Header Card
          AppCard(
            backgroundColor: cardBgColor,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: const Color(0xFF0F6B66).withAlpha(30),
                  child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'E', style: const TextStyle(fontSize: 24, color: Color(0xFF0F6B66), fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: glass.textPrimary)),
                      Text('${_employee['employeeId'] ?? 'EMP'} • ${_employee['department'] ?? 'General'}', style: TextStyle(color: glass.textSecondary, fontSize: 12)),
                      Text(_employee['designation'] ?? 'Staff', style: TextStyle(color: glass.textPrimary, fontWeight: FontWeight.w600, fontSize: 12)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isActive ? const Color(0xFF10B981).withAlpha(30) : Colors.grey.withAlpha(30),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    isActive ? 'ACTIVE' : 'INACTIVE',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isActive ? const Color(0xFF10B981) : Colors.grey),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 9 Tabs Bar (Matching Angular reference)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildTabButton('personal', '1. Personal'),
                const SizedBox(width: 6),
                _buildTabButton('contact', '2. Contact'),
                const SizedBox(width: 6),
                _buildTabButton('job', '3. Job'),
                const SizedBox(width: 6),
                _buildTabButton('documents', '4. Documents'),
                const SizedBox(width: 6),
                _buildTabButton('attendance', '5. Attendance'),
                const SizedBox(width: 6),
                _buildTabButton('leave', '6. Leave'),
                const SizedBox(width: 6),
                _buildTabButton('salary', '7. Salary'),
                const SizedBox(width: 6),
                _buildTabButton('performance', '8. Performance'),
                const SizedBox(width: 6),
                _buildTabButton('activity', '9. Activity'),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Tab Content Card
          AppCard(
            backgroundColor: cardBgColor,
            padding: const EdgeInsets.all(16),
            child: _buildTabContent(glass),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(String id, String label) {
    final isSelected = _activeTab == id;
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        backgroundColor: isSelected ? const Color(0xFF0F6B66) : Colors.transparent,
        foregroundColor: isSelected ? Colors.white : context.glass.textPrimary,
        side: BorderSide(color: isSelected ? const Color(0xFF0F6B66) : context.glass.cardBorder),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        visualDensity: VisualDensity.compact,
      ),
      onPressed: () => setState(() => _activeTab = id),
      child: Text(label, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
    );
  }

  Widget _buildTabContent(GlassTheme glass) {
    switch (_activeTab) {
      case 'personal':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Personal Information', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: glass.textPrimary)),
            const Divider(height: 16),
            _buildInfoRow(glass, 'Gender', _employee['gender']?.toString() ?? '—'),
            _buildInfoRow(glass, 'Marital Status', _employee['maritalStatus']?.toString() ?? '—'),
            _buildInfoRow(glass, 'Date of Birth', _employee['dateOfBirth']?.toString() ?? '—'),
            _buildInfoRow(glass, 'Nationality', _employee['nationality']?.toString() ?? '—'),
            _buildInfoRow(glass, 'Blood Group', _employee['bloodGroup']?.toString() ?? '—'),
            _buildInfoRow(glass, 'Religion', _employee['religion']?.toString() ?? '—'),
            _buildInfoRow(glass, 'Aadhaar Number', _maskSensitive(_employee['aadhaar']?.toString())),
            _buildInfoRow(glass, 'PAN Number', _maskSensitive(_employee['pan']?.toString())),
          ],
        );
      case 'contact':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Contact & Emergency Information', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: glass.textPrimary)),
            const Divider(height: 16),
            _buildInfoRow(glass, 'Email', _employee['email']?.toString() ?? '—'),
            _buildInfoRow(glass, 'Phone', _employee['phone']?.toString() ?? '—'),
            _buildInfoRow(glass, 'Address', _employee['address']?.toString() ?? '—'),
            _buildInfoRow(glass, 'City', _employee['city']?.toString() ?? '—'),
            _buildInfoRow(glass, 'State', _employee['state']?.toString() ?? '—'),
            _buildInfoRow(glass, 'Country', _employee['country']?.toString() ?? '—'),
            _buildInfoRow(glass, 'Postal Code', _employee['postalCode']?.toString() ?? '—'),
            _buildInfoRow(glass, 'Emergency Contact', _employee['emergencyContactName']?.toString() ?? '—'),
            _buildInfoRow(glass, 'Emergency Phone', _employee['emergencyContactPhone']?.toString() ?? '—'),
          ],
        );
      case 'job':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Job & Organizational Details', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: glass.textPrimary)),
            const Divider(height: 16),
            _buildInfoRow(glass, 'Department', _employee['department']?.toString() ?? '—'),
            _buildInfoRow(glass, 'Designation', _employee['designation']?.toString() ?? '—'),
            _buildInfoRow(glass, 'Branch', _employee['branch']?.toString() ?? '—'),
            _buildInfoRow(glass, 'Joining Date', _employee['joiningDate']?.toString() ?? '—'),
            _buildInfoRow(glass, 'Employment Type', _employee['employmentType']?.toString() ?? 'Full-Time'),
            _buildInfoRow(glass, 'Reporting Manager', _employee['reportingManager']?.toString() ?? '—'),
            _buildInfoRow(glass, 'Shift', _employee['shift']?.toString() ?? '—'),
          ],
        );
      case 'documents':
        final docs = _employee['documents'] as List? ?? [];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Employee Documents (${docs.length})', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: glass.textPrimary)),
            const Divider(height: 16),
            docs.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Center(child: Text('No documents uploaded for this employee.', style: TextStyle(fontSize: 13, color: glass.textSecondary))),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: docs.length,
                    itemBuilder: (ctx, i) {
                      final doc = docs[i];
                      return ListTile(
                        leading: const Icon(Icons.insert_drive_file_outlined, color: Color(0xFF0F6B66)),
                        title: Text(doc['name']?.toString() ?? 'Document', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: glass.textPrimary)),
                        subtitle: Text('Type: ${doc['type'] ?? 'PDF'} • Size: ${doc['size'] ?? '—'}', style: TextStyle(fontSize: 11, color: glass.textSecondary)),
                      );
                    },
                  ),
          ],
        );
      case 'attendance':
        final atts = _employee['attendance'] as List? ?? [];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Attendance History', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: glass.textPrimary)),
            const Divider(height: 16),
            atts.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Center(child: Text('No attendance records available.', style: TextStyle(fontSize: 13, color: glass.textSecondary))),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: atts.length,
                    itemBuilder: (ctx, i) {
                      final a = atts[i];
                      return ListTile(
                        title: Text(a['date']?.toString() ?? 'Date', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: glass.textPrimary)),
                        subtitle: Text('Clock-In: ${a['clockIn'] ?? '—'} • Clock-Out: ${a['clockOut'] ?? '—'} • Status: ${a['status'] ?? 'Present'}', style: TextStyle(fontSize: 11, color: glass.textSecondary)),
                      );
                    },
                  ),
          ],
        );
      case 'leave':
        final leaves = _employee['leaves'] as List? ?? [];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Leave History', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: glass.textPrimary)),
            const Divider(height: 16),
            leaves.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Center(child: Text('No leave records found.', style: TextStyle(fontSize: 13, color: glass.textSecondary))),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: leaves.length,
                    itemBuilder: (ctx, i) {
                      final l = leaves[i];
                      return ListTile(
                        title: Text('${l['leaveType'] ?? 'Leave'} (${l['days'] ?? 1} days)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: glass.textPrimary)),
                        subtitle: Text('From: ${l['startDate']} to ${l['endDate']} • Status: ${l['status'] ?? 'Approved'}', style: TextStyle(fontSize: 11, color: glass.textSecondary)),
                      );
                    },
                  ),
          ],
        );
      case 'salary':
        final currencyFmt = NumberFormat.currency(symbol: '₹', decimalDigits: 2);
        final salary = (_employee['salary'] ?? _employee['basicSalary'] as num?)?.toDouble() ?? 120000.0;
        final allowances = (_employee['allowances'] as num?)?.toDouble() ?? 15000.0;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Salary & Compensation', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: glass.textPrimary)),
            const Divider(height: 16),
            _buildInfoRow(glass, 'Basic Salary', currencyFmt.format(salary)),
            _buildInfoRow(glass, 'Allowances', currencyFmt.format(allowances)),
            _buildInfoRow(glass, 'Bank Name', _employee['bankName']?.toString() ?? '—'),
            _buildInfoRow(glass, 'Account Number', _maskSensitive(_employee['accountNumber']?.toString())),
            _buildInfoRow(glass, 'IFSC Code', _employee['ifscCode']?.toString() ?? '—'),
          ],
        );
      case 'performance':
        final perf = _employee['performance'] is Map ? _employee['performance'] as Map<String, dynamic> : null;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Performance & Ratings', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: glass.textPrimary)),
            const Divider(height: 16),
            if (perf == null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(child: Text('No performance reviews recorded yet.', style: TextStyle(fontSize: 13, color: glass.textSecondary))),
              )
            else ...[
              _buildInfoRow(glass, 'Overall Rating', '${perf['overallRating'] ?? '—'} / 5.0'),
              _buildInfoRow(glass, 'Goals Rating', '${perf['goalsRating'] ?? '—'} / 5.0'),
              _buildInfoRow(glass, 'Competency Rating', '${perf['competencyRating'] ?? '—'} / 5.0'),
              _buildInfoRow(glass, 'Review Comments', perf['comments']?.toString() ?? '—'),
            ],
          ],
        );
      case 'activity':
        final acts = _employee['activities'] as List? ?? [];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Activity History', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: glass.textPrimary)),
            const Divider(height: 16),
            acts.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Center(child: Text('No recent employee activity logged.', style: TextStyle(fontSize: 13, color: glass.textSecondary))),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: acts.length,
                    itemBuilder: (ctx, i) {
                      final act = acts[i];
                      return ListTile(
                        title: Text(act['action']?.toString() ?? 'Action', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: glass.textPrimary)),
                        subtitle: Text(act['timestamp']?.toString() ?? '', style: TextStyle(fontSize: 11, color: glass.textSecondary)),
                      );
                    },
                  ),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }

  String _maskSensitive(String? val) {
    if (val == null || val.trim().isEmpty) return '—';
    if (val.length <= 4) return '****';
    return '****-****-${val.substring(val.length - 4)}';
  }

  Widget _buildInfoRow(GlassTheme glass, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: glass.textSecondary)),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: glass.textPrimary)),
        ],
      ),
    );
  }
}
