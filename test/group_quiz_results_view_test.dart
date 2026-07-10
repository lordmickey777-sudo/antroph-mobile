import 'package:antroph_mobile/core/theme/theme_provider.dart';
import 'package:antroph_mobile/features/story/models/interactive_story_models.dart';
import 'package:antroph_mobile/features/story/widgets/group_quiz_results_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smooth_corner/smooth_corner.dart';

void main() {
  test('group quiz scores are sorted and keep competition ranks for ties', () {
    final scores = groupQuizScoresFromSession(_completedGroupSession());

    expect(scores.map((entry) => entry.name), ['Ada', 'Chidi', 'Ben']);
    expect(scores.map((entry) => entry.score), [5, 5, 2]);
    expect(scores.map((entry) => entry.rank), [1, 1, 3]);
  });

  testWidgets('results sheet shows every player score and dismisses', (
    tester,
  ) async {
    var closeCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GroupQuizResultsView(
            session: _completedGroupSession(),
            currentUserId: 'user-ada',
            onClose: () => closeCalls++,
          ),
        ),
      ),
    );

    expect(find.text('Final results'), findsOneWidget);
    expect(find.byKey(const ValueKey('group-score-row-ada')), findsOneWidget);
    expect(find.byKey(const ValueKey('group-score-row-chidi')), findsOneWidget);
    expect(find.byKey(const ValueKey('group-score-row-ben')), findsOneWidget);
    expect(find.text('You • Host • +1 this round'), findsOneWidget);
    expect(find.text('5 pts'), findsNWidgets(3));
    expect(find.text('2 pts'), findsOneWidget);

    final sheet = tester.widget<Material>(
      find.byKey(const ValueKey('group-quiz-results-sheet')),
    );
    expect(sheet.color, AppTheme.searchInputBackground);

    final doneButton = tester.widget<FilledButton>(
      find.byKey(const ValueKey('group-quiz-results-done')),
    );
    expect(doneButton.style?.backgroundColor?.resolve({}), Colors.white);
    expect(doneButton.style?.foregroundColor?.resolve({}), Colors.black);
    expect(doneButton.style?.shape?.resolve({}), isA<SmoothRectangleBorder>());

    await tester.tap(find.byKey(const ValueKey('group-quiz-results-done')));

    expect(closeCalls, 1);
  });

  testWidgets('show helper presents the results as a modal bottom sheet', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () => showGroupQuizResultsBottomSheet(
                context,
                session: _completedGroupSession(),
                currentUserId: 'user-ada',
              ),
              child: const Text('Show results'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Show results'));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsOneWidget);
    expect(
      find.byKey(const ValueKey('group-quiz-results-sheet')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('group-quiz-results-close')));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsNothing);
  });
}

InteractiveSessionState _completedGroupSession() {
  return InteractiveSessionState.fromJson({
    'session_id': 'session-1',
    'story_id': 'story-1',
    'interaction_mode': 'group',
    'ai_role': 'host',
    'interactive_state': {
      'template': 'quiz',
      'session_type': 'group',
      'phase': 'completed',
      'current_round': 5,
      'total_rounds': 5,
      'score_delta': {'ada': 1, 'chidi': 0, 'ben': 0},
      'final_standings': [
        {
          'rank': 3,
          'participant_id': 'ben',
          'user_id': 'user-ben',
          'display_name': 'Ben',
          'score': 2,
        },
        {
          'rank': 1,
          'participant_id': 'chidi',
          'user_id': 'user-chidi',
          'display_name': 'Chidi',
          'score': 5,
        },
        {
          'rank': 1,
          'participant_id': 'ada',
          'user_id': 'user-ada',
          'display_name': 'Ada',
          'score': 5,
        },
      ],
    },
    'participants': [
      {
        'id': 'ada',
        'session_id': 'session-1',
        'user_id': 'user-ada',
        'display_name': 'Ada',
        'role': 'host',
        'status': 'active',
        'score': 5,
      },
      {
        'id': 'ben',
        'session_id': 'session-1',
        'user_id': 'user-ben',
        'display_name': 'Ben',
        'role': 'participant',
        'status': 'active',
        'score': 2,
      },
      {
        'id': 'chidi',
        'session_id': 'session-1',
        'user_id': 'user-chidi',
        'display_name': 'Chidi',
        'role': 'participant',
        'status': 'active',
        'score': 5,
      },
    ],
    'events': const [],
    'last_seq': 10,
    'is_completed': true,
  });
}
