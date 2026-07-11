import 'package:antroph_mobile/features/story/data/stories_repository.dart';
import 'package:antroph_mobile/features/story/models/interactive_story_models.dart';
import 'package:antroph_mobile/features/story/providers/interactive_story_provider.dart';
import 'package:antroph_mobile/features/story/providers/story_providers.dart';
import 'package:antroph_mobile/core/network/error_formatter.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _HistoryStoriesRepository repository;
  late ProviderContainer container;
  late ProviderSubscription<InteractiveStoryState> subscription;
  late InteractiveStoryNotifier notifier;

  setUp(() {
    repository = _HistoryStoriesRepository();
    container = ProviderContainer(
      overrides: [storiesRepositoryProvider.overrideWithValue(repository)],
    );
    subscription = container.listen(
      interactiveStoryProvider,
      (_, __) {},
      fireImmediately: true,
    );
    notifier = container.read(interactiveStoryProvider.notifier);
  });

  tearDown(() {
    subscription.close();
    container.dispose();
  });

  test('loads completed history read-only and blocks mutations', () async {
    repository.session = _session(isCompleted: true);

    await notifier.loadReadOnly('session-1');

    var state = container.read(interactiveStoryProvider);
    expect(state.session?.sessionId, 'session-1');
    expect(state.isReadOnly, isTrue);
    expect(repository.historyLoadEventLimit, 250);

    await notifier.submitText('Do not send');
    await notifier.submitOption(optionId: 'a', inputType: 'option_select');
    await notifier.submitPlayerChat('Do not send this either');
    await notifier.advanceQuestion();
    await notifier.retryGeneration();

    expect(repository.submitCalls, 0);
    expect(repository.advanceCalls, 0);

    await notifier.leaveSession();
    state = container.read(interactiveStoryProvider);
    expect(repository.leaveCalls, 0);
    expect(state.session, isNull);
    expect(state.isReadOnly, isFalse);
  });

  test('resumes a live session and delegates history queries', () async {
    repository.session = _session();

    await notifier.resume(' session-1 ');

    final state = container.read(interactiveStoryProvider);
    expect(repository.resumeCalls, 1);
    expect(state.session?.sessionId, 'session-1');
    expect(state.isReadOnly, isFalse);

    final history = await notifier.fetchSoloHistory(
      storyId: 'story-1',
      limit: 8,
    );
    expect(repository.historyStoryId, 'story-1');
    expect(repository.historyLimit, 8);
    expect(history.single.sessionId, 'session-1');
  });

  test('caches solo history until a refresh is requested', () async {
    final first = await notifier.fetchSoloHistory(storyId: 'story-1', limit: 8);
    final second = await notifier.fetchSoloHistory(
      storyId: 'story-1',
      limit: 8,
    );

    expect(repository.soloHistoryCalls, 1);
    expect(identical(first, second), isTrue);

    await notifier.fetchSoloHistory(
      storyId: 'story-1',
      limit: 8,
      forceRefresh: true,
    );
    expect(repository.soloHistoryCalls, 2);
  });

  test('copyWith can explicitly clear an attached session', () {
    final initial = InteractiveStoryState(session: _session());

    final cleared = initial.copyWith(session: null);

    expect(cleared.session, isNull);
  });

  test('failed opens clear stale session data', () async {
    repository.session = _session();
    expect(await notifier.resume('session-1'), isTrue);

    repository.startError = const ApiError(message: 'Start failed');
    expect(
      await notifier.start(storyId: 'story-2', interactionMode: 'solo'),
      isFalse,
    );
    var state = container.read(interactiveStoryProvider);
    expect(state.session, isNull);
    expect(state.error, 'Start failed');

    repository.startError = null;
    expect(await notifier.resume('session-1'), isTrue);
    repository.resumeError = const ApiError(message: 'Resume failed');
    expect(await notifier.resume('session-2'), isFalse);
    state = container.read(interactiveStoryProvider);
    expect(state.session, isNull);
    expect(state.error, 'Resume failed');

    repository.resumeError = null;
    expect(await notifier.resume('session-1'), isTrue);
    repository.historyError = const ApiError(message: 'History failed');
    expect(await notifier.loadReadOnly('session-2'), isFalse);
    state = container.read(interactiveStoryProvider);
    expect(state.session, isNull);
    expect(state.isReadOnly, isFalse);
    expect(state.error, 'History failed');
  });

  test('completed room snapshot immediately becomes read-only', () async {
    repository.session = _session(isPaused: true);
    expect(await notifier.resume('session-1'), isTrue);

    notifier.applyRoomSnapshotForTest(
      _session(isCompleted: true, isPaused: false),
    );

    final state = container.read(interactiveStoryProvider);
    expect(state.session?.isCompleted, isTrue);
    expect(state.session?.isPaused, isFalse);
    expect(state.isReadOnly, isTrue);
  });

  test('session_completed event marks the live session read-only', () async {
    repository.session = _session(isPaused: true);
    expect(await notifier.resume('session-1'), isTrue);

    notifier.applyRoomEventForTest({
      'event_type': 'session_completed',
      'seq': 5,
      'payload': const <String, dynamic>{},
    });

    final state = container.read(interactiveStoryProvider);
    expect(state.session?.isCompleted, isTrue);
    expect(state.session?.isPaused, isFalse);
    expect(state.session?.interactiveState['phase'], 'completed');
    expect(state.isReadOnly, isTrue);
  });

  test('openExact falls back to completed read-only history on 409', () async {
    repository.resumeError = const ApiError(
      message: 'Session already completed',
      statusCode: 409,
    );
    repository.session = _session(isCompleted: true);

    expect(await notifier.openExact(' session-1 '), isTrue);

    final state = container.read(interactiveStoryProvider);
    expect(state.session?.sessionId, 'session-1');
    expect(state.isReadOnly, isTrue);
    expect(repository.historyLoadEventLimit, 250);
  });

  test(
    'openExact failure never leaves the previous session attached',
    () async {
      repository.session = _session();
      expect(await notifier.resume('session-1'), isTrue);
      repository.resumeError = const ApiError(
        message: 'Session was not found',
        statusCode: 404,
      );

      expect(await notifier.openExact('missing-session'), isFalse);

      final state = container.read(interactiveStoryProvider);
      expect(state.session, isNull);
      expect(state.isReadOnly, isFalse);
      expect(state.error, 'Session was not found');
    },
  );

  test(
    'restart preserves choose-new-topic semantics with startFresh',
    () async {
      repository.session = _session();

      await notifier.restart(
        storyId: 'story-1',
        interactionMode: 'solo',
        sessionType: 'solo',
      );

      expect(repository.startCalls, 1);
      expect(repository.lastStartFresh, isTrue);
      expect(container.read(interactiveStoryProvider).isReadOnly, isFalse);
    },
  );
}

