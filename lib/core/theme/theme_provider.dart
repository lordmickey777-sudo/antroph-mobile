import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _fullButtonShape = StadiumBorder();

/// App theme definitions
class AppTheme {
  static const darkBg = Color(0xFF141718);
  static const darkSurface = Color(0xFF1B1D1F);

  static ButtonStyle _elevatedStyle() {
    return ElevatedButton.styleFrom(
      backgroundColor: Colors.white,
      foregroundColor: Colors.black,
      disabledBackgroundColor: Colors.white.withValues(alpha: 0.4),
      disabledForegroundColor: Colors.black.withValues(alpha: 0.6),
      shape: _fullButtonShape,
    );
  }

  static ButtonStyle _filledStyle() {
    return FilledButton.styleFrom(
      backgroundColor: Colors.white,
      foregroundColor: Colors.black,
      disabledBackgroundColor: Colors.white.withValues(alpha: 0.4),
      disabledForegroundColor: Colors.black.withValues(alpha: 0.6),
      shape: _fullButtonShape,
    );
  }

  static ButtonStyle _textStyle() {
    final buttonScheme = ColorScheme.fromSeed(
      seedColor: Colors.deepPurple,
      brightness: Brightness.dark,
    );
    return TextButton.styleFrom(
      foregroundColor: buttonScheme.primary,
      disabledForegroundColor: buttonScheme.primary.withValues(alpha: 0.4),
      shape: _fullButtonShape,
    );
  }

  static ButtonStyle _outlinedStyle() {
    final buttonScheme = ColorScheme.fromSeed(
      seedColor: Colors.deepPurple,
      brightness: Brightness.dark,
    );
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
    elevatedButtonTheme: ElevatedButtonThemeData(style: _elevatedStyle()),
    filledButtonTheme: FilledButtonThemeData(style: _filledStyle()),
    textButtonTheme: TextButtonThemeData(style: _textStyle()),
    outlinedButtonTheme: OutlinedButtonThemeData(style: _outlinedStyle()),
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
}

/// Extension for theme-aware colors (always dark)
extension ThemeColors on BuildContext {
  bool get isDarkMode => true;

  Color get primaryTextColor => Colors.white;
  Color get secondaryTextColor => Colors.white70;
  Color get tertiaryTextColor => Colors.white38;

  Color get surfaceColor => const Color(0xFF1B1D1F);
  Color get backgroundColor => const Color(0xFF141718);

  Color get cardBackground => const Color(0xFF1F2223);
  Color get inputBackground => const Color(0xFF1F2223);
  Color get actionButtonBackground => Colors.white;
  Color get actionButtonForeground => Colors.black;

  Color get dividerColor => Colors.white.withValues(alpha: 0.1);
}
