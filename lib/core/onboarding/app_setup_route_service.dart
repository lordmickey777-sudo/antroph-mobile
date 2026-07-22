import 'package:antroph_mobile/core/onboarding/app_setup_storage_service.dart';
import 'package:antroph_mobile/features/profile/data/profile_repository.dart';

class AppSetupRouteService {
  const AppSetupRouteService._();

  static const String personalizationRoute = '/setup/interests';
  static const String voiceRoute = '/setup/voice';
  static const String homeRoute = '/home';
  static const String onboardingRoute = '/onboarding';

  static Future<String> resolveAuthenticatedRoute({
    String? userId,
    ProfileRepository? profileRepository,
  }) async {
    final repo = profileRepository ?? ProfileRepository();

    // Server onboarding is authoritative. It covers intro, interests, and voice.
    final savedVibe = await AppSetupStorageService.getSelectedVibe();
    final hasCompletedSetup = await AppSetupStorageService.hasCompletedSetup();
    try {
      final profile = await repo.getMyProfile();
      if (profile.onboardingCompleted) {
        return homeRoute;
      }
      return onboardingRoute;
    } catch (_) {
      if (!hasCompletedSetup && (savedVibe == null || savedVibe.isEmpty)) {
        return personalizationRoute;
      }
    }

    // 2. Check if setup is fully completed (Voice selection)
    if (!hasCompletedSetup) {
      return voiceRoute;
    }

    return homeRoute;
  }
}
