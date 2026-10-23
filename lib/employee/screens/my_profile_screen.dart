import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_service.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/custom_text_field.dart';
import 'edit_profile_screen.dart';

class MyProfileScreen extends ConsumerStatefulWidget {
  final bool showAppBar;
  const MyProfileScreen({super.key, this.showAppBar = false});

  @override
  ConsumerState<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends ConsumerState<MyProfileScreen> {
  int _activeTab = 0; // 0: Employment, 1: Personal, 2: Financial, 3: Security
  bool _pushNotifications = true;

  // Profile data state
  late Map<String, dynamic> _profileData;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authServiceProvider).user;
    _profileData = {
      'firstName': user?.firstName ?? 'John',
      'lastName': user?.lastName ?? 'Doe',
      'email': user?.email ?? 'john.doe@envisionbeyond.com',
      'phone': user?.phone ?? '+1 (555) 019-2834',
      'role': user?.role.toFormattedString() ?? 'Employee',
      'organization': 'Envision Beyond India Pvt Ltd',
      'employeeId': user?.employeeId ?? 'EMP-2026-004',
      'department': user?.department ?? 'Engineering',
      'designation': user?.designation ?? 'Senior Software Engineer',
      'branch': user?.branch ?? 'Headquarters - Bangalore',
      'team': 'Alpha Core Team',
      'shift': 'General Shift (09:00 - 18:00)',
      'workLocation': 'Bangalore Tech Park, Block B',
      'reportingManager': 'Sarah Jenkins (Engineering Director)',
      'joinedDate': '15 Jan 2023',
      'dateOfBirth': '12 Aug 1995',
      'gender': 'Male',
      'maritalStatus': 'Single',
      'nationality': 'Indian',
      'address': '123 Tech Park Avenue, Electronic City',
      'city': 'Bangalore',
      'state': 'Karnataka',
      'country': 'India',
      'postalCode': '560100',
      'region': 'South Asia',
      'emergencyContactName': 'Jane Doe (Sister)',
      'emergencyContactPhone': '+1 (555) 987-6543',
      'emergencyContactRelation': 'Sibling',
      'bankName': 'HDFC Bank',
      'bankAccountNumber': '**** **** 4589',
      'ifscCode': 'HDFC0001234',
      'taxId': 'ABCDE1234F',
      'panNumber': 'ABCDE1234F',
      'salary': 1250000,
      'branchHistory': [
        {'branchName': 'Bangalore HQ', 'startDate': '15 Jan 2023', 'endDate': null, 'isActive': true},
        {'branchName': 'Mumbai Hub', 'startDate': '10 Mar 2021', 'endDate': '14 Jan 2023', 'isActive': false},
      ],
      'avatarUrl': user?.avatar ?? '',
    };
  }

  void _openEditModal() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const EditProfileScreen()),
    ).then((_) {
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bodyContent = SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Hero Header Card
          _buildHeroHeader(context, isDark),
          const SizedBox(height: 16),


          // 3. Profile Navigation Tabs
          _buildTabsNav(context, isDark),
          const SizedBox(height: 16),

          // 4. Tab Content
          _buildActiveTabContent(context, isDark),
          const SizedBox(height: 32),
        ],
      ),
    );

    if (!widget.showAppBar) return bodyContent;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: bodyContent,
    );
  }

  Widget _buildHeroHeader(BuildContext context, bool isDark) {
    final fullName = '${_profileData['firstName']} ${_profileData['lastName']}';
    final avatarUrl = _profileData['avatarUrl'] as String?;
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
          BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.04), blurRadius: 20, offset: const Offset(0, 8)),
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
                backgroundColor: Colors.white.withOpacity(0.25),
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
                    // Avatar Wrapper with Camera Badge
                    Transform.translate(
                      offset: const Offset(0, -40),
                      child: Stack(
                        children: [
                          Container(
                            width: 84,
                            height: 84,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: surfaceColor,
                              border: Border.all(color: surfaceColor, width: 4),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 10, offset: const Offset(0, 4)),
                              ],
                            ),
                            child: ClipOval(
                              child: avatarUrl != null && avatarUrl.isNotEmpty
                                  ? Image.network(avatarUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _defaultAvatar(fullName))
                                  : _defaultAvatar(fullName),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                icon: const Icon(Icons.camera_alt, size: 13, color: Colors.white),
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Avatar upload triggered')),
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
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
                                    color: isDark ? AppColors.darkPrimary.withOpacity(0.3) : AppColors.lightPrimary,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: isDark ? AppColors.darkPrimary : const Color(0xFFBFDBFE)),
                                  ),
                                  child: Text(
                                    _profileData['role'] ?? 'Employee',
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
                                    _profileData['email'] ?? '',
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

                // Hero Badges / Pills
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _buildHeroPill(Icons.business, _profileData['organization'], pillBg, textColor),
                    _buildHeroPill(Icons.badge, 'ID: ${_profileData['employeeId']}', pillBg, secondaryTextColor),
                    _buildHeroPill(Icons.account_tree, _profileData['department'], pillBg, secondaryTextColor),
                    _buildHeroPill(Icons.group, _profileData['team'], pillBg, secondaryTextColor),
                    _buildHeroPill(Icons.access_time, _profileData['shift'], isDark ? const Color(0xFF3B2D0C) : const Color(0xFFFEF3C7), isDark ? const Color(0xFFFDE047) : const Color(0xFF92400E)),
                    _buildHeroPill(Icons.location_on, _profileData['workLocation'], isDark ? const Color(0xFF1E1B4B) : const Color(0xFFEEF2FF), isDark ? const Color(0xFF818CF8) : const Color(0xFF4338CA)),
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
                  boxShadow: isActive ? [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))] : [],
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
    final history = _profileData['branchHistory'] as List<dynamic>? ?? [];

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
                      _detailCard('Organization', _profileData['organization'], Icons.business, isDark, constraints: constraints),
                      _detailCard('Employee ID', _profileData['employeeId'], Icons.fingerprint, isDark, isCode: true, constraints: constraints),
                      _detailCard('Department', _profileData['department'], Icons.account_tree, isDark, constraints: constraints),
                      _detailCard('Designation', _profileData['designation'], Icons.work, isDark, constraints: constraints),
                      _detailCard('Branch', _profileData['branch'], Icons.account_balance, isDark, constraints: constraints),
                      _detailCard('Team', _profileData['team'], Icons.groups, isDark, constraints: constraints),
                      _detailCard('Reporting Manager', _profileData['reportingManager'], Icons.person_pin, isDark, constraints: constraints),
                      _detailCard('Joined Date', _profileData['joinedDate'], Icons.calendar_today, isDark, constraints: constraints),
                      _detailCard('Work Location', _profileData['workLocation'], Icons.location_on, isDark, constraints: constraints),
                      _detailCard('Assigned Shift', _profileData['shift'], Icons.access_time, isDark, constraints: constraints),
                      _detailCard('Salary (CTC)', '₹ ${_profileData['salary']}', Icons.payments, isDark, isGreen: true, constraints: constraints),
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
                      separatorBuilder: (_, __) => const Divider(height: 16),
                      itemBuilder: (context, index) {
                        final h = history[index];
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
                                        Text(h['branchName'], style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText), overflow: TextOverflow.ellipsis),
                                        const SizedBox(height: 2),
                                        Text('${h['startDate']} - ${h['endDate'] ?? 'Present'}', style: TextStyle(fontSize: 11.5, color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText), overflow: TextOverflow.ellipsis),
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
                      _detailCard('Email Address', _profileData['email'], Icons.email, isDark, constraints: constraints),
                      _detailCard('Phone Number', _profileData['phone'], Icons.phone, isDark, constraints: constraints),
                      _detailCard('Date of Birth', _profileData['dateOfBirth'], Icons.cake, isDark, constraints: constraints),
                      _detailCard('Gender', _profileData['gender'], Icons.wc, isDark, constraints: constraints),
                      _detailCard('Marital Status', _profileData['maritalStatus'], Icons.favorite, isDark, constraints: constraints),
                      _detailCard('Nationality', _profileData['nationality'], Icons.flag, isDark, constraints: constraints),
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
                      _detailCard('Street Address', _profileData['address'], Icons.home, isDark, fullWidth: true, constraints: constraints),
                      _detailCard('City', _profileData['city'], Icons.location_city, isDark, constraints: constraints),
                      _detailCard('State / Province', _profileData['state'], Icons.map, isDark, constraints: constraints),
                      _detailCard('Country', _profileData['country'], Icons.public, isDark, constraints: constraints),
                      _detailCard('Postal Code', _profileData['postalCode'], Icons.markunread_mailbox, isDark, isCode: true, constraints: constraints),
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
    return Column(
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader('Bank & Payroll Accounts', 'Disbursement accounts and tax registration identifiers', Icons.account_balance, isDark),
              const Divider(height: 24),
              LayoutBuilder(
                builder: (context, constraints) {
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _detailCard('Bank Name', _profileData['bankName'], Icons.account_balance, isDark, constraints: constraints),
                      _detailCard('Account Number', _profileData['bankAccountNumber'], Icons.credit_card, isDark, isCode: true, constraints: constraints),
                      _detailCard('IFSC Code', _profileData['ifscCode'], Icons.qr_code, isDark, isCode: true, constraints: constraints),
                      _detailCard('Tax ID / PAN', _profileData['taxId'], Icons.receipt_long, isDark, isCode: true, constraints: constraints),
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
                      _detailCard('Contact Name', _profileData['emergencyContactName'], Icons.security, isDark, constraints: constraints),
                      _detailCard('Contact Phone', _profileData['emergencyContactPhone'], Icons.phone_forwarded, isDark, constraints: constraints),
                      _detailCard('Relationship', _profileData['emergencyContactRelation'], Icons.people, isDark, constraints: constraints),
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
              Switch(
                value: _pushNotifications,
                onChanged: (val) {
                  setState(() => _pushNotifications = val);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Push notifications ${val ? 'enabled' : 'disabled'}')),
                  );
                },
              ),
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
                          Text('Ensures check-ins within 500m office perimeter', style: TextStyle(fontSize: 11.5, color: secondaryTextColor), overflow: TextOverflow.ellipsis),
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
                child: const Text('Active', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.success)),
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
            color: isDark ? AppColors.darkPrimary.withOpacity(0.3) : AppColors.lightPrimary,
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
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
