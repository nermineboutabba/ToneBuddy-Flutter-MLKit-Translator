import 'package:flutter_test/flutter_test.dart';
import 'package:tone_buddy/main.dart';

void main() {
  testWidgets('ToneBuddy renders splash then home screen controls', (WidgetTester tester) async {
    await tester.pumpWidget(const ToneBuddyApp());
    expect(find.text('On-Device Smart Reply & Translation'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(find.text('ToneBuddy'), findsOneWidget);
    expect(find.text('Generate Smart Reply'), findsOneWidget);
    expect(find.text('Language'), findsOneWidget);
    expect(find.text('Tone Context'), findsOneWidget);
  });
}
