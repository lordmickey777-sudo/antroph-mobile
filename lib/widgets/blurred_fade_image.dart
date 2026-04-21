import 'dart:ui';

import 'package:flutter/material.dart';

/// Renders an image with a bottom-fading blur effect, producing a frosted
/// footer that keeps overlaid text and buttons legible against any image.
///
/// [imageBuilder] is invoked twice — once for the sharp base layer and once
/// for the blurred copy — so the caller controls image decoding, error
/// handling, and shimmer behaviour.
class BlurredFadeImage extends StatelessWidget {
  const BlurredFadeImage({
    super.key,
    required this.imageBuilder,
    this.blurSigma = 22,
    this.fadeStart = 0.55,
    this.fadeEnd = 0.85,
    this.gradient,
  });

  final WidgetBuilder imageBuilder;
  final double blurSigma;
  final double fadeStart;
  final double fadeEnd;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        imageBuilder(context),
        Positioned.fill(
          child: IgnorePointer(
            child: ShaderMask(
              shaderCallback: (rect) => LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: const [Colors.transparent, Colors.black],
                stops: [fadeStart, fadeEnd],
              ).createShader(rect),
              blendMode: BlendMode.dstIn,
              child: ClipRect(
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(
                    sigmaX: blurSigma,
                    sigmaY: blurSigma,
                  ),
                  child: imageBuilder(context),
                ),
              ),
            ),
          ),
        ),
        if (gradient != null)
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(decoration: BoxDecoration(gradient: gradient)),
            ),
          ),
      ],
    );
  }
}
