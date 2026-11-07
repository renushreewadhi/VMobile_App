import 'package:flutter/material.dart';
import '../../admin/screens/admin_documents_screen.dart';

/// HR Documents Screen delegating to [AdminDocumentsScreen] for complete feature parity with Angular.
class HrDocumentsScreen extends StatelessWidget {
  final bool showAppBar;
  const HrDocumentsScreen({super.key, this.showAppBar = true});

  @override
  Widget build(BuildContext context) {
    return AdminDocumentsScreen(showAppBar: showAppBar);
  }
}
