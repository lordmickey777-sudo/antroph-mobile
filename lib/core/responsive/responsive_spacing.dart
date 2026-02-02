import 'responsive_utils.dart';

/// Standard responsive padding values
class AppPadding {
  AppPadding._();

  /// Horizontal page padding: 16 -> 32 -> 40
  static const horizontal = ResponsiveValue<double>(
    phone: 16.0,
    tablet: 32.0,
    largeTablet: 40.0,
  );

  /// Form/auth page padding: 24 -> 32 -> 40
  static const form = ResponsiveValue<double>(
    phone: 24.0,
    tablet: 32.0,
    largeTablet: 40.0,
  );

  /// Card internal padding: 16 -> 20 -> 24
  static const card = ResponsiveValue<double>(
    phone: 16.0,
    tablet: 20.0,
    largeTablet: 24.0,
  );

  /// Small spacing: 12 -> 14 -> 16
  static const small = ResponsiveValue<double>(
    phone: 12.0,
    tablet: 14.0,
    largeTablet: 16.0,
  );

  /// Medium spacing: 16 -> 20 -> 24
  static const medium = ResponsiveValue<double>(
    phone: 16.0,
    tablet: 20.0,
    largeTablet: 24.0,
  );

  /// Large spacing: 24 -> 32 -> 40
  static const large = ResponsiveValue<double>(
    phone: 24.0,
    tablet: 32.0,
    largeTablet: 40.0,
  );
}

/// Max content widths for centering on wide screens
class ContentWidth {
  ContentWidth._();

  /// Max width for forms (login, signup, etc)
  static const double form = 480.0;

  /// Max width for standard content
  static const double content = 720.0;

  /// Max width for wide content
  static const double wide = 960.0;

  /// Max width for full-width content with margins
  static const double full = 1200.0;
}

/// Responsive sizing for UI elements
class AppSizing {
  AppSizing._();

  /// Button height: 56 -> 60 -> 64
  static const buttonHeight = ResponsiveValue<double>(
    phone: 56.0,
    tablet: 60.0,
    largeTablet: 64.0,
  );

  /// Input field min height: 64 -> 68 -> 72
  static const inputHeight = ResponsiveValue<double>(
    phone: 64.0,
    tablet: 68.0,
    largeTablet: 72.0,
  );

  /// Nav bar max width: 480 -> 560 -> 640
  static const navBarMaxWidth = ResponsiveValue<double>(
    phone: 480.0,
    tablet: 560.0,
    largeTablet: 640.0,
  );

  /// Nav bar height: 60 -> 64 -> 68
  static const navBarHeight = ResponsiveValue<double>(
    phone: 60.0,
    tablet: 64.0,
    largeTablet: 68.0,
  );

  /// Large avatar size: 116 -> 140 -> 160
  static const avatarLarge = ResponsiveValue<double>(
    phone: 116.0,
    tablet: 140.0,
    largeTablet: 160.0,
  );

  /// Medium avatar size: 58 -> 70 -> 80
  static const avatarMedium = ResponsiveValue<double>(
    phone: 58.0,
    tablet: 70.0,
    largeTablet: 80.0,
  );

  /// Icon size: 24 -> 28 -> 32
  static const iconSize = ResponsiveValue<double>(
    phone: 24.0,
    tablet: 28.0,
    largeTablet: 32.0,
  );

  /// Touch target minimum: 44 -> 48 -> 52
  static const touchTarget = ResponsiveValue<double>(
    phone: 44.0,
    tablet: 48.0,
    largeTablet: 52.0,
  );
}
