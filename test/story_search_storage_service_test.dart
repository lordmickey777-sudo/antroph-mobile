import 'package:antroph_mobile/features/story/data/story_search_storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('StorySearchStorageService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('saves and loads recent searches newest first', () async {
      await StorySearchStorageService.saveSearch(
        'Mystery',
        type: StoryRecentSearchType.story,
      );
      await StorySearchStorageService.saveSearch(
        'Adventure',
        type: StoryRecentSearchType.story,
      );

      expect(await StorySearchStorageService.loadRecentSearches(), [
        'Adventure',
        'Mystery',
      ]);
    });

    test('dedupes recent searches case-insensitively', () async {
      await StorySearchStorageService.saveSearch(
        ' Mystery ',
        type: StoryRecentSearchType.story,
      );
      await StorySearchStorageService.saveSearch(
        'mystery',
        type: StoryRecentSearchType.story,
      );

      expect(await StorySearchStorageService.loadRecentSearches(), ['mystery']);
    });

    test('caps recent searches at eight items', () async {
      for (var i = 0; i < 10; i++) {
        await StorySearchStorageService.saveSearch(
          'search $i',
          type: StoryRecentSearchType.story,
        );
      }

      final recents = await StorySearchStorageService.loadRecentSearches();
      expect(recents, hasLength(StorySearchStorageService.maxRecentSearches));
      expect(recents.first, 'search 9');
      expect(recents.last, 'search 2');
    });

    test('clears recent searches', () async {
      await StorySearchStorageService.saveSearch(
        'Mystery',
        type: StoryRecentSearchType.story,
      );
      await StorySearchStorageService.clearRecentSearches();

      expect(await StorySearchStorageService.loadRecentSearches(), isEmpty);
    });

    test('saves and loads recent search metadata', () async {
      await StorySearchStorageService.saveSearch(
        'A Story',
        type: StoryRecentSearchType.story,
        image: 'https://example.com/story.jpg',
      );

      final items = await StorySearchStorageService.loadRecentSearchItems();

      expect(items, hasLength(1));
      expect(items.single.value, 'A Story');
      expect(items.single.type, StoryRecentSearchType.story);
      expect(items.single.image, 'https://example.com/story.jpg');
    });

    test('excludes category and text searches from recents', () async {
      await StorySearchStorageService.saveSearch('Food');
      await StorySearchStorageService.saveSearch(
        'Cooking',
        type: StoryRecentSearchType.category,
      );
      await StorySearchStorageService.saveSearch(
        'A Story',
        type: StoryRecentSearchType.story,
      );

      expect(await StorySearchStorageService.loadRecentSearches(), ['A Story']);
    });
  });
}
