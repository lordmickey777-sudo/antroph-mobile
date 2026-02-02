import 'package:flutter/material.dart';

/// A widget that shows a fade gradient at the top when content is scrolled.
/// Wrap your scrollable content (like CustomScrollView) with this widget.
class ScrollFadeGradient extends StatefulWidget {
  const ScrollFadeGradient({
    super.key,
    required this.child,
    this.height = 60,
    this.fadeThreshold = 10,
  });

  final Widget child;
  final double height;
  final double fadeThreshold;

  @override
  State<ScrollFadeGradient> createState() => _ScrollFadeGradientState();
}

class _ScrollFadeGradientState extends State<ScrollFadeGradient> {
  double _scrollOffset = 0;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF141718) : const Color(0xFFF5F5F7);
    final opacity = (_scrollOffset / widget.fadeThreshold).clamp(0.0, 1.0);

    return Stack(
      children: [
        NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification is ScrollUpdateNotification) {
              setState(() {
                _scrollOffset = notification.metrics.pixels;
              });
            }
            return false;
          },
          child: widget.child,
        ),
        if (opacity > 0)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: AnimatedOpacity(
                opacity: opacity,
                duration: const Duration(milliseconds: 150),
                child: Container(
                  height: widget.height,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [bgColor, bgColor.withValues(alpha: 0)],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
