import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:etaprise_hrms/core/theme/app_theme.dart';
import 'package:etaprise_hrms/core/widgets/glass_header.dart';
import 'package:etaprise_hrms/core/widgets/glass_search_bar.dart';
import 'package:etaprise_hrms/core/widgets/module_card.dart';
import 'package:etaprise_hrms/core/widgets/status_badge.dart';

void main() {
  testWidgets('Glass components golden preview test - Light Theme', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: ListView(
              children: [
                const GlassHeader(title: "Golden Test Header", userInitial: "E"),
                const GlassSearchBar(placeholder: "Search test..."),
                const StatusBadge(label: "ACTIVE", status: StatusType.success),
                ModuleCard(
                  icon: Icons.calendar_today_rounded,
                  gradientColors: const [Color(0xFF34D399), Color(0xFF059669)],
                  title: "Attendance & Time",
                  subtitle: "Check In/Out, Timesheets",
                  count: 4,
                  onPress: () {},
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text("Golden Test Header"), findsOneWidget);
    expect(find.text("Attendance & Time"), findsOneWidget);
  });

  testWidgets('Glass components golden preview test - Dark Theme', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: ListView(
              children: [
                const GlassHeader(title: "Golden Test Header", userInitial: "E"),
                const GlassSearchBar(placeholder: "Search test..."),
                const StatusBadge(label: "PENDING", status: StatusType.pending),
                ModuleCard(
                  icon: Icons.account_balance_wallet_outlined,
                  gradientColors: const [Color(0xFF818CF8), Color(0xFF4F46E5)],
                  title: "Finance",
                  subtitle: "Payslips, Expenses",
                  count: 4,
                  onPress: () {},
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text("Golden Test Header"), findsOneWidget);
    expect(find.text("Finance"), findsOneWidget);
  });
}
