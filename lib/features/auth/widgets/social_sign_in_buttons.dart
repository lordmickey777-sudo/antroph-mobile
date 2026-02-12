import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:antroph_mobile/core/auth/state/auth_state.dart';
import 'package:antroph_mobile/widgets/typography_text.dart';

/// Platform-aware social sign-in buttons.
///
/// - Android: Google only
/// - iOS: Google + Apple
class SocialSignInButtons extends ConsumerWidget {
  const SocialSignInButtons({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loading = ref.watch(authControllerProvider).isLoading;

    return Column(
      children: [
        _SocialButton(
          label: 'Continue with Google',
          icon: _googleIcon(),
          onTap: loading
              ? null
              : () => ref.read(authControllerProvider.notifier).signInWithGoogle(),
        ),
        if (Platform.isIOS) ...[
          const SizedBox(height: 12),
          _SocialButton(
            label: 'Continue with Apple',
            icon: const Icon(IconData(0xF04BE, fontFamily: 'CupertinoIcons', fontPackage: 'cupertino_icons'), color: Colors.white, size: 20),
            onTap: loading
                ? null
                : () => ref.read(authControllerProvider.notifier).signInWithApple(),
          ),
        ],
      ],
    );
  }

  Widget _googleIcon() {
    return SizedBox(
      width: 20,
      height: 20,
      child: CustomPaint(painter: _GoogleLogoPainter()),
    );
  }
}

/// Divider row with "or" text, to place between the main auth button and social buttons.
class OrDivider extends StatelessWidget {
  const OrDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.2))),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: TypographyText(
            'or',
            variant: TypographyVariant.body2,
            color: Colors.white54,
          ),
        ),
        Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.2))),
      ],
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({required this.label, required this.icon, required this.onTap});

  final String label;
  final Widget icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Material(
        color: const Color(0xFF1F2223),
        borderRadius: BorderRadius.circular(40),
        child: InkWell(
          onTap: onTap == null
              ? null
              : () {
                  HapticFeedback.lightImpact();
                  onTap!();
                },
          borderRadius: BorderRadius.circular(40),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                icon,
                const SizedBox(width: 12),
                TypographyText(
                  label,
                  variant: TypographyVariant.body1,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Paints the Google "G" logo with the four brand colours.
class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    final paint = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    // Blue
    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(
      Rect.fromLTWH(0, 0, w, h),
      -0.5,
      -2.6,
      true,
      paint,
    );

    // Green
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(
      Rect.fromLTWH(0, 0, w, h),
      0.5,
      1.1,
      true,
      paint,
    );

    // Yellow
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(
      Rect.fromLTWH(0, 0, w, h),
      1.6,
      1.1,
      true,
      paint,
    );

    // Red
    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(
      Rect.fromLTWH(0, 0, w, h),
      2.7,
      0.9,
      true,
      paint,
    );

    // White centre
    paint.color = Colors.white;
    canvas.drawCircle(Offset(w / 2, h / 2), w * 0.32, paint);

    // Blue bar (right side of G)
    paint.color = const Color(0xFF4285F4);
    final barRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.48, h * 0.36, w * 0.52, h * 0.28),
      const Radius.circular(1),
    );
    canvas.drawRRect(barRect, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
