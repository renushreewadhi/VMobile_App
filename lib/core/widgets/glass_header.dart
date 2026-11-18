import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/glass_theme.dart';
import '../theme/app_colors.dart';
import '../theme/theme_provider.dart';
import '../auth/auth_service.dart';
import '../../employee/screens/my_profile_screen.dart';
import '../../employee/screens/notifications_screen.dart';
import 'theme_toggle_button.dart';

class GlassHeader extends ConsumerWidget implements PreferredSizeWidget {
  final String? title;
  final Widget? leading;
  final List<Widget>? actions;
  final String? userInitial;
  final VoidCallback? onAvatarTap;
  final VoidCallback? onBackPressed;
  final bool showBackButton;

  const GlassHeader({
    super.key,
    this.title,
    this.leading,
    this.actions,
    this.userInitial,
    this.onAvatarTap,
    this.onBackPressed,
    this.showBackButton = false,
  });

  @override
  Size get preferredSize {
    final hasTitle = title != null && title!.isNotEmpty;
    return Size.fromHeight(hasTitle ? 100.0 : 54.0);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final glass = context.glass;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authState = ref.watch(authServiceProvider);
    final user = authState.user;
    final initial = userInitial ?? (authState.isAuthenticated && user != null && user.firstName.isNotEmpty ? user.firstName[0].toUpperCase() : '');
    final topPadding = MediaQuery.paddingOf(context).top;
    final hasTitle = title != null && title!.isNotEmpty;
    final ModalRoute<dynamic>? parentRoute = ModalRoute.of(context);
    final bool canPop = parentRoute?.canPop ?? false;

    return RepaintBoundary(
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: glass.headerBlur, sigmaY: glass.headerBlur),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: glass.headerFill,
              border: Border(
                bottom: BorderSide(color: glass.headerBorder, width: 1),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. TOP FIXED BRAND ROW (Always present across every page: Logo + Theme toggle + Profile Avatar)
                Padding(
                  padding: EdgeInsets.only(top: topPadding),
                  child: SizedBox(
                    height: 54,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 16, right: 8),
                      child: Row(
                        children: [
                          leading ??
                              Image.asset(
                                'lib/assets/img.png',
                                height: 26,
                                fit: BoxFit.contain,
                                color: isDark ? Colors.white : null,
                                errorBuilder: (_, __, ___) => Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.business_rounded, color: isDark ? Colors.white : AppColors.primary, size: 22),
                                    const SizedBox(width: 6),
                                    Text('etaprise', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                                  ],
                                ),
                              ),
                          const Spacer(),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: actions ?? [
                              const ThemeToggleButton(size: 20),
                              if (authState.isAuthenticated && authState.user != null) ...[
                                const SizedBox(width: 4),
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  icon: Stack(
                                    children: [
                                      Icon(Icons.notifications_outlined, color: isDark ? Colors.white : const Color(0xFF0F172A), size: 22),
                                      Positioned(
                                        right: 0,
                                        top: 0,
                                        child: Container(
                                          width: 7,
                                          height: 7,
                                          decoration: const BoxDecoration(
                                            color: AppColors.primary,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  tooltip: 'Notifications',
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                                    );
                                  },
                                ),
                                const SizedBox(width: 4),
                                PopupMenuButton<String>(
                                  offset: const Offset(0, 48),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  color: isDark ? const Color(0xFF141D2E) : Colors.white,
                                  elevation: 8,
                                  onSelected: (value) async {
                                    if (value == 'profile') {
                                      if (onAvatarTap != null) {
                                        onAvatarTap!();
                                      } else {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(builder: (_) => const MyProfileScreen(showAppBar: true)),
                                        );
                                      }
                                    } else if (value == 'notifications') {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                                      );
                                    } else if (value == 'logout') {
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          backgroundColor: isDark ? const Color(0xFF141D2E) : Colors.white,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                          title: Text(
                                            'Confirm Logout',
                                            style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontWeight: FontWeight.bold),
                                          ),
                                          content: Text(
                                            'Are you sure you want to log out of your account?',
                                            style: TextStyle(color: isDark ? const Color(0xFFA3AFBD) : const Color(0xFF475569)),
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(ctx, false),
                                              child: const Text('Cancel'),
                                            ),
                                            ElevatedButton(
                                              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                                              onPressed: () => Navigator.pop(ctx, true),
                                              child: const Text('Logout', style: TextStyle(color: Colors.white)),
                                            ),
                                          ],
                                        ),
                                      );

                                      if (confirm == true && context.mounted) {
                                        final authNotifier = ref.read(authServiceProvider.notifier);
                                        final navigator = Navigator.of(context, rootNavigator: true);
                                        navigator.popUntil((route) => route.isFirst);
                                        await authNotifier.logout();
                                      }
                                    }
                                  },
                                  itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                                    PopupMenuItem<String>(
                                      enabled: false,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 4),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 38,
                                              height: 38,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                gradient: LinearGradient(
                                                  colors: glass.avatarGradient,
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                ),
                                              ),
                                              child: Center(
                                                child: Text(
                                                  initial,
                                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    user?.fullName.isNotEmpty == true ? user!.fullName : 'User',
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      fontWeight: FontWeight.bold,
                                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                  Text(
                                                    user?.email ?? '',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: isDark ? Colors.white70 : const Color(0xFF64748B),
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const PopupMenuDivider(height: 1),
                                    PopupMenuItem<String>(
                                      value: 'profile',
                                      child: Row(
                                        children: [
                                          Icon(Icons.person_outline_rounded, size: 18, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                                          const SizedBox(width: 10),
                                          Text(
                                            'My Profile',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    PopupMenuItem<String>(
                                      value: 'notifications',
                                      child: Row(
                                        children: [
                                          Icon(Icons.notifications_none_rounded, size: 18, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                                          const SizedBox(width: 10),
                                          Text(
                                            'Notifications',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuDivider(height: 1),
                                    PopupMenuItem<String>(
                                      value: 'logout',
                                      child: Row(
                                        children: const [
                                          Icon(Icons.logout_rounded, size: 18, color: AppColors.error),
                                          SizedBox(width: 10),
                                          Text(
                                            'Logout',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.error,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                  child: Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(
                                        colors: glass.avatarGradient,
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      border: glass.avatarRing != Colors.transparent
                                          ? Border.all(color: glass.avatarRing, width: 2)
                                          : null,
                                    ),
                                    child: Center(
                                      child: Text(
                                        initial,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // 2. SUBHEADER ROW FOR PAGE TITLE & BACK BUTTON (Directly below brand row)
                if (hasTitle)
                  Container(
                    height: 46,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: glass.headerBorder.withOpacity(0.5), width: 0.5),
                      ),
                    ),
                    child: Row(
                      children: [
                        if (showBackButton || (leading == null && canPop))
                          IconButton(
                            icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: glass.textPrimary),
                            onPressed: onBackPressed ?? () => Navigator.of(context).maybePop(),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        if (showBackButton || (leading == null && canPop)) const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            title!,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: glass.textPrimary,
                              letterSpacing: -0.3,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
