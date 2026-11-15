import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weutube/main.dart';

void main() {
  testWidgets('shows welcome sign in and registration actions', (tester) async {
    await tester.pumpWidget(const WeuTubeApp());
    expect(find.text('Sign In'), findsWidgets);
    expect(find.text('Create Account'), findsOneWidget);
  });
}
