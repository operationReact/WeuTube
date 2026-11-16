import 'package:flutter_test/flutter_test.dart';
import 'package:weutube/main.dart';
import 'package:weutube/product_ui.dart' show WeuTubeBrand, WeuTubeBrandIcon;

void main() {
  testWidgets('landing displays WeuTube brand and onboarding', (tester) async {
    await tester.pumpWidget(const WeuTubeApp());
    // The approved master artwork is one vector, never separately typeset text.
    expect(find.byType(WeuTubeBrand), findsWidgets);
    expect(find.byType(WeuTubeBrandIcon), findsNothing);
    expect(find.text('Create Account'), findsWidgets);
    expect(find.text('Sign In'), findsWidgets);
    expect(find.text('Built for creators'), findsOneWidget);
  });

  testWidgets('sign in opens real authentication form', (tester) async {
    await tester.pumpWidget(const WeuTubeApp());
    await tester.tap(find.text('Sign In').first);
    await tester.pumpAndSettle();
    expect(find.text('Welcome Back'), findsOneWidget);
    expect(find.text('Email Address'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
  });

  testWidgets('create account has name email and password', (tester) async {
    await tester.pumpWidget(const WeuTubeApp());
    await tester.tap(find.text('Create Account').first);
    await tester.pumpAndSettle();
    expect(find.text('Full Name'), findsOneWidget);
    expect(find.text('Email Address'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
  });
}
