import 'package:antroph_mobile/features/story/models/interactive_story_models.dart';
import 'package:antroph_mobile/features/story/widgets/interactive_story_renderer.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('InteractiveStoryRenderer renders quiz and scoreboard blocks', (
    tester,
  ) async {
    final session = InteractiveSessionState.fromJson({
      'session_id': 'session-1',
      'story_id': 'story-1',
      'interaction_mode': 'group',
      'ai_role': 'host',
      'participants': [],
      'events': [],
      'current_turn': {
        'type': 'interactive_turn.v1',
        'session_id': 'session-1',
        'turn_id': 'turn-1',
        'seq': 1,
        'speaker': {'type': 'ai', 'role': 'host'},
        'blocks': [
          {'kind': 'text', 'text': 'Round one'},
          {
            'kind': 'quiz',
            'question': 'Capital of France?',
            'options': [
              {'id': 'paris', 'label': 'Paris'},
              {'id': 'rome', 'label': 'Rome'},
            ],
          },
          {
            'kind': 'scoreboard',
            'players': [
              {'display_name': 'Ada', 'score': 1},
            ],
          },
          {'kind': 'unsupported'},
        ],
      },
      'last_seq': 1,
      'is_completed': false,
    });

    var selected = '';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InteractiveStoryRenderer(
            session: session,
            onChoice: (_) {},
            onQuizAnswer: (value, _) => selected = value,
            onRetryGeneration: () {},
            onReplay: () {},
            onLeave: () {},
          ),
        ),
      ),
    );

    expect(find.text('Round one'), findsOneWidget);
    expect(find.text('Capital of France?'), findsOneWidget);
    expect(find.text('Paris'), findsOneWidget);
    expect(find.text('Scoreboard'), findsOneWidget);
    expect(find.text('Unsupported block: unsupported'), findsOneWidget);

    await tester.tap(find.text('Paris'));
    expect(selected, 'paris');
  });

  testWidgets('InteractiveStoryRenderer renders active quiz transcript', (
    tester,
  ) async {
    final session = InteractiveSessionState.fromJson({
      'session_id': 'session-1',
      'story_id': 'story-1',
      'interaction_mode': 'group',
      'ai_role': 'host',
      'participants': [
        {'id': 'p1', 'session_id': 'session-1', 'display_name': 'Ada'},
        {'id': 'p2', 'session_id': 'session-1', 'display_name': 'Ben'},
      ],
      'interactive_state': {
        'template': 'quiz',
        'phase': 'question_active',
        'current_round': 2,
        'total_rounds': 5,
        'answered_count': 1,
        'eligible_count': 2,
        'question': {
          'question_id': 'q1',
          'text': 'Which planet is red?',
          'correct_option_id': 'mars',
          'expires_at': DateTime.now()
              .toUtc()
              .add(const Duration(seconds: 30))
              .toIso8601String(),
          'options': [
            {'id': 'mars', 'label': 'Mars'},
            {'id': 'venus', 'label': 'Venus'},
          ],
        },
      },
      'events': [],
      'last_seq': 1,
      'is_completed': false,
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InteractiveStoryRenderer(
            session: session,
            localQuizSelections: const {'q1': 'mars'},
            onChoice: (_) {},
            onQuizAnswer: (_, _) {},
            onRetryGeneration: () {},
            onReplay: () {},
            onLeave: () {},
          ),
        ),
      ),
    );

    expect(find.text('Which planet is red?'), findsOneWidget);
    expect(find.text('Mars'), findsOneWidget);
    expect(find.text('Venus'), findsOneWidget);
  });

  for (final hasHistoricalQuestionEvents in <bool>[true, false]) {
    testWidgets('timer confirmation stays above an active question '
        '${hasHistoricalQuestionEvents ? 'with events' : 'from state'}', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(400, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      const confirmation =
          'Untimed it is. Give me a second to line up your first question.';
      const lead = 'Alright, let us start with web development.';
      const questionText =
          'Which programming language is commonly used on the web?';
      final question = {
        'question_id': 'timer-question',
        'lead_text': lead,
        'text': questionText,
        'options': [
          {'id': 'a', 'label': 'Python'},
          {'id': 'b', 'label': 'HTML'},
        ],
      };
      final session = InteractiveSessionState.fromJson({
        'session_id': 'timer-order-session',
        'story_id': 'story-1',
        'interaction_mode': 'interactive',
        'ai_role': 'host',
        'interactive_state': {
          'template': 'quiz',
          'phase': 'question_active',
          'session_type': 'solo',
          'current_round': 1,
          'total_rounds': 3,
          'question': question,
        },
        'participants': const [],
        'events': [
          {
            'id': 'timer-choice',
            'session_id': 'timer-order-session',
            'seq': 4,
            'actor_type': 'user',
            'event_type': 'solo_user_message',
            'payload': {
              'text': 'untimed',
              'display_text': 'Untimed',
              'phase': 'timer_selection',
            },
          },
          if (hasHistoricalQuestionEvents) ...[
            {
              'id': 'stale-timer-turn',
              'session_id': 'timer-order-session',
              'seq': 5,
              'actor_type': 'ai',
              'event_type': 'interactive_turn',
              'payload': {
                'type': 'interactive_turn.v1',
                'session_id': 'timer-order-session',
                'turn_id': 'stale-timer-turn',
                'seq': 5,
                'speaker': {'type': 'ai', 'role': 'host'},
                'blocks': [
                  {'kind': 'text', 'text': 'Stale timer confirmation'},
                ],
              },
            },
            {
              'id': 'question-started',
              'session_id': 'timer-order-session',
              'seq': 6,
              'actor_type': 'system',
              'event_type': 'question_started',
              'payload': {'round': 1, 'question': question},
            },
          ],
        ],
        'current_turn': {
          'type': 'interactive_turn.v1',
          'session_id': 'timer-order-session',
          'turn_id': 'canonical-timer-turn',
          'seq': 5,
          'speaker': {'type': 'ai', 'role': 'host'},
          'blocks': [
            {'kind': 'text', 'text': confirmation},
          ],
          'state_patch': {'phase': 'generating_question'},
        },
        'last_seq': hasHistoricalQuestionEvents ? 6 : 5,
        'is_completed': false,
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InteractiveStoryRenderer(
              session: session,
              localQuizSelections: const {'timer-question': 'b'},
              onChoice: (_) {},
              onQuizAnswer: (_, _) {},
              onRetryGeneration: () {},
              onReplay: () {},
              onLeave: () {},
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 900));

      expect(find.text(confirmation), findsOneWidget);
      expect(find.text('Stale timer confirmation'), findsNothing);
      expect(find.text(lead), findsOneWidget);
      expect(find.text(questionText), findsOneWidget);
      expect(
        tester.getTopLeft(find.text(confirmation)).dy,
        lessThan(tester.getTopLeft(find.text(lead)).dy),
      );
      expect(
        tester.getTopLeft(find.text(confirmation)).dy,
        lessThan(tester.getTopLeft(find.text(questionText)).dy),
      );
    });
  }

  testWidgets('solo answer progress uses a personal confirmation', (
    tester,
  ) async {
    final soloSession = InteractiveSessionState.fromJson({
      'session_id': 'solo-session',
      'story_id': 'story-1',
      'interaction_mode': 'interactive',
      'ai_role': 'host',
      'interactive_state': {
        'template': 'quiz',
        'session_type': 'solo',
        'phase': 'question_active',
        'question': {
          'question_id': 'q1',
          'text': 'Which planet is red?',
          'options': [
            {'id': 'mars', 'label': 'Mars'},
            {'id': 'venus', 'label': 'Venus'},
          ],
        },
      },
      'events': [
        {
          'id': 'answer-progress',
          'session_id': 'solo-session',
          'seq': 1,
          'actor_type': 'system',
          'event_type': 'answer_received',
          'payload': {'answered_count': 1, 'eligible_count': 1},
        },
      ],
      'last_seq': 1,
      'is_completed': false,
    });

    Widget renderer(InteractiveSessionState session) => MaterialApp(
      home: Scaffold(
        body: InteractiveStoryRenderer(
          session: session,
          onChoice: (_) {},
          onQuizAnswer: (_, _) {},
          onRetryGeneration: () {},
          onReplay: () {},
          onLeave: () {},
        ),
      ),
    );

    await tester.pumpWidget(renderer(soloSession));

    expect(find.text('You have locked in your answer'), findsOneWidget);
    expect(find.text('1/1 players have locked in their answers'), findsNothing);

    final groupSession = soloSession.copyWith(
      interactiveState: {
        ...soloSession.interactiveState,
        'session_type': 'group',
      },
    );
    await tester.pumpWidget(renderer(groupSession));

    expect(find.text('You have locked in your answer'), findsNothing);
    expect(
      find.text('1/1 players have locked in their answers'),
      findsOneWidget,
    );
  });

  testWidgets('InteractiveStoryRenderer orders canonical quiz options A to D', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final session = InteractiveSessionState.fromJson({
      'session_id': 'session-1',
      'story_id': 'story-1',
      'interaction_mode': 'group',
      'ai_role': 'host',
      'participants': const [],
      'interactive_state': {
        'template': 'quiz',
        'session_type': 'group',
        'phase': 'question_active',
        'current_round': 1,
        'total_rounds': 3,
        'question': {
          'question_id': 'q-abcd',
          'text': 'Choose the second letter.',
          'correct_option_id': 'b',
          'expires_at': DateTime.now()
              .toUtc()
              .add(const Duration(seconds: 5))
              .toIso8601String(),
          'options': [
            {'id': 'd', 'label': 'Delta'},
            {'id': 'b', 'label': 'Beta'},
            {'id': 'a', 'label': 'Alpha'},
            {'id': 'c', 'label': 'Gamma'},
          ],
        },
      },
      'events': const [],
      'last_seq': 1,
      'is_completed': false,
    });
    var selected = '';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InteractiveStoryRenderer(
            session: session,
            onChoice: (_) {},
            onQuizAnswer: (optionId, _) => selected = optionId,
            onRetryGeneration: () {},
            onReplay: () {},
            onLeave: () {},
          ),
        ),
      ),
    );
    await tester.pump();

    final alphaY = tester.getTopLeft(find.text('Alpha')).dy;
    final betaY = tester.getTopLeft(find.text('Beta')).dy;
    final gammaY = tester.getTopLeft(find.text('Gamma')).dy;
    final deltaY = tester.getTopLeft(find.text('Delta')).dy;
    expect(alphaY, lessThan(betaY));
    expect(betaY, lessThan(gammaY));
    expect(gammaY, lessThan(deltaY));

    await tester.tap(find.text('Beta'));
    await tester.pump();
    await tester.tap(find.text('Confirm'));
    expect(selected, 'b');
  });

  testWidgets('InteractiveStoryRenderer renders results and final podium', (
    tester,
  ) async {
    final base = {
      'session_id': 'session-1',
      'story_id': 'story-1',
      'interaction_mode': 'group',
      'ai_role': 'host',
      'participants': [
        {
          'id': 'p1',
          'session_id': 'session-1',
          'display_name': 'Ada',
          'score': 2,
        },
        {
          'id': 'p2',
          'session_id': 'session-1',
          'display_name': 'Ben',
          'score': 1,
        },
      ],
      'events': [],
      'last_seq': 1,
    };
    final resultsSession = InteractiveSessionState.fromJson({
      ...base,
      'interactive_state': {
        'template': 'quiz',
        'phase': 'showing_results',
        'result': {
          'question_id': 'q1',
          'correct_option_id': 'mars',
          'explanation': 'Mars is known as the red planet.',
          'answered_count': 2,
          'eligible_count': 2,
          'answers': [
            {'participant_id': 'p1', 'is_correct': true, 'points_awarded': 1},
          ],
          'standings': [
            {
              'rank': 1,
              'participant_id': 'p1',
              'display_name': 'Ada',
              'score': 2,
            },
          ],
        },
      },
      'is_completed': false,
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InteractiveStoryRenderer(
            session: resultsSession,
            onChoice: (_) {},
            onQuizAnswer: (_, _) {},
            onRetryGeneration: () {},
            onReplay: () {},
            onLeave: () {},
          ),
        ),
      ),
    );

    expect(find.text('Correct Answer: mars'), findsOneWidget);
    expect(find.text('Mars is known as the red planet.'), findsOneWidget);

    final finalSession = InteractiveSessionState.fromJson({
      ...base,
      'interactive_state': {
        'template': 'quiz',
        'session_type': 'group',
        'phase': 'completed',
        'current_round': 3,
        'total_rounds': 3,
        'winner_participant_ids': ['p1'],
        'final_standings': [
          {
            'rank': 1,
            'participant_id': 'p1',
            'display_name': 'Ada',
            'score': 2,
          },
          {
            'rank': 2,
            'participant_id': 'p2',
            'display_name': 'Ben',
            'score': 1,
          },
        ],
      },
      'is_completed': true,
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InteractiveStoryRenderer(
            session: finalSession,
            onChoice: (_) {},
            onQuizAnswer: (_, _) {},
            onRetryGeneration: () {},
            onReplay: () {},
            onLeave: () {},
          ),
        ),
      ),
    );

    expect(find.text('Winner: Ada'), findsOneWidget);
    expect(find.text('Replay'), findsOneWidget);
    expect(find.text('Leave'), findsOneWidget);
  });

  testWidgets('group host opens player scores from Show final results', (
    tester,
  ) async {
    var completed = false;
    var advanceCalls = 0;

    InteractiveSessionState buildSession() => InteractiveSessionState.fromJson({
      'session_id': 'session-1',
      'story_id': 'story-1',
      'interaction_mode': 'group',
      'ai_role': 'host',
      'participants': [
        {
          'id': 'p1',
          'session_id': 'session-1',
          'user_id': 'u1',
          'display_name': 'Ada',
          'role': 'host',
          'status': 'active',
          'score': 4,
        },
        {
          'id': 'p2',
          'session_id': 'session-1',
          'user_id': 'u2',
          'display_name': 'Ben',
          'role': 'participant',
          'status': 'active',
          'score': 2,
        },
      ],
      'interactive_state': completed
          ? {
              'template': 'quiz',
              'session_type': 'group',
              'phase': 'completed',
              'current_round': 3,
              'total_rounds': 3,
              'winner_participant_ids': ['p1'],
              'final_standings': [
                {
                  'rank': 1,
                  'participant_id': 'p1',
                  'user_id': 'u1',
                  'display_name': 'Ada',
                  'score': 4,
                },
                {
                  'rank': 2,
                  'participant_id': 'p2',
                  'user_id': 'u2',
                  'display_name': 'Ben',
                  'score': 2,
                },
              ],
            }
          : {
              'template': 'quiz',
              'session_type': 'group',
              'phase': 'showing_results',
              'current_round': 3,
              'total_rounds': 3,
              'current_question_id': 'q3',
              'result': {
                'question_id': 'q3',
                'correct_option_id': 'a',
                'answers': const [],
                'standings': [
                  {
                    'rank': 1,
                    'participant_id': 'p1',
                    'display_name': 'Ada',
                    'score': 4,
                  },
                  {
                    'rank': 2,
                    'participant_id': 'p2',
                    'display_name': 'Ben',
                    'score': 2,
                  },
                ],
              },
            },
      'events': const [],
      'last_seq': 3,
      'is_completed': completed,
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => InteractiveStoryRenderer(
              session: buildSession(),
              currentUserId: 'u1',
              onChoice: (_) {},
              onQuizAnswer: (_, _) {},
              onRetryGeneration: () {},
              onAdvanceQuestion: () {
                advanceCalls++;
                setState(() => completed = true);
              },
              onReplay: () {},
              onLeave: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('Show final results'), findsOneWidget);
    await tester.tap(find.text('Show final results'));
    await tester.pumpAndSettle();

    expect(advanceCalls, 1);
    expect(
      find.byKey(const ValueKey('group-quiz-results-sheet')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('group-score-value-p1')), findsOneWidget);
    expect(find.byKey(const ValueKey('group-score-value-p2')), findsOneWidget);
    expect(find.text('4 pts'), findsNWidgets(2));
    expect(find.text('2 pts'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('group-quiz-results-done')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('group-quiz-results-sheet')),
      findsNothing,
    );
  });

  testWidgets('InteractiveStoryRenderer renders pending user text at bottom', (
    tester,
  ) async {
    final session = InteractiveSessionState.fromJson({
      'session_id': 'session-1',
      'story_id': 'story-1',
      'interaction_mode': 'interactive',
      'ai_role': 'host',
      'interactive_state': {
        'template': 'quiz',
        'phase': 'discussion',
        'session_type': 'solo',
      },
      'participants': [],
      'events': [
        {
          'id': 'event-1',
          'session_id': 'session-1',
          'seq': 1,
          'actor_type': 'ai',
          'event_type': 'interactive_turn',
          'payload': {
            'type': 'interactive_turn.v1',
            'session_id': 'session-1',
            'turn_id': 'turn-1',
            'seq': 1,
            'speaker': {'type': 'ai', 'role': 'host'},
            'blocks': [
              {'kind': 'text', 'text': 'What topic do you want to discuss?'},
            ],
          },
        },
      ],
      'last_seq': 1,
      'is_completed': false,
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InteractiveStoryRenderer(
            session: session,
            pendingTextMessages: const [
              PendingInteractiveTextMessage(
                clientId: 'pending-1',
                text: 'Computer science',
              ),
            ],
            onChoice: (_) {},
            onQuizAnswer: (_, _) {},
            onRetryGeneration: () {},
            onReplay: () {},
            onLeave: () {},
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 900));

    final aiPosition = tester.getTopLeft(
      find.text('What topic do you want to discuss?'),
    );
    final pendingPosition = tester.getTopLeft(find.text('Computer science'));

    expect(find.text('Computer science'), findsOneWidget);
    expect(pendingPosition.dy, greaterThan(aiPosition.dy));
  });

  testWidgets('solo Chat renders Aura replies as separate paragraphs', (
    tester,
  ) async {
    const reply =
        'Geography connects physical landscapes with how people build communities.\n\n'
        'Climate, trade, migration, and resources all shape those relationships.';
    final session = InteractiveSessionState.fromJson({
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
      'events': const [
        {
          'id': 'chat-turn-event',
          'session_id': 'session-1',
          'seq': 1,
          'actor_type': 'ai',
          'event_type': 'interactive_turn',
          'payload': {
            'type': 'interactive_turn.v1',
            'session_id': 'session-1',
            'turn_id': 'chat-turn',
            'seq': 1,
            'speaker': {'type': 'ai', 'role': 'host'},
            'blocks': [
              {'kind': 'text', 'text': reply},
            ],
          },
        },
      ],
      'last_seq': 1,
      'is_completed': false,
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InteractiveStoryRenderer(
            session: session,
            onChoice: (_) {},
            onQuizAnswer: (_, _) {},
            onRetryGeneration: () {},
            onReplay: () {},
            onLeave: () {},
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 900));

    final replyFinder = find.text(reply);
    expect(replyFinder, findsOneWidget);
    expect(tester.widget<Text>(replyFinder).data, contains('\n\n'));

    final streamingSession = InteractiveSessionState.fromJson({
      'session_id': 'session-2',
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
      'last_seq': 0,
      'is_completed': false,
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InteractiveStoryRenderer(
            session: streamingSession,
            streamingAssistantText: reply,
            onChoice: (_) {},
            onQuizAnswer: (_, _) {},
            onRetryGeneration: () {},
            onReplay: () {},
            onLeave: () {},
          ),
        ),
      ),
    );
    await tester.pump();

    final streamedReplyFinder = find.text(reply);
    expect(streamedReplyFinder, findsOneWidget);
    expect(tester.widget<Text>(streamedReplyFinder).data, contains('\n\n'));
  });

  testWidgets(
    'InteractiveStoryRenderer treats solo quiz phases as quiz when template is missing',
    (tester) async {
      final session = InteractiveSessionState.fromJson({
        'session_id': 'session-1',
        'story_id': 'story-1',
        'interaction_mode': 'interactive',
        'ai_role': 'host',
        'interactive_state': {'phase': 'discussion', 'session_type': 'solo'},
        'participants': [
          {
            'id': 'participant-1',
            'role': 'host',
            'status': 'active',
            'score': 0,
          },
        ],
        'events': [
          {
            'id': 'event-1',
            'session_id': 'session-1',
            'seq': 1,
            'actor_type': 'ai',
            'event_type': 'interactive_turn',
            'payload': {
              'type': 'interactive_turn.v1',
              'session_id': 'session-1',
              'turn_id': 'turn-1',
              'seq': 1,
              'speaker': {'type': 'ai', 'role': 'host'},
              'blocks': [
                {'kind': 'text', 'text': 'Let us unpack backend for frontend.'},
              ],
            },
          },
        ],
        'last_seq': 1,
        'is_completed': false,
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InteractiveStoryRenderer(
              session: session,
              onChoice: (_) {},
              onQuizAnswer: (_, _) {},
              onRetryGeneration: () {},
              onReplay: () {},
              onLeave: () {},
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 900));

      expect(find.text('Let us unpack backend for frontend.'), findsOneWidget);
      expect(find.text('host'), findsNothing);
      expect(find.text('1'), findsNothing);
    },
  );

  testWidgets(
    'InteractiveStoryRenderer never shows generic room header for game fallback',
    (tester) async {
      InteractiveSessionState fallbackSession({
        required String interactionMode,
        required String sessionType,
        required String text,
      }) => InteractiveSessionState.fromJson({
        'session_id': 'session-1',
        'story_id': 'story-1',
        'interaction_mode': interactionMode,
        'ai_role': 'host',
        'interactive_state': {
          'phase': 'unknown_transient_phase',
          'session_type': sessionType,
        },
        'participants': [
          {
            'id': 'participant-1',
            'role': 'host',
            'status': 'active',
            'score': 0,
          },
        ],
        'current_turn': {
          'type': 'interactive_turn.v1',
          'session_id': 'session-1',
          'turn_id': 'turn-1',
          'seq': 1,
          'speaker': {'type': 'ai', 'role': 'host'},
          'blocks': [
            {'kind': 'text', 'text': text},
          ],
        },
        'last_seq': 1,
        'is_completed': false,
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InteractiveStoryRenderer(
              session: fallbackSession(
                interactionMode: 'interactive',
                sessionType: 'solo',
                text: 'Solo fallback should not have a room header above it.',
              ),
              onChoice: (_) {},
              onQuizAnswer: (_, _) {},
              onRetryGeneration: () {},
              onReplay: () {},
              onLeave: () {},
            ),
          ),
        ),
      );

      expect(
        find.text('Solo fallback should not have a room header above it.'),
        findsOneWidget,
      );
      expect(find.text('host'), findsNothing);
      expect(find.text('1'), findsNothing);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InteractiveStoryRenderer(
              session: fallbackSession(
                interactionMode: 'group',
                sessionType: 'group',
                text: 'Group fallback should not have a room header above it.',
              ),
              onChoice: (_) {},
              onQuizAnswer: (_, _) {},
              onRetryGeneration: () {},
              onReplay: () {},
              onLeave: () {},
            ),
          ),
        ),
      );

      expect(
        find.text('Group fallback should not have a room header above it.'),
        findsOneWidget,
      );
      expect(find.text('host'), findsNothing);
      expect(find.text('1'), findsNothing);
    },
  );

  testWidgets(
    'InteractiveStoryRenderer does not wait for host after solo result',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final session = InteractiveSessionState.fromJson({
        'session_id': 'session-1',
        'story_id': 'story-1',
        'interaction_mode': 'interactive',
        'ai_role': 'host',
        'interactive_state': {
          'template': 'quiz',
          'phase': 'showing_results',
          'session_type': 'solo',
          'current_round': 3,
          'total_rounds': 3,
          'result': {
            'question_id': 'q1',
            'correct_option_id': 'ssd',
            'explanation': 'An SSD keeps files after power is off.',
            'answered_count': 1,
            'eligible_count': 1,
            'answers': const [],
            'standings': const [],
          },
        },
        'participants': const [],
        'events': const [],
        'last_seq': 1,
        'is_completed': false,
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InteractiveStoryRenderer(
              session: session,
              onChoice: (_) {},
              onQuizAnswer: (_, _) {},
              onRetryGeneration: () {},
              onReplay: () {},
              onLeave: () {},
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('Waiting for host'), findsNothing);
      expect(find.text('Calculating results...'), findsOneWidget);
    },
  );

  testWidgets('untimed solo quiz answers stay left after question reveal', (
    tester,
  ) async {
    const viewportWidth = 400.0;
    await tester.binding.setSurfaceSize(const Size(viewportWidth, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final session = InteractiveSessionState.fromJson({
      'session_id': 'session-1',
      'story_id': 'story-1',
      'interaction_mode': 'interactive',
      'ai_role': 'host',
      'interactive_state': {
        'template': 'quiz',
        'phase': 'question_active',
        'session_type': 'solo',
        'current_round': 1,
        'total_rounds': 3,
        'question': {
          'question_id': 'q1',
          'text': 'Which part of a computer stores files for the long term?',
          'correct_option_id': 'ssd',
          'options': [
            {'id': 'cpu', 'label': 'CPU cache'},
            {'id': 'ssd', 'label': 'SSD'},
          ],
        },
      },
      'participants': const [],
      'events': const [],
      'last_seq': 1,
      'is_completed': false,
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InteractiveStoryRenderer(
            session: session,
            onChoice: (_) {},
            onQuizAnswer: (_, _) {},
            onRetryGeneration: () {},
            onReplay: () {},
            onLeave: () {},
          ),
        ),
      ),
    );

    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    expect(find.text('CPU cache'), findsOneWidget);
    expect(find.text('SSD'), findsOneWidget);
    final firstAnswerButton = find
        .ancestor(
          of: find.text('CPU cache'),
          matching: find.byType(OutlinedButton),
        )
        .first;
    final firstAnswerRect = tester.getRect(firstAnswerButton);
    expect(firstAnswerRect.left, lessThan(40));
    expect(firstAnswerRect.width, greaterThan(viewportWidth * 0.7));
  });

  testWidgets(
    'InteractiveStoryRenderer renders a bottom-aligned topic suggestion column',
    (tester) async {
      const viewportHeight = 1000.0;
      await tester.binding.setSurfaceSize(const Size(400, viewportHeight));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      String? selectedTopic;
      var customTopicCalls = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InteractiveStoryRenderer(
              session: _topicSuggestionSession(
                includeEventSuggestions: true,
                includeStateSuggestions: false,
              ),
              onChoice: (_) {},
              onTopicSuggestion: (topic) => selectedTopic = topic,
              onCustomTopicRequested: () => customTopicCalls += 1,
              onQuizAnswer: (_, _) {},
              onRetryGeneration: () {},
              onReplay: () {},
              onLeave: () {},
            ),
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey('topic-suggestion-instruction')),
        findsNothing,
      );
      final historyChip = find.byKey(
        const ValueKey('topic-suggestion-history'),
      );
      final politicsChip = find.byKey(
        const ValueKey('topic-suggestion-politics'),
      );
      final educationChip = find.byKey(
        const ValueKey('topic-suggestion-education'),
      );
      final customTopicChip = find.byKey(
        const ValueKey('topic-suggestion-custom_topic'),
      );
      expect(historyChip, findsOneWidget);
      expect(politicsChip, findsOneWidget);
      expect(educationChip, findsOneWidget);
      expect(customTopicChip, findsOneWidget);
      final historyMaterial = find
          .descendant(of: historyChip, matching: find.byType(Material))
          .first;
      expect(
        tester.widget<Material>(historyMaterial).color,
        const Color(0xED101112),
      );
      expect(
        tester.widget<Material>(historyMaterial).borderRadius,
        BorderRadius.circular(8),
      );
      expect(
        tester.widget<Text>(find.text('History')).style?.color,
        Colors.white,
      );
      expect(tester.getSize(historyChip).height, greaterThanOrEqualTo(40));
      expect(tester.getSize(historyChip).height, lessThan(44));
      expect(
        tester.getSize(historyChip).width,
        closeTo(tester.getSize(find.text('History')).width + 28, 0.1),
      );
      expect(
        tester.getSize(politicsChip).width,
        closeTo(tester.getSize(find.text('Politics')).width + 28, 0.1),
      );
      expect(
        tester.getSize(educationChip).width,
        closeTo(tester.getSize(find.text('Education')).width + 28, 0.1),
      );
      expect(tester.getSize(customTopicChip).width, lessThanOrEqualTo(250));
      expect(
        tester.getSize(customTopicChip).width,
        greaterThan(tester.getSize(educationChip).width),
      );
      final historyRect = tester.getRect(historyChip);
      final politicsRect = tester.getRect(politicsChip);
      final educationRect = tester.getRect(educationChip);
      final customTopicRect = tester.getRect(customTopicChip);
      expect(
        tester.getRect(find.text('History')).center.dy,
        closeTo(historyRect.center.dy, 0.1),
      );
      expect(400 - historyRect.right, closeTo(8, 0.1));
      expect(historyRect.top, lessThan(politicsRect.top));
      expect(politicsRect.top, lessThan(educationRect.top));
      expect(educationRect.top, lessThan(customTopicRect.top));
      expect(historyRect.right, politicsRect.right);
      expect(historyRect.right, educationRect.right);
      expect(historyRect.right, customTopicRect.right);
      expect(customTopicRect.bottom, greaterThan(viewportHeight - 60));

      await tester.tap(find.text('History'));
      expect(selectedTopic, 'History');

      await tester.ensureVisible(find.text('Type my own topic'));
      await tester.tap(find.text('Type my own topic'));
      expect(customTopicCalls, 1);
      expect(selectedTopic, 'History');
    },
  );

  testWidgets('topic suggestion column stays responsive with large text', (
    tester,
  ) async {
    const viewportWidth = 220.0;
    await tester.binding.setSurfaceSize(const Size(viewportWidth, 420));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(1.6)),
          child: Scaffold(
            body: InteractiveStoryRenderer(
              session: _topicSuggestionSession(),
              onChoice: (_) {},
              onTopicSuggestion: (_) {},
              onCustomTopicRequested: () {},
              onQuizAnswer: (_, _) {},
              onRetryGeneration: () {},
              onReplay: () {},
              onLeave: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final chipFinders = [
      find.byKey(const ValueKey('topic-suggestion-history')),
      find.byKey(const ValueKey('topic-suggestion-politics')),
      find.byKey(const ValueKey('topic-suggestion-education')),
      find.byKey(const ValueKey('topic-suggestion-custom_topic')),
    ];
    for (final chipFinder in chipFinders) {
      expect(chipFinder, findsOneWidget);
      final rect = tester.getRect(chipFinder);
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(viewportWidth));
      expect(rect.height, greaterThanOrEqualTo(40));
    }
    final historyRect = tester.getRect(chipFinders[0]);
    for (final chipFinder in chipFinders.skip(1)) {
      final rect = tester.getRect(chipFinder);
      expect(rect.right, historyRect.right);
    }
    expect(
      tester.getSize(chipFinders.last).width,
      greaterThan(tester.getSize(chipFinders.first).width),
    );
    expect(
      tester
          .getTopLeft(find.byKey(const ValueKey('topic-suggestion-politics')))
          .dy,
      greaterThan(
        tester
            .getTopLeft(find.byKey(const ValueKey('topic-suggestion-history')))
            .dy,
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'mode selection renders bottom Quiz and Chat tabs and hides while pending',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      String? selectedOption;

      Widget renderer({Set<String> pendingKeys = const <String>{}}) =>
          MaterialApp(
            home: Scaffold(
              body: InteractiveStoryRenderer(
                session: _modeSelectionSession(),
                pendingKeys: pendingKeys,
                onChoice: (optionId) => selectedOption = optionId,
                onQuizAnswer: (_, _) {},
                onRetryGeneration: () {},
                onReplay: () {},
                onLeave: () {},
              ),
            ),
          );

      await tester.pumpWidget(renderer());
      await tester.pump(const Duration(milliseconds: 900));

      final quizTab = find.byKey(const ValueKey('mode-suggestion-quiz'));
      final chatTab = find.byKey(const ValueKey('mode-suggestion-chat'));
      expect(find.text('What do you want to do next?'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('mode-suggestion-instruction')),
        findsNothing,
      );
      expect(quizTab, findsOneWidget);
      expect(chatTab, findsOneWidget);
      expect(find.text('Take me to quiz'), findsOneWidget);
      expect(find.text('Chat with Aura'), findsOneWidget);
      expect(tester.getSize(quizTab).width, lessThanOrEqualTo(250));
      expect(tester.getSize(chatTab).width, lessThanOrEqualTo(250));
      expect(
        find.byKey(const ValueKey('topic-suggestion-history')),
        findsNothing,
      );
      expect(
        tester.getRect(quizTab).top,
        lessThan(tester.getRect(chatTab).top),
      );
      expect(tester.getRect(chatTab).bottom, greaterThan(740));

      await tester.tap(quizTab);
      expect(selectedOption, 'quiz');

      await tester.pumpWidget(
        renderer(pendingKeys: const {'mode-turn-option_select-quiz'}),
      );
      await tester.pump();
      expect(quizTab, findsNothing);
      expect(chatTab, findsNothing);
    },
  );

  testWidgets(
    'timer selection renders bottom Timed and Untimed tabs and hides while pending',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      String? selectedOption;

      Widget renderer({
        Set<String> pendingKeys = const <String>{},
        String phase = 'timer_selection',
      }) => MaterialApp(
        home: Scaffold(
          body: InteractiveStoryRenderer(
            session: _timerSelectionSession(phase: phase),
            pendingKeys: pendingKeys,
            onChoice: (optionId) => selectedOption = optionId,
            onQuizAnswer: (_, _) {},
            onRetryGeneration: () {},
            onReplay: () {},
            onLeave: () {},
          ),
        ),
      );

      await tester.pumpWidget(renderer());
      await tester.pump(const Duration(milliseconds: 900));

      final timedTab = find.byKey(const ValueKey('timer-suggestion-timed'));
      final untimedTab = find.byKey(const ValueKey('timer-suggestion-untimed'));
      expect(find.text('Do you want this quiz timed?'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('timer-suggestion-instruction')),
        findsNothing,
      );
      expect(timedTab, findsOneWidget);
      expect(untimedTab, findsOneWidget);
      expect(
        tester.getSize(timedTab).width,
        closeTo(tester.getSize(find.text('Timed')).width + 28, 0.1),
      );
      expect(
        tester.getSize(untimedTab).width,
        closeTo(tester.getSize(find.text('Untimed')).width + 28, 0.1),
      );
      expect(find.byKey(const ValueKey('mode-suggestion-quiz')), findsNothing);
      expect(
        tester.getRect(timedTab).top,
        lessThan(tester.getRect(untimedTab).top),
      );
      expect(tester.getRect(untimedTab).bottom, greaterThan(740));

      await tester.tap(timedTab);
      expect(selectedOption, 'timed');

      await tester.pumpWidget(
        renderer(pendingKeys: const {'timer-turn-option_select-timed'}),
      );
      await tester.pump();
      expect(timedTab, findsNothing);
      expect(untimedTab, findsNothing);

      await tester.pumpWidget(renderer(phase: 'generating_question'));
      await tester.pump();
      expect(timedTab, findsNothing);
      expect(untimedTab, findsNothing);
    },
  );

  testWidgets(
    'post-setup solo quiz renders persistent modes and topic decision tabs',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      String? selectedOption;

      final activeSession = _activeSoloQuizSession();
      final postQuestionSession = activeSession.copyWith(
        interactiveState: {
          ...activeSession.interactiveState,
          'phase': 'post_question_prompt',
          'result': const {
            'question_id': 'active-question',
            'correct_option_id': 'a',
          },
        },
      );

      Widget renderer({
        String mode = 'quiz',
        bool showDecision = false,
        InteractiveSessionState? session,
      }) => MaterialApp(
        home: Scaffold(
          body: InteractiveStoryRenderer(
            session: session ?? activeSession,
            soloViewMode: mode,
            showSoloModeSwitch: !showDecision,
            showQuizTopicDecision: showDecision,
            onChoice: (optionId) => selectedOption = optionId,
            onQuizAnswer: (_, _) {},
            onRetryGeneration: () {},
            onReplay: () {},
            onLeave: () {},
          ),
        ),
      );

      await tester.pumpWidget(renderer());
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pump();

      final quizMode = find.byKey(const ValueKey('persistent-mode-quiz'));
      final chatMode = find.byKey(const ValueKey('persistent-mode-chat'));
      expect(quizMode, findsNothing);
      expect(chatMode, findsOneWidget);
      expect(find.text('Next question'), findsNothing);
      expect(find.text('Continue Chat'), findsNothing);
      expect(
        find.byKey(const ValueKey('persistent-mode-instruction')),
        findsOneWidget,
      );
      final firstQuizAnswer = find
          .ancestor(
            of: find.text('Sumerians'),
            matching: find.byType(OutlinedButton),
          )
          .first;
      final quizAnswerRect = tester.getRect(firstQuizAnswer);
      final chatActionRect = tester.getRect(chatMode);
      expect(quizAnswerRect.left, lessThan(chatActionRect.left));
      expect(quizAnswerRect.width, greaterThan(chatActionRect.width));
      expect(400 - chatActionRect.right, closeTo(8, 0.1));
      await tester.tap(chatMode);
      expect(selectedOption, 'chat');

      await tester.pumpWidget(renderer(mode: 'chat'));
      await tester.pump();
      expect(quizMode, findsOneWidget);
      expect(chatMode, findsNothing);
      expect(find.text('Take me to quiz'), findsOneWidget);
      expect(find.text('Continue Chat'), findsNothing);
      expect(find.text('Next question'), findsNothing);
      expect(tester.getSize(quizMode).width, lessThanOrEqualTo(250));
      await tester.pumpWidget(renderer(mode: 'chat', showDecision: true));
      await tester.pump();
      final continueTopic = find.byKey(
        const ValueKey('topic-decision-continue_topic'),
      );
      final newTopic = find.byKey(const ValueKey('topic-decision-new_topic'));
      expect(quizMode, findsNothing);
      expect(chatMode, findsNothing);
      expect(continueTopic, findsOneWidget);
      expect(newTopic, findsOneWidget);
      expect(
        find.byKey(const ValueKey('topic-decision-instruction')),
        findsOneWidget,
      );
      expect(
        tester.getRect(continueTopic).top,
        lessThan(tester.getRect(newTopic).top),
      );

      await tester.tap(continueTopic);
      expect(selectedOption, 'continue_topic');

      await tester.pumpWidget(renderer(session: postQuestionSession));
      await tester.pump();
      expect(quizMode, findsOneWidget);
      expect(chatMode, findsOneWidget);
      expect(find.text('Next question'), findsOneWidget);
      expect(find.text('Continue Quiz'), findsNothing);
      expect(tester.getSize(quizMode).width, lessThanOrEqualTo(250));
      expect(
        find.descendant(
          of: quizMode,
          matching: find.byIcon(CupertinoIcons.chevron_right),
        ),
        findsOneWidget,
      );
      final nextQuestionRect = tester.getRect(find.text('Next question'));
      final chevronRect = tester.getRect(
        find.descendant(
          of: quizMode,
          matching: find.byIcon(CupertinoIcons.chevron_right),
        ),
      );
      expect(nextQuestionRect.center.dy, closeTo(chevronRect.center.dy, 0.1));
      expect(chevronRect.left, greaterThan(nextQuestionRect.right));
      expect(
        find.descendant(
          of: quizMode,
          matching: find.byIcon(CupertinoIcons.check_mark),
        ),
        findsNothing,
      );
      expect(
        tester.getRect(quizMode).top,
        lessThan(tester.getRect(chatMode).top),
      );
    },
  );

  testWidgets('topic suggestion tabs hide while text submission is pending', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InteractiveStoryRenderer(
            session: _topicSuggestionSession(),
            pendingKeys: const {'topic-turn-text-pending'},
            onChoice: (_) {},
            onTopicSuggestion: (_) {},
            onCustomTopicRequested: () {},
            onQuizAnswer: (_, _) {},
            onRetryGeneration: () {},
            onReplay: () {},
            onLeave: () {},
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('topic-suggestion-history')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('topic-suggestion-instruction')),
      findsNothing,
    );
  });

  testWidgets(
    'InteractiveStoryRenderer falls back to state topic suggestions',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InteractiveStoryRenderer(
              session: _topicSuggestionSession(
                includeEventSuggestions: false,
                includeStateSuggestions: true,
              ),
              onChoice: (_) {},
              onTopicSuggestion: (_) {},
              onCustomTopicRequested: () {},
              onQuizAnswer: (_, _) {},
              onRetryGeneration: () {},
              onReplay: () {},
              onLeave: () {},
            ),
          ),
        ),
      );

      expect(find.text('History'), findsOneWidget);
      expect(find.text('Politics'), findsOneWidget);
      expect(find.text('Education'), findsOneWidget);
      expect(find.text('Type my own topic'), findsOneWidget);
    },
  );

  testWidgets(
    'InteractiveStoryRenderer hides initial topics after phase change or clarification',
    (tester) async {
      Widget renderer(InteractiveSessionState session) => MaterialApp(
        home: Scaffold(
          body: InteractiveStoryRenderer(
            session: session,
            onChoice: (_) {},
            onTopicSuggestion: (_) {},
            onCustomTopicRequested: () {},
            onQuizAnswer: (_, _) {},
            onRetryGeneration: () {},
            onReplay: () {},
            onLeave: () {},
          ),
        ),
      );

      await tester.pumpWidget(
        renderer(_topicSuggestionSession(phase: 'mode_selection')),
      );
      expect(find.text('History'), findsNothing);
      expect(find.text('Type my own topic'), findsNothing);

      await tester.pumpWidget(
        renderer(_topicSuggestionSession(hasPendingClarification: true)),
      );
      await tester.pump();
      expect(find.text('History'), findsNothing);
      expect(find.text('Type my own topic'), findsNothing);
    },
  );

  testWidgets('solo clarification keeps its prompt left and choices right', (
    tester,
  ) async {
    const viewportWidth = 400.0;
    await tester.binding.setSurfaceSize(const Size(viewportWidth, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final session = InteractiveSessionState.fromJson({
      'session_id': 'clarification-session',
      'story_id': 'story-1',
      'interaction_mode': 'interactive',
      'ai_role': 'host',
      'interactive_state': {
        'template': 'quiz',
        'phase': 'topic_selection',
        'session_type': 'solo',
        'pending_topic_options': ['World history', 'Ancient history'],
      },
      'participants': const [],
      'events': const [],
      'current_turn': {
        'type': 'interactive_turn.v1',
        'session_id': 'clarification-session',
        'turn_id': 'clarification-turn',
        'seq': 2,
        'speaker': {'type': 'ai', 'role': 'host'},
        'blocks': [
          {
            'kind': 'choice_group',
            'prompt': 'Which kind of history do you mean?',
            'options': [
              {'id': 'world_history', 'label': 'World history'},
              {'id': 'ancient_history', 'label': 'Ancient history'},
            ],
            'metadata': {'choice_kind': 'solo_topic_clarification'},
          },
        ],
      },
      'last_seq': 2,
      'is_completed': false,
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InteractiveStoryRenderer(
            session: session,
            onChoice: (_) {},
            onQuizAnswer: (_, _) {},
            onRetryGeneration: () {},
            onReplay: () {},
            onLeave: () {},
          ),
        ),
      ),
    );
    await tester.pump();

    final promptRect = tester.getRect(
      find.text('Which kind of history do you mean?'),
    );
    final worldChoice = find
        .ancestor(
          of: find.text('World history'),
          matching: find.byType(InkWell),
        )
        .first;
    final ancientChoice = find
        .ancestor(
          of: find.text('Ancient history'),
          matching: find.byType(InkWell),
        )
        .first;
    expect(promptRect.left, lessThan(tester.getRect(worldChoice).left));
    expect(viewportWidth - tester.getRect(ancientChoice).right, lessThan(20));
  });

  testWidgets(
    'mode snapshot prefers canonical current turn over stale equal-seq topic turn',
    (tester) async {
      final session = InteractiveSessionState.fromJson({
        'session_id': 'mixed-mode-session',
        'story_id': 'story-1',
        'interaction_mode': 'interactive',
        'ai_role': 'host',
        'interactive_state': {
          'template': 'quiz',
          'phase': 'topic_selection',
          'session_type': 'solo',
          'selected_topic': 'History',
          'topic_suggestions': _topicSuggestions,
        },
        'participants': const [],
        'events': [
          {
            'id': 'historical-topic-suggestions',
            'session_id': 'mixed-mode-session',
            'seq': 1,
            'actor_type': 'ai',
            'event_type': 'topic_selection_started',
            'payload': {
              'prompt': 'What would you like to explore?',
              'topic_suggestions': _topicSuggestions,
            },
          },
          {
            'id': 'selected-topic',
            'session_id': 'mixed-mode-session',
            'seq': 2,
            'actor_type': 'user',
            'event_type': 'topic_selected',
            'payload': {'topic': 'History'},
          },
          {
            'id': 'stale-topic-turn-event',
            'session_id': 'mixed-mode-session',
            'seq': 3,
            'actor_type': 'ai',
            'event_type': 'interactive_turn',
            'payload': {
              'type': 'interactive_turn.v1',
              'session_id': 'mixed-mode-session',
              'turn_id': 'stale-topic-turn',
              'seq': 3,
              'speaker': {'type': 'ai', 'role': 'host'},
              'blocks': [
                {'kind': 'text', 'text': 'Which kind of history did you mean?'},
                {
                  'kind': 'choice_group',
                  'prompt': '',
                  'options': [
                    {'id': 'world_history', 'label': 'World history'},
                    {'id': 'ancient_history', 'label': 'Ancient history'},
                  ],
                  'metadata': {'choice_kind': 'solo_topic_clarification'},
                },
              ],
              'state_patch': {'phase': 'topic_selection'},
            },
          },
        ],
        'current_turn': {
          'type': 'interactive_turn.v1',
          'session_id': 'mixed-mode-session',
          'turn_id': 'canonical-mode-turn',
          'seq': 3,
          'speaker': {'type': 'ai', 'role': 'host'},
          'blocks': [
            {
              'kind': 'text',
              'text': 'History it is. What do you want to do next?',
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

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InteractiveStoryRenderer(
              session: session,
              onChoice: (_) {},
              onTopicSuggestion: (_) {},
              onCustomTopicRequested: () {},
              onQuizAnswer: (_, _) {},
              onRetryGeneration: () {},
              onReplay: () {},
              onLeave: () {},
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 900));

      expect(
        find.byKey(const ValueKey('topic-suggestion-history')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('topic-suggestion-custom_topic')),
        findsNothing,
      );
      expect(find.text('World history'), findsNothing);
      expect(find.text('Ancient history'), findsNothing);
      expect(
        find.byKey(const ValueKey('mode-suggestion-quiz')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('mode-suggestion-chat')),
        findsOneWidget,
      );
      expect(find.text('Take me to quiz'), findsOneWidget);
      expect(find.text('Chat with Aura'), findsOneWidget);
    },
  );

  testWidgets(
    'guided topic aspect renders newest candidates and path actions together',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(240, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final selectedIds = <String>[];
      var customAspectRequests = 0;
      final callLink = LayerLink();

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
            child: Scaffold(
              body: InteractiveStoryRenderer(
                session: _guidedAspectSession(),
                customTopicCallLink: callLink,
                onChoice: selectedIds.add,
                onCustomTopicRequested: () => customAspectRequests += 1,
                onQuizAnswer: (_, _) {},
                onRetryGeneration: () {},
                onReplay: () {},
                onLeave: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final firstAspect = find.byKey(
        const ValueKey('topic-aspect-ancient_cities'),
      );
      final secondAspect = find.byKey(
        const ValueKey('topic-aspect-trade_routes'),
      );
      final thirdAspect = find.byKey(const ValueKey('topic-aspect-daily_life'));
      final customAspect = find.byKey(
        const ValueKey('topic-aspect-custom_aspect'),
      );
      final quizAction = find.byKey(const ValueKey('topic-path-action-quiz'));
      final chatAction = find.byKey(const ValueKey('topic-path-action-chat'));
      final changeAction = find.byKey(
        const ValueKey('topic-path-action-change_aspect'),
      );

      expect(firstAspect, findsOneWidget);
      expect(secondAspect, findsOneWidget);
      expect(thirdAspect, findsOneWidget);
      expect(customAspect, findsOneWidget);
      expect(
        find.byKey(const ValueKey('topic-aspect-unused_fourth')),
        findsNothing,
      );
      expect(find.text('Old politics branch'), findsNothing);
      expect(find.text('Old culture branch'), findsNothing);
      expect(quizAction, findsOneWidget);
      expect(chatAction, findsOneWidget);
      expect(changeAction, findsOneWidget);
      expect(find.text('Take me to quiz'), findsOneWidget);
      expect(find.text('Chat with Aura'), findsOneWidget);
      expect(find.text('Choose another aspect'), findsOneWidget);
      expect(
        tester.getRect(quizAction).top,
        lessThan(tester.getRect(chatAction).top),
      );
      expect(
        tester.getRect(chatAction).top,
        lessThan(tester.getRect(changeAction).top),
      );
      expect(find.textContaining('History › Ancient worlds'), findsNothing);
      expect(
        find.byKey(const ValueKey('topic-aspect-instruction')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('topic-path-action-instruction')),
        findsNothing,
      );

      expect(
        find.byKey(
          const ValueKey('topic-path-action-call-target-change_aspect'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('topic-aspect-call-target-custom_aspect')),
        findsNothing,
      );
      expect(find.byType(CompositedTransformTarget), findsOneWidget);

      for (final finder in [
        firstAspect,
        secondAspect,
        thirdAspect,
        customAspect,
        quizAction,
        chatAction,
        changeAction,
      ]) {
        final rect = tester.getRect(finder);
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(240));
        expect(rect.width, lessThanOrEqualTo(220));
        expect(rect.height, greaterThanOrEqualTo(40));
      }
      expect(tester.getSize(thirdAspect).height, greaterThan(40));
      expect(tester.takeException(), isNull);

      await tester.ensureVisible(firstAspect);
      await tester.tap(firstAspect);
      await tester.ensureVisible(customAspect);
      await tester.tap(customAspect);
      await tester.ensureVisible(quizAction);
      await tester.tap(quizAction);
      await tester.ensureVisible(changeAction);
      await tester.tap(changeAction);

      expect(selectedIds, ['ancient_cities', 'quiz', 'change_aspect']);
      expect(customAspectRequests, 1);
    },
  );

  testWidgets('pending custom aspect hides every guided action', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InteractiveStoryRenderer(
            session: _guidedAspectSession(),
            pendingKeys: const {'guided-turn-text-custom-aspect'},
            onChoice: (_) {},
            onQuizAnswer: (_, _) {},
            onRetryGeneration: () {},
            onReplay: () {},
            onLeave: () {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('topic-aspect-ancient_cities')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('topic-aspect-custom_aspect')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('topic-path-action-quiz')), findsNothing);
    expect(find.byKey(const ValueKey('topic-path-action-chat')), findsNothing);
    expect(
      find.byKey(const ValueKey('topic-path-action-change_aspect')),
      findsNothing,
    );
  });

  testWidgets(
    'failed guided aspects show custom input retry and one action set',
    (tester) async {
      final selectedIds = <String>[];
      var customAspectRequests = 0;
      final callLink = LayerLink();

      Widget renderer({bool inputActive = false}) => MaterialApp(
        home: Scaffold(
          body: InteractiveStoryRenderer(
            session: _guidedAspectSession(status: 'failed'),
            customTopicCallLink: callLink,
            hideCustomTopicSuggestion: inputActive,
            onChoice: selectedIds.add,
            onCustomTopicRequested: () => customAspectRequests += 1,
            onQuizAnswer: (_, _) {},
            onRetryGeneration: () {},
            onReplay: () {},
            onLeave: () {},
          ),
        ),
      );

      await tester.pumpWidget(renderer());
      final customAspect = find.byKey(
        const ValueKey('topic-aspect-custom_aspect'),
      );
      final retry = find.byKey(
        const ValueKey('topic-path-action-retry_aspects'),
      );
      final chatAction = find.byKey(const ValueKey('topic-path-action-chat'));

      expect(customAspect, findsOneWidget);
      expect(retry, findsOneWidget);
      expect(find.text('Try suggestions again'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('topic-aspect-ancient_cities')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('topic-path-action-quiz')),
        findsOneWidget,
      );
      expect(chatAction, findsOneWidget);
      expect(
        find.byKey(const ValueKey('topic-path-action-change_aspect')),
        findsOneWidget,
      );
      expect(find.byType(CompositedTransformTarget), findsOneWidget);
      expect(
        find.byKey(
          const ValueKey('topic-path-action-call-target-retry_aspects'),
        ),
        findsOneWidget,
      );

      await tester.tap(customAspect);
      await tester.tap(retry);
      expect(customAspectRequests, 1);
      expect(selectedIds, ['retry_aspects']);

      await tester.pumpWidget(renderer(inputActive: true));
      await tester.pump();
      expect(customAspect, findsNothing);
      expect(retry, findsOneWidget);
      expect(chatAction, findsOneWidget);
    },
  );

  testWidgets(
    'guided aspect catalogue anchors call to custom without actions',
    (tester) async {
      final callLink = LayerLink();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InteractiveStoryRenderer(
              session: _guidedAspectSession(includeActions: false),
              customTopicCallLink: callLink,
              onChoice: (_) {},
              onCustomTopicRequested: () {},
              onQuizAnswer: (_, _) {},
              onRetryGeneration: () {},
              onReplay: () {},
              onLeave: () {},
            ),
          ),
        ),
      );

      final customAspect = find.byKey(
        const ValueKey('topic-aspect-custom_aspect'),
      );
      expect(customAspect, findsOneWidget);
      expect(
        find.byKey(const ValueKey('topic-aspect-call-target-custom_aspect')),
        findsOneWidget,
      );
      expect(find.byType(CompositedTransformTarget), findsOneWidget);
      expect(
        find.byKey(const ValueKey('topic-path-action-chat')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'guided topic transcript uses display text and gates historical choices',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InteractiveStoryRenderer(
              session: _guidedAspectSession(includeDisplayEvents: true),
              onChoice: (_) {},
              onCustomTopicRequested: () {},
              onQuizAnswer: (_, _) {},
              onRetryGeneration: () {},
              onReplay: () {},
              onLeave: () {},
            ),
          ),
        ),
      );

      expect(find.text('History and society'), findsOneWidget);
      expect(find.text('Ancient worlds'), findsOneWidget);
      expect(find.text('Mediterranean trade'), findsOneWidget);
      expect(find.text('Next question'), findsOneWidget);
      expect(find.text('candidate_internal_id'), findsNothing);
      expect(find.text('aspect_internal_id'), findsNothing);
      expect(find.text('topic_internal_id'), findsNothing);
      expect(find.text('continue_topic'), findsNothing);
      expect(find.text('continue_with_topic'), findsNothing);
      expect(find.text('Continue'), findsNothing);

      final inactiveSession = _guidedAspectSession(phase: 'mode_selection');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InteractiveStoryRenderer(
              session: inactiveSession,
              onChoice: (_) {},
              onCustomTopicRequested: () {},
              onQuizAnswer: (_, _) {},
              onRetryGeneration: () {},
              onReplay: () {},
              onLeave: () {},
            ),
          ),
        ),
      );
      await tester.pump();
      expect(
        find.byKey(const ValueKey('topic-aspect-ancient_cities')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('topic-path-action-chat')),
        findsNothing,
      );
      expect(find.text('Old politics branch'), findsNothing);
    },
  );

  testWidgets(
    'old action turn does not combine with a canonical aspect-only turn',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InteractiveStoryRenderer(
              session: _guidedAspectSession(
                includeActions: false,
                historicalChoiceKind: 'solo_topic_path_actions',
              ),
              onChoice: (_) {},
              onCustomTopicRequested: () {},
              onQuizAnswer: (_, _) {},
              onRetryGeneration: () {},
              onReplay: () {},
              onLeave: () {},
            ),
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey('topic-aspect-ancient_cities')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('topic-aspect-custom_aspect')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('topic-path-action-quiz')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('topic-path-action-chat')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('topic-path-action-change_aspect')),
        findsNothing,
      );
      expect(find.text('Old quiz action'), findsNothing);
      expect(find.text('Old chat action'), findsNothing);
      expect(find.text('Old change action'), findsNothing);
    },
  );

  testWidgets(
    'old aspect turn does not combine with a max-depth action-only turn',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InteractiveStoryRenderer(
              session: _guidedAspectSession(
                status: 'max_depth',
                includeCandidates: false,
              ),
              onChoice: (_) {},
              onCustomTopicRequested: () {},
              onQuizAnswer: (_, _) {},
              onRetryGeneration: () {},
              onReplay: () {},
              onLeave: () {},
            ),
          ),
        ),
      );

      expect(find.text('Old politics branch'), findsNothing);
      expect(find.text('Old culture branch'), findsNothing);
      expect(
        find.byKey(const ValueKey('topic-aspect-ancient_cities')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('topic-aspect-custom_aspect')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('topic-path-action-quiz')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('topic-path-action-chat')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('topic-path-action-change_aspect')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'generating aspect status suppresses stale guided controls and loads',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InteractiveStoryRenderer(
              session: _guidedAspectSession(
                status: 'generating',
                currentRevision: 'revision-stale',
              ),
              onChoice: (_) {},
              onCustomTopicRequested: () {},
              onQuizAnswer: (_, _) {},
              onRetryGeneration: () {},
              onReplay: () {},
              onLeave: () {},
            ),
          ),
        ),
      );

      expect(find.text('Finding topic aspects'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('topic-aspect-ancient_cities')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('topic-aspect-custom_aspect')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('topic-path-action-quiz')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('topic-path-action-chat')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('topic-path-action-change_aspect')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('topic-path-action-retry_aspects')),
        findsNothing,
      );
    },
  );

  testWidgets('action-only canonical turn uses current state aspect fallback', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InteractiveStoryRenderer(
            session: _guidedAspectSession(includeCandidates: false),
            onChoice: (_) {},
            onCustomTopicRequested: () {},
            onQuizAnswer: (_, _) {},
            onRetryGeneration: () {},
            onReplay: () {},
            onLeave: () {},
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('topic-aspect-ancient_cities')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('topic-aspect-trade_routes')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('topic-aspect-daily_life')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('topic-aspect-custom_aspect')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('topic-path-action-quiz')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('topic-path-action-chat')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('topic-path-action-change_aspect')),
      findsOneWidget,
    );
  });

  testWidgets(
    'clean max-depth snapshot uses selected topic path and custom aspect',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InteractiveStoryRenderer(
              session: _guidedAspectSession(
                status: 'max_depth',
                includeCandidates: false,
                includeHistorical: false,
                useSelectedTopicPathOnly: true,
              ),
              onChoice: (_) {},
              onCustomTopicRequested: () {},
              onQuizAnswer: (_, _) {},
              onRetryGeneration: () {},
              onReplay: () {},
              onLeave: () {},
            ),
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey('topic-aspect-ancient_cities')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('topic-aspect-custom_aspect')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('topic-path-action-quiz')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('topic-path-action-chat')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('topic-path-action-change_aspect')),
        findsOneWidget,
      );
      expect(find.textContaining('History › Ancient worlds'), findsNothing);
    },
  );

  testWidgets(
    'root topic catalogue orders compact Continue after aspects and custom',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(220, 1300));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final selectedIds = <String>[];
      var customAspectRequests = 0;
      final callLink = LayerLink();

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.8)),
            child: Scaffold(
              body: InteractiveStoryRenderer(
                session: _rootTopicContinueSession(),
                customTopicCallLink: callLink,
                onChoice: selectedIds.add,
                onCustomTopicRequested: () => customAspectRequests += 1,
                onQuizAnswer: (_, _) {},
                onRetryGeneration: () {},
                onReplay: () {},
                onLeave: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final firstAspect = find.byKey(
        const ValueKey('topic-aspect-root_history'),
      );
      final secondAspect = find.byKey(
        const ValueKey('topic-aspect-root_inventions'),
      );
      final thirdAspect = find.byKey(
        const ValueKey('topic-aspect-root_people'),
      );
      final customAspect = find.byKey(
        const ValueKey('topic-aspect-custom_aspect'),
      );
      final continueAction = find.byKey(
        const ValueKey('topic-aspect-continue_with_topic'),
      );

      expect(firstAspect, findsOneWidget);
      expect(secondAspect, findsOneWidget);
      expect(thirdAspect, findsOneWidget);
      expect(customAspect, findsOneWidget);
      expect(continueAction, findsOneWidget);
      expect(find.text('Type my own aspect'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('topic-aspect-unused_root_fourth')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('topic-path-action-quiz')),
        findsNothing,
      );

      final ordered = [
        firstAspect,
        secondAspect,
        thirdAspect,
        customAspect,
        continueAction,
      ];
      for (var index = 0; index < ordered.length - 1; index++) {
        expect(
          tester.getRect(ordered[index]).top,
          lessThan(tester.getRect(ordered[index + 1]).top),
        );
      }
      expect(
        tester.getSize(continueAction).width,
        lessThanOrEqualTo(tester.getSize(customAspect).width),
      );
      for (final option in ordered) {
        final rect = tester.getRect(option);
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(220));
        expect(rect.height, greaterThanOrEqualTo(40));
      }
      expect(
        find.byKey(
          const ValueKey('topic-aspect-call-target-continue_with_topic'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('topic-aspect-call-target-custom_aspect')),
        findsNothing,
      );
      expect(find.byType(CompositedTransformTarget), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.ensureVisible(continueAction);
      await tester.tap(continueAction);
      await tester.ensureVisible(customAspect);
      await tester.tap(customAspect);

      expect(selectedIds, ['continue_with_topic']);
      expect(customAspectRequests, 1);
    },
  );

  testWidgets(
    'expanded root actions replace catalogue and anchor the call to Chat',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(220, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final selectedIds = <String>[];
      final callLink = LayerLink();

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(220, 1000),
              textScaler: TextScaler.linear(1.8),
            ),
            child: Scaffold(
              body: InteractiveStoryRenderer(
                session: _rootTopicContinueSession(expanded: true),
                customTopicCallLink: callLink,
                onChoice: selectedIds.add,
                onCustomTopicRequested: () {},
                onQuizAnswer: (_, _) {},
                onRetryGeneration: () {},
                onReplay: () {},
                onLeave: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      final quizAction = find.byKey(const ValueKey('topic-path-action-quiz'));
      final chatAction = find.byKey(const ValueKey('topic-path-action-chat'));
      final chooseAspectAction = find.byKey(
        const ValueKey('topic-path-action-choose_aspect'),
      );

      expect(
        find.byKey(const ValueKey('topic-aspect-root_history')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('topic-aspect-custom_aspect')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('topic-aspect-continue_with_topic')),
        findsNothing,
      );
      expect(quizAction, findsOneWidget);
      expect(chatAction, findsOneWidget);
      expect(chooseAspectAction, findsNothing);
      expect(find.text('Take me to quiz'), findsOneWidget);
      expect(find.text('Chat with Aura'), findsOneWidget);
      expect(find.text('Choose an aspect'), findsNothing);
      expect(find.text("Let's keep History broad."), findsOneWidget);
      expect(
        find.text(
          'Would you like to take a quiz about History or chat with Aura?',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'Would you like to take a quiz about History, chat with Aura, or choose an aspect first?',
        ),
        findsNothing,
      );
      expect(
        tester.getRect(quizAction).top,
        lessThan(tester.getRect(chatAction).top),
      );
      expect(
        find.byKey(const ValueKey('topic-path-action-call-target-chat')),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('topic-path-action-call-target-choose_aspect'),
        ),
        findsNothing,
      );
      expect(find.byType(CompositedTransformTarget), findsOneWidget);
      for (final option in [quizAction, chatAction]) {
        final rect = tester.getRect(option);
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(220));
        expect(rect.height, greaterThanOrEqualTo(40));
      }
      expect(tester.takeException(), isNull);

      await tester.tap(quizAction);
      await tester.tap(chatAction);
      expect(selectedIds, ['quiz', 'chat']);
    },
  );

  testWidgets(
    'expansion flag and pending state immediately gate obsolete root controls',
    (tester) async {
      Widget renderer(
        InteractiveSessionState session, {
        Set<String> pendingKeys = const {},
      }) => MaterialApp(
        home: Scaffold(
          body: InteractiveStoryRenderer(
            session: session,
            pendingKeys: pendingKeys,
            onChoice: (_) {},
            onCustomTopicRequested: () {},
            onQuizAnswer: (_, _) {},
            onRetryGeneration: () {},
            onReplay: () {},
            onLeave: () {},
          ),
        ),
      );

      await tester.pumpWidget(
        renderer(
          _rootTopicContinueSession(expanded: true, turnExpanded: false),
        ),
      );
      expect(
        find.byKey(const ValueKey('topic-aspect-root_history')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('topic-aspect-continue_with_topic')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('topic-path-action-quiz')),
        findsNothing,
      );

      await tester.pumpWidget(
        renderer(
          _rootTopicContinueSession(expanded: false, turnExpanded: true),
        ),
      );
      await tester.pump();
      expect(
        find.byKey(const ValueKey('topic-path-action-quiz')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('topic-path-action-chat')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('topic-path-action-choose_aspect')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('topic-aspect-root_history')),
        findsOneWidget,
      );

      await tester.pumpWidget(
        renderer(_rootTopicContinueSession(includeCurrentTurn: false)),
      );
      await tester.pump();
      final fallbackCustom = find.byKey(
        const ValueKey('topic-aspect-custom_aspect'),
      );
      final fallbackContinue = find.byKey(
        const ValueKey('topic-aspect-continue_with_topic'),
      );
      expect(
        find.byKey(const ValueKey('topic-aspect-root_history')),
        findsOneWidget,
      );
      expect(fallbackCustom, findsOneWidget);
      expect(fallbackContinue, findsOneWidget);
      expect(
        tester.getRect(fallbackCustom).top,
        lessThan(tester.getRect(fallbackContinue).top),
      );

      await tester.pumpWidget(
        renderer(
          _rootTopicContinueSession(),
          pendingKeys: const {'root-turn-option_select-continue_with_topic'},
        ),
      );
      await tester.pump();
      expect(
        find.byKey(const ValueKey('topic-aspect-root_history')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('topic-aspect-custom_aspect')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('topic-aspect-continue_with_topic')),
        findsNothing,
      );
    },
  );

  testWidgets('read-only history suppresses every live interaction', (
    tester,
  ) async {
    var selectedChoice = '';
    final session = InteractiveSessionState.fromJson({
      'session_id': 'history-session',
      'story_id': 'story-1',
      'interaction_mode': 'interactive',
      'ai_role': 'host',
      'interactive_state': {
        'template': 'quiz',
        'phase': 'complete',
        'session_type': 'solo',
        'selected_topic': 'History',
      },
      'participants': const [],
      'events': [
        {
          'id': 'history-turn-event',
          'session_id': 'history-session',
          'seq': 1,
          'actor_type': 'ai',
          'event_type': 'interactive_turn',
          'payload': {
            'type': 'interactive_turn.v1',
            'session_id': 'history-session',
            'turn_id': 'history-turn',
            'seq': 1,
            'speaker': {'type': 'ai', 'role': 'host'},
            'blocks': [
              {'kind': 'text', 'text': 'This is a saved transcript.'},
              {
                'kind': 'choice_group',
                'prompt': 'Old action',
                'options': [
                  {'id': 'archive-option', 'label': 'Archive option'},
                ],
              },
            ],
          },
        },
      ],
      'last_seq': 1,
      'is_completed': true,
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InteractiveStoryRenderer(
            session: session,
            readOnly: true,
            showSoloModeSwitch: true,
            onChoice: (value) => selectedChoice = value,
            onQuizAnswer: (_, _) {},
            onRetryGeneration: () {},
            onReplay: () {},
            onLeave: () {},
          ),
        ),
      ),
    );

    expect(find.text('This is a saved transcript.'), findsOneWidget);
    expect(find.text('Archive option'), findsOneWidget);
    expect(find.text('Switch between Chat and Quiz.'), findsNothing);
    await tester.tap(find.text('Archive option'), warnIfMissed: false);
    await tester.pump();
    expect(selectedChoice, isEmpty);
  });
}

