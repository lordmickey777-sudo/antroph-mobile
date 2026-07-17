import 'dart:async';
import 'dart:typed_data';

import 'package:antroph_mobile/core/auth/models/user.dart';
import 'package:antroph_mobile/core/auth/state/auth_state.dart';
import 'package:antroph_mobile/core/network/error_formatter.dart';
import 'package:antroph_mobile/features/home/providers/voice_chat_provider.dart';
import 'package:antroph_mobile/features/home/services/pcm_audio_player.dart';
import 'package:antroph_mobile/features/home/services/realtime_voice_client.dart';
import 'package:antroph_mobile/features/story/data/stories_repository.dart';
import 'package:antroph_mobile/features/story/models/interactive_story_models.dart';
import 'package:antroph_mobile/features/story/models/story_detail.dart';
import 'package:antroph_mobile/features/story/presentation/story_chat_flow_page.dart';
import 'package:antroph_mobile/features/story/providers/interactive_story_provider.dart';
import 'package:antroph_mobile/features/story/providers/story_providers.dart';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('group entry shows animated loading while session starts', (
    tester,
  ) async {
    final startDelay = Completer<void>();
    final repository = _QuizStoriesRepository(
      session: _session(phase: 'group_setup', sessionType: 'group'),
      startDelay: startDelay.future,
    );
    await _pumpQuizPage(tester, repository: repository, userId: 'host-user');

    expect(repository.startCalls, 1);
    expect(find.text('Thinking...'), findsOneWidget);

    startDelay.complete();
    await tester.pump();
    await tester.pump();
    await _disposeQuizPage(tester);
  });

  testWidgets(
    'shows reconnect modal after fifteen seconds and syncs the question',
    (tester) async {
      final repository = _QuizStoriesRepository(
        session: _session(phase: 'generating_question', sessionType: 'group'),
      );
      await _pumpQuizPage(tester, repository: repository, userId: 'host-user');

      await tester.pump(const Duration(seconds: 14));
      expect(find.text('Question is taking longer'), findsNothing);

      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Question is taking longer'), findsOneWidget);
      expect(find.text('Reconnect & check'), findsOneWidget);

      repository.session = _session(
        phase: 'question_active',
        sessionType: 'group',
      );
      await tester.tap(find.text('Reconnect & check'));
      await tester.pump();
      await tester.pump();

      expect(repository.fetchCalls, greaterThanOrEqualTo(1));
      expect(repository.retryCalls, 0);
      expect(find.text('Question is taking longer'), findsNothing);
      await _disposeQuizPage(tester);
    },
  );

  testWidgets('group participant reconnects without calling host retry', (
    tester,
  ) async {
    final repository = _QuizStoriesRepository(
      session: _session(phase: 'generation_failed', sessionType: 'group'),
    );
    await _pumpQuizPage(tester, repository: repository, userId: 'player-user');

    expect(find.text('Waiting for the host'), findsOneWidget);
    expect(find.text('Reconnect & check'), findsOneWidget);

    await tester.tap(find.text('Reconnect & check'));
    await tester.pump();
    await tester.pump();

    expect(repository.fetchCalls, greaterThanOrEqualTo(1));
    expect(repository.retryCalls, 0);
    expect(find.text('Waiting for the host'), findsOneWidget);
    await _disposeQuizPage(tester);
  });

  testWidgets('solo recovery retries once after canonical failure check', (
    tester,
  ) async {
    final repository = _QuizStoriesRepository(
      session: _session(phase: 'generation_failed', sessionType: 'solo'),
      retrySession: _session(phase: 'generating_question', sessionType: 'solo'),
    );
    await _pumpQuizPage(tester, repository: repository, userId: 'solo-user');

    expect(find.text('Question failed to load'), findsOneWidget);
    expect(find.text('Reconnect & retry'), findsOneWidget);

    final pageContext = tester.element(find.byType(StoryChatFlowPage));
    final container = ProviderScope.containerOf(pageContext);
    final notifier = container.read(interactiveStoryProvider.notifier);
    final first = notifier.recoverGeneration(canRetry: true);
    final second = notifier.recoverGeneration(canRetry: true);
    await tester.pump();
    await first;
    await second;
    await tester.pump();

    expect(repository.fetchCalls, greaterThanOrEqualTo(1));
    expect(repository.retryCalls, 1);
    expect(find.text('Checking connection'), findsOneWidget);
    await _disposeQuizPage(tester);
  });

  testWidgets('retry conflict refetches the question that won the race', (
    tester,
  ) async {
    final repository = _QuizStoriesRepository(
      session: _session(phase: 'generation_failed', sessionType: 'solo'),
      retryError: const ApiError(
        message: 'Question already advanced.',
        statusCode: 409,
      ),
      conflictSession: _session(phase: 'question_active', sessionType: 'solo'),
    );
    await _pumpQuizPage(tester, repository: repository, userId: 'solo-user');

    await tester.tap(find.text('Reconnect & retry'));
    await tester.pump();
    await tester.pump();

    expect(repository.retryCalls, 1);
    expect(repository.fetchCalls, greaterThanOrEqualTo(2));
    expect(find.text('Question failed to load'), findsNothing);
    await _disposeQuizPage(tester);
  });

  testWidgets('solo topic suggestion enters guided aspect selection', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _QuizStoriesRepository(session: _topicSession());
    await _pumpQuizPage(
      tester,
      repository: repository,
      userId: 'solo-user',
      interactionMode: 'interactive',
      textScaler: TextScaler.linear(1.8),
    );

    final inputFinder = find.byKey(const ValueKey('solo-topic-text-field'));
    expect(inputFinder, findsNothing);
    expect(find.text('Message'), findsNothing);
    expect(find.byIcon(Icons.call_rounded), findsOneWidget);
    final customTopicRect = tester.getRect(
      find.byKey(const ValueKey('topic-suggestion-custom_topic')),
    );
    final callRect = tester.getRect(
      find.byKey(const ValueKey('solo-topic-floating-call')),
    );
    expect(
      find.byKey(const ValueKey('topic-suggestion-instruction')),
      findsNothing,
    );
    expect(customTopicRect.bottom, greaterThan(callRect.top));
    expect(customTopicRect.center.dy, closeTo(callRect.center.dy, 0.1));
    expect(callRect.left, closeTo(12, 0.1));
    expect(customTopicRect.left - callRect.right, greaterThanOrEqualTo(10));
    expect(320 - customTopicRect.right, closeTo(8, 0.1));
    expect(customTopicRect.overlaps(callRect), isFalse);
    await tester.ensureVisible(find.text('History'));
    await tester.tap(find.text('History'));
    await tester.pump();
    await tester.pump();

    expect(repository.submittedInputs, hasLength(1));
    expect(repository.submittedInputs.single.inputType, 'text');
    expect(repository.submittedInputs.single.text, 'History');
    expect(repository.submittedInputs.single.optionId, isNull);
    expect(
      find.byKey(const ValueKey('topic-suggestion-history')),
      findsNothing,
    );
    final customAspect = find.byKey(
      const ValueKey('topic-aspect-custom_aspect'),
    );
    final continueWithTopic = find.byKey(
      const ValueKey('topic-aspect-continue_with_topic'),
    );
    final floatingCall = find.byKey(const ValueKey('solo-topic-floating-call'));
    expect(
      find.byKey(const ValueKey('topic-aspect-ancient_history')),
      findsOneWidget,
    );
    expect(customAspect, findsOneWidget);
    expect(continueWithTopic, findsOneWidget);
    expect(floatingCall, findsOneWidget);
    expect(find.byIcon(Icons.call_rounded), findsOneWidget);
    await tester.ensureVisible(continueWithTopic);
    await tester.pumpAndSettle();
    final callTarget = find.byKey(
      const ValueKey('topic-aspect-call-target-continue_with_topic'),
    );
    expect(callTarget, findsOneWidget);
    expect(
      tester.getRect(callTarget).center.dy,
      closeTo(tester.getRect(continueWithTopic).center.dy, 0.1),
    );
    expect(
      tester.getRect(continueWithTopic).center.dy,
      closeTo(tester.getRect(floatingCall).center.dy, 0.1),
    );
    expect(
      tester.getRect(floatingCall).right,
      lessThan(tester.getRect(continueWithTopic).left),
    );
    await _disposeQuizPage(tester);
  });

  testWidgets('aspect choices support repeated suggestions and custom input', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _QuizStoriesRepository(
      session: _aspectSuggestionSession(),
    );
    await _pumpQuizPage(
      tester,
      repository: repository,
      userId: 'solo-user',
      interactionMode: 'interactive',
    );

    await tester.tap(
      find.byKey(const ValueKey('topic-aspect-ancient_history')),
    );
    await tester.pump();
    await tester.pump();

    expect(repository.submittedInputs, hasLength(1));
    expect(repository.submittedInputs.single.inputType, 'option_select');
    expect(repository.submittedInputs.single.optionId, 'ancient_history');
    expect(repository.submittedInputs.single.metadata, {
      'expected_revision': '1',
      'expected_topic_path': ['History'],
    });
    final chatAction = find.byKey(const ValueKey('topic-path-action-chat'));
    final changeAspect = find.byKey(
      const ValueKey('topic-path-action-change_aspect'),
    );
    final floatingCall = find.byKey(const ValueKey('solo-topic-floating-call'));
    expect(chatAction, findsOneWidget);
    expect(changeAspect, findsOneWidget);
    expect(floatingCall, findsOneWidget);
    expect(find.byIcon(Icons.call_rounded), findsOneWidget);
    expect(
      tester.getRect(changeAspect).center.dy,
      closeTo(tester.getRect(floatingCall).center.dy, 4),
    );
    expect(
      tester.getRect(floatingCall).right,
      lessThan(tester.getRect(changeAspect).left),
    );
    expect(360 - tester.getRect(chatAction).right, closeTo(8, 0.1));

    await tester.tap(
      find.byKey(const ValueKey('topic-path-action-change_aspect')),
    );
    await tester.pump();
    await tester.pump();

    expect(repository.submittedInputs, hasLength(2));
    expect(repository.submittedInputs.last.inputType, 'option_select');
    expect(repository.submittedInputs.last.optionId, 'change_aspect');
    expect(repository.submittedInputs.last.metadata, {
      'expected_revision': '2',
      'expected_topic_path': ['History', 'Ancient history'],
    });
    final customAspect = find.byKey(
      const ValueKey('topic-aspect-custom_aspect'),
    );
    expect(customAspect, findsOneWidget);

    await tester.ensureVisible(customAspect);
    await tester.pump();
    await tester.tap(customAspect);
    await tester.pump();

    final composer = find.byKey(const ValueKey('solo-topic-text-field'));
    expect(composer, findsOneWidget);
    expect(customAspect, findsNothing);
    expect(
      find.byKey(const ValueKey('topic-aspect-ancient_history')),
      findsOneWidget,
    );
    expect(
      tester.widget<TextField>(composer).decoration?.hintText,
      'Type your own aspect',
    );
    expect(tester.widget<TextField>(composer).focusNode?.hasFocus, isTrue);
    expect(find.byIcon(Icons.call_rounded), findsOneWidget);

    final blockedContinue = find.byKey(
      const ValueKey('topic-aspect-continue_with_topic'),
    );
    await tester.ensureVisible(blockedContinue);
    await tester.pump();
    await tester.tap(blockedContinue);
    await tester.pump();
    expect(repository.submittedInputs, hasLength(2));
    expect(composer, findsOneWidget);

    await tester.enterText(composer, 'Women rulers');
    await tester.pump();
    await tester.tap(find.byTooltip('Send'));
    await tester.pump();
    await tester.pump();

    expect(repository.submittedInputs, hasLength(3));
    expect(repository.submittedInputs.last.inputType, 'text');
    expect(repository.submittedInputs.last.text, 'Women rulers');
    expect(repository.submittedInputs.last.optionId, isNull);
    expect(repository.submittedInputs.last.metadata, {
      'expected_revision': '3',
      'expected_topic_path': ['History'],
    });
    expect(composer, findsNothing);
    expect(
      find.byKey(const ValueKey('topic-path-action-quiz')),
      findsOneWidget,
    );
    expect(repository.session.interactiveState['topic_path'], [
      'History',
      'Women rulers',
    ]);
    await _disposeQuizPage(tester);
  });

  testWidgets('root Continue offers only Quiz and Chat', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _QuizStoriesRepository(
      session: _aspectSuggestionSession(),
    );
    await _pumpQuizPage(
      tester,
      repository: repository,
      userId: 'solo-user',
      interactionMode: 'interactive',
    );

    final customAspect = find.byKey(
      const ValueKey('topic-aspect-custom_aspect'),
    );
    final continueWithTopic = find.byKey(
      const ValueKey('topic-aspect-continue_with_topic'),
    );
    var floatingCall = find.byKey(const ValueKey('solo-topic-floating-call'));
    expect(customAspect, findsOneWidget);
    expect(continueWithTopic, findsOneWidget);
    expect(floatingCall, findsOneWidget);
    await tester.ensureVisible(continueWithTopic);
    await tester.pump();
    expect(
      tester.getRect(continueWithTopic).center.dy,
      closeTo(tester.getRect(floatingCall).center.dy, 0.1),
    );

    await tester.ensureVisible(continueWithTopic);
    await tester.tap(continueWithTopic);
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    expect(repository.submittedInputs, hasLength(1));
    expect(repository.submittedInputs.single.inputType, 'option_select');
    expect(repository.submittedInputs.single.optionId, 'continue_with_topic');
    expect(repository.submittedInputs.single.metadata, {
      'expected_revision': '1',
      'expected_topic_path': ['History'],
    });
    expect(
      repository.session.interactiveState['topic_path_actions_expanded'],
      isTrue,
    );
    expect(customAspect, findsNothing);
    final quizAction = find.byKey(const ValueKey('topic-path-action-quiz'));
    final chatAction = find.byKey(const ValueKey('topic-path-action-chat'));
    final chooseAspect = find.byKey(
      const ValueKey('topic-path-action-choose_aspect'),
    );
    expect(quizAction, findsOneWidget);
    expect(chatAction, findsOneWidget);
    expect(chooseAspect, findsNothing);
    expect(find.text('Continue'), findsNothing);
    expect(find.text("Let's keep History broad."), findsOneWidget);
    expect(
      find.text(
        'Would you like to take a quiz about History or chat with Aura?',
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('topic-path-action-instruction')),
      findsNothing,
    );
    floatingCall = find.byKey(const ValueKey('solo-topic-floating-call'));
    expect(floatingCall, findsOneWidget);
    expect(
      tester.getRect(chatAction).center.dy,
      closeTo(tester.getRect(floatingCall).center.dy, 4),
    );
    expect(find.text('Choose an aspect'), findsNothing);
    await _disposeQuizPage(tester);
  });

  testWidgets('expanded root topic routes Quiz directly to timer selection', (
    tester,
  ) async {
    final repository = _QuizStoriesRepository(
      session: _rootExpandedActionsSession(),
    );
    await _pumpQuizPage(
      tester,
      repository: repository,
      userId: 'solo-user',
      interactionMode: 'interactive',
    );

    await tester.tap(find.byKey(const ValueKey('topic-path-action-quiz')));
    await tester.pump();
    await tester.pump();

    expect(repository.submittedInputs, hasLength(1));
    expect(repository.submittedInputs.single.optionId, 'quiz');
    expect(repository.submittedInputs.single.metadata, {
      'expected_revision': '1',
      'expected_topic_path': ['History'],
    });
    expect(repository.session.interactiveState['phase'], 'timer_selection');
    expect(
      repository.session.interactiveState,
      isNot(contains('topic_path_actions_expanded')),
    );
    expect(
      find.byKey(const ValueKey('timer-suggestion-timed')),
      findsOneWidget,
    );
    await _disposeQuizPage(tester);
  });

  testWidgets('expanded root topic routes Chat directly to discussion', (
    tester,
  ) async {
    final repository = _QuizStoriesRepository(
      session: _rootExpandedActionsSession(),
    );
    await _pumpQuizPage(
      tester,
      repository: repository,
      userId: 'solo-user',
      interactionMode: 'interactive',
    );

    await tester.tap(find.byKey(const ValueKey('topic-path-action-chat')));
    await tester.pump();
    await tester.pump();

    expect(repository.submittedInputs, hasLength(1));
    expect(repository.submittedInputs.single.optionId, 'chat');
    expect(repository.submittedInputs.single.metadata, {
      'expected_revision': '1',
      'expected_topic_path': ['History'],
    });
    expect(repository.session.interactiveState['phase'], 'discussion');
    expect(
      repository.session.interactiveState,
      isNot(contains('topic_path_actions_expanded')),
    );
    expect(find.byKey(const ValueKey('solo-topic-text-field')), findsOneWidget);
    await _disposeQuizPage(tester);
  });

  testWidgets('custom aspect composer resets when revision or path changes', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _QuizStoriesRepository(
      session: _aspectSuggestionSession(),
    );
    await _pumpQuizPage(
      tester,
      repository: repository,
      userId: 'solo-user',
      interactionMode: 'interactive',
    );

    final pageContext = tester.element(find.byType(StoryChatFlowPage));
    final container = ProviderScope.containerOf(pageContext);
    final notifier = container.read(interactiveStoryProvider.notifier);

    void updateAspectContext({
      required int revision,
      required List<String> path,
    }) {
      final storyState = container.read(interactiveStoryProvider);
      final session = storyState.session!;
      notifier.state = storyState.copyWith(
        session: session.copyWith(
          interactiveState: {
            ...session.interactiveState,
            'topic_aspect_revision': revision,
            'topic_path': path,
            'topic_drilldown_depth': path.length - 1,
          },
          lastSeq: session.lastSeq + 1,
        ),
      );
    }

    final customAspect = find.byKey(
      const ValueKey('topic-aspect-custom_aspect'),
    );
    await tester.ensureVisible(customAspect);
    await tester.tap(customAspect);
    await tester.pump();
    var composer = find.byKey(const ValueKey('solo-topic-text-field'));
    await tester.enterText(composer, 'Stale revision text');
    await tester.pump();

    updateAspectContext(revision: 2, path: const ['History']);
    await tester.pump();

    expect(composer, findsNothing);
    expect(customAspect, findsOneWidget);
    await tester.ensureVisible(customAspect);
    await tester.tap(customAspect);
    await tester.pump();
    composer = find.byKey(const ValueKey('solo-topic-text-field'));
    expect(tester.widget<TextField>(composer).controller?.text, isEmpty);
    await tester.enterText(composer, 'Stale path text');
    await tester.pump();

    updateAspectContext(revision: 2, path: const ['History', 'Modern history']);
    await tester.pump();

    expect(composer, findsNothing);
    expect(customAspect, findsOneWidget);
    expect(repository.submittedInputs, isEmpty);
    await _disposeQuizPage(tester);
  });

  testWidgets('guided topic path routes Quiz directly to timer selection', (
    tester,
  ) async {
    final repository = _QuizStoriesRepository(session: _aspectActionsSession());
    await _pumpQuizPage(
      tester,
      repository: repository,
      userId: 'solo-user',
      interactionMode: 'interactive',
    );

    await tester.tap(find.byKey(const ValueKey('topic-path-action-quiz')));
    await tester.pump();
    await tester.pump();

    expect(repository.submittedInputs, hasLength(1));
    expect(repository.submittedInputs.single.inputType, 'option_select');
    expect(repository.submittedInputs.single.optionId, 'quiz');
    expect(repository.submittedInputs.single.metadata, {
      'expected_revision': '2',
      'expected_topic_path': ['History', 'Ancient history'],
    });
    expect(repository.session.interactiveState['phase'], 'timer_selection');
    expect(
      find.byKey(const ValueKey('timer-suggestion-timed')),
      findsOneWidget,
    );
    await _disposeQuizPage(tester);
  });

  testWidgets('guided topic path routes Chat directly to discussion', (
    tester,
  ) async {
    final repository = _QuizStoriesRepository(session: _aspectActionsSession());
    await _pumpQuizPage(
      tester,
      repository: repository,
      userId: 'solo-user',
      interactionMode: 'interactive',
    );

    await tester.tap(find.byKey(const ValueKey('topic-path-action-chat')));
    await tester.pump();
    await tester.pump();

    expect(repository.submittedInputs, hasLength(1));
    expect(repository.submittedInputs.single.inputType, 'option_select');
    expect(repository.submittedInputs.single.optionId, 'chat');
    expect(repository.submittedInputs.single.metadata, {
      'expected_revision': '2',
      'expected_topic_path': ['History', 'Ancient history'],
    });
    expect(repository.session.interactiveState['phase'], 'discussion');
    expect(find.byKey(const ValueKey('solo-topic-text-field')), findsOneWidget);
    expect(find.byIcon(Icons.call_rounded), findsOneWidget);
    await _disposeQuizPage(tester);
  });

  testWidgets('failed aspect generation retries through option selection', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _QuizStoriesRepository(session: _aspectFailureSession());
    await _pumpQuizPage(
      tester,
      repository: repository,
      userId: 'solo-user',
      interactionMode: 'interactive',
    );

    final customAspect = find.byKey(
      const ValueKey('topic-aspect-custom_aspect'),
    );
    final floatingCall = find.byKey(const ValueKey('solo-topic-floating-call'));
    expect(customAspect, findsOneWidget);
    expect(floatingCall, findsOneWidget);
    final retry = find.byKey(const ValueKey('topic-path-action-retry_aspects'));
    expect(retry, findsOneWidget);
    expect(
      tester.getRect(retry).center.dy,
      closeTo(tester.getRect(floatingCall).center.dy, 0.1),
    );

    await tester.tap(retry);
    await tester.pump();
    await tester.pump();

    expect(repository.submittedInputs, hasLength(1));
    expect(repository.submittedInputs.single.inputType, 'option_select');
    expect(repository.submittedInputs.single.optionId, 'retry_aspects');
    expect(repository.submittedInputs.single.metadata, {
      'expected_revision': '1',
      'expected_topic_path': ['History'],
    });
    expect(repository.session.interactiveState['topic_aspect_status'], 'ready');
    expect(
      find.byKey(const ValueKey('topic-aspect-custom_aspect')),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.call_rounded), findsOneWidget);
    await _disposeQuizPage(tester);
  });

  testWidgets('max-depth custom aspect owns the floating call without Chat', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _QuizStoriesRepository(
      session: _aspectMaxDepthSession(),
    );
    await _pumpQuizPage(
      tester,
      repository: repository,
      userId: 'solo-user',
      interactionMode: 'interactive',
    );

    final customAspect = find.byKey(
      const ValueKey('topic-aspect-custom_aspect'),
    );
    final floatingCall = find.byKey(const ValueKey('solo-topic-floating-call'));
    expect(customAspect, findsOneWidget);
    expect(floatingCall, findsOneWidget);
    expect(find.byIcon(Icons.call_rounded), findsOneWidget);
    expect(
      tester.getRect(customAspect).center.dy,
      closeTo(tester.getRect(floatingCall).center.dy, 0.1),
    );
    await _disposeQuizPage(tester);
  });

  testWidgets('guided aspect loading keeps the fallback call available', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final previous = _aspectActionsSession();
    final repository = _QuizStoriesRepository(
      session: previous.copyWith(
        interactiveState: {
          ...previous.interactiveState,
          'topic_path': const ['History', 'Ancient history', 'Ancient Egypt'],
          'pending_topic_aspects': const [],
          'topic_aspect_status': 'generating',
          'topic_drilldown_depth': 2,
          'topic_aspect_revision': 3,
        },
        lastSeq: previous.lastSeq + 1,
      ),
    );
    await _pumpQuizPage(
      tester,
      repository: repository,
      userId: 'solo-user',
      interactionMode: 'interactive',
    );

    expect(find.text('Finding topic aspects'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('solo-topic-floating-call')),
      findsNothing,
    );
    expect(find.byIcon(Icons.call_rounded), findsOneWidget);
    await _disposeQuizPage(tester);
  });

  testWidgets('solo mode tabs submit Quiz by option ID', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _QuizStoriesRepository(session: _modeSession());
    await _pumpQuizPage(
      tester,
      repository: repository,
      userId: 'solo-user',
      interactionMode: 'interactive',
    );

    final quizTab = find.byKey(const ValueKey('mode-suggestion-quiz'));
    final chatTab = find.byKey(const ValueKey('mode-suggestion-chat'));
    final call = find.byKey(const ValueKey('solo-topic-floating-call'));
    expect(quizTab, findsOneWidget);
    expect(chatTab, findsOneWidget);
    expect(call, findsOneWidget);
    expect(
      tester.getRect(chatTab).center.dy,
      closeTo(tester.getRect(call).center.dy, 0.1),
    );
    expect(tester.getRect(call).left, closeTo(12, 0.1));
    expect(tester.getRect(call).right, lessThan(tester.getRect(chatTab).left));
    expect(320 - tester.getRect(chatTab).right, closeTo(8, 0.1));

    await tester.tap(quizTab);
    await tester.pump();
    await tester.pump();

    expect(repository.submittedInputs, hasLength(1));
    expect(repository.submittedInputs.single.inputType, 'option_select');
    expect(repository.submittedInputs.single.optionId, 'quiz');
    expect(quizTab, findsNothing);
    expect(chatTab, findsNothing);
    expect(
      find.byKey(const ValueKey('timer-suggestion-timed')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('timer-suggestion-untimed')),
      findsOneWidget,
    );
    await _disposeQuizPage(tester);
  });

  testWidgets('solo timer tabs submit Untimed by option ID', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _QuizStoriesRepository(session: _timerSession());
    await _pumpQuizPage(
      tester,
      repository: repository,
      userId: 'solo-user',
      interactionMode: 'interactive',
    );

    final timedTab = find.byKey(const ValueKey('timer-suggestion-timed'));
    final untimedTab = find.byKey(const ValueKey('timer-suggestion-untimed'));
    final call = find.byKey(const ValueKey('solo-topic-floating-call'));
    expect(timedTab, findsOneWidget);
    expect(untimedTab, findsOneWidget);
    expect(call, findsOneWidget);
    expect(find.byKey(const ValueKey('solo-topic-text-field')), findsNothing);
    final untimedRect = tester.getRect(untimedTab);
    final callRect = tester.getRect(call);
    expect(untimedRect.center.dy, closeTo(callRect.center.dy, 0.1));
    expect(callRect.left, closeTo(12, 0.1));
    expect(untimedRect.left - callRect.right, greaterThanOrEqualTo(10));
    expect(320 - untimedRect.right, closeTo(8, 0.1));

    await tester.tap(untimedTab);
    await tester.pump();
    await tester.pump();

    expect(repository.submittedInputs, hasLength(1));
    expect(repository.submittedInputs.single.inputType, 'option_select');
    expect(repository.submittedInputs.single.optionId, 'untimed');
    expect(timedTab, findsNothing);
    expect(untimedTab, findsNothing);
    await _disposeQuizPage(tester);
  });

  testWidgets(
    'post-setup quiz switches through Chat and resumes the same question',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repository = _QuizStoriesRepository(
        session: _activeSoloQuizSession(),
      );
      await _pumpQuizPage(
        tester,
        repository: repository,
        userId: 'solo-user',
        interactionMode: 'interactive',
      );

      final quizMode = find.byKey(const ValueKey('persistent-mode-quiz'));
      final chatMode = find.byKey(const ValueKey('persistent-mode-chat'));
      expect(quizMode, findsNothing);
      expect(chatMode, findsOneWidget);
      expect(find.text('Next question'), findsNothing);
      expect(find.byKey(const ValueKey('solo-topic-text-field')), findsNothing);

      await tester.tap(chatMode);
      await tester.pump();

      final composer = find.byKey(const ValueKey('solo-topic-text-field'));
      final floatingCall = find.byKey(
        const ValueKey('solo-topic-floating-call'),
      );
      expect(composer, findsOneWidget);
      expect(quizMode, findsOneWidget);
      expect(chatMode, findsNothing);
      expect(find.text('Continue Chat'), findsNothing);
      expect(find.text('Next question'), findsNothing);
      expect(repository.submittedInputs, isEmpty);
      expect(floatingCall, findsNothing);
      expect(find.byIcon(Icons.call_rounded), findsOneWidget);
      expect(
        tester.getRect(composer).top - tester.getRect(quizMode).bottom,
        closeTo(12, 0.1),
      );
      final voiceButton = find.byTooltip('Voice');
      expect(voiceButton, findsOneWidget);
      expect(
        tester.getRect(voiceButton).left,
        greaterThan(tester.getRect(composer).right),
      );

      await tester.enterText(composer, 'Tell me more about early cities');
      await tester.pump();
      await tester.tap(find.byTooltip('Send'));
      await tester.pump();
      await tester.pump();

      expect(repository.submittedInputs, hasLength(1));
      expect(repository.submittedInputs.single.inputType, 'solo_chat');
      expect(repository.session.interactiveState['phase'], 'question_active');
      expect(
        repository.session.interactiveState['current_question_id'],
        'active-question',
      );

      await tester.tap(quizMode);
      await tester.pump();

      final continueTopic = find.byKey(
        const ValueKey('topic-decision-continue_topic'),
      );
      final newTopic = find.byKey(const ValueKey('topic-decision-new_topic'));
      expect(composer, findsNothing);
      expect(quizMode, findsNothing);
      expect(chatMode, findsNothing);
      expect(continueTopic, findsOneWidget);
      expect(newTopic, findsOneWidget);
      final newTopicRect = tester.getRect(newTopic);
      final decisionCallRect = tester.getRect(floatingCall);
      expect(newTopicRect.center.dy, closeTo(decisionCallRect.center.dy, 0.1));

      await tester.tap(continueTopic);
      await tester.pump();

      expect(repository.submittedInputs, hasLength(1));
      expect(quizMode, findsNothing);
      expect(chatMode, findsOneWidget);
      expect(repository.session.interactiveState['phase'], 'question_active');
      expect(
        repository.session.interactiveState['current_question_id'],
        'active-question',
      );
      await _disposeQuizPage(tester);
    },
  );

  testWidgets('Choose a new topic restarts into topic selection', (
    tester,
  ) async {
    final repository = _QuizStoriesRepository(
      session: _activeSoloQuizSession(),
      restartSession: _topicSession(sessionId: 'fresh-topic-session'),
    );
    await _pumpQuizPage(
      tester,
      repository: repository,
      userId: 'solo-user',
      interactionMode: 'interactive',
    );

    await tester.tap(find.byKey(const ValueKey('persistent-mode-chat')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('persistent-mode-quiz')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('topic-decision-new_topic')));
    await tester.pump();
    await tester.pump();

    expect(repository.startCalls, 2);
    expect(repository.session.sessionId, 'fresh-topic-session');
    expect(repository.session.interactiveState['phase'], 'topic_selection');
    expect(
      find.byKey(const ValueKey('topic-suggestion-history')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('persistent-mode-chat')), findsNothing);
    expect(
      find.byKey(const ValueKey('topic-decision-new_topic')),
      findsNothing,
    );

    await tester.tap(find.byKey(const ValueKey('topic-suggestion-history')));
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(repository.submittedInputs, hasLength(1));
    expect(repository.submittedInputs.first.inputType, 'text');
    expect(repository.submittedInputs.first.text, 'History');
    expect(
      find.byKey(const ValueKey('topic-aspect-custom_aspect')),
      findsOneWidget,
    );
    await _disposeQuizPage(tester);
  });

  testWidgets('Continue last topic advances a post-question quiz', (
    tester,
  ) async {
    final repository = _QuizStoriesRepository(session: _postQuestionSession());
    await _pumpQuizPage(
      tester,
      repository: repository,
      userId: 'solo-user',
      interactionMode: 'interactive',
    );

    await tester.tap(find.byKey(const ValueKey('persistent-mode-chat')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('persistent-mode-quiz')));
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('topic-decision-continue_topic')),
    );
    await tester.pump();
    await tester.pump();

    expect(repository.submittedInputs, hasLength(1));
    expect(repository.submittedInputs.single.inputType, 'option_select');
    expect(repository.submittedInputs.single.optionId, 'continue_topic');
    expect(repository.session.interactiveState['phase'], 'generating_question');
    expect(find.text('Next question'), findsOneWidget);
    expect(find.text('continue_topic'), findsNothing);
    await _disposeQuizPage(tester);
  });

  testWidgets('post-question Chat stays open across repeated Aura replies', (
    tester,
  ) async {
    final repository = _QuizStoriesRepository(session: _postQuestionSession());
    await _pumpQuizPage(
      tester,
      repository: repository,
      userId: 'solo-user',
      interactionMode: 'interactive',
    );

    await tester.tap(find.byKey(const ValueKey('persistent-mode-chat')));
    await tester.pump();

    final composer = find.byKey(const ValueKey('solo-topic-text-field'));
    expect(composer, findsOneWidget);
    expect(tester.widget<TextField>(composer).enabled, isNot(false));

    await tester.enterText(composer, 'Explain the answer further');
    await tester.pump();
    await tester.tap(find.byTooltip('Send'));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));

    expect(repository.submittedInputs, hasLength(1));
    expect(repository.submittedInputs.first.inputType, 'solo_chat');
    expect(repository.submittedInputs.first.text, 'Explain the answer further');
    expect(
      find.text('Aura reply to: Explain the answer further'),
      findsOneWidget,
    );
    expect(composer, findsOneWidget);
    expect(tester.widget<TextField>(composer).enabled, isNot(false));
    expect(
      repository.session.interactiveState['phase'],
      'post_question_prompt',
    );
    expect(repository.session.interactiveState['result'], isNotNull);

    await tester.enterText(composer, 'Give me another example');
    await tester.pump();
    await tester.tap(find.byTooltip('Send'));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));

    expect(repository.submittedInputs, hasLength(2));
    expect(
      repository.submittedInputs.map((input) => input.inputType),
      everyElement('solo_chat'),
    );
    expect(repository.submittedInputs.last.text, 'Give me another example');
    expect(find.text('Aura reply to: Give me another example'), findsOneWidget);
    expect(composer, findsOneWidget);
    expect(tester.widget<TextField>(composer).enabled, isNot(false));
    expect(
      repository.session.interactiveState['phase'],
      'post_question_prompt',
    );
    expect(find.byKey(const ValueKey('persistent-mode-chat')), findsNothing);
    expect(find.text('Continue Chat'), findsNothing);
    expect(find.byKey(const ValueKey('persistent-mode-quiz')), findsOneWidget);
    await _disposeQuizPage(tester);
  });

  testWidgets('Next question directly generates the next question', (
    tester,
  ) async {
    final repository = _QuizStoriesRepository(session: _postQuestionSession());
    await _pumpQuizPage(
      tester,
      repository: repository,
      userId: 'solo-user',
      interactionMode: 'interactive',
    );

    expect(find.text('Next question'), findsOneWidget);
    expect(find.text('Continue Quiz'), findsNothing);
    expect(find.text('Chat with Aura'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('persistent-mode-quiz')));
    await tester.pump();
    await tester.pump();

    expect(repository.submittedInputs, hasLength(1));
    expect(repository.submittedInputs.single.inputType, 'option_select');
    expect(repository.submittedInputs.single.optionId, 'continue_topic');
    expect(repository.session.interactiveState['phase'], 'generating_question');
    expect(find.text('Next question'), findsOneWidget);
    expect(find.text('continue_topic'), findsNothing);
    await _disposeQuizPage(tester);
  });

  testWidgets('custom topic focuses the input without submitting', (
    tester,
  ) async {
    final repository = _QuizStoriesRepository(session: _topicSession());
    await _pumpQuizPage(
      tester,
      repository: repository,
      userId: 'solo-user',
      interactionMode: 'interactive',
      viewPadding: const EdgeInsets.only(bottom: 24),
    );

    final inputFinder = find.byKey(const ValueKey('solo-topic-text-field'));
    expect(inputFinder, findsNothing);

    await tester.ensureVisible(find.text('Type my own topic'));
    await tester.tap(find.text('Type my own topic'));
    await tester.pump();

    expect(inputFinder, findsOneWidget);
    expect(
      find.byKey(const ValueKey('topic-suggestion-custom_topic')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('solo-topic-floating-call')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('topic-suggestion-history')),
      findsOneWidget,
    );
    final educationRect = tester.getRect(
      find.byKey(const ValueKey('topic-suggestion-education')),
    );
    final inputRect = tester.getRect(inputFinder);
    expect(inputRect.top - educationRect.bottom, closeTo(12, 0.1));
    expect(find.byIcon(Icons.call_rounded), findsOneWidget);
    expect(
      tester.getRect(find.byTooltip('Voice')).left,
      greaterThan(inputRect.right),
    );
    expect(tester.widget<TextField>(inputFinder).enabled, isNot(false));
    expect(tester.widget<TextField>(inputFinder).focusNode?.hasFocus, isTrue);
    expect(tester.testTextInput.isVisible, isTrue);
    expect(repository.submittedInputs, isEmpty);
    await _disposeQuizPage(tester);
  });

  testWidgets('custom topic suggestions scroll when the keyboard is visible', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 620));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _QuizStoriesRepository(session: _topicSession());
    await _pumpQuizPage(
      tester,
      repository: repository,
      userId: 'solo-user',
      interactionMode: 'interactive',
      viewInsets: const EdgeInsets.only(bottom: 300),
    );

    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Type my own topic'));
    await tester.tap(find.text('Type my own topic'));
    await tester.pump(const Duration(milliseconds: 250));

    expect(
      find.byKey(const ValueKey('topic-suggestion-custom_topic')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('solo-topic-text-field')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _disposeQuizPage(tester);
  });

  testWidgets('floating topic call remains tappable', (tester) async {
    final repository = _QuizStoriesRepository(session: _topicSession());
    await _pumpQuizPage(
      tester,
      repository: repository,
      userId: 'solo-user',
      interactionMode: 'interactive',
      voicePageBuilder: (_) =>
          const Scaffold(body: Center(child: Text('Test voice route'))),
    );

    await tester.tap(find.byKey(const ValueKey('solo-topic-floating-call')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Test voice route'), findsOneWidget);
    await _disposeQuizPage(tester);
  });

  testWidgets('custom topic input locks again after submission', (
    tester,
  ) async {
    final repository = _QuizStoriesRepository(session: _topicSession());
    await _pumpQuizPage(
      tester,
      repository: repository,
      userId: 'solo-user',
      interactionMode: 'interactive',
    );

    final inputFinder = find.byKey(const ValueKey('solo-topic-text-field'));
    await tester.ensureVisible(find.text('Type my own topic'));
    await tester.tap(find.text('Type my own topic'));
    await tester.pump();
    await tester.enterText(inputFinder, 'Science and technology');
    await tester.pump();
    await tester.tap(find.byTooltip('Send'));
    await tester.pump();
    await tester.pump();

    expect(repository.submittedInputs, hasLength(1));
    expect(repository.submittedInputs.single.text, 'Science and technology');
    expect(inputFinder, findsNothing);
    expect(
      find.byKey(const ValueKey('topic-suggestion-history')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('topic-suggestion-custom_topic')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('topic-aspect-custom_aspect')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('topic-aspect-ancient_history')),
      findsOneWidget,
    );
    expect(tester.testTextInput.isVisible, isFalse);
    await _disposeQuizPage(tester);
  });

  testWidgets('pending custom topic keeps the fallback call visible', (
    tester,
  ) async {
    final repository = _DelayedQuizStoriesRepository(session: _topicSession());
    await _pumpQuizPage(
      tester,
      repository: repository,
      userId: 'solo-user',
      interactionMode: 'interactive',
    );

    await tester.ensureVisible(find.text('Type my own topic'));
    await tester.tap(find.text('Type my own topic'));
    await tester.pump();
    final inputFinder = find.byKey(const ValueKey('solo-topic-text-field'));
    await tester.enterText(inputFinder, 'Science and technology');
    await tester.pump();
    await tester.tap(find.byTooltip('Send'));
    await tester.pump();

    expect(inputFinder, findsNothing);
    expect(
      find.byKey(const ValueKey('topic-suggestion-history')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('solo-topic-floating-call')),
      findsNothing,
    );
    expect(find.byIcon(Icons.call_rounded), findsOneWidget);

    repository.releaseSubmit();
    await tester.pump();
    await tester.pump();
    await _disposeQuizPage(tester);
  });

  testWidgets('pre-setup Chat switches directly to timer selection', (
    tester,
  ) async {
    final repository = _QuizStoriesRepository(
      session: _topicSession(phase: 'discussion'),
    );
    await _pumpQuizPage(
      tester,
      repository: repository,
      userId: 'solo-user',
      interactionMode: 'interactive',
    );

    final inputFinder = find.byKey(const ValueKey('solo-topic-text-field'));
    final quizMode = find.byKey(const ValueKey('persistent-mode-quiz'));
    expect(inputFinder, findsOneWidget);
    expect(tester.widget<TextField>(inputFinder).enabled, isNot(false));
    expect(quizMode, findsOneWidget);

    await tester.tap(quizMode);
    await tester.pump();
    await tester.pump();

    expect(repository.submittedInputs, hasLength(1));
    expect(repository.submittedInputs.single.inputType, 'option_select');
    expect(repository.submittedInputs.single.optionId, 'quiz');
    expect(
      find.byKey(const ValueKey('topic-decision-continue_topic')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('timer-suggestion-timed')),
      findsOneWidget,
    );
    await _disposeQuizPage(tester);
  });

  testWidgets('solo mode selection keeps the text input hidden', (
    tester,
  ) async {
    final repository = _QuizStoriesRepository(
      session: _topicSession(phase: 'mode_selection'),
    );
    await _pumpQuizPage(
      tester,
      repository: repository,
      userId: 'solo-user',
      interactionMode: 'interactive',
    );

    final inputFinder = find.byKey(const ValueKey('solo-topic-text-field'));
    expect(inputFinder, findsNothing);
    expect(find.text('Message'), findsNothing);
    expect(find.byIcon(Icons.call_rounded), findsOneWidget);
    await _disposeQuizPage(tester);
  });

  testWidgets('solo topic clarification retains its call control', (
    tester,
  ) async {
    final repository = _QuizStoriesRepository(
      session: _topicSession(hasPendingClarification: true),
    );
    await _pumpQuizPage(
      tester,
      repository: repository,
      userId: 'solo-user',
      interactionMode: 'interactive',
    );

    expect(
      find.byKey(const ValueKey('solo-topic-floating-call')),
      findsNothing,
    );
    expect(find.byIcon(Icons.call_rounded), findsOneWidget);
    expect(find.text('Message'), findsNothing);
    await _disposeQuizPage(tester);
  });

  testWidgets('group quiz keeps its existing bottom-bar placeholder', (
    tester,
  ) async {
    final repository = _QuizStoriesRepository(
      session: _session(phase: 'question_active', sessionType: 'group'),
    );
    await _pumpQuizPage(
      tester,
      repository: repository,
      userId: 'host-user',
      viewInsets: const EdgeInsets.only(bottom: 260),
    );

    expect(find.byKey(const ValueKey('solo-topic-text-field')), findsNothing);
    expect(find.text('Message'), findsOneWidget);
    expect(find.byIcon(Icons.call_rounded), findsOneWidget);
    await _disposeQuizPage(tester);
  });

  testWidgets('group setup choices submit host configuration', (tester) async {
    final turn = InteractiveTurn.fromJson({
      'type': 'interactive_turn.v1',
      'session_id': 'session-1',
      'turn_id': 'group-setup-turn',
      'seq': 2,
      'speaker': {'type': 'ai', 'role': 'host'},
      'blocks': const [
        {
          'kind': 'text',
          'text': 'Before we start, choose how this game should get questions.',
        },
        {
          'kind': 'choice_group',
          'prompt': '',
          'options': [
            {'id': 'question_bank', 'label': 'Pick from story questions'},
            {'id': 'random', 'label': 'Generate random questions'},
          ],
          'metadata': {
            'choice_kind': 'group_quiz_setup',
            'setup_stage': 'question_source',
          },
        },
      ],
      'input_requests': const [],
      'state_patch': const {
        'phase': 'group_setup',
        'group_setup_stage': 'question_source',
      },
    });
    final base = _session(phase: 'group_setup', sessionType: 'group');
    final repository = _QuizStoriesRepository(
      session: base.copyWith(
        currentTurn: turn,
        lastSeq: turn.seq,
        interactiveState: {
          ...base.interactiveState,
          'group_setup_stage': 'question_source',
        },
      ),
    );
    await _pumpQuizPage(tester, repository: repository, userId: 'host-user');

    expect(find.text('Generate random questions'), findsOneWidget);
    await tester.tap(find.text('Generate random questions'));
    await tester.pump();

    expect(repository.submittedInputs, hasLength(1));
    expect(repository.submittedInputs.single.inputType, 'option_select');
    expect(repository.submittedInputs.single.optionId, 'random');
    await _disposeQuizPage(tester);
  });

  testWidgets('group setup option panel excludes welcome copy', (tester) async {
    final turn = InteractiveTurn.fromJson({
      'type': 'interactive_turn.v1',
      'session_id': 'session-1',
      'turn_id': 'group-setup-turn',
      'seq': 2,
      'speaker': {'type': 'ai', 'role': 'host'},
      'blocks': const [
        {
          'kind': 'text',
          'text':
              'Welcome in. Step into The Hot Seat, a high-pressure group trivia room hosted by Aura.\n\nBefore we start, choose how this game should get its questions.',
        },
        {
          'kind': 'choice_group',
          'prompt': '',
          'options': [
            {'id': 'question_bank', 'label': 'Pick from story questions'},
            {'id': 'random', 'label': 'Generate random questions'},
          ],
          'metadata': {
            'choice_kind': 'group_quiz_setup',
            'setup_stage': 'question_source',
          },
        },
      ],
      'input_requests': const [],
      'state_patch': const {
        'phase': 'group_setup',
        'group_setup_stage': 'question_source',
      },
    });
    final base = _session(phase: 'group_setup', sessionType: 'group');
    final repository = _QuizStoriesRepository(
      session: base.copyWith(
        currentTurn: turn,
        lastSeq: turn.seq,
        interactiveState: {
          ...base.interactiveState,
          'group_setup_stage': 'question_source',
        },
      ),
    );
    await _pumpQuizPage(tester, repository: repository, userId: 'host-user');

    expect(
      find.text(
        'Before we start, choose how this game should get its questions.',
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        'Welcome in. Step into The Hot Seat, a high-pressure group trivia room hosted by Aura.\n\nBefore we start',
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('group-setup-option-panel')),
        matching: find.text(
          'Before we start, choose how this game should get its questions.',
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('group-setup-option-panel')),
        matching: find.textContaining('Welcome in.'),
      ),
      findsNothing,
    );
    await _disposeQuizPage(tester);
  });

  testWidgets('group setup topic accepts typed subject', (tester) async {
    final turn = InteractiveTurn.fromJson({
      'type': 'interactive_turn.v1',
      'session_id': 'session-1',
      'turn_id': 'group-topic-turn',
      'seq': 3,
      'speaker': {'type': 'ai', 'role': 'host'},
      'blocks': const [
        {
          'kind': 'text',
          'text': 'What topic or subject should the random questions focus on?',
        },
        {
          'kind': 'choice_group',
          'prompt': '',
          'options': [
            {'id': 'science', 'label': 'Science'},
            {'id': 'history', 'label': 'History'},
            {'id': 'any_topic', 'label': 'Any topic'},
          ],
          'metadata': {
            'choice_kind': 'group_quiz_setup',
            'setup_stage': 'topic_subject',
          },
        },
      ],
      'input_requests': const [],
      'state_patch': const {
        'phase': 'group_setup',
        'group_setup_stage': 'topic_subject',
      },
    });
    final base = _session(phase: 'group_setup', sessionType: 'group');
    final repository = _QuizStoriesRepository(
      session: base.copyWith(
        currentTurn: turn,
        lastSeq: turn.seq,
        interactiveState: {
          ...base.interactiveState,
          'group_setup_stage': 'topic_subject',
        },
      ),
    );
    await _pumpQuizPage(tester, repository: repository, userId: 'host-user');

    expect(find.text('Type a topic or subject'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'African history');
    await tester.pump();
    await tester.tap(find.byIcon(CupertinoIcons.paperplane_fill).last);
    await tester.pump();

    expect(repository.submittedInputs, hasLength(1));
    expect(repository.submittedInputs.single.inputType, 'text');
    expect(repository.submittedInputs.single.text, 'African history');
    await _disposeQuizPage(tester);
  });

  testWidgets(
    'group setup choice replies immediately while request is pending',
    (tester) async {
      final submitDelay = Completer<void>();
      final turn = InteractiveTurn.fromJson({
        'type': 'interactive_turn.v1',
        'session_id': 'session-1',
        'turn_id': 'group-topic-turn',
        'seq': 3,
        'speaker': {'type': 'ai', 'role': 'host'},
        'blocks': const [
          {
            'kind': 'text',
            'text':
                'What topic or subject should the random questions focus on?',
          },
          {
            'kind': 'choice_group',
            'prompt': '',
            'options': [
              {'id': 'science', 'label': 'Science'},
              {'id': 'history', 'label': 'History'},
              {'id': 'pop_culture', 'label': 'Pop culture'},
              {'id': 'any_topic', 'label': 'Any topic'},
            ],
            'metadata': {
              'choice_kind': 'group_quiz_setup',
              'setup_stage': 'topic_subject',
            },
          },
        ],
        'input_requests': const [],
        'state_patch': const {
          'phase': 'group_setup',
          'group_setup_stage': 'topic_subject',
        },
      });
      final base = _session(phase: 'group_setup', sessionType: 'group');
      final repository = _QuizStoriesRepository(
        session: base.copyWith(
          currentTurn: turn,
          lastSeq: turn.seq,
          interactiveState: {
            ...base.interactiveState,
            'group_setup_stage': 'topic_subject',
          },
        ),
        submitDelay: submitDelay.future,
      );
      await _pumpQuizPage(tester, repository: repository, userId: 'host-user');

      expect(find.text('Any topic'), findsOneWidget);
      await tester.tap(find.text('Any topic'));
      await tester.pump();

      expect(repository.submittedInputs, hasLength(1));
      expect(repository.submittedInputs.single.optionId, 'any_topic');
      expect(find.text('Any topic'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('group-setup-option-panel')),
        findsNothing,
      );

      submitDelay.complete();
      await tester.pump();
      await tester.pump();
      await _disposeQuizPage(tester);
    },
  );

  testWidgets('group participant sees only host setup room status', (
    tester,
  ) async {
    final turn = InteractiveTurn.fromJson({
      'type': 'interactive_turn.v1',
      'session_id': 'session-1',
      'turn_id': 'group-setup-turn',
      'seq': 4,
      'speaker': {'type': 'ai', 'role': 'host'},
      'blocks': const [
        {'kind': 'text', 'text': 'Do you want timed rounds?'},
        {
          'kind': 'choice_group',
          'prompt': '',
          'options': [
            {'id': 'timed', 'label': 'Timed rounds'},
            {'id': 'untimed', 'label': 'Untimed rounds'},
          ],
          'metadata': {
            'choice_kind': 'group_quiz_setup',
            'setup_stage': 'round_timer',
          },
        },
      ],
      'input_requests': const [],
      'state_patch': const {
        'phase': 'group_setup',
        'group_setup_stage': 'round_timer',
      },
    });
    final base = _session(phase: 'group_setup', sessionType: 'group');
    final repository = _QuizStoriesRepository(
      session: base.copyWith(
        currentTurn: turn,
        lastSeq: turn.seq,
        events: const [
          StorySessionEvent(
            id: 'setup-turn-1',
            sessionId: 'session-1',
            seq: 1,
            actorType: 'ai',
            eventType: 'interactive_turn',
            payload: {
              'type': 'interactive_turn.v1',
              'session_id': 'session-1',
              'turn_id': 'group-source-turn',
              'seq': 1,
              'speaker': {'type': 'ai', 'role': 'host'},
              'blocks': [
                {
                  'kind': 'text',
                  'text':
                      'Before we start, choose how this game should get its questions.',
                },
                {
                  'kind': 'choice_group',
                  'prompt': '',
                  'options': [
                    {
                      'id': 'question_bank',
                      'label': 'Pick from story questions',
                    },
                    {'id': 'random', 'label': 'Generate random questions'},
                  ],
                  'metadata': {'choice_kind': 'group_quiz_setup'},
                },
              ],
              'input_requests': [],
              'state_patch': {'phase': 'group_setup'},
            },
          ),
          StorySessionEvent(
            id: 'setup-choice-1',
            sessionId: 'session-1',
            seq: 2,
            actorType: 'user',
            eventType: 'setup_choice_selected',
            payload: {
              'stage': 'question_count',
              'option_id': '4',
              'text': '4 questions',
              'participant_text': 'This game will have 4 questions.',
            },
          ),
          StorySessionEvent(
            id: 'setup-choice-2',
            sessionId: 'session-1',
            seq: 3,
            actorType: 'user',
            eventType: 'setup_choice_selected',
            payload: {
              'stage': 'round_timer',
              'option_id': 'timed',
              'text': 'Timed rounds',
              'participant_text': 'This game will have timed rounds.',
            },
          ),
        ],
        interactiveState: {
          ...base.interactiveState,
          'group_setup_stage': 'round_timer',
        },
      ),
    );
    await _pumpQuizPage(tester, repository: repository, userId: 'player-user');

    expect(find.text('Host is setting up the room.'), findsOneWidget);
    expect(find.text('This game will have 4 questions.'), findsNothing);
    expect(find.text('This game will have timed rounds.'), findsNothing);
    expect(find.textContaining('Join code:'), findsNothing);
    expect(find.text('Do you want timed rounds?'), findsNothing);
    expect(
      find.text(
        'Before we start, choose how this game should get its questions.',
      ),
      findsNothing,
    );
    await _disposeQuizPage(tester);
  });

  testWidgets('group host sees setup selections as replies', (tester) async {
    final base = _session(phase: 'group_setup', sessionType: 'group');
    final repository = _QuizStoriesRepository(
      session: base.copyWith(
        lastSeq: 2,
        events: const [
          StorySessionEvent(
            id: 'setup-choice-1',
            sessionId: 'session-1',
            seq: 1,
            actorType: 'user',
            actorUserId: 'host-user',
            eventType: 'setup_choice_selected',
            payload: {
              'stage': 'question_count',
              'option_id': '4',
              'text': '4 questions',
              'participant_text': 'This game will have 4 questions.',
            },
          ),
          StorySessionEvent(
            id: 'setup-choice-2',
            sessionId: 'session-1',
            seq: 2,
            actorType: 'user',
            actorUserId: 'host-user',
            eventType: 'setup_choice_selected',
            payload: {
              'stage': 'round_timer',
              'option_id': 'timed',
              'text': 'Timed rounds',
              'participant_text': 'This game will have timed rounds.',
            },
          ),
        ],
      ),
    );
    await _pumpQuizPage(tester, repository: repository, userId: 'host-user');

    expect(find.text('4 questions'), findsOneWidget);
    expect(find.text('Timed rounds'), findsOneWidget);
    expect(find.text('This game will have 4 questions.'), findsNothing);
    expect(find.textContaining('Join code:'), findsNothing);
    await _disposeQuizPage(tester);
  });

  testWidgets('group host reviews setup before starting quiz', (tester) async {
    final reviewTurn = InteractiveTurn.fromJson({
      'type': 'interactive_turn.v1',
      'session_id': 'session-1',
      'turn_id': 'group-review-turn',
      'seq': 3,
      'speaker': {'type': 'ai', 'role': 'host'},
      'blocks': const [
        {
          'kind': 'text',
          'text':
              'Review this quiz setup before starting.\n\nGame: Quiz story\nSource: Random questions\nTopic: Science\nQuestions: 4 questions\nRounds: Timed rounds',
        },
        {
          'kind': 'choice_group',
          'prompt': '',
          'options': [
            {'id': 'start_quiz', 'label': 'Start quiz'},
            {'id': 'edit_quiz', 'label': 'Edit quiz'},
          ],
          'metadata': {
            'choice_kind': 'group_quiz_setup',
            'setup_stage': 'review',
          },
        },
      ],
      'input_requests': const [],
      'state_patch': const {
        'phase': 'group_setup_review',
        'group_setup_stage': 'review',
      },
    });
    final base = _session(phase: 'group_setup_review', sessionType: 'group');
    final repository = _QuizStoriesRepository(
      session: base.copyWith(
        currentTurn: reviewTurn,
        lastSeq: reviewTurn.seq,
        interactiveState: {
          ...base.interactiveState,
          'phase': 'group_setup_review',
          'group_setup_stage': 'review',
          'question_source_mode': 'random',
          'selected_topic': 'Science',
          'total_rounds': 4,
          'quiz_timer_enabled': true,
        },
      ),
    );
    await _pumpQuizPage(tester, repository: repository, userId: 'host-user');

    expect(
      find.byKey(const ValueKey('group-setup-option-panel')),
      findsOneWidget,
    );
    expect(find.text('Start quiz'), findsOneWidget);
    expect(find.text('Edit quiz'), findsOneWidget);
    expect(find.textContaining('Topic: Science'), findsWidgets);
    expect(find.textContaining('Questions: 4 questions'), findsWidgets);
    await _disposeQuizPage(tester);
  });

  testWidgets('group host continues from the bottom option panel', (
    tester,
  ) async {
    final advanceDelay = Completer<void>();
    final repository = _QuizStoriesRepository(
      session: _session(phase: 'showing_results', sessionType: 'group'),
      advanceDelay: advanceDelay.future,
    );
    await _pumpQuizPage(tester, repository: repository, userId: 'host-user');

    expect(
      find.byKey(const ValueKey('group-host-advance-option-panel')),
      findsOneWidget,
    );
    expect(find.text('Ready for next question'), findsOneWidget);
    expect(
      find.text(
        'Players can keep chatting, or you can continue when everyone is ready.',
      ),
      findsOneWidget,
    );
    expect(find.text('Next question'), findsOneWidget);
    expect(find.text('Continue'), findsNothing);
    expect(find.text('Message'), findsOneWidget);

    await tester.tap(find.text('Next question'));
    await tester.pump();

    expect(repository.advanceCalls, 1);
    expect(
      find.byKey(const ValueKey('group-host-advance-option-panel')),
      findsNothing,
    );
    expect(find.text('Next question'), findsNothing);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byIcon(Icons.call_rounded), findsOneWidget);
    expect(find.text('Getting questions...'), findsOneWidget);
    expect(repository.session.interactiveState['phase'], 'showing_results');

    advanceDelay.complete();
    await tester.pump();
    await tester.pump();

    expect(repository.advanceCalls, 1);
    expect(repository.session.interactiveState['phase'], 'generating_question');
    await _disposeQuizPage(tester);
  });

  testWidgets('group host option popup keeps message input editable', (
    tester,
  ) async {
    final repository = _QuizStoriesRepository(
      session: _session(phase: 'showing_results', sessionType: 'group'),
    );
    await _pumpQuizPage(
      tester,
      repository: repository,
      userId: 'host-user',
      viewInsets: const EdgeInsets.only(bottom: 260),
    );

    expect(
      find.byKey(const ValueKey('group-host-advance-option-panel')),
      findsOneWidget,
    );
    expect(find.byType(TextField), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Ready when you are');
    await tester.pump();
    await tester.tap(find.byIcon(CupertinoIcons.paperplane_fill).last);
    await tester.pump();
    await tester.pump();

    expect(repository.submittedInputs, hasLength(1));
    expect(repository.submittedInputs.single.inputType, 'player_chat');
    expect(repository.submittedInputs.single.text, 'Ready when you are');
    await _disposeQuizPage(tester);
  });

  testWidgets('group host input temporarily hides and restores option tab', (
    tester,
  ) async {
    final repository = _QuizStoriesRepository(
      session: _session(phase: 'showing_results', sessionType: 'group'),
    );
    await _pumpQuizPage(
      tester,
      repository: repository,
      userId: 'host-user',
      viewInsets: const EdgeInsets.only(bottom: 260),
    );

    expect(find.text('Next question'), findsOneWidget);
    await tester.tap(find.byTooltip('Hide options'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('group-host-advance-option-panel')),
      findsOneWidget,
    );
    expect(find.text('Next question'), findsNothing);

    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('group-host-advance-option-panel')),
      findsNothing,
    );
    expect(find.byType(TextField), findsOneWidget);

    await _pumpQuizPage(tester, repository: repository, userId: 'host-user');
    expect(
      find.byKey(const ValueKey('group-host-advance-option-panel')),
      findsOneWidget,
    );
    expect(find.text('Next question'), findsNothing);
    expect(find.text('Ready for next question'), findsOneWidget);
    await _disposeQuizPage(tester);
  });

  testWidgets('group host option popup lifts above the keyboard', (
    tester,
  ) async {
    final repository = _QuizStoriesRepository(
      session: _session(phase: 'showing_results', sessionType: 'group'),
    );
    await _pumpQuizPage(
      tester,
      repository: repository,
      userId: 'host-user',
      viewInsets: const EdgeInsets.only(bottom: 260),
    );

    final panelRect = tester.getRect(
      find.byKey(const ValueKey('group-host-advance-option-panel')),
    );
    final screenHeight =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;
    expect(panelRect.bottom, lessThan(screenHeight - 200));
    await _disposeQuizPage(tester);
  });

  testWidgets('group host option popup pushes transcript above it', (
    tester,
  ) async {
    final base = _session(phase: 'showing_results', sessionType: 'group');
    final repository = _QuizStoriesRepository(
      session: base.copyWith(
        interactiveState: {
          ...base.interactiveState,
          'result': const {
            'question_id': 'question-1',
            'correct_option_id': 'a',
            'explanation': 'The host can continue when the room is ready.',
          },
        },
      ),
    );
    await _pumpQuizPage(tester, repository: repository, userId: 'host-user');

    expect(find.text('Ready for next question'), findsOneWidget);
    await tester.tap(find.byTooltip('Hide options'));
    await tester.pumpAndSettle();

    final panelTop = tester
        .getTopLeft(
          find.byKey(const ValueKey('group-host-advance-option-panel')),
        )
        .dy;
    final resultBottom = tester
        .getBottomLeft(find.textContaining('Correct Answer').last)
        .dy;
    expect(resultBottom, lessThan(panelTop));
    await _disposeQuizPage(tester);
  });

  testWidgets('group host pencil tap opens the input', (tester) async {
    final repository = _QuizStoriesRepository(
      session: _session(phase: 'showing_results', sessionType: 'group'),
    );
    await _pumpQuizPage(
      tester,
      repository: repository,
      userId: 'host-user',
      viewInsets: const EdgeInsets.only(bottom: 260),
    );

    expect(
      find.byKey(const ValueKey('group-host-advance-option-panel')),
      findsOneWidget,
    );
    await tester.tap(find.byIcon(CupertinoIcons.pencil).first);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('group-host-advance-option-panel')),
      findsNothing,
    );
    expect(find.byType(TextField), findsOneWidget);
    await _disposeQuizPage(tester);
  });

  testWidgets('group host focused input lifts without dark backdrop', (
    tester,
  ) async {
    final repository = _QuizStoriesRepository(
      session: _session(phase: 'showing_results', sessionType: 'group'),
    );
    await _pumpQuizPage(
      tester,
      repository: repository,
      userId: 'host-user',
      viewInsets: const EdgeInsets.only(bottom: 260),
    );

    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();

    final inputRect = tester.getRect(find.byType(TextField));
    final screenHeight =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;
    expect(inputRect.bottom, lessThan(screenHeight - 200));
    expect(
      find.byKey(const ValueKey('group-keyboard-composer-backdrop')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('group-host-advance-option-panel')),
      findsNothing,
    );
    await _disposeQuizPage(tester);
  });

  testWidgets('group host input reattaches when keyboard closes', (
    tester,
  ) async {
    final repository = _QuizStoriesRepository(
      session: _session(phase: 'showing_results', sessionType: 'group'),
    );
    await _pumpQuizPage(
      tester,
      repository: repository,
      userId: 'host-user',
      viewInsets: const EdgeInsets.only(bottom: 260),
    );

    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('group-host-advance-option-panel')),
      findsNothing,
    );

    await _pumpQuizPage(tester, repository: repository, userId: 'host-user');
    expect(
      find.byKey(const ValueKey('group-host-advance-option-panel')),
      findsOneWidget,
    );
    expect(find.text('Next question'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    await _disposeQuizPage(tester);
  });

  testWidgets('group host final popup opens the leaderboard', (tester) async {
    final base = _session(phase: 'showing_results', sessionType: 'group');
    final repository = _QuizStoriesRepository(
      session: base.copyWith(
        interactiveState: {
          ...base.interactiveState,
          'current_round': 3,
          'total_rounds': 3,
          'result': {
            'question_id': 'question-3',
            'correct_option_id': 'a',
            'standings': const [
              {
                'rank': 1,
                'participant_id': 'host-participant',
                'user_id': 'host-user',
                'display_name': 'Host',
                'score': 4,
              },
              {
                'rank': 2,
                'participant_id': 'player-participant',
                'user_id': 'player-user',
                'display_name': 'Player',
                'score': 2,
              },
            ],
          },
        },
      ),
    );
    await _pumpQuizPage(tester, repository: repository, userId: 'host-user');

    expect(find.text('Show final results'), findsOneWidget);
    await tester.tap(find.text('Show final results'));
    await tester.pumpAndSettle();

    expect(repository.advanceCalls, 1);
    expect(
      find.byKey(const ValueKey('group-quiz-results-sheet')),
      findsOneWidget,
    );
    expect(find.text('Player scores'), findsOneWidget);
    expect(find.text('4 pts'), findsAtLeastNWidgets(1));
    expect(find.text('2 pts'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('group-quiz-results-done')));
    await tester.pumpAndSettle();
    await _disposeQuizPage(tester);
  });

  testWidgets('group final results do not show next-question loading', (
    tester,
  ) async {
    final advanceDelay = Completer<void>();
    final base = _session(phase: 'showing_results', sessionType: 'group');
    final repository = _QuizStoriesRepository(
      session: base.copyWith(
        interactiveState: {
          ...base.interactiveState,
          'current_round': 3,
          'total_rounds': 3,
          'result': {
            'question_id': 'question-3',
            'correct_option_id': 'a',
            'standings': const [
              {
                'rank': 1,
                'participant_id': 'host-participant',
                'user_id': 'host-user',
                'display_name': 'Host',
                'score': 4,
              },
            ],
          },
        },
      ),
      advanceDelay: advanceDelay.future,
    );
    await _pumpQuizPage(tester, repository: repository, userId: 'host-user');

    await tester.tap(find.text('Show final results'));
    await tester.pump();

    expect(repository.advanceCalls, 1);
    expect(
      find.byKey(const ValueKey('group-quiz-results-sheet')),
      findsOneWidget,
    );
    expect(find.text('Loading next question'), findsNothing);
    expect(find.text('Getting questions...'), findsNothing);
    expect(find.text('Aura is getting the next question ready'), findsNothing);

    advanceDelay.complete();
    await tester.pumpAndSettle();
    await _disposeQuizPage(tester);
  });

  testWidgets('group participant keeps waiting without host advance panel', (
    tester,
  ) async {
    final repository = _QuizStoriesRepository(
      session: _session(phase: 'showing_results', sessionType: 'group'),
    );
    await _pumpQuizPage(tester, repository: repository, userId: 'player-user');

    expect(
      find.byKey(const ValueKey('group-host-advance-option-panel')),
      findsNothing,
    );
    expect(find.text('Waiting for host'), findsOneWidget);
    expect(find.text('Next question'), findsNothing);
    await _disposeQuizPage(tester);
  });

  testWidgets('group participant results chat keeps its editable composer', (
    tester,
  ) async {
    final repository = _QuizStoriesRepository(
      session: _session(phase: 'showing_results', sessionType: 'group'),
    );
    await _pumpQuizPage(tester, repository: repository, userId: 'player-user');

    expect(find.byKey(const ValueKey('solo-topic-text-field')), findsOneWidget);
    await _disposeQuizPage(tester);
  });

  testWidgets('completed group game shows replay and close in option popup', (
    tester,
  ) async {
    final base = _session(phase: 'showing_results', sessionType: 'group');
    final repository = _QuizStoriesRepository(
      session: base.copyWith(
        interactiveState: {
          ...base.interactiveState,
          'phase': 'completed',
          'current_round': 3,
          'total_rounds': 3,
          'winner_participant_ids': ['host-participant'],
          'final_standings': const [
            {
              'rank': 1,
              'participant_id': 'host-participant',
              'user_id': 'host-user',
              'display_name': 'Host',
              'score': 4,
            },
            {
              'rank': 2,
              'participant_id': 'player-participant',
              'user_id': 'player-user',
              'display_name': 'Player',
              'score': 2,
            },
          ],
        },
        isCompleted: true,
      ),
    );
    await _pumpQuizPage(tester, repository: repository, userId: 'host-user');

    expect(find.text('Winner: Host'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('group-completed-option-panel')),
      findsOneWidget,
    );
    expect(find.text('Game finished'), findsOneWidget);
    expect(
      find.text('View the leaderboard, replay this game, or close the room.'),
      findsOneWidget,
    );
    final panelTop = tester
        .getTopLeft(find.byKey(const ValueKey('group-completed-option-panel')))
        .dy;
    final winnerBottom = tester.getBottomLeft(find.text('Winner: Host')).dy;
    expect(winnerBottom, lessThan(panelTop));
    expect(find.text('Leaderboard'), findsNothing);
    expect(find.text('Replay'), findsNothing);
    expect(find.text('Close game'), findsNothing);
    expect(find.text('Leave'), findsNothing);
    expect(find.byType(TextField), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Good game everyone');
    await tester.pump();
    await tester.tap(find.byIcon(CupertinoIcons.paperplane_fill).last);
    await tester.pump();
    await tester.pump();

    expect(repository.submittedInputs, hasLength(1));
    expect(repository.submittedInputs.single.inputType, 'player_chat');
    expect(repository.submittedInputs.single.text, 'Good game everyone');

    final pageContext = tester.element(find.byType(StoryChatFlowPage));
    final container = ProviderScope.containerOf(pageContext);
    await container.read(interactiveStoryProvider.notifier).advanceQuestion();
    expect(repository.advanceCalls, 0);

    await tester.tap(find.byTooltip('Show options'));
    await tester.pumpAndSettle();

    expect(find.text('Leaderboard'), findsOneWidget);
    expect(find.text('Replay'), findsOneWidget);
    expect(find.text('Close game'), findsOneWidget);

    await _disposeQuizPage(tester);
  });

  testWidgets('completed group participant can view leaderboard position', (
    tester,
  ) async {
    final base = _session(phase: 'showing_results', sessionType: 'group');
    final repository = _QuizStoriesRepository(
      session: base.copyWith(
        interactiveState: {
          ...base.interactiveState,
          'phase': 'completed',
          'current_round': 3,
          'total_rounds': 3,
          'winner_participant_ids': ['host-participant'],
          'final_standings': const [
            {
              'rank': 1,
              'participant_id': 'host-participant',
              'user_id': 'host-user',
              'display_name': 'Host',
              'score': 4,
            },
            {
              'rank': 2,
              'participant_id': 'player-participant',
              'user_id': 'player-user',
              'display_name': 'Player',
              'score': 2,
            },
          ],
        },
        isCompleted: true,
      ),
    );
    await _pumpQuizPage(tester, repository: repository, userId: 'player-user');

    expect(find.text('Leaderboard'), findsNothing);
    await tester.tap(find.byTooltip('Show options'));
    await tester.pumpAndSettle();

    expect(find.text('Leaderboard'), findsOneWidget);
    await tester.tap(find.text('Leaderboard'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('group-quiz-results-sheet')),
      findsOneWidget,
    );
    expect(find.text('You'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('group-score-row-player-participant')),
      findsOneWidget,
    );
    expect(find.text('#2'), findsAtLeastNWidgets(1));

    await tester.tap(find.byKey(const ValueKey('group-quiz-results-done')));
    await tester.pumpAndSettle();
    await _disposeQuizPage(tester);
  });

  testWidgets('solo history browsing keeps the active session connected', (
    tester,
  ) async {
    final now = DateTime.utc(2026, 7, 11, 12);
    final repository = _QuizStoriesRepository(
      session: _session(phase: 'discussion', sessionType: 'solo'),
      history: [
        SoloInteractiveSessionSummary(
          sessionId: 'session-1',
          storyId: 'story-1',
          storyTitle: 'Quiz story',
          isCompleted: false,
          isPaused: true,
          topicPath: const ['History', 'Ancient Egypt'],
          viewMode: 'chat',
          currentRound: 2,
          lastActivityAt: now,
          createdAt: now.subtract(const Duration(hours: 1)),
        ),
      ],
    );
    await _pumpQuizPage(
      tester,
      repository: repository,
      userId: 'solo-user',
      interactionMode: 'interactive',
    );

    expect(repository.startCalls, 0);
    expect(repository.soloHistoryCalls, 1);
    expect(find.text('CHECKING SESSIONS...'), findsNothing);
    expect(find.byKey(const ValueKey('continue-solo-session')), findsNothing);
    await tester.pump();
    await tester.pump();
    expect(repository.resumeCalls, 1);

    await tester.tap(find.byTooltip('Solo session history'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Solo session history'), findsOneWidget);
    expect(repository.soloHistoryCalls, 1);
    expect(repository.leaveCalls, 0);

    await tester.tap(find.byKey(const ValueKey('close-solo-history')));
    await tester.pump();
    expect(find.text('Solo session history'), findsNothing);
    expect(repository.leaveCalls, 0);
    final pageContext = tester.element(find.byType(StoryChatFlowPage));
    final container = ProviderScope.containerOf(pageContext);
    expect(
      container.read(interactiveStoryProvider).session?.sessionId,
      'session-1',
    );
    await _disposeQuizPage(tester);
  });

  testWidgets('timed solo question blocks history without leaving', (
    tester,
  ) async {
    final now = DateTime.utc(2026, 7, 11, 12);
    final base = _session(phase: 'question_active', sessionType: 'solo');
    final repository = _QuizStoriesRepository(
      session: base.copyWith(
        interactiveState: {
          ...base.interactiveState,
          'expires_at': now.add(const Duration(seconds: 30)).toIso8601String(),
        },
      ),
      history: [
        SoloInteractiveSessionSummary(
          sessionId: 'session-1',
          storyId: 'story-1',
          storyTitle: 'Quiz story',
          isCompleted: false,
          isPaused: true,
          topicPath: const ['Science'],
          viewMode: 'quiz',
          currentRound: 1,
          lastActivityAt: now,
          createdAt: now,
        ),
      ],
    );
    await _pumpQuizPage(
      tester,
      repository: repository,
      userId: 'solo-user',
      interactionMode: 'interactive',
    );
    await tester.tap(find.byKey(const ValueKey('continue-solo-session')));
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byTooltip('Solo session history'));
    await tester.pump();
    expect(
      find.text('Finish this timed question before opening session history.'),
      findsOneWidget,
    );
    expect(find.text('Solo session history'), findsNothing);
    expect(repository.leaveCalls, 0);
    await _disposeQuizPage(tester);
  });
}

Future<void> _disposeQuizPage(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 3));
}

