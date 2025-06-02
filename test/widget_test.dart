import 'package:flutter_test/flutter_test.dart';

import 'package:medilog/main.dart';

void main() {
  testWidgets('Medilog app launches', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MedilogApp());

    // Verify that our app starts with the title "Medilog"
    expect(find.text('Medilog'), findsWidgets);
  });
}
