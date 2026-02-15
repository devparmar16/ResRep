import 'package:flutter_test/flutter_test.dart';
import 'package:scholar_lens_app/main.dart';

void main() {
  testWidgets('App renders ScholarLens title', (WidgetTester tester) async {
    await tester.pumpWidget(const ScholarLensApp());
    await tester.pump();

    // Verify the app title is rendered
    expect(find.text('Scholar'), findsWidgets);
  });
}
