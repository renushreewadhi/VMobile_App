import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:etaprise_hrms/team-lead/screens/my_team_screen.dart';
import 'package:etaprise_hrms/core/api/api_client.dart';

class TeamTestApiClient extends ApiClient {
  @override
  Future<dynamic> get(String endpoint, {Map<String, String>? queryParams, Map<String, String>? headers}) async {
    if (endpoint.contains('employees')) {
      return [
        {
          'id': 'EMP-001',
          'employeeId': 'EMP-001',
          'firstName': 'Rahul',
          'lastName': 'Sharma',
          'designation': 'Senior Engineer',
          'department': 'Engineering',
          'email': 'rahul@company.com',
          'phone': '+91 9876543210',
          'employmentStatus': 'ACTIVE',
          'tasksCount': 3
        },
        {
          'id': 'EMP-002',
          'employeeId': 'EMP-002',
          'firstName': 'Amit',
          'lastName': 'Kumar',
          'designation': 'Backend Dev',
          'department': 'Engineering',
          'email': 'amit@company.com',
          'phone': '+91 9876543212',
          'employmentStatus': 'ON_LEAVE',
          'tasksCount': 1
        }
      ];
    }
    return [];
  }
}

void main() {
  testWidgets('MyTeamScreen renders members, filters, and opens profile modal', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(TeamTestApiClient()),
        ],
        child: const MaterialApp(
          home: MyTeamScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('My Direct Team Members'), findsOneWidget);
    expect(find.text('Rahul Sharma'), findsOneWidget);
    expect(find.text('Amit Kumar'), findsOneWidget);

    // Filter by ON_LEAVE chip
    await tester.tap(find.text('On Leave (1)'));
    await tester.pumpAndSettle();

    expect(find.text('Amit Kumar'), findsOneWidget);
    expect(find.text('Rahul Sharma'), findsNothing);

    // Reset filter to ALL
    await tester.tap(find.text('All (2)'));
    await tester.pumpAndSettle();

    // Open Profile Modal for Rahul Sharma
    await tester.tap(find.text('Profile').first);
    await tester.pumpAndSettle();

    expect(find.text('CONTACT & EMPLOYMENT DETAILS'), findsOneWidget);
    expect(find.text('Assign Task To Member'), findsOneWidget);
  });
}
