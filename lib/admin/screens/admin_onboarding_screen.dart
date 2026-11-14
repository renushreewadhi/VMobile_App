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
import 'admin_onboarding_detail_screen.dart';
import 'admin_onboarding_form_screen.dart';

/// Strongly typed Onboarding Candidate Model
class OnboardingModel {
  final String id;
  final String employeeName;
  final String jobPosition;
  final String departmentName;
  final String status; // NOT_STARTED, IN_PROGRESS, AWAITING_APPROVAL, COMPLETED, UPCOMING
  final double progress;
  final String startDate;
  final String? mentorName;

  OnboardingModel({
    required this.id,
    required this.employeeName,
    required this.jobPosition,
    required this.departmentName,
    required this.status,
    required this.progress,
    required this.startDate,
    this.mentorName,
  });

  factory OnboardingModel.fromJson(Map<String, dynamic> json) {
    final rawProg = json['progress'] ?? json['completionRate'] ?? 0;
    final progDouble = rawProg is num ? rawProg.toDouble() : (double.tryParse(rawProg.toString()) ?? 0.0);

    final rawDate = json['startDate']?.toString() ?? json['joiningDate']?.toString() ?? DateTime.now().toIso8601String();
    final cleanDate = rawDate.contains('T') ? rawDate.split('T')[0] : rawDate;

    return OnboardingModel(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      employeeName: json['employeeName']?.toString() ?? json['candidateName']?.toString() ?? json['name']?.toString() ?? 'Candidate',
      jobPosition: json['jobPosition']?.toString() ?? json['designationName']?.toString() ?? json['position']?.toString() ?? 'Position',
      departmentName: json['departmentName']?.toString() ?? json['department']?.toString() ?? 'Unassigned',
      status: (json['status']?.toString() ?? 'IN_PROGRESS').toUpperCase(),
      progress: progDouble,
      startDate: cleanDate,
      mentorName: json['mentorName']?.toString() ?? json['mentor']?.toString(),
    );
  }
}

class AdminOnboardingScreen extends ConsumerStatefulWidget {
  final bool? showAppBar;
  const AdminOnboardingScreen({super.key, this.showAppBar = true});

  @override
  ConsumerState<AdminOnboardingScreen> createState() => _AdminOnboardingScreenState();
}

class _AdminOnboardingScreenState extends ConsumerState<AdminOnboardingScreen> {
  bool get _showAppBar => widget.showAppBar ?? true;
  bool _isLoading = true;
  String? _errorMessage;
  List<OnboardingModel> _onboardings = [];

  String _searchTerm = '';
  String _activeTab = 'ALL'; // ALL, IN_PROGRESS, COMPLETED, UPCOMING (Matching Angular reference)
  String _selectedDepartment = '';

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

