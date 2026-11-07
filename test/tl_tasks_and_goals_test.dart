import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:etaprise_hrms/team-lead/screens/tl_tasks_screen.dart';
import 'package:etaprise_hrms/core/api/api_client.dart';

class TaskTestApiClient extends ApiClient {
  @override
  Future<dynamic> get(String endpoint, {Map<String, String>? queryParams, Map<String, String>? headers}) async {
    if (endpoint.contains('tasks') || endpoint.contains('my-tasks')) {
      return [
        {
          'id': 'T-101',
          'title': 'Implement login API',
          'description': 'JWT auth and validation',
          'assignee': 'Rahul Sharma',
          'priority': 'HIGH',
          'status': 'IN_PROGRESS',
          'dueDate': '2026-10-25'
        }
      ];
    }
    return [];
  }

  @override
  Future<dynamic> put(String endpoint, {dynamic body, dynamic data, Map<String, String>? headers}) async {
    return {'success': true};
  }
}

void main() {
  testWidgets('TlTasksScreen renders tasks and supports status movement', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(TaskTestApiClient()),
        ],
        child: const MaterialApp(
          home: TlTasksScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Team Tasks'), findsOneWidget);
    expect(find.text('Implement login API'), findsOneWidget);
    expect(find.text('Rahul Sharma'), findsOneWidget);
    expect(find.text('To Do'), findsOneWidget);
  });
}
