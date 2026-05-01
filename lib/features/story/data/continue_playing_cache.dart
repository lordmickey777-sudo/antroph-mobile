import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import '../models/story_models.dart';

/// JSON disk cache for the "Continue Playing" list.
class ContinuePlayingCacheService {
  static const _key = 'continue_playing_cache_v1';
  static const _timestampKey = 'continue_playing_cache_ts_v1';
  static const Duration maxAge = Duration(minutes: 10);

  static Future<void> save(List<ContinuePlayingDto> data) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(data.map((e) => e.toJson()).toList());
    await prefs.setString(_key, jsonStr);
    await prefs.setInt(_timestampKey, DateTime.now().millisecondsSinceEpoch);
  }

  static Future<List<ContinuePlayingDto>?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_key);
    if (str == null || str.isEmpty) return null;
    try {
      final list = jsonDecode(str) as List<dynamic>;
      return list
          .map((e) => ContinuePlayingDto.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return null;
    }
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    await prefs.remove(_timestampKey);
  }
}
