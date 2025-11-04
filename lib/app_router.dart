import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/home/presentation/home_page.dart';
import 'features/splash/presentation/splash_page.dart';
import 'features/onboarding/presentation/onboarding_page.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        name: 'splash',
        builder: (context, state) => const SplashPage(),
      ),
      GoRoute(
        path: '/onboarding',
        name: 'onboarding',
        builder: (context, state) => const OnboardingPage(),
      ),
      GoRoute(
        path: '/home',
        name: 'home',
        builder: (context, state) => const HomePage(),
      ),
    ],
  );
});
