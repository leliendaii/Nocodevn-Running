import 'package:flutter_test/flutter_test.dart';
import 'package:running_tracker/main.dart';

void main() {
  testWidgets('App starts smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const RunningTrackerApp());
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('RUN TRACKER PRO'), findsWidgets);
  });
}
