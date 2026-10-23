import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/glass_theme.dart';
import '../theme/theme_provider.dart';
import 'glass_card.dart';

class GlassHeader extends ConsumerWidget implements PreferredSizeWidget {
  final String title;
  final Widget? leading;
  final List<Widget>? actions;
  final String? userInitial;
  final VoidCallback? onAvatarTap;

  const GlassHeader({
    super.key,
    required this.title,
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
            // Leading icon tile
            leading ??
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: glass.headerIconTileFill,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.dashboard_outlined,
                      size: 22,
                      color: glass.headerIconColor,
                    ),
                  ),
                ),
            const SizedBox(width: 12),
            // Title
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      color: glass.textPrimary,
                    ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
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
              // Avatar
              GestureDetector(
                onTap: onAvatarTap,
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
                      userInitial ?? 'U',
                      style: const TextStyle(
                        fontSize: 16,
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
      ),
    );
  }
}
