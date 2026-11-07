import 'package:flutter/material.dart';
import '../../admin/screens/admin_announcements_screen.dart';

/// HR Announcements Screen delegating to [AdminAnnouncementsScreen] for complete feature parity with Angular.
class HrAnnouncementsScreen extends StatelessWidget {
  final bool showAppBar;
  const HrAnnouncementsScreen({super.key, this.showAppBar = true});

  @override
  Widget build(BuildContext context) {
    return AdminAnnouncementsScreen(showAppBar: showAppBar);
  }
}
