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
import '../data/continue_playing_cache.dart';

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
final _isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(
    authControllerProvider.select((v) => v.asData?.value != null),
  );
});

/// Hybrid provider: returns cached data immediately when available, then refreshes from network.
/// Watches auth state so stories refresh automatically when user logs in/out
/// (the API returns personalized data for authenticated users).
class StoriesHomeSectionsNotifier extends AsyncNotifier<StoriesHomeResponse> {
  @override
  Future<StoriesHomeResponse> build() async {
    final repo = ref.read(storiesRepositoryProvider);
    final riveRegistry = ref.read(riveRegistryServiceProvider);
    final isAuthenticated = ref.watch(_isAuthenticatedProvider);

    // Try cache first
    final cached = await StoriesCacheService.load(
      isAuthenticated: isAuthenticated,
    );

    if (cached != null) {
      unawaited(riveRegistry.syncManifest().catchError((_) {}));
      _preloadStoryMascots(riveRegistry, cached);

      // Trigger background refresh to update the UI if data changed on backend
      _refreshInBackground(repo, riveRegistry, isAuthenticated);

      return cached;
    }

    return _fetchFromNetwork(repo, riveRegistry, isAuthenticated);
  }

  Future<void> _refreshInBackground(
    StoriesRepository repo,
    RiveRegistryService riveRegistry,
    bool isAuthenticated,
  ) async {
    try {
      final fresh = await repo.fetchHomeSections();
      await StoriesCacheService.save(fresh, isAuthenticated: isAuthenticated);
      unawaited(riveRegistry.syncManifest().catchError((_) {}));
      _preloadStoryMascots(riveRegistry, fresh);

      // Update state so UI reflects the new data from backend
      state = AsyncData(fresh);
    } catch (_) {
      // Keep cached content visible when a background refresh fails.
    }
  }

  Future<StoriesHomeResponse> _fetchFromNetwork(
    StoriesRepository repo,
    RiveRegistryService riveRegistry,
    bool isAuthenticated,
  ) async {
    final res = await repo.fetchHomeSections();
    await StoriesCacheService.save(res, isAuthenticated: isAuthenticated);
    unawaited(riveRegistry.syncManifest().catchError((_) {}));
    _preloadStoryMascots(riveRegistry, res);
    return res;
  }

  Future<void> refreshNow() async {
    final repo = ref.read(storiesRepositoryProvider);
    final riveRegistry = ref.read(riveRegistryServiceProvider);
    final isAuthenticated = ref.read(_isAuthenticatedProvider);
    final fresh = await _fetchFromNetwork(repo, riveRegistry, isAuthenticated);
    state = AsyncData(fresh);
  }
}

final storiesHomeSectionsProvider =
    AsyncNotifierProvider<StoriesHomeSectionsNotifier, StoriesHomeResponse>(
      StoriesHomeSectionsNotifier.new,
    );

class ContinuePlayingNotifier extends AsyncNotifier<List<ContinuePlayingDto>> {
  @override
  Future<List<ContinuePlayingDto>> build() async {
    final isAuthenticated = ref.watch(_isAuthenticatedProvider);
    if (!isAuthenticated) return const [];

    final repo = ref.read(storiesRepositoryProvider);

    // Return disk cache immediately while refreshing in background
    final cached = await ContinuePlayingCacheService.load();
    if (cached != null) {
      _refreshInBackground(repo);
      return cached;
    }

    final res = await repo.fetchContinuePlaying();
    await ContinuePlayingCacheService.save(res);
    return res;
  }

  Future<void> _refreshInBackground(StoriesRepository repo) async {
    try {
      final fresh = await repo.fetchContinuePlaying();
      await ContinuePlayingCacheService.save(fresh);
      state = AsyncData(fresh);
    } catch (_) {
      // Keep cached content visible when a background refresh fails.
    }
  }

  Future<void> refreshNow() async {
    final isAuthenticated = ref.read(_isAuthenticatedProvider);
    if (!isAuthenticated) {
      state = const AsyncData([]);
      return;
    }
    final repo = ref.read(storiesRepositoryProvider);
    final fresh = await repo.fetchContinuePlaying();
    await ContinuePlayingCacheService.save(fresh);
    state = AsyncData(fresh);
  }
}

final continuePlayingProvider =
    AsyncNotifierProvider<ContinuePlayingNotifier, List<ContinuePlayingDto>>(
      ContinuePlayingNotifier.new,
    );

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
