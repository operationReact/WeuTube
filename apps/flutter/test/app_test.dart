import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weutube/main.dart';
import 'package:weutube/product_ui.dart' show WeuTubeBrand;

void main() {
  testWidgets('opens social Home directly with a populated feed', (tester) async {
    await tester.pumpWidget(const WeuTubeApp());
    expect(find.byType(WeuTubeBrand), findsOneWidget);
    expect(find.text('Discover creators'), findsOneWidget);
    expect(find.byTooltip('Search creators and videos'), findsOneWidget);
    expect(find.text('Your video'), findsNothing);
    expect(find.text('Latest'), findsOneWidget);
    expect(find.text('For you'), findsOneWidget);
    expect(find.text('Home'), findsWidgets);
    expect(find.text('Explore'), findsWidgets);
    expect(find.text('Shorts'), findsWidgets);
    expect(find.text('Create'), findsWidgets);
  });

  testWidgets('Explore has discovery without forcing login', (tester) async {
    await tester.pumpWidget(const WeuTubeApp());
    await tester.tap(find.text('Explore').first);
    await tester.pump();
    expect(find.text('People, passions and places worth finding.'), findsOneWidget);
    expect(find.text('Search creators, videos or topics'), findsOneWidget);
  });

  testWidgets('Sign-in is available when a person wants to create', (tester) async {
    await tester.pumpWidget(const WeuTubeApp());
    await tester.tap(find.text('Create').last);
    await tester.pump();
    expect(find.text('Create something great.'), findsOneWidget);
    await tester.ensureVisible(find.text('Sign in to upload'));
    await tester.pump();
    await tester.tap(find.text('Sign in to upload'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome Back'), findsOneWidget);
    expect(find.text('Email Address'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    await tester.tap(find.text('New to WeuTube? Create Account'));
    await tester.pumpAndSettle();
    expect(find.text('Full Name'), findsOneWidget);
  });
  testWidgets('Latest tab selects recent-first feed without duplicate search',
      (tester) async {
    await tester.pumpWidget(const WeuTubeApp());
    await tester.tap(find.text('Latest').first);
    await tester.pump();
    expect(find.text('Latest'), findsOneWidget);
    expect(find.byTooltip('Search creators and videos'), findsOneWidget);
  });

  testWidgets('Shorts has a dedicated immersive layout', (tester) async {
    await tester.pumpWidget(const WeuTubeApp());
    await tester.tap(find.text('Shorts').last);
    await tester.pump();
    expect(find.byType(WeuTubeBrand), findsNothing);
    expect(find.text('Shorts'), findsWidgets);
  });

  testWidgets('mobile auth uses one brand and compact accessible fields',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const WeuTubeApp());
    await tester.tap(find.text('Create').last);
    await tester.pump();
    await tester.ensureVisible(find.text('Sign in to upload'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign in to upload'));
    await tester.pumpAndSettle();
    expect(find.byType(WeuTubeBrand), findsOneWidget);
    expect(find.byTooltip('Sign in'), findsNothing);
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.byType(AutofillGroup), findsOneWidget);
    expect(find.text('Welcome Back'), findsOneWidget);
    await tester.ensureVisible(find.text('New to WeuTube? Create Account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New to WeuTube? Create Account'));
    await tester.pumpAndSettle();
    expect(find.byType(WeuTubeBrand), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(4));
    expect(find.text('Confirm Password'), findsOneWidget);
    expect(find.text('Use at least 12 characters for your password.'),
      findsOneWidget);
  });

  testWidgets('signup rejects mismatched passwords without API call',
      (tester) async {
    await tester.pumpWidget(const WeuTubeApp());
    await tester.tap(find.text('Create').last);
    await tester.pump();
    await tester.ensureVisible(find.text('Sign in to upload'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign in to upload'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New to WeuTube? Create Account'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('auth-full-name')),
      'Example Person');
    await tester.enterText(find.byKey(const ValueKey('auth-email-address')),
      'sample@example.com');
    await tester.enterText(find.byKey(const ValueKey('auth-password')),
      'long-example-password-123');
    await tester.enterText(find.byKey(const ValueKey('auth-confirm-password')),
      'long-example-password-456');
    final submit = find.widgetWithText(FilledButton, 'Create Account');
    await tester.ensureVisible(submit);
    await tester.pumpAndSettle();
    await tester.tap(submit);
    await tester.pump();
    expect(find.text('Passwords do not match'), findsOneWidget);
  });

}
