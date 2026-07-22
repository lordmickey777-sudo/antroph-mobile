import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:antroph_mobile/core/onboarding/app_setup_route_service.dart';
import 'package:antroph_mobile/widgets/typography_text.dart';
import 'package:antroph_mobile/core/auth/state/auth_state.dart';
import 'package:antroph_mobile/core/theme/theme_provider.dart';

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
    final minimumDisplay = Future<void>.delayed(
      const Duration(milliseconds: 450),
    );

    try {
      await ref.read(authControllerProvider.future);
    } catch (_) {
      // Ignore auth restore errors and fall back to the auth flow.
    }

    await minimumDisplay;
    if (!mounted) return;

    final user = ref.read(authControllerProvider).value;
    if (user == null) {
      _navigate('/auth/login');
      return;
    }

    final nextRoute = await AppSetupRouteService.resolveAuthenticatedRoute(
      userId: user.id,
    );
    if (!mounted) return;
    _navigate(nextRoute);
  }

  void _navigate(String path) {
    if (_navigated || !mounted) return;
    _navigated = true;
    context.go(path);
  }

  @override
  Widget build(BuildContext context) {
    // Always use dark theme for splash screen regardless of app theme
    return Theme(
      data: AppTheme.darkTheme,
      child: Scaffold(
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
      ),
    );
  }
}
