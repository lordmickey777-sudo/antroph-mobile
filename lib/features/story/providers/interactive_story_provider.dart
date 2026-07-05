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
    this.pendingInputKeys = const <String>{},
    this.pendingTextMessages = const <PendingInteractiveTextMessage>[],
    this.localQuizSelections = const <String, String>{},
    this.streamingAssistantText,
    this.recentStreamedAssistantText,
    this.isRetryingGeneration = false,
    this.error,
  });

  final InteractiveSessionState? session;
  final bool isLoading;
  final Set<String> pendingInputKeys;
  final List<PendingInteractiveTextMessage> pendingTextMessages;
  final Map<String, String> localQuizSelections;
  final String? streamingAssistantText;
  final String? recentStreamedAssistantText;
  final bool isRetryingGeneration;
  final String? error;

  InteractiveStoryState copyWith({
    InteractiveSessionState? session,
    bool? isLoading,
    Set<String>? pendingInputKeys,
    List<PendingInteractiveTextMessage>? pendingTextMessages,
    Map<String, String>? localQuizSelections,
    Object? streamingAssistantText = _unset,
    Object? recentStreamedAssistantText = _unset,
    bool? isRetryingGeneration,
    Object? error = _unset,
  }) {
    return InteractiveStoryState(
      session: session ?? this.session,
      isLoading: isLoading ?? this.isLoading,
      pendingInputKeys: pendingInputKeys ?? this.pendingInputKeys,
      pendingTextMessages: pendingTextMessages ?? this.pendingTextMessages,
      localQuizSelections: localQuizSelections ?? this.localQuizSelections,
      streamingAssistantText: streamingAssistantText == _unset
          ? this.streamingAssistantText
          : streamingAssistantText as String?,
      recentStreamedAssistantText: recentStreamedAssistantText == _unset
          ? this.recentStreamedAssistantText
          : recentStreamedAssistantText as String?,
      isRetryingGeneration: isRetryingGeneration ?? this.isRetryingGeneration,
      error: error == _unset ? this.error : error as String?,
    );
  }
}

const _unset = Object();

class InteractiveStoryNotifier extends Notifier<InteractiveStoryState> {
  IOWebSocketChannel? _roomChannel;
  StreamSubscription<dynamic>? _roomSubscription;
  Timer? _refreshTimer;
  bool _isDisposed = false;

  @override
  InteractiveStoryState build() {
    _isDisposed = false;
    ref.onDispose(() {
      _isDisposed = true;
      _refreshTimer?.cancel();
      _refreshTimer = null;
      unawaited(_disconnectRoomSocket());
    });
    return const InteractiveStoryState();
  }

  String get _deviceType => Platform.isIOS ? 'ios' : 'android';
  String get _deviceId => 'mobile-app';

