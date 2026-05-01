import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import '../models/community_story_model.dart';
import '../models/rive_element_model.dart';

/// JSON disk cache for the community browse list.
class CommunityStoriesCacheService {
  static const _prefix = 'community_stories_cache_v1';
  static const _tsPrefix = 'community_stories_cache_ts_v1';
  static const Duration maxAge = Duration(minutes: 15);

  static String _key(String? categoryId) => '${_prefix}_${categoryId ?? 'all'}';
  static String _tsKey(String? categoryId) => '${_tsPrefix}_${categoryId ?? 'all'}';

  static Future<void> save(
    List<CommunityStoryDto> data, {
    required String? categoryId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(data.map((e) => e.toJson()).toList());
    await prefs.setString(_key(categoryId), jsonStr);
    await prefs.setInt(_tsKey(categoryId), DateTime.now().millisecondsSinceEpoch);
  }

  static Future<List<CommunityStoryDto>?> load({required String? categoryId}) async {
    final prefs = await SharedPreferences.getInstance();
    final ts = prefs.getInt(_tsKey(categoryId));
    if (ts == null) return null;
    final str = prefs.getString(_key(categoryId));
    if (str == null || str.isEmpty) return null;
    try {
      final list = jsonDecode(str) as List<dynamic>;
      return list
          .map((e) => CommunityStoryDto.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return null;
    }
  }

  static Future<void> clear({String? categoryId}) async {
    final prefs = await SharedPreferences.getInstance();
    if (categoryId != null) {
      await prefs.remove(_key(categoryId));
      await prefs.remove(_tsKey(categoryId));
    } else {
      // Clear all categories
      final keys = prefs.getKeys().where((k) => k.startsWith(_prefix) || k.startsWith(_tsPrefix));
      for (final k in keys) {
        await prefs.remove(k);
      }
    }
  }

  // Rive Elements cache
  static const _rivePrefix = 'rive_elements_cache_v1_';
  static const _riveTsPrefix = 'rive_elements_cache_ts_v1_';

  static Future<void> saveRiveElements(List<RiveElementDto> data, String? category) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(data.map((e) => e.toJson()).toList());
    final key = '${_rivePrefix}${category ?? 'all'}';
    final tsKey = '${_riveTsPrefix}${category ?? 'all'}';
    await prefs.setString(key, jsonStr);
    await prefs.setInt(tsKey, DateTime.now().millisecondsSinceEpoch);
  }

  static Future<List<RiveElementDto>?> loadRiveElements(String? category) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '${_rivePrefix}${category ?? 'all'}';
    final tsKey = '${_riveTsPrefix}${category ?? 'all'}';
    final ts = prefs.getInt(tsKey);
    if (ts == null) return null;
    final str = prefs.getString(key);
    if (str == null || str.isEmpty) return null;
    try {
      final list = jsonDecode(str) as List<dynamic>;
      return list.map((e) => RiveElementDto.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return null;
    }
  }
}
