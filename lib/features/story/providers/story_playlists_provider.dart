import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/story_playlists_models.dart';
import 'story_providers.dart';
import '../data/playlist_cache.dart';

final storyPlaylistsProvider = FutureProvider<List<PlaylistDto>>((ref) async {
  final repo = ref.read(storiesRepositoryProvider);

  // Return disk cache immediately while refreshing in background
  final cached = await PlaylistCacheService.loadPlaylists();
  if (cached != null) {
    print('DEBUG: storyPlaylistsProvider - CACHE HIT');
    () async {
      try {
        final fresh = await repo.fetchPlaylists();
        print('DEBUG: storyPlaylistsProvider - Background Refresh Success');
        await PlaylistCacheService.savePlaylists(fresh);
      } catch (e) {
        print('DEBUG: storyPlaylistsProvider - Background Refresh Error: $e');
      }
    }();
    return cached;
  }
  print('DEBUG: storyPlaylistsProvider - CACHE MISS');

  final res = await repo.fetchPlaylists();
  await PlaylistCacheService.savePlaylists(res);
  return res;
});

final playlistDetailProvider = FutureProvider.family<PlaylistDetailDto, String>(
  (ref, playlistId) async {
    final repo = ref.read(storiesRepositoryProvider);

    // Return disk cache immediately while refreshing in background
    final cached = await PlaylistCacheService.loadPlaylistDetail(playlistId);
    if (cached != null) {
      print('DEBUG: playlistDetailProvider($playlistId) - CACHE HIT');
      () async {
        try {
          final fresh = await repo.fetchPlaylistDetail(playlistId);
          print('DEBUG: playlistDetailProvider($playlistId) - Background Refresh Success');
          await PlaylistCacheService.savePlaylistDetail(playlistId, fresh);
        } catch (e) {
          print('DEBUG: playlistDetailProvider($playlistId) - Background Refresh Error: $e');
        }
      }();
      return cached;
    }
    print('DEBUG: playlistDetailProvider($playlistId) - CACHE MISS');

    final res = await repo.fetchPlaylistDetail(playlistId);
    await PlaylistCacheService.savePlaylistDetail(playlistId, res);
    return res;
  },
);
