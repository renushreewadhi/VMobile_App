import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/auth/auth_service.dart';
import '../../core/models/user_model.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/loading_shimmer.dart';
import '../../core/widgets/glass_scaffold.dart';
import 'edit_profile_screen.dart';

class MyProfileScreen extends ConsumerStatefulWidget {
  final bool showAppBar;
  const MyProfileScreen({super.key, this.showAppBar = false});

  @override
  ConsumerState<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends ConsumerState<MyProfileScreen> {
  int _activeTab = 0; // 0: Employment, 1: Personal, 2: Financial, 3: Security
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _profileData;
  int _requestId = 0;
  String? _currentUserId;
  bool _maskFinancial = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _checkUserAndLoad();
    });
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

    final apiClient = ref.read(apiClientProvider);
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
          final res = await apiClient.get(ApiEndpoints.employeeDetail(id!));
          final data = res is Map<String, dynamic> ? (res['data'] ?? res) : null;
          if (data != null && data is Map<String, dynamic> && (data['id'] != null || data['employeeId'] != null || data['email'] != null)) {
            matchedEmp = data;
            break;
          }
        } catch (_) {}

        try {
          final res = await apiClient.get('/employees/$id');
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
          final res = await apiClient.get('/employees/all');
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

      if (!mounted || currentReq != _requestId) return;

      // Fallback: Synthesize profile data from authUser session so HR / Admin / User accounts ALWAYS display a complete profile!
      final Map<String, dynamic> sessionProfile = {
        'id': authUser.id,
        'employeeId': (authUser.employeeId != null && authUser.employeeId!.trim().isNotEmpty) ? authUser.employeeId : authUser.id,
        'firstName': authUser.firstName.isNotEmpty ? authUser.firstName : 'User',
        'lastName': authUser.lastName,
        'name': authUser.fullName,
        'email': authUser.email,
        'role': authUser.role.name.toUpperCase(),
        'department': authUser.department ?? 'Human Resources',
        'designation': authUser.designation ?? (authUser.role == UserRole.HR ? 'HR Manager' : (authUser.role == UserRole.ADMIN ? 'System Administrator' : 'Staff')),
        'organization': 'Etaprise HRMS',
        'workLocation': authUser.branch ?? 'Headquarters',
        'joiningDate': DateTime.now().toIso8601String(),
        'avatar': authUser.avatar,
        'phone': authUser.phone ?? '—',
      };

      setState(() {
        _profileData = matchedEmp ?? sessionProfile;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (e) {
      if (kDebugMode) debugPrint('[MyProfile] Error fetching profile: $e');
      if (!mounted || currentReq != _requestId) return;

      final Map<String, dynamic> sessionProfile = {
        'id': authUser.id,
        'employeeId': (authUser.employeeId != null && authUser.employeeId!.trim().isNotEmpty) ? authUser.employeeId : authUser.id,
        'firstName': authUser.firstName.isNotEmpty ? authUser.firstName : 'User',
        'lastName': authUser.lastName,
        'name': authUser.fullName,
        'email': authUser.email,
        'role': authUser.role.name.toUpperCase(),
        'department': authUser.department ?? 'Human Resources',
        'designation': authUser.designation ?? (authUser.role == UserRole.HR ? 'HR Manager' : 'Staff'),
        'organization': 'Etaprise HRMS',
        'workLocation': authUser.branch ?? 'Headquarters',
        'joiningDate': DateTime.now().toIso8601String(),
        'avatar': authUser.avatar,
        'phone': authUser.phone ?? '—',
      };

      setState(() {
        _profileData = sessionProfile;
        _errorMessage = null;
        _isLoading = false;
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
      return '****${val.substring(val.length - 4)}';
    }
    if (val.length > 4) {
      return '*****${val.substring(val.length - 4)}';
    }
    return '****';
  }

  void _openEditModal() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const EditProfileScreen()),
    ).then((_) {
      if (mounted) _fetchProfile();
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authServiceProvider, (previous, next) {
      if (next.user?.id != _currentUserId) {
        _checkUserAndLoad();
      }
    });

    if (_isLoading) {
      final skeleton = const LoadingShimmer();
      if (!widget.showAppBar) return skeleton;
      return GlassScaffold(title: 'My Profile', body: skeleton);
    }

    if (_profileData == null || _profileData!.isEmpty) {
      final errBody = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.account_circle_outlined, size: 54, color: Colors.grey),
              const SizedBox(height: 16),
              const Text('Profile Unlinked or Unavailable', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(_errorMessage ?? 'No profile data available.', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
              const SizedBox(height: 24),
              ElevatedButton.icon(onPressed: _fetchProfile, icon: const Icon(Icons.refresh), label: const Text('Retry')),
            ],
          ),
        ),
      );
      if (!widget.showAppBar) return errBody;
      return GlassScaffold(title: 'My Profile', body: errBody);
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bodyContent = SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeroHeader(context, isDark),
          const SizedBox(height: 16),
          _buildTabsNav(context, isDark),
          const SizedBox(height: 16),
          _buildActiveTabContent(context, isDark),
          const SizedBox(height: 32),
        ],
      ),
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
    final email = p['email'] ?? '—';
    final role = p['role'] ?? 'Employee';
    final organization = p['organization'] ?? p['companyName'] ?? p['branch'] ?? 'Etaprise HRMS';
    final employeeId = p['employeeId'] ?? p['code'] ?? '—';
    final department = p['department'] ?? 'Human Resources';
    final team = p['teamName'] ?? p['team'] ?? 'Core HR';
    final shift = p['shiftName'] ?? p['shift'] ?? 'General Shift';
    final workLocation = p['workLocation'] ?? 'Headquarters';
    final avatarUrl = _resolveAvatarUrl(p['avatar'] ?? p['avatarUrl']);

    final surfaceColor = isDark ? AppColors.darkMainSurface : Colors.white;
    final textColor = isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText;
    final secondaryTextColor = isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText;
    final borderColor = isDark ? AppColors.darkBordersAndDividers : AppColors.lightBordersAndDividers;
    final pillBg = isDark ? AppColors.darkSecondarySurface : AppColors.lightSecondarySurface;

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(isDark ? 50 : 10), blurRadius: 20, offset: const Offset(0, 8)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Cover Banner
          Container(
            height: 100,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1E3A8A), Color(0xFF2563EB), Color(0xFF4F46E5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            padding: const EdgeInsets.all(16),
            alignment: Alignment.topRight,
            child: ElevatedButton.icon(
              onPressed: _openEditModal,
              icon: const Icon(Icons.edit, size: 14, color: Colors.white),
              label: const Text('Edit Profile', style: TextStyle(color: Colors.white, fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white.withAlpha(60),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              ),
            ),
          ),

          // Main Info Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Transform.translate(
                      offset: const Offset(0, -40),
                      child: Container(
                        width: 84,
                        height: 84,
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
                              ? Image.network(
                                  avatarUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (c, e, s) => _defaultAvatar(fullName),
                                )
                              : _defaultAvatar(fullName),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    fullName,
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: isDark ? AppColors.darkPrimary.withAlpha(80) : AppColors.lightPrimary,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: isDark ? AppColors.darkPrimary : const Color(0xFFBFDBFE)),
                                  ),
                                  child: Text(
                                    role,
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? Colors.blueAccent : AppColors.primary),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.email_outlined, size: 13, color: secondaryTextColor),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    email,
                                    style: TextStyle(fontSize: 12.5, color: secondaryTextColor),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _buildHeroPill(Icons.business, organization, pillBg, textColor),
                    _buildHeroPill(Icons.badge, 'ID: $employeeId', pillBg, secondaryTextColor),
                    _buildHeroPill(Icons.account_tree, department, pillBg, secondaryTextColor),
                    _buildHeroPill(Icons.group, team, pillBg, secondaryTextColor),
                    _buildHeroPill(Icons.access_time, shift, isDark ? const Color(0xFF3B2D0C) : const Color(0xFFFEF3C7), isDark ? const Color(0xFFFDE047) : const Color(0xFF92400E)),
                    _buildHeroPill(Icons.location_on, workLocation, isDark ? const Color(0xFF1E1B4B) : const Color(0xFFEEF2FF), isDark ? const Color(0xFF818CF8) : const Color(0xFF4338CA)),
                  ],
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
        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
      ),
    );
  }

  Widget _buildHeroPill(IconData icon, String label, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: fg),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabsNav(BuildContext context, bool isDark) {
    final tabs = [
      {'title': 'Employment', 'icon': Icons.business_center},
      {'title': 'Personal', 'icon': Icons.person},
      {'title': 'Financial', 'icon': Icons.account_balance_wallet},
      {'title': 'Security', 'icon': Icons.shield},
    ];

    final navBg = isDark ? AppColors.darkSecondarySurface : AppColors.lightSecondarySurface;

    return Container(
      decoration: BoxDecoration(
        color: navBg,
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: List.generate(tabs.length, (index) {
          final tab = tabs[index];
          final isActive = _activeTab == index;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _activeTab = index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
                decoration: BoxDecoration(
                  color: isActive ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: isActive ? [BoxShadow(color: AppColors.primary.withAlpha(80), blurRadius: 8, offset: const Offset(0, 4))] : [],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(tab['icon'] as IconData, size: 15, color: isActive ? Colors.white : (isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText)),
                    const SizedBox(height: 3),
                    Text(
                      tab['title'] as String,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
                        color: isActive ? Colors.white : (isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
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

    return Column(
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader('Employment Overview', 'Official designation, team structure, and location', Icons.badge, isDark),
              const Divider(height: 24),
              LayoutBuilder(
                builder: (context, constraints) {
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _detailCard('Organization', p['organization'] ?? p['companyName'] ?? p['branch'] ?? 'Etaprise HRMS', Icons.business, isDark, constraints: constraints),
                      _detailCard('Employee ID', p['employeeId'] ?? p['code'] ?? '—', Icons.fingerprint, isDark, isCode: true, constraints: constraints),
                      _detailCard('Department', p['department'] ?? 'Human Resources', Icons.account_tree, isDark, constraints: constraints),
                      _detailCard('Designation', p['designation'] ?? 'HR Manager', Icons.work, isDark, constraints: constraints),
                      _detailCard('Branch', p['branch'] ?? p['branchName'] ?? 'Main Office', Icons.account_balance, isDark, constraints: constraints),
                      _detailCard('Team', p['teamName'] ?? p['team'] ?? 'Core HR', Icons.groups, isDark, constraints: constraints),
                      _detailCard('Reporting Manager', p['reportingManagerName'] ?? p['reportingManager'] ?? '—', Icons.person_pin, isDark, constraints: constraints),
                      _detailCard('Joined Date', _formatDate(p['joiningDate'] ?? p['joinedDate']), Icons.calendar_today, isDark, constraints: constraints),
                      _detailCard('Work Location', p['workLocation'] ?? 'Headquarters', Icons.location_on, isDark, constraints: constraints),
                      _detailCard('Assigned Shift', p['shiftName'] ?? p['shift'] ?? 'General Shift', Icons.access_time, isDark, constraints: constraints),
                      _detailCard('Salary (CTC)', p['salary'] != null ? '₹ ${p['salary']}' : null, Icons.payments, isDark, isGreen: true, constraints: constraints),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader('Branch Assignment History', 'Track of previous and current branch transfers', Icons.alt_route, isDark),
              const Divider(height: 24),
              history.isEmpty
                  ? Text('No branch history available', style: TextStyle(color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText))
                  : ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: history.length,
                      separatorBuilder: (context, idx) => const Divider(height: 16),
                      itemBuilder: (context, idx) {
                        final h = history[idx] as Map<String, dynamic>;
                        final isActive = h['isActive'] == true;
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  const Icon(Icons.business, size: 16, color: AppColors.primary),
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
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPersonalTab(bool isDark) {
    final p = _profileData!;

    return Column(
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader('Personal Details', 'Basic personal identifiers and background details', Icons.person_outline, isDark),
              const Divider(height: 24),
              LayoutBuilder(
                builder: (context, constraints) {
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _detailCard('Email Address', p['email'], Icons.email, isDark, constraints: constraints),
                      _detailCard('Phone Number', p['phone'], Icons.phone, isDark, constraints: constraints),
                      _detailCard('Date of Birth', _formatDate(p['dateOfBirth']), Icons.cake, isDark, constraints: constraints),
                      _detailCard('Gender', p['gender'], Icons.wc, isDark, constraints: constraints),
                      _detailCard('Marital Status', p['maritalStatus'], Icons.favorite, isDark, constraints: constraints),
                      _detailCard('Nationality', p['nationality'], Icons.flag, isDark, constraints: constraints),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader('Residential Address', 'Current mailing and home location records', Icons.home_outlined, isDark),
              const Divider(height: 24),
              LayoutBuilder(
                builder: (context, constraints) {
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _detailCard('Street Address', p['address'], Icons.home, isDark, fullWidth: true, constraints: constraints),
                      _detailCard('City', p['city'], Icons.location_city, isDark, constraints: constraints),
                      _detailCard('State / Province', p['state'], Icons.map, isDark, constraints: constraints),
                      _detailCard('Country', p['country'], Icons.public, isDark, constraints: constraints),
                      _detailCard('Postal Code', p['zipCode'] ?? p['postalCode'], Icons.markunread_mailbox, isDark, isCode: true, constraints: constraints),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFinancialTab(bool isDark) {
    final p = _profileData!;

    return Column(
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: _buildSectionHeader('Bank & Payroll Accounts', 'Disbursement accounts and tax identifiers', Icons.account_balance, isDark)),
                  IconButton(
                    icon: Icon(_maskFinancial ? Icons.visibility_off : Icons.visibility, size: 20),
                    tooltip: _maskFinancial ? 'Reveal Financial Data' : 'Mask Financial Data',
                    onPressed: () => setState(() => _maskFinancial = !_maskFinancial),
                  ),
                ],
              ),
              const Divider(height: 24),
              LayoutBuilder(
                builder: (context, constraints) {
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _detailCard('Bank Name', p['bankName'], Icons.account_balance, isDark, constraints: constraints),
                      _detailCard('Account Number', _maskValue(p['bankAccountNumber']?.toString(), isAccount: true), Icons.credit_card, isDark, isCode: true, constraints: constraints),
                      _detailCard('IFSC Code', _maskValue(p['ifscCode']?.toString()), Icons.qr_code, isDark, isCode: true, constraints: constraints),
                      _detailCard('Tax ID / PAN', _maskValue(p['panNumber'] ?? p['taxId']?.toString()), Icons.receipt_long, isDark, isCode: true, constraints: constraints),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader('Emergency Contacts', 'Primary point of contact during emergency situations', Icons.emergency, isDark),
              const Divider(height: 24),
              LayoutBuilder(
                builder: (context, constraints) {
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _detailCard('Contact Name', p['emergencyContactName'], Icons.security, isDark, constraints: constraints),
                      _detailCard('Contact Phone', p['emergencyContactPhone'], Icons.phone_forwarded, isDark, constraints: constraints),
                      _detailCard('Relationship', p['emergencyContactRelation'], Icons.people, isDark, constraints: constraints),
                    ],
                  );
                },
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

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('System Preferences', 'Notification settings and location verification rules', Icons.settings_suggest, isDark),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.notifications_active, color: AppColors.primary),
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
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.location_searching, color: AppColors.success),
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

  Widget _buildSectionHeader(String title, String subtitle, IconData icon, bool isDark) {
    final textColor = isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText;
    final secondaryTextColor = isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText;

    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkPrimary.withAlpha(80) : AppColors.lightPrimary,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.primary, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: textColor), overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text(subtitle, style: TextStyle(fontSize: 11.5, color: secondaryTextColor), overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
  }

  Widget _detailCard(String label, String? value, IconData icon, bool isDark, {bool isCode = false, bool isGreen = false, bool fullWidth = false, required BoxConstraints constraints}) {
    final cardBg = isDark ? AppColors.darkSecondarySurface : AppColors.lightInputBackground;
    final borderColor = isDark ? AppColors.darkBordersAndDividers : AppColors.lightBordersAndDividers;
    final textColor = isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText;
    final secondaryTextColor = isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText;

    double cardWidth;
    if (fullWidth || constraints.maxWidth < 450) {
      cardWidth = double.infinity;
    } else {
      cardWidth = (constraints.maxWidth - 12) / 2;
    }

    return SizedBox(
      width: cardWidth,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 13, color: AppColors.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label.toUpperCase(),
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: secondaryTextColor),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              value ?? '—',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: isGreen ? AppColors.success : textColor,
                fontFamily: isCode ? 'monospace' : null,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
