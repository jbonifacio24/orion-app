import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const _orange = Color(0xFFE9682B);
  static const _charcoal = Color(0xFF171717);

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: _orange, brightness: Brightness.light),
        scaffoldBackgroundColor: const Color(0xFFF7F7F5),
        inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(backgroundColor: _orange, foregroundColor: Colors.white),
        ),
        brightness: Brightness.light,
      );

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _orange,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: _charcoal,
        inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
        brightness: Brightness.dark,
      );
}
