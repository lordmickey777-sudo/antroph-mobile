import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/state/auth_state.dart';
import '../../../core/env/env.dart';
import '../models/story_socket_models.dart';
import '../services/story_websocket_service.dart';

enum StoryWsPhase {
  idle,
  connecting,
  authenticating,
  starting,
  running,
  awaitingChoice,
  streamingAudio,
  error,
  closed,
}

class StorySocketState {
  const StorySocketState({
    this.phase = StoryWsPhase.idle,
    this.storyId,
    this.storyTitle,
    this.sessionId,
    this.resumeToken,
    this.currentNode,
    this.choices = const <StoryChoiceOption>[],
    this.currentAudio,
    this.latestExpression,
    this.lastTranscript,
    this.lastTranscriptIsFinal = false,
    this.error,
    this.log = const <StoryLogEntry>[],
    this.lastCorrelationId,
  });

  final StoryWsPhase phase;
  final String? storyId;
  final String? storyTitle;
  final String? sessionId;
  final String? resumeToken;
  final StoryNodeView? currentNode;
  final List<StoryChoiceOption> choices;
  final StoryAudioMeta? currentAudio;
  final StoryExpression? latestExpression;
  final String? lastTranscript;
  final bool lastTranscriptIsFinal;
  final String? error;
  final List<StoryLogEntry> log;
  final String? lastCorrelationId;

  StorySocketState copyWith({
    StoryWsPhase? phase,
    String? storyId,
    String? storyTitle,
    String? sessionId,
    String? resumeToken,
    StoryNodeView? currentNode,
    List<StoryChoiceOption>? choices,
    StoryAudioMeta? currentAudio,
    bool clearAudio = false,
    StoryExpression? latestExpression,
    bool clearExpression = false,
    bool clearNode = false,
    bool clearChoices = false,
    String? lastTranscript,
    bool? lastTranscriptIsFinal,
    String? error,
    bool clearError = false,
    bool clearTranscript = false,
    List<StoryLogEntry>? log,
    String? lastCorrelationId,
  }) {
    return StorySocketState(
      phase: phase ?? this.phase,
      storyId: storyId ?? this.storyId,
      storyTitle: storyTitle ?? this.storyTitle,
      sessionId: sessionId ?? this.sessionId,
      resumeToken: resumeToken ?? this.resumeToken,
      currentNode: clearNode ? null : currentNode ?? this.currentNode,
      choices: clearChoices ? <StoryChoiceOption>[] : (choices ?? this.choices),
      currentAudio: clearAudio ? null : currentAudio ?? this.currentAudio,
      latestExpression: clearExpression ? null : latestExpression ?? this.latestExpression,
      lastTranscript: clearTranscript ? null : lastTranscript ?? this.lastTranscript,
      lastTranscriptIsFinal: lastTranscriptIsFinal ?? this.lastTranscriptIsFinal,
      error: clearError ? null : (error ?? this.error),
      log: log ?? this.log,
      lastCorrelationId: lastCorrelationId ?? this.lastCorrelationId,
    );
  }

  factory StorySocketState.initial() => const StorySocketState();
}

class StorySocketNotifier extends Notifier<StorySocketState> {
  late final StoryWebSocketService _service;
  StreamSubscription<StoryServerMessage>? _subscription;
  String? _clientId;
  String? _startMessageId;

  @override
  StorySocketState build() {
    _service = StoryWebSocketService.instance;
    ref.onDispose(() async {
      await _service.disconnect('dispose');
      await _subscription?.cancel();
    });
    return StorySocketState.initial();
  }

  Future<void> startStory({
    required String storyId,
    required String storyTitle,
    String? startScene,
    String? resumeToken,
  }) async {
    final wsUrl = AppEnv.storyWsUrl;
    if (wsUrl.isEmpty) {
      state = state.copyWith(
        phase: StoryWsPhase.error,
        error: 'Missing STORY_WS_URL in env or dart-define.',
      );
      return;
    }

    final token = ref.read(authControllerProvider.notifier).tokens?.accessToken ?? '';
    final headers = token.isNotEmpty ? {HttpHeaders.authorizationHeader: 'Bearer $token'} : null;

    state = state.copyWith(
      phase: StoryWsPhase.connecting,
      storyId: storyId,
      storyTitle: storyTitle,
      clearError: true,
      clearAudio: true,
      clearExpression: true,
      clearNode: true,
      clearChoices: true,
      clearTranscript: true,
      log: [
        ...state.log,
        StoryLogEntry(label: 'Connecting to story socket'),
      ],
    );

    try {
      await _service.connect(url: wsUrl, headers: headers);
    } catch (err) {
      state = state.copyWith(
        phase: StoryWsPhase.error,
        error: '$err',
        log: [...state.log, StoryLogEntry(label: 'connect failed')],
      );
      return;
    }
    await _subscription?.cancel();
    _subscription = _service.messages.listen(_handleIncoming, onError: _handleError, onDone: _handleClosed);

    _sendAuth(token);
    _sendStartSession();
    _sendStartStory(storyId: storyId, startScene: startScene, resumeToken: resumeToken);
  }

