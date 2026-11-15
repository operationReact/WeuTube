import 'package:flutter_test/flutter_test.dart';
import 'package:weutube/main.dart';
void main() {
 testWidgets('welcome actions render', (tester) async {
  await tester.pumpWidget(const WeuTubeApp());
  expect(find.text('Sign In'), findsWidgets);
  expect(find.text('Create Account'), findsOneWidget);
 });
}
