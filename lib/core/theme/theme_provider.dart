import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _themeKey = 'app_theme_mode';

/// Theme mode provider with persistence
final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    _loadTheme();
    return ThemeMode.dark; // Default to dark
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final themeName = prefs.getString(_themeKey);
    if (themeName != null) {
      state = ThemeMode.values.firstWhere(
        (e) => e.name == themeName,
        orElse: () => ThemeMode.dark,
      );
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, mode.name);
  }

  Future<void> toggleTheme() async {
    final newMode = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    await setThemeMode(newMode);
  }

  bool get isDarkMode => state == ThemeMode.dark;
}

/// App theme definitions
class AppTheme {
  static const darkBg = Color(0xFF141718);
  static const darkSurface = Color(0xFF1B1D1F);
  static const lightBg = Color(0xFFF5F5F7);
  static const lightSurface = Color(0xFFFFFFFF);
  static final _darkButtonScheme = ColorScheme.fromSeed(
    seedColor: Colors.deepPurple,
    brightness: Brightness.dark,
  );
  static final _darkElevatedStyle = ElevatedButton.styleFrom(
    backgroundColor: _darkButtonScheme.primary,
    foregroundColor: _darkButtonScheme.onPrimary,
    disabledBackgroundColor: _darkButtonScheme.primary.withValues(alpha: 0.4),
    disabledForegroundColor: _darkButtonScheme.onPrimary.withValues(alpha: 0.6),
  );
  static final _darkTextStyle = TextButton.styleFrom(
    foregroundColor: _darkButtonScheme.primary,
    disabledForegroundColor: _darkButtonScheme.primary.withValues(alpha: 0.4),
  );
  static final _darkOutlinedStyle = OutlinedButton.styleFrom(
    foregroundColor: _darkButtonScheme.primary,
    disabledForegroundColor: _darkButtonScheme.primary.withValues(alpha: 0.4),
    side: BorderSide(color: _darkButtonScheme.primary),
  );

  static ThemeData get darkTheme => ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        fontFamily: 'Aeonik',
        scaffoldBackgroundColor: darkBg,
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
        splashColor: Colors.transparent,
        hoverColor: Colors.transparent,
        appBarTheme: const AppBarTheme(
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          backgroundColor: Colors.transparent,
        ),
        cardColor: darkSurface,
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: darkSurface,
        ),
      );

  static ThemeData get lightTheme => ThemeData(
        brightness: Brightness.light,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.light,
        ),
        fontFamily: 'Aeonik',
        scaffoldBackgroundColor: lightBg,
        elevatedButtonTheme: ElevatedButtonThemeData(style: _darkElevatedStyle),
        textButtonTheme: TextButtonThemeData(style: _darkTextStyle),
        outlinedButtonTheme: OutlinedButtonThemeData(style: _darkOutlinedStyle),
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
        splashColor: Colors.transparent,
        hoverColor: Colors.transparent,
        appBarTheme: const AppBarTheme(
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.black87,
        ),
        cardColor: lightSurface,
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: lightSurface,
        ),
      );
}

/// Extension for easy theme-aware colors
extension ThemeColors on BuildContext {
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;

  Color get primaryTextColor => isDarkMode ? Colors.white : Colors.black87;
  Color get secondaryTextColor => isDarkMode ? Colors.white70 : Colors.black54;
  Color get tertiaryTextColor => isDarkMode ? Colors.white38 : Colors.black38;

  Color get surfaceColor => isDarkMode ? const Color(0xFF1B1D1F) : Colors.white;
  Color get backgroundColor =>
      isDarkMode ? const Color(0xFF141718) : const Color(0xFFF5F5F7);

  Color get cardBackground =>
      isDarkMode ? const Color(0xFF1F2223) : Colors.white;
  Color get inputBackground =>
      isDarkMode ? const Color(0xFF1F2223) : const Color(0xFFEEEEF0);

  Color get dividerColor =>
      isDarkMode ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.1);
}
