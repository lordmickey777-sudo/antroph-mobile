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

  testWidgets('InteractiveStoryRenderer renders live quiz answered count', (
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

    expect(find.text('2/5'), findsOneWidget);
    expect(find.text('1/2 answered'), findsOneWidget);
    expect(find.text('Correct'), findsOneWidget);
    expect(find.text('Waiting for others...'), findsOneWidget);
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

    expect(find.text('Answer revealed'), findsOneWidget);
    expect(find.text('Correct answer: mars'), findsOneWidget);
    expect(find.text('Next question starting...'), findsOneWidget);

    final finalSession = InteractiveSessionState.fromJson({
      ...base,
      'interactive_state': {
        'template': 'quiz',
        'phase': 'completed',
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
}
