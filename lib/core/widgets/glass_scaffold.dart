import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_background.dart';
import 'glass_bottom_tab_bar.dart';
import 'glass_header.dart';

class GlassScaffold extends StatelessWidget {
  final String? title;
  final PreferredSizeWidget? appBar;
  final Widget body;
  final List<GlassTab>? tabs;
  final bool showBottomBar;
  final Widget? floatingActionButton;
  final Widget? bottomSheet;
  final Color? backgroundColor;

  const GlassScaffold({
    super.key,
    this.title,
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

    final effectiveAppBar = appBar ?? GlassHeader(title: title);

    return Scaffold(
      backgroundColor: backgroundColor ?? Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned.fill(
            child: AppBackground(child: SizedBox.expand()),
          ),
          Column(
            children: [
              effectiveAppBar,
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom: (showBottomBar && tabs != null) ? (85.0 + bottomPadding) : 0.0,
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: body,
                  ),
                ),
              ),
            ],
          ),
          if (showBottomBar && tabs != null) GlassBottomTabBar(tabs: tabs!),
        ],
      ),
      floatingActionButton: floatingActionButton,
      bottomSheet: bottomSheet,
    );
  }
}
