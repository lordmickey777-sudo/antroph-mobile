import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

enum StoryRecentSearchType { text, category, story, featured }

class StoryRecentSearch {
  const StoryRecentSearch({
    required this.value,
    this.type = StoryRecentSearchType.text,
    this.image,
  });

  final String value;
  final StoryRecentSearchType type;
  final String? image;

  String encode() {
    return jsonEncode({
      'value': value,
      'type': type.name,
      if (image != null && image!.trim().isNotEmpty) 'image': image,
    });
  }

  static StoryRecentSearch decode(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, Object?>) {
        final value = (decoded['value'] as String?)?.trim() ?? '';
        if (value.isEmpty) return const StoryRecentSearch(value: '');
        final typeName = decoded['type'] as String?;
        return StoryRecentSearch(
          value: value,
          type: StoryRecentSearchType.values.firstWhere(
            (type) => type.name == typeName,
            orElse: () => StoryRecentSearchType.text,
          ),
          image: (decoded['image'] as String?)?.trim(),
        );
      }
    } catch (_) {
      // Older app versions stored raw search strings.
    }
    return StoryRecentSearch(value: raw.trim());
  }
}

class StorySearchStorageService {
  static const _recentSearchesKey = 'story_recent_searches';
  static const maxRecentSearches = 8;

  static Future<List<StoryRecentSearch>> loadRecentSearchItems() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs
            .getStringList(_recentSearchesKey)
            ?.map(StoryRecentSearch.decode)
            .where((item) => item.value.isNotEmpty)
            .where(
              (item) =>
                  item.type == StoryRecentSearchType.story ||
                  item.type == StoryRecentSearchType.featured,
            )
            .toList() ??
        const <StoryRecentSearch>[];
  }

  static Future<List<String>> loadRecentSearches() async {
    final items = await loadRecentSearchItems();
    return items.map((item) => item.value).toList();
  }

  static Future<void> saveSearch(
    String value, {
    StoryRecentSearchType type = StoryRecentSearchType.text,
    String? image,
  }) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;
    if (type != StoryRecentSearchType.story &&
        type != StoryRecentSearchType.featured) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final existing = await loadRecentSearchItems();
    final normalized = _normalize(trimmed);
    final next = <StoryRecentSearch>[
      StoryRecentSearch(value: trimmed, type: type, image: image?.trim()),
      ...existing.where((item) => _normalize(item.value) != normalized),
    ].take(maxRecentSearches).map((item) => item.encode()).toList();

    await prefs.setStringList(_recentSearchesKey, next);
  }

  static Future<void> clearRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_recentSearchesKey);
  }

  static String _normalize(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }
}
