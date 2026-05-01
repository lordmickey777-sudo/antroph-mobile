import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/story_playlists_models.dart';

class PlaylistCacheService {
  static const _playlistsKey = 'story_playlists_cache_v1';
  static const _playlistsTsKey = 'story_playlists_cache_ts_v1';
  
  static const _detailPrefix = 'playlist_detail_cache_v1_';
  static const _detailTsPrefix = 'playlist_detail_cache_ts_v1_';
  
  static const Duration maxAge = Duration(minutes: 15);

  static Future<void> savePlaylists(List<PlaylistDto> data) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(data.map((e) => e.toJson()).toList());
    await prefs.setString(_playlistsKey, jsonStr);
    await prefs.setInt(_playlistsTsKey, DateTime.now().millisecondsSinceEpoch);
  }

  static Future<List<PlaylistDto>?> loadPlaylists() async {
    final prefs = await SharedPreferences.getInstance();
    final ts = prefs.getInt(_playlistsTsKey);
    if (ts == null) return null;
    final str = prefs.getString(_playlistsKey);
    if (str == null || str.isEmpty) return null;
    try {
      final list = jsonDecode(str) as List<dynamic>;
      return list.map((e) => PlaylistDto.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return null;
    }
  }

  static Future<void> savePlaylistDetail(String id, PlaylistDetailDto data) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(data.toJson());
    await prefs.setString('${_detailPrefix}$id', jsonStr);
    await prefs.setInt('${_detailTsPrefix}$id', DateTime.now().millisecondsSinceEpoch);
  }

  static Future<PlaylistDetailDto?> loadPlaylistDetail(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final ts = prefs.getInt('${_detailTsPrefix}$id');
    if (ts == null) return null;
    final str = prefs.getString('${_detailPrefix}$id');
    if (str == null || str.isEmpty) return null;
    try {
      final map = jsonDecode(str) as Map<String, dynamic>;
      return PlaylistDetailDto.fromJson(map);
    } catch (_) {
      return null;
    }
  }
}
