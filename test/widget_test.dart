// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:bite_and_burp_web/main.dart'; // Tera main app import ho raha hai

void main() {
  testWidgets('App loads smoke test', (WidgetTester tester) async {
    // 🌟 NAYA: Yahan 'MyApp' ki jagah tera asli 'BiteAndBurpWebApp' daal diya
    await tester.pumpWidget(const BiteAndBurpWebApp());

    // 🌟 NAYA: Counter check hatake, sirf ye check kar rahe hain ki app bina crash hue load ho rahi hai ya nahi
    expect(find.byType(BiteAndBurpWebApp), findsOneWidget);
  });
}
