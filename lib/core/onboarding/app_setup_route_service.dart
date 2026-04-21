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

    try {
      final profile = await repo.getMyProfile();
      if (!profile.personalizationCompleted) {
        return personalizationRoute;
      }
    } catch (_) {
      final hasCompletedSetup =
          await AppSetupStorageService.hasCompletedSetup();
      return hasCompletedSetup ? homeRoute : personalizationRoute;
    }

    final hasCompletedSetup = await AppSetupStorageService.hasCompletedSetup();
    return hasCompletedSetup ? homeRoute : voiceRoute;
  }
}
