import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/home/presentation/home_page.dart';
import 'features/splash/presentation/splash_page.dart';
import 'features/onboarding/presentation/onboarding_page.dart';
import 'features/auth/pages/login_page.dart';
import 'features/auth/pages/forgot_password_page.dart';
import 'features/auth/pages/signup_page.dart';
import 'features/profile/presentation/customization_page.dart';
import 'features/profile/presentation/subscription_page.dart';
import 'features/profile/presentation/scan_page.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    routes: <RouteBase>[
      GoRoute(path: '/', name: 'splash', builder: (context, state) => const SplashPage()),
      GoRoute(
        path: '/onboarding',
        name: 'onboarding',
        builder: (context, state) => const OnboardingPage(),
      ),
      GoRoute(path: '/home', name: 'home', builder: (context, state) => const HomePage()),
      GoRoute(path: '/auth/login', name: 'login', builder: (context, state) => const LoginPage()),
      GoRoute(
        path: '/auth/forgot-password',
        name: 'forgot-password',
        builder: (context, state) => const ForgotPasswordPage(),
      ),
      GoRoute(
        path: '/auth/signup',
        name: 'signup',
        builder: (context, state) => const SignUpPage(),
      ),
      GoRoute(
        path: '/profile/customization',
        name: 'customization',
        builder: (context, state) => const CustomizationPage(),
      ),
      GoRoute(
        path: '/profile/subscription',
        name: 'subscription',
        builder: (context, state) => const SubscriptionPage(),
      ),
      GoRoute(path: '/profile/scan', name: 'scan', builder: (context, state) => const ScanPage()),
    ],
  );
});
