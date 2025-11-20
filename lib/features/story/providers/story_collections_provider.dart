import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/stories_repository.dart';
import '../models/story_collections_models.dart';
import 'story_providers.dart';

final storyCollectionsProvider = FutureProvider.autoDispose<List<StoryCollectionDto>>((ref) async {
  final repo = ref.read(storiesRepositoryProvider);
  return repo.fetchCollections();
});

final storyCollectionDetailProvider = FutureProvider.family.autoDispose<StoryCollectionDetailDto, String>(
  (ref, collectionId) async {
    final repo = ref.read(storiesRepositoryProvider);
    return repo.fetchCollectionDetail(collectionId);
  },
);
