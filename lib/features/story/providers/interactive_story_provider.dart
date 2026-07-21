import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/status.dart' as ws_status;

import '../../../core/auth/state/auth_state.dart';
import '../../../core/env/env.dart';
import '../../../core/network/error_formatter.dart';
import '../models/interactive_story_models.dart';
import 'story_providers.dart';

class InteractiveStoryState {
  const InteractiveStoryState({
    this.session,
    this.isLoading = false,
    this.isReadOnly = false,
    this.pendingInputKeys = const <String>{},
    this.pendingTextMessages = const <PendingInteractiveTextMessage>[],
    this.localQuizSelections = const <String, String>{},
    this.streamingAssistantText,
    this.recentStreamedAssistantText,
    this.isGenerationTakingLong = false,
    this.isRetryingGeneration = false,
    this.isAdvancingQuestion = false,
    this.error,
  });

  final InteractiveSessionState? session;
  final bool isLoading;
  final bool isReadOnly;
  final Set<String> pendingInputKeys;
  final List<PendingInteractiveTextMessage> pendingTextMessages;
  final Map<String, String> localQuizSelections;
  final String? streamingAssistantText;
  final String? recentStreamedAssistantText;
  final bool isGenerationTakingLong;
  final bool isRetryingGeneration;
  final bool isAdvancingQuestion;
  final String? error;

  InteractiveStoryState copyWith({
    Object? session = _unset,
    bool? isLoading,
    bool? isReadOnly,
    Set<String>? pendingInputKeys,
    List<PendingInteractiveTextMessage>? pendingTextMessages,
    Map<String, String>? localQuizSelections,
    Object? streamingAssistantText = _unset,
    Object? recentStreamedAssistantText = _unset,
    bool? isGenerationTakingLong,
    bool? isRetryingGeneration,
    bool? isAdvancingQuestion,
    Object? error = _unset,
  }) {
    return InteractiveStoryState(
      session: identical(session, _unset)
          ? this.session
          : session as InteractiveSessionState?,
      isLoading: isLoading ?? this.isLoading,
      isReadOnly: isReadOnly ?? this.isReadOnly,
      pendingInputKeys: pendingInputKeys ?? this.pendingInputKeys,
      pendingTextMessages: pendingTextMessages ?? this.pendingTextMessages,
      localQuizSelections: localQuizSelections ?? this.localQuizSelections,
      streamingAssistantText: streamingAssistantText == _unset
          ? this.streamingAssistantText
          : streamingAssistantText as String?,
      recentStreamedAssistantText: recentStreamedAssistantText == _unset
          ? this.recentStreamedAssistantText
          : recentStreamedAssistantText as String?,
      isGenerationTakingLong:
          isGenerationTakingLong ?? this.isGenerationTakingLong,
      isRetryingGeneration: isRetryingGeneration ?? this.isRetryingGeneration,
      isAdvancingQuestion: isAdvancingQuestion ?? this.isAdvancingQuestion,
      error: error == _unset ? this.error : error as String?,
    );
  }
}

const _unset = Object();

bool _isCompletedGroupChatRoom(InteractiveSessionState? session) {
  if (session == null || !session.isCompleted) return false;
  final state = session.interactiveState;
  return state['session_type'] == 'group' && state['template'] == 'quiz';
}

bool _isReadOnlyInteractiveSession(InteractiveSessionState session) {
  return session.isCompleted && !_isCompletedGroupChatRoom(session);
}

class InteractiveStoryNotifier extends Notifier<InteractiveStoryState> {
  static const generationSlowThreshold = Duration(seconds: 30);
  static const _recoveryRequestTimeout = Duration(seconds: 7);
  static const _socketConnectTimeout = Duration(seconds: 6);

  IOWebSocketChannel? _roomChannel;
  StreamSubscription<dynamic>? _roomSubscription;
  Timer? _refreshTimer;
  Timer? _generationWatchdogTimer;
  String? _generationWatchdogKey;
  Future<void>? _generationRecovery;
  final Map<String, List<SoloInteractiveSessionSummary>> _soloHistoryCache =
      <String, List<SoloInteractiveSessionSummary>>{};
  bool _isDisposed = false;

  @override
  InteractiveStoryState build() {
    _isDisposed = false;
    ref.onDispose(() {
      _isDisposed = true;
      _refreshTimer?.cancel();
      _refreshTimer = null;
      _generationWatchdogTimer?.cancel();
      _generationWatchdogTimer = null;
      unawaited(_disconnectRoomSocket());
    });
    return const InteractiveStoryState();
  }

  String get _deviceType => Platform.isIOS ? 'ios' : 'android';
  String get _deviceId => 'mobile-app';

  Future<bool> start({
    required String storyId,
    required String interactionMode,
    String? sessionType,
    String? roomType,
    bool startFresh = false,
  }) async {
    if (state.isLoading) return false;
    final existing = state.session;
    if (!startFresh &&
        existing != null &&
        existing.storyId == storyId &&
        !state.isReadOnly) {
      return true;
    }

    await _disconnectRoomSocket();
    if (_isDisposed) return false;
    state = const InteractiveStoryState(isLoading: true);
    try {
      final repo = ref.read(storiesRepositoryProvider);
      final session = await repo.startInteractiveSession(
        storyId: storyId,
        deviceType: _deviceType,
        deviceId: _deviceId,
        sessionType:
            sessionType ?? (interactionMode == 'group' ? 'group' : 'solo'),
        roomType: roomType,
        startFresh: startFresh,
      );
      if (_isDisposed) return false;
      final normalizedSession = _normalizeSessionSnapshot(session);
      final isReadOnly = _isReadOnlyInteractiveSession(normalizedSession);
      state = InteractiveStoryState(
        session: normalizedSession,
        isReadOnly: isReadOnly,
      );
      if (!isReadOnly) {
        unawaited(_connectRoomSocket(session.sessionId));
      }
      _scheduleWaitingRefresh();
      return true;
    } on ApiError catch (e) {
      if (_isDisposed) return false;
      state = InteractiveStoryState(error: e.message);
      return false;
    } catch (e) {
      if (_isDisposed) return false;
      state = InteractiveStoryState(error: '$e');
      return false;
    }
  }

  Future<void> restart({
    required String storyId,
    required String interactionMode,
    String? sessionType,
    String? roomType,
  }) async {
    await _disconnectRoomSocket();
    if (_isDisposed) return;
    state = const InteractiveStoryState();
    await start(
      storyId: storyId,
      interactionMode: interactionMode,
      sessionType: sessionType,
      roomType: roomType,
      startFresh: true,
    );
  }

  String _soloHistoryCacheKey(String? storyId) {
    final normalized = storyId?.trim();
    return normalized == null || normalized.isEmpty ? '__all__' : normalized;
  }

  List<SoloInteractiveSessionSummary>? cachedSoloHistory({String? storyId}) {
    return _soloHistoryCache[_soloHistoryCacheKey(storyId)];
  }

  Future<List<SoloInteractiveSessionSummary>> fetchSoloHistory({
    String? storyId,
    int limit = 20,
    bool forceRefresh = false,
  }) async {
    final cacheKey = _soloHistoryCacheKey(storyId);
    if (!forceRefresh) {
      final cached = _soloHistoryCache[cacheKey];
      if (cached != null) return cached;
    }
    final history = await ref
        .read(storiesRepositoryProvider)
        .fetchSoloInteractiveHistory(storyId: storyId, limit: limit);
    final cachedHistory = List<SoloInteractiveSessionSummary>.unmodifiable(
      history,
    );
    _soloHistoryCache[cacheKey] = cachedHistory;
    return cachedHistory;
  }

  Future<bool> resume(String sessionId) async {
    final normalizedId = sessionId.trim();
    if (normalizedId.isEmpty || state.isLoading) return false;

    await _disconnectRoomSocket();
    if (_isDisposed) return false;
    state = const InteractiveStoryState(isLoading: true);
    try {
      final session = await ref
          .read(storiesRepositoryProvider)
          .resumeInteractiveSession(normalizedId);
      if (_isDisposed) return false;
      final normalizedSession = _normalizeSessionSnapshot(session);
      final isReadOnly = _isReadOnlyInteractiveSession(normalizedSession);
      state = InteractiveStoryState(
        session: normalizedSession,
        isReadOnly: isReadOnly,
      );
      if (!isReadOnly) {
        unawaited(_connectRoomSocket(normalizedSession.sessionId));
      }
      _scheduleWaitingRefresh();
      return true;
    } on ApiError catch (e) {
      if (_isDisposed) return false;
      state = InteractiveStoryState(error: e.message);
      return false;
    } catch (e) {
      if (_isDisposed) return false;
      state = InteractiveStoryState(error: '$e');
      return false;
    }
  }

