import 'package:flutter_test/flutter_test.dart';
import 'package:heatbubble/app.dart';

void main() {
  testWidgets('HeatBubble app renders', (WidgetTester tester) async {
    await tester.pumpWidget(const HeatBubbleApp());
    // Basic smoke test — just ensure the widget tree builds
    expect(find.byType(HeatBubbleApp), findsOneWidget);
  });
}
