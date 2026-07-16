import 'dart:typed_data';

import 'package:antroph_mobile/features/home/models/realtime_voice_bridge_models.dart';
import 'package:antroph_mobile/features/home/presentation/voice_chat_screen.dart';
import 'package:antroph_mobile/features/home/providers/voice_chat_provider.dart';
import 'package:antroph_mobile/features/home/services/pcm_audio_player.dart';
import 'package:antroph_mobile/features/home/services/realtime_voice_client.dart';
import 'package:antroph_mobile/features/home/widgets/chat_bubble.dart';
import 'package:antroph_mobile/features/story/data/stories_repository.dart';
import 'package:antroph_mobile/features/story/models/story_session.dart';
import 'package:antroph_mobile/features/story/presentation/story_chat_flow_page.dart';
import 'package:antroph_mobile/features/story/presentation/story_voice_page.dart';
import 'package:antroph_mobile/features/story/providers/story_providers.dart';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('StoryChatFlowPage starts in chat and opens voice page', (
    tester,
  ) async {
    final fake = FakeVoiceChatController();
    final storiesRepository = _FakeStoriesRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          voiceChatControllerProvider.overrideWith(() => fake),
          storiesRepositoryProvider.overrideWithValue(storiesRepository),
        ],
        child: MaterialApp(
          home: StoryChatFlowPage(
            storyId: 'story_1',
            storyTitle: 'Test Story',
            initialInteractionMode: 'narrative',
            voicePageBuilder: _testVoicePageBuilder,
          ),
        ),
      ),
    );

    // Let initState post-frame run.
    await tester.pump();

    expect(find.byType(TextField), findsOneWidget);
    expect(find.byIcon(Icons.call_rounded), findsOneWidget);

    expect(fake.startStorySessionCalls, 0);
    expect(fake.stopPlaybackCalls, greaterThanOrEqualTo(1));
    expect(fake.state.isMuted, isTrue);

    // Voice UI should not build in chat page.
    expect(find.byType(VoiceChatScreen), findsNothing);

    await tester.tap(find.byIcon(Icons.call_rounded));
    await tester.pump(); // start route transition
    await tester.pump(const Duration(milliseconds: 500)); // finish transition

    expect(find.byType(VoiceChatScreen), findsOneWidget);
    expect(fake.startStorySessionCalls, greaterThanOrEqualTo(1));
    expect(fake.toggleMuteCalls, greaterThanOrEqualTo(2));
    expect(fake.startRecordingCalls, 1);
  });

  testWidgets('StoryChatFlowPage shows Aura bubble immediately after send', (
    tester,
  ) async {
    final fake = FakeVoiceChatController();
    final storiesRepository = _FakeStoriesRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          voiceChatControllerProvider.overrideWith(() => fake),
          storiesRepositoryProvider.overrideWithValue(storiesRepository),
        ],
        child: MaterialApp(
          home: StoryChatFlowPage(
            storyId: 'story_1',
            storyTitle: 'Test Story',
            initialInteractionMode: 'narrative',
            voicePageBuilder: _testVoicePageBuilder,
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'Tell me more');
    await tester.pump();
    await tester.tap(find.byIcon(CupertinoIcons.paperplane_fill));
    await tester.pump();

    expect(find.text('Tell me more'), findsOneWidget);
    expect(find.byType(ChatBubble), findsNWidgets(2));
    expect(storiesRepository.streamCalls, 1);
    expect(fake.sendTextPromptCalls, 0);
  });

  testWidgets('voice turns are appended to the text chat after voice closes', (
    tester,
  ) async {
    final fake = FakeVoiceChatController();
    final storiesRepository = _FakeStoriesRepository(
      conversation: const [
        {'speaker': 'assistant', 'message': 'Welcome to the story.'},
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          voiceChatControllerProvider.overrideWith(() => fake),
          storiesRepositoryProvider.overrideWithValue(storiesRepository),
        ],
        child: MaterialApp(
          home: StoryChatFlowPage(
            storyId: 'story_1',
            storyTitle: 'Test Story',
            initialInteractionMode: 'narrative',
            voicePageBuilder: (context) => Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () {
                    storiesRepository.conversation = const [
                      {
                        'speaker': 'assistant',
                        'message': 'Welcome to the story.',
                      },
                      {'speaker': 'user', 'message': 'Tell me about the path.'},
                      {
                        'speaker': 'ai',
                        'message': 'The path leads toward the old forest.',
                      },
                    ];
                    Navigator.of(context).pop();
                  },
                  child: const Text('Return to chat'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Welcome to the story.'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.call_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Return to chat'));
    await tester.pumpAndSettle();

    expect(find.text('Tell me about the path.'), findsOneWidget);
    expect(find.text('The path leads toward the old forest.'), findsOneWidget);
    expect(storiesRepository.fetchConversationCalls, greaterThanOrEqualTo(2));
  });

  testWidgets('active story session opens at latest message', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final fake = FakeVoiceChatController();
    final storiesRepository = _FakeStoriesRepository(
      conversation: const [
        {
          'speaker': 'assistant',
          'message':
              'Lila stepped into the park while the morning was still quiet.',
        },
        {
          'speaker': 'user',
          'message': 'She keeps walking until the trees thin out.',
        },
        {
          'speaker': 'assistant',
          'message':
              'The path bent toward a pond where the light trembled across the surface.',
        },
        {'speaker': 'user', 'message': 'She pauses there for a while.'},
        {
          'speaker': 'assistant',
          'message':
              'The silence gave her enough room to notice how tired her thoughts had become.',
        },
        {'speaker': 'user', 'message': 'What does she understand?'},
        {
          'speaker': 'assistant',
          'message':
              'She realizes that peace does not arrive all at once. It returns in small moments when she stops chasing every worry.',
        },
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          voiceChatControllerProvider.overrideWith(() => fake),
          storiesRepositoryProvider.overrideWithValue(storiesRepository),
        ],
        child: const MaterialApp(
          home: StoryChatFlowPage(
            storyId: 'story_1',
            storyTitle: 'A Quiet Place',
            initialInteractionMode: 'narrative',
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    final scrollable = tester.state<ScrollableState>(
      find.byType(Scrollable).first,
    );
    expect(scrollable.position.pixels, scrollable.position.maxScrollExtent);
    expect(find.textContaining('peace does not arrive'), findsOneWidget);
  });

  testWidgets('normal narrative story renders numbered chapters as buttons', (
    tester,
  ) async {
    final fake = FakeVoiceChatController();
    final storiesRepository = _FakeStoriesRepository(
      conversation: const [
        {
          'speaker': 'assistant',
          'message': '''Here are three stories to choose from:

1. **The Silent Promise:** A newly married couple discovers commitment.
2. **Across the Miles:** Two long-distance partners navigate love.
3. **Wedding Whisper:** A wedding planner finds unexpected romance.

Which story would you like to explore?''',
        },
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          voiceChatControllerProvider.overrideWith(() => fake),
          storiesRepositoryProvider.overrideWithValue(storiesRepository),
        ],
        child: const MaterialApp(
          home: StoryChatFlowPage(
            storyId: 'story_1',
            storyTitle: 'Love in Translation',
            initialInteractionMode: 'narrative',
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('The Silent Promise'), findsOneWidget);
    expect(find.text('Across the Miles'), findsOneWidget);
    expect(find.text('Wedding Whisper'), findsOneWidget);
  });

  testWidgets('story option menu keeps introduction visible', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final fake = FakeVoiceChatController();
    final storiesRepository = _FakeStoriesRepository(
      conversation: const [
        {
          'speaker': 'assistant',
          'message':
              '''Welcome to How to Stop Overthinking. Tonight, the room begins with a mind that keeps circling the same small worry until it feels larger than the day around it.

1. Shadows of Doubt: A late-night message turns one quiet fear into a choice.
2. The Evening Dinner: A family meal gives an anxious thought somewhere to land.
3. The Open Window: Morning light interrupts a spiral before it takes over.

Which story would you like to explore?''',
        },
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          voiceChatControllerProvider.overrideWith(() => fake),
          storiesRepositoryProvider.overrideWithValue(storiesRepository),
        ],
        child: const MaterialApp(
          home: StoryChatFlowPage(
            storyId: 'story_1',
            storyTitle: 'How to Stop Overthinking',
            initialInteractionMode: 'narrative',
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(
      find.textContaining('Welcome to How to Stop Overthinking'),
      findsOneWidget,
    );
    expect(find.text('Shadows of Doubt'), findsOneWidget);
    expect(find.text('The Evening Dinner'), findsOneWidget);
    expect(find.text('The Open Window'), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.pencil), findsOneWidget);
    expect(find.textContaining('Which story would you like'), findsNothing);
  });

  testWidgets('option panel chevron collapses and expands choices', (
    tester,
  ) async {
    final fake = FakeVoiceChatController();
    final storiesRepository = _FakeStoriesRepository(
      conversation: const [
        {
          'speaker': 'assistant',
          'message': '''Choose one story:

1. Shadows of Doubt: A late-night message turns one quiet fear into a choice.
2. The Evening Dinner: A family meal gives an anxious thought somewhere to land.
3. The Open Window: Morning light interrupts a spiral before it takes over.''',
        },
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          voiceChatControllerProvider.overrideWith(() => fake),
          storiesRepositoryProvider.overrideWithValue(storiesRepository),
        ],
        child: const MaterialApp(
          home: StoryChatFlowPage(
            storyId: 'story_1',
            storyTitle: 'Beneath the Surface',
            initialInteractionMode: 'narrative',
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byIcon(CupertinoIcons.xmark), findsNothing);
    expect(find.byIcon(CupertinoIcons.chevron_down), findsOneWidget);
    expect(find.text('Shadows of Doubt'), findsOneWidget);

    await tester.tap(find.byIcon(CupertinoIcons.chevron_down));
    await tester.pumpAndSettle();

    expect(find.text('What kind of story sounds good?'), findsOneWidget);
    expect(find.text('Type your own answer...'), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.chevron_up), findsOneWidget);
    expect(find.text('Shadows of Doubt'), findsNothing);

    await tester.tap(find.byIcon(CupertinoIcons.chevron_up));
    await tester.pumpAndSettle();

    expect(find.byIcon(CupertinoIcons.chevron_down), findsOneWidget);
    expect(find.text('Shadows of Doubt'), findsOneWidget);
  });

  testWidgets('story option panel drag scrolls chat page', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final fake = FakeVoiceChatController();
    final storiesRepository = _FakeStoriesRepository(
      conversation: const [
        {
          'speaker': 'assistant',
          'message':
              'The first thought arrives before breakfast and refuses to leave.',
        },
        {
          'speaker': 'user',
          'message': 'I want to understand why it keeps looping.',
        },
        {
          'speaker': 'assistant',
          'message':
              'By noon, every ordinary sound has become another reason to replay the same question.',
        },
        {'speaker': 'user', 'message': 'Give me a story for that.'},
        {
          'speaker': 'assistant',
          'message':
              '''Welcome to How to Stop Overthinking. Choose a starting point for the feeling you want to follow.

1. Shadows of Doubt: A late-night message turns one quiet fear into a choice.
2. The Evening Dinner: A family meal gives an anxious thought somewhere to land.
3. The Open Window: Morning light interrupts a spiral before it takes over.

Which story would you like to explore?''',
        },
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          voiceChatControllerProvider.overrideWith(() => fake),
          storiesRepositoryProvider.overrideWithValue(storiesRepository),
        ],
        child: const MaterialApp(
          home: StoryChatFlowPage(
            storyId: 'story_1',
            storyTitle: 'How to Stop Overthinking',
            initialInteractionMode: 'narrative',
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    final scrollable = tester.state<ScrollableState>(
      find.byType(Scrollable).first,
    );
    final before = scrollable.position.pixels;
    expect(before, greaterThan(0));

    await tester.drag(find.text('Try different stories'), const Offset(0, 140));
    await tester.pump();

    expect(scrollable.position.pixels, lessThan(before));
  });

  testWidgets('story option panel auto-scrolls latest intro into view', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final fake = FakeVoiceChatController();
    final storiesRepository = _FakeStoriesRepository(
      conversation: const [
        {
          'speaker': 'assistant',
          'message':
              'The first thought arrives before breakfast and refuses to leave.',
        },
        {
          'speaker': 'user',
          'message': 'I want to understand why it keeps looping.',
        },
        {
          'speaker': 'assistant',
          'message':
              'By noon, every ordinary sound has become another reason to replay the same question.',
        },
        {'speaker': 'user', 'message': 'Give me a story for that.'},
        {
          'speaker': 'assistant',
          'message':
              '''Welcome to How to Stop Overthinking. Choose a starting point for the feeling you want to follow.

Feel free to choose the one that resonates most with what your mind keeps replaying.

1. Shadows of Doubt: A late-night message turns one quiet fear into a choice.
2. The Evening Dinner: A family meal gives an anxious thought somewhere to land.
3. The Open Window: Morning light interrupts a spiral before it takes over.

Which story would you like to explore?''',
        },
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          voiceChatControllerProvider.overrideWith(() => fake),
          storiesRepositoryProvider.overrideWithValue(storiesRepository),
        ],
        child: const MaterialApp(
          home: StoryChatFlowPage(
            storyId: 'story_1',
            storyTitle: 'How to Stop Overthinking',
            initialInteractionMode: 'narrative',
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    final latestIntro = tester.getRect(
      find.textContaining('Feel free to choose the one that resonates'),
    );
    final optionTabTitle = tester.getRect(
      find.text('What kind of story sounds good?'),
    );

    expect(latestIntro.bottom, lessThan(optionTabTitle.top));
  });

  testWidgets('story action choices use assistant question as panel title', (
    tester,
  ) async {
    final fake = FakeVoiceChatController();
    final storiesRepository = _FakeStoriesRepository(
      conversation: const [
        {
          'speaker': 'assistant',
          'message':
              '''Lila noticed an elderly man sitting on a bench, feeding the birds. His calm presence seemed to cut through the fog of her anxiety.

What would you like Lila to do next?

1. Strike up a conversation with the elderly man to learn from his experience.
2. Sit quietly nearby and observe, allowing herself some time to reflect.
3. Continue walking, seeking clarity in solitude.''',
        },
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          voiceChatControllerProvider.overrideWith(() => fake),
          storiesRepositoryProvider.overrideWithValue(storiesRepository),
        ],
        child: const MaterialApp(
          home: StoryChatFlowPage(
            storyId: 'story_1',
            storyTitle: 'Beneath the Surface',
            initialInteractionMode: 'narrative',
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(
      find.textContaining('What would you like Lila to do next?'),
      findsOneWidget,
    );
    expect(find.text('What kind of story sounds good?'), findsNothing);
    expect(
      find.textContaining('His calm presence seemed to cut through'),
      findsOneWidget,
    );
    expect(find.textContaining('Strike up a conversation'), findsOneWidget);
  });

  testWidgets('normal narrative story deduplicates repeated chapter buttons', (
    tester,
  ) async {
    final fake = FakeVoiceChatController();
    final storiesRepository = _FakeStoriesRepository(
      conversation: const [
        {
          'speaker': 'assistant',
          'message': '''Today, I have three stories for you to explore:

1. **The Letter on the Kitchen Counter:** A folded note changes dinner.
2. **Sunday Dinner's Silent Tension:** A family meal reveals what was avoided.
3. **The Photograph in the Attic:** An old picture brings a buried memory back.

1. **The Letter on the Kitchen Counter:** A folded note changes dinner.
2. **Sunday Dinner's Silent Tension:** A family meal reveals what was avoided.
3. **The Photograph in the Attic:** An old picture brings a buried memory back.

Which of these stories would you like to dive into?''',
        },
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          voiceChatControllerProvider.overrideWith(() => fake),
          storiesRepositoryProvider.overrideWithValue(storiesRepository),
        ],
        child: const MaterialApp(
          home: StoryChatFlowPage(
            storyId: 'story_1',
            storyTitle: 'Beneath the Surface',
            initialInteractionMode: 'narrative',
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('The Letter on the Kitchen Counter'), findsOneWidget);
    expect(find.text("Sunday Dinner's Silent Tension"), findsOneWidget);
    expect(find.text('The Photograph in the Attic'), findsOneWidget);
    expect(find.text('Try different stories'), findsOneWidget);
  });

  testWidgets('internal regeneration prompt displays as friendly user bubble', (
    tester,
  ) async {
    final fake = FakeVoiceChatController();
    final storiesRepository = _FakeStoriesRepository();
    const prompt =
        'Give me three different story options for Beneath the Surface. Make every option specific to this story room, using its title, premise, characters, themes, tone, or setting. Do not reuse generic options from another story. Use numbered options with a title and one short teaser in the same line. Do not use quotation marks or subtitles.';

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          voiceChatControllerProvider.overrideWith(() => fake),
          storiesRepositoryProvider.overrideWithValue(storiesRepository),
        ],
        child: const MaterialApp(
          home: StoryChatFlowPage(
            storyId: 'story_1',
            storyTitle: 'Beneath the Surface',
            initialInteractionMode: 'narrative',
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), prompt);
    await tester.pump();
    await tester.tap(find.byIcon(CupertinoIcons.paperplane_fill));
    await tester.pump();

    expect(find.text('Try different stories'), findsWidgets);
    expect(
      find.textContaining('Give me three different story options'),
      findsNothing,
    );
    expect(storiesRepository.sentMessages.single, prompt);
  });

  testWidgets('history hides internal story regeneration prompt', (
    tester,
  ) async {
    final fake = FakeVoiceChatController();
    final storiesRepository = _FakeStoriesRepository(
      conversation: const [
        {
          'speaker': 'user',
          'message':
              'Give me three different story options for Beneath the Surface. Make every option specific to this story room, using its title, premise, characters, themes, tone, or setting. Do not reuse generic options from another story. Use numbered options with a title and one short teaser in the same line. Do not use quotation marks or subtitles.',
        },
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          voiceChatControllerProvider.overrideWith(() => fake),
          storiesRepositoryProvider.overrideWithValue(storiesRepository),
        ],
        child: const MaterialApp(
          home: StoryChatFlowPage(
            storyId: 'story_1',
            storyTitle: 'Beneath the Surface',
            initialInteractionMode: 'narrative',
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Try different stories'), findsOneWidget);
    expect(
      find.textContaining('Give me three different story options'),
      findsNothing,
    );
  });

  testWidgets('latest story paragraph shows next and story-choice actions', (
    tester,
  ) async {
    final fake = FakeVoiceChatController();
    final storiesRepository = _FakeStoriesRepository(
      conversation: const [
        {
          'speaker': 'assistant',
          'message':
              'The letter waits on the kitchen counter, unopened and heavy with everything no one said. What insight might she draw from this moment of peace?',
        },
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          voiceChatControllerProvider.overrideWith(() => fake),
          storiesRepositoryProvider.overrideWithValue(storiesRepository),
        ],
        child: const MaterialApp(
          home: StoryChatFlowPage(
            storyId: 'story_1',
            storyTitle: 'Beneath the Surface',
            initialInteractionMode: 'narrative',
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Next'), findsOneWidget);
    expect(find.text('Try different stories'), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.pencil), findsOneWidget);
    expect(
      find.textContaining('What insight might she draw from this moment'),
      findsOneWidget,
    );
    expect(
      find.textContaining('The letter waits on the kitchen counter'),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        'The letter waits on the kitchen counter, unopened and heavy with everything no one said. What insight',
      ),
      findsNothing,
    );
    expect(
      find.text('She might realize calm is something she can return to.'),
      findsOneWidget,
    );
    expect(
      find.text('She could see that worry is only one part of her.'),
      findsOneWidget,
    );
    expect(
      find.text('She may decide to carry that gentleness into tomorrow.'),
      findsNothing,
    );

    await tester.tap(
      find.text('She might realize calm is something she can return to.'),
    );
    await tester.pump();

    expect(
      storiesRepository.sentMessages.single,
      'She might realize calm is something she can return to.',
    );

    await tester.tap(find.text('Next'));
    await tester.pump();

    expect(find.text('Next'), findsWidgets);
  });

  testWidgets('continuation suggestion tab does not cover latest story content', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final fake = FakeVoiceChatController();
    final storiesRepository = _FakeStoriesRepository(
      conversation: const [
        {
          'speaker': 'assistant',
          'message':
              '''As Lila walked home, she pondered over the idea of taking one small, honest step towards maintaining her newfound calm. She decided that each day, she would dedicate a few moments to herself, allowing her mind the space to breathe.

This commitment felt manageable, a gentle promise to nurture her inner peace. With this intention, Lila began to feel more connected to herself and the world around her. She realized that these small steps were not about changing everything at once but embracing the journey towards a more balanced life. How might this journey of self-discovery influence her interactions with others?''',
        },
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          voiceChatControllerProvider.overrideWith(() => fake),
          storiesRepositoryProvider.overrideWithValue(storiesRepository),
        ],
        child: const MaterialApp(
          home: StoryChatFlowPage(
            storyId: 'story_1',
            storyTitle: 'A Quiet Place',
            initialInteractionMode: 'narrative',
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    final storyText = tester.getRect(
      find.textContaining('journey towards a more balanced life'),
    );
    final panelTitle = tester.getRect(
      find.textContaining('How might this journey of self-discovery'),
    );

    expect(storyText.bottom, lessThan(panelTitle.top));

    final scrollable = tester.state<ScrollableState>(
      find.byType(Scrollable).first,
    );
    final expandedMaxScrollExtent = scrollable.position.maxScrollExtent;

    await tester.tap(find.byIcon(CupertinoIcons.chevron_down));
    await tester.pumpAndSettle();

    expect(
      scrollable.position.maxScrollExtent,
      lessThan(expandedMaxScrollExtent),
    );
  });

  testWidgets('story action restores previous choices before regenerating', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final fake = FakeVoiceChatController();
    final storiesRepository = _FakeStoriesRepository(
      conversation: const [
        {
          'speaker': 'assistant',
          'message': '''Choose one story:

1. **The Letter on the Kitchen Counter:** A folded note changes dinner.
2. **Sunday Dinner's Silent Tension:** A family meal reveals what was avoided.
3. **The Photograph in the Attic:** An old picture brings a memory back.''',
        },
        {
          'speaker': 'user',
          'message': 'I choose The Letter on the Kitchen Counter.',
        },
        {
          'speaker': 'assistant',
          'message':
              'The letter waits on the kitchen counter, unopened and heavy with everything no one said.',
        },
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          voiceChatControllerProvider.overrideWith(() => fake),
          storiesRepositoryProvider.overrideWithValue(storiesRepository),
        ],
        child: const MaterialApp(
          home: StoryChatFlowPage(
            storyId: 'story_1',
            storyTitle: 'Beneath the Surface',
            initialInteractionMode: 'narrative',
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    final tryButtons = find.text('Try different stories');
    expect(tryButtons, findsOneWidget);

    await tester.tap(tryButtons.last);
    await tester.pump();

    expect(storiesRepository.sentMessages, isEmpty);
    expect(find.text('The Letter on the Kitchen Counter'), findsOneWidget);
    expect(find.text("Sunday Dinner's Silent Tension"), findsOneWidget);
    expect(find.text('The Photograph in the Attic'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pump();

    expect(storiesRepository.sentMessages.single, 'Continue.');
  });

  testWidgets('VoiceChatScreen shows Ready for armed story state', (
    tester,
  ) async {
    final fake = FakeVoiceChatController(
      initialState: const VoiceChatState(
        isStoryMode: true,
        phase: RealtimeVoicePhase.ready,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [voiceChatControllerProvider.overrideWith(() => fake)],
        child: const MaterialApp(
          home: Scaffold(
            body: VoiceChatScreen(isStoryMode: true, showMascotFace: false),
          ),
        ),
      ),
    );

    await tester.pump();

    expect(find.text('Ready'), findsOneWidget);
    expect(find.text('Listening'), findsNothing);
    expect(find.text("Say something when you're ready"), findsNothing);
  });

  testWidgets('VoiceChatScreen shows Mic on only while actively recording', (
    tester,
  ) async {
    final fake = FakeVoiceChatController(
      initialState: const VoiceChatState(
        isStoryMode: true,
        isRecording: true,
        phase: RealtimeVoicePhase.recording,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [voiceChatControllerProvider.overrideWith(() => fake)],
        child: const MaterialApp(
          home: Scaffold(
            body: VoiceChatScreen(isStoryMode: true, showMascotFace: false),
          ),
        ),
      ),
    );

    await tester.pump();

    expect(find.text('Mic on'), findsOneWidget);
    expect(find.text("Say something when you're ready"), findsOneWidget);
  });
}

Widget _testVoicePageBuilder(BuildContext context) {
  return const StoryVoicePage(
    storyId: 'story_1',
    storyTitle: 'Test Story',
    showMascotFace: false, // avoids Rive FFI in widget tests
  );
}

class FakeVoiceChatController extends VoiceChatController {
  FakeVoiceChatController({this.initialState = const VoiceChatState()})
    : super(
        client: _NoopRealtimeVoiceClient(),
        player: _NoopAudioChunkPlayer(),
        voiceUriOverride: Uri.parse('wss://example.com/ws/realtime/voice'),
      );

  final VoiceChatState initialState;

  int startStorySessionCalls = 0;
  int stopPlaybackCalls = 0;
  int toggleMuteCalls = 0;
  int startRecordingCalls = 0;
  int endStorySessionCalls = 0;
  int sendTextPromptCalls = 0;

  @override
  VoiceChatState build() {
    // Avoid initializing platform audio/recorder in widget tests.
    return initialState;
  }

  @override
  Future<void> startStorySession(String storyId) async {
    startStorySessionCalls++;
    state = state.copyWith(
      isStoryMode: true,
      phase: RealtimeVoicePhase.ready,
      isConnecting: false,
    );
  }

  @override
  Future<void> resumeStorySession(String storySessionId) async {
    startStorySessionCalls++;
    state = state.copyWith(
      isStoryMode: true,
      phase: RealtimeVoicePhase.ready,
      isConnecting: false,
    );
  }

  @override
  Future<void> stopPlayback({bool restartListening = false}) async {
    stopPlaybackCalls++;
  }

  @override
  void toggleMute() {
    toggleMuteCalls++;
    final next = !state.isMuted;
    state = state.copyWith(isMuted: next);
    if (!next && state.isSessionReady) {
      startRecording();
    }
  }

  @override
  Future<void> startRecording() async {
    startRecordingCalls++;
    state = state.copyWith(isRecording: true);
  }

  @override
  Future<void> sendTextPrompt(String prompt, {bool textOnly = false}) async {
    sendTextPromptCalls++;
    final trimmed = prompt.trim();
    state = state.copyWith(
      conversationHistory: [
        ...state.conversationHistory,
        ConversationItem(role: 'user', content: trimmed),
      ],
      showPendingAssistantBubble: textOnly,
      clearAiResponse: true,
    );
  }

  @override
  Future<void> pauseStorySession() async {}

  @override
  Future<void> resumePausedSession() async {}

  @override
  Future<void> endStorySession() async {
    endStorySessionCalls++;
  }
}

class _FakeStoriesRepository extends StoriesRepository {
  _FakeStoriesRepository({this.conversation = const []}) : super(dio: Dio());

  int streamCalls = 0;
  int fetchConversationCalls = 0;
  final List<String> sentMessages = [];
  List<Map<String, dynamic>> conversation;

  StorySession get _session => StorySession(
    id: 'session_1',
    storyId: 'story_1',
    currentNodeId: 'node_1',
    pathHistory: const [],
    milestonesReached: const [],
    isPaused: false,
    isCompleted: false,
    lastActivityAt: DateTime(2026, 7, 10),
    version: 1,
  );

  @override
  Future<StorySession> startSession({
    required String storyId,
    required String deviceType,
    required String deviceId,
  }) async => _session;

  @override
  Future<List<Map<String, dynamic>>> fetchStoryConversation({
    required String storyId,
  }) async {
    fetchConversationCalls++;
    return conversation;
  }

  @override
  Stream<StoryTextStreamEvent> streamStoryText({
    required String storyId,
    required String message,
    int? expectedVersion,
  }) async* {
    streamCalls++;
    sentMessages.add(message);
    yield const StoryTextStreamEvent(type: 'token', content: 'A reply');
    yield StoryTextStreamEvent(type: 'done', session: _session);
  }
}

class _NoopRealtimeVoiceClient extends RealtimeVoiceClient {}

class _NoopAudioChunkPlayer implements AudioChunkPlayer {
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
