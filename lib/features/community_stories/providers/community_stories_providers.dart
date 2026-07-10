import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/community_stories_repository.dart';
import '../models/community_story_model.dart';
import '../models/rive_element_model.dart';
import '../data/community_stories_cache.dart';

final communityStoriesRepositoryProvider = Provider<CommunityStoriesRepository>(
  (ref) {
    return CommunityStoriesRepository();
  },
);

/// Fetch active Rive elements. Pass category or null for all.
final riveElementsProvider =
    FutureProvider.family<List<RiveElementDto>, String?>((ref, category) async {
      final repo = ref.read(communityStoriesRepositoryProvider);

      // Return disk cache immediately while refreshing in background
      final cached = await CommunityStoriesCacheService.loadRiveElements(
        category,
      );
      if (cached != null) {
        () async {
          try {
            final fresh = await repo.fetchRiveElements(category: category);
            await CommunityStoriesCacheService.saveRiveElements(
              fresh,
              category,
            );
          } catch (_) {}
        }();
        return cached;
      }

      final res = await repo.fetchRiveElements(category: category);
      await CommunityStoriesCacheService.saveRiveElements(res, category);
      return res;
    });

/// Fetch current user's community stories.
final myStoriesProvider = FutureProvider<List<CommunityStoryDto>>((ref) async {
  final repo = ref.read(communityStoriesRepositoryProvider);

  // Return disk cache immediately while refreshing in background
  final cached = await CommunityStoriesCacheService.load(
    categoryId: 'my_stories',
  );
  if (cached != null) {
    print('DEBUG: myStoriesProvider - CACHE HIT');
    () async {
      try {
        final fresh = await repo.fetchMyStories();
        print('DEBUG: myStoriesProvider - Background Refresh Success');
        await CommunityStoriesCacheService.save(
          fresh,
          categoryId: 'my_stories',
        );
      } catch (e) {
        print('DEBUG: myStoriesProvider - Background Refresh Error: $e');
      }
    }();
    return cached;
  }
  print('DEBUG: myStoriesProvider - CACHE MISS');

  final res = await repo.fetchMyStories();
  await CommunityStoriesCacheService.save(res, categoryId: 'my_stories');
  return res;
});

/// Fetch a single community story by ID.
final communityStoryDetailProvider = FutureProvider.autoDispose
    .family<CommunityStoryDto, String>((ref, storyId) async {
      final repo = ref.read(communityStoriesRepositoryProvider);
      return repo.fetchStory(storyId);
    });

/// Browse published community stories. Pass categoryId or null for all.
final communityBrowseProvider =
    FutureProvider.family<List<CommunityStoryDto>, String?>((
      ref,
      categoryId,
    ) async {
      final repo = ref.read(communityStoriesRepositoryProvider);
      final cacheCategoryId = '${categoryId ?? 'all'}:approved_published_v1';

      Future<List<CommunityStoryDto>> fetchStories() async {
        final stories = await repo.browseCommunityStories(
          categoryId: categoryId,
        );
        return stories.where((story) => story.isApprovedAndPublished).toList();
      }

      // Return disk cache immediately while refreshing in background
      final cached = await CommunityStoriesCacheService.load(
        categoryId: cacheCategoryId,
      );
      if (cached != null) {
        print('DEBUG: communityBrowseProvider($categoryId) - CACHE HIT');
        final visibleCached = cached
            .where((story) => story.isApprovedAndPublished)
            .toList();
        () async {
          try {
            final fresh = await fetchStories();
            print(
              'DEBUG: communityBrowseProvider($categoryId) - Background Refresh Success',
            );
            await CommunityStoriesCacheService.save(
              fresh,
              categoryId: cacheCategoryId,
            );
          } catch (e) {
            print(
              'DEBUG: communityBrowseProvider($categoryId) - Background Refresh Error: $e',
            );
          }
        }();
        return visibleCached;
      }
      print('DEBUG: communityBrowseProvider($categoryId) - CACHE MISS');

      final res = await fetchStories();
      await CommunityStoriesCacheService.save(res, categoryId: cacheCategoryId);
      return res;
    });
