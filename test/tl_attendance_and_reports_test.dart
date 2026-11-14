import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:etaprise_hrms/team_lead/screens/tl_reports_screen.dart';
import 'package:etaprise_hrms/core/api/api_client.dart';

class ReportTestApiClient extends ApiClient {
  @override
  Future<dynamic> get(String endpoint, {Map<String, String>? queryParams, Map<String, String>? headers}) async {
    if (endpoint.contains('attendance')) {
      return [{'id': '1', 'name': 'Rahul', 'status': 'PRESENT'}];
    }
    if (endpoint.contains('tasks')) {
      return [{'title': 'Task 1', 'status': 'COMPLETED'}];
    }
    if (endpoint.contains('employees')) {
      return [{'firstName': 'Rahul', 'lastName': 'Sharma', 'designation': 'Senior Engineer'}];
    }
    return [];
  }
}

void main() {
  testWidgets('TlReportsScreen renders analytics metrics and export buttons', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(ReportTestApiClient()),
        ],
        child: const MaterialApp(
          home: TlReportsScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Team Analytics'), findsWidgets);
    expect(find.text('Avg Attendance'), findsOneWidget);
    expect(find.text('Task Completion'), findsOneWidget);
    expect(find.text('Export Excel'), findsOneWidget);
    expect(find.text('Export PDF'), findsOneWidget);
  });
}
