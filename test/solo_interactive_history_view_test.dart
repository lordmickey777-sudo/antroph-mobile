import 'package:antroph_mobile/features/story/models/interactive_story_models.dart';
import 'package:antroph_mobile/features/story/presentation/solo_interactive_history_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  SoloInteractiveSessionSummary summary({
    String id = 'session-1',
    bool completed = false,
    bool paused = true,
    int round = 2,
  }) {
    final now = DateTime.utc(2026, 7, 11, 12);
    return SoloInteractiveSessionSummary(
      sessionId: id,
      storyId: 'story-1',
      storyTitle: 'Solo interactivity',
      isCompleted: completed,
      isPaused: paused,
      topicPath: const ['History', 'Ancient history', 'Egypt'],
      viewMode: 'quiz',
      currentRound: round,
      score: 1,
      lastActivityAt: now,
      createdAt: now.subtract(const Duration(days: 1)),
      completedAt: completed ? now : null,
      preview: 'Exploring how the Old Kingdom shaped Egyptian history.',
    );
  }

  Future<void> setCompactPhone(WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('launcher remains usable on a narrow phone with large text', (
    tester,
  ) async {
    await setCompactPhone(tester);
    var continued = false;
    var startedFresh = false;
    var openedHistory = false;

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 640),
            textScaler: TextScaler.linear(1.5),
          ),
          child: Scaffold(
            backgroundColor: Colors.black,
            body: SoloInteractiveSessionLauncher(
              latestSession: summary(),
              hasHistory: true,
              isBusy: false,
              onContinue: () => continued = true,
              onStartFresh: () => startedFresh = true,
              onViewHistory: () => openedHistory = true,
              onRetry: () {},
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('continue-solo-session')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('start-fresh-solo-session')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('view-solo-history')), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const ValueKey('continue-solo-session')),
    );
    await tester.tap(find.byKey(const ValueKey('continue-solo-session')));
    await tester.pump();
    expect(continued, isTrue);
    expect(startedFresh, isFalse);
    expect(openedHistory, isFalse);
  });

  testWidgets('history list distinguishes resumable and completed sessions', (
    tester,
  ) async {
    await setCompactPhone(tester);
    SoloInteractiveSessionSummary? selected;
    final sessions = <SoloInteractiveSessionSummary>[
      summary(),
      summary(id: 'session-2', completed: true, paused: false, round: 5),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.black,
          body: SoloInteractiveSessionHistoryView(
            sessions: sessions,
            isBusy: false,
            onBack: () {},
            onSelect: (value) => selected = value,
            onStartFresh: () {},
            onRetry: () {},
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Paused'), findsOneWidget);
    expect(find.text('Completed'), findsOneWidget);
    expect(find.byKey(const ValueKey('solo-history-list')), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('solo-history-session-session-2')),
    );
    await tester.pump();
    expect(selected?.sessionId, 'session-2');
  });

  testWidgets('read-only history banner is compact', (tester) async {
    await setCompactPhone(tester);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.black,
          body: Column(children: [SoloHistoryReadOnlyBanner()]),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Recent transcript · Read only'), findsOneWidget);
  });

  testWidgets('history scrolls on a short screen with accessibility text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 240);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 240),
            textScaler: TextScaler.linear(2),
          ),
          child: Scaffold(
            backgroundColor: Colors.black,
            body: SoloInteractiveSessionHistoryView(
              sessions: [
                summary(),
                summary(id: 'session-2'),
              ],
              isBusy: false,
              onBack: () {},
              onSelect: (_) {},
              onStartFresh: () {},
              onRetry: () {},
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('solo-history-list')), findsOneWidget);
    await tester.drag(
      find.byKey(const ValueKey('solo-history-list')),
      const Offset(0, -120),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
