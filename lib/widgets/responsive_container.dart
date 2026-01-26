import 'package:flutter/material.dart';
import '../core/responsive/responsive_spacing.dart';
import '../core/responsive/responsive_utils.dart';

/// A container that centers content and applies max-width on larger screens.
/// Use this to wrap page content for proper iPad scaling.
class ResponsiveContainer extends StatelessWidget {
  final Widget child;
  final double? maxWidth;
  final EdgeInsetsGeometry? padding;
  final bool center;

  const ResponsiveContainer({
    super.key,
    required this.child,
    this.maxWidth,
    this.padding,
    this.center = true,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = child;

    // Apply padding if provided
    if (padding != null) {
      content = Padding(padding: padding!, child: content);
    }

    // Apply max-width constraint and centering on larger screens
    if (center && context.isTabletOrLarger) {
      content = Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: maxWidth ?? ContentWidth.content,
          ),
          child: content,
        ),
      );
    }

    return content;
  }
}

/// A scaffold body wrapper that centers content on wide screens.
/// Includes SafeArea and optional padding.
class ResponsiveBody extends StatelessWidget {
  final Widget child;
  final double? maxWidth;
  final EdgeInsetsGeometry? padding;
  final bool useSafeArea;

  const ResponsiveBody({
    super.key,
    required this.child,
    this.maxWidth,
    this.padding,
    this.useSafeArea = true,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = ResponsiveContainer(
      maxWidth: maxWidth,
      padding: padding,
      child: child,
    );

    if (useSafeArea) {
      content = SafeArea(child: content);
    }

    return content;
  }
}

/// A form container that centers with max-width suitable for forms.
/// Use for login, signup, and similar form-based pages.
class ResponsiveFormContainer extends StatelessWidget {
  final Widget child;
  final double? maxWidth;
  final EdgeInsetsGeometry? padding;

  const ResponsiveFormContainer({
    super.key,
    required this.child,
    this.maxWidth,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth ?? ContentWidth.form,
        ),
        child: Padding(
          padding: padding ??
              EdgeInsets.symmetric(
                horizontal: AppPadding.form.of(context),
              ),
          child: child,
        ),
      ),
    );
  }
}

/// A LayoutBuilder-based responsive widget that provides constraints
/// and responsive helper methods to its builder.
class ResponsiveBuilder extends StatelessWidget {
  final Widget Function(
    BuildContext context,
    BoxConstraints constraints,
    DeviceType deviceType,
  ) builder;

  const ResponsiveBuilder({
    super.key,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final deviceType = ResponsiveValue<DeviceType>(
          phone: DeviceType.phone,
          tablet: DeviceType.tablet,
          largeTablet: DeviceType.largeTablet,
        ).fromConstraints(constraints);

        return builder(context, constraints, deviceType);
      },
    );
  }
}
