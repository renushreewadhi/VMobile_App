import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:etaprise_hrms/team_lead/screens/tl_dashboard_screen.dart';
import 'package:etaprise_hrms/core/api/api_client.dart';

class TestApiClient extends ApiClient {
  @override
  Future<dynamic> get(String endpoint, {Map<String, String>? queryParams, Map<String, String>? headers}) async {
    if (endpoint.contains('attendance')) {
      return [
        {'id': '1', 'name': 'Rahul Sharma', 'status': 'PRESENT'},
        {'id': '2', 'name': 'Priya Verma', 'status': 'PRESENT'},
      ];
    }
    if (endpoint.contains('leave')) {
      return [
        {'id': 'L-1', 'employeeName': 'Rahul Sharma', 'status': 'PENDING'},
      ];
    }
    return [];
  }
}

void main() {
  testWidgets('TlDashboardScreen renders correctly and shows team stats', (WidgetTester tester) async {
    int navigatedTab = -1;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(TestApiClient()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: TlDashboardScreen(
              onNavigateTab: (idx) => navigatedTab = idx,
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Team Lead Portal'), findsOneWidget);
    expect(find.text('2 Team Members'), findsOneWidget);
    expect(find.text('1 Approvals Pending'), findsOneWidget);
    expect(find.text('Quick Lead Actions'), findsOneWidget);
    expect(find.text('Team Projects & Member Assignment'), findsOneWidget);
    expect(find.text('Team Analytics & Reports'), findsOneWidget);

    // Tap on Pastel Pill to trigger tab navigation callback
    await tester.tap(find.text('2 Team Members'));
    await tester.pump();

    expect(navigatedTab, equals(1));
  });
}