class _HistoryStoriesRepository extends StoriesRepository {
  _HistoryStoriesRepository()
    : super(dio: Dio(BaseOptions(baseUrl: 'https://example.test')));

  InteractiveSessionState session = _session();
  int startCalls = 0;
  int resumeCalls = 0;
  int submitCalls = 0;
  int advanceCalls = 0;
  int leaveCalls = 0;
  int historyLoadEventLimit = 0;
  int soloHistoryCalls = 0;
  bool? lastStartFresh;
  String? historyStoryId;
  int? historyLimit;
  ApiError? startError;
  ApiError? resumeError;
  ApiError? historyError;

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
    final error = startError;
    if (error != null) throw error;
    startCalls += 1;
    lastStartFresh = startFresh;
    return session;
  }

  @override
  Future<InteractiveSessionState> fetchInteractiveSession(
    String sessionId,
  ) async {
    return session;
  }

  @override
  Future<InteractiveSessionState> fetchInteractiveSessionHistory(
    String sessionId, {
    int eventLimit = 250,
  }) async {
    historyLoadEventLimit = eventLimit;
    final error = historyError;
    if (error != null) throw error;
    return session;
  }

  @override
  Future<InteractiveSessionState> resumeInteractiveSession(
    String sessionId,
  ) async {
    resumeCalls += 1;
    final error = resumeError;
    if (error != null) throw error;
    return session;
  }

  @override
  Future<List<SoloInteractiveSessionSummary>> fetchSoloInteractiveHistory({
    String? storyId,
    int limit = 20,
  }) async {
    soloHistoryCalls += 1;
    historyStoryId = storyId;
    historyLimit = limit;
    return [
      SoloInteractiveSessionSummary.fromJson({
        'session_id': 'session-1',
        'story_id': 'story-1',
        'story_title': 'The Hot Seat',
        'is_paused': true,
        'is_completed': false,
        'topic_path': ['History'],
        'last_activity_at': '2026-07-11T10:00:00Z',
        'created_at': '2026-07-11T09:00:00Z',
      }),
    ];
  }

  @override
  Future<InteractiveInputResponse> submitInteractiveInput({
    required String sessionId,
    required InteractiveInput input,
  }) async {
    submitCalls += 1;
    throw StateError('Read-only sessions must not submit input.');
  }

  @override
  Future<InteractiveSessionState> advanceInteractiveSession(
    String sessionId,
  ) async {
    advanceCalls += 1;
    return session;
  }

  @override
  Future<void> leaveInteractiveSession(String sessionId) async {
    leaveCalls += 1;
  }
}

InteractiveSessionState _session({
  bool isCompleted = false,
  bool isPaused = false,
}) {
  return InteractiveSessionState.fromJson({
    'session_id': 'session-1',
    'story_id': 'story-1',
    'interaction_mode': 'interactive',
    'ai_role': 'host',
    'interactive_state': {
      'session_type': 'solo',
      'phase': isCompleted ? 'completed' : 'discussion',
    },
    'participants': const [],
    'events': const [],
    'last_seq': 4,
    'is_completed': isCompleted,
    'is_paused': isPaused,
    'created_at': '2026-07-11T09:00:00Z',
    'updated_at': '2026-07-11T10:00:00Z',
  });
}
