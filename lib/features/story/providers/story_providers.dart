import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/stories_repository.dart';
import '../models/story_models.dart';
import '../models/story_detail.dart';
import '../../../core/network/error_formatter.dart';
import '../../../core/auth/state/auth_state.dart';
import '../data/stories_cache.dart';

final storiesRepositoryProvider = Provider<StoriesRepository>((ref) {
  return StoriesRepository();
});

/// Stable boolean derived from auth state.
/// Only changes on login/logout, not during loading transitions.
final _isAuthenticatedProvider = Provider.autoDispose<bool>((ref) {
  return ref.watch(authControllerProvider).asData?.value != null;
});

/// Hybrid provider: returns cached data immediately when available, then refreshes from network.
/// Watches auth state so stories refresh automatically when user logs in/out
/// (the API returns personalized data for authenticated users).
final storiesHomeSectionsProvider = FutureProvider.autoDispose<StoriesHomeResponse>((ref) async {
  final repo = ref.read(storiesRepositoryProvider);
  final isAuthenticated = ref.watch(_isAuthenticatedProvider);

  // Try cache first (cache validates auth context to avoid serving stale guest data)
  final cached = await StoriesCacheService.load(isAuthenticated: isAuthenticated);
  if (cached != null) {
    // Background refresh; ignore result/errors.
    () async {
      try {
        final fresh = await repo.fetchHomeSections();
        await StoriesCacheService.save(fresh, isAuthenticated: isAuthenticated);
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
