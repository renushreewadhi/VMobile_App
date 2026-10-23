import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:etaprise_hrms/app.dart';

void main() {
  testWidgets('Etaprise HRMS App Smoke Test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: EtapriseHrmsApp(),
      ),
    );

    expect(find.text('Initializing Etaprise HRMS...'), findsOneWidget);
  });
}
