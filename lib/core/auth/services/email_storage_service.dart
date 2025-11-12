import 'package:shared_preferences/shared_preferences.dart';

/// Service to handle persistent storage of the last successfully used email
/// for login functionality.
class EmailStorageService {
  static const String _lastEmailKey = 'last_login_email';

  /// Retrieves the last email used for successful login.
  /// Returns null if no email has been stored.
  static Future<String?> getLastEmail() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_lastEmailKey);
    } catch (e) {
      // Log error in production apps
      return null;
    }
  }

  /// Stores the email after a successful login.
  /// This email will be used to prefill the login form on next app launch.
  static Future<void> saveLastEmail(String email) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastEmailKey, email.trim());
    } catch (e) {
      // Log error in production apps
      // Don't throw - this is a nice-to-have feature
    }
  }

  /// Clears the stored email (useful for logout or privacy features).
  static Future<void> clearLastEmail() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_lastEmailKey);
    } catch (e) {
      // Log error in production apps
    }
  }
}
