import 'package:flutter/material.dart';
import '../../admin/screens/admin_expense_invoices_screen.dart';

/// HR Expense Invoices Screen delegating to [AdminExpenseInvoicesScreen] for complete feature parity with Angular.
class HrExpenseInvoicesScreen extends StatelessWidget {
  final bool showAppBar;
  const HrExpenseInvoicesScreen({super.key, this.showAppBar = true});

  @override
  Widget build(BuildContext context) {
    return const AdminExpenseInvoicesScreen();
  }
}