const _topicSuggestions = <Map<String, dynamic>>[
  {'id': 'history', 'label': 'History'},
  {'id': 'politics', 'label': 'Politics'},
  {'id': 'education', 'label': 'Education'},
  {'id': 'custom_topic', 'label': 'Type my own topic'},
];

InteractiveSessionState _guidedAspectSession({
  String phase = 'topic_selection',
  String status = 'ready',
  bool includeDisplayEvents = false,
  bool includeCandidates = true,
  bool includeActions = true,
  bool includeHistorical = true,
  String historicalChoiceKind = 'solo_topic_aspect',
  String currentRevision = 'revision-current',
  bool useSelectedTopicPathOnly = false,
}) {
  return InteractiveSessionState.fromJson({
    'session_id': 'guided-aspect-session',
    'story_id': 'story-1',
    'interaction_mode': 'interactive',
    'ai_role': 'host',
    'interactive_state': {
      'template': 'quiz',
      'phase': phase,
      'session_type': 'solo',
      'topic_selection_stage': 'aspect',
      'selected_topic': 'History',
      if (!useSelectedTopicPathOnly)
        'topic_path': [
          'History',
          {'id': 'ancient_worlds', 'label': 'Ancient worlds'},
        ],
      if (useSelectedTopicPathOnly)
        'selected_topic_path': ['History', 'Ancient worlds'],
      'topic_drilldown_depth': 2,
      'topic_aspect_revision': 'revision-current',
      'topic_aspect_status': status,
      'allow_custom_aspect': true,
      'pending_topic_aspects': status == 'max_depth'
          ? const <Map<String, String>>[]
          : const [
              {
                'id': 'ancient_cities',
                'label': 'How ancient cities were governed',
                'value': 'ancient city government',
              },
              {
                'id': 'trade_routes',
                'label': 'Trade routes and cultural exchange',
                'value': 'ancient trade routes',
              },
              {
                'id': 'daily_life',
                'label': 'Daily life across early civilizations',
                'value': 'daily life in early civilizations',
              },
              {
                'id': 'unused_fourth',
                'label': 'This fourth generated aspect is not shown',
                'value': 'unused fourth aspect',
              },
            ],
    },
    'participants': const [],
    'events': [
      if (includeHistorical)
        {
          'id': 'old-aspect-turn',
          'session_id': 'guided-aspect-session',
          'seq': 4,
          'actor_type': 'ai',
          'event_type': 'interactive_turn',
          'payload': {
            'type': 'interactive_turn.v1',
            'session_id': 'guided-aspect-session',
            'turn_id': 'old-aspect-turn',
            'seq': 4,
            'speaker': {'type': 'ai', 'role': 'host'},
            'blocks': [
              {
                'kind': 'choice_group',
                'prompt': 'Old choices',
                'options': historicalChoiceKind == 'solo_topic_path_actions'
                    ? const [
                        {'id': 'quiz', 'label': 'Old quiz action'},
                        {'id': 'chat', 'label': 'Old chat action'},
                        {'id': 'change_aspect', 'label': 'Old change action'},
                      ]
                    : const [
                        {'id': 'old_politics', 'label': 'Old politics branch'},
                        {'id': 'old_culture', 'label': 'Old culture branch'},
                      ],
                'metadata': {
                  'choice_kind': historicalChoiceKind,
                  'topic_path': ['History', 'Old branch'],
                  'depth': 1,
                  'revision': 'revision-old',
                },
              },
            ],
            'state_patch': {
              'phase': 'topic_selection',
              'topic_selection_stage': 'aspect',
            },
          },
        },
      if (includeDisplayEvents) ...[
        if (includeCandidates)
          {
            'id': 'candidate-selected',
            'session_id': 'guided-aspect-session',
            'seq': 5,
            'actor_type': 'user',
            'event_type': 'topic_candidate_selected',
            'payload': {
              'candidate_id': 'candidate_internal_id',
              'display_text': 'History and society',
            },
          },
        {
          'id': 'aspect-selected',
          'session_id': 'guided-aspect-session',
          'seq': 6,
          'actor_type': 'user',
          'event_type': 'topic_aspect_selected',
          'payload': {
            'aspect_id': 'aspect_internal_id',
            'display_text': 'Ancient worlds',
          },
        },
        {
          'id': 'topic-selected',
          'session_id': 'guided-aspect-session',
          'seq': 7,
          'actor_type': 'user',
          'event_type': 'topic_selected',
          'payload': {
            'topic': 'topic_internal_id',
            'display_text': 'Mediterranean trade',
          },
        },
        {
          'id': 'continue-topic-message',
          'session_id': 'guided-aspect-session',
          'seq': 8,
          'actor_type': 'user',
          'event_type': 'solo_user_message',
          'payload': {
            'text': 'continue_topic',
            'phase': 'post_question_prompt',
          },
        },
        {
          'id': 'continue-with-topic-message',
          'session_id': 'guided-aspect-session',
          'seq': 9,
          'actor_type': 'user',
          'event_type': 'solo_user_message',
          'payload': {
            'text': 'continue_with_topic',
            'phase': 'topic_selection',
          },
        },
      ],
    ],
    'current_turn': {
      'type': 'interactive_turn.v1',
      'session_id': 'guided-aspect-session',
      'turn_id': 'current-guided-aspect-turn',
      'seq': 20,
      'speaker': {'type': 'ai', 'role': 'host'},
      'blocks': [
        if (includeCandidates)
          {
            'kind': 'choice_group',
            'prompt': 'Choose a direction',
            'options': [
              {
                'id': 'ancient_cities',
                'label': 'How ancient cities were governed',
              },
              {
                'id': 'trade_routes',
                'label': 'Trade routes and cultural exchange',
              },
              {
                'id': 'daily_life',
                'label': 'Daily life across early civilizations',
              },
              {'id': 'custom_aspect', 'label': 'Custom aspect'},
            ],
            'metadata': {
              'choice_kind': 'solo_topic_aspect',
              'topic_path': ['History', 'Ancient worlds'],
              'depth': 2,
              'revision': currentRevision,
            },
          },
        if (includeActions)
          {
            'kind': 'choice_group',
            'prompt': 'Choose what happens next',
            'options': [
              if (status == 'failed')
                {'id': 'retry_aspects', 'label': 'Try suggestions again'},
              {'id': 'change_aspect', 'label': 'Change'},
              {'id': 'chat', 'label': 'Discuss'},
              {'id': 'quiz', 'label': 'Quiz'},
            ],
            'metadata': {
              'choice_kind': 'solo_topic_path_actions',
              'topic_path': ['History', 'Ancient worlds'],
              'depth': 2,
              'revision': currentRevision,
            },
          },
      ],
      'state_patch': {
        'phase': 'topic_selection',
        'topic_selection_stage': 'aspect',
      },
    },
    'last_seq': 20,
    'is_completed': false,
  });
}

