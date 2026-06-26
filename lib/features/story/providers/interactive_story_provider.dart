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
    this.localQuizSelections = const <String, String>{},
    this.error,
  });

  final InteractiveSessionState? session;
  final bool isLoading;
  final Set<String> pendingInputKeys;
  final Map<String, String> localQuizSelections;
  final String? error;

  InteractiveStoryState copyWith({
    InteractiveSessionState? session,
    bool? isLoading,
    Set<String>? pendingInputKeys,
    Map<String, String>? localQuizSelections,
    Object? error = _unset,
  }) {
    return InteractiveStoryState(
      session: session ?? this.session,
      isLoading: isLoading ?? this.isLoading,
      pendingInputKeys: pendingInputKeys ?? this.pendingInputKeys,
      localQuizSelections: localQuizSelections ?? this.localQuizSelections,
      error: error == _unset ? this.error : error as String?,
    );
  }
}

const _unset = Object();

class InteractiveStoryNotifier extends Notifier<InteractiveStoryState> {
  IOWebSocketChannel? _roomChannel;
  StreamSubscription<dynamic>? _roomSubscription;
  Timer? _refreshTimer;

  @override
  InteractiveStoryState build() {
    ref.onDispose(() {
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
      );
      state = InteractiveStoryState(session: session);
      unawaited(_connectRoomSocket(session.sessionId));
      _scheduleWaitingRefresh();
    } on ApiError catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: '$e');
    }
  }

  Future<void> restart({
    required String storyId,
    required String interactionMode,
    String? sessionType,
  }) async {
    await _disconnectRoomSocket();
    state = const InteractiveStoryState();
    await start(
      storyId: storyId,
      interactionMode: interactionMode,
      sessionType: sessionType,
    );
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
      state = InteractiveStoryState(session: session);
      unawaited(_connectRoomSocket(session.sessionId));
      _scheduleWaitingRefresh();
    } on ApiError catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    } catch (e) {
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
      state = InteractiveStoryState(session: session);
      _scheduleWaitingRefresh();
    } on ApiError catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: '$e');
    }
  }

  Future<void> retryGeneration() async {
    final sessionId = state.session?.sessionId;
    if (sessionId == null || sessionId.isEmpty || state.isLoading) return;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final repo = ref.read(storiesRepositoryProvider);
      final session = await repo.retryInteractiveQuizGeneration(sessionId);
      state = state.copyWith(session: session, isLoading: false);
      _scheduleWaitingRefresh();
    } on ApiError catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: '$e');
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
      state = const InteractiveStoryState();
    } on ApiError {
      await _disconnectRoomSocket();
      state = const InteractiveStoryState();
    } catch (_) {
      await _disconnectRoomSocket();
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
      final current = state.session;
      if (current == null) return;
      final nextEvents = [...current.events, response.event];
      if (response.turn != null) {
        nextEvents.add(
          StorySessionEvent(
            id: response.turn!.turnId,
            sessionId: sessionId,
            seq: response.turn!.seq,
            actorType: 'ai',
            eventType: 'interactive_turn',
            payload: response.turn!.toJson(),
          ),
        );
      }
      state = state.copyWith(
        session: current.copyWith(
          interactiveState: response.state,
          events: nextEvents,
          currentTurn: response.turn ?? current.currentTurn,
          lastSeq: response.turn?.seq ?? response.event.seq,
        ),
        pendingInputKeys: {...state.pendingInputKeys}..remove(key),
      );
    } on ApiError catch (e) {
      if (e.statusCode == 409) {
        final nextSelections = Map<String, String>.from(
          state.localQuizSelections,
        );
        if (inputType == 'quiz_answer' && questionId != null) {
          nextSelections.remove(questionId);
        }
        state = state.copyWith(
          pendingInputKeys: {...state.pendingInputKeys}..remove(key),
          localQuizSelections: nextSelections,
          error: null,
        );
        await _refreshSilently();
        return;
      }
      state = state.copyWith(
        pendingInputKeys: {...state.pendingInputKeys}..remove(key),
        error: e.message,
      );
    } catch (e) {
      state = state.copyWith(
        pendingInputKeys: {...state.pendingInputKeys}..remove(key),
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

    state = state.copyWith(
      pendingInputKeys: {...state.pendingInputKeys, key},
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
      final current = state.session;
      if (current == null) return;
      final nextEvents = [...current.events, response.event];
      if (response.turn != null) {
        nextEvents.add(
          StorySessionEvent(
            id: response.turn!.turnId,
            sessionId: sessionId,
            seq: response.turn!.seq,
            actorType: 'ai',
            eventType: 'interactive_turn',
            payload: response.turn!.toJson(),
          ),
        );
      }
      state = state.copyWith(
        session: current.copyWith(
          interactiveState: response.state,
          events: nextEvents,
          currentTurn: response.turn ?? current.currentTurn,
          lastSeq: response.turn?.seq ?? response.event.seq,
        ),
        pendingInputKeys: {...state.pendingInputKeys}..remove(key),
      );
    } on ApiError catch (e) {
      state = state.copyWith(
        pendingInputKeys: {...state.pendingInputKeys}..remove(key),
        error: e.message,
      );
    } catch (e) {
      state = state.copyWith(
        pendingInputKeys: {...state.pendingInputKeys}..remove(key),
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
      _roomChannel = channel;
      _roomSubscription = channel.stream.listen(
        _handleRoomSocketMessage,
        onError: (_) {
          _roomChannel = null;
          _roomSubscription = null;
          _scheduleWaitingRefresh();
        },
        onDone: () {
          _roomChannel = null;
          _roomSubscription = null;
          _scheduleWaitingRefresh();
        },
      );
    } catch (_) {
      try {
        await channel?.sink.close(ws_status.normalClosure, 'connect_error');
      } catch (_) {}
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
        state = state.copyWith(session: session);
        _scheduleWaitingRefresh();
      }
      return;
    }

    if (type != 'room_event') return;
    _applyRoomEvent(payload);
  }

  void _applyRoomEvent(Map<String, dynamic> event) {
    final current = state.session;
    if (current == null) return;
    final eventType = (event['event_type'] as String?)?.trim() ?? '';
    final payload =
        (event['payload'] as Map?)?.cast<String, dynamic>() ??
        <String, dynamic>{};
    final seq = (event['seq'] as num?)?.toInt() ?? current.lastSeq;
    final nextState = Map<String, dynamic>.from(current.interactiveState);

    switch (eventType) {
      case 'question_generation_started':
        nextState
          ..['phase'] = 'generating_question'
          ..['current_round'] =
              (payload['round'] as num?)?.toInt() ?? nextState['current_round']
          ..['question'] = null
          ..['result'] = null;
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
    state = state.copyWith(
      session: current.copyWith(
        interactiveState: nextState,
        events: nextEvents,
        lastSeq: seq > current.lastSeq ? seq : current.lastSeq,
      ),
    );
    _scheduleWaitingRefresh();
  }

  void _scheduleWaitingRefresh() {
    _refreshTimer?.cancel();
    final session = state.session;
    if (session == null || session.isCompleted) return;
    final phase = session.interactiveState['phase'] as String?;
    final hasQuestion = session.interactiveState['question'] is Map;
    if (phase == 'question_active') {
      final expiresAt = _parseStateDate(session.interactiveState['expires_at']);
      final delay = _expiryRefreshDelay(expiresAt);
      _refreshTimer = Timer(delay, () {
        unawaited(_refreshSilently());
      });
      return;
    }
    final shouldPoll =
        phase == 'generating_question' ||
        phase == 'question_generation_started' ||
        phase == 'finalizing_question' ||
        phase == 'showing_results' ||
        (!hasQuestion && session.currentTurn == null);
    if (!shouldPoll) return;
    _refreshTimer = Timer(const Duration(seconds: 2), () {
      unawaited(_refreshSilently());
    });
  }

  Future<void> _refreshSilently() async {
    final sessionId = state.session?.sessionId;
    if (sessionId == null || sessionId.isEmpty) return;
    try {
      final repo = ref.read(storiesRepositoryProvider);
      final session = await repo.fetchInteractiveSession(sessionId);
      state = state.copyWith(session: session);
    } catch (_) {
      // Keep the current UI state and try again while it is still waiting.
    } finally {
      _scheduleWaitingRefresh();
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
}

final interactiveStoryProvider =
    NotifierProvider.autoDispose<
      InteractiveStoryNotifier,
      InteractiveStoryState
    >(InteractiveStoryNotifier.new);
