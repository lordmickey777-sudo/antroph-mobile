import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppEnv {
  static bool _loaded = false;

  static Future<void> load() async {
    if (_loaded) return;
    try {
      await dotenv.load(fileName: '.env');
      _loaded = true;
    } catch (_) {
      // Silently ignore; fallback to dart-define values.
    }
  }

  static String get apiBaseUrl => _string('API_BASE_URL', '');
  static String get sentryDsn => _string('SENTRY_DSN', '');

  static String _string(String key, String fallback) {
    // If dotenv hasn't been initialized (e.g., .env not bundled), avoid calling it.
    if (dotenv.isInitialized) {
      final v = dotenv.maybeGet(key);
      if (v != null && v.isNotEmpty) {
        return v;
      }
    }
    // Fallback to dart-define or provided default
    return String.fromEnvironment(key, defaultValue: fallback);
  }
}
