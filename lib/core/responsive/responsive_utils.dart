import 'package:flutter/material.dart';

/// Device type classification based on screen width
enum DeviceType { phone, tablet, largeTablet }

/// Breakpoint definitions for responsive layouts
/// Follows the existing pattern from chat_page.dart
class Breakpoints {
  Breakpoints._();

  /// Phone breakpoint: < 600px
  static const double phone = 600;

  /// Tablet breakpoint: 600-900px
  static const double tablet = 900;
}

/// Extension on BuildContext for responsive utilities
extension ResponsiveContext on BuildContext {
  /// Get screen width from MediaQuery
  double get screenWidth => MediaQuery.of(this).size.width;

  /// Get screen height from MediaQuery
  double get screenHeight => MediaQuery.of(this).size.height;

  /// Get current device type based on screen width
  DeviceType get deviceType {
    final width = screenWidth;
    if (width < Breakpoints.phone) return DeviceType.phone;
    if (width < Breakpoints.tablet) return DeviceType.tablet;
    return DeviceType.largeTablet;
  }

  /// Check if device is a phone
  bool get isPhone => deviceType == DeviceType.phone;

  /// Check if device is a tablet (600-900px)
  bool get isTablet => deviceType == DeviceType.tablet;

  /// Check if device is a large tablet (>900px)
  bool get isLargeTablet => deviceType == DeviceType.largeTablet;

  /// Check if device is tablet or larger
  bool get isTabletOrLarger => !isPhone;

  /// Check if device is in landscape orientation
  bool get isLandscape =>
      MediaQuery.of(this).orientation == Orientation.landscape;
}

/// Responsive value that returns different values based on device type
class ResponsiveValue<T> {
  final T phone;
  final T? _tablet;
  final T? _largeTablet;

  const ResponsiveValue({
    required this.phone,
    T? tablet,
    T? largeTablet,
  })  : _tablet = tablet,
        _largeTablet = largeTablet;

  /// Get tablet value, falls back to phone
  T get tablet => _tablet ?? phone;

  /// Get large tablet value, falls back to tablet then phone
  T get largeTablet => _largeTablet ?? _tablet ?? phone;

  /// Get value based on BuildContext
  T of(BuildContext context) {
    switch (context.deviceType) {
      case DeviceType.phone:
        return phone;
      case DeviceType.tablet:
        return tablet;
      case DeviceType.largeTablet:
        return largeTablet;
    }
  }

  /// Get value based on BoxConstraints (for use inside LayoutBuilder)
  T fromConstraints(BoxConstraints constraints) {
    final width = constraints.maxWidth;
    if (width >= Breakpoints.tablet) return largeTablet;
    if (width >= Breakpoints.phone) return tablet;
    return phone;
  }

  /// Get value based on raw width
  T fromWidth(double width) {
    if (width >= Breakpoints.tablet) return largeTablet;
    if (width >= Breakpoints.phone) return tablet;
    return phone;
  }
}

/// Helper function for inline responsive values
T responsive<T>(
  BuildContext context, {
  required T phone,
  T? tablet,
  T? largeTablet,
}) {
  return ResponsiveValue<T>(
    phone: phone,
    tablet: tablet,
    largeTablet: largeTablet,
  ).of(context);
}

/// Helper function for responsive values from constraints
T responsiveFromConstraints<T>(
  BoxConstraints constraints, {
  required T phone,
  T? tablet,
  T? largeTablet,
}) {
  return ResponsiveValue<T>(
    phone: phone,
    tablet: tablet,
    largeTablet: largeTablet,
  ).fromConstraints(constraints);
}
