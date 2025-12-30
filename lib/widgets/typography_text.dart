import 'package:flutter/material.dart';

/// A reusable text widget that maps semantic typography variants to
/// the current Theme's TextStyles.
///
/// Variants:
/// - h1 -> textTheme.headlineLarge
/// - h2 -> textTheme.headlineMedium
/// - h3 -> textTheme.headlineSmall
/// - body1 -> textTheme.bodyLarge
/// - body2 -> textTheme.bodyMedium
class TypographyText extends StatelessWidget {
  const TypographyText(
    this.text, {
    super.key,
    this.variant = TypographyVariant.body1,
    this.color,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.fontWeight,
    this.height,
    this.fontSize,
    this.style,
    this.softWrap,
    this.textScaleFactor,
  });

  final String text;
  final TypographyVariant variant;

  /// Optional overrides
  final Color? color;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final FontWeight? fontWeight;
  final double? height;
  final double? fontSize;
  final TextStyle? style;
  final bool? softWrap;
  final double? textScaleFactor;

  TextStyle? _resolveBaseStyle(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    switch (variant) {
      case TypographyVariant.h1:
        return theme.headlineLarge;
      case TypographyVariant.h2:
        return theme.headlineMedium;
      case TypographyVariant.h3:
        return theme.headlineSmall;
      case TypographyVariant.h4:
        return theme.titleLarge;
      case TypographyVariant.body1:
        return theme.bodyLarge;
      case TypographyVariant.body2:
        return theme.bodyMedium;
    }
  }

  @override
  Widget build(BuildContext context) {
    TextStyle? base = _resolveBaseStyle(context);

    if (fontWeight != null) {
      base =
          base?.copyWith(fontWeight: fontWeight) ??
          TextStyle(fontWeight: fontWeight);
    }
    if (color != null) {
      base = base?.copyWith(color: color) ?? TextStyle(color: color);
    }
    if (height != null) {
      base = base?.copyWith(height: height) ?? TextStyle(height: height);
    }
    if (fontSize != null) {
      base = base?.copyWith(fontSize: fontSize) ?? TextStyle(fontSize: fontSize);
    }
    if (style != null) {
      base = base?.merge(style) ?? style;
    }

    return Text(
      text,
      style: base,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
      softWrap: softWrap,
      textScaleFactor: textScaleFactor,
    );
  }
}

/// The available typography variants for [TypographyText].
enum TypographyVariant { h1, h2, h3, h4, body1, body2 }
