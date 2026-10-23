import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/glass_theme.dart';
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
    return Size.fromHeight(hasTitle ? 116.0 : 60.0);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final glass = context.glass;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeNotifier = ref.read(themeProvider.notifier);
    final authState = ref.watch(authServiceProvider);
    final user = authState.user;
    final initial = userInitial ?? (user != null && user.firstName.isNotEmpty ? user.firstName[0].toUpperCase() : 'E');
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
                // Top Status Bar Safe Area + WhatsApp-style primary brand row
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
                            const SizedBox(width: 4),
                            Semantics(
                              label: "User profile",
                              button: true,
                              child: GestureDetector(
                                onTap: onAvatarTap ?? () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const MyProfileScreen(showAppBar: true)),
                                  );
                                },
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
                      ),
                    ),
                  ),
                ),
                // Subheader row for page title and back button (if title is present)
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
