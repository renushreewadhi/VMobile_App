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
import 'admin_branch_form_screen.dart';

class AdminBranchDetailScreen extends ConsumerStatefulWidget {
  final String branchId;
  final bool showAppBar;

  const AdminBranchDetailScreen({super.key, required this.branchId, this.showAppBar = true});

  @override
  ConsumerState<AdminBranchDetailScreen> createState() => _AdminBranchDetailScreenState();
}

class _AdminBranchDetailScreenState extends ConsumerState<AdminBranchDetailScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic> _branch = {};
  List<dynamic> _branchEmployees = [];

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
    _requestId++; // Invalidate pending requests immediately
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

    _loadBranchDetail();
  }

  void _resetState() {
    _branch = {};
    _branchEmployees = [];
  }

  Future<void> _loadBranchDetail() async {
    final currentReq = ++_requestId;
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final apiClient = ref.read(apiClientProvider);

    try {
      final res = await apiClient.get(ApiEndpoints.branches);
      if (!mounted || currentReq != _requestId) return;

      dynamic rawBranches = res;
      if (res is Map<String, dynamic> && res.containsKey('data')) {
        rawBranches = res['data'];
      }

      Map<String, dynamic>? foundBranch;
      if (rawBranches is List) {
        for (final item in rawBranches) {
          if (item is Map<String, dynamic> && (item['id'] ?? item['_id'])?.toString() == widget.branchId) {
            foundBranch = item;
            break;
          }
        }
      }

      if (foundBranch == null) {
        if (!mounted || currentReq != _requestId) return;
        setState(() {
          _errorMessage = 'Branch office not found.';
          _isLoading = false;
        });
        return;
      }

      // Load employees for this branch using authoritative branchId/name/code matching
      List<dynamic> branchEmps = [];
      try {
        final empRes = await apiClient.get(ApiEndpoints.employeesAll);
        if (!mounted || currentReq != _requestId) return;
        dynamic rawEmps = empRes is Map<String, dynamic> && empRes.containsKey('data') ? empRes['data'] : empRes;

        if (rawEmps is List) {
          final bName = (foundBranch['name'] ?? '').toString().toLowerCase();
          final bCode = (foundBranch['code'] ?? '').toString().toLowerCase();
          final bId = widget.branchId.toLowerCase();

          branchEmps = rawEmps.where((e) {
            if (e is! Map<String, dynamic>) return false;
            final eBranchVal = (e['branch'] ?? e['branchName'] ?? '').toString().toLowerCase();
            final eBranchId = (e['branchId'] ?? '').toString().toLowerCase();

            if (eBranchId.isNotEmpty) {
              return eBranchId == bId;
            }
            return eBranchVal.isNotEmpty && (eBranchVal == bName || eBranchVal == bCode);
          }).toList();
        }
      } catch (e) {
        debugPrint('[AdminBranchDetail] Employee fetch warning: $e');
      }

      if (!mounted || currentReq != _requestId) return;
      setState(() {
        _branch = foundBranch!;
        _branchEmployees = branchEmps;
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
        _errorMessage = 'Failed to load branch details. Please check network connection.';
        _isLoading = false;
      });
    }
  }

  Future<void> _deactivateBranch() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Deactivate branch "${_branch['name'] ?? 'Branch'}"?'),
        content: const Text('This action will delete the branch location from the system.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final currentReq = ++_requestId;
    final apiClient = ref.read(apiClientProvider);

    try {
      await apiClient.delete('${ApiEndpoints.branches}/${widget.branchId}');
      if (!mounted || currentReq != _requestId) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Branch deactivated successfully')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted || currentReq != _requestId) return;
      final msg = e is ApiException ? e.message : 'Failed to deactivate branch.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red),
      );
    }
  }

  String _getCoverImage() {
    final img = _branch['imageUrl']?.toString() ?? _branch['image']?.toString();
    if (img != null && img.trim().isNotEmpty) return img.trim();
    return 'https://images.unsplash.com/photo-1497366216548-37526070297c?auto=format&fit=crop&w=800&q=80';
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

    final rawStatus = (_branch['status'] ?? 'Active').toString().toUpperCase();
    final isActive = rawStatus == 'ACTIVE' || rawStatus == 'TRUE';

    final bodyContent = !isAuthorized
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
                      Text('You do not have administrative permissions to view branch details.', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: glass.textSecondary)),
                    ],
                  ),
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadBranchDetail,
              child: _buildMainContent(glass, cardBgColor, isActive),
            );

    if (!widget.showAppBar) return Material(color: Colors.transparent, child: bodyContent);

    return GlassScaffold(
      appBar: GlassHeader(
        title: _branch['name']?.toString() ?? 'Branch Details',
        actions: [
          if (isAuthorized && _errorMessage == null && !_isLoading) ...[
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit Branch',
              onPressed: () async {
                final updated = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(builder: (_) => AdminBranchFormScreen(branchId: widget.branchId, initialData: _branch)),
                );
                if (updated == true) _loadBranchDetail();
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              tooltip: 'Deactivate Branch',
              onPressed: _deactivateBranch,
            ),
          ],
        ],
      ),
      body: bodyContent,
    );
  }

  Widget _buildMainContent(GlassTheme glass, Color cardBgColor, bool isActive) {
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
              Text('Unable to Load Branch Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: glass.textPrimary)),
              const SizedBox(height: 8),
              Text(_errorMessage!, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: glass.textSecondary)),
              const SizedBox(height: 24),
              AppButton(label: 'Retry', icon: Icons.refresh_rounded, width: 140, onPressed: _loadBranchDetail),
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
          // Hero Cover Banner Card
          Container(
            height: 160,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              image: DecorationImage(
                image: NetworkImage(_getCoverImage()),
                fit: BoxFit.cover,
              ),
            ),
            alignment: Alignment.topRight,
            padding: const EdgeInsets.all(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isActive ? const Color(0xFF10B981) : Colors.grey,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                isActive ? 'ACTIVE' : 'INACTIVE',
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header Info
          Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: const Color(0xFF0F6B66).withAlpha(30),
                child: const Icon(Icons.business_rounded, color: Color(0xFF0F6B66), size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_branch['name']?.toString() ?? 'Branch Name', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: glass.textPrimary)),
                    Text('Code: ${_branch['code'] ?? '—'}', style: TextStyle(fontSize: 13, color: glass.textSecondary, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Metric Summary Row
          Row(
            children: [
              Expanded(child: _buildMetricTile(glass, cardBgColor, label: 'Branch Staff', value: '${_branchEmployees.length}', icon: Icons.groups_rounded, iconColor: const Color(0xFF2563EB))),
              const SizedBox(width: 8),
              Expanded(child: _buildMetricTile(glass, cardBgColor, label: 'Phone', value: _branch['phone']?.toString() ?? '—', icon: Icons.phone_outlined, iconColor: const Color(0xFF10B981))),
              const SizedBox(width: 8),
              Expanded(child: _buildMetricTile(glass, cardBgColor, label: 'Email', value: _branch['email']?.toString() ?? '—', icon: Icons.email_outlined, iconColor: const Color(0xFF8B5CF6))),
            ],
          ),
          const SizedBox(height: 16),

          // Location Details Card
          AppCard(
            backgroundColor: cardBgColor,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Location Details', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: glass.textPrimary)),
                const Divider(height: 16),
                _buildInfoRow(glass, 'Address', _branch['address']?.toString() ?? '—'),
                _buildInfoRow(glass, 'City / State', '${_branch['city'] ?? '—'}, ${_branch['state'] ?? '—'}'),
                _buildInfoRow(glass, 'Country', _branch['country']?.toString() ?? '—'),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Staff Roster Card
          AppCard(
            backgroundColor: cardBgColor,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Branch Employees (${_branchEmployees.length})', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: glass.textPrimary)),
                const Divider(height: 16),
                if (_branchEmployees.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: Text('No employees currently assigned to this branch.', style: TextStyle(fontSize: 13, color: glass.textSecondary))),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _branchEmployees.length,
                    itemBuilder: (context, index) {
                      final emp = _branchEmployees[index];
                      final name = '${emp['firstName'] ?? ''} ${emp['lastName'] ?? ''}'.trim();
                      final empName = name.isNotEmpty ? name : (emp['name'] ?? 'Employee');
                      final code = emp['employeeCode'] ?? emp['id'] ?? '—';
                      final dept = emp['department'] ?? emp['departmentName'] ?? '—';
                      final desig = emp['designation'] ?? 'Staff';

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: const Color(0xFF0F6B66).withAlpha(30),
                              child: Text(empName[0].toUpperCase(), style: const TextStyle(color: Color(0xFF0F6B66), fontWeight: FontWeight.bold, fontSize: 12)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(empName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: glass.textPrimary)),
                                  Text('$code • $dept ($desig)', style: TextStyle(fontSize: 11, color: glass.textSecondary)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile(
    GlassTheme glass,
    Color cardBgColor, {
    required String label,
    required String value,
    required IconData icon,
    required Color iconColor,
  }) {
    return AppCard(
      backgroundColor: cardBgColor,
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 4),
              Expanded(child: Text(label, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10, color: glass.textSecondary, fontWeight: FontWeight.w600))),
            ],
          ),
          const SizedBox(height: 4),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: glass.textPrimary)),
        ],
      ),
    );
  }

  Widget _buildInfoRow(GlassTheme glass, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: TextStyle(fontSize: 12, color: glass.textSecondary)),
          ),
          Expanded(
            child: Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: glass.textPrimary)),
          ),
        ],
      ),
    );
  }
}
