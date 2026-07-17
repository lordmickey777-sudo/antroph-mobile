import 'package:antroph_mobile/features/home/models/chat_models.dart';
import 'package:antroph_mobile/features/home/widgets/chat_bubble.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('empty streaming assistant bubble shows the supplied status', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatBubble(
            message: ChatMessageModel(
              id: 'assistant-loading',
              role: ChatRole.assistant,
              message: '',
              ts: DateTime(2026, 7, 16),
              streaming: true,
            ),
            onRetry: () {},
            maxWidth: 320,
          ),
        ),
      ),
    );

    expect(find.text('Thinking…'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 2500));

    expect(find.text('Thinking…'), findsOneWidget);
    expect(find.text('Processing…'), findsNothing);
  });

  testWidgets('streaming status uses a handwriting reveal', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatBubble(
            message: ChatMessageModel(
              id: 'assistant-loading',
              role: ChatRole.assistant,
              message: '',
              ts: DateTime(2026, 7, 16),
              streaming: true,
            ),
            onRetry: () {},
            maxWidth: 320,
          ),
        ),
      ),
    );

    final visibleLettersAtStart = find.descendant(
      of: find.byType(ClipRect),
      matching: find.text('Thinking...'),
    );
    expect(visibleLettersAtStart, findsOneWidget);

    await tester.pump(const Duration(milliseconds: 900));

    expect(find.text('Thinking…'), findsOneWidget);
  });

  testWidgets('streaming status bubble keeps a stable width', (tester) async {
    const bubbleKey = ValueKey('loading-bubble');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatBubble(
            key: bubbleKey,
            message: ChatMessageModel(
              id: 'assistant-loading',
              role: ChatRole.assistant,
              message: '',
              ts: DateTime(2026, 7, 16),
              streaming: true,
            ),
            onRetry: () {},
            maxWidth: 320,
          ),
        ),
      ),
    );

    final initialWidth = tester.getSize(find.byKey(bubbleKey)).width;

    await tester.pump(const Duration(milliseconds: 2500));
    final processingWidth = tester.getSize(find.byKey(bubbleKey)).width;

    expect(processingWidth, initialWidth);
  });

  testWidgets('streaming assistant bubble can use a custom status label', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatBubble(
            message: ChatMessageModel(
              id: 'assistant-connecting',
              role: ChatRole.assistant,
              message: '',
              ts: DateTime(2026, 7, 16),
              streaming: true,
            ),
            onRetry: () {},
            maxWidth: 320,
            loadingLabel: 'Connecting…',
          ),
        ),
      ),
    );

    expect(find.text('Connecting…'), findsOneWidget);
    expect(find.text('Thinking…'), findsNothing);

    await tester.pump(const Duration(milliseconds: 2500));

    expect(find.text('Connecting…'), findsOneWidget);
    expect(find.text('Preparing…'), findsNothing);
  });
}
