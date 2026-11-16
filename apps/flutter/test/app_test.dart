import 'package:flutter_test/flutter_test.dart';
import 'package:weutube/main.dart';
import 'package:weutube/product_ui.dart' show WeuTubeBrand;

void main() {
  testWidgets('opens social Home directly with a populated feed', (tester) async {
    await tester.pumpWidget(const WeuTubeApp());
    expect(find.byType(WeuTubeBrand), findsOneWidget);
    expect(find.text('Find your next spark.'), findsOneWidget);
    expect(find.text('Fresh from the community'), findsOneWidget);
    expect(find.text('Home'), findsWidgets);
    expect(find.text('Explore'), findsWidgets);
    expect(find.text('Shorts'), findsWidgets);
    expect(find.text('Create'), findsWidgets);
  });

  testWidgets('Explore has discovery without forcing login', (tester) async {
    await tester.pumpWidget(const WeuTubeApp());
    await tester.tap(find.text('Explore').first);
    await tester.pump();
    expect(find.text('Explore your world'), findsOneWidget);
    expect(find.text('Trending discoveries'), findsOneWidget);
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
}
