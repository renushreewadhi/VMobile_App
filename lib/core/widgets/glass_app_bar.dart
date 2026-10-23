import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/glass_theme.dart';
import '../theme/theme_provider.dart';
import 'glass_card.dart';

class GlassAppBar extends ConsumerWidget implements PreferredSizeWidget {
  final Widget? title;
  final Widget? leading;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  final bool centerTitle;
  final bool automaticallyImplyLeading;
  final VoidCallback? onBackPressed;

  const GlassAppBar({
    super.key,
    this.title,
    this.leading,
    this.actions,
    this.bottom,
    this.centerTitle = false,
    this.automaticallyImplyLeading = true,
    this.onBackPressed,
  });

  @override
  Size get preferredSize => Size.fromHeight(70.0 + (bottom?.preferredSize.height ?? 0.0));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final glass = context.glass;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeNotifier = ref.read(themeProvider.notifier);
    final ModalRoute<dynamic>? parentRoute = ModalRoute.of(context);
    final bool canPop = parentRoute?.canPop ?? false;

    Widget? leadingWidget = leading;
    if (leadingWidget == null && automaticallyImplyLeading && canPop) {
      leadingWidget = Semantics(
        label: "Go back",
        button: true,
        child: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: glass.textPrimary),
          onPressed: onBackPressed ?? () => Navigator.of(context).maybePop(),
        ),
      );
    }

    return RepaintBoundary(
      child: GlassSurface(
        blur: true,
        radius: glass.headerRadius,
        fillColor: glass.headerFill,
        borderColor: glass.headerBorder,
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                if (leadingWidget != null) leadingWidget,
                if (leadingWidget != null) const SizedBox(width: 4),
                Expanded(
                  child: Align(
                    alignment: centerTitle ? Alignment.center : Alignment.centerLeft,
                    child: title ?? const SizedBox.shrink(),
                  ),
                ),
                if (actions != null) ...actions!,
                if (actions == null)
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
              ],
            ),
            if (bottom != null) bottom!,
          ],
        ),
      ),
    );
  }
}
