import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/stories_repository.dart';
import '../models/story_models.dart';
import '../models/story_detail.dart';
import '../../../core/network/error_formatter.dart';

final storiesRepositoryProvider = Provider<StoriesRepository>((ref) {
  return StoriesRepository();
});

final storiesHomeSectionsProvider = FutureProvider.autoDispose<StoriesHomeResponse>((ref) async {
  final repo = ref.read(storiesRepositoryProvider);
  try {
    final res = await repo.fetchHomeSections();
    return res;
  } on ApiError catch (e) {
    // Re-throw to preserve typed error upstream
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
