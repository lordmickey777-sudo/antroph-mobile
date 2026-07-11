import 'package:antroph_mobile/features/story/data/stories_repository.dart';
import 'package:antroph_mobile/features/story/models/interactive_story_models.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _AuthRetryAdapter implements HttpClientAdapter {
  int requestCount = 0;
  final List<RequestOptions> requests = <RequestOptions>[];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requestCount += 1;
    requests.add(options);
    if (requestCount == 1) {
      return ResponseBody.fromString(
        '{"detail":"Could not validate credentials"}',
        401,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    }
    return ResponseBody.fromString(
      '''
      {
        "status": "accepted",
        "event": {
          "id": "chat-event-1",
          "session_id": "session-1",
          "seq": 9,
          "actor_type": "user",
          "event_type": "solo_user_message",
          "payload": {"text": "Explain it again", "mode": "chat"}
        },
        "turn": {
          "type": "interactive_turn.v1",
          "session_id": "session-1",
          "turn_id": "chat-turn-1",
          "seq": 10,
          "speaker": {"type": "ai", "role": "host"},
          "blocks": [{"kind": "text", "text": "Here is another explanation."}]
        },
        "state": {"session_type": "solo", "phase": "post_question_prompt"}
      }
      ''',
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }
}

void main() {
  test('interactive input refreshes and retries after a 401', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
    final adapter = _AuthRetryAdapter();
    dio.httpClientAdapter = adapter;
    var refreshCalls = 0;
    dio.interceptors.add(
      InterceptorsWrapper(
        onError: (error, handler) async {
          if (error.response?.statusCode == 401 && refreshCalls == 0) {
            refreshCalls += 1;
            final request = error.requestOptions;
            final response = await dio.fetch<dynamic>(
              request.copyWith(
                headers: {
                  ...request.headers,
                  'Authorization': 'Bearer refreshed-token',
                },
                extra: {...request.extra, 'retried': true},
              ),
            );
            handler.resolve(response);
            return;
          }
          handler.next(error);
        },
      ),
    );
    final repository = StoriesRepository(dio: dio);

    final response = await repository.submitInteractiveInput(
      sessionId: 'session-1',
      input: const InteractiveInput(
        inputType: 'solo_chat',
        text: 'Explain it again',
      ),
    );

    expect(refreshCalls, 1);
    expect(adapter.requestCount, 2);
    expect(
      adapter.requests.last.headers['Authorization'],
      'Bearer refreshed-token',
    );
    expect(response.status, 'accepted');
    expect(response.event.eventType, 'solo_user_message');
    expect(response.turn?.blocks, isNotEmpty);
    expect(response.state['phase'], 'post_question_prompt');
  });
}
