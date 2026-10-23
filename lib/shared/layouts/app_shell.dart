import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_provider.dart';
import '../../employee/screens/my_profile_screen.dart';

class AppShell extends ConsumerStatefulWidget {
  final Widget body;
  final String title;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<NavigationDestination> destinations;

  const AppShell({
    super.key,
    required this.body,
    required this.title,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
  });

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authServiceProvider);
    final themeMode = ref.watch(themeProvider);
    final user = authState.user;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: CompanyLogo(isDark: isDark),
        actions: [
          IconButton(
            tooltip: 'Toggle Theme',
            icon: Icon(
              themeMode == ThemeMode.dark ? Icons.wb_sunny_rounded : Icons.nightlight_round,
              size: 20,
              color: isDark ? AppColors.primaryLight : AppColors.primary,
            ),
            onPressed: () {
              ref.read(themeProvider.notifier).toggleTheme();
            },
          ),
          if (user != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: PopupMenuButton<String>(
                offset: const Offset(0, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
                elevation: 4,
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: isDark ? AppColors.primaryLight : AppColors.primary,
                  child: Text(
                    user.firstName.isNotEmpty ? user.firstName[0].toUpperCase() : 'U',
                    style: TextStyle(
                      color: isDark ? Colors.black : Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                onSelected: (value) {
                  if (value == 'profile') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const MyProfileScreen(showAppBar: true)),
                    );
                  } else if (value == 'logout') {
                    ref.read(authServiceProvider.notifier).logout();
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    enabled: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.fullName,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText,
                          ),
                        ),
                        Text(
                          user.role.toFormattedString(),
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'profile',
                    child: Row(
                      children: [
                        Icon(Icons.person_outline_rounded, size: 18),
                        SizedBox(width: 10),
                        Text('My Profile'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'logout',
                    child: Row(
                      children: [
                        Icon(Icons.logout_rounded, size: 18, color: AppColors.error),
                        SizedBox(width: 10),
                        Text('Logout', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.title.isNotEmpty && widget.title != 'Etaprise HRMS')
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkMainSurface : Colors.white,
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? AppColors.darkBordersAndDividers : AppColors.lightBordersAndDividers,
                    width: 0.5,
                  ),
                ),
              ),
              child: Text(
                widget.title,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText,
                  letterSpacing: -0.3,
                ),
              ),
            ),
          Expanded(
            child: widget.body,
          ),
        ],
      ),
      bottomNavigationBar: widget.destinations.isNotEmpty
          ? Container(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: isDark ? AppColors.darkBordersAndDividers : AppColors.lightBordersAndDividers,
                    width: 1,
                  ),
                ),
              ),
              child: NavigationBar(
                selectedIndex: widget.selectedIndex,
                onDestinationSelected: widget.onDestinationSelected,
                destinations: widget.destinations,
              ),
            )
          : null,
    );
  }
}

class CompanyLogo extends StatelessWidget {
  final bool isDark;
  const CompanyLogo({super.key, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'lib/assets/img.png',
      height: 28,
      fit: BoxFit.contain,
    );
  }
}
