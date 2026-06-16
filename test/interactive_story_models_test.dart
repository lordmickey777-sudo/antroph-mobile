import 'package:antroph_mobile/features/story/models/interactive_story_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('InteractiveSessionState parses supported block types', () {
    final state = InteractiveSessionState.fromJson({
      'session_id': 'session-1',
      'story_id': 'story-1',
      'join_code': 'ABC123',
      'interaction_mode': 'group',
      'ai_role': 'host',
      'interactive_state': {'round': 1},
      'participants': [
        {
          'id': 'p1',
          'session_id': 'session-1',
          'display_name': 'Ada',
          'role': 'host',
          'status': 'active',
          'score': 2,
        },
      ],
      'events': [],
      'current_turn': {
        'type': 'interactive_turn.v1',
        'session_id': 'session-1',
        'turn_id': 'turn-1',
        'seq': 3,
        'speaker': {'type': 'ai', 'role': 'host'},
        'blocks': [
          {'kind': 'text', 'text': 'Welcome'},
          {
            'kind': 'choice_group',
            'prompt': 'Pick one',
            'options': [
              {'id': 'a', 'label': 'A'},
            ],
          },
          {
            'kind': 'quiz',
            'question': '2 + 2?',
            'options': [
              {'id': '4', 'label': '4'},
            ],
            'time_limit_ms': 30000,
          },
          {'kind': 'timer', 'expires_at': '2026-05-21T12:00:00Z'},
          {
            'kind': 'media',
            'media_type': 'image',
            'url': 'https://example.com/a.png',
          },
          {
            'kind': 'scoreboard',
            'players': [
              {'display_name': 'Ada', 'score': 2},
            ],
          },
          {'kind': 'private_prompt', 'text': 'Act this out'},
          {'kind': 'system', 'text': 'Notice'},
          {'kind': 'new_kind', 'payload': true},
        ],
      },
      'last_seq': 3,
      'is_completed': false,
    });

    expect(state.joinCode, 'ABC123');
    expect(state.participants.single.displayName, 'Ada');
    final blocks = state.currentTurn!.blocks;
    expect(blocks[0], isA<InteractiveTextBlock>());
    expect(blocks[1], isA<InteractiveChoiceGroupBlock>());
    expect(blocks[2], isA<InteractiveQuizBlock>());
    expect(blocks[3], isA<InteractiveTimerBlock>());
    expect(blocks[4], isA<InteractiveMediaBlock>());
    expect(blocks[5], isA<InteractiveScoreboardBlock>());
    expect(blocks[6], isA<InteractivePrivatePromptBlock>());
    expect(blocks[7], isA<InteractiveSystemBlock>());
    expect(blocks[8], isA<InteractiveUnknownBlock>());
  });
}