  Future<void> endStory() async {
    if (_service.isConnected) {
      final messageId = _service.newMessageId('end');
      _service.sendEnvelope(
        StoryWsEnvelope(
          type: 'end_session',
          messageId: messageId,
          payload: {'reason': 'user_exit'},
        ),
      );
    }
    await _service.disconnect('user_exit');
    state = StorySocketState.initial();
  }

  void retryLastStart() {
    final id = state.storyId;
    final title = state.storyTitle;
    if (id == null || title == null) return;
    startStory(storyId: id, storyTitle: title, resumeToken: state.resumeToken);
  }

  void sendChoice(String choiceId) {
    if (state.phase == StoryWsPhase.error || state.storyId == null) return;
    final messageId = _service.newMessageId('choice');
    final nodeId = state.currentNode?.nodeId;
    final storyContext = state.currentNode?.storyContext;
    final payload = <String, dynamic>{
      'choice_id': choiceId,
      if (nodeId != null) 'node_id': nodeId,
      if (storyContext != null)
        'story_state': {
          'scene_id': storyContext.sceneId,
          'node_id': storyContext.nodeId,
        },
    };
    _service.sendEnvelope(
      StoryWsEnvelope(
        type: 'choice_selection',
        messageId: messageId,
        correlationId: state.lastCorrelationId,
        payload: payload,
      ),
    );
    state = state.copyWith(
      phase: StoryWsPhase.running,
      log: [...state.log, StoryLogEntry(label: 'choice_selection $choiceId')],
    );
  }

  void sendUserText(String text) {
    if (text.trim().isEmpty) return;
    final messageId = _service.newMessageId('text');
    _service.sendEnvelope(
      StoryWsEnvelope(
        type: 'user_text',
        messageId: messageId,
        correlationId: state.lastCorrelationId,
        payload: {
          'text': text.trim(),
          if (state.currentNode?.storyContext != null) 'story_context': state.currentNode!.storyContext!.toJson(),
        },
      ),
    );
    state = state.copyWith(log: [...state.log, StoryLogEntry(label: 'user_text sent')]);
  }