Future<void> _pumpQuizPage(
  WidgetTester tester, {
  required _QuizStoriesRepository repository,
  required String userId,
  String interactionMode = 'group',
  TextScaler? textScaler,
  EdgeInsets? viewPadding,
  EdgeInsets? viewInsets,
  WidgetBuilder? voicePageBuilder,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        storiesRepositoryProvider.overrideWithValue(repository),
        authControllerProvider.overrideWith(() => _TestAuthController(userId)),
        voiceChatControllerProvider.overrideWith(_TestVoiceController.new),
        storyDetailProvider(
          'story-1',
        ).overrideWith((ref) async => _storyDetail),
      ],
      child: MaterialApp(
        builder: (context, child) {
          if (textScaler == null && viewPadding == null && viewInsets == null) {
            return child!;
          }
          var data = MediaQuery.of(context);
          if (textScaler != null) {
            data = data.copyWith(textScaler: textScaler);
          }
          if (viewPadding != null) {
            data = data.copyWith(
              padding: viewPadding,
              viewPadding: viewPadding,
            );
          }
          if (viewInsets != null) {
            data = data.copyWith(viewInsets: viewInsets);
          }
          return MediaQuery(data: data, child: child!);
        },
        home: StoryChatFlowPage(
          storyId: 'story-1',
          storyTitle: 'Quiz story',
          initialInteractionMode: interactionMode,
          voicePageBuilder: voicePageBuilder,
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

InteractiveSessionState _session({
  required String phase,
  required String sessionType,
}) {
  return InteractiveSessionState(
    sessionId: 'session-1',
    storyId: 'story-1',
    interactionMode: sessionType == 'group' ? 'group' : 'interactive',
    aiRole: 'host',
    interactiveState: {
      'template': 'quiz',
      'session_type': sessionType,
      'phase': phase,
      'current_round': 1,
      'total_rounds': 3,
      if (phase == 'generation_failed')
        'generation_error': 'The next question could not be loaded.',
      if (phase == 'question_active')
        'question': {
          'question_id': 'question-1',
          'prompt': 'Ready?',
          'options': const [
            {'id': 'a', 'label': 'Yes'},
            {'id': 'b', 'label': 'No'},
          ],
        },
    },
    participants: sessionType == 'group'
        ? const [
            StoryParticipant(
              id: 'host-participant',
              sessionId: 'session-1',
              userId: 'host-user',
              deviceId: 'host-device',
              displayName: 'Host',
              role: 'host',
              status: 'active',
              score: 0,
            ),
            StoryParticipant(
              id: 'player-participant',
              sessionId: 'session-1',
              userId: 'player-user',
              deviceId: 'player-device',
              displayName: 'Player',
              role: 'participant',
              status: 'active',
              score: 0,
            ),
          ]
        : const [],
  );
}

const _pageTopicSuggestions = <Map<String, dynamic>>[
  {'id': 'history', 'label': 'History'},
  {'id': 'politics', 'label': 'Politics'},
  {'id': 'education', 'label': 'Education'},
  {'id': 'custom_topic', 'label': 'Type my own topic'},
];

InteractiveSessionState _topicSession({
  String sessionId = 'session-1',
  String phase = 'topic_selection',
  bool hasPendingClarification = false,
}) {
  return InteractiveSessionState.fromJson({
    'session_id': sessionId,
    'story_id': 'story-1',
    'interaction_mode': 'interactive',
    'ai_role': 'host',
    'interactive_state': {
      'template': 'quiz',
      'session_type': 'solo',
      'phase': phase,
      if (phase != 'topic_selection') 'selected_topic': 'History',
      'topic_prompt': 'What would you like to explore?',
      'topic_suggestions': _pageTopicSuggestions,
      if (hasPendingClarification)
        'pending_topic_options': const ['World history', 'Ancient history'],
    },
    'participants': const [],
    'events': [
      {
        'id': 'topic-event',
        'session_id': sessionId,
        'seq': 1,
        'actor_type': 'ai',
        'event_type': 'topic_selection_started',
        'payload': {
          'prompt': 'What would you like to explore?',
          'topic_suggestions': _pageTopicSuggestions,
        },
      },
    ],
    'last_seq': 1,
    'is_completed': false,
  });
}

InteractiveTurn _modeTurn({int seq = 2}) {
  return InteractiveTurn.fromJson({
    'type': 'interactive_turn.v1',
    'session_id': 'session-1',
    'turn_id': 'mode-turn-$seq',
    'seq': seq,
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
  });
}

InteractiveTurn _timerTurn({int seq = 4}) {
  return InteractiveTurn.fromJson({
    'type': 'interactive_turn.v1',
    'session_id': 'session-1',
    'turn_id': 'timer-turn-$seq',
    'seq': seq,
    'speaker': {'type': 'ai', 'role': 'host'},
    'blocks': [
      {
        'kind': 'text',
        'text': 'Do you want this quiz timed, or do you want it untimed?',
      },
      {
        'kind': 'choice_group',
        'prompt': '',
        'options': [
          {'id': 'timed', 'label': 'Timed'},
          {'id': 'untimed', 'label': 'Untimed'},
        ],
        'metadata': {'choice_kind': 'solo_quiz_timer'},
      },
    ],
  });
}

const _pageAspectSuggestions = <Map<String, dynamic>>[
  {'id': 'ancient_history', 'label': 'Ancient history'},
  {'id': 'modern_history', 'label': 'Modern history'},
  {'id': 'cultural_history', 'label': 'Cultural history'},
];

InteractiveTurn _aspectSuggestionTurn({
  required int seq,
  int revision = 1,
  List<String> topicPath = const ['History'],
  List<Map<String, dynamic>> suggestions = _pageAspectSuggestions,
  bool includePrompt = true,
}) {
  final depth = topicPath.length - 1;
  return InteractiveTurn.fromJson({
    'type': 'interactive_turn.v1',
    'session_id': 'session-1',
    'turn_id': 'aspect-turn-$seq',
    'seq': seq,
    'speaker': {'type': 'ai', 'role': 'host'},
    'blocks': [
      if (includePrompt)
        {'kind': 'text', 'text': 'Which aspect should we focus on?'},
      {
        'kind': 'choice_group',
        'prompt': '',
        'options': [
          ...suggestions,
          if (depth == 0) {'id': 'continue_with_topic', 'label': 'Continue'},
        ],
        'metadata': {
          'choice_kind': 'solo_topic_aspect',
          'topic_path': topicPath,
          'depth': depth,
          'revision': revision,
          'allow_custom_aspect': true,
          'topic_path_actions_expanded': false,
        },
      },
    ],
    'state_patch': {
      'phase': 'topic_selection',
      'topic_selection_stage': 'aspect',
      'pending_topic_aspects': suggestions,
      'topic_aspect_status': 'ready',
      'topic_aspect_revision': revision,
      'topic_path': topicPath,
      'topic_drilldown_depth': depth,
      'allow_custom_aspect': true,
      'topic_path_actions_expanded': false,
    },
  });
}

InteractiveTurn _aspectActionsTurn({
  required int seq,
  int revision = 2,
  List<String> topicPath = const ['History', 'Ancient history'],
}) {
  final depth = topicPath.length - 1;
  return InteractiveTurn.fromJson({
    'type': 'interactive_turn.v1',
    'session_id': 'session-1',
    'turn_id': 'aspect-actions-turn-$seq',
    'seq': seq,
    'speaker': {'type': 'ai', 'role': 'host'},
    'blocks': [
      {'kind': 'text', 'text': 'That gives us a clear path.'},
      {
        'kind': 'choice_group',
        'prompt': '',
        'options': [
          {'id': 'quiz', 'label': 'Take me to quiz'},
          {'id': 'chat', 'label': 'Chat with Aura'},
          {'id': 'change_aspect', 'label': 'Change aspect'},
        ],
        'metadata': {
          'choice_kind': 'solo_topic_path_actions',
          'topic_path': topicPath,
          'depth': depth,
          'revision': revision,
          'allow_custom_aspect': true,
          'topic_path_actions_expanded': false,
        },
      },
    ],
    'state_patch': {
      'phase': 'topic_selection',
      'topic_selection_stage': 'aspect',
      'pending_topic_aspects': const [],
      'topic_aspect_status': 'selected',
      'topic_aspect_revision': revision,
      'topic_path': topicPath,
      'topic_drilldown_depth': depth,
      'allow_custom_aspect': true,
      'topic_path_actions_expanded': false,
    },
  });
}

InteractiveTurn _rootExpandedActionsTurn({
  required int seq,
  int revision = 1,
  List<String> topicPath = const ['History'],
}) {
  final depth = topicPath.length - 1;
  return InteractiveTurn.fromJson({
    'type': 'interactive_turn.v1',
    'session_id': 'session-1',
    'turn_id': 'root-actions-turn-$seq',
    'seq': seq,
    'speaker': {'type': 'ai', 'role': 'host'},
    'blocks': [
      {
        'kind': 'text',
        'text':
            'Would you like to take a quiz about ${topicPath.first} or chat with Aura?',
      },
      {
        'kind': 'choice_group',
        'prompt': '',
        'options': [
          {'id': 'quiz', 'label': 'Take me to quiz'},
          {'id': 'chat', 'label': 'Chat with Aura'},
        ],
        'metadata': {
          'choice_kind': 'solo_topic_path_actions',
          'topic_path': topicPath,
          'depth': depth,
          'revision': revision,
          'allow_custom_aspect': false,
          'topic_path_actions_expanded': true,
        },
      },
    ],
    'state_patch': {
      'phase': 'topic_selection',
      'topic_selection_stage': 'aspect',
      'pending_topic_aspects': _pageAspectSuggestions,
      'topic_aspect_status': 'ready',
      'topic_aspect_revision': revision,
      'topic_path': topicPath,
      'topic_drilldown_depth': depth,
      'allow_custom_aspect': false,
      'topic_path_actions_expanded': true,
    },
  });
}

InteractiveTurn _aspectFailureTurn({required int seq}) {
  return InteractiveTurn.fromJson({
    'type': 'interactive_turn.v1',
    'session_id': 'session-1',
    'turn_id': 'aspect-failure-turn-$seq',
    'seq': seq,
    'speaker': {'type': 'ai', 'role': 'host'},
    'blocks': [
      {
        'kind': 'text',
        'text': 'Type the aspect you want, or try the suggestions again.',
      },
      {
        'kind': 'choice_group',
        'prompt': '',
        'options': [
          {'id': 'retry_aspects', 'label': 'Try suggestions again'},
        ],
        'metadata': {
          'choice_kind': 'solo_topic_path_actions',
          'topic_path': const ['History'],
          'depth': 0,
          'revision': 1,
          'allow_custom_aspect': true,
          'topic_path_actions_expanded': false,
        },
      },
    ],
    'state_patch': {
      'phase': 'topic_selection',
      'topic_selection_stage': 'aspect',
      'topic_aspect_status': 'failed',
      'topic_aspect_revision': 1,
      'topic_path': const ['History'],
      'topic_drilldown_depth': 0,
      'allow_custom_aspect': true,
      'topic_path_actions_expanded': false,
      'pending_topic_aspects': const [],
    },
  });
}

InteractiveSessionState _aspectSuggestionSession() {
  final turn = _aspectSuggestionTurn(seq: 3);
  return InteractiveSessionState(
    sessionId: 'session-1',
    storyId: 'story-1',
    interactionMode: 'interactive',
    aiRole: 'host',
    interactiveState: const {
      'template': 'quiz',
      'session_type': 'solo',
      'phase': 'topic_selection',
      'topic_selection_stage': 'aspect',
      'topic_path': ['History'],
      'pending_topic_aspects': _pageAspectSuggestions,
      'topic_aspect_status': 'ready',
      'topic_drilldown_depth': 0,
      'topic_aspect_revision': 1,
      'allow_custom_aspect': true,
      'topic_path_actions_expanded': false,
    },
    currentTurn: turn,
    lastSeq: turn.seq,
  );
}

InteractiveSessionState _aspectActionsSession() {
  final turn = _aspectActionsTurn(seq: 5);
  return InteractiveSessionState(
    sessionId: 'session-1',
    storyId: 'story-1',
    interactionMode: 'interactive',
    aiRole: 'host',
    interactiveState: const {
      'template': 'quiz',
      'session_type': 'solo',
      'phase': 'topic_selection',
      'topic_selection_stage': 'aspect',
      'topic_path': ['History', 'Ancient history'],
      'pending_topic_aspects': [],
      'topic_aspect_status': 'selected',
      'topic_drilldown_depth': 1,
      'topic_aspect_revision': 2,
      'allow_custom_aspect': true,
      'topic_path_actions_expanded': false,
    },
    currentTurn: turn,
    lastSeq: turn.seq,
  );
}

InteractiveSessionState _rootExpandedActionsSession() {
  final turn = _rootExpandedActionsTurn(seq: 5);
  return InteractiveSessionState(
    sessionId: 'session-1',
    storyId: 'story-1',
    interactionMode: 'interactive',
    aiRole: 'host',
    interactiveState: const {
      'template': 'quiz',
      'session_type': 'solo',
      'phase': 'topic_selection',
      'topic_selection_stage': 'aspect',
      'topic_path': ['History'],
      'pending_topic_aspects': _pageAspectSuggestions,
      'topic_aspect_status': 'ready',
      'topic_drilldown_depth': 0,
      'topic_aspect_revision': 1,
      'allow_custom_aspect': false,
      'topic_path_actions_expanded': true,
    },
    currentTurn: turn,
    lastSeq: turn.seq,
  );
}

InteractiveSessionState _aspectFailureSession() {
  final turn = _aspectFailureTurn(seq: 3);
  return InteractiveSessionState(
    sessionId: 'session-1',
    storyId: 'story-1',
    interactionMode: 'interactive',
    aiRole: 'host',
    interactiveState: const {
      'template': 'quiz',
      'session_type': 'solo',
      'phase': 'topic_selection',
      'topic_selection_stage': 'aspect',
      'topic_path': ['History'],
      'pending_topic_aspects': [],
      'topic_aspect_status': 'failed',
      'topic_drilldown_depth': 0,
      'topic_aspect_revision': 1,
      'allow_custom_aspect': true,
      'topic_path_actions_expanded': false,
    },
    currentTurn: turn,
    lastSeq: turn.seq,
  );
}

InteractiveSessionState _aspectMaxDepthSession() {
  return const InteractiveSessionState(
    sessionId: 'session-1',
    storyId: 'story-1',
    interactionMode: 'interactive',
    aiRole: 'host',
    interactiveState: {
      'template': 'quiz',
      'session_type': 'solo',
      'phase': 'topic_selection',
      'topic_selection_stage': 'aspect',
      'topic_path': [
        'History',
        'Ancient history',
        'Ancient Egypt',
        'Old Kingdom',
        'Royal power',
        'Women rulers',
      ],
      'pending_topic_aspects': [],
      'topic_aspect_status': 'max_depth',
      'topic_drilldown_depth': 5,
      'topic_aspect_revision': 'max-depth-revision',
      'allow_custom_aspect': true,
      'topic_path_actions_expanded': false,
    },
    lastSeq: 7,
  );
}

InteractiveSessionState _modeSession() {
  return InteractiveSessionState(
    sessionId: 'session-1',
    storyId: 'story-1',
    interactionMode: 'interactive',
    aiRole: 'host',
    interactiveState: const {
      'template': 'quiz',
      'session_type': 'solo',
      'phase': 'mode_selection',
      'selected_topic': 'History',
    },
    currentTurn: _modeTurn(),
    lastSeq: 2,
  );
}

InteractiveSessionState _timerSession() {
  return InteractiveSessionState(
    sessionId: 'session-1',
    storyId: 'story-1',
    interactionMode: 'interactive',
    aiRole: 'host',
    interactiveState: const {
      'template': 'quiz',
      'session_type': 'solo',
      'phase': 'timer_selection',
      'selected_topic': 'History',
    },
    currentTurn: _timerTurn(),
    lastSeq: 4,
  );
}

InteractiveSessionState _activeSoloQuizSession() {
  return InteractiveSessionState(
    sessionId: 'active-solo-session',
    storyId: 'story-1',
    interactionMode: 'interactive',
    aiRole: 'host',
    interactiveState: const {
      'template': 'quiz',
      'session_type': 'solo',
      'phase': 'question_active',
      'selected_topic': 'History',
      'quiz_setup_complete': true,
      'quiz_timer_enabled': true,
      'current_round': 1,
      'total_rounds': 3,
      'current_question_id': 'active-question',
      'expires_at': '2099-01-01T00:00:00Z',
      'question': {
        'question_id': 'active-question',
        'text': 'Who built the first known cities?',
        'expires_at': '2099-01-01T00:00:00Z',
        'options': [
          {'id': 'a', 'label': 'Sumerians'},
          {'id': 'b', 'label': 'Romans'},
        ],
      },
    },
    lastSeq: 5,
  );
}

InteractiveSessionState _postQuestionSession() {
  return InteractiveSessionState(
    sessionId: 'post-question-session',
    storyId: 'story-1',
    interactionMode: 'interactive',
    aiRole: 'host',
    interactiveState: const {
      'template': 'quiz',
      'session_type': 'solo',
      'phase': 'post_question_prompt',
      'selected_topic': 'History',
      'quiz_setup_complete': true,
      'quiz_timer_enabled': false,
      'current_round': 1,
      'total_rounds': 3,
      'current_question_id': 'completed-question',
      'question': {
        'question_id': 'completed-question',
        'text': 'Which civilization built Ur?',
        'options': [
          {'id': 'a', 'label': 'Sumerians'},
          {'id': 'b', 'label': 'Romans'},
        ],
      },
      'result': {
        'question_id': 'completed-question',
        'correct_option_id': 'a',
        'answers': [],
      },
    },
    lastSeq: 8,
  );
}

final _storyDetail = StoryDetailDto(
  id: 'story-1',
  categoryId: 'category-1',
  title: 'Quiz story',
  description: '',
  author: '',
  ageRating: 0,
  tags: const [],
  durationMinutes: 5,
  difficulty: 'easy',
  isPremium: false,
  price: 0,
  isPublished: true,
  publishedAt: null,
  createdByAdminId: 'admin-1',
  createdAt: null,
  updatedAt: null,
  tree: const {},
  previewNodeIds: const [],
  interactionMode: 'group',
  interactiveConfig: const {'template': 'quiz'},
);

class _QuizStoriesRepository extends StoriesRepository {
  _QuizStoriesRepository({
    required this.session,
    this.retrySession,
    this.retryError,
    this.conflictSession,
    this.restartSession,
    this.history = const <SoloInteractiveSessionSummary>[],
    this.advanceDelay,
    this.submitDelay,
    this.startDelay,
  }) : super(dio: Dio());

  InteractiveSessionState session;
  final InteractiveSessionState? retrySession;
  final ApiError? retryError;
  final InteractiveSessionState? conflictSession;
  final InteractiveSessionState? restartSession;
  final List<SoloInteractiveSessionSummary> history;
  final Future<void>? advanceDelay;
  final Future<void>? submitDelay;
  final Future<void>? startDelay;
  int fetchCalls = 0;
  int retryCalls = 0;
  int startCalls = 0;
  int resumeCalls = 0;
  int leaveCalls = 0;
  int soloHistoryCalls = 0;
  int advanceCalls = 0;
  final List<InteractiveInput> submittedInputs = [];

  @override
  Future<InteractiveSessionState> startInteractiveSession({
    required String storyId,
    String deviceType = 'mobile',
    String? deviceId,
    String? sessionType,
    String? roomType,
    String? hostDisplayName,
    int? maxParticipants,
    bool startFresh = false,
  }) async {
    startCalls += 1;
    if (startDelay != null) await startDelay;
    if (startCalls > 1 && restartSession != null) {
      session = restartSession!;
    }
    return session;
  }

  @override
  Future<List<SoloInteractiveSessionSummary>> fetchSoloInteractiveHistory({
    String? storyId,
    int limit = 20,
  }) async {
    soloHistoryCalls += 1;
    return history;
  }

  @override
  Future<InteractiveSessionState> resumeInteractiveSession(
    String sessionId,
  ) async {
    resumeCalls += 1;
    return session;
  }

  @override
  Future<void> leaveInteractiveSession(String sessionId) async {
    leaveCalls += 1;
  }

  @override
  Future<InteractiveSessionState> fetchInteractiveSession(
    String sessionId,
  ) async {
    fetchCalls += 1;
    return session;
  }

  @override
  Future<InteractiveSessionState> retryInteractiveQuizGeneration(
    String sessionId,
  ) async {
    retryCalls += 1;
    if (retryError != null) {
      session = conflictSession ?? session;
      throw retryError!;
    }
    session = retrySession ?? session;
    return session;
  }

  @override
  Future<InteractiveSessionState> advanceInteractiveSession(
    String sessionId,
  ) async {
    advanceCalls += 1;
    if (advanceDelay != null) await advanceDelay;
    final currentRound =
        (session.interactiveState['current_round'] as num?)?.toInt() ?? 1;
    final totalRounds =
        (session.interactiveState['total_rounds'] as num?)?.toInt() ?? 1;
    final nextState = <String, dynamic>{
      ...session.interactiveState,
      'phase': currentRound >= totalRounds
          ? 'completed'
          : 'generating_question',
      if (currentRound < totalRounds) 'current_round': currentRound + 1,
    };
    session = session.copyWith(
      interactiveState: nextState,
      isCompleted: currentRound >= totalRounds,
    );
    return session;
  }

  @override
  Future<InteractiveInputResponse> submitInteractiveInput({
    required String sessionId,
    required InteractiveInput input,
  }) async {
    submittedInputs.add(input);
    if (submitDelay != null) await submitDelay;
    final currentPhase = session.interactiveState['phase'];
    if (input.inputType == 'player_chat') {
      final event = StorySessionEvent(
        id: 'player-chat-event-${session.lastSeq + 1}',
        sessionId: sessionId,
        seq: session.lastSeq + 1,
        actorType: 'user',
        eventType: 'player_chat',
        payload: {'text': input.text, 'phase': currentPhase},
      );
      session = session.copyWith(
        events: [...session.events, event],
        lastSeq: event.seq,
      );
      return InteractiveInputResponse(
        status: 'accepted',
        event: event,
        state: session.interactiveState,
      );
    }
    if (currentPhase == 'topic_selection') {
      final stage = session.interactiveState['topic_selection_stage'];
      final seq = session.lastSeq + 1;
      if (stage != 'aspect') {
        final candidateId = input.optionId?.trim() ?? '';
        final typedTopic = input.text?.trim() ?? '';
        final candidateLabel = typedTopic.isNotEmpty
            ? typedTopic
            : _labelForOption(_pageTopicSuggestions, candidateId);
        final event = StorySessionEvent(
          id: 'topic-candidate-event-$seq',
          sessionId: sessionId,
          seq: seq,
          actorType: 'user',
          eventType: 'topic_candidate_selected',
          payload: {
            if (candidateId.isNotEmpty) 'option_id': candidateId,
            'topic': candidateLabel,
            'display_text': candidateLabel,
            'topic_path': [candidateLabel],
            'depth': 0,
          },
        );
        final nextState = <String, dynamic>{
          ...session.interactiveState,
          'topic_selection_stage': 'aspect',
          'topic_path': [candidateLabel],
          'pending_topic_aspects': _pageAspectSuggestions,
          'topic_aspect_status': 'ready',
          'topic_drilldown_depth': 0,
          'topic_aspect_revision': 1,
          'allow_custom_aspect': true,
          'topic_path_actions_expanded': false,
        };
        final turn = _aspectSuggestionTurn(
          seq: seq + 1,
          topicPath: [candidateLabel],
        );
        session = session.copyWith(
          interactiveState: nextState,
          events: [...session.events, event],
          currentTurn: turn,
          lastSeq: turn.seq,
        );
        return InteractiveInputResponse(
          status: 'accepted',
          event: event,
          turn: turn,
          state: nextState,
        );
      }

      final optionId = input.optionId?.trim().toLowerCase() ?? '';
      if (optionId == 'continue_with_topic') {
        final path =
            ((session.interactiveState['topic_path'] as List?) ?? const [])
                .map((part) => part.toString())
                .where((part) => part.trim().isNotEmpty)
                .toList();
        final revision =
            (session.interactiveState['topic_aspect_revision'] as num?)
                ?.toInt() ??
            1;
        final event = StorySessionEvent(
          id: 'root-topic-action-event-$seq',
          sessionId: sessionId,
          seq: seq,
          actorType: 'user',
          eventType: 'topic_aspect_selected',
          payload: {
            'action': optionId,
            'option_id': optionId,
            'display_text': "Let's keep ${path.first} broad.",
            'topic_path': path,
            'depth': path.length - 1,
            'topic_path_actions_expanded': true,
            'allow_custom_aspect': false,
            'pending_topic_aspects': _pageAspectSuggestions,
            'topic_aspect_status': 'ready',
            'topic_aspect_revision': revision,
          },
        );
        final nextState = <String, dynamic>{
          ...session.interactiveState,
          'topic_path_actions_expanded': true,
          'allow_custom_aspect': false,
          'pending_topic_aspects': _pageAspectSuggestions,
          'topic_aspect_status': 'ready',
        };
        final turn = _rootExpandedActionsTurn(
          seq: seq + 1,
          revision: revision,
          topicPath: path,
        );
        session = session.copyWith(
          interactiveState: nextState,
          events: [...session.events, event],
          currentTurn: turn,
          lastSeq: turn.seq,
        );
        return InteractiveInputResponse(
          status: 'accepted',
          event: event,
          turn: turn,
          state: nextState,
        );
      }

      if (optionId == 'quiz' || optionId == 'chat') {
        final path =
            ((session.interactiveState['topic_path'] as List?) ?? const [])
                .map((part) => part.toString())
                .where((part) => part.trim().isNotEmpty)
                .toList();
        final selectedTopic = path.last;
        final nextPhase = optionId == 'quiz' ? 'timer_selection' : 'discussion';
        final displayText = optionId == 'quiz'
            ? 'Take me to quiz'
            : 'Chat with Aura';
        final event = StorySessionEvent(
          id: 'topic-selected-event-$seq',
          sessionId: sessionId,
          seq: seq,
          actorType: 'user',
          eventType: 'topic_selected',
          payload: {
            'action': optionId,
            'option_id': optionId,
            'display_text': displayText,
            'topic': selectedTopic,
            'topic_path': path,
          },
        );
        final nextState = <String, dynamic>{
          ...session.interactiveState,
          'phase': nextPhase,
          'selected_topic': selectedTopic,
          'selected_topic_path': path,
        };
        for (final key in const [
          'topic_selection_stage',
          'topic_path',
          'topic_drilldown_depth',
          'topic_aspect_revision',
          'topic_aspect_status',
          'allow_custom_aspect',
          'topic_path_actions_expanded',
          'pending_topic_aspects',
        ]) {
          nextState.remove(key);
        }
        final turn = optionId == 'quiz'
            ? _timerTurn(seq: seq + 1)
            : InteractiveTurn.fromJson({
                'type': 'interactive_turn.v1',
                'session_id': sessionId,
                'turn_id': 'guided-chat-turn-${seq + 1}',
                'seq': seq + 1,
                'speaker': {'type': 'ai', 'role': 'host'},
                'blocks': [
                  {'kind': 'text', 'text': 'Let us explore that path.'},
                ],
                'state_patch': {'phase': 'discussion'},
              });
        session = session.copyWith(
          interactiveState: nextState,
          events: [...session.events, event],
          currentTurn: turn,
          lastSeq: turn.seq,
        );
        return InteractiveInputResponse(
          status: 'accepted',
          event: event,
          turn: turn,
          state: nextState,
        );
      }

      if (optionId == 'change_aspect' || optionId == 'retry_aspects') {
        final currentPath =
            ((session.interactiveState['topic_path'] as List?) ?? const [])
                .map((part) => part.toString())
                .where((part) => part.trim().isNotEmpty)
                .toList();
        final nextPath = optionId == 'change_aspect' && currentPath.length > 1
            ? currentPath.sublist(0, currentPath.length - 1)
            : currentPath;
        final revision =
            ((session.interactiveState['topic_aspect_revision'] as num?)
                    ?.toInt() ??
                0) +
            1;
        final event = StorySessionEvent(
          id: 'aspect-retry-event-$seq',
          sessionId: sessionId,
          seq: seq,
          actorType: 'user',
          eventType: 'topic_aspect_selected',
          payload: {
            'action': optionId,
            'option_id': optionId,
            'display_text': optionId == 'change_aspect'
                ? 'Choose another aspect'
                : 'Try suggestions again',
            'topic_path': nextPath,
            'depth': nextPath.length - 1,
          },
        );
        final nextState = <String, dynamic>{
          ...session.interactiveState,
          'topic_path': nextPath,
          'pending_topic_aspects': _pageAspectSuggestions,
          'topic_aspect_status': 'ready',
          'topic_drilldown_depth': nextPath.length - 1,
          'topic_aspect_revision': revision,
          'topic_path_actions_expanded': false,
        };
        final turn = _aspectSuggestionTurn(
          seq: seq + 1,
          revision: revision,
          topicPath: nextPath,
        );
        session = session.copyWith(
          interactiveState: nextState,
          events: [...session.events, event],
          currentTurn: turn,
          lastSeq: turn.seq,
        );
        return InteractiveInputResponse(
          status: 'accepted',
          event: event,
          turn: turn,
          state: nextState,
        );
      }

      final typedAspect = input.text?.trim() ?? '';
      final aspectLabel = typedAspect.isNotEmpty
          ? typedAspect
          : _labelForOption(_pageAspectSuggestions, optionId);
      final previousPath =
          ((session.interactiveState['topic_path'] as List?) ?? const [])
              .map((part) => part.toString())
              .where((part) => part.trim().isNotEmpty)
              .toList();
      final nextPath = [...previousPath, aspectLabel];
      final revision =
          ((session.interactiveState['topic_aspect_revision'] as num?)
                  ?.toInt() ??
              0) +
          1;
      final event = StorySessionEvent(
        id: 'topic-aspect-event-$seq',
        sessionId: sessionId,
        seq: seq,
        actorType: 'user',
        eventType: 'topic_aspect_selected',
        payload: {
          'action': optionId.isNotEmpty ? 'select_aspect' : 'custom_aspect',
          'option_id': optionId.isNotEmpty ? optionId : null,
          'aspect': aspectLabel,
          'display_text': aspectLabel,
          'topic_path': nextPath,
          'depth': nextPath.length - 1,
        },
      );
      final nextState = <String, dynamic>{
        ...session.interactiveState,
        'topic_path': nextPath,
        'pending_topic_aspects': const <dynamic>[],
        'topic_aspect_status': 'selected',
        'topic_drilldown_depth': nextPath.length - 1,
        'topic_aspect_revision': revision,
        'topic_path_actions_expanded': false,
      };
      final turn = _aspectActionsTurn(
        seq: seq + 1,
        revision: revision,
        topicPath: nextPath,
      );
      session = session.copyWith(
        interactiveState: nextState,
        events: [...session.events, event],
        currentTurn: turn,
        lastSeq: turn.seq,
      );
      return InteractiveInputResponse(
        status: 'accepted',
        event: event,
        turn: turn,
        state: nextState,
      );
    }
    if (input.inputType == 'solo_chat') {
      final event = StorySessionEvent(
        id: 'solo-chat-event-${session.lastSeq + 1}',
        sessionId: sessionId,
        seq: session.lastSeq + 1,
        actorType: 'user',
        eventType: 'solo_user_message',
        payload: {'text': input.text, 'phase': currentPhase, 'mode': 'chat'},
      );
      final turn = InteractiveTurn.fromJson({
        'type': 'interactive_turn.v1',
        'session_id': sessionId,
        'turn_id': 'solo-chat-turn-${event.seq + 1}',
        'seq': event.seq + 1,
        'speaker': {'type': 'ai', 'role': 'host'},
        'blocks': [
          {'kind': 'text', 'text': 'Aura reply to: ${input.text}'},
        ],
      });
      session = session.copyWith(
        events: [...session.events, event],
        currentTurn: turn,
        lastSeq: turn.seq,
      );
      return InteractiveInputResponse(
        status: 'accepted',
        event: event,
        turn: turn,
        state: session.interactiveState,
      );
    }
    if (currentPhase == 'post_question_prompt' &&
        input.optionId == 'continue_topic') {
      final event = StorySessionEvent(
        id: 'continue-topic-event',
        sessionId: sessionId,
        seq: session.lastSeq + 1,
        actorType: 'user',
        eventType: 'solo_user_message',
        payload: {'text': 'continue_topic', 'phase': currentPhase},
      );
      final nextState = <String, dynamic>{
        ...session.interactiveState,
        'phase': 'generating_question',
        'current_round':
            ((session.interactiveState['current_round'] as num?)?.toInt() ??
                1) +
            1,
      };
      session = session.copyWith(
        interactiveState: nextState,
        events: [...session.events, event],
        lastSeq: event.seq,
      );
      return InteractiveInputResponse(
        status: 'accepted',
        event: event,
        state: nextState,
      );
    }
    if ((currentPhase == 'mode_selection' || currentPhase == 'discussion') &&
        input.optionId != null) {
      final optionId = input.optionId!.trim().toLowerCase();
      final event = StorySessionEvent(
        id: 'mode-selected-event',
        sessionId: sessionId,
        seq: session.lastSeq + 1,
        actorType: 'user',
        eventType: 'solo_user_message',
        payload: {'text': optionId, 'phase': currentPhase},
      );
      final nextState = <String, dynamic>{
        ...session.interactiveState,
        'phase': optionId == 'chat' ? 'discussion' : 'timer_selection',
      };
      final timerTurn = optionId == 'chat'
          ? null
          : _timerTurn(seq: event.seq + 1);
      session = session.copyWith(
        interactiveState: nextState,
        events: [...session.events, event],
        currentTurn: timerTurn,
        lastSeq: timerTurn?.seq ?? event.seq,
      );
      return InteractiveInputResponse(
        status: 'accepted',
        event: event,
        turn: timerTurn,
        state: nextState,
      );
    }
    if (currentPhase == 'timer_selection' && input.optionId != null) {
      final optionId = input.optionId!.trim().toLowerCase();
      final event = StorySessionEvent(
        id: 'timer-selected-event',
        sessionId: sessionId,
        seq: session.lastSeq + 1,
        actorType: 'user',
        eventType: 'solo_user_message',
        payload: {'text': optionId, 'phase': 'timer_selection'},
      );
      final nextState = <String, dynamic>{
        ...session.interactiveState,
        'phase': 'generating_question',
        'quiz_timer_enabled': optionId == 'timed',
        'quiz_setup_complete': true,
      };
      session = session.copyWith(
        interactiveState: nextState,
        events: [...session.events, event],
        lastSeq: event.seq,
      );
      return InteractiveInputResponse(
        status: 'accepted',
        event: event,
        state: nextState,
      );
    }
    final topic = input.text?.trim() ?? '';
    final event = StorySessionEvent(
      id: 'topic-selected-event',
      sessionId: sessionId,
      seq: session.lastSeq + 1,
      actorType: 'user',
      eventType: 'topic_selected',
      payload: {'topic': topic},
    );
    final nextState = <String, dynamic>{
      ...session.interactiveState,
      'phase': 'mode_selection',
      'selected_topic': topic,
    };
    final modeTurn = _modeTurn(seq: event.seq + 1);
    session = session.copyWith(
      interactiveState: nextState,
      events: [...session.events, event],
      currentTurn: modeTurn,
      lastSeq: modeTurn.seq,
    );
    return InteractiveInputResponse(
      status: 'accepted',
      event: event,
      turn: modeTurn,
      state: nextState,
    );
  }
}

class _DelayedQuizStoriesRepository extends _QuizStoriesRepository {
  _DelayedQuizStoriesRepository({required super.session});

  final Completer<void> _submitGate = Completer<void>();

  void releaseSubmit() {
    if (!_submitGate.isCompleted) _submitGate.complete();
  }

  @override
  Future<InteractiveInputResponse> submitInteractiveInput({
    required String sessionId,
    required InteractiveInput input,
  }) async {
    await _submitGate.future;
    return super.submitInteractiveInput(sessionId: sessionId, input: input);
  }
}

String _labelForOption(List<Map<String, dynamic>> options, String optionId) {
  final normalizedId = optionId.trim().toLowerCase();
  for (final option in options) {
    if (option['id']?.toString().trim().toLowerCase() == normalizedId) {
      return option['label']?.toString().trim() ?? optionId;
    }
  }
  return optionId;
}

class _TestAuthController extends AuthController {
  _TestAuthController(this.userId);

  final String userId;

  @override
  Future<AuthUser?> build() async => AuthUser(
    id: userId,
    email: '$userId@example.com',
    emailVerificationRequired: false,
  );
}

class _TestVoiceController extends VoiceChatController {
  _TestVoiceController()
    : super(
        client: RealtimeVoiceClient(),
        player: _NoopAudioPlayer(),
        voiceUriOverride: Uri.parse('wss://example.com/ws/realtime/voice'),
      );

  @override
  VoiceChatState build() => const VoiceChatState(isMuted: true);

  @override
  Future<void> stopPlayback({bool restartListening = false}) async {}

  @override
  Future<void> ensureStorySessionConnected(
    String storyId, {
    String? preferredSessionId,
  }) async {}

  @override
  Future<void> endStorySession() async {}
}

class _NoopAudioPlayer implements AudioChunkPlayer {
  @override
  Future<void> addChunk(
    Uint8List bytes, {
    int sampleRate = 16000,
    int bufferSize = 4096,
    bool interleaved = true,
    VoidCallback? onFinished,
  }) async {}

  @override
  Future<void> dispose() async {}

  @override
  Future<void> stop() async {}
}
