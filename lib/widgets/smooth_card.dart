import 'package:flutter/material.dart';
import 'package:smooth_corner/smooth_corner.dart';

/// Wraps a child in iOS-style continuous (squircle) corners with an optional
/// border. Use this for any card-like surface so the corner curvature is
/// consistent across the app.
class SmoothCard extends StatelessWidget {
  const SmoothCard({
    super.key,
    required this.child,
    this.radius = 20,
    this.smoothness = 1,
    this.borderColor,
    this.borderWidth = 1,
  });

  final Widget child;
  final double radius;
  final double smoothness;
  final Color? borderColor;
  final double borderWidth;

  @override
  Widget build(BuildContext context) {
    final resolvedBorder =
        borderColor ??
        (Theme.of(context).brightness == Brightness.dark
            ? Colors.white.withValues(alpha: 0.15)
            : Colors.black.withValues(alpha: 0.1));

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      clipBehavior: Clip.antiAlias,
      child: SmoothClipRRect(
        smoothness: smoothness,
        borderRadius: BorderRadius.circular(radius),
        side: BorderSide(color: resolvedBorder, width: borderWidth),
        child: child,
      ),
    );
  }
}
