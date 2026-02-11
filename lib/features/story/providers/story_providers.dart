import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/stories_repository.dart';
import '../models/mascot_model.dart';
import '../models/story_models.dart';
import '../models/story_detail.dart';
import '../services/mascot_cache_service.dart';
import '../../../core/network/error_formatter.dart';
import '../../../core/auth/state/auth_state.dart';
import '../data/stories_cache.dart';

final storiesRepositoryProvider = Provider<StoriesRepository>((ref) {
  return StoriesRepository();
});

final mascotCacheServiceProvider = Provider<MascotCacheService>((ref) {
  return MascotCacheService();
});

/// Stable boolean derived from auth state.
/// Only changes on login/logout, not during loading transitions.
final _isAuthenticatedProvider = Provider.autoDispose<bool>((ref) {
  return ref.watch(authControllerProvider).asData?.value != null;
});

/// Hybrid provider: returns cached data immediately when available, then refreshes from network.
/// Watches auth state so stories refresh automatically when user logs in/out
/// (the API returns personalized data for authenticated users).
final storiesHomeSectionsProvider =
    FutureProvider.autoDispose<StoriesHomeResponse>((ref) async {
      final repo = ref.read(storiesRepositoryProvider);
      final mascotCache = ref.read(mascotCacheServiceProvider);
      final isAuthenticated = ref.watch(_isAuthenticatedProvider);

      // Try cache first (cache validates auth context to avoid serving stale guest data)
      final cached = await StoriesCacheService.load(
        isAuthenticated: isAuthenticated,
      );
      if (cached != null) {
        _preloadStoryMascots(mascotCache, cached);
        // Background refresh; ignore result/errors.
        () async {
          try {
            final fresh = await repo.fetchHomeSections();
            await StoriesCacheService.save(
              fresh,
              isAuthenticated: isAuthenticated,
            );
            _preloadStoryMascots(mascotCache, fresh);
          } catch (_) {
            // swallow
          }
        }();
        return cached;
      }
      // No cache: fetch from network
      try {
        final res = await repo.fetchHomeSections();
        await StoriesCacheService.save(res, isAuthenticated: isAuthenticated);
        _preloadStoryMascots(mascotCache, res);
        return res;
      } on ApiError {
        rethrow;
      }
    });

/// Fetch a single story detail by id
final storyDetailProvider = FutureProvider.family
    .autoDispose<StoryDetailDto, String>((ref, id) async {
      final repo = ref.read(storiesRepositoryProvider);
      try {
        return await repo.fetchStoryDetail(id);
      } on ApiError {
        rethrow;
      }
    });

void _preloadStoryMascots(
  MascotCacheService cache,
  StoriesHomeResponse response,
) {
  final mascotIds = <String>{};
  final mascotConfigs = <MascotConfig>[];

  for (final section in response.sections) {
    for (final story in section.items) {
      final mascot = story.mascot;
      if (mascot != null) {
        mascotConfigs.add(mascot);
        continue;
      }
      final mascotId = story.mascotId?.trim() ?? '';
      if (mascotId.isNotEmpty) mascotIds.add(mascotId);
    }
  }

  for (final story in response.featuredStories) {
    final mascot = story.mascot;
    if (mascot != null) {
      mascotConfigs.add(mascot);
      continue;
    }
    final mascotId = story.mascotId?.trim() ?? '';
    if (mascotId.isNotEmpty) mascotIds.add(mascotId);
  }

  if (mascotConfigs.isNotEmpty) {
    unawaited(cache.preloadMascotConfigs(mascotConfigs));
  }
  if (mascotIds.isNotEmpty) {
    unawaited(cache.preloadMascots(mascotIds.toList()));
  }
}
