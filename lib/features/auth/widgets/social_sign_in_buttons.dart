import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:antroph_mobile/core/auth/state/auth_state.dart';
import 'package:antroph_mobile/core/theme/theme_provider.dart';
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
          icon: _socialIcon('assets/images/google.svg'),
          onTap: loading
              ? null
              : () => ref
                    .read(authControllerProvider.notifier)
                    .signInWithGoogle(),
        ),
        if (Platform.isIOS) ...[
          const SizedBox(height: 12),
          _SocialButton(
            label: 'Continue with Apple',
            icon: _socialIcon('assets/images/apple.svg'),
            onTap: loading
                ? null
                : () => ref
                      .read(authControllerProvider.notifier)
                      .signInWithApple(),
          ),
        ],
      ],
    );
  }

  Widget _socialIcon(String assetPath) {
    return SizedBox(width: 20, height: 20, child: SvgPicture.asset(assetPath));
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
  const _SocialButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final Widget icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final buttonBackground = context.actionButtonBackground;
    final buttonForeground = context.actionButtonForeground;

    return SizedBox(
      height: 56,
      child: Material(
        color: buttonBackground,
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
                  color: buttonForeground,
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
