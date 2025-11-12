import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A general purpose button for the app that provides a subtle
/// haptic + tap feedback when pressed.
///
/// Wraps [ElevatedButton] by default. You can override [style]
/// or supply a different [builder] if you need full control.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.enableFeedback = true,
    this.style,
  });

  /// Callback invoked after feedback is triggered.
  final VoidCallback? onPressed;

  /// Button contents.
  final Widget child;

  /// Whether to trigger haptic + tap feedback.
  final bool enableFeedback;

  /// Optional style forwarded to [ElevatedButton.styleFrom].
  final ButtonStyle? style;

  void _handlePress(BuildContext context) async {
    if (enableFeedback) {
      // More noticeable haptic feedback
      HapticFeedback.mediumImpact();
      Feedback.forTap(context);
    }
    onPressed?.call();
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: style,
      onPressed: onPressed == null ? null : () => _handlePress(context),
      child: child,
    );
  }
}
