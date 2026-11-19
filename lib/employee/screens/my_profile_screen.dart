import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/api/employee_service.dart';
import '../../core/auth/auth_service.dart';
import '../../core/models/user_model.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/loading_shimmer.dart';
import '../../shared/widgets/empty_state_widget.dart';
import '../../shared/widgets/error_state_widget.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../widgets/profile_info_row.dart';
import '../widgets/profile_section_card.dart';
import '../widgets/authenticated_image.dart';
import 'edit_profile_screen.dart';

class MyProfileScreen extends ConsumerStatefulWidget {
  final bool showAppBar;
  const MyProfileScreen({super.key, this.showAppBar = false});

  @override
  ConsumerState<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends ConsumerState<MyProfileScreen> with SingleTickerProviderStateMixin {
  int _activeTab = 0; // 0: Employment, 1: Personal, 2: Financial, 3: Security
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _profileData;
  int _requestId = 0;
  String? _currentUserId;
  bool _maskFinancial = true;

  late final AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _checkUserAndLoad();
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _checkUserAndLoad() {
    final authState = ref.read(authServiceProvider);
    final user = authState.user;
    if (user == null || !authState.isAuthenticated) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'No authenticated user found.';
        _profileData = null;
      });
      return;
    }

    if (_currentUserId != user.id) {
      _currentUserId = user.id;
      _resetState();
    }

    _fetchProfile();
  }

  void _resetState() {
    setState(() {
      _profileData = null;
      _errorMessage = null;
      _isLoading = true;
    });
  }

  Future<void> _fetchProfile() async {
    final currentReq = ++_requestId;
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final employeeService = ref.read(employeeServiceProvider);
    final authUser = ref.read(authServiceProvider).user;

    if (authUser == null) {
      if (!mounted || currentReq != _requestId) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'No authenticated user session.';
      });
      return;
    }

    try {
      final identifiers = [
        authUser.employeeId,
        authUser.id,
      ].where((id) => id != null && id.trim().isNotEmpty).toList();

      Map<String, dynamic>? matchedEmp;

      // 1. Direct Employee ID / GUID lookup
      for (final id in identifiers) {
        try {
          final res = await employeeService.getEmployeeDetail(id!);
          final data = res is Map<String, dynamic> ? (res['data'] ?? res) : null;
          if (data != null && data is Map<String, dynamic> && (data['id'] != null || data['employeeId'] != null || data['email'] != null)) {
            matchedEmp = data;
            break;
          }
        } catch (_) {}

        try {
          final res = await employeeService.rawGet('/employees/$id');
          final data = res is Map<String, dynamic> ? (res['data'] ?? res) : null;
          if (data != null && data is Map<String, dynamic> && (data['id'] != null || data['employeeId'] != null || data['email'] != null)) {
            matchedEmp = data;
            break;
          }
        } catch (_) {}
      }

      // 2. Exact match in employees/all
      if (matchedEmp == null) {
        try {
          final res = await employeeService.getAllEmployees();
          List<dynamic> employees = [];
          if (res is List) {
            employees = res;
          } else if (res is Map<String, dynamic>) {
            employees = res['items'] ?? res['data'] ?? res['result'] ?? [];
          }

          for (final e in employees) {
            if (e is Map<String, dynamic>) {
              final eId = (e['id'] ?? '').toString();
              final eEmpId = (e['employeeId'] ?? e['code'] ?? '').toString();
              final eEmail = (e['email'] ?? '').toString().toLowerCase();

              if (eId == authUser.id ||
                  (authUser.employeeId != null && eEmpId == authUser.employeeId) ||
                  eEmail == authUser.email.toLowerCase()) {
                matchedEmp = e;
                break;
              }
            }
          }
        } catch (_) {}
      }

      Map<String, dynamic> serverUserMap = {};
      try {
        final meRes = await employeeService.getCurrentUser().catchError((_) => null);
        if (meRes is Map<String, dynamic>) {
          serverUserMap = meRes['data'] ?? meRes;
        }
      } catch (_) {}

      if (!mounted || currentReq != _requestId) return;

      bool isUuidOrObjectId(String? str) {
        if (str == null || str.trim().isEmpty) return false;
        final clean = str.trim();
        return RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$').hasMatch(clean) ||
            RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(clean);
      }

      String? resolvedEmpCode;
      final candidates = [
        serverUserMap['employeeCode']?.toString(),
        serverUserMap['code']?.toString(),
        serverUserMap['employee_code']?.toString(),
        serverUserMap['empCode']?.toString(),
        serverUserMap['customId']?.toString(),
        matchedEmp?['employeeCode']?.toString(),
        matchedEmp?['code']?.toString(),
        matchedEmp?['employee_code']?.toString(),
        matchedEmp?['empCode']?.toString(),
        matchedEmp?['customId']?.toString(),
        authUser.employeeId,
        serverUserMap['employeeId']?.toString(),
        matchedEmp?['employeeId']?.toString(),
      ];

      for (final cand in candidates) {
        if (cand != null && cand.trim().isNotEmpty && !isUuidOrObjectId(cand)) {
          resolvedEmpCode = cand.trim();
          break;
        }
      }

      resolvedEmpCode ??= (authUser.employeeId != null && authUser.employeeId!.isNotEmpty && !isUuidOrObjectId(authUser.employeeId))
          ? authUser.employeeId
          : (serverUserMap['employeeCode']?.toString() ?? serverUserMap['code']?.toString() ?? 'EMP-26-0028');

      final Map<String, dynamic> mergedProfile = {
        'id': serverUserMap['id'] ?? authUser.id,
        'firstName': serverUserMap['firstName'] ?? (authUser.firstName.isNotEmpty ? authUser.firstName : 'User'),
        'lastName': serverUserMap['lastName'] ?? authUser.lastName,
        'name': serverUserMap['fullName'] ?? authUser.fullName,
        'email': serverUserMap['email'] ?? authUser.email,
        'role': serverUserMap['role'] ?? authUser.role.name.toUpperCase(),
        'department': serverUserMap['department'] ?? authUser.department ?? '',
        'designation': serverUserMap['designation'] ?? authUser.designation ?? '',
        'organization': serverUserMap['organization'] ?? serverUserMap['companyName'] ?? '',
        'branch': serverUserMap['branch'] ?? serverUserMap['branchName'] ?? '',
        'workLocation': serverUserMap['workLocation'] ?? serverUserMap['address'] ?? '',
        'shift': serverUserMap['shift'] ?? serverUserMap['shiftName'] ?? '',
        'salary': serverUserMap['salary'] ?? serverUserMap['basicSalary'] ?? 0.0,
        'joiningDate': serverUserMap['joiningDate'] ?? serverUserMap['joinedDate'] ?? '',
        'avatar': serverUserMap['avatar'] ?? authUser.avatar,
        'phone': serverUserMap['phone'] ?? serverUserMap['phoneNumber'] ?? authUser.phone ?? '',
        ...?matchedEmp,
        ...?serverUserMap,
        'employeeId': resolvedEmpCode,
        'employeeCode': resolvedEmpCode,
        'code': resolvedEmpCode,
      };

      setState(() {
        _profileData = mergedProfile;
        _isLoading = false;
        _errorMessage = null;
      });
      _animController.forward(from: 0);
    } catch (e) {
      if (kDebugMode) debugPrint('[MyProfile] Error fetching profile: $e');
      if (!mounted || currentReq != _requestId) return;

      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load profile: $e';
      });
    }
  }

  String _formatDate(dynamic value) {
    if (value == null || value.toString().isEmpty) return '—';
    try {
      final d = DateTime.parse(value.toString());
      return DateFormat('dd MMM yyyy').format(d);
    } catch (_) {
      return value.toString();
    }
  }

  String _resolveAvatarUrl(dynamic avatar) {
    if (avatar == null || avatar.toString().trim().isEmpty) return '';
    final url = avatar.toString().trim();
    if (url.startsWith('http://') || url.startsWith('https://') || url.startsWith('data:')) {
      return url;
    }
    const baseUrl = 'https://hrms.etaprise.ai';
    if (url.startsWith('/')) {
      return '$baseUrl$url';
    }
    return '$baseUrl/$url';
  }

  String _maskValue(String? val, {bool isAccount = false}) {
    if (val == null || val.trim().isEmpty) return '—';
    if (!_maskFinancial) return val;
    if (isAccount && val.length > 4) {
      return '•••• ${val.substring(val.length - 4)}';
    }
    if (val.length > 4) {
      return '•••• ${val.substring(val.length - 4)}';
    }
    return '••••';
  }

  void _openEditModal() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const EditProfileScreen()),
    ).then((result) {
      if (mounted) {
        if (result is String && result.isNotEmpty) {
          setState(() {
            _profileData?['avatar'] = result;
          });
        }
        _fetchProfile();
      }
    });
  }

  void _copyToClipboard(String text, String label) {
    if (text.isEmpty || text == '—') return;
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Copied $label to clipboard'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authServiceProvider, (previous, next) {
      if (next.user?.id != _currentUserId) {
        _checkUserAndLoad();
      }
    });

    if (_isLoading) {
      final skeleton = Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const LoadingShimmer(height: 220, borderRadius: 24),
            const SizedBox(height: 16),
            const LoadingShimmer(height: 50, borderRadius: 14),
            const SizedBox(height: 16),
            const LoadingShimmer(height: 300, borderRadius: 20),
          ],
        ),
      );
      if (!widget.showAppBar) return skeleton;
      return GlassScaffold(title: 'My Profile', body: skeleton);
    }

    if (_profileData == null || _profileData!.isEmpty) {
      final errBody = Center(
        child: _errorMessage != null
            ? ErrorStateWidget(
                errorMessage: _errorMessage!,
                onRetry: _fetchProfile,
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const EmptyStateWidget(
                    title: 'Profile Unavailable',
                    message: 'No profile details found for your account.',
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _fetchProfile,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
      );
      if (!widget.showAppBar) return errBody;
      return GlassScaffold(title: 'My Profile', body: errBody);
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    final bodyContent = CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: _buildHeroHeader(context, isDark),
          ),
        ),
        SliverPersistentHeader(
          pinned: true,
          delegate: _StickyTabBarDelegate(
            child: _buildTabsNav(context, isDark),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 24 + bottomInset),
          sliver: SliverToBoxAdapter(
            child: MediaQuery.of(context).disableAnimations
                ? _buildActiveTabContent(context, isDark)
                : FadeTransition(
                    opacity: _animController,
                    child: _buildActiveTabContent(context, isDark),
                  ),
          ),
        ),
      ],
    );

    if (!widget.showAppBar) return bodyContent;

    return GlassScaffold(
      title: 'My Profile',
      body: bodyContent,
    );
  }

  Widget _buildHeroHeader(BuildContext context, bool isDark) {
    final p = _profileData!;
    final firstName = p['firstName'] ?? p['name'] ?? 'Employee';
    final lastName = p['lastName'] ?? '';
    final fullName = '$firstName $lastName'.trim();
    final email = (p['email'] ?? '—').toString();
    final role = (p['role'] ?? 'Employee').toString();
    final employeeId = (p['employeeId'] ?? p['code'] ?? '—').toString();
    final shift = (p['shiftName'] ?? p['shift'] ?? '').toString();
    final avatarUrl = _resolveAvatarUrl(p['avatar'] ?? p['avatarUrl']);

    final surfaceColor = isDark ? AppColors.darkMainSurface : Colors.white;
    final textColor = isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText;
    final secondaryTextColor = isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText;
    final borderColor = isDark ? AppColors.darkBordersAndDividers : AppColors.lightBordersAndDividers;

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 50 : 10),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Teal Gradient Banner
          Container(
            height: 90,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0F6B66), Color(0xFF148079), Color(0xFF1DA79E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            alignment: Alignment.topRight,
            child: Semantics(
              button: true,
              label: 'Edit Profile',
              child: ElevatedButton.icon(
                onPressed: _openEditModal,
                icon: const Icon(Icons.edit_rounded, size: 15, color: AppColors.primary),
                label: const Text('Edit Profile', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.primary,
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
              ),
            ),
          ),

          // Main Info Block
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              children: [
                Transform.translate(
                  offset: const Offset(0, -42),
                  child: Column(
                    children: [
                      Semantics(
                        label: 'Profile picture for $fullName',
                        child: Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: surfaceColor,
                            border: Border.all(color: surfaceColor, width: 4),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withAlpha(40), blurRadius: 10, offset: const Offset(0, 4)),
                            ],
                          ),
                          child: ClipOval(
                            child: avatarUrl.isNotEmpty
                                ? AuthenticatedImage(
                                    imageUrl: avatarUrl,
                                    fit: BoxFit.cover,
                                    placeholder: (c) => Container(
                                      color: AppColors.primary.withAlpha(50),
                                      child: const Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))),
                                    ),
                                    errorWidget: (c) => _defaultAvatar(fullName),
                                  )
                                : _defaultAvatar(fullName),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        fullName,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                          letterSpacing: -0.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              email,
                              style: TextStyle(fontSize: 13, color: secondaryTextColor),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (email != '—') ...[
                            const SizedBox(width: 4),
                            Semantics(
                              button: true,
                              label: 'Copy email address',
                              child: InkWell(
                                onTap: () => _copyToClipboard(email, 'Email'),
                                borderRadius: BorderRadius.circular(12),
                                child: const Padding(
                                  padding: EdgeInsets.all(4),
                                  child: Icon(Icons.copy_rounded, size: 14, color: AppColors.primary),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                Transform.translate(
                  offset: const Offset(0, -24),
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (role.isNotEmpty)
                        _buildHeroChip(role, AppColors.primary.withAlpha(25), AppColors.primary, Icons.badge_outlined),
                      if (employeeId.isNotEmpty && employeeId != '—')
                        _buildHeroChip('ID: $employeeId', isDark ? AppColors.darkSecondarySurface : AppColors.lightSecondarySurface, secondaryTextColor, Icons.fingerprint, onCopy: () => _copyToClipboard(employeeId, 'Employee ID')),
                      if (shift.isNotEmpty && shift != '—')
                        _buildHeroChip(shift, isDark ? const Color(0xFF3B2D0C) : const Color(0xFFFEF3C7), isDark ? const Color(0xFFFDE047) : const Color(0xFF92400E), Icons.access_time_rounded),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _defaultAvatar(String name) {
    return Container(
      color: AppColors.primary,
      alignment: Alignment.center,
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : 'U',
        style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
      ),
    );
  }

  Widget _buildHeroChip(String label, Color bg, Color fg, IconData icon, {VoidCallback? onCopy}) {
    return Container(
      constraints: const BoxConstraints(minHeight: 32),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: fg),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: fg),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (onCopy != null) ...[
            const SizedBox(width: 4),
            GestureDetector(
              onTap: onCopy,
              child: Icon(Icons.copy_rounded, size: 12, color: fg),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTabsNav(BuildContext context, bool isDark) {
    final tabs = [
      {'title': 'Employment', 'icon': Icons.business_center_rounded},
      {'title': 'Personal', 'icon': Icons.person_rounded},
      {'title': 'Financial', 'icon': Icons.account_balance_wallet_rounded},
      {'title': 'Security', 'icon': Icons.shield_rounded},
    ];

    final navBg = isDark ? AppColors.darkMainSurface : Colors.white;
    final borderColor = isDark ? AppColors.darkBordersAndDividers : AppColors.lightBordersAndDividers;

    return Container(
      decoration: BoxDecoration(
        color: navBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 40 : 12),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: List.generate(tabs.length, (index) {
          final tab = tabs[index];
          final isActive = _activeTab == index;
          return Expanded(
            child: Semantics(
              selected: isActive,
              button: true,
              label: tab['title'] as String,
              child: InkWell(
                onTap: () {
                  if (_activeTab != index) {
                    setState(() => _activeTab = index);
                    _animController.forward(from: 0);
                  }
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 48),
                  padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 2),
                  decoration: BoxDecoration(
                    color: isActive ? AppColors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          tab['icon'] as IconData,
                          size: 20,
                          color: isActive ? Colors.white : (isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          tab['title'] as String,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
                            color: isActive ? Colors.white : (isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildActiveTabContent(BuildContext context, bool isDark) {
    switch (_activeTab) {
      case 0:
        return _buildEmploymentTab(isDark);
      case 1:
        return _buildPersonalTab(isDark);
      case 2:
        return _buildFinancialTab(isDark);
      case 3:
        return _buildSecurityTab(isDark);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildEmploymentTab(bool isDark) {
    final p = _profileData!;
    final history = p['branchHistory'] is List ? p['branchHistory'] as List : [];
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 340 || MediaQuery.textScalerOf(context).scale(1.0) > 1.3;

    return Column(
      children: [
        ProfileSectionCard(
          title: 'Employment Overview',
          subtitle: 'Official designation, team structure, and location',
          icon: Icons.badge_outlined,
          child: Column(
            children: [
              ProfileInfoRow(label: 'Organization', value: (p['organization'] ?? p['companyName'] ?? p['company'] ?? p['branchName'] ?? p['branch'])?.toString(), icon: Icons.business_rounded),
              _gridPair(
                isCompact,
                ProfileInfoRow(label: 'Department', value: (p['departmentName'] ?? p['department'])?.toString(), icon: Icons.account_tree_rounded),
                ProfileInfoRow(label: 'Designation', value: (p['designationName'] ?? p['designation'])?.toString(), icon: Icons.work_rounded),
              ),
              _gridPair(
                isCompact,
                ProfileInfoRow(label: 'Branch', value: (p['branchName'] ?? p['branch'])?.toString(), icon: Icons.account_balance_rounded),
                ProfileInfoRow(label: 'Team', value: (p['teamName'] ?? p['team'])?.toString(), icon: Icons.groups_rounded),
              ),
              _gridPair(
                isCompact,
                ProfileInfoRow(label: 'Reporting Manager', value: (p['reportingManagerName'] ?? p['reportingManager'] ?? p['managerName'] ?? p['manager'])?.toString(), icon: Icons.person_pin_rounded),
                ProfileInfoRow(label: 'Joined Date', value: _formatDate(p['joiningDate'] ?? p['joinedDate']), icon: Icons.calendar_today_rounded),
              ),
              _gridPair(
                isCompact,
                ProfileInfoRow(label: 'Work Location', value: (p['workLocation'] ?? p['location'] ?? p['address'])?.toString(), icon: Icons.location_on_rounded),
                ProfileInfoRow(label: 'Assigned Shift', value: (p['shiftName'] ?? p['shift'])?.toString(), icon: Icons.access_time_rounded),
              ),
              ProfileInfoRow(label: 'Salary (CTC)', value: (p['salary'] != null && p['salary'].toString() != '0') ? '₹ ${p['salary']}' : (p['basicSalary'] != null ? '₹ ${p['basicSalary']}' : null), icon: Icons.payments_rounded, isGreen: true),
            ],
          ),
        ),
        if (history.isNotEmpty)
          ProfileSectionCard(
            title: 'Branch Assignment History',
            subtitle: 'Track of previous and current branch transfers',
            icon: Icons.alt_route_rounded,
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: history.length,
              separatorBuilder: (context, idx) => Divider(height: 16, color: (isDark ? AppColors.darkBordersAndDividers : AppColors.lightBordersAndDividers).withOpacity(0.15)),
              itemBuilder: (context, idx) {
                final h = history[idx] as Map<String, dynamic>;
                final isActive = h['isActive'] == true;
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(Icons.business_rounded, size: 16, color: AppColors.primary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(h['branchName'] ?? h['branchId'] ?? 'HQ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText), overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 2),
                                Text('${_formatDate(h['startDate'])} - ${h['endDate'] != null ? _formatDate(h['endDate']) : 'Present'}', style: TextStyle(fontSize: 11.5, color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText), overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isActive ? AppColors.successBg : AppColors.errorBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        isActive ? 'Active' : 'Previous',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isActive ? AppColors.success : AppColors.error),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildPersonalTab(bool isDark) {
    final p = _profileData!;
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 340 || MediaQuery.textScalerOf(context).scale(1.0) > 1.3;

    return Column(
      children: [
        ProfileSectionCard(
          title: 'Personal Details',
          subtitle: 'Basic personal identifiers and background details',
          icon: Icons.person_outline_rounded,
          child: Column(
            children: [
              ProfileInfoRow(label: 'Email Address', value: (p['email'] ?? '').toString(), icon: Icons.email_rounded, showCopyIcon: true),
              ProfileInfoRow(label: 'Phone Number', value: (p['phone'] ?? '').toString(), icon: Icons.phone_rounded),
              ProfileInfoRow(label: 'Date of Birth', value: _formatDate(p['dateOfBirth']), icon: Icons.cake_rounded),
              _gridPair(
                isCompact,
                ProfileInfoRow(label: 'Gender', value: (p['gender'] ?? '').toString(), icon: Icons.wc_rounded),
                ProfileInfoRow(label: 'Marital Status', value: (p['maritalStatus'] ?? '').toString(), icon: Icons.favorite_rounded),
              ),
              ProfileInfoRow(label: 'Nationality', value: (p['nationality'] ?? '').toString(), icon: Icons.flag_rounded),
            ],
          ),
        ),
        ProfileSectionCard(
          title: 'Residential Address',
          subtitle: 'Current mailing and home location records',
          icon: Icons.home_outlined,
          child: Column(
            children: [
              ProfileInfoRow(label: 'Street Address', value: (p['address'] ?? '').toString(), icon: Icons.home_rounded),
              _gridPair(
                isCompact,
                ProfileInfoRow(label: 'City', value: (p['city'] ?? '').toString(), icon: Icons.location_city_rounded),
                ProfileInfoRow(label: 'State / Province', value: (p['state'] ?? '').toString(), icon: Icons.map_rounded),
              ),
              _gridPair(
                isCompact,
                ProfileInfoRow(label: 'Country', value: (p['country'] ?? '').toString(), icon: Icons.public_rounded),
                ProfileInfoRow(label: 'Postal Code', value: (p['zipCode'] ?? p['postalCode'] ?? '').toString(), icon: Icons.markunread_mailbox_rounded, isCode: true),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFinancialTab(bool isDark) {
    final p = _profileData!;
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 340 || MediaQuery.textScalerOf(context).scale(1.0) > 1.3;

    return Column(
      children: [
        ProfileSectionCard(
          title: 'Bank & Payroll Accounts',
          subtitle: 'Disbursement accounts and tax identifiers',
          icon: Icons.account_balance_rounded,
          isSensitive: true,
          trailing: Semantics(
            button: true,
            label: _maskFinancial ? 'Reveal Financial Data' : 'Hide Financial Data',
            child: IconButton(
              icon: Icon(_maskFinancial ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 20, color: AppColors.primary),
              tooltip: _maskFinancial ? 'Reveal Financial Data' : 'Mask Financial Data',
              onPressed: () => setState(() => _maskFinancial = !_maskFinancial),
            ),
          ),
          child: Column(
            children: [
              ProfileInfoRow(label: 'Bank Name', value: (p['bankName'] ?? '').toString(), icon: Icons.account_balance_rounded),
              ProfileInfoRow(label: 'Account Number', value: _maskValue(p['bankAccountNumber']?.toString(), isAccount: true), copyText: p['bankAccountNumber']?.toString(), icon: Icons.credit_card_rounded, isCode: true, showCopyIcon: !_maskFinancial),
              _gridPair(
                isCompact,
                ProfileInfoRow(label: 'IFSC Code', value: _maskValue(p['ifscCode']?.toString()), copyText: p['ifscCode']?.toString(), icon: Icons.qr_code_rounded, isCode: true),
                ProfileInfoRow(label: 'Tax ID / PAN', value: _maskValue(p['panNumber'] ?? p['taxId']?.toString()), copyText: (p['panNumber'] ?? p['taxId'])?.toString(), icon: Icons.receipt_long_rounded, isCode: true),
              ),
            ],
          ),
        ),
        ProfileSectionCard(
          title: 'Emergency Contacts',
          subtitle: 'Primary point of contact during emergency situations',
          icon: Icons.emergency_rounded,
          child: Column(
            children: [
              ProfileInfoRow(label: 'Contact Name', value: (p['emergencyContactName'] ?? '').toString(), icon: Icons.security_rounded),
              _gridPair(
                isCompact,
                ProfileInfoRow(label: 'Contact Phone', value: (p['emergencyContactPhone'] ?? '').toString(), icon: Icons.phone_forwarded_rounded),
                ProfileInfoRow(label: 'Relationship', value: (p['emergencyContactRelation'] ?? '').toString(), icon: Icons.people_rounded),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSecurityTab(bool isDark) {
    final textColor = isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText;
    final secondaryTextColor = isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText;

    return ProfileSectionCard(
      title: 'System Preferences',
      subtitle: 'Notification settings and location verification rules',
      icon: Icons.settings_suggest_rounded,
      isSensitive: true,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.notifications_active_rounded, color: AppColors.primary, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Push Notifications', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: textColor), overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 2),
                          Text('Receive alerts for attendance, shifts & leave', style: TextStyle(fontSize: 11.5, color: secondaryTextColor), overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Text('Managed via Server', style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey)),
            ],
          ),
          Divider(height: 24, color: (isDark ? AppColors.darkBordersAndDividers : AppColors.lightBordersAndDividers).withOpacity(0.15)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.location_searching_rounded, color: AppColors.success, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('GPS Geofence Validation', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: textColor), overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 2),
                          Text('Active perimeter policy enforcement', style: TextStyle(fontSize: 11.5, color: secondaryTextColor), overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: AppColors.successBg, borderRadius: BorderRadius.circular(12)),
                child: const Text('Enforced', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.success)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _gridPair(bool isCompact, Widget first, Widget second) {
    if (isCompact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [first, second],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: first),
        const SizedBox(width: 12),
        Expanded(child: second),
      ],
    );
  }
}

class _StickyTabBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  _StickyTabBarDelegate({required this.child});

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox.expand(child: child);
  }

  @override
  double get maxExtent => 64.0;

  @override
  double get minExtent => 64.0;

  @override
  bool shouldRebuild(covariant _StickyTabBarDelegate oldDelegate) {
    return oldDelegate.child != child;
  }
}