  Future<void> start({
    required String storyId,
    required String interactionMode,
    String? sessionType,
    String? roomType,
  }) async {
    if (state.isLoading) return;
    final existing = state.session;
    if (existing != null && existing.storyId == storyId) return;

    state = state.copyWith(isLoading: true, error: null);
    try {
      final repo = ref.read(storiesRepositoryProvider);
      final session = await repo.startInteractiveSession(
        storyId: storyId,
        deviceType: _deviceType,
        deviceId: _deviceId,
        sessionType:
            sessionType ?? (interactionMode == 'group' ? 'group' : 'solo'),
        roomType: roomType,
      );
      if (_isDisposed) return;
      state = InteractiveStoryState(session: session);
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
    );
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
      state = InteractiveStoryState(session: session);
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
      state = InteractiveStoryState(session: session);
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
      state = InteractiveStoryState(session: session);
      _scheduleWaitingRefresh();
    } on ApiError catch (e) {
      if (_isDisposed) return;
      state = state.copyWith(isLoading: false, error: e.message);
    } catch (e) {
      if (_isDisposed) return;
      state = state.copyWith(isLoading: false, error: '$e');
    }
  }

  Future<void> retryGeneration() async {
    final sessionId = state.session?.sessionId;
    if (sessionId == null || sessionId.isEmpty || state.isLoading) return;
    state = state.copyWith(
      isLoading: true,
      isRetryingGeneration: true,
      error: null,
    );
    try {
      final repo = ref.read(storiesRepositoryProvider);
      final session = await repo.retryInteractiveQuizGeneration(sessionId);
      if (_isDisposed) return;
      state = state.copyWith(
        session: session,
        isLoading: false,
        isRetryingGeneration: _shouldKeepGenerationRetryOverlay(session),
      );
      _scheduleWaitingRefresh();
    } on ApiError catch (e) {
      if (_isDisposed) return;
      state = state.copyWith(
        isLoading: false,
        isRetryingGeneration: false,
        error: e.message,
      );
    } catch (e) {
      if (_isDisposed) return;
      state = state.copyWith(
        isLoading: false,
        isRetryingGeneration: false,
        error: '$e',
      );
    }
  }

  Future<void> leaveSession() async {
    final sessionId = state.session?.sessionId;
    if (sessionId == null || sessionId.isEmpty || state.isLoading) return;
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
  }) async {
    final sessionId = state.session?.sessionId;
    if (sessionId == null || sessionId.isEmpty) return;
    if (inputType == 'quiz_answer' && _isQuizAnswerExpired()) return;

    final key =
        '${questionId ?? state.session?.currentTurn?.turnId ?? state.session?.lastSeq}-$inputType-$optionId';
    if (state.pendingInputKeys.contains(key)) return;

    state = state.copyWith(
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
      final response = await repo.submitInteractiveInput(
        sessionId: sessionId,
        input: InteractiveInput(
          inputType: inputType,
          questionId: questionId,
          optionId: optionId,
          idempotencyKey: key,
        ),
      );
      if (_isDisposed) return;
      final current = state.session;
      if (current == null) return;
      final mergedSession = _mergeResponseIntoSession(current, response);
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
        streamingAssistantText: null,
        error: e.message,
      );
    } catch (e) {
      if (_isDisposed) return;
      state = state.copyWith(
        pendingInputKeys: {...state.pendingInputKeys}..remove(key),
        pendingTextMessages: _pendingTextMessagesExcluding(key),
        streamingAssistantText: null,
        error: '$e',
      );
    }
  }

  Future<void> submitText(String text) async {
    final sessionId = state.session?.sessionId;
    final trimmed = text.trim();
    if (sessionId == null || sessionId.isEmpty || trimmed.isEmpty) return;
    final key =
        '${state.session?.currentTurn?.turnId ?? state.session?.lastSeq}-text-${DateTime.now().millisecondsSinceEpoch}';
    final pendingMessage = PendingInteractiveTextMessage(
      clientId: key,
      text: trimmed,
    );

    state = state.copyWith(
      pendingInputKeys: {...state.pendingInputKeys, key},
      pendingTextMessages: [...state.pendingTextMessages, pendingMessage],
      streamingAssistantText: null,
      recentStreamedAssistantText: null,
      error: null,
    );

    try {
      final repo = ref.read(storiesRepositoryProvider);
      final response = await repo.submitInteractiveInput(
        sessionId: sessionId,
        input: InteractiveInput(
          inputType: 'text',
          text: trimmed,
          idempotencyKey: key,
        ),
      );
      if (_isDisposed) return;
      final current = state.session;
      if (current == null) return;
      final mergedSession = _mergeResponseIntoSession(current, response);
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
    } on ApiError catch (e) {
      if (_isDisposed) return;
      state = state.copyWith(
        pendingInputKeys: {...state.pendingInputKeys}..remove(key),
        pendingTextMessages: _pendingTextMessagesExcluding(key),
        streamingAssistantText: null,
        error: e.message,
      );
    } catch (e) {
      if (_isDisposed) return;
      state = state.copyWith(
        pendingInputKeys: {...state.pendingInputKeys}..remove(key),
        pendingTextMessages: _pendingTextMessagesExcluding(key),
        streamingAssistantText: null,
        error: '$e',
      );
    }
  }

  Future<void> submitPlayerChat(String text) async {
    final sessionId = state.session?.sessionId;
    final trimmed = text.trim();
    if (sessionId == null || sessionId.isEmpty || trimmed.isEmpty) return;
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

  Future<void> _connectRoomSocket(String sessionId) async {
    if (_isDisposed) return;
    if (sessionId.isEmpty) return;
    final token =
        ref.read(authControllerProvider.notifier).tokens?.accessToken ?? '';
    if (token.isEmpty) return;
    final url = _roomSocketUrl(sessionId, token);
    if (url.isEmpty) return;

    await _disconnectRoomSocket();
    IOWebSocketChannel? channel;
    try {
      channel = IOWebSocketChannel.connect(Uri.parse(url));
      await channel.ready;
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
        final session = InteractiveSessionState.fromJson(
          snapshot.cast<String, dynamic>(),
        );
        state = state.copyWith(
          session: session,
          isRetryingGeneration:
              state.isRetryingGeneration &&
              _shouldKeepGenerationRetryOverlay(session),
        );
        _scheduleWaitingRefresh();
      }
      return;
    }

    if (type != 'room_event') return;
    _applyRoomEvent(payload);
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
      case 'topic_selected':
        _consumePendingTextByValue(payload['topic'] as String?);
        nextState['selected_topic'] = payload['topic'];
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
    final nextSession = current.copyWith(
      interactiveState: nextState,
      events: nextEvents,
      currentTurn: nextTurn,
      lastSeq: seq > current.lastSeq ? seq : current.lastSeq,
    );
    state = state.copyWith(
      session: nextSession,
      isRetryingGeneration:
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
    _scheduleWaitingRefresh();
  }

  void applyRoomEventForTest(Map<String, dynamic> event) {
    _applyRoomEvent(event);
  }

  void _scheduleWaitingRefresh() {
    if (_isDisposed) return;
    _refreshTimer?.cancel();
    final session = state.session;
    if (session == null || session.isCompleted) return;
    final phase = session.interactiveState['phase'] as String?;
    final topicPromptStatus =
        session.interactiveState['topic_prompt_status'] as String?;
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
        (phase == 'topic_selection' && topicPromptStatus == 'generating') ||
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
    final sessionId = state.session?.sessionId;
    if (sessionId == null || sessionId.isEmpty) return;
    try {
      final repo = ref.read(storiesRepositoryProvider);
      final session = await repo.fetchInteractiveSession(sessionId);
      if (_isDisposed) return;
      state = state.copyWith(
        session: session,
        isRetryingGeneration:
            state.isRetryingGeneration &&
            _shouldKeepGenerationRetryOverlay(session),
      );
    } catch (_) {
      // Keep the current UI state and try again while it is still waiting.
    } finally {
      if (!_isDisposed) {
        _scheduleWaitingRefresh();
      }
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

  bool _shouldKeepGenerationRetryOverlay(InteractiveSessionState session) {
    final phase = session.interactiveState['phase'] as String?;
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
    return current.copyWith(
      interactiveState: response.state,
      events: nextEvents,
      currentTurn: nextTurn,
      lastSeq: responseSeq > current.lastSeq ? responseSeq : current.lastSeq,
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

  String _normalizePendingText(String? value) {
    return (value ?? '').trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
  }
}

final interactiveStoryProvider =
    NotifierProvider.autoDispose<
      InteractiveStoryNotifier,
      InteractiveStoryState
    >(InteractiveStoryNotifier.new);
