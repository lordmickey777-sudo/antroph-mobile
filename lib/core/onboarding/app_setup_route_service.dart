import 'package:antroph_mobile/core/onboarding/app_setup_storage_service.dart';
import 'package:antroph_mobile/features/profile/data/profile_repository.dart';

class AppSetupRouteService {
  const AppSetupRouteService._();

  static const String personalizationRoute = '/setup/interests';
  static const String voiceRoute = '/setup/voice';
  static const String homeRoute = '/home';

  static Future<String> resolveAuthenticatedRoute({
    ProfileRepository? profileRepository,
  }) async {
    final repo = profileRepository ?? ProfileRepository();

    // 1. Check if interests/preferences are completed (Backend + Local check)
    final savedVibe = await AppSetupStorageService.getSelectedVibe();
    try {
      final profile = await repo.getMyProfile();
      if (!profile.personalizationCompleted || savedVibe == null || savedVibe.isEmpty) {
        return personalizationRoute;
      }
    } catch (_) {
      final hasCompletedSetup = await AppSetupStorageService.hasCompletedSetup();
      if (!hasCompletedSetup && (savedVibe == null || savedVibe.isEmpty)) {
        return personalizationRoute;
      }
    }

    // 2. Check if setup is fully completed (Voice selection)
    final hasCompletedSetup = await AppSetupStorageService.hasCompletedSetup();
    if (!hasCompletedSetup) {
      return voiceRoute;
    }

    return homeRoute;
  }
}
