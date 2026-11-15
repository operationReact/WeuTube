import 'package:flutter_test/flutter_test.dart';
import 'package:weutube/main.dart';

void main() {
  testWidgets('landing displays the creator-first brand and onboarding', (tester) async {
    await tester.pumpWidget(const WeuTubeApp());
    expect(find.text('Weu'), findsWidgets);
    expect(find.text('Tube'), findsWidgets);
    expect(find.text('Create Account'), findsWidgets);
    expect(find.text('Sign In'), findsWidgets);
    expect(find.text('How WeuTube Works'), findsOneWidget);
  });

  testWidgets('sign in routes into clearly labelled preview session', (tester) async {
    await tester.pumpWidget(const WeuTubeApp());
    await tester.tap(find.text('Sign In').first);
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.textContaining('UI preview only'), findsOneWidget);
  });
}