InteractiveSessionState _rootTopicContinueSession({
  bool expanded = false,
  bool? turnExpanded,
  bool includeCurrentTurn = true,
  String status = 'ready',
}) {
  final effectiveTurnExpanded = turnExpanded ?? expanded;
  return InteractiveSessionState.fromJson({
    'session_id': 'root-topic-session',
    'story_id': 'story-1',
    'interaction_mode': 'interactive',
    'ai_role': 'host',
    'interactive_state': {
      'template': 'quiz',
      'phase': 'topic_selection',
      'session_type': 'solo',
      'topic_selection_stage': 'aspect',
      'selected_topic': 'History',
      'topic_path': ['History'],
      'topic_drilldown_depth': 0,
      'topic_aspect_revision': 'root-revision',
      'topic_aspect_status': status,
      'topic_path_actions_expanded': expanded,
      'allow_custom_aspect': true,
      'pending_topic_aspects': const [
        {
          'id': 'root_history',
          'label': 'Major periods across world history',
          'value': 'major historical periods',
        },
        {
          'id': 'root_inventions',
          'label': 'Inventions that changed everyday life',
          'value': 'transformative inventions',
        },
        {
          'id': 'root_people',
          'label': 'People who shaped their societies',
          'value': 'influential historical people',
        },
        {
          'id': 'unused_root_fourth',
          'label': 'A fourth root aspect that must stay hidden',
          'value': 'unused root aspect',
        },
      ],
    },
    'participants': const [],
    'events': [
      if (expanded)
        {
          'id': 'root-continue-event',
          'session_id': 'root-topic-session',
          'seq': 9,
          'actor_type': 'user',
          'event_type': 'topic_aspect_selected',
          'payload': const {
            'action': 'continue_with_topic',
            'option_id': 'continue_with_topic',
            'topic_path': ['History'],
          },
        },
    ],
    if (includeCurrentTurn)
      'current_turn': {
        'type': 'interactive_turn.v1',
        'session_id': 'root-topic-session',
        'turn_id': effectiveTurnExpanded
            ? 'root-actions-turn'
            : 'root-aspects-turn',
        'seq': 10,
        'speaker': {'type': 'ai', 'role': 'host'},
        'blocks': [
          if (effectiveTurnExpanded)
            {
              'kind': 'text',
              'text':
                  'Would you like to take a quiz about History, chat with Aura, or choose an aspect first?',
            },
          if (!effectiveTurnExpanded)
            {
              'kind': 'choice_group',
              'prompt': 'Choose a direction',
              'options': const [
                {'id': 'continue_with_topic', 'label': 'Keep this broad topic'},
                {
                  'id': 'root_history',
                  'label': 'Major periods across world history',
                },
                {
                  'id': 'root_inventions',
                  'label': 'Inventions that changed everyday life',
                },
                {
                  'id': 'root_people',
                  'label': 'People who shaped their societies',
                },
                {
                  'id': 'unused_root_fourth',
                  'label': 'A fourth root aspect that must stay hidden',
                },
              ],
              'metadata': {
                'choice_kind': 'solo_topic_aspect',
                'topic_path': ['History'],
                'depth': 0,
                'revision': 'root-revision',
                'allow_custom_aspect': true,
                'topic_path_actions_expanded': false,
              },
            },
          if (effectiveTurnExpanded)
            {
              'kind': 'choice_group',
              'prompt': 'Choose what happens next',
              'options': const [
                {'id': 'choose_aspect', 'label': 'Pick a direction'},
                {'id': 'chat', 'label': 'Discuss'},
                {'id': 'quiz', 'label': 'Quiz'},
              ],
              'metadata': {
                'choice_kind': 'solo_topic_path_actions',
                'topic_path': ['History'],
                'depth': 0,
                'revision': 'root-revision',
                'allow_custom_aspect': true,
                'topic_path_actions_expanded': true,
              },
            },
        ],
        'state_patch': {
          'phase': 'topic_selection',
          'topic_selection_stage': 'aspect',
          'topic_path_actions_expanded': effectiveTurnExpanded,
        },
      },
    'last_seq': 10,
    'is_completed': false,
  });
}

