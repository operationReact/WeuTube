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
    await tester.tap(find.text('New creator? Create Account'));
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

}
