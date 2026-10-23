import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/glass_theme.dart';
import '../theme/theme_provider.dart';
import '../auth/auth_service.dart';
import '../../employee/screens/my_profile_screen.dart';
import 'glass_card.dart';

class GlassHeader extends ConsumerWidget implements PreferredSizeWidget {
  final String? title;
  final Widget? leading;
  final List<Widget>? actions;
  final String? userInitial;
  final VoidCallback? onAvatarTap;

  const GlassHeader({
    super.key,
    this.title,
    this.leading,
    this.actions,
    this.userInitial,
    this.onAvatarTap,
  });

  @override
  Size get preferredSize => const Size.fromHeight(70);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final glass = context.glass;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeNotifier = ref.read(themeProvider.notifier);
    final authState = ref.watch(authServiceProvider);
    final user = authState.user;
    final initial = userInitial ?? (user != null && user.firstName.isNotEmpty ? user.firstName[0].toUpperCase() : 'E');

    return RepaintBoundary(
      child: GlassSurface(
        blur: true,
        radius: glass.headerRadius,
        fillColor: glass.headerFill,
        borderColor: glass.headerBorder,
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            // Leading: Brand Logo image or custom leading
            leading ??
                Image.asset(
                  'lib/assets/img.png',
                  height: 28,
                  fit: BoxFit.contain,
                ),
            const SizedBox(width: 12),
            // Title (if present)
            if (title != null && title!.isNotEmpty)
              Expanded(
                child: Text(
                  title!,
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        color: glass.textPrimary,
                      ),
                  overflow: TextOverflow.ellipsis,
                ),
              )
            else
              const Spacer(),
            // Actions
            if (actions != null) ...actions!,
            if (actions == null) ...[
              // Theme Toggle with Semantics
              Semantics(
                label: isDark ? "Switch to light mode" : "Switch to dark mode",
                button: true,
                child: IconButton(
                  onPressed: () => themeNotifier.toggleTheme(),
                  icon: Icon(
                    isDark ? Icons.wb_sunny_rounded : Icons.nightlight_round,
                    size: 22,
                    color: glass.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Profile Avatar / Icon
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
                    width: 40,
                    height: 40,
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
                      boxShadow: [
                        BoxShadow(
                          color: glass.avatarGradient.last.withOpacity(0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        initial,
                        style: const TextStyle(
                          fontSize: 16,
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
    );
  }
}