  Future<bool> loadReadOnly(String sessionId) async {
    final normalizedId = sessionId.trim();
    if (normalizedId.isEmpty || state.isLoading) return false;

    await _disconnectRoomSocket();
    if (_isDisposed) return false;
    state = const InteractiveStoryState(isLoading: true, isReadOnly: true);
    try {
      final session = await ref
          .read(storiesRepositoryProvider)
          .fetchInteractiveSessionHistory(normalizedId);
      if (_isDisposed) return false;
      state = InteractiveStoryState(
        session: _normalizeSessionSnapshot(session),
        isReadOnly: true,
      );
      return true;
    } on ApiError catch (e) {
      if (_isDisposed) return false;
      state = InteractiveStoryState(error: e.message);
      return false;
    } catch (e) {
      if (_isDisposed) return false;
      state = InteractiveStoryState(error: '$e');
      return false;
    }
  }

  /// Opens an exact session ID safely for deep links and stale history rows.
  ///
  /// A session can complete between the history request and the resume tap. In
  /// that case the resume endpoint returns 409; fetch the canonical transcript
  /// and open it read-only only when the server confirms it is completed.
  Future<bool> openExact(String sessionId) async {
    final normalizedId = sessionId.trim();
    if (normalizedId.isEmpty || state.isLoading) return false;

    await _disconnectRoomSocket();
    if (_isDisposed) return false;
    state = const InteractiveStoryState(isLoading: true);
    try {
      final session = await ref
          .read(storiesRepositoryProvider)
          .resumeInteractiveSession(normalizedId);
      if (_isDisposed) return false;
      final normalizedSession = _normalizeSessionSnapshot(session);
      final isReadOnly = _isReadOnlyInteractiveSession(normalizedSession);
      state = InteractiveStoryState(
        session: normalizedSession,
        isReadOnly: isReadOnly,
      );
      if (!isReadOnly) {
        unawaited(_connectRoomSocket(normalizedSession.sessionId));
        _scheduleWaitingRefresh();
      }
      return true;
    } on ApiError catch (resumeError) {
      if (_isDisposed) return false;
      if (resumeError.statusCode != 409) {
        state = InteractiveStoryState(error: resumeError.message);
        return false;
      }
      try {
        final canonical = await ref
            .read(storiesRepositoryProvider)
            .fetchInteractiveSessionHistory(normalizedId);
        if (_isDisposed) return false;
        final normalizedSession = _normalizeSessionSnapshot(canonical);
        if (!normalizedSession.isCompleted) {
          state = InteractiveStoryState(error: resumeError.message);
          return false;
        }
        state = InteractiveStoryState(
          session: normalizedSession,
          isReadOnly: true,
        );
        return true;
      } on ApiError catch (historyError) {
        if (_isDisposed) return false;
        state = InteractiveStoryState(error: historyError.message);
        return false;
      } catch (error) {
        if (_isDisposed) return false;
        state = InteractiveStoryState(error: '$error');
        return false;
      }
    } catch (error) {
      if (_isDisposed) return false;
      state = InteractiveStoryState(error: '$error');
      return false;
    }
  }

