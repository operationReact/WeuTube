import 'package:flutter_test/flutter_test.dart';
import 'package:weutube/main.dart';

void main() {
  testWidgets('landing displays WeuTube brand and onboarding', (tester) async {
    await tester.pumpWidget(const WeuTubeApp());
    expect(find.text('Weu'), findsWidgets);
    expect(find.text('Tube'), findsWidgets);
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
