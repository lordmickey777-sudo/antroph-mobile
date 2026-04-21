import 'package:shared_preferences/shared_preferences.dart';

/// Persists the first-run setup flow selections shown after authentication.
class AppSetupStorageService {
  static const _setupCompletedKey = 'app_setup_completed';
  static const _selectedInterestsKey = 'app_setup_selected_interests';
  static const _selectedVibeKey = 'app_setup_selected_vibe';
  static const _selectedVoiceKey = 'app_setup_selected_voice';
  static const _selectedVoiceIdKey = 'app_setup_selected_voice_id';

  static Future<bool> hasCompletedSetup() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_setupCompletedKey) ?? false;
  }

  static Future<List<String>> getSelectedInterests() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_selectedInterestsKey) ?? <String>[];
  }

  static Future<void> saveSelectedInterests(List<String> interests) async {
    final prefs = await SharedPreferences.getInstance();
    final normalized = interests.toSet().toList()..sort();
    await prefs.setStringList(_selectedInterestsKey, normalized);
  }

  static Future<String?> getSelectedVibe() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_selectedVibeKey);
  }

  static Future<void> saveSelectedVibe(String vibe) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedVibeKey, vibe.trim());
  }

  static Future<String?> getSelectedVoice() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_selectedVoiceKey);
  }

  static Future<void> saveSelectedVoice(String voice) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedVoiceKey, voice);
  }

  static Future<String?> getSelectedVoiceId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_selectedVoiceIdKey);
  }

  static Future<void> saveSelectedVoiceId(String voiceId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedVoiceIdKey, voiceId);
  }

  static Future<void> markSetupCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_setupCompletedKey, true);
  }
}
