import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weutube/main.dart';

void main() {
  testWidgets('shows sign in entry', (tester) async {
    await tester.pumpWidget(const WeuTubeApp());
    expect(find.text('WeuTube'), findsOneWidget);
    expect(find.text('Sign In'), findsWidgets);
  });
}
