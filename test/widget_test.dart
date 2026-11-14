import 'package:flutter_test/flutter_test.dart';
import 'package:behavioral_monitor/main.dart';

void main() {
  testWidgets('App loads and displays consent screen when not consented', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const BehaviorMonitorApp(hasConsented: false));
    await tester.pumpAndSettle();

    // Verify that the Consent screen appears
    expect(find.text('Data Privacy & Consent'), findsOneWidget);
    expect(find.text('I Agree'), findsOneWidget);
  });
}
