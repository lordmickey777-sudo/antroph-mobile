import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/community_stories_repository.dart';
import '../models/community_story_model.dart';
import '../models/rive_element_model.dart';

final communityStoriesRepositoryProvider =
    Provider<CommunityStoriesRepository>((ref) {
  return CommunityStoriesRepository();
});

/// Fetch active Rive elements. Pass category or null for all.
final riveElementsProvider = FutureProvider.autoDispose
    .family<List<RiveElementDto>, String?>((ref, category) async {
  final repo = ref.read(communityStoriesRepositoryProvider);
  return repo.fetchRiveElements(category: category);
});

/// Fetch current user's community stories.
final myStoriesProvider =
    FutureProvider.autoDispose<List<CommunityStoryDto>>((ref) async {
  final repo = ref.read(communityStoriesRepositoryProvider);
  return repo.fetchMyStories();
});

/// Fetch a single community story by ID.
final communityStoryDetailProvider = FutureProvider.autoDispose
    .family<CommunityStoryDto, String>((ref, storyId) async {
  final repo = ref.read(communityStoriesRepositoryProvider);
  return repo.fetchStory(storyId);
});

/// Browse published community stories. Pass categoryId or null for all.
final communityBrowseProvider = FutureProvider.autoDispose
    .family<List<CommunityStoryDto>, String?>((ref, categoryId) async {
  final repo = ref.read(communityStoriesRepositoryProvider);
  return repo.browseCommunityStories(categoryId: categoryId);
});