  Future<void> joinPublic({
    required String storyId,
    String? displayName,
  }) async {
    if (state.isLoading) return;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final repo = ref.read(storiesRepositoryProvider);
      final session = await repo.joinPublicInteractiveRoom(
        storyId: storyId,
        deviceType: _deviceType,
        deviceId: _deviceId,
        displayName: displayName,
      );
      if (_isDisposed) return;
      final normalizedSession = _normalizeSessionSnapshot(session);
      state = InteractiveStoryState(session: normalizedSession);
      unawaited(_connectRoomSocket(session.sessionId));
      _scheduleWaitingRefresh();
    } on ApiError catch (e) {
      if (_isDisposed) return;
      state = state.copyWith(isLoading: false, error: e.message);
    } catch (e) {
      if (_isDisposed) return;
      state = state.copyWith(isLoading: false, error: '$e');
    }
  }

  Future<void> joinByCode(String joinCode, {String? displayName}) async {
    final code = joinCode.trim();
    if (code.isEmpty || state.isLoading) return;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final repo = ref.read(storiesRepositoryProvider);
      final session = await repo.joinInteractiveSessionByCode(
        joinCode: code,
        deviceType: _deviceType,
        deviceId: _deviceId,
        displayName: displayName,
      );
      if (_isDisposed) return;
      final normalizedSession = _normalizeSessionSnapshot(session);
      state = InteractiveStoryState(session: normalizedSession);
      unawaited(_connectRoomSocket(session.sessionId));
      _scheduleWaitingRefresh();
    } on ApiError catch (e) {
      if (_isDisposed) return;
      state = state.copyWith(isLoading: false, error: e.message);
    } catch (e) {
      if (_isDisposed) return;
      state = state.copyWith(isLoading: false, error: '$e');
    }
  }

  Future<void> refresh() async {
    final sessionId = state.session?.sessionId;
    if (sessionId == null || sessionId.isEmpty || state.isLoading) return;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final repo = ref.read(storiesRepositoryProvider);
      final session = await repo.fetchInteractiveSession(sessionId);
      if (_isDisposed) return;
      if (state.session?.sessionId != sessionId) return;
      if (_isOlderSessionSnapshot(session)) {
        state = state.copyWith(isLoading: false, error: null);
        return;
      }
      final normalizedSession = _normalizeSessionSnapshot(session);
      final isReadOnly = _isReadOnlyInteractiveSession(normalizedSession);
      state = state.copyWith(
        session: normalizedSession,
        isLoading: false,
        isReadOnly: isReadOnly,
        error: null,
      );
      if (isReadOnly) {
        await _disconnectRoomSocket();
        return;
      }
      _scheduleWaitingRefresh();
    } on ApiError catch (e) {
      if (_isDisposed) return;
      state = state.copyWith(isLoading: false, error: e.message);
    } catch (e) {
      if (_isDisposed) return;
      state = state.copyWith(isLoading: false, error: '$e');
    }
  }

  Future<void> retryGeneration() {
    return recoverGeneration(canRetry: true);
  }

  Future<void> recoverGeneration({required bool canRetry}) {
    final activeRecovery = _generationRecovery;
    if (activeRecovery != null) return activeRecovery;

    final recovery = _recoverGeneration(canRetry: canRetry);
    _generationRecovery = recovery;
    return recovery.whenComplete(() {
      if (identical(_generationRecovery, recovery)) {
        _generationRecovery = null;
      }
    });
  }

  Future<void> _recoverGeneration({required bool canRetry}) async {
    final sessionId = state.session?.sessionId;
    if (sessionId == null || sessionId.isEmpty || state.isRetryingGeneration) {
      return;
    }
    if (!_canMutateCurrentSession) return;
    state = state.copyWith(isRetryingGeneration: true, error: null);

    InteractiveSessionState? canonicalSession;
    var requestedRetry = false;
    try {
      final repo = ref.read(storiesRepositoryProvider);
      try {
        canonicalSession = await repo
            .fetchInteractiveSession(sessionId)
            .timeout(_recoveryRequestTimeout);
        if (_isDisposed) return;
        canonicalSession = _normalizeSessionSnapshot(canonicalSession);
        state = state.copyWith(session: canonicalSession);
        _scheduleWaitingRefresh();
      } catch (_) {
        // Reconnecting can still restore the room snapshot. Normal polling
        // remains active if the one-off canonical request is unavailable.
      }

      if (_isDisposed) return;
      await _connectRoomSocket(sessionId);
      if (_isDisposed) return;

      final latestSession = canonicalSession ?? state.session;
      final phase = latestSession?.interactiveState['phase'] as String?;
      if (canRetry && phase == 'generation_failed') {
        requestedRetry = true;
        _resetGenerationWatchdog();
        final retriedSession = await repo
            .retryInteractiveQuizGeneration(sessionId)
            .timeout(_recoveryRequestTimeout);
        if (_isDisposed) return;
        state = state.copyWith(
          session: _normalizeSessionSnapshot(retriedSession),
        );
      }

      if (_isDisposed) return;
      state = state.copyWith(
        isRetryingGeneration:
            requestedRetry && _shouldKeepGenerationRetryOverlay(state.session),
      );
      _scheduleWaitingRefresh();
    } on ApiError catch (e) {
      if (_isDisposed) return;
      if (e.statusCode == 409) {
        try {
          final canonicalSession = await ref
              .read(storiesRepositoryProvider)
              .fetchInteractiveSession(sessionId)
              .timeout(_recoveryRequestTimeout);
          if (_isDisposed) return;
          state = state.copyWith(
            session: _normalizeSessionSnapshot(canonicalSession),
            isRetryingGeneration: false,
            error: null,
          );
          return;
        } catch (_) {
          // Fall through to the original conflict if the canonical refetch fails.
        }
      }
      state = state.copyWith(isRetryingGeneration: false, error: e.message);
    } catch (e) {
      if (_isDisposed) return;
      state = state.copyWith(
        isRetryingGeneration: false,
        error: 'Could not reconnect. Aura will keep checking for the question.',
      );
    } finally {
      if (!_isDisposed) {
        _scheduleWaitingRefresh();
      }
    }
  }

  Future<void> advanceQuestion({bool showLoading = true}) async {
    final sessionId = state.session?.sessionId;
    if (sessionId == null ||
        sessionId.isEmpty ||
        state.isLoading ||
        state.isAdvancingQuestion ||
        !_canMutateCurrentSession) {
      return;
    }
    state = state.copyWith(
      isAdvancingQuestion: showLoading ? true : state.isAdvancingQuestion,
      error: null,
    );
    try {
      final repo = ref.read(storiesRepositoryProvider);
      final session = await repo.advanceInteractiveSession(sessionId);
      if (_isDisposed) return;
      state = state.copyWith(
        session: _normalizeSessionSnapshot(session),
        isAdvancingQuestion: showLoading ? false : state.isAdvancingQuestion,
      );
      _scheduleWaitingRefresh();
    } on ApiError catch (e) {
      if (_isDisposed) return;
      state = state.copyWith(
        isAdvancingQuestion: showLoading ? false : state.isAdvancingQuestion,
        error: e.message,
      );
    } catch (e) {
      if (_isDisposed) return;
      state = state.copyWith(
        isAdvancingQuestion: showLoading ? false : state.isAdvancingQuestion,
        error: '$e',
      );
    }
  }

  Future<void> leaveSession() async {
    final sessionId = state.session?.sessionId;
    if (sessionId == null || sessionId.isEmpty || state.isLoading) return;
    if (!_canMutateCurrentSession) {
      await _disconnectRoomSocket();
      if (_isDisposed) return;
      state = const InteractiveStoryState();
      return;
    }
    state = state.copyWith(isLoading: true, error: null);
    try {
      final repo = ref.read(storiesRepositoryProvider);
      await repo.leaveInteractiveSession(sessionId);
      await _disconnectRoomSocket();
      if (_isDisposed) return;
      state = const InteractiveStoryState();
    } on ApiError {
      await _disconnectRoomSocket();
      if (_isDisposed) return;
      state = const InteractiveStoryState();
    } catch (_) {
      await _disconnectRoomSocket();
      if (_isDisposed) return;
      state = const InteractiveStoryState();
    }
  }

  Future<void> submitOption({
    required String optionId,
    required String inputType,
    String? questionId,
    String? displayText,
  }) async {
    final sessionId = state.session?.sessionId;
    if (sessionId == null || sessionId.isEmpty || !_canMutateCurrentSession) {
      return;
    }
    if (inputType == 'quiz_answer' && _isQuizAnswerExpired()) return;

    final key =
        '${questionId ?? state.session?.currentTurn?.turnId ?? state.session?.lastSeq}-$inputType-$optionId';
    if (state.pendingInputKeys.contains(key)) return;

    final optimisticSetupEvent = _optimisticGroupSetupEvent(
      state.session,
      optionId,
      key,
    );
    final optimisticSession = _sessionWithOptimisticGroupSetup(
      state.session,
      optionId,
      key,
      optimisticSetupEvent,
    );

    state = state.copyWith(
      session: optimisticSession,
      pendingInputKeys: {...state.pendingInputKeys, key},
      localQuizSelections: inputType == 'quiz_answer' && questionId != null
          ? {...state.localQuizSelections, questionId: optionId}
          : state.localQuizSelections,
      streamingAssistantText: null,
      recentStreamedAssistantText: null,
      error: null,
    );

    try {
      final repo = ref.read(storiesRepositoryProvider);
      final requestMetadata = <String, dynamic>{
        if (inputType == 'option_select')
          ..._guidedAspectExpectationMetadata(state.session),
        if (displayText != null && displayText.trim().isNotEmpty)
          'display_text': displayText.trim(),
      };
      final response = await repo.submitInteractiveInput(
        sessionId: sessionId,
        input: InteractiveInput(
          inputType: inputType,
          questionId: questionId,
          optionId: optionId,
          metadata: requestMetadata,
          idempotencyKey: key,
        ),
      );
      if (_isDisposed) return;
      final current = state.session;
      if (current == null || current.sessionId != sessionId) return;
      final canonicalBase =
          _sessionWithoutOptimisticEvent(current, key) ?? current;
      final mergedSession = _mergeResponseIntoSession(canonicalBase, response);
      final streamedText = state.streamingAssistantText?.trim();
      state = state.copyWith(
        session: mergedSession,
        pendingInputKeys: {...state.pendingInputKeys}..remove(key),
        pendingTextMessages: _pendingTextMessagesExcluding(key),
        streamingAssistantText: null,
        recentStreamedAssistantText:
            streamedText == null || streamedText.isEmpty
            ? _unset
            : streamedText,
      );
      _scheduleWaitingRefresh();
    } on ApiError catch (e) {
      if (_isDisposed) return;
      if (e.statusCode == 409) {
        final nextSelections = Map<String, String>.from(
          state.localQuizSelections,
        );
        if (inputType == 'quiz_answer' && questionId != null) {
          nextSelections.remove(questionId);
        }
        state = state.copyWith(
          pendingInputKeys: {...state.pendingInputKeys}..remove(key),
          pendingTextMessages: _pendingTextMessagesExcluding(key),
          session: _sessionWithoutOptimisticEvent(state.session, key),
          localQuizSelections: nextSelections,
          streamingAssistantText: null,
          error: null,
        );
        await _refreshSilently();
        return;
      }
      state = state.copyWith(
        pendingInputKeys: {...state.pendingInputKeys}..remove(key),
        pendingTextMessages: _pendingTextMessagesExcluding(key),
        session: _sessionWithoutOptimisticEvent(state.session, key),
        streamingAssistantText: null,
        error: e.message,
      );
    } catch (e) {
      if (_isDisposed) return;
      state = state.copyWith(
        pendingInputKeys: {...state.pendingInputKeys}..remove(key),
        pendingTextMessages: _pendingTextMessagesExcluding(key),
        session: _sessionWithoutOptimisticEvent(state.session, key),
        streamingAssistantText: null,
        error: '$e',
      );
    }
  }

  Future<void> submitText(
    String text, {
    String inputType = 'text',
    Map<String, dynamic> metadata = const <String, dynamic>{},
  }) async {
    final sessionId = state.session?.sessionId;
    final trimmed = text.trim();
    if (sessionId == null ||
        sessionId.isEmpty ||
        trimmed.isEmpty ||
        !_canMutateCurrentSession) {
      return;
    }
    final key =
        '${state.session?.currentTurn?.turnId ?? state.session?.lastSeq}-text-${DateTime.now().millisecondsSinceEpoch}';
    final optimisticSetupEvent = _optimisticGroupSetupEvent(
      state.session,
      trimmed,
      key,
    );
    final optimisticSession = _sessionWithOptimisticGroupSetup(
      state.session,
      trimmed,
      key,
      optimisticSetupEvent,
    );

    state = state.copyWith(
      session: optimisticSession,
      pendingInputKeys: {...state.pendingInputKeys, key},
      pendingTextMessages: optimisticSetupEvent == null
          ? [
              ...state.pendingTextMessages,
              PendingInteractiveTextMessage(clientId: key, text: trimmed),
            ]
          : state.pendingTextMessages,
      streamingAssistantText: null,
      recentStreamedAssistantText: null,
      error: null,
    );

    try {
      final repo = ref.read(storiesRepositoryProvider);
      final requestMetadata = <String, dynamic>{
        ..._guidedAspectExpectationMetadata(state.session),
        ...metadata,
      };
      final response = await repo.submitInteractiveInput(
        sessionId: sessionId,
        input: InteractiveInput(
          inputType: inputType,
          text: trimmed,
          metadata: requestMetadata,
          idempotencyKey: key,
        ),
      );
      if (_isDisposed) return;
      final current = state.session;
      if (current == null || current.sessionId != sessionId) return;
      final canonicalBase =
          _sessionWithoutOptimisticEvent(current, key) ?? current;
      final mergedSession = _mergeResponseIntoSession(canonicalBase, response);
      final streamedText = state.streamingAssistantText?.trim();
      state = state.copyWith(
        session: mergedSession,
        pendingInputKeys: {...state.pendingInputKeys}..remove(key),
        pendingTextMessages: _pendingTextMessagesExcluding(key),
        streamingAssistantText: null,
        recentStreamedAssistantText:
            streamedText == null || streamedText.isEmpty
            ? _unset
            : streamedText,
      );
      _scheduleWaitingRefresh();
    } on ApiError catch (e) {
      if (_isDisposed) return;
      state = state.copyWith(
        pendingInputKeys: {...state.pendingInputKeys}..remove(key),
        pendingTextMessages: _pendingTextMessagesExcluding(key),
        session: _sessionWithoutOptimisticEvent(state.session, key),
        streamingAssistantText: null,
        error: e.message,
      );
    } catch (e) {
      if (_isDisposed) return;
      state = state.copyWith(
        pendingInputKeys: {...state.pendingInputKeys}..remove(key),
        pendingTextMessages: _pendingTextMessagesExcluding(key),
        session: _sessionWithoutOptimisticEvent(state.session, key),
        streamingAssistantText: null,
        error: '$e',
      );
    }
  }

  Future<void> submitPlayerChat(String text) async {
    final sessionId = state.session?.sessionId;
    final trimmed = text.trim();
    if (sessionId == null ||
        sessionId.isEmpty ||
        trimmed.isEmpty ||
        !_canSubmitPlayerChat) {
      return;
    }
    final key =
        '${state.session?.lastSeq ?? 0}-player_chat-${DateTime.now().millisecondsSinceEpoch}';
    final pendingMessage = PendingInteractiveTextMessage(
      clientId: key,
      text: trimmed,
    );

    state = state.copyWith(
      pendingInputKeys: {...state.pendingInputKeys, key},
      pendingTextMessages: [...state.pendingTextMessages, pendingMessage],
      error: null,
    );

    try {
      final repo = ref.read(storiesRepositoryProvider);
      final response = await repo.submitInteractiveInput(
        sessionId: sessionId,
        input: InteractiveInput(
          inputType: 'player_chat',
          text: trimmed,
          idempotencyKey: key,
        ),
      );
      if (_isDisposed) return;
      final current = state.session;
      if (current == null) return;
      state = state.copyWith(
        session: _mergeResponseIntoSession(current, response),
        pendingInputKeys: {...state.pendingInputKeys}..remove(key),
        pendingTextMessages: _pendingTextMessagesExcluding(key),
      );
    } on ApiError catch (e) {
      if (_isDisposed) return;
      state = state.copyWith(
        pendingInputKeys: {...state.pendingInputKeys}..remove(key),
        pendingTextMessages: _pendingTextMessagesExcluding(key),
        error: e.message,
      );
    } catch (e) {
      if (_isDisposed) return;
      state = state.copyWith(
        pendingInputKeys: {...state.pendingInputKeys}..remove(key),
        pendingTextMessages: _pendingTextMessagesExcluding(key),
        error: '$e',
      );
    }
  }

  void clear() {
    unawaited(_disconnectRoomSocket());
    state = const InteractiveStoryState();
  }

  void clearError() {
    state = state.copyWith(error: null);
  }

  bool get _canMutateCurrentSession {
    final session = state.session;
    return session != null && !state.isReadOnly && !session.isCompleted;
  }

  bool get _canSubmitPlayerChat {
    final session = state.session;
    if (session == null || state.isReadOnly) return false;
    return !session.isCompleted || _isCompletedGroupChatRoom(session);
  }

  Future<void> _connectRoomSocket(String sessionId) async {
    if (_isDisposed) return;
    if (sessionId.isEmpty) return;
    final session = state.session;
    if (state.isReadOnly ||
        session == null ||
        session.sessionId != sessionId ||
        (session.isCompleted && !_isCompletedGroupChatRoom(session))) {
      return;
    }
    final token =
        ref.read(authControllerProvider.notifier).tokens?.accessToken ?? '';
    if (token.isEmpty) return;
    final url = _roomSocketUrl(sessionId, token);
    if (url.isEmpty) return;

    await _disconnectRoomSocket();
    IOWebSocketChannel? channel;
    try {
      channel = IOWebSocketChannel.connect(Uri.parse(url));
      await channel.ready.timeout(_socketConnectTimeout);
      if (_isDisposed) {
        try {
          await channel.sink.close(ws_status.normalClosure, 'dispose');
        } catch (_) {}
        return;
      }
      _roomChannel = channel;
      _roomSubscription = channel.stream.listen(
        _handleRoomSocketMessage,
        onError: (_) {
          if (_isDisposed) return;
          _roomChannel = null;
          _roomSubscription = null;
          _scheduleWaitingRefresh();
        },
        onDone: () {
          if (_isDisposed) return;
          _roomChannel = null;
          _roomSubscription = null;
          _scheduleWaitingRefresh();
        },
      );
    } catch (_) {
      try {
        await channel?.sink.close(ws_status.normalClosure, 'connect_error');
      } catch (_) {}
      if (_isDisposed) return;
      _roomChannel = null;
      _roomSubscription = null;
      _scheduleWaitingRefresh();
    }
  }

  Future<void> _disconnectRoomSocket() async {
    _refreshTimer?.cancel();
    _refreshTimer = null;
    await _roomSubscription?.cancel();
    _roomSubscription = null;
    try {
      await _roomChannel?.sink.close(ws_status.normalClosure, 'dispose');
    } catch (_) {}
    _roomChannel = null;
  }

  String _roomSocketUrl(String sessionId, String token) {
    final api = AppEnv.apiBaseUrl.trim();
    if (api.isEmpty) return '';
    final parsed = Uri.tryParse(api);
    if (parsed == null) return '';
    final scheme = switch (parsed.scheme) {
      'https' => 'wss',
      'http' => 'ws',
      'wss' => 'wss',
      'ws' => 'ws',
      _ => parsed.scheme.isEmpty ? 'wss' : parsed.scheme,
    };
    final base = parsed.scheme.isEmpty
        ? Uri.parse('wss://$api')
        : parsed.replace(scheme: scheme, query: '', fragment: '');
    final baseSegments = base.pathSegments.where(
      (segment) => segment.isNotEmpty,
    );
    final uri = base.replace(
      pathSegments: [...baseSegments, 'ws', 'story-sessions', sessionId],
    );
    return uri
        .replace(queryParameters: {'token': token, 'device_id': _deviceId})
        .toString();
  }

  void _handleRoomSocketMessage(dynamic data) {
    if (_isDisposed) return;
    if (state.isReadOnly ||
        (state.session?.isCompleted == true &&
            !_isCompletedGroupChatRoom(state.session))) {
      return;
    }
    if (data is! String) return;
    final decoded = jsonDecode(data);
    if (decoded is! Map) return;
    final message = decoded.cast<String, dynamic>();
    final type = message['type'] as String?;
    final payload = (message['data'] as Map?)?.cast<String, dynamic>();
    if (payload == null) return;

    if (type == 'room_state') {
      final snapshot = payload['snapshot'];
      if (snapshot is Map) {
        _applyRoomSnapshot(
          InteractiveSessionState.fromJson(snapshot.cast<String, dynamic>()),
        );
      }
      return;
    }

    if (type != 'room_event') return;
    _applyRoomEvent(payload);
  }

  void _applyRoomSnapshot(InteractiveSessionState session) {
    if (_isDisposed || _isOlderSessionSnapshot(session)) return;
    final normalizedSession = _normalizeSessionSnapshot(session);
    final isReadOnly = _isReadOnlyInteractiveSession(normalizedSession);
    state = state.copyWith(
      session: normalizedSession,
      isReadOnly: isReadOnly,
      isRetryingGeneration:
          !isReadOnly &&
          state.isRetryingGeneration &&
          _shouldKeepGenerationRetryOverlay(normalizedSession),
    );
    if (isReadOnly) {
      _resetGenerationWatchdog(clearSlowState: true);
      unawaited(_disconnectRoomSocket());
      return;
    }
    _scheduleWaitingRefresh();
  }

  void applyRoomSnapshotForTest(InteractiveSessionState session) {
    _applyRoomSnapshot(session);
  }

  void _applyRoomEvent(Map<String, dynamic> event) {
    if (_isDisposed) return;
    final current = state.session;
    if (current == null) return;
    final eventType = (event['event_type'] as String?)?.trim() ?? '';
    final payload =
        (event['payload'] as Map?)?.cast<String, dynamic>() ??
        <String, dynamic>{};
    if (eventType == 'solo_assistant_stream') {
      final text = (payload['text'] as String?)?.trim();
      state = state.copyWith(
        streamingAssistantText: text == null || text.isEmpty ? null : text,
        recentStreamedAssistantText: null,
      );
      return;
    }
    final seq = (event['seq'] as num?)?.toInt() ?? current.lastSeq;
    if (seq <= current.lastSeq) return;
    final nextState = Map<String, dynamic>.from(current.interactiveState);
    InteractiveTurn? nextTurn = current.currentTurn;
    String? recentStreamedAssistantText;

    switch (eventType) {
      case 'topic_selection_started':
        nextState
          ..['template'] = 'quiz'
          ..['phase'] = 'topic_selection'
          ..['topic_prompt'] = payload['prompt']
          ..['topic_prompt_status'] = 'ready';
        break;
      case 'topic_candidate_selected':
        _consumePendingTopicSelection(payload);
        _mergeTopicSelectionState(nextState, payload);
        nextState
          ..['template'] = 'quiz'
          ..['phase'] = 'topic_selection'
          ..['topic_selection_stage'] =
              payload['topic_selection_stage'] ?? 'aspect';
        _markTopicAspectGenerationPending(nextState, payload);
        break;
      case 'topic_aspect_selected':
        _consumePendingTopicSelection(payload);
        _mergeTopicSelectionState(nextState, payload);
        nextState
          ..['template'] = 'quiz'
          ..['phase'] = payload['phase'] ?? 'topic_selection'
          ..['topic_selection_stage'] =
              payload['topic_selection_stage'] ??
              nextState['topic_selection_stage'] ??
              'aspect';
        final aspectAction = (payload['action'] ?? payload['option_id'])
            ?.toString()
            .trim()
            .toLowerCase();
        if (aspectAction == 'continue_with_topic') {
          nextState
            ..['topic_path_actions_expanded'] = true
            ..['allow_custom_aspect'] = false;
        } else if (aspectAction == 'choose_aspect') {
          nextState
            ..['topic_path_actions_expanded'] = false
            ..['allow_custom_aspect'] = true;
        } else {
          _markTopicAspectGenerationPending(nextState, payload);
        }
        break;
      case 'topic_selected':
        _consumePendingTopicSelection(payload);
        _mergeTopicSelectionState(nextState, payload);
        nextState['selected_topic'] =
            payload['topic'] ?? nextState['selected_topic'];
        final topicAction = (payload['action'] ?? payload['option_id'])
            ?.toString()
            .trim()
            .toLowerCase();
        if (topicAction == 'quiz' || topicAction == 'chat') {
          nextState['phase'] = topicAction == 'quiz'
              ? 'timer_selection'
              : 'discussion';
          final topicPath = payload['topic_path'];
          if (topicPath is List) {
            nextState['selected_topic_path'] = topicPath;
          }
          _clearTopicAspectWorkingState(nextState);
        }
        break;
      case 'solo_user_message':
        _consumePendingTextByValue(payload['text'] as String?);
        break;
      case 'player_chat_message':
        final clientId = payload['client_id'] as String?;
        if (clientId != null && clientId.isNotEmpty) {
          _consumePendingTextByClientId(clientId);
        } else {
          _consumePendingTextByValue(payload['text'] as String?);
        }
        break;
      case 'interactive_turn':
        recentStreamedAssistantText = state.streamingAssistantText?.trim();
        nextTurn = InteractiveTurn.fromJson(payload);
        nextState.addAll(nextTurn.statePatch);
        break;
      case 'question_generation_started':
        nextState
          ..['phase'] = 'generating_question'
          ..['selected_topic'] = payload['topic'] ?? nextState['selected_topic']
          ..['current_round'] =
              (payload['round'] as num?)?.toInt() ?? nextState['current_round']
          ..['question'] = null
          ..['result'] = null;
        nextState.remove('generation_error');
        break;
      case 'generation_failed':
        nextState
          ..['phase'] = 'generation_failed'
          ..['current_round'] =
              (payload['round'] as num?)?.toInt() ?? nextState['current_round']
          ..['generation_error'] =
              payload['message'] ??
              payload['error'] ??
              nextState['generation_error'] ??
              'Question generation failed. The host can retry.'
          ..['current_question_id'] = null
          ..['question'] = null
          ..['expires_at'] = null;
        break;
      case 'quiz_waiting_for_players':
        nextState
          ..['phase'] = 'waiting_for_players'
          ..['waiting_round'] = payload['round']
          ..['waiting_reason'] = payload['reason']
          ..['question'] = null;
        break;
      case 'question_started':
        final question = payload['question'];
        if (question is Map) {
          nextState
            ..['phase'] = 'question_active'
            ..['question'] = question.cast<String, dynamic>()
            ..['current_question_id'] =
                (question['question_id'] as String?) ??
                nextState['current_question_id']
            ..['eligible_participant_ids'] =
                payload['eligible_participant_ids'] ??
                nextState['eligible_participant_ids']
            ..['answered_participant_ids'] = <String>[]
            ..['expires_at'] =
                question['expires_at'] ?? nextState['expires_at'];
          nextState['answered_count'] =
              payload['answered_count'] ?? nextState['answered_count'] ?? 0;
          nextState['eligible_count'] =
              payload['eligible_count'] ??
              nextState['eligible_count'] ??
              ((nextState['eligible_participant_ids'] as List?)?.length ?? 0);
          nextState['scores'] = payload['scores'] ?? nextState['scores'];
          nextState.remove('generation_error');
        }
        break;
      case 'answer_received':
        final participantId = payload['participant_id'] as String?;
        final answered = [
          ...((nextState['answered_participant_ids'] as List?) ?? const []),
          if (participantId != null) participantId,
        ];
        final answeredIds = answered.toSet().toList();
        nextState['answered_participant_ids'] = answeredIds;
        nextState['answered_count'] =
            payload['answered_count'] ?? answeredIds.length;
        nextState['eligible_count'] =
            payload['eligible_count'] ?? nextState['eligible_count'];
        break;
      case 'question_completed':
        nextState
          ..['phase'] = 'showing_results'
          ..['result'] = payload;
        nextState['scores'] = payload['scores'] ?? nextState['scores'];
        nextState['score_delta'] =
            payload['score_delta'] ?? nextState['score_delta'];
        nextState['standings'] = payload['standings'] ?? nextState['standings'];
        break;
      case 'scoreboard_updated':
        nextState['scores'] = payload['scores'] ?? nextState['scores'];
        nextState['score_delta'] =
            payload['score_delta'] ?? nextState['score_delta'];
        nextState['standings'] = payload['standings'] ?? nextState['standings'];
        break;
      case 'session_completed':
        nextState
          ..['phase'] = 'completed'
          ..['final_standings'] = payload['final_standings']
          ..['winner_participant_ids'] = payload['winner_participant_ids'];
        break;
      default:
        return;
    }

    final sessionEvent = StorySessionEvent(
      id: '${current.sessionId}-$seq-$eventType',
      sessionId: current.sessionId,
      seq: seq,
      actorType: 'system',
      eventType: eventType,
      payload: payload,
    );
    final nextEvents =
        current.events.any(
          (event) => event.seq == seq && event.eventType == eventType,
        )
        ? current.events
        : [...current.events, sessionEvent];
    final didComplete = eventType == 'session_completed';
    final nextSession = _normalizeSessionSnapshot(
      current.copyWith(
        interactiveState: nextState,
        events: nextEvents,
        currentTurn: nextTurn,
        lastSeq: seq > current.lastSeq ? seq : current.lastSeq,
        isCompleted: didComplete ? true : null,
        isPaused: didComplete ? false : null,
      ),
    );
    final isReadOnly = _isReadOnlyInteractiveSession(nextSession);
    state = state.copyWith(
      session: nextSession,
      isReadOnly: didComplete ? isReadOnly : state.isReadOnly,
      isRetryingGeneration:
          !didComplete &&
          state.isRetryingGeneration &&
          _shouldKeepGenerationRetryOverlay(nextSession),
      streamingAssistantText: eventType == 'interactive_turn'
          ? null
          : state.streamingAssistantText,
      recentStreamedAssistantText:
          recentStreamedAssistantText == null ||
              recentStreamedAssistantText.isEmpty
          ? _unset
          : recentStreamedAssistantText,
    );
    if (didComplete) {
      _resetGenerationWatchdog(clearSlowState: true);
      if (isReadOnly) {
        unawaited(_disconnectRoomSocket());
      }
      return;
    }
    _scheduleWaitingRefresh();
  }

  void applyRoomEventForTest(Map<String, dynamic> event) {
    _applyRoomEvent(event);
  }

  void _scheduleWaitingRefresh() {
    if (_isDisposed) return;
    _refreshTimer?.cancel();
    final session = state.session;
    _syncGenerationWatchdog(session);
    if (state.isReadOnly || session == null || session.isCompleted) return;
    final phase = session.interactiveState['phase'] as String?;
    final topicPromptStatus =
        session.interactiveState['topic_prompt_status'] as String?;
    final topicSelectionStage =
        session.interactiveState['topic_selection_stage'] as String?;
    final topicAspectStatus =
        session.interactiveState['topic_aspect_status'] as String?;
    final hasQuestion = session.interactiveState['question'] is Map;
    if (phase == 'question_active') {
      final expiresAt = _parseStateDate(session.interactiveState['expires_at']);
      final delay = _expiryRefreshDelay(expiresAt);
      _refreshTimer = Timer(delay, () {
        if (_isDisposed) return;
        unawaited(_refreshSilently());
      });
      return;
    }
    final shouldPoll =
        phase == 'generating_question' ||
        phase == 'question_generation_started' ||
        phase == 'generation_failed' ||
        (phase == 'topic_selection' && topicPromptStatus == 'generating') ||
        (phase == 'topic_selection' &&
            topicSelectionStage == 'aspect' &&
            (topicAspectStatus == 'generating' ||
                topicAspectStatus == 'loading')) ||
        phase == 'finalizing_question' ||
        phase == 'showing_results' ||
        (!hasQuestion && session.currentTurn == null);
    if (!shouldPoll) return;
    _refreshTimer = Timer(const Duration(seconds: 2), () {
      if (_isDisposed) return;
      unawaited(_refreshSilently());
    });
  }

  Future<void> _refreshSilently() async {
    if (_isDisposed) return;
    if (state.isReadOnly || state.session?.isCompleted == true) return;
    final sessionId = state.session?.sessionId;
    if (sessionId == null || sessionId.isEmpty) return;
    try {
      final repo = ref.read(storiesRepositoryProvider);
      final session = await repo.fetchInteractiveSession(sessionId);
      if (_isDisposed) return;
      if (state.session?.sessionId != sessionId) return;
      if (_isOlderSessionSnapshot(session)) return;
      final normalizedSession = _normalizeSessionSnapshot(session);
      final isReadOnly = _isReadOnlyInteractiveSession(normalizedSession);
      state = state.copyWith(
        session: normalizedSession,
        isReadOnly: isReadOnly,
        isRetryingGeneration:
            !isReadOnly &&
            state.isRetryingGeneration &&
            _shouldKeepGenerationRetryOverlay(normalizedSession),
      );
      if (isReadOnly) {
        _resetGenerationWatchdog(clearSlowState: true);
        unawaited(_disconnectRoomSocket());
      }
    } catch (_) {
      // Keep the current UI state and try again while it is still waiting.
    } finally {
      if (!_isDisposed) {
        _scheduleWaitingRefresh();
      }
    }
  }

  void _syncGenerationWatchdog(InteractiveSessionState? session) {
    final phase = session?.interactiveState['phase'] as String?;
    final isGenerating =
        phase == 'generating_question' ||
        phase == 'question_generation_started';
    if (session == null || !isGenerating) {
      _resetGenerationWatchdog(clearSlowState: true);
      return;
    }

    final round = session.interactiveState['current_round'];
    final key = '${session.sessionId}:${round ?? 'unknown'}';
    if (_generationWatchdogKey == key) return;

    _generationWatchdogTimer?.cancel();
    _generationWatchdogKey = key;
    if (state.isGenerationTakingLong) {
      state = state.copyWith(isGenerationTakingLong: false);
    }
    final requestedAt = _parseStateDate(
      session.interactiveState['generation_requested_at'],
    );
    final elapsed = requestedAt == null
        ? Duration.zero
        : DateTime.now().toUtc().difference(requestedAt);
    final remaining = generationSlowThreshold - elapsed;
    final watchdogDelay = remaining.isNegative ? Duration.zero : remaining;
    _generationWatchdogTimer = Timer(watchdogDelay, () {
      if (_isDisposed || _generationWatchdogKey != key) return;
      final current = state.session;
      final currentPhase = current?.interactiveState['phase'] as String?;
      final currentRound = current?.interactiveState['current_round'];
      if (current?.sessionId != session.sessionId ||
          currentRound != round ||
          (currentPhase != 'generating_question' &&
              currentPhase != 'question_generation_started')) {
        return;
      }
      state = state.copyWith(isGenerationTakingLong: true);
    });
  }

  void _resetGenerationWatchdog({bool clearSlowState = false}) {
    _generationWatchdogTimer?.cancel();
    _generationWatchdogTimer = null;
    _generationWatchdogKey = null;
    if (clearSlowState && state.isGenerationTakingLong) {
      state = state.copyWith(isGenerationTakingLong: false);
    }
  }

  Duration _expiryRefreshDelay(DateTime? expiresAt) {
    if (expiresAt == null) return const Duration(seconds: 2);
    final remaining = expiresAt.difference(DateTime.now().toUtc());
    if (remaining.isNegative) return const Duration(milliseconds: 500);
    return remaining + const Duration(milliseconds: 800);
  }

  bool _isQuizAnswerExpired() {
    final session = state.session;
    if (session == null) return true;
    final interactiveState = session.interactiveState;
    if (interactiveState['phase'] != 'question_active') return false;

    final question = interactiveState['question'];
    final questionExpiresAt = question is Map ? question['expires_at'] : null;
    final expiresAt =
        _parseStateDate(questionExpiresAt) ??
        _parseStateDate(interactiveState['expires_at']);
    if (expiresAt == null) return false;
    return !expiresAt.isAfter(DateTime.now().toUtc());
  }

  DateTime? _parseStateDate(dynamic raw) {
    if (raw is String && raw.trim().isNotEmpty) {
      final value = raw.trim();
      final hasTimezone = RegExp(r'(Z|[+-]\d\d:\d\d)$').hasMatch(value);
      return DateTime.tryParse(hasTimezone ? value : '${value}Z')?.toUtc();
    }
    return null;
  }

  bool _shouldKeepGenerationRetryOverlay(InteractiveSessionState? session) {
    final phase = session?.interactiveState['phase'] as String?;
    return phase == 'generating_question' ||
        phase == 'question_generation_started';
  }

  InteractiveSessionState _mergeResponseIntoSession(
    InteractiveSessionState current,
    InteractiveInputResponse response,
  ) {
    final nextEvents = [...current.events];
    if (!_hasEvent(nextEvents, response.event.seq, response.event.eventType)) {
      nextEvents.add(response.event);
    }
    if (response.turn != null &&
        !_hasEvent(nextEvents, response.turn!.seq, 'interactive_turn')) {
      nextEvents.add(
        StorySessionEvent(
          id: response.turn!.turnId,
          sessionId: current.sessionId,
          seq: response.turn!.seq,
          actorType: 'ai',
          eventType: 'interactive_turn',
          payload: response.turn!.toJson(),
        ),
      );
    }
    final responseSeq = response.turn?.seq ?? response.event.seq;
    final currentTurn = current.currentTurn;
    final nextTurn = switch ((currentTurn, response.turn)) {
      (InteractiveTurn existing, InteractiveTurn incoming)
          when existing.seq > incoming.seq =>
        existing,
      (_, InteractiveTurn incoming) => incoming,
      _ => currentTurn,
    };
    return _normalizeSessionSnapshot(
      current.copyWith(
        interactiveState: responseSeq >= current.lastSeq
            ? response.state
            : current.interactiveState,
        events: nextEvents,
        currentTurn: nextTurn,
        lastSeq: responseSeq > current.lastSeq ? responseSeq : current.lastSeq,
      ),
    );
  }

  StorySessionEvent? _optimisticGroupSetupEvent(
    InteractiveSessionState? session,
    String optionId,
    String clientId,
  ) {
    if (session == null) return null;
    final interactiveState = session.interactiveState;
    if (interactiveState['session_type'] != 'group' ||
        interactiveState['template'] != 'quiz' ||
        (interactiveState['phase'] != 'group_setup' &&
            interactiveState['phase'] != 'group_setup_review')) {
      return null;
    }
    final stage =
        interactiveState['group_setup_stage']?.toString().trim() ??
        'question_source';
    final displayText = _setupOptionDisplayText(session.currentTurn, optionId);
    final nextSeq = session.lastSeq + 1;
    return StorySessionEvent(
      id: 'local-$clientId',
      sessionId: session.sessionId,
      seq: nextSeq,
      actorType: 'user',
      eventType: 'setup_choice_selected',
      payload: {
        'stage': stage,
        'option_id': optionId,
        'text': displayText,
        'participant_text': _setupParticipantText(
          stage: stage,
          optionId: optionId,
          displayText: displayText,
        ),
        'client_id': clientId,
      },
    );
  }

  InteractiveSessionState? _sessionWithOptimisticGroupSetup(
    InteractiveSessionState? session,
    String optionId,
    String clientId,
    StorySessionEvent? setupEvent,
  ) {
    if (session == null || setupEvent == null) return session;
    final aiEvent = _optimisticGroupSetupAiEvent(
      session,
      optionId,
      clientId,
      setupEvent.seq + 1,
    );
    final events = [...session.events, setupEvent];
    var lastSeq = setupEvent.seq > session.lastSeq
        ? setupEvent.seq
        : session.lastSeq;
    var interactiveState = session.interactiveState;
    InteractiveTurn? currentTurn = session.currentTurn;
    if (aiEvent != null) {
      events.add(aiEvent);
      lastSeq = aiEvent.seq > lastSeq ? aiEvent.seq : lastSeq;
      final optimisticTurn = InteractiveTurn.fromJson(aiEvent.payload);
      currentTurn = optimisticTurn;
      interactiveState = {
        ...interactiveState,
        ...optimisticTurn.statePatch,
        'current_turn_id': optimisticTurn.turnId,
      };
    }
    return session.copyWith(
      interactiveState: interactiveState,
      events: events,
      currentTurn: currentTurn,
      lastSeq: lastSeq,
    );
  }

  StorySessionEvent? _optimisticGroupSetupAiEvent(
    InteractiveSessionState session,
    String optionId,
    String clientId,
    int seq,
  ) {
    final interactiveState = session.interactiveState;
    final stage =
        interactiveState['group_setup_stage']?.toString().trim() ??
        'topic_subject';
    final normalized = optionId.trim().toLowerCase();
    final displayText = _setupOptionDisplayText(session.currentTurn, optionId);
    List<InteractiveBlock> blocks;
    Map<String, dynamic> statePatch;
    if (stage == 'topic_subject') {
      final selectedTopic = normalized == 'any_topic'
          ? 'Any topic'
          : displayText;
      blocks = [
        InteractiveTextBlock(text: 'Great, we will focus on $selectedTopic.'),
        const InteractiveTextBlock(
          text: 'Should this group quiz be timed or untimed?',
        ),
        _optimisticGroupSetupChoiceBlock('round_timer', session.currentTurn),
      ];
      statePatch = {
        'phase': 'group_setup',
        'group_setup_stage': 'round_timer',
        'selected_topic': selectedTopic,
      };
    } else if (stage == 'round_timer') {
      final timerEnabled = normalized == 'timed' || normalized == 'timer';
      final label = timerEnabled ? 'Timed' : 'Untimed';
      blocks = [
        InteractiveTextBlock(text: '$label it is.'),
        const InteractiveTextBlock(
          text: 'How many questions should this quiz have?',
        ),
        _optimisticGroupSetupChoiceBlock('question_count', session.currentTurn),
      ];
      statePatch = {
        'phase': 'group_setup',
        'group_setup_stage': 'question_count',
        'quiz_timer_enabled': timerEnabled,
      };
    } else if (stage == 'question_count') {
      final questionCount = _setupQuestionCount(optionId);
      if (questionCount == null) return null;
      blocks = [
        InteractiveTextBlock(
          text:
              '$questionCount questions it is. Here is the game setup before we start.',
        ),
        InteractiveTextBlock(
          text: _optimisticGroupSetupSummary({
            ...interactiveState,
            'total_rounds': questionCount,
          }),
        ),
        _optimisticGroupSetupChoiceBlock('review', session.currentTurn),
      ];
      statePatch = {
        ...interactiveState,
        'phase': 'group_setup',
        'group_setup_stage': 'review',
        'total_rounds': questionCount,
      };
    } else if (stage == 'review') {
      if (normalized == 'edit_setup' || normalized == 'edit') {
        blocks = [
          const InteractiveTextBlock(
            text: "No problem. Let's update the setup.",
          ),
          const InteractiveTextBlock(
            text: 'What topic should this group quiz focus on?',
          ),
          _optimisticGroupSetupChoiceBlock(
            'topic_subject',
            session.currentTurn,
          ),
        ];
        statePatch = {
          ...interactiveState,
          'phase': 'group_setup',
          'group_setup_stage': 'topic_subject',
          'selected_topic': null,
          'quiz_timer_enabled': null,
          'total_rounds': null,
          'quiz_setup_complete': false,
        };
      } else {
        blocks = [
          const InteractiveTextBlock(
            text: 'Perfect. Give me a second to line up the first question.',
          ),
        ];
        statePatch = {
          ...interactiveState,
          'phase': 'generating_question',
          'group_setup_stage': 'complete',
          'quiz_setup_complete': true,
          'current_question_id': null,
          'eligible_participant_ids': const <String>[],
          'answered_participant_ids': const <String>[],
          'expires_at': null,
          'question': null,
          'result': null,
          'generation_error': null,
          'generation_requested_at': DateTime.now().toUtc().toIso8601String(),
        };
      }
    } else {
      return null;
    }

    final turn = InteractiveTurn(
      type: 'interactive_turn.v1',
      sessionId: session.sessionId,
      turnId: 'local-$clientId-ai',
      seq: seq,
      speaker: InteractiveSpeaker(
        role: session.aiRole,
        displayName: session.aiRole,
      ),
      blocks: blocks,
      statePatch: statePatch,
    );
    return StorySessionEvent(
      id: 'local-$clientId-ai-event',
      sessionId: session.sessionId,
      seq: seq,
      actorType: 'ai',
      eventType: 'interactive_turn',
      payload: {...turn.toJson(), 'client_id': clientId},
    );
  }

  static InteractiveChoiceGroupBlock _optimisticGroupSetupChoiceBlock(
    String stage,
    InteractiveTurn? currentTurn,
  ) {
    if (stage == 'round_timer') {
      return const InteractiveChoiceGroupBlock(
        prompt: 'Should this group quiz be timed?',
        options: [
          InteractiveOption(id: 'timed', label: 'Timed'),
          InteractiveOption(id: 'untimed', label: 'Untimed'),
        ],
        metadata: {
          'choice_kind': 'group_quiz_setup',
          'setup_stage': 'round_timer',
        },
      );
    }
    if (stage == 'question_count') {
      return const InteractiveChoiceGroupBlock(
        prompt: 'How many questions should this quiz have?',
        options: [
          InteractiveOption(id: '5', label: '5 questions'),
          InteractiveOption(id: '10', label: '10 questions'),
          InteractiveOption(id: '15', label: '15 questions'),
        ],
        metadata: {
          'choice_kind': 'group_quiz_setup',
          'setup_stage': 'question_count',
        },
      );
    }
    if (stage == 'review') {
      return const InteractiveChoiceGroupBlock(
        prompt: 'Ready to start?',
        options: [
          InteractiveOption(id: 'start_game', label: 'Start game'),
          InteractiveOption(id: 'edit_setup', label: 'Edit setup'),
        ],
        metadata: {'choice_kind': 'group_quiz_setup', 'setup_stage': 'review'},
      );
    }
    for (final block in currentTurn?.blocks ?? const <InteractiveBlock>[]) {
      if (block is InteractiveChoiceGroupBlock &&
          block.metadata['choice_kind'] == 'group_quiz_setup') {
        return block;
      }
    }
    return const InteractiveChoiceGroupBlock(
      prompt: 'What topic should this group quiz focus on?',
      options: [InteractiveOption(id: 'any_topic', label: 'Any topic')],
      metadata: {
        'choice_kind': 'group_quiz_setup',
        'setup_stage': 'topic_subject',
      },
    );
  }

  String _optimisticGroupSetupSummary(Map<String, dynamic> state) {
    final topic = state['selected_topic']?.toString().trim().isNotEmpty == true
        ? state['selected_topic'].toString().trim()
        : 'Any topic';
    final mode = state['quiz_timer_enabled'] == true ? 'Timed' : 'Untimed';
    final count = _setupQuestionCount(state['total_rounds']?.toString() ?? '');
    final total = count ?? 5;
    final questionLabel = total == 1 ? 'question' : 'questions';
    return 'Game setup summary:\n'
        'Topic: $topic\n'
        'Mode: $mode\n'
        'Length: $total $questionLabel';
  }

  String _setupOptionDisplayText(InteractiveTurn? turn, String optionId) {
    for (final block in turn?.blocks ?? const <InteractiveBlock>[]) {
      if (block is! InteractiveChoiceGroupBlock) continue;
      if (block.metadata['choice_kind'] != 'group_quiz_setup') continue;
      for (final option in block.options) {
        if (option.id == optionId) {
          return option.label.isEmpty ? option.id : option.label;
        }
      }
    }
    return optionId.replaceAll('_', ' ');
  }

  int? _setupQuestionCount(String optionId) {
    final digits = RegExp(r'\d+').stringMatch(optionId);
    if (digits == null) return null;
    final parsed = int.tryParse(digits);
    if (parsed == null) return null;
    return parsed.clamp(1, 20);
  }

  String _setupParticipantText({
    required String stage,
    required String optionId,
    required String displayText,
  }) {
    if (stage == 'question_source') {
      return optionId == 'question_bank'
          ? 'Host is setting up questions from the story.'
          : 'Host is setting up random questions.';
    }
    if (stage == 'topic_subject') {
      return optionId == 'any_topic'
          ? 'Host is setting up questions on any topic.'
          : 'Host picked $displayText as the topic.';
    }
    if (stage == 'question_count') {
      final count = int.tryParse(optionId);
      if (count == 1) return 'This game will have 1 question.';
      if (count != null) return 'This game will have $count questions.';
    }
    if (stage == 'round_timer') {
      return optionId == 'timed'
          ? 'This game will have timed rounds.'
          : 'This game will have untimed rounds.';
    }
    if (stage == 'review') {
      return 'Host is reviewing the quiz setup.';
    }
    return 'Host selected $displayText.';
  }

  InteractiveSessionState? _sessionWithoutOptimisticEvent(
    InteractiveSessionState? session,
    String clientId,
  ) {
    if (session == null) return null;
    final removedEvents = session.events
        .where((event) => event.payload['client_id'] == clientId)
        .toList(growable: false);
    final nextEvents = session.events
        .where((event) => event.payload['client_id'] != clientId)
        .toList(growable: false);
    if (nextEvents.length == session.events.length) return session;
    final newestTurn = _newestInteractiveTurn(nextEvents);
    final lastSeq = nextEvents.fold<int>(
      0,
      (maxSeq, event) => event.seq > maxSeq ? event.seq : maxSeq,
    );
    final nextState = Map<String, dynamic>.from(session.interactiveState);
    String? setupStage;
    for (final event in removedEvents) {
      if (event.eventType != 'setup_choice_selected') continue;
      final stage = event.payload['stage']?.toString().trim();
      if (stage == null || stage.isEmpty) continue;
      setupStage = stage;
      break;
    }
    if (setupStage != null) {
      nextState
        ..['phase'] = 'group_setup'
        ..['group_setup_stage'] = setupStage
        ..['current_turn_id'] = newestTurn?.turnId;
      if (setupStage == 'topic_subject') {
        nextState
          ..remove('selected_topic')
          ..remove('quiz_timer_enabled')
          ..remove('total_rounds')
          ..remove('quiz_setup_complete');
      } else if (setupStage == 'round_timer') {
        nextState
          ..remove('quiz_timer_enabled')
          ..remove('total_rounds')
          ..remove('quiz_setup_complete');
      } else if (setupStage == 'question_count') {
        nextState
          ..remove('total_rounds')
          ..remove('quiz_setup_complete');
      }
    }
    return session.copyWith(
      interactiveState: nextState,
      events: nextEvents,
      currentTurn: newestTurn,
      lastSeq: lastSeq,
    );
  }

  InteractiveTurn? _newestInteractiveTurn(List<StorySessionEvent> events) {
    InteractiveTurn? newest;
    for (final event in events) {
      if (event.eventType != 'interactive_turn') continue;
      try {
        final turn = InteractiveTurn.fromJson(event.payload);
        if (newest == null || turn.seq > newest.seq) newest = turn;
      } catch (_) {
        // Ignore malformed local/cached events.
      }
    }
    return newest;
  }

  bool _isOlderSessionSnapshot(InteractiveSessionState incoming) {
    final current = state.session;
    return current != null &&
        current.sessionId == incoming.sessionId &&
        incoming.lastSeq < current.lastSeq;
  }

  InteractiveSessionState _normalizeSessionSnapshot(
    InteractiveSessionState session,
  ) {
    final interactiveState = session.interactiveState;
    if (interactiveState['session_type'] != 'solo' ||
        interactiveState['phase'] != 'topic_selection') {
      return session;
    }
    final turn = _newestSoloModeTurn(session);
    if (turn == null) return session;

    final latestTopicPromptSeq = session.events
        .where((event) => event.eventType == 'topic_selection_started')
        .fold<int>(
          0,
          (latest, event) => event.seq > latest ? event.seq : latest,
        );
    if (turn.seq <= latestTopicPromptSeq) return session;

    final normalizedState = <String, dynamic>{
      ...interactiveState,
      ...turn.statePatch,
      'phase': 'mode_selection',
    };
    final selectedTopic = normalizedState['selected_topic']?.toString().trim();
    if (selectedTopic == null || selectedTopic.isEmpty) {
      final topicEvents =
          session.events
              .where(
                (event) =>
                    event.eventType == 'topic_selected' &&
                    event.seq <= turn.seq,
              )
              .toList()
            ..sort((left, right) => right.seq.compareTo(left.seq));
      for (final event in topicEvents) {
        final topic = event.payload['topic']?.toString().trim();
        if (topic != null && topic.isNotEmpty) {
          normalizedState['selected_topic'] = topic;
          break;
        }
      }
    }
    return session.copyWith(
      interactiveState: normalizedState,
      currentTurn: turn,
      lastSeq: turn.seq > session.lastSeq ? turn.seq : session.lastSeq,
    );
  }

  InteractiveTurn? _newestSoloModeTurn(InteractiveSessionState session) {
    InteractiveTurn? newest;
    final currentTurn = session.currentTurn;
    if (currentTurn != null && _isSoloModeTurn(currentTurn)) {
      newest = currentTurn;
    }
    for (final event in session.events) {
      if (event.eventType != 'interactive_turn') continue;
      try {
        final turn = InteractiveTurn.fromJson(event.payload);
        if (!_isSoloModeTurn(turn)) continue;
        if (newest == null || turn.seq > newest.seq) newest = turn;
      } catch (_) {
        // Ignore malformed historical turns and keep the canonical snapshot.
      }
    }
    return newest;
  }

  bool _isSoloModeTurn(InteractiveTurn turn) {
    if (turn.statePatch['phase'] == 'mode_selection') return true;
    return turn.blocks.whereType<InteractiveChoiceGroupBlock>().any(
      (block) => block.metadata['choice_kind'] == 'solo_quiz_mode',
    );
  }

  bool _hasEvent(List<StorySessionEvent> events, int seq, String eventType) {
    return events.any(
      (event) => event.seq == seq && event.eventType == eventType,
    );
  }

  List<PendingInteractiveTextMessage> _pendingTextMessagesExcluding(
    String clientId,
  ) {
    return state.pendingTextMessages
        .where((message) => message.clientId != clientId)
        .toList();
  }

  void _consumePendingTextByClientId(String clientId) {
    final nextMessages = _pendingTextMessagesExcluding(clientId);
    if (nextMessages.length == state.pendingTextMessages.length) return;
    state = state.copyWith(pendingTextMessages: nextMessages);
  }

  void _consumePendingTextByValue(String? rawValue) {
    final normalized = _normalizePendingText(rawValue);
    if (normalized.isEmpty || state.pendingTextMessages.isEmpty) return;
    final nextMessages = [...state.pendingTextMessages];
    final index = nextMessages.indexWhere(
      (message) => _normalizePendingText(message.text) == normalized,
    );
    if (index == -1) return;
    nextMessages.removeAt(index);
    state = state.copyWith(pendingTextMessages: nextMessages);
  }

  void _consumePendingTopicSelection(Map<String, dynamic> payload) {
    for (final key in const [
      'option_id',
      'candidate_id',
      'aspect_id',
      'action_id',
      'selection_id',
    ]) {
      _consumePendingOptionByValue(payload[key]?.toString());
    }
    for (final key in const ['topic', 'aspect', 'text']) {
      final value = payload[key]?.toString();
      _consumePendingOptionByValue(value);
      _consumePendingTextByValue(value);
    }
  }

  void _consumePendingOptionByValue(String? rawValue) {
    final normalized = _normalizePendingText(rawValue);
    if (normalized.isEmpty || state.pendingInputKeys.isEmpty) return;
    final suffix = '-option_select-$normalized';
    final nextKeys = {...state.pendingInputKeys}
      ..removeWhere((key) => key.trim().toLowerCase().endsWith(suffix));
    if (nextKeys.length == state.pendingInputKeys.length) return;
    state = state.copyWith(pendingInputKeys: nextKeys);
  }

  void _mergeTopicSelectionState(
    Map<String, dynamic> target,
    Map<String, dynamic> payload,
  ) {
    final sources = <Map<String, dynamic>>[];
    final responseState = payload['state'];
    if (responseState is Map) {
      sources.add(responseState.cast<String, dynamic>());
    }
    final statePatch = payload['state_patch'];
    if (statePatch is Map) {
      sources.add(statePatch.cast<String, dynamic>());
    }
    sources.add(payload);

    for (final source in sources) {
      for (final key in const [
        'phase',
        'topic_selection_stage',
        'topic_path',
        'pending_topic_aspects',
        'topic_aspect_status',
        'topic_drilldown_depth',
        'topic_aspect_revision',
        'allow_custom_aspect',
        'topic_path_actions_expanded',
        'selected_topic',
        'selected_topic_path',
        'topic_candidate',
        'selected_topic_candidate',
        'selected_topic_aspect',
        'topic_prompt',
        'topic_prompt_status',
        'topic_suggestions',
        'pending_topic_options',
      ]) {
        if (source.containsKey(key)) target[key] = source[key];
      }
    }
  }

  void _clearTopicAspectWorkingState(Map<String, dynamic> target) {
    for (final key in const [
      'topic_selection_stage',
      'topic_path',
      'topic_drilldown_depth',
      'topic_aspect_revision',
      'topic_aspect_status',
      'allow_custom_aspect',
      'topic_path_actions_expanded',
      'pending_topic_aspects',
      'pending_topic_options',
      'pending_topic_fragment',
      'pending_topic_clarification_attempts',
    ]) {
      target.remove(key);
    }
  }

  void _markTopicAspectGenerationPending(
    Map<String, dynamic> target,
    Map<String, dynamic> payload,
  ) {
    final depth = (payload['depth'] as num?)?.toInt();
    if (depth != null) target['topic_drilldown_depth'] = depth;
    if (!payload.containsKey('topic_aspect_status')) {
      target['topic_aspect_status'] = 'generating';
    }
    if (!payload.containsKey('pending_topic_aspects')) {
      target['pending_topic_aspects'] = <dynamic>[];
    }
  }

  Map<String, dynamic> _guidedAspectExpectationMetadata(
    InteractiveSessionState? session,
  ) {
    final interactiveState = session?.interactiveState;
    if (interactiveState == null ||
        interactiveState['session_type'] != 'solo' ||
        interactiveState['phase'] != 'topic_selection' ||
        interactiveState['topic_selection_stage'] != 'aspect') {
      return const <String, dynamic>{};
    }
    final revision = interactiveState['topic_aspect_revision']
        ?.toString()
        .trim();
    final path = ((interactiveState['topic_path'] as List?) ?? const [])
        .map((part) => part.toString().trim())
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    if (revision == null || revision.isEmpty || path.isEmpty) {
      return const <String, dynamic>{};
    }
    return <String, dynamic>{
      'expected_revision': revision,
      'expected_topic_path': path,
    };
  }

  String _normalizePendingText(String? value) {
    return (value ?? '').trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
  }
}

final interactiveStoryProvider =
    NotifierProvider.autoDispose<
      InteractiveStoryNotifier,
      InteractiveStoryState
    >(InteractiveStoryNotifier.new);
