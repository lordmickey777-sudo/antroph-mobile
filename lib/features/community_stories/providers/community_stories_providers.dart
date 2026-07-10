import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/state/auth_state.dart';
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

/// Fetch current user's community stories with user-scoped stale-while-refresh.
class MyStoriesNotifier extends AsyncNotifier<List<CommunityStoryDto>> {
  String? _activeCacheKey;
  int _generation = 0;

  @override
  Future<List<CommunityStoryDto>> build() async {
    final generation = ++_generation;
    final userId = ref.watch(
      authControllerProvider.select(
        (auth) => auth.asData?.value?.id.trim() ?? '',
      ),
    );
    if (userId.isEmpty) {
      _activeCacheKey = null;
      return const <CommunityStoryDto>[];
    }

    final cacheKey = 'my_stories:$userId';
    _activeCacheKey = cacheKey;
    final repo = ref.read(communityStoriesRepositoryProvider);
    final cached = await CommunityStoriesCacheService.load(
      categoryId: cacheKey,
    );
    if (cached != null) {
      _scheduleBackgroundRefresh(repo, cacheKey, generation);
      return cached;
    }

    final fresh = await _fetch(repo);
    if (_activeCacheKey == cacheKey && _generation == generation) {
      await CommunityStoriesCacheService.save(fresh, categoryId: cacheKey);
    }
    return fresh;
  }

  void _scheduleBackgroundRefresh(
    CommunityStoriesRepository repo,
    String cacheKey,
    int generation,
  ) {
    // Use the event queue so build can publish cached data before fresh data.
    unawaited(
      Future<void>(() async {
        try {
          final fresh = await _fetch(repo);
          if (_activeCacheKey == cacheKey && _generation == generation) {
            await CommunityStoriesCacheService.save(
              fresh,
              categoryId: cacheKey,
            );
          }
          if (_activeCacheKey == cacheKey && _generation == generation) {
            state = AsyncData(fresh);
          }
        } catch (_) {
          // Keep valid cached content visible when refresh fails.
        }
      }),
    );
  }

  Future<List<CommunityStoryDto>> _fetch(CommunityStoriesRepository repo) =>
      repo.fetchMyStories();

  Future<void> refreshNow() async {
    final cacheKey = _activeCacheKey;
    if (cacheKey == null) {
      state = const AsyncData(<CommunityStoryDto>[]);
      return;
    }
    final generation = ++_generation;
    final repo = ref.read(communityStoriesRepositoryProvider);
    final fresh = await _fetch(repo);
    if (_activeCacheKey == cacheKey && _generation == generation) {
      await CommunityStoriesCacheService.save(fresh, categoryId: cacheKey);
    }
    if (_activeCacheKey == cacheKey && _generation == generation) {
      state = AsyncData(fresh);
    }
  }
}

final myStoriesProvider =
    AsyncNotifierProvider<MyStoriesNotifier, List<CommunityStoryDto>>(
      MyStoriesNotifier.new,
    );

/// Fetch a single community story by ID.
final communityStoryDetailProvider = FutureProvider.autoDispose
    .family<CommunityStoryDto, String>((ref, storyId) async {
      final repo = ref.read(communityStoriesRepositoryProvider);
      return repo.fetchStory(storyId);
    });

/// Browse published community stories. Pass categoryId or null for all.
class CommunityBrowseNotifier extends AsyncNotifier<List<CommunityStoryDto>> {
  CommunityBrowseNotifier(this.categoryId);

  final String? categoryId;
  int _generation = 0;

  String get _cacheKey => '${categoryId ?? 'all'}:approved_published_v1';

  @override
  Future<List<CommunityStoryDto>> build() async {
    final generation = ++_generation;
    final repo = ref.read(communityStoriesRepositoryProvider);
    final cached = await CommunityStoriesCacheService.load(
      categoryId: _cacheKey,
    );
    if (cached != null) {
      _scheduleBackgroundRefresh(repo, generation);
      return _visibleStories(cached);
    }

    final fresh = await _fetch(repo);
    if (_generation == generation) {
      await CommunityStoriesCacheService.save(fresh, categoryId: _cacheKey);
    }
    return fresh;
  }

  void _scheduleBackgroundRefresh(
    CommunityStoriesRepository repo,
    int generation,
  ) {
    // Updating state directly avoids self-invalidation loops when signed URLs
    // differ between otherwise identical responses.
    unawaited(
      Future<void>(() async {
        try {
          final fresh = await _fetch(repo);
          if (_generation == generation) {
            await CommunityStoriesCacheService.save(
              fresh,
              categoryId: _cacheKey,
            );
          }
          if (_generation == generation) state = AsyncData(fresh);
        } catch (_) {
          // Keep valid cached content visible when refresh fails.
        }
      }),
    );
  }

  Future<List<CommunityStoryDto>> _fetch(
    CommunityStoriesRepository repo,
  ) async {
    final stories = await repo.browseCommunityStories(categoryId: categoryId);
    return _visibleStories(stories);
  }

  List<CommunityStoryDto> _visibleStories(List<CommunityStoryDto> stories) {
    return stories.where((story) => story.isApprovedAndPublished).toList();
  }

  Future<void> refreshNow() async {
    final generation = ++_generation;
    final repo = ref.read(communityStoriesRepositoryProvider);
    final fresh = await _fetch(repo);
    if (_generation == generation) {
      await CommunityStoriesCacheService.save(fresh, categoryId: _cacheKey);
    }
    if (_generation == generation) state = AsyncData(fresh);
  }
}

final communityBrowseProvider =
    AsyncNotifierProvider.family<
      CommunityBrowseNotifier,
      List<CommunityStoryDto>,
      String?
    >(CommunityBrowseNotifier.new);
