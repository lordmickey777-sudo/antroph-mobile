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
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
}

Future<void> _disposeQuizPage(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 3));
}

Future<void> _pumpQuizPage(
  WidgetTester tester, {
  required _QuizStoriesRepository repository,
  required String userId,
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
      child: const MaterialApp(
        home: StoryChatFlowPage(
          storyId: 'story-1',
          storyTitle: 'Quiz story',
          initialInteractionMode: 'group',
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
  }) : super(dio: Dio());

  InteractiveSessionState session;
  final InteractiveSessionState? retrySession;
  final ApiError? retryError;
  final InteractiveSessionState? conflictSession;
  int fetchCalls = 0;
  int retryCalls = 0;

  @override
  Future<InteractiveSessionState> startInteractiveSession({
    required String storyId,
    String deviceType = 'mobile',
    String? deviceId,
    String? sessionType,
    String? roomType,
    String? hostDisplayName,
    int? maxParticipants,
  }) async => session;

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
