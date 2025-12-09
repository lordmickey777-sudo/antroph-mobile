import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/story_playlists_models.dart';
import 'story_providers.dart';

final storyPlaylistsProvider = FutureProvider.autoDispose<List<PlaylistDto>>((ref) async {
  final repo = ref.read(storiesRepositoryProvider);
  return repo.fetchPlaylists();
});

final playlistDetailProvider = FutureProvider.family.autoDispose<PlaylistDetailDto, String>(
  (ref, playlistId) async {
    final repo = ref.read(storiesRepositoryProvider);
    return repo.fetchPlaylistDetail(playlistId);
  },
);
