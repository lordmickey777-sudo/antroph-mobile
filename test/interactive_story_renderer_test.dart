import 'package:antroph_mobile/features/story/models/interactive_story_models.dart';
import 'package:antroph_mobile/features/story/widgets/interactive_story_renderer.dart';
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

  testWidgets(
    'InteractiveStoryRenderer shows untimed solo options after question reveal',
    (tester) async {
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
    },
  );
}
