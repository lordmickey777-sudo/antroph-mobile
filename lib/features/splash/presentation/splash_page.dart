import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:antroph_mobile/widgets/typography_text.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Navigate to onboarding after a short delay
    _timer = Timer(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      context.go('/onboarding');
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
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
