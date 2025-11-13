import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/stories_repository.dart';
import '../models/story_models.dart';
import '../models/story_detail.dart';
import '../../../core/network/error_formatter.dart';
import '../data/stories_cache.dart';

final storiesRepositoryProvider = Provider<StoriesRepository>((ref) {
  return StoriesRepository();
});

/// Hybrid provider: returns cached data immediately when available, then refreshes from network.
final storiesHomeSectionsProvider = FutureProvider.autoDispose<StoriesHomeResponse>((ref) async {
  final repo = ref.read(storiesRepositoryProvider);
  // Try cache first
  final cached = await StoriesCacheService.load();
  if (cached != null) {
    // Fire-and-forget refresh; listeners will be able to refetch manually when needed.
    // For a more reactive refresh, consider using a Notifier and state.
    // We still return cached immediately to avoid infinite shimmer.
    // Attempt to refresh in background; ignore errors.
    // Background refresh; ignore result/errors.
    () async {
      try {
        final fresh = await repo.fetchHomeSections();
        await StoriesCacheService.save(fresh);
      } catch (_) {
        // swallow
      }
    }();
    return cached;
  }
  // No cache: fetch from network
  try {
    final res = await repo.fetchHomeSections();
    await StoriesCacheService.save(res);
    return res;
  } on ApiError catch (e) {
    throw e;
  }
});

/// Fetch a single story detail by id
final storyDetailProvider = FutureProvider.family.autoDispose<StoryDetailDto, String>((
  ref,
  id,
) async {
  final repo = ref.read(storiesRepositoryProvider);
  try {
    return await repo.fetchStoryDetail(id);
  } on ApiError catch (e) {
    throw e;
  }
});
