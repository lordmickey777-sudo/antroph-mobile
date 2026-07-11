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

    test('ignores stale room events that would regress topic selection', () {
      notifier.state = InteractiveStoryState(
        session: _buildModeSelectionSession(),
      );

      notifier.applyRoomEventForTest({
        'event_type': 'topic_selection_started',
        'seq': 1,
        'payload': {
          'prompt': 'What topic do you want to play?',
          'topic_suggestions': const [
            {'id': 'geography', 'label': 'Geography'},
            {'id': 'science', 'label': 'Science'},
            {'id': 'sports', 'label': 'Sports'},
            {'id': 'custom_topic', 'label': 'Type my own topic'},
          ],
        },
      });

      final session = container.read(interactiveStoryProvider).session!;
      expect(session.interactiveState['phase'], 'mode_selection');
      expect(session.interactiveState['selected_topic'], 'Sex');
      expect(session.currentTurn?.seq, 3);
      expect(session.lastSeq, 3);
    });

    test('applies guided topic socket events and clears pending options', () {
      notifier.state = InteractiveStoryState(
        session: _buildTopicSelectionSession(),
        pendingTextMessages: const [
          PendingInteractiveTextMessage(
            clientId: 'topic-client-id',
            text: 'History',
          ),
        ],
      );

      notifier.applyRoomEventForTest({
        'event_type': 'topic_candidate_selected',
        'seq': 2,
        'payload': {
          'topic': 'History',
          'option_id': null,
          'display_text': 'History',
          'topic_path': ['History'],
          'depth': 0,
          'allow_custom_aspect': true,
        },
      });

      var storyState = container.read(interactiveStoryProvider);
      var session = storyState.session!;
      expect(storyState.pendingTextMessages, isEmpty);
      expect(session.interactiveState['phase'], 'topic_selection');
      expect(session.interactiveState['topic_selection_stage'], 'aspect');
      expect(session.interactiveState['topic_path'], ['History']);
      expect(session.interactiveState['topic_drilldown_depth'], 0);
      expect(session.interactiveState['topic_aspect_status'], 'generating');
      expect(session.interactiveState['pending_topic_aspects'], isEmpty);
      expect(session.interactiveState['allow_custom_aspect'], isTrue);

      notifier.state = storyState.copyWith(
        pendingInputKeys: const {'aspect-turn-option_select-ancient_history'},
      );
      notifier.applyRoomEventForTest({
        'event_type': 'topic_aspect_selected',
        'seq': 3,
        'payload': {
          'action': 'select_aspect',
          'aspect': 'Ancient history',
          'option_id': 'ancient_history',
          'display_text': 'Ancient history',
          'topic_path': ['History', 'Ancient history'],
          'depth': 1,
        },
      });

      storyState = container.read(interactiveStoryProvider);
      session = storyState.session!;
      expect(storyState.pendingInputKeys, isEmpty);
      expect(session.interactiveState['phase'], 'topic_selection');
      expect(session.interactiveState['topic_selection_stage'], 'aspect');
      expect(session.interactiveState['topic_path'], [
        'History',
        'Ancient history',
      ]);
      expect(session.interactiveState['topic_drilldown_depth'], 1);
      expect(session.interactiveState['topic_aspect_status'], 'generating');

      notifier.state = storyState.copyWith(
        pendingInputKeys: const {'actions-turn-option_select-quiz'},
      );
      notifier.applyRoomEventForTest({
        'event_type': 'topic_selected',
        'seq': 4,
        'payload': {
          'option_id': 'quiz',
          'action': 'quiz',
          'display_text': 'Take me to quiz',
          'topic': 'Ancient history',
          'topic_path': ['History', 'Ancient history'],
        },
      });

      storyState = container.read(interactiveStoryProvider);
      session = storyState.session!;
      expect(storyState.pendingInputKeys, isEmpty);
      expect(session.interactiveState['phase'], 'timer_selection');
      expect(session.interactiveState['selected_topic'], 'Ancient history');
      expect(session.interactiveState['selected_topic_path'], [
        'History',
        'Ancient history',
      ]);
      expect(
        session.interactiveState,
        isNot(contains('topic_selection_stage')),
      );
      expect(session.interactiveState, isNot(contains('topic_path')));
      expect(session.interactiveState, isNot(contains('topic_aspect_status')));
    });

    test('maps a guided Chat socket action directly to discussion', () {
      notifier.state = const InteractiveStoryState(
        session: InteractiveSessionState(
          sessionId: 'session-1',
          storyId: 'story-1',
          interactionMode: 'interactive',
          aiRole: 'host',
          interactiveState: {
            'template': 'quiz',
            'session_type': 'solo',
            'phase': 'topic_selection',
            'topic_selection_stage': 'aspect',
            'topic_path': ['History', 'Ancient history'],
            'topic_drilldown_depth': 1,
            'topic_aspect_status': 'ready',
            'pending_topic_aspects': [],
          },
          lastSeq: 3,
        ),
        pendingInputKeys: {'actions-turn-option_select-chat'},
      );

      notifier.applyRoomEventForTest({
        'event_type': 'topic_selected',
        'seq': 4,
        'payload': {
          'action': 'chat',
          'option_id': 'chat',
          'display_text': 'Chat with Aura',
          'topic': 'Ancient history',
          'topic_path': ['History', 'Ancient history'],
        },
      });

      final storyState = container.read(interactiveStoryProvider);
      expect(storyState.pendingInputKeys, isEmpty);
      expect(storyState.session!.interactiveState['phase'], 'discussion');
      expect(
        storyState.session!.interactiveState['selected_topic'],
        'Ancient history',
      );
      expect(storyState.session!.interactiveState['selected_topic_path'], [
        'History',
        'Ancient history',
      ]);
      expect(
        storyState.session!.interactiveState,
        isNot(contains('topic_selection_stage')),
      );
    });

    test(
      'toggles root topic actions from socket state and clears on final',
      () {
        notifier.state = const InteractiveStoryState(
          session: InteractiveSessionState(
            sessionId: 'session-1',
            storyId: 'story-1',
            interactionMode: 'interactive',
            aiRole: 'host',
            interactiveState: {
              'template': 'quiz',
              'session_type': 'solo',
              'phase': 'topic_selection',
              'topic_selection_stage': 'aspect',
              'topic_path': ['History'],
              'topic_drilldown_depth': 0,
              'topic_aspect_revision': 'revision-1',
              'topic_aspect_status': 'ready',
              'pending_topic_aspects': [
                {'id': 'ancient', 'label': 'Ancient history'},
                {'id': 'modern', 'label': 'Modern history'},
                {'id': 'cultural', 'label': 'Cultural history'},
              ],
              'allow_custom_aspect': true,
              'topic_path_actions_expanded': false,
            },
            lastSeq: 3,
          ),
          pendingInputKeys: {'aspect-turn-option_select-continue_with_topic'},
        );

        notifier.applyRoomEventForTest({
          'event_type': 'topic_aspect_selected',
          'seq': 4,
          'payload': {
            'action': 'continue_with_topic',
            'option_id': 'continue_with_topic',
            'display_text': 'Continue',
            'topic_path': ['History'],
            'depth': 0,
            'state_patch': {
              'topic_path_actions_expanded': true,
              'allow_custom_aspect': false,
            },
          },
        });

        var storyState = container.read(interactiveStoryProvider);
        expect(storyState.pendingInputKeys, isEmpty);
        expect(
          storyState.session!.interactiveState['topic_path_actions_expanded'],
          isTrue,
        );
        expect(
          storyState.session!.interactiveState['allow_custom_aspect'],
          isFalse,
        );
        expect(
          storyState.session!.interactiveState['pending_topic_aspects'],
          hasLength(3),
        );
        expect(
          storyState.session!.interactiveState['topic_aspect_status'],
          'ready',
        );

        notifier.state = storyState.copyWith(
          pendingInputKeys: const {
            'root-actions-turn-option_select-choose_aspect',
          },
        );
        notifier.applyRoomEventForTest({
          'event_type': 'topic_aspect_selected',
          'seq': 5,
          'payload': {
            'action': 'choose_aspect',
            'option_id': 'choose_aspect',
            'display_text': 'Choose an aspect',
            'topic_path': ['History'],
            'depth': 0,
            'state': {
              'topic_path_actions_expanded': false,
              'allow_custom_aspect': true,
            },
          },
        });

        storyState = container.read(interactiveStoryProvider);
        expect(storyState.pendingInputKeys, isEmpty);
        expect(
          storyState.session!.interactiveState['topic_path_actions_expanded'],
          isFalse,
        );
        expect(
          storyState.session!.interactiveState['allow_custom_aspect'],
          isTrue,
        );

        notifier.state = storyState.copyWith(
          pendingInputKeys: const {'root-actions-turn-option_select-chat'},
        );
        notifier.applyRoomEventForTest({
          'event_type': 'topic_selected',
          'seq': 6,
          'payload': {
            'action': 'chat',
            'option_id': 'chat',
            'display_text': 'Chat with Aura',
            'topic': 'History',
            'topic_path': ['History'],
          },
        });

        storyState = container.read(interactiveStoryProvider);
        expect(storyState.pendingInputKeys, isEmpty);
        expect(storyState.session!.interactiveState['phase'], 'discussion');
        expect(
          storyState.session!.interactiveState,
          isNot(contains('topic_path_actions_expanded')),
        );
      },
    );

    testWidgets('polls while guided aspect generation is pending', (
      tester,
    ) async {
      notifier.state = InteractiveStoryState(
        session: _buildTopicSelectionSession(),
      );
      var fetchCalls = 0;
      repository.fetchInteractiveSessionHandler = (_) async {
        fetchCalls += 1;
        final turn = InteractiveTurn.fromJson({
          'type': 'interactive_turn.v1',
          'session_id': 'session-1',
          'turn_id': 'aspect-turn-3',
          'seq': 3,
          'speaker': {'type': 'ai', 'role': 'host'},
          'blocks': [
            {
              'kind': 'choice_group',
              'prompt': '',
              'options': [
                {'id': 'ancient', 'label': 'Ancient history'},
                {'id': 'modern', 'label': 'Modern history'},
                {'id': 'cultural', 'label': 'Cultural history'},
              ],
              'metadata': {
                'choice_kind': 'solo_topic_aspect',
                'topic_path': ['History'],
                'depth': 0,
                'revision': 'revision-1',
              },
            },
          ],
        });
        return InteractiveSessionState(
          sessionId: 'session-1',
          storyId: 'story-1',
          interactionMode: 'interactive',
          aiRole: 'host',
          interactiveState: {
            'template': 'quiz',
            'session_type': 'solo',
            'phase': 'topic_selection',
            'topic_selection_stage': 'aspect',
            'topic_path': ['History'],
            'topic_drilldown_depth': 0,
            'topic_aspect_revision': 'revision-1',
            'topic_aspect_status': 'ready',
            'allow_custom_aspect': true,
            'pending_topic_aspects': [
              {'id': 'ancient', 'label': 'Ancient history'},
              {'id': 'modern', 'label': 'Modern history'},
              {'id': 'cultural', 'label': 'Cultural history'},
            ],
          },
          currentTurn: turn,
          lastSeq: 3,
        );
      };

      notifier.applyRoomEventForTest({
        'event_type': 'topic_candidate_selected',
        'seq': 2,
        'payload': {
          'topic': 'History',
          'topic_path': ['History'],
          'depth': 0,
        },
      });

      expect(
        container
            .read(interactiveStoryProvider)
            .session!
            .interactiveState['topic_aspect_status'],
        'generating',
      );
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();

      expect(fetchCalls, 1);
      expect(
        container
            .read(interactiveStoryProvider)
            .session!
            .interactiveState['topic_aspect_status'],
        'ready',
      );
    });

    test(
      'attaches guided revision and path only to aspect option selections',
      () async {
        notifier.state = const InteractiveStoryState(
          session: InteractiveSessionState(
            sessionId: 'session-1',
            storyId: 'story-1',
            interactionMode: 'interactive',
            aiRole: 'host',
            interactiveState: {
              'template': 'quiz',
              'session_type': 'solo',
              'phase': 'topic_selection',
              'topic_selection_stage': 'aspect',
              'topic_path': ['History'],
              'topic_aspect_revision': 'revision-2',
              'topic_aspect_status': 'ready',
              'topic_path_actions_expanded': false,
            },
            lastSeq: 3,
          ),
        );
        InteractiveInput? submittedInput;
        repository.submitInteractiveInputHandler =
            ({required sessionId, required input}) async {
              submittedInput = input;
              return InteractiveInputResponse(
                status: 'accepted',
                event: StorySessionEvent(
                  id: 'event-4',
                  sessionId: sessionId,
                  seq: 4,
                  actorType: 'user',
                  eventType: 'topic_aspect_selected',
                  payload: const {
                    'action': 'continue_with_topic',
                    'option_id': 'continue_with_topic',
                  },
                ),
                state: notifier.state.session!.interactiveState,
              );
            };

        await notifier.submitOption(
          optionId: 'continue_with_topic',
          inputType: 'option_select',
        );

        expect(submittedInput?.metadata, {
          'expected_revision': 'revision-2',
          'expected_topic_path': ['History'],
        });

        notifier.state = InteractiveStoryState(
          session: _buildModeSelectionSession(),
        );
        submittedInput = null;

        await notifier.submitOption(
          optionId: 'quiz',
          inputType: 'option_select',
        );

        expect(submittedInput?.metadata, isEmpty);
      },
    );
  });

  group('InteractiveStoryNotifier refresh reconciliation', () {
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
    });

    tearDown(() {
      subscription.close();
      container.dispose();
    });

    test(
      'rejects a mixed refresh snapshot older than the current session',
      () async {
        notifier.state = InteractiveStoryState(
          session: _buildModeSelectionSession(),
        );
        repository.fetchInteractiveSessionHandler = (_) async =>
            _buildMixedTopicAndModeSession(lastSeq: 2);

        await notifier.refresh();

        final session = container.read(interactiveStoryProvider).session!;
        expect(session.interactiveState['phase'], 'mode_selection');
        expect(session.interactiveState['selected_topic'], 'Sex');
        expect(session.currentTurn?.turnId, 'mode-turn');
        expect(session.lastSeq, 3);
        expect(session.events, isEmpty);
      },
    );

    for (final snapshotLastSeq in const [1, 3]) {
      test('normalizes a ${snapshotLastSeq == 1 ? 'same-sequence' : 'newer'} '
          'mixed refresh snapshot to mode selection', () async {
        notifier.state = InteractiveStoryState(
          session: _buildTopicSelectionSession(),
        );
        repository.fetchInteractiveSessionHandler = (_) async =>
            _buildMixedTopicAndModeSession(lastSeq: snapshotLastSeq);

        await notifier.refresh();

        final session = container.read(interactiveStoryProvider).session!;
        expect(session.interactiveState['phase'], 'mode_selection');
        expect(session.interactiveState['phase'], isNot('topic_selection'));
        expect(session.interactiveState['selected_topic'], 'Sex');
        expect(session.currentTurn?.turnId, 'mode-turn');
        expect(session.currentTurn?.statePatch['phase'], 'mode_selection');
        expect(session.lastSeq, 3);
      });
    }
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

  Future<InteractiveSessionState> Function(String sessionId)?
  fetchInteractiveSessionHandler;

  @override
  Future<InteractiveSessionState> fetchInteractiveSession(
    String sessionId,
  ) async {
    final handler = fetchInteractiveSessionHandler;
    if (handler == null) {
      throw UnimplementedError('fetchInteractiveSessionHandler not configured');
    }
    return handler(sessionId);
  }

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

