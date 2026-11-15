import 'package:flutter/material.dart';
import 'product_ui.dart';

void main() => runApp(const WeuTubeApp());

class WeuTubeApp extends StatelessWidget {
  const WeuTubeApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'WeuTube',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: soft,
      colorScheme: ColorScheme.fromSeed(
        seedColor: navy, primary: navy, secondary: coral),
      fontFamily: 'Roboto',
      textTheme: const TextTheme(
        bodyMedium: TextStyle(color: navy),
        bodyLarge: TextStyle(color: navy)),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)))),
      inputDecorationTheme: InputDecorationTheme(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12))),
    ),
    home: const WeuTubeProduct(),
  );
}
