import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:antroph_mobile/core/theme/theme_provider.dart';

import 'typography_text.dart';

/// A reusable pill-shaped action button with consistent ripple feedback.
class AppPillButton extends StatelessWidget {
  const AppPillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.backgroundColor,
    this.foregroundColor,
    this.borderColor,
    this.padding = const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
    this.radius = 999,
    this.enableFeedback = true,
    this.variant = TypographyVariant.body1,
    this.fontWeight,
    this.fontSize,
    this.iconSize = 18,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Color? borderColor;
  final EdgeInsets padding;
  final double radius;
  final bool enableFeedback;
  final TypographyVariant variant;
  final FontWeight? fontWeight;
  final double? fontSize;
  final double iconSize;

  void _handleTap(BuildContext context) {
    if (enableFeedback) {
      HapticFeedback.mediumImpact();
      Feedback.forTap(context);
    }
    onPressed?.call();
  }

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null && !isLoading;
    final shouldDim = onPressed == null && !isLoading;
    final fg = foregroundColor ?? context.actionButtonForeground;
    final bg = backgroundColor ?? context.actionButtonBackground;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: borderColor == null
          ? BorderSide.none
          : BorderSide(color: borderColor!),
    );

    final rippleColor = fg.withValues(alpha: 0.18);
    final highlightColor = fg.withValues(alpha: 0.08);

    final content = Padding(
      padding: padding,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLoading)
            SizedBox(
              width: iconSize,
              height: iconSize,
              child: CupertinoActivityIndicator(color: fg),
            )
          else if (icon != null)
            Icon(icon, size: iconSize, color: fg),
          if (isLoading || icon != null) const SizedBox(width: 6),
          TypographyText(
            label,
            variant: variant,
            color: fg,
            fontWeight: fontWeight,
            fontSize: fontSize,
          ),
        ],
      ),
    );

    final button = Material(
      color: bg,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: isEnabled ? () => _handleTap(context) : null,
        splashColor: rippleColor,
        highlightColor: highlightColor,
        child: content,
      ),
    );

    if (isEnabled || !shouldDim) return button;

    return Opacity(opacity: 0.6, child: button);
  }
}

/// A reusable circular icon button with consistent ripple feedback.
class AppCircleIconButton extends StatelessWidget {
  const AppCircleIconButton({
    super.key,
    required this.onPressed,
    required this.icon,
    this.isLoading = false,
    this.size = 34,
    this.iconSize = 18,
    this.backgroundColor,
    this.foregroundColor,
    this.borderColor,
    this.enableFeedback = true,
  });

  final VoidCallback? onPressed;
  final IconData icon;
  final bool isLoading;
  final double size;
  final double iconSize;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Color? borderColor;
  final bool enableFeedback;

  void _handleTap(BuildContext context) {
    if (enableFeedback) {
      HapticFeedback.lightImpact();
      Feedback.forTap(context);
    }
    onPressed?.call();
  }

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null && !isLoading;
    final shouldDim = onPressed == null && !isLoading;
    final fg = foregroundColor ?? context.actionButtonForeground;
    final bg = backgroundColor ?? context.actionButtonBackground;
    final rippleColor = fg.withValues(alpha: 0.18);
    final highlightColor = fg.withValues(alpha: 0.08);

    final shape = CircleBorder(
      side: borderColor == null
          ? BorderSide.none
          : BorderSide(color: borderColor!),
    );

    final button = Material(
      color: bg,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: isEnabled ? () => _handleTap(context) : null,
        customBorder: shape,
        splashColor: rippleColor,
        highlightColor: highlightColor,
        child: SizedBox(
          width: size,
          height: size,
          child: Center(
            child: isLoading
                ? CupertinoActivityIndicator(color: fg)
                : Icon(icon, size: iconSize, color: fg),
          ),
        ),
      ),
    );

    if (isEnabled || !shouldDim) return button;
    return Opacity(opacity: 0.6, child: button);
  }
}
