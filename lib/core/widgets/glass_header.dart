import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/glass_theme.dart';
import '../theme/app_colors.dart';
import '../theme/theme_provider.dart';
import '../auth/auth_service.dart';
import '../../employee/screens/my_profile_screen.dart';

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
    return Size.fromHeight(hasTitle ? 112.0 : 60.0);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final glass = context.glass;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeNotifier = ref.read(themeProvider.notifier);
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
                    height: 56,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          leading ??
                              Image.asset(
                                'lib/assets/img.png',
                                height: 26,
                                fit: BoxFit.contain,
                                color: isDark ? Colors.white : null,
                              ),
                          const Spacer(),
                          if (actions != null) ...actions!,
                          if (actions == null) ...[
                            Semantics(
                              label: isDark ? "Switch to light mode" : "Switch to dark mode",
                              button: true,
                              child: IconButton(
                                onPressed: () => themeNotifier.toggleTheme(),
                                icon: Icon(
                                  isDark ? Icons.wb_sunny_rounded : Icons.nightlight_round,
                                  size: 20,
                                  color: glass.textSecondary,
                                ),
                              ),
                            ),
                            if (authState.isAuthenticated && authState.user != null) ...[
                              const SizedBox(width: 4),
                              Semantics(
                                label: "User profile",
                                button: true,
                                child: PopupMenuButton<String>(
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
                                        // Capture before awaiting: this header is disposed as soon as auth state flips.
                                        final authNotifier = ref.read(authServiceProvider.notifier);
                                        final navigator = Navigator.of(context, rootNavigator: true);
                                        // Unwind any pushed screens; the auth-gated root shows the login screen.
                                        // Do NOT push a standalone LoginScreen: it would replace the gated root,
                                        // so the next login could never navigate to the dashboard.
                                        navigator.popUntil((route) => route.isFirst);
                                        await authNotifier.logout();
                                      }
                                    }
                                  },
                                  itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
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
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                // 2. SUBHEADER ROW FOR PAGE TITLE & BACK BUTTON (Directly below brand row)
                if (hasTitle)
                  Container(
                    height: 52,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: glass.headerBorder.withOpacity(0.5), width: 0.5),
                      ),
                    ),
                    child: Row(
                      children: [
                        if (showBackButton || canPop)
                          IconButton(
                            icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: glass.textPrimary),
                            onPressed: onBackPressed ?? () => Navigator.of(context).maybePop(),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        if (showBackButton || canPop) const SizedBox(width: 12),
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