InteractiveSessionState _buildModeSelectionSession() {
  return InteractiveSessionState.fromJson({
    'session_id': 'session-1',
    'story_id': 'story-1',
    'interaction_mode': 'interactive',
    'ai_role': 'host',
    'interactive_state': {
      'template': 'quiz',
      'phase': 'mode_selection',
      'session_type': 'solo',
      'selected_topic': 'Sex',
    },
    'participants': const [],
    'events': const [],
    'current_turn': {
      'type': 'interactive_turn.v1',
      'session_id': 'session-1',
      'turn_id': 'mode-turn',
      'seq': 3,
      'speaker': {'type': 'ai', 'role': 'host'},
      'blocks': [
        {
          'kind': 'text',
          'text': 'Nice, Sex it is. What do you want to do next?',
        },
        {
          'kind': 'choice_group',
          'prompt': '',
          'options': [
            {'id': 'chat', 'label': 'Chat'},
            {'id': 'quiz', 'label': 'Quiz'},
          ],
          'metadata': {'choice_kind': 'solo_quiz_mode'},
        },
      ],
      'state_patch': {'phase': 'mode_selection'},
    },
    'last_seq': 3,
    'is_completed': false,
  });
}

const _oldTopicSuggestions = <Map<String, dynamic>>[
  {'id': 'geography', 'label': 'Geography'},
  {'id': 'science', 'label': 'Science'},
  {'id': 'sports', 'label': 'Sports'},
  {'id': 'custom_topic', 'label': 'Type my own topic'},
];

