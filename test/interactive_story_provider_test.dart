import 'dart:async';

import 'package:dio/dio.dart';
import 'package:antroph_mobile/core/network/error_formatter.dart';
import 'package:antroph_mobile/features/story/data/stories_repository.dart';
import 'package:antroph_mobile/features/story/models/interactive_story_models.dart';
import 'package:antroph_mobile/features/story/providers/interactive_story_provider.dart';
import 'package:antroph_mobile/features/story/providers/story_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('InteractiveStoryNotifier submitText', () {
    late ProviderContainer container;
    late ProviderSubscription<InteractiveStoryState> subscription;
    late FakeStoriesRepository repository;
    late InteractiveStoryNotifier notifier;

    setUp(() {
      repository = FakeStoriesRepository();
      container = ProviderContainer(
        overrides: [storiesRepositoryProvider.overrideWithValue(repository)],
      );
      subscription = container.listen(
        interactiveStoryProvider,
        (_, __) {},
        fireImmediately: true,
      );
      notifier = container.read(interactiveStoryProvider.notifier);
      notifier.state = InteractiveStoryState(session: _buildQuizSession());
    });

    tearDown(() {
      subscription.close();
      container.dispose();
    });

    test('adds optimistic pending text immediately', () async {
      final completer = Completer<InteractiveInputResponse>();
      repository.submitInteractiveInputHandler =
          ({required sessionId, required input}) {
            return completer.future;
          };

      final future = notifier.submitText('Hello there');
      await Future<void>.delayed(Duration.zero);

      final pending = container
          .read(interactiveStoryProvider)
          .pendingTextMessages;
      expect(pending, hasLength(1));
      expect(pending.single.text, 'Hello there');

      completer.complete(_soloUserMessageResponse('Hello there'));
      await future;
    });

    test('removes pending text on HTTP success', () async {
      final completer = Completer<InteractiveInputResponse>();
      repository.submitInteractiveInputHandler =
          ({required sessionId, required input}) {
            return completer.future;
          };

      final future = notifier.submitText('Tell me more');
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(interactiveStoryProvider).pendingTextMessages,
        hasLength(1),
      );

      completer.complete(_soloUserMessageResponse('Tell me more', seq: 3));
      await future;

      final state = container.read(interactiveStoryProvider);
      expect(state.pendingTextMessages, isEmpty);
      expect(
        state.session!.events.where(
          (event) => event.eventType == 'solo_user_message',
        ),
        hasLength(1),
      );
    });

    test('removes pending text when socket ack arrives first', () async {
      final completer = Completer<InteractiveInputResponse>();
      repository.submitInteractiveInputHandler =
          ({required sessionId, required input}) {
            return completer.future;
          };

      final future = notifier.submitText('Relationship');
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(interactiveStoryProvider).pendingTextMessages,
        hasLength(1),
      );

      notifier.applyRoomEventForTest({
        'event_type': 'solo_user_message',
        'seq': 4,
        'payload': {'text': 'Relationship', 'phase': 'discussion'},
      });

      var state = container.read(interactiveStoryProvider);
      expect(state.pendingTextMessages, isEmpty);

      completer.complete(_soloUserMessageResponse('Relationship', seq: 4));
      await future;

      state = container.read(interactiveStoryProvider);
      expect(state.pendingTextMessages, isEmpty);
      expect(
        state.session!.events.where(
          (event) => event.eventType == 'solo_user_message',
        ),
        hasLength(1),
      );
    });

    test('removes pending text on failure and keeps the error', () async {
      repository.submitInteractiveInputHandler =
          ({required sessionId, required input}) async {
            throw const ApiError(
              message: 'Could not send message.',
              statusCode: 500,
            );
          };

      await notifier.submitText('Need help');

      final state = container.read(interactiveStoryProvider);
      expect(state.pendingTextMessages, isEmpty);
      expect(state.error, 'Could not send message.');
      expect(state.pendingInputKeys, isEmpty);
    });
  });
}

class FakeStoriesRepository extends StoriesRepository {
  FakeStoriesRepository()
    : super(dio: Dio(BaseOptions(baseUrl: 'http://test')));

  Future<InteractiveInputResponse> Function({
    required String sessionId,
    required InteractiveInput input,
  })?
  submitInteractiveInputHandler;

  @override
  Future<InteractiveInputResponse> submitInteractiveInput({
    required String sessionId,
    required InteractiveInput input,
  }) async {
    final handler = submitInteractiveInputHandler;
    if (handler == null) {
      throw UnimplementedError('submitInteractiveInputHandler not configured');
    }
    return handler(sessionId: sessionId, input: input);
  }
}

InteractiveSessionState _buildQuizSession() {
  return InteractiveSessionState.fromJson({
    'session_id': 'session-1',
    'story_id': 'story-1',
    'interaction_mode': 'interactive',
    'ai_role': 'host',
    'interactive_state': {
      'template': 'quiz',
      'phase': 'discussion',
      'session_type': 'solo',
    },
    'participants': const [],
    'events': const [],
    'current_turn': {
      'type': 'interactive_turn.v1',
      'session_id': 'session-1',
      'turn_id': 'turn-1',
      'seq': 1,
      'speaker': {'type': 'ai', 'role': 'host'},
      'blocks': [
        {'kind': 'text', 'text': 'Tell me what you want to discuss.'},
      ],
    },
    'last_seq': 1,
    'is_completed': false,
  });
}

InteractiveInputResponse _soloUserMessageResponse(String text, {int seq = 2}) {
  return InteractiveInputResponse.fromJson({
    'status': 'accepted',
    'event': {
      'id': 'event-$seq',
      'session_id': 'session-1',
      'seq': seq,
      'actor_type': 'user',
      'event_type': 'solo_user_message',
      'payload': {'text': text, 'phase': 'discussion'},
    },
    'turn': {
      'type': 'interactive_turn.v1',
      'session_id': 'session-1',
      'turn_id': 'turn-$seq',
      'seq': seq + 1,
      'speaker': {'type': 'ai', 'role': 'host'},
      'blocks': [
        {'kind': 'text', 'text': 'Got it.'},
      ],
      'state_patch': {
        'template': 'quiz',
        'phase': 'discussion',
        'session_type': 'solo',
      },
    },
    'state': {
      'template': 'quiz',
      'phase': 'discussion',
      'session_type': 'solo',
    },
  });
}
