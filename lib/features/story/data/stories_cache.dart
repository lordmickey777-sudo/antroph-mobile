import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import '../models/story_models.dart';

/// Simple JSON cache for StoriesHomeResponse using shared_preferences.
class StoriesCacheService {
  static const _key = 'stories_home_cache_v1';
  static const _timestampKey = 'stories_home_cache_ts_v1';
  static const Duration maxAge = Duration(minutes: 15);

  /// Save stories to cache.
  static Future<void> save(StoriesHomeResponse data) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(data.toJson());
    await prefs.setString(_key, jsonStr);
    await prefs.setInt(_timestampKey, DateTime.now().millisecondsSinceEpoch);
  }

  /// Load cached stories if not expired. Returns null if missing or stale.
  static Future<StoriesHomeResponse?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final ts = prefs.getInt(_timestampKey);
    if (ts == null) return null;
    final age = DateTime.now().millisecondsSinceEpoch - ts;
    if (age > maxAge.inMilliseconds) return null; // stale
    final str = prefs.getString(_key);
    if (str == null || str.isEmpty) return null;
    try {
      final map = jsonDecode(str) as Map<String, dynamic>;
      return StoriesHomeResponse.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  /// Force clear cache.
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    await prefs.remove(_timestampKey);
  }
}
