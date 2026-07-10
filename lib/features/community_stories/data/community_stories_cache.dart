import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import '../models/community_story_model.dart';
import '../models/rive_element_model.dart';

/// JSON disk cache for the community browse list.
class CommunityStoriesCacheService {
  static const _prefix = 'community_stories_cache_v2';
  static const _tsPrefix = 'community_stories_cache_ts_v2';
  static const _legacyPrefix = 'community_stories_cache_v1_';
  static const _legacyTsPrefix = 'community_stories_cache_ts_v1_';
  static const Duration maxAge = Duration(minutes: 15);

  static String _key(String? categoryId) => '${_prefix}_${categoryId ?? 'all'}';
  static String _tsKey(String? categoryId) =>
      '${_tsPrefix}_${categoryId ?? 'all'}';

  static Future<void> save(
    List<CommunityStoryDto> data, {
    required String? categoryId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await _purgeLegacyEntries(prefs);
    final jsonStr = jsonEncode(data.map((e) => e.toJson()).toList());
    await prefs.setString(_key(categoryId), jsonStr);
    await prefs.setInt(
      _tsKey(categoryId),
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  static Future<List<CommunityStoryDto>?> load({
    required String? categoryId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await _purgeLegacyEntries(prefs);
    final key = _key(categoryId);
    final timestampKey = _tsKey(categoryId);
    final ts = prefs.getInt(_tsKey(categoryId));
    if (ts == null || _isExpired(ts)) {
      await _removePair(prefs, key, timestampKey);
      return null;
    }
    final str = prefs.getString(key);
    if (str == null || str.isEmpty) {
      await _removePair(prefs, key, timestampKey);
      return null;
    }
    try {
      final list = jsonDecode(str) as List<dynamic>;
      return list
          .map((e) => CommunityStoryDto.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      await _removePair(prefs, key, timestampKey);
      return null;
    }
  }

  static Future<void> clear({String? categoryId}) async {
    final prefs = await SharedPreferences.getInstance();
    await _purgeLegacyEntries(prefs);
    if (categoryId != null) {
      await prefs.remove(_key(categoryId));
      await prefs.remove(_tsKey(categoryId));
    } else {
      // Clear all categories
      final keys = prefs.getKeys().where(
        (k) => k.startsWith(_prefix) || k.startsWith(_tsPrefix),
      );
      for (final k in keys) {
        await prefs.remove(k);
      }
    }
  }

  // Rive Elements cache
  static const _rivePrefix = 'rive_elements_cache_v2_';
  static const _riveTsPrefix = 'rive_elements_cache_ts_v2_';
  static const _legacyRivePrefix = 'rive_elements_cache_v1_';
  static const _legacyRiveTsPrefix = 'rive_elements_cache_ts_v1_';

  static Future<void> saveRiveElements(
    List<RiveElementDto> data,
    String? category,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await _purgeLegacyEntries(prefs);
    final jsonStr = jsonEncode(data.map((e) => e.toJson()).toList());
    final key = '$_rivePrefix${category ?? 'all'}';
    final tsKey = '$_riveTsPrefix${category ?? 'all'}';
    await prefs.setString(key, jsonStr);
    await prefs.setInt(tsKey, DateTime.now().millisecondsSinceEpoch);
  }

  static Future<List<RiveElementDto>?> loadRiveElements(
    String? category,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await _purgeLegacyEntries(prefs);
    final key = '$_rivePrefix${category ?? 'all'}';
    final tsKey = '$_riveTsPrefix${category ?? 'all'}';
    final ts = prefs.getInt(tsKey);
    if (ts == null || _isExpired(ts)) {
      await _removePair(prefs, key, tsKey);
      return null;
    }
    final str = prefs.getString(key);
    if (str == null || str.isEmpty) {
      await _removePair(prefs, key, tsKey);
      return null;
    }
    try {
      final list = jsonDecode(str) as List<dynamic>;
      return list
          .map((e) => RiveElementDto.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      await _removePair(prefs, key, tsKey);
      return null;
    }
  }

  static bool _isExpired(int timestamp) {
    final age = DateTime.now().millisecondsSinceEpoch - timestamp;
    return age < 0 || age >= maxAge.inMilliseconds;
  }

  static Future<void> _removePair(
    SharedPreferences prefs,
    String key,
    String timestampKey,
  ) async {
    await prefs.remove(key);
    await prefs.remove(timestampKey);
  }

  static Future<void> _purgeLegacyEntries(SharedPreferences prefs) async {
    final legacyKeys = prefs.getKeys().where(
      (key) =>
          key.startsWith(_legacyPrefix) ||
          key.startsWith(_legacyTsPrefix) ||
          key.startsWith(_legacyRivePrefix) ||
          key.startsWith(_legacyRiveTsPrefix),
    );
    for (final key in legacyKeys.toList(growable: false)) {
      await prefs.remove(key);
    }
  }
}
