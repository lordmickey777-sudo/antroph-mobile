import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/error_formatter.dart';
import '../models/story_models.dart';
import '../models/story_playlists_models.dart';
import '../models/story_detail.dart';
import '../models/story_session.dart';

class StoriesRepository {
  StoriesRepository({Dio? dio}) : _dio = dio ?? ApiClient.I.dio;
  final Dio _dio;

  /// Fetch home sections for stories page.
  /// Public endpoint; no auth required.
  Future<StoriesHomeResponse> fetchHomeSections({
    int limitPerSection = 6,
    int collectionsPage = 1,
    int collectionsPageSize = 10,
  }) async {
    try {
      final res = await _dio.get(
        '/stories/home',
        queryParameters: {
          'limit_per_section': limitPerSection,
          'collections_page': collectionsPage,
          'collections_page_size': collectionsPageSize,
        },
        options: Options(extra: const {'skipAuth': true}),
      );
      final data = res.data as Map<String, dynamic>;
      return StoriesHomeResponse.fromJson(data);
    } on DioException catch (e) {
      throw ErrorFormatter.fromDio(e);
    }
  }

  Future<List<PlaylistDto>> fetchPlaylists() async {
    try {
      final res = await _dio.get('/playlists');
      final data = res.data as List;
      return data
          .cast<Map<String, dynamic>>()
          .map((e) => PlaylistDto.fromJson(e))
          .toList();
    } on DioException catch (e) {
      throw ErrorFormatter.fromDio(e);
    }
  }

  Future<PlaylistDetailDto> fetchPlaylistDetail(String playlistId) async {
    try {
      final res = await _dio.get('/playlists/$playlistId');
      final data = res.data as Map<String, dynamic>;
      return PlaylistDetailDto.fromJson(data);
    } on DioException catch (e) {
      throw ErrorFormatter.fromDio(e);
    }
  }

  Future<void> addStoriesToPlaylist({
    required String playlistId,
    required List<String> storyIds,
    int? position,
  }) async {
    try {
      final payload = <String, dynamic>{
        'story_ids': storyIds,
      };
      if (position != null) {
        payload['position'] = position;
      }
      await _dio.post('/playlists/$playlistId/stories', data: payload);
    } on DioException catch (e) {
      throw ErrorFormatter.fromDio(e);
    }
  }

  /// Fetch detailed story information by ID.
  /// Public endpoint; no auth required.
  Future<StoryDetailDto> fetchStoryDetail(String storyId) async {
    try {
      final res = await _dio.get(
        '/stories/$storyId',
        options: Options(extra: const {'skipAuth': true}),
      );
      final data = res.data as Map<String, dynamic>;
      return StoryDetailDto.fromJson(data);
    } on DioException catch (e) {
      throw ErrorFormatter.fromDio(e);
    }
  }

  /// Start a new story session or resume existing one.
  /// Requires authentication.
  Future<StorySession> startSession({
    required String storyId,
    required String deviceType,
    required String deviceId,
  }) async {
    try {
      final res = await _dio.post(
        '/stories/$storyId/start',
        data: {"device_type": 'mobile', "device_id": 'null', "autoplay": true},
      );
      final data = res.data as Map<String, dynamic>;
      return StorySession.fromJson(data);
    } on DioException catch (e) {
      throw ErrorFormatter.fromDio(e);
    }
  }

  /// Pause the current active story session.
  /// Requires authentication.
  Future<StorySession> pauseSession(String storyId) async {
    try {
      final res = await _dio.post('/stories/$storyId/session/pause');
      final data = res.data as Map<String, dynamic>;
      return StorySession.fromJson(data);
    } on DioException catch (e) {
      throw ErrorFormatter.fromDio(e);
    }
  }

  /// Resume (unpause) the current active story session.
  /// Requires authentication.
  Future<StorySession> playSession(String storyId) async {
    try {
      final res = await _dio.post('/stories/$storyId/session/play');
      final data = res.data as Map<String, dynamic>;
      return StorySession.fromJson(data);
    } on DioException catch (e) {
      throw ErrorFormatter.fromDio(e);
    }
  }
}
