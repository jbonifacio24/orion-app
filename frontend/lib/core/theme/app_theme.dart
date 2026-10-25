import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract final class AppTheme {
  static const _themeModeKey = 'motohub.theme_mode';
  static final ValueNotifier<ThemeMode> themeMode = ValueNotifier(ThemeMode.light);

  static const _racingRed = Color(0xFFB53D32);
  static const _racingRedDark = Color(0xFFFF806D);
  static const _graphite = Color(0xFF1A2022);
  static const _steel = Color(0xFF50616A);
  static const _steelDark = Color(0xFFAFBDC2);
  static const _brass = Color(0xFF9A6A24);
  static const _brassDark = Color(0xFFE2B866);
  static const _lightBackground = Color(0xFFF3F2ED);
  static const _darkBackground = Color(0xFF111719);
  static const _darkSurface = Color(0xFF20282A);

  static Future<void> restoreThemeMode() async {
    final preferences = await SharedPreferences.getInstance();
    themeMode.value = switch (preferences.getString(_themeModeKey)) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.light,
    };
  }

  static Future<void> setThemeMode(ThemeMode mode) async {
    themeMode.value = mode;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_themeModeKey, mode.name);
  }

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: _racingRed, brightness: Brightness.light).copyWith(
          primary: _racingRed,
          onPrimary: Colors.white,
          secondary: _steel,
          onSecondary: Colors.white,
          tertiary: _brass,
          onTertiary: Colors.white,
          surface: Colors.white,
          onSurface: _graphite,
          surfaceContainerHighest: const Color(0xFFE7E7E2),
        ),
        scaffoldBackgroundColor: _lightBackground,
        appBarTheme: const AppBarTheme(backgroundColor: _graphite, foregroundColor: Colors.white, centerTitle: false),
        inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder(), focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: _racingRed, width: 2))),
        splashFactory: InkRipple.splashFactory,
        filledButtonTheme: FilledButtonThemeData(style: _filledButtonStyle(background: _racingRed, foreground: Colors.white)),
        outlinedButtonTheme: OutlinedButtonThemeData(style: _outlinedButtonStyle(_racingRed)),
        textButtonTheme: TextButtonThemeData(style: _textButtonStyle(_racingRed)),
        iconButtonTheme: IconButtonThemeData(style: _iconButtonStyle(_racingRed)),
        floatingActionButtonTheme: FloatingActionButtonThemeData(backgroundColor: _racingRed, foregroundColor: Colors.white, elevation: 4, highlightElevation: 9, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
        cardTheme: CardThemeData(color: Colors.white, elevation: 1, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
        brightness: Brightness.light,
      );

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _racingRedDark,
          brightness: Brightness.dark,
        ).copyWith(
          primary: _racingRedDark,
          onPrimary: const Color(0xFF35130F),
          secondary: _steelDark,
          onSecondary: const Color(0xFF172024),
          tertiary: _brassDark,
          onTertiary: const Color(0xFF2D2110),
          surface: _darkSurface,
          onSurface: const Color(0xFFE7E7E1),
          surfaceContainerHighest: const Color(0xFF303A3C),
        ),
        scaffoldBackgroundColor: _darkBackground,
        appBarTheme: const AppBarTheme(backgroundColor: _graphite, foregroundColor: Colors.white, centerTitle: false),
        inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder(), focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: _racingRedDark, width: 2))),
        splashFactory: InkRipple.splashFactory,
        filledButtonTheme: FilledButtonThemeData(style: _filledButtonStyle(background: _racingRedDark, foreground: const Color(0xFF35130F))),
        outlinedButtonTheme: OutlinedButtonThemeData(style: _outlinedButtonStyle(_racingRedDark)),
        textButtonTheme: TextButtonThemeData(style: _textButtonStyle(_racingRedDark)),
        iconButtonTheme: IconButtonThemeData(style: _iconButtonStyle(_racingRedDark)),
        floatingActionButtonTheme: FloatingActionButtonThemeData(backgroundColor: _racingRedDark, foregroundColor: const Color(0xFF35130F), elevation: 4, highlightElevation: 9, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
        cardTheme: CardThemeData(color: _darkSurface, elevation: 1, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
        brightness: Brightness.dark,
      );

  static ButtonStyle _filledButtonStyle({required Color background, required Color foreground}) => ButtonStyle(
        animationDuration: const Duration(milliseconds: 220),
        backgroundColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.disabled) ? background.withValues(alpha: 0.35) : states.contains(WidgetState.pressed) ? Color.lerp(background, Colors.black, 0.12) : states.contains(WidgetState.hovered) ? Color.lerp(background, Colors.white, 0.08) : background),
        foregroundColor: WidgetStatePropertyAll(foreground),
        overlayColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.pressed) ? foreground.withValues(alpha: 0.16) : states.contains(WidgetState.hovered) ? foreground.withValues(alpha: 0.08) : null),
        elevation: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.pressed) ? 1 : states.contains(WidgetState.hovered) ? 7 : 3),
        shadowColor: WidgetStatePropertyAll(background.withValues(alpha: 0.35)),
        shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
        padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 20, vertical: 14)),
      );

  static ButtonStyle _outlinedButtonStyle(Color color) => ButtonStyle(
        animationDuration: const Duration(milliseconds: 220),
        foregroundColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.disabled) ? color.withValues(alpha: 0.4) : color),
        overlayColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.pressed) ? color.withValues(alpha: 0.16) : states.contains(WidgetState.hovered) ? color.withValues(alpha: 0.08) : null),
        side: WidgetStateProperty.resolveWith((states) => BorderSide(color: color.withValues(alpha: states.contains(WidgetState.pressed) || states.contains(WidgetState.hovered) ? 1 : 0.7), width: states.contains(WidgetState.pressed) ? 2 : 1)),
        shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
        padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 20, vertical: 14)),
      );

  static ButtonStyle _textButtonStyle(Color color) => ButtonStyle(
        animationDuration: const Duration(milliseconds: 220),
        foregroundColor: WidgetStatePropertyAll(color),
        overlayColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.pressed) ? color.withValues(alpha: 0.16) : states.contains(WidgetState.hovered) ? color.withValues(alpha: 0.08) : null),
        shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
        padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 14, vertical: 10)),
      );

  static ButtonStyle _iconButtonStyle(Color color) => IconButton.styleFrom(
        foregroundColor: color,
        hoverColor: color.withValues(alpha: 0.12),
        highlightColor: color.withValues(alpha: 0.2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        animationDuration: const Duration(milliseconds: 220),
      );
}
