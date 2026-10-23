import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_background.dart';
import 'glass_bottom_tab_bar.dart';

class GlassScaffold extends StatelessWidget {
  final PreferredSizeWidget? appBar;
  final Widget body;
  final List<GlassTab>? tabs;
  final bool showBottomBar;
  final Widget? floatingActionButton;
  final Widget? bottomSheet;
  final Color? backgroundColor;

  const GlassScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.tabs,
    this.showBottomBar = false,
    this.floatingActionButton,
    this.bottomSheet,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.paddingOf(context).top;
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarContrastEnforced: false,
      ),
    );

    return Scaffold(
      backgroundColor: backgroundColor ?? Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned.fill(
            child: AppBackground(child: SizedBox.expand()),
          ),
          Positioned.fill(
            child: Column(
              children: [
                if (appBar != null)
                  Padding(
                    padding: EdgeInsets.only(top: topPadding + 4),
                    child: appBar,
                  ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      bottom: (showBottomBar && tabs != null) ? (85.0 + bottomPadding) : 0.0,
                    ),
                    child: body,
                  ),
                ),
              ],
            ),
          ),
          if (showBottomBar && tabs != null) GlassBottomTabBar(tabs: tabs!),
        ],
      ),
      floatingActionButton: floatingActionButton,
      bottomSheet: bottomSheet,
    );
  }
}
