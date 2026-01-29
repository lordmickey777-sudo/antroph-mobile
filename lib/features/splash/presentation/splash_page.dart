import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:antroph_mobile/widgets/typography_text.dart';
import 'package:antroph_mobile/core/auth/state/auth_state.dart';
import 'package:antroph_mobile/core/onboarding/onboarding_storage_service.dart';

class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage> {
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _determineStartRoute();
  }

  Future<void> _determineStartRoute() async {
    // Keep the splash visible briefly while we restore session/onboarding state.
    final hasCompletedOnboarding = await OnboardingStorageService.hasCompletedOnboarding();
    final minimumDisplay = hasCompletedOnboarding
        ? Future<void>.value()
        : Future.delayed(const Duration(milliseconds: 1200));

    // Attempt to restore auth session in background (for returning users)
    try {
      await ref.read(authControllerProvider.future);
    } catch (_) {
      // Ignore auth errors - user can continue as guest
    }

    await minimumDisplay;
    if (!mounted) return;

    if (!hasCompletedOnboarding) {
      _navigate('/onboarding');
      return;
    }

    // Always go to home - auth is handled via auth guard sheets when needed
    _navigate('/home');
  }

  void _navigate(String path) {
    if (_navigated || !mounted) return;
    _navigated = true;
    context.go(path);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Centered logo
          Center(
            child: Platform.environment.containsKey('FLUTTER_TEST')
                ? const SizedBox(width: 180, height: 180)
                : Image.asset(
                    'assets/images/logo.png',
                    width: 180,
                    fit: BoxFit.contain,
                  ),
          ),
          // Version label at bottom center
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: const TypographyText(
                  'Aura 1.0',
                  variant: TypographyVariant.body2,
                  color: Colors.white70,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