  void _handleIncoming(StoryServerMessage msg) {
    switch (msg.type) {
      case 'auth_ack':
        state = state.copyWith(
          phase: StoryWsPhase.starting,
          sessionId: msg.payload['session_id'] as String? ?? state.sessionId,
          log: [...state.log, StoryLogEntry(label: 'auth acknowledged')],
        );
        break;
      case 'session_ack':
      case 'start_session_ack':
        state = state.copyWith(
          sessionId: msg.payload['session_id'] as String? ?? state.sessionId,
          resumeToken: msg.payload['resume_token'] as String? ?? state.resumeToken,
          log: [...state.log, StoryLogEntry(label: 'session ack')],
        );
        break;
      case 'resume_ack':
        StoryNodeView? node;
        if (msg.payload['story_state'] is Map) {
          node = StoryNodeView.fromStoryState((msg.payload['story_state'] as Map).cast<String, dynamic>());
        }
        state = state.copyWith(
          phase: StoryWsPhase.running,
          sessionId: msg.payload['session_id'] as String? ?? state.sessionId,
          resumeToken: msg.payload['resume_token'] as String? ?? state.resumeToken,
          currentNode: node ?? state.currentNode,
          choices: node?.availableChoices ?? state.choices,
          lastCorrelationId: msg.correlationId ?? msg.messageId ?? state.lastCorrelationId,
          log: [...state.log, StoryLogEntry(label: 'resume acknowledged')],
        );
        break;
      case 'story_state':
      case 'ai_response':
        final node = StoryNodeView.fromStoryState(msg.payload);
        state = state.copyWith(
          phase: node.availableChoices.isNotEmpty ? StoryWsPhase.awaitingChoice : StoryWsPhase.running,
          currentNode: node,
          choices: node.availableChoices,
          lastCorrelationId: msg.correlationId ?? msg.messageId ?? _startMessageId ?? state.lastCorrelationId,
          log: [...state.log, StoryLogEntry(label: msg.type)],
        );
        break;
      case 'choice_prompt':
        final choices = ((msg.payload['choices'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => StoryChoiceOption.fromJson(e.cast<String, dynamic>()))
            .toList();
        state = state.copyWith(
          phase: StoryWsPhase.awaitingChoice,
          choices: choices,
          lastCorrelationId: msg.correlationId ?? msg.messageId ?? state.lastCorrelationId,
          log: [...state.log, StoryLogEntry(label: 'choice_prompt')],
        );
        break;
      case 'choice_ack':
        state = state.copyWith(
          phase: StoryWsPhase.running,
          log: [...state.log, StoryLogEntry(label: 'choice_ack')],
        );
        break;
      case 'audio_start':
        final audio = StoryAudioMeta.fromJson(msg.payload);
        state = state.copyWith(
          currentAudio: audio,
          phase: StoryWsPhase.streamingAudio,
          log: [...state.log, StoryLogEntry(label: 'audio_start ${audio.audioId}')],
        );
        break;
      case 'audio_end':
        state = state.copyWith(
          clearAudio: true,
          phase: StoryWsPhase.running,
          log: [...state.log, StoryLogEntry(label: 'audio_end')],
        );
        break;
      case 'expression':
        final expression = StoryExpression.fromJson(msg.payload);
        state = state.copyWith(
          latestExpression: expression,
          log: [...state.log, StoryLogEntry(label: 'expression ${expression.name}')],
        );
        break;
      case 'transcript_partial':
      case 'transcript_final':
        final text = (msg.payload['text'] as String?)?.trim() ?? '';
        final isFinal = msg.type == 'transcript_final';
        state = state.copyWith(
          lastTranscript: text,
          lastTranscriptIsFinal: isFinal,
          log: [...state.log, StoryLogEntry(label: msg.type)],
        );
        break;
      case 'error':
        final err = StorySocketError.fromJson(msg.payload);
        state = state.copyWith(
          phase: StoryWsPhase.error,
          error: '${err.code}: ${err.message}',
          log: [...state.log, StoryLogEntry(label: 'error ${err.code}')],
        );
        break;
      case 'throttle':
        state = state.copyWith(log: [...state.log, StoryLogEntry(label: 'throttle')]);
        break;
      case 'socket_closed':
        state = state.copyWith(phase: StoryWsPhase.closed);
        break;
      default:
        state = state.copyWith(
          log: [...state.log, StoryLogEntry(label: 'unhandled ${msg.type}')],
        );
    }
  }

  void _handleError(Object err, StackTrace st) {
    state = state.copyWith(
      phase: StoryWsPhase.error,
      error: '$err',
      log: [...state.log, StoryLogEntry(label: 'socket error')],
    );
  }

  void _handleClosed() {
    state = state.copyWith(
      phase: StoryWsPhase.closed,
      log: [...state.log, StoryLogEntry(label: 'socket closed')],
    );
  }

  void _sendAuth(String token) {
    final messageId = _service.newMessageId('auth');
    final platform = Platform.isIOS ? 'ios' : 'android';
    final clientId = _clientId ?? 'mobile-${_service.newMessageId('client')}';
    _clientId = clientId;
    _service.sendEnvelope(
      StoryWsEnvelope(
        type: 'auth',
        messageId: messageId,
        payload: {
          'token': token,
          'client_id': clientId,
          'platform': platform,
          'app_version': '1.0.0',
        },
      ),
    );
    state = state.copyWith(phase: StoryWsPhase.authenticating);
  }

  void _sendStartSession() {
    final messageId = _service.newMessageId('session');
    final platform = Platform.isIOS ? 'ios' : 'android';
    final clientId = _clientId ?? 'mobile-${_service.newMessageId('client')}';
    _clientId = clientId;
    _service.sendEnvelope(
      StoryWsEnvelope(
        type: 'start_session',
        messageId: messageId,
        payload: {
          'client_id': clientId,
          'platform': platform,
          'app_version': '1.0.0',
        },
      ),
    );
  }

  void _sendStartStory({required String storyId, String? startScene, String? resumeToken}) {
    final messageId = _service.newMessageId('start');
    _startMessageId = messageId;
    _service.sendEnvelope(
      StoryWsEnvelope(
        type: 'start_story',
        messageId: messageId,
        payload: {
          'story_id': storyId,
          if (startScene != null) 'start_scene': startScene,
          'resume_token': resumeToken,
          'player_profile': {
            'user_id': state.storyId ?? storyId,
            'voice_pref': 'female_en',
          },
        },
      ),
    );
  }
}

final storySocketProvider =
    NotifierProvider.autoDispose<StorySocketNotifier, StorySocketState>(StorySocketNotifier.new);