InteractiveSessionState _buildTopicSelectionSession() {
  return InteractiveSessionState.fromJson({
    'session_id': 'session-1',
    'story_id': 'story-1',
    'interaction_mode': 'interactive',
    'ai_role': 'host',
    'interactive_state': {
      'template': 'quiz',
      'phase': 'topic_selection',
      'session_type': 'solo',
      'topic_prompt': 'What topic do you want to play?',
      'topic_prompt_status': 'ready',
      'topic_suggestions': _oldTopicSuggestions,
    },
    'participants': const [],
    'events': [_topicSelectionStartedEvent],
    'last_seq': 1,
    'is_completed': false,
  });
}

InteractiveSessionState _buildMixedTopicAndModeSession({required int lastSeq}) {
  return InteractiveSessionState.fromJson({
    'session_id': 'session-1',
    'story_id': 'story-1',
    'interaction_mode': 'interactive',
    'ai_role': 'host',
    'interactive_state': {
      'template': 'quiz',
      'phase': 'topic_selection',
      'session_type': 'solo',
      'topic_prompt': 'What topic do you want to play?',
      'topic_prompt_status': 'ready',
      'topic_suggestions': _oldTopicSuggestions,
    },
    'participants': const [],
    'events': [
      _topicSelectionStartedEvent,
      {
        'id': 'topic-selected-event',
        'session_id': 'session-1',
        'seq': 2,
        'actor_type': 'user',
        'event_type': 'topic_selected',
        'payload': {'topic': 'Sex'},
      },
      {
        'id': 'mode-turn',
        'session_id': 'session-1',
        'seq': 3,
        'actor_type': 'ai',
        'event_type': 'interactive_turn',
        'payload': _modeSelectionTurn,
      },
    ],
    'current_turn': _modeSelectionTurn,
    'last_seq': lastSeq,
    'is_completed': false,
  });
}

const _topicSelectionStartedEvent = <String, dynamic>{
  'id': 'topic-selection-event',
  'session_id': 'session-1',
  'seq': 1,
  'actor_type': 'ai',
  'event_type': 'topic_selection_started',
  'payload': {
    'prompt': 'What topic do you want to play?',
    'topic_suggestions': _oldTopicSuggestions,
  },
};

const _modeSelectionTurn = <String, dynamic>{
  'type': 'interactive_turn.v1',
  'session_id': 'session-1',
  'turn_id': 'mode-turn',
  'seq': 3,
  'speaker': {'type': 'ai', 'role': 'host'},
  'blocks': [
    {'kind': 'text', 'text': 'Nice, Sex it is. What do you want to do next?'},
    {
      'kind': 'choice_group',
      'prompt': '',
      'options': [
        {'id': 'chat', 'label': 'Chat'},
        {'id': 'quiz', 'label': 'Quiz'},
      ],
      'metadata': {'choice_kind': 'solo_quiz_mode'},
    },
  ],
  'state_patch': {'phase': 'mode_selection'},
};

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
