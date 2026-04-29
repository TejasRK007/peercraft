import 'package:flutter_test/flutter_test.dart';
import 'package:peercraft/main.dart';

void main() {
  testWidgets('PeerCraft onboarding screen smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const PeerCraftApp());
    // Onboarding uses repeating animations, so `pumpAndSettle` may never
    // fully settle. Pump a fixed duration instead.
    await tester.pump(const Duration(seconds: 2));

    // Verify the app renders the onboarding headline and CTA
    expect(find.text('Get Started'), findsOneWidget);
    expect(find.text('PeerCraft'), findsOneWidget);
  });
}
