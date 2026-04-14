import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _themeKey = 'app_theme_mode';
const _fullButtonShape = StadiumBorder();

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
  static ColorScheme _buttonSchemeFor(Brightness brightness) {
    return ColorScheme.fromSeed(
      seedColor: Colors.deepPurple,
      brightness: brightness,
    );
  }

  static ButtonStyle _elevatedStyleFor(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final background = isDark ? Colors.white : Colors.black;
    final foreground = isDark ? Colors.black : Colors.white;

    return ElevatedButton.styleFrom(
      backgroundColor: background,
      foregroundColor: foreground,
      disabledBackgroundColor: background.withValues(alpha: 0.4),
      disabledForegroundColor: foreground.withValues(alpha: 0.6),
      shape: _fullButtonShape,
    );
  }

  static ButtonStyle _filledStyleFor(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final background = isDark ? Colors.white : Colors.black;
    final foreground = isDark ? Colors.black : Colors.white;

    return FilledButton.styleFrom(
      backgroundColor: background,
      foregroundColor: foreground,
      disabledBackgroundColor: background.withValues(alpha: 0.4),
      disabledForegroundColor: foreground.withValues(alpha: 0.6),
      shape: _fullButtonShape,
    );
  }

  static ButtonStyle _textStyleFor(Brightness brightness) {
    final buttonScheme = _buttonSchemeFor(brightness);
    return TextButton.styleFrom(
      foregroundColor: buttonScheme.primary,
      disabledForegroundColor: buttonScheme.primary.withValues(alpha: 0.4),
      shape: _fullButtonShape,
    );
  }

  static ButtonStyle _outlinedStyleFor(Brightness brightness) {
    final buttonScheme = _buttonSchemeFor(brightness);
    return OutlinedButton.styleFrom(
      foregroundColor: buttonScheme.primary,
      disabledForegroundColor: buttonScheme.primary.withValues(alpha: 0.4),
      side: BorderSide(color: buttonScheme.primary),
      shape: _fullButtonShape,
    );
  }

  static ThemeData get darkTheme => ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.deepPurple,
      brightness: Brightness.dark,
    ),
    fontFamily: 'Aeonik',
    scaffoldBackgroundColor: darkBg,
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: _elevatedStyleFor(Brightness.dark),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: _filledStyleFor(Brightness.dark),
    ),
    textButtonTheme: TextButtonThemeData(style: _textStyleFor(Brightness.dark)),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: _outlinedStyleFor(Brightness.dark),
    ),
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
    bottomSheetTheme: const BottomSheetThemeData(backgroundColor: darkSurface),
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
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: _elevatedStyleFor(Brightness.light),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: _filledStyleFor(Brightness.light),
    ),
    textButtonTheme: TextButtonThemeData(
      style: _textStyleFor(Brightness.light),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: _outlinedStyleFor(Brightness.light),
    ),
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
    bottomSheetTheme: const BottomSheetThemeData(backgroundColor: lightSurface),
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
  Color get actionButtonBackground => isDarkMode ? Colors.white : Colors.black;
  Color get actionButtonForeground => isDarkMode ? Colors.black : Colors.white;

  Color get dividerColor => isDarkMode
      ? Colors.white.withValues(alpha: 0.1)
      : Colors.black.withValues(alpha: 0.1);
}
