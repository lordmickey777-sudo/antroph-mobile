import 'package:shared_preferences/shared_preferences.dart';

/// Handles persistence of onboarding completion so we can skip onboarding
/// screens on subsequent app launches.
class OnboardingStorageService {
  static const _onboardingCompletedKey = 'onboarding_completed';

  static Future<bool> hasCompletedOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_onboardingCompletedKey) ?? false;
  }

  static Future<void> markCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingCompletedKey, true);
  }
}
