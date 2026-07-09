import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/error_formatter.dart';
import '../models/story_models.dart';
import '../models/story_playlists_models.dart';
import '../models/story_detail.dart';
import '../models/story_session.dart';
import '../models/interactive_story_models.dart';

class StoriesRepository {
  StoriesRepository({Dio? dio}) : _dio = dio ?? ApiClient.I.dio;
  final Dio _dio;

  /// Fetch home sections for stories page.
  /// Sends auth header if available to get personalized data (My Playlist, is_added flags).
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
        options: Options(receiveTimeout: const Duration(seconds: 45)),
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
      final records = _extractPlaylistRecords(res.data);
      return records.map((e) => PlaylistDto.fromJson(e)).toList();
    } on DioException catch (e) {
      throw ErrorFormatter.fromDio(e);
    }
  }

  List<Map<String, dynamic>> _extractPlaylistRecords(dynamic payload) {
    if (payload is List) {
      return payload.whereType<Map<String, dynamic>>().toList();
    }
    if (payload is Map<String, dynamic>) {
      final nestedList =
          (payload['data'] as List?) ??
          (payload['playlists'] as List?) ??
          (payload['collections'] as List?) ??
          (payload['items'] as List?) ??
          (payload['results'] as List?);
      if (nestedList != null) {
        return nestedList.whereType<Map<String, dynamic>>().toList();
      }
      return [payload];
    }
    return [];
  }

  Future<List<ContinuePlayingDto>> fetchContinuePlaying({
    int limit = 10,
  }) async {
    try {
      final res = await _dio.get(
        '/stories/me/continue',
        queryParameters: {'limit': limit},
      );
      final payload = res.data;
      if (payload is! List) return const [];
      return payload
          .whereType<Map<String, dynamic>>()
          .map(ContinuePlayingDto.fromJson)
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
    required List<String> storyIds,
    int? position,
  }) async {
    try {
      final payload = <String, dynamic>{'story_ids': storyIds};
      if (position != null) {
        payload['position'] = position;
      }
      await _dio.post('/playlists/stories', data: payload);
    } on DioException catch (e) {
      throw ErrorFormatter.fromDio(e);
    }
  }

  Future<void> removeStoriesFromCollection({
    required List<String> storyIds,
  }) async {
    try {
      await _dio.delete('/playlists/stories', data: {'story_ids': storyIds});
    } on DioException catch (e) {
      throw ErrorFormatter.fromDio(e);
    }
  }

  /// Fetch detailed story information by ID.
  /// Public endpoint, but send auth when available so creators can preview
  /// their own unpublished community stories.
  Future<StoryDetailDto> fetchStoryDetail(String storyId) async {
    try {
      final res = await _dio.get(
        '/stories/$storyId',
        options: Options(receiveTimeout: const Duration(seconds: 60)),
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
        data: {
          "device_type": deviceType,
          "device_id": deviceId,
          "autoplay": true,
        },
      );
      final data = res.data as Map<String, dynamic>;
      return StorySession.fromJson(data);
    } on DioException catch (e) {
      throw ErrorFormatter.fromDio(e);
    }
  }

  Future<List<Map<String, dynamic>>> fetchStoryConversation({
    required String storyId,
  }) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final res = await _dio.get(
          '/stories/$storyId/conversation',
          options: Options(receiveTimeout: const Duration(seconds: 45)),
        );
        final data = res.data;
        if (data is! Map<String, dynamic>) return const [];
        final history = data['history'];
        if (history is! List) return const [];
        return history.whereType<Map<String, dynamic>>().toList();
      } on DioException catch (e) {
        if (attempt == 0 && _isTransientConnectionError(e)) {
          await Future<void>.delayed(const Duration(milliseconds: 450));
          continue;
        }
        throw ErrorFormatter.fromDio(e);
      }
    }
    return const [];
  }

  bool _isTransientConnectionError(DioException e) {
    final message = e.message ?? e.error?.toString() ?? '';
    return e.type == DioExceptionType.unknown &&
        (message.contains('Connection closed') ||
            message.contains('Connection reset') ||
            message.contains('SocketException') ||
            message.contains('HttpException'));
  }

  Future<StorySession> sendStoryText({
    required String storyId,
    required String message,
    int? expectedVersion,
  }) async {
    try {
      final res = await _dio.post(
        '/stories/$storyId/choose',
        data: {'voice_command': message},
        options: Options(
          receiveTimeout: const Duration(seconds: 75),
          headers: {
            if (expectedVersion != null) 'If-Match': expectedVersion.toString(),
          },
        ),
      );
      final data = res.data as Map<String, dynamic>;
      return StorySession.fromJson(
        (data['session'] as Map).cast<String, dynamic>(),
      );
    } on DioException catch (e) {
      throw ErrorFormatter.fromDio(e);
    }
  }

  Stream<StoryTextStreamEvent> streamStoryText({
    required String storyId,
    required String message,
    int? expectedVersion,
  }) async* {
    try {
      final res = await _dio.post<ResponseBody>(
        '/stories/$storyId/chat/stream',
        data: {'voice_command': message},
        options: Options(
          responseType: ResponseType.stream,
          receiveTimeout: const Duration(seconds: 90),
          headers: {
            'Accept': 'text/event-stream',
            if (expectedVersion != null) 'If-Match': expectedVersion.toString(),
          },
        ),
      );
      final body = res.data;
      if (body == null) return;

      var buffer = '';
      await for (final chunk in utf8.decoder.bind(body.stream)) {
        buffer += chunk;
        while (true) {
          final boundary = buffer.indexOf('\n\n');
          if (boundary < 0) break;
          final rawEvent = buffer.substring(0, boundary);
          buffer = buffer.substring(boundary + 2);
          final event = StoryTextStreamEvent.fromSse(rawEvent);
          if (event != null) yield event;
        }
      }

      final tail = buffer.trim();
      if (tail.isNotEmpty) {
        final event = StoryTextStreamEvent.fromSse(tail);
        if (event != null) yield event;
      }
    } on DioException catch (e) {
      throw ErrorFormatter.fromDio(e);
    }
  }

  Future<InteractiveSessionState> startInteractiveSession({
    required String storyId,
    String deviceType = 'mobile',
    String? deviceId,
    String? sessionType,
    String? roomType,
    String? hostDisplayName,
    int? maxParticipants,
  }) async {
    try {
      final res = await _dio.post(
        '/stories/$storyId/sessions',
        data: {
          'device_type': deviceType,
          if (deviceId != null) 'device_id': deviceId,
          if (sessionType != null) 'session_type': sessionType,
          if (roomType != null) 'room_type': roomType,
          if (hostDisplayName != null) 'host_display_name': hostDisplayName,
          if (maxParticipants != null) 'max_participants': maxParticipants,
        },
        options: Options(receiveTimeout: const Duration(seconds: 45)),
      );
      return InteractiveSessionState.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ErrorFormatter.fromDio(e);
    }
  }

  Future<InteractiveSessionState> joinPublicInteractiveRoom({
    required String storyId,
    String deviceType = 'mobile',
    String? deviceId,
    String? displayName,
  }) async {
    try {
      final res = await _dio.post(
        '/stories/$storyId/public-room/join',
        data: {
          'device_type': deviceType,
          if (deviceId != null) 'device_id': deviceId,
          if (displayName != null) 'display_name': displayName,
        },
        options: Options(receiveTimeout: const Duration(seconds: 45)),
      );
      return InteractiveSessionState.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ErrorFormatter.fromDio(e);
    }
  }

  Future<InteractiveSessionState> joinInteractiveSession({
    required String sessionId,
    String deviceType = 'mobile',
    String? deviceId,
    String? displayName,
  }) async {
    try {
      final res = await _dio.post(
        '/story-sessions/$sessionId/join',
        data: {
          'device_type': deviceType,
          if (deviceId != null) 'device_id': deviceId,
          if (displayName != null) 'display_name': displayName,
        },
      );
      return InteractiveSessionState.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ErrorFormatter.fromDio(e);
    }
  }

  Future<InteractiveSessionState> joinInteractiveSessionByCode({
    required String joinCode,
    String deviceType = 'mobile',
    String? deviceId,
    String? displayName,
  }) async {
    try {
      final res = await _dio.post(
        '/story-sessions/join-code/${joinCode.trim()}',
        data: {
          'device_type': deviceType,
          if (deviceId != null) 'device_id': deviceId,
          if (displayName != null) 'display_name': displayName,
        },
      );
      return InteractiveSessionState.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ErrorFormatter.fromDio(e);
    }
  }

  Future<InteractiveSessionState> fetchInteractiveSession(
    String sessionId,
  ) async {
    try {
      final res = await _dio.get('/story-sessions/$sessionId');
      return InteractiveSessionState.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ErrorFormatter.fromDio(e);
    }
  }

  Future<InteractiveInputResponse> submitInteractiveInput({
    required String sessionId,
    required InteractiveInput input,
  }) async {
    try {
      final res = await _dio.post(
        '/story-sessions/$sessionId/input',
        data: input.toJson(),
        options: Options(
          receiveTimeout: const Duration(seconds: 60),
          validateStatus: (status) => (status ?? 0) < 500,
        ),
      );
      if (res.statusCode == 409) {
        throw ApiError(
          message: _extractErrorMessage(res.data) ?? 'This turn has expired.',
          statusCode: 409,
        );
      }
      return InteractiveInputResponse.fromJson(
        res.data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw ErrorFormatter.fromDio(e);
    }
  }

  String? _extractErrorMessage(dynamic data) {
    if (data is Map<String, dynamic>) {
      final detail = data['detail'];
      if (detail is String && detail.trim().isNotEmpty) return detail.trim();
      final message = data['message'];
      if (message is String && message.trim().isNotEmpty) {
        return message.trim();
      }
    }
    if (data is String && data.trim().isNotEmpty) return data.trim();
    return null;
  }

  Future<InteractiveSessionState> retryInteractiveQuizGeneration(
    String sessionId,
  ) async {
    try {
      final res = await _dio.post(
        '/story-sessions/$sessionId/retry-generation',
      );
      return InteractiveSessionState.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ErrorFormatter.fromDio(e);
    }
  }

  Future<InteractiveSessionState> advanceInteractiveSession(
    String sessionId,
  ) async {
    try {
      final res = await _dio.post('/story-sessions/$sessionId/advance');
      return InteractiveSessionState.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ErrorFormatter.fromDio(e);
    }
  }

  Future<void> leaveInteractiveSession(String sessionId) async {
    try {
      final res = await _dio.post(
        '/story-sessions/$sessionId/leave',
        options: Options(
          receiveTimeout: const Duration(seconds: 45),
          validateStatus: (status) => (status ?? 0) < 500,
          extra: const {'suppressErrorLog': true},
        ),
      );
      if (res.statusCode == 404) return;
      if ((res.statusCode ?? 0) >= 400) {
        throw ApiError(
          message: _extractErrorMessage(res.data) ?? 'Could not leave game.',
          statusCode: res.statusCode,
        );
      }
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

class StoryTextStreamEvent {
  const StoryTextStreamEvent({
    required this.type,
    this.content,
    this.session,
    this.error,
  });

  final String type;
  final String? content;
  final StorySession? session;
  final String? error;

  bool get isToken => type == 'token';
  bool get isDone => type == 'done';
  bool get isError => type == 'error';

  static StoryTextStreamEvent? fromSse(String rawEvent) {
    final dataLines = rawEvent
        .split('\n')
        .map((line) => line.trimRight())
        .where((line) => line.startsWith('data:'))
        .map((line) => line.substring(5).trimLeft())
        .where((line) => line.isNotEmpty)
        .toList();
    if (dataLines.isEmpty) return null;

    final data = dataLines.join('\n');
    final decoded = jsonDecode(data);
    if (decoded is! Map<String, dynamic>) return null;

    final type = (decoded['type'] as String?)?.trim() ?? '';
    final sessionJson = decoded['session'];
    return StoryTextStreamEvent(
      type: type,
      content: decoded['content'] as String?,
      error: decoded['error'] as String?,
      session: sessionJson is Map
          ? StorySession.fromJson(sessionJson.cast<String, dynamic>())
          : null,
    );
  }
}
