import 'package:flutter/material.dart';
import 'app_background.dart';
import 'glass_bottom_tab_bar.dart';

class GlassScaffold extends StatelessWidget {
  final PreferredSizeWidget? appBar;
  final Widget body;
  final List<GlassTab>? tabs;
  final Widget? floatingActionButton;
  final Color? backgroundColor;

  const GlassScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.tabs,
    this.floatingActionButton,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor ?? Colors.transparent,
      appBar: appBar,
      body: AppBackground(
        child: Stack(
          children: [
            Padding(
              padding: EdgeInsets.only(bottom: tabs != null ? 85.0 : 0.0),
              child: body,
            ),
            if (tabs != null) GlassBottomTabBar(tabs: tabs!),
          ],
        ),
      ),
      floatingActionButton: floatingActionButton,
    );
  }
}
