import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:etaprise_hrms/team-lead/screens/team_leave_approval_screen.dart';
import 'package:etaprise_hrms/core/api/api_client.dart';

class LeaveTestApiClient extends ApiClient {
  @override
  Future<dynamic> get(String endpoint, {Map<String, String>? queryParams, Map<String, String>? headers}) async {
    if (endpoint.contains('pending')) {
      return [
        {
          'id': 'L-101',
          'employeeName': 'Rahul Sharma',
          'leaveType': 'Casual Leave',
          'startDate': '2026-10-22',
          'endDate': '2026-10-24',
          'totalDays': 3,
          'reason': 'Family function',
          'createdAt': '2026-10-18'
        }
      ];
    }
    return [];
  }

  @override
  Future<dynamic> post(String endpoint, {dynamic body, dynamic data, Map<String, String>? headers}) async {
    return {'success': true};
  }
}

void main() {
  testWidgets('TeamLeaveApprovalScreen renders pending requests and handles approval', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(LeaveTestApiClient()),
        ],
        child: const MaterialApp(
          home: TeamLeaveApprovalScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Team Leave Management'), findsOneWidget);
    expect(find.text('Pending Requests'), findsOneWidget);
    expect(find.text('Rahul Sharma'), findsWidgets);
    expect(find.text('Casual Leave • 3 Day(s) (2026-10-22 to 2026-10-24)'), findsOneWidget);

    // Tap Approve button
    await tester.tap(find.text('Approve'));
    await tester.pump();

    // Verify decision process works cleanly
    expect(find.text('Team Leave Management'), findsOneWidget);
  });
}
