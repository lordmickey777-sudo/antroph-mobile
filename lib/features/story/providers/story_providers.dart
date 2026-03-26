import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/stories_repository.dart';
import '../models/story_models.dart';
import '../models/story_detail.dart';
import '../services/mascot_cache_service.dart';
import '../services/rive_registry_service.dart';
import '../../../core/db/app_database.dart';
import '../../../core/network/error_formatter.dart';
import '../../../core/auth/state/auth_state.dart';
import '../../community_stories/models/rive_element_model.dart';
import '../data/stories_cache.dart';

final storiesRepositoryProvider = Provider<StoriesRepository>((ref) {
  return StoriesRepository();
});

final riveRegistryServiceProvider = Provider<RiveRegistryService>((ref) {
  final database = ref.read(databaseProvider);
  late final RiveRegistryService registry;
  final mascotCacheService = MascotCacheService(
    onFilesDeleted: (paths) => registry.clearLocalPathsForFiles(paths),
  );
  registry = RiveRegistryService(
    database: database,
    mascotCacheService: mascotCacheService,
  );
  return registry;
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
      final riveRegistry = ref.read(riveRegistryServiceProvider);
      final isAuthenticated = ref.watch(_isAuthenticatedProvider);

      // Try cache first (cache validates auth context to avoid serving stale guest data)
      final cached = await StoriesCacheService.load(
        isAuthenticated: isAuthenticated,
      );
      if (cached != null) {
        unawaited(riveRegistry.syncManifest().catchError((_) {}));
        _preloadStoryMascots(riveRegistry, cached);
        // Background refresh; ignore result/errors.
        () async {
          try {
            final fresh = await repo.fetchHomeSections();
            await StoriesCacheService.save(
              fresh,
              isAuthenticated: isAuthenticated,
            );
            unawaited(riveRegistry.syncManifest().catchError((_) {}));
            _preloadStoryMascots(riveRegistry, fresh);
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
        unawaited(riveRegistry.syncManifest().catchError((_) {}));
        _preloadStoryMascots(riveRegistry, res);
        return res;
      } on ApiError {
        rethrow;
      }
    });

final continuePlayingProvider =
    FutureProvider.autoDispose<List<ContinuePlayingDto>>((ref) async {
      final isAuthenticated = ref.watch(_isAuthenticatedProvider);
      if (!isAuthenticated) return const [];

      final repo = ref.read(storiesRepositoryProvider);
      try {
        return await repo.fetchContinuePlaying();
      } on ApiError {
        rethrow;
      }
    });

/// Fetch a single story detail by id
final storyDetailProvider = FutureProvider.family
    .autoDispose<StoryDetailDto, String>((ref, id) async {
      final repo = ref.read(storiesRepositoryProvider);
      final riveRegistry = ref.read(riveRegistryServiceProvider);
      try {
        final detail = await repo.fetchStoryDetail(id);
        final enriched = await riveRegistry.attachLocalMascot(detail);
        unawaited(
          riveRegistry.cacheElementFromDetail(detail).catchError((_) {}),
        );
        unawaited(riveRegistry.syncManifest().catchError((_) {}));
        return enriched;
      } on ApiError {
        rethrow;
      }
    });

void _preloadStoryMascots(
  RiveRegistryService registry,
  StoriesHomeResponse response,
) {
  final elementIds = <String>{};
  final riveElements = <RiveElementDto>[];

  for (final section in response.sections) {
    for (final story in section.items) {
      final riveElement = story.riveElement;
      if (riveElement != null) {
        riveElements.add(riveElement);
        continue;
      }
      final elementId = story.riveElementId?.trim() ?? '';
      if (elementId.isNotEmpty) elementIds.add(elementId);
    }
  }

  for (final story in response.featuredStories) {
    final riveElement = story.riveElement;
    if (riveElement != null) {
      riveElements.add(riveElement);
      continue;
    }
    final elementId = story.riveElementId?.trim() ?? '';
    if (elementId.isNotEmpty) elementIds.add(elementId);
  }

  if (riveElements.isNotEmpty) {
    unawaited(() async {
      for (final element in riveElements) {
        try {
          await registry.cacheElementDto(element);
        } catch (_) {
          // Best-effort preload.
        }
      }
    }());
  }
  if (elementIds.isNotEmpty) {
    unawaited(() async {
      for (final elementId in elementIds) {
        try {
          await registry.ensureElementById(elementId);
        } catch (_) {
          // Best-effort preload.
        }
      }
    }());
  }
}
