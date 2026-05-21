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
            onQuizAnswer: (value) => selected = value,
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
}
