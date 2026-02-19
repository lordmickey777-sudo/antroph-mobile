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
  static String get posthogApiKey => _string('POSTHOG_API_KEY', '');
  static String get posthogHost =>
      _string('POSTHOG_HOST', 'https://us.i.posthog.com');
  static String get robotSerial => _string('ROBOT_SERIAL', '');
  static String get chatWsUrl {
    final direct = _string('CHAT_WS_URL', '');
    if (direct.isNotEmpty) {
      return _normalizeWsUrl(direct);
    }
    return voiceRealtimeWsUrl;
  }

  static String get voiceRealtimeWsUrl {
    final direct = _string('VOICE_REALTIME_WS_URL', '');
    if (direct.isNotEmpty) {
      return _normalizeWsUrl(direct);
    }
    final api = apiBaseUrl;
    if (api.isEmpty) return '';
    final base = api.endsWith('/') ? api.substring(0, api.length - 1) : api;
    if (base.startsWith('https://')) {
      return '${base.replaceFirst('https://', 'wss://')}/ws/realtime/voice';
    }
    if (base.startsWith('http://')) {
      return '${base.replaceFirst('http://', 'ws://')}/ws/realtime/voice';
    }
    return 'wss://$base/ws/realtime/voice';
  }

  static String get storyWsUrl {
    final direct = _string('STORY_WS_URL', '');
    if (direct.isNotEmpty) {
      return direct;
    }
    final api = apiBaseUrl;
    if (api.startsWith('https://')) {
      return api.replaceFirst('https://', 'wss://');
    }
    if (api.startsWith('http://')) {
      return api.replaceFirst('http://', 'ws://');
    }
    return '';
  }

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

  static String _normalizeWsUrl(String input) {
    var trimmed = input.trim();
    if (trimmed.endsWith('#')) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    final uri = Uri.tryParse(trimmed);
    if (uri == null) return trimmed;
    if (uri.scheme == 'https') return uri.replace(scheme: 'wss').toString();
    if (uri.scheme == 'http') return uri.replace(scheme: 'ws').toString();
    return trimmed;
  }
}
