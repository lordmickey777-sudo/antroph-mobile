import 'package:shared_preferences/shared_preferences.dart';

/// Manages user consent for third-party AI data processing.
class AiConsentService {
  static const _consentKey = 'ai_data_consent_accepted';
  static const _consentDateKey = 'ai_data_consent_date';

  static Future<bool> hasAcceptedConsent() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_consentKey) ?? false;
  }

  static Future<void> acceptConsent() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_consentKey, true);
    await prefs.setString(_consentDateKey, DateTime.now().toIso8601String());
  }

  static Future<void> revokeConsent() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_consentKey, false);
    await prefs.remove(_consentDateKey);
  }
}
