import 'dart:convert';

import 'package:antroph_mobile/features/story/data/stories_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('solo session APIs send fresh intent and decode history', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
    final adapter = _SoloSessionAdapter();
    dio.httpClientAdapter = adapter;
    final repository = StoriesRepository(dio: dio);

    await repository.startInteractiveSession(
      storyId: 'story-1',
      sessionType: 'solo',
      startFresh: true,
    );
    final startRequest = adapter.requests.single;
    expect(startRequest.path, '/stories/story-1/sessions');
    expect((startRequest.data as Map)['start_fresh'], isTrue);

    final history = await repository.fetchSoloInteractiveHistory(
      storyId: 'story-1',
      limit: 500,
    );
    final historyRequest = adapter.requests[1];
    expect(historyRequest.path, '/story-sessions/me/solo-history');
    expect(historyRequest.queryParameters['story_id'], 'story-1');
    expect(historyRequest.queryParameters['limit'], 50);
    expect(history, hasLength(1));
    expect(history.single.displayTopic, 'History › Ancient Egypt');
    expect(history.single.isPaused, isTrue);

    final resumed = await repository.resumeInteractiveSession('session-1');
    expect(adapter.requests[2].path, '/story-sessions/session-1/resume');
    expect(resumed.sessionId, 'session-1');
    expect(resumed.isCompleted, isFalse);

    await repository.fetchInteractiveSessionHistory('session-1');
    expect(adapter.requests[3].path, '/story-sessions/session-1');
    expect(adapter.requests[3].queryParameters['limit'], 250);
  });
}

class _SoloSessionAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = <RequestOptions>[];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (options.path == '/story-sessions/me/solo-history') {
      return _jsonResponse([
        {
          'session_id': 'session-1',
          'story_id': 'story-1',
          'story_title': 'The Hot Seat',
          'story_cover_image_url': 'https://example.test/cover.jpg',
          'is_paused': true,
          'is_completed': false,
          'phase': 'discussion',
          'topic_path': ['History', 'Ancient Egypt'],
          'view_mode': 'chat',
          'current_round': 2,
          'score': 10,
          'last_activity_at': '2026-07-11T10:30:00Z',
          'created_at': '2026-07-11T09:30:00Z',
          'completed_at': null,
          'preview': 'The pyramids were our latest topic.',
        },
      ]);
    }
    return _jsonResponse({
      'session_id': 'session-1',
      'story_id': 'story-1',
      'interaction_mode': 'interactive',
      'ai_role': 'host',
      'interactive_state': {'session_type': 'solo', 'phase': 'discussion'},
      'participants': [],
      'events': [],
      'last_seq': 4,
      'is_completed': false,
      'created_at': '2026-07-11T09:30:00Z',
      'updated_at': '2026-07-11T10:30:00Z',
    });
  }

  ResponseBody _jsonResponse(Object payload) {
    return ResponseBody.fromString(
      jsonEncode(payload),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }
}