InteractiveSessionState _topicSuggestionSession({
  String phase = 'topic_selection',
  bool includeEventSuggestions = true,
  bool includeStateSuggestions = true,
  bool hasPendingClarification = false,
}) {
  return InteractiveSessionState.fromJson({
    'session_id': 'topic-session',
    'story_id': 'story-1',
    'interaction_mode': 'interactive',
    'ai_role': 'host',
    'interactive_state': {
      'template': 'quiz',
      'phase': phase,
      'session_type': 'solo',
      'topic_prompt': 'What would you like to explore?',
      if (includeStateSuggestions) 'topic_suggestions': _topicSuggestions,
      if (hasPendingClarification)
        'pending_topic_options': const ['World history', 'Ancient history'],
    },
    'participants': const [],
    'events': [
      {
        'id': 'topic-event',
        'session_id': 'topic-session',
        'seq': 1,
        'actor_type': 'ai',
        'event_type': 'topic_selection_started',
        'payload': {
          'prompt': 'What would you like to explore?',
          if (includeEventSuggestions) 'topic_suggestions': _topicSuggestions,
        },
      },
    ],
    'last_seq': 1,
    'is_completed': false,
  });
}

InteractiveSessionState _modeSelectionSession() {
  return InteractiveSessionState.fromJson({
    'session_id': 'mode-session',
    'story_id': 'story-1',
    'interaction_mode': 'interactive',
    'ai_role': 'host',
    'interactive_state': {
      'template': 'quiz',
      'phase': 'mode_selection',
      'session_type': 'solo',
      'selected_topic': 'History',
    },
    'participants': const [],
    'events': const [],
    'current_turn': {
      'type': 'interactive_turn.v1',
      'session_id': 'mode-session',
      'turn_id': 'mode-turn',
      'seq': 2,
      'speaker': {'type': 'ai', 'role': 'host'},
      'blocks': [
        {'kind': 'text', 'text': 'What do you want to do next?'},
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
    },
    'last_seq': 2,
    'is_completed': false,
  });
}

InteractiveSessionState _timerSelectionSession({
  String phase = 'timer_selection',
}) {
  return InteractiveSessionState.fromJson({
    'session_id': 'timer-session',
    'story_id': 'story-1',
    'interaction_mode': 'interactive',
    'ai_role': 'host',
    'interactive_state': {
      'template': 'quiz',
      'phase': phase,
      'session_type': 'solo',
      'selected_topic': 'History',
    },
    'participants': const [],
    'events': const [],
    'current_turn': {
      'type': 'interactive_turn.v1',
      'session_id': 'timer-session',
      'turn_id': 'timer-turn',
      'seq': 3,
      'speaker': {'type': 'ai', 'role': 'host'},
      'blocks': [
        {'kind': 'text', 'text': 'Do you want this quiz timed?'},
        {
          'kind': 'choice_group',
          'prompt': '',
          'options': [
            {'id': 'untimed', 'label': 'Untimed'},
            {'id': 'timed', 'label': 'Timed'},
          ],
          'metadata': {'choice_kind': 'solo_quiz_timer'},
        },
      ],
    },
    'last_seq': 3,
    'is_completed': false,
  });
}

InteractiveSessionState _activeSoloQuizSession() {
  return InteractiveSessionState.fromJson({
    'session_id': 'active-solo-session',
    'story_id': 'story-1',
    'interaction_mode': 'interactive',
    'ai_role': 'host',
    'interactive_state': {
      'template': 'quiz',
      'phase': 'question_active',
      'session_type': 'solo',
      'selected_topic': 'History',
      'quiz_setup_complete': true,
      'current_round': 1,
      'total_rounds': 3,
      'current_question_id': 'active-question',
      'question': {
        'question_id': 'active-question',
        'text': 'Who built the first known cities?',
        'options': [
          {'id': 'a', 'label': 'Sumerians'},
          {'id': 'b', 'label': 'Romans'},
        ],
      },
    },
    'participants': const [],
    'events': const [],
    'last_seq': 4,
    'is_completed': false,
  });
}