    _loadOnboardings();
  }

  void _resetState() {
    _onboardings = [];
    _searchTerm = '';
    _activeTab = 'ALL';
    _selectedDepartment = '';
  }

  Future<void> _loadOnboardings() async {
    final currentReq = ++_requestId;
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final apiClient = ref.read(apiClientProvider);

    try {
      final res = await apiClient.get(ApiEndpoints.onboarding).catchError((_) => null);
      if (!mounted || currentReq != _requestId) return;

      dynamic rawData = res;
      if (res is Map<String, dynamic>) {
        if (res['data'] is List) rawData = res['data'];
        else if (res['items'] is List) rawData = res['items'];
        else if (res['onboarding'] is List) rawData = res['onboarding'];
      }

      List<OnboardingModel> items = [];
      if (rawData is List) {
        for (final item in rawData) {
          if (item is Map<String, dynamic>) {
            try {
              items.add(OnboardingModel.fromJson(item));
            } catch (_) {}
          }
        }
      }

      if (!mounted || currentReq != _requestId) return;
      setState(() {
        _onboardings = items;
        _isLoading = false;
        _errorMessage = null;
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
        _errorMessage = 'Failed to load onboarding records. Please check connection.';
        _isLoading = false;
      });
    }
  }

  List<OnboardingModel> get _filteredOnboardings {
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);

    return _onboardings.where((o) {
      bool matchesTab = true;
      if (_activeTab == 'IN_PROGRESS') {
        matchesTab = o.status == 'IN_PROGRESS' || o.status == 'NOT_STARTED' || o.status == 'AWAITING_APPROVAL';
      } else if (_activeTab == 'UPCOMING') {
        matchesTab = o.status == 'UPCOMING' || (o.startDate.compareTo(todayStr) > 0);
      } else if (_activeTab == 'COMPLETED') {
        matchesTab = o.status == 'COMPLETED';
      }

      final matchesDept = _selectedDepartment.isEmpty || o.departmentName.toLowerCase() == _selectedDepartment.toLowerCase();

      final matchesSearch = _searchTerm.trim().isEmpty ||
          o.employeeName.toLowerCase().contains(_searchTerm.toLowerCase()) ||
          o.jobPosition.toLowerCase().contains(_searchTerm.toLowerCase()) ||
          o.departmentName.toLowerCase().contains(_searchTerm.toLowerCase()) ||
          (o.mentorName != null && o.mentorName!.toLowerCase().contains(_searchTerm.toLowerCase()));

      return matchesTab && matchesDept && matchesSearch;
    }).toList();
  }

  int get _totalCount => _onboardings.length;
  int get _pendingCount => _onboardings.where((o) => o.status == 'NOT_STARTED' || o.status == 'AWAITING_APPROVAL').length;
  int get _inProgressCount => _onboardings.where((o) => o.status == 'IN_PROGRESS').length;
  int get _awaitingApprovalCount => _onboardings.where((o) => o.status == 'AWAITING_APPROVAL').length;
  int get _completedCount => _onboardings.where((o) => o.status == 'COMPLETED').length;
  
  int get _joiningThisWeekCount {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 6));
    
    return _onboardings.where((o) {
      try {
        final dt = DateTime.parse(o.startDate);
        return dt.isAfter(startOfWeek.subtract(const Duration(days: 1))) && dt.isBefore(endOfWeek.add(const Duration(days: 1)));
      } catch (_) {
        return false;
      }
    }).length;
  }

  double get _avgProgress {
    if (_onboardings.isEmpty) return 0.0;
    final total = _onboardings.fold(0.0, (sum, o) => sum + o.progress);
    return total / _onboardings.length;
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
                    Text('You do not have administrative permissions to view onboarding records.', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: glass.textSecondary)),
                  ],
                ),
              ),
            ),
          )
        : RefreshIndicator(
            onRefresh: _loadOnboardings,
            child: _buildMainContent(glass, cardBgColor),
          );

    if (!_showAppBar) return mainContent;

    return GlassScaffold(
      appBar: GlassHeader(
        title: 'Onboarding Management',
        actions: [
          if (isAuthorized)
            IconButton(
              icon: const Icon(Icons.person_add_rounded, size: 20),
              tooltip: 'New Onboarding',
              onPressed: () async {
                final created = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminOnboardingFormScreen()),
                );
                if (created == true) _loadOnboardings();
              },
            ),
        ],
      ),
      body: mainContent,
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
              Text('Unable to Load Onboarding Records', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: glass.textPrimary)),
              const SizedBox(height: 8),
              Text(_errorMessage!, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: glass.textSecondary)),
              const SizedBox(height: 24),
              AppButton(label: 'Retry', icon: Icons.refresh_rounded, width: 140, onPressed: _loadOnboardings),
            ],
          ),
        ),
      );
    }

    final filtered = _filteredOnboardings;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // KPI Metric Summary Cards Grid (2x3 matching web)
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.55,
            children: [
              _buildStatTile(glass, cardBgColor, label: 'Total Onboardings', value: '$_totalCount', icon: Icons.badge_rounded, iconColor: const Color(0xFF2563EB)),
              _buildStatTile(glass, cardBgColor, label: 'Pending', value: '$_pendingCount', icon: Icons.schedule_rounded, iconColor: const Color(0xFFD97706)),
              _buildStatTile(glass, cardBgColor, label: 'In Progress', value: '$_inProgressCount', icon: Icons.hourglass_top_rounded, iconColor: const Color(0xFF3B82F6)),
              _buildStatTile(glass, cardBgColor, label: 'Awaiting Approval', value: '$_awaitingApprovalCount', icon: Icons.assignment_turned_in_rounded, iconColor: const Color(0xFF8B5CF6)),
              _buildStatTile(glass, cardBgColor, label: 'Completed', value: '$_completedCount', icon: Icons.check_circle_rounded, iconColor: const Color(0xFF10B981)),
              _buildStatTile(glass, cardBgColor, label: 'Joining This Week', value: '$_joiningThisWeekCount', icon: Icons.calendar_month_rounded, iconColor: const Color(0xFFEC4899)),
            ],
          ),
          const SizedBox(height: 16),

          // Overall Progress Bar Card
          AppCard(
            backgroundColor: cardBgColor,
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Onboarding Progress', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: glass.textPrimary)),
                    Text('${_avgProgress.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: (_avgProgress / 100).clamp(0.0, 1.0),
                    backgroundColor: const Color(0xFF10B981).withAlpha(30),
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                    minHeight: 8,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Search and Department Filter Bar
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search candidate name, position...',
                    hintStyle: TextStyle(color: glass.textSecondary, fontSize: 12),
                    prefixIcon: Icon(Icons.search_rounded, color: glass.textSecondary, size: 18),
                    filled: true,
                    fillColor: cardBgColor,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: glass.cardBorder)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: glass.cardBorder)),
                  ),
                  style: TextStyle(color: glass.textPrimary, fontSize: 13),
                  onChanged: (val) => setState(() => _searchTerm = val),
                ),
              ),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: _selectedDepartment.isEmpty ? null : _selectedDepartment,
                hint: const Text('All Depts', style: TextStyle(fontSize: 11)),
                underline: const SizedBox.shrink(),
                items: const [
                  DropdownMenuItem(value: '', child: Text('All Depts', style: TextStyle(fontSize: 11))),
                  DropdownMenuItem(value: 'Engineering', child: Text('Engineering', style: TextStyle(fontSize: 11))),
                  DropdownMenuItem(value: 'Human Resources', child: Text('HR', style: TextStyle(fontSize: 11))),
                  DropdownMenuItem(value: 'Finance', child: Text('Finance', style: TextStyle(fontSize: 11))),
                ],
                onChanged: (val) => setState(() => _selectedDepartment = val ?? ''),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Tabs Row (All Candidates, In Progress, Completed, etc.)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildTabButton('All Candidates', 'ALL'),
                const SizedBox(width: 6),
                _buildTabButton('In Progress', 'IN_PROGRESS'),
                const SizedBox(width: 6),
                _buildTabButton('Completed', 'COMPLETED'),
                const SizedBox(width: 6),
                _buildTabButton('Upcoming', 'UPCOMING'),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Candidates Feed List or Empty State
          if (filtered.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 48),
              alignment: Alignment.center,
              child: Column(
                children: [
                  Icon(Icons.assignment_outlined, size: 48, color: glass.textSecondary.withAlpha(128)),
                  const SizedBox(height: 12),
                  Text('No Candidates Found', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: glass.textPrimary)),
                  const SizedBox(height: 6),
                  Text('There are no onboarding candidates matching your search or filter criteria.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: glass.textSecondary)),
                ],
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final o = filtered[index];
                return AppCard(
                  backgroundColor: cardBgColor,
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(o.employeeName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: glass.textPrimary)),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: o.status == 'COMPLETED' ? const Color(0xFF10B981).withAlpha(30) : const Color(0xFF2563EB).withAlpha(30),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              o.status.replaceAll('_', ' '),
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: o.status == 'COMPLETED' ? const Color(0xFF10B981) : const Color(0xFF2563EB)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text('${o.jobPosition} • ${o.departmentName}', style: TextStyle(fontSize: 11.5, color: glass.textSecondary)),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Progress: ${o.progress.toStringAsFixed(0)}%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: glass.textPrimary)),
                          Text('Start: ${o.startDate}', style: TextStyle(fontSize: 11, color: glass.textSecondary)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (o.progress / 100).clamp(0.0, 1.0),
                          backgroundColor: const Color(0xFF2563EB).withAlpha(20),
                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
                          minHeight: 5,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton.icon(
                            icon: const Icon(Icons.remove_red_eye_outlined, size: 14),
                            label: const Text('View Details', style: TextStyle(fontSize: 11)),
                            style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                            onPressed: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => AdminOnboardingDetailScreen(candidateId: o.id)),
                              );
                              _loadOnboardings();
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

  Widget _buildTabButton(String label, String tabKey) {
    final isSelected = _activeTab == tabKey;
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        backgroundColor: isSelected ? const Color(0xFF0F6B66) : Colors.transparent,
        foregroundColor: isSelected ? Colors.white : const Color(0xFF475569),
        side: BorderSide(color: isSelected ? const Color(0xFF0F6B66) : const Color(0xFFCBD5E1)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        visualDensity: VisualDensity.compact,
      ),
      onPressed: () => setState(() => _activeTab = tabKey),
      child: Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildStatTile(
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, size: 16, color: iconColor),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: iconColor.withAlpha(20), borderRadius: BorderRadius.circular(6)),
                child: Icon(Icons.trending_up_rounded, size: 12, color: iconColor),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: glass.textPrimary)),
              const SizedBox(height: 2),
              Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 9.5, color: glass.textSecondary, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }
}
