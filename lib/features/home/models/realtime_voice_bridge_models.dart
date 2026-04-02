/// Client message types sent to the realtime voice bridge.
enum RealtimeClientMessageType {
  storyStart('story_start'),
  storyStop('story_stop'),
  storyPause('story_pause'),
  storyResume('story_resume'),
  joinRoom('join_room'),
  leaveRoom('leave_room'),
  deviceTakeover('device_takeover'),
  inputAudioBufferAppend('input_audio_buffer.append'),
  inputAudioBufferCommit('input_audio_buffer.commit');

  const RealtimeClientMessageType(this.value);
  final String value;
}

/// Server message types received from the realtime voice bridge.
enum RealtimeServerMessageType {
  // Story control messages
  storySessionReady('story_session_ready'),
  storyStarted('story_started'),
  storyResumed('story_resumed'),
  storyResponse('story_response'),
  storyAck('story_ack'),
  takeoverGranted('takeover_granted'),
  takeoverDenied('takeover_denied'),
  roomJoined('room_joined'),

  // OpenAI Realtime session messages
  sessionCreated('session.created'),
  sessionUpdated('session.updated'),

  // Conversation history
  conversationHistoryFull('conversation.history.full'),

  // OpenAI Realtime conversation messages
  conversationItemCreate('conversation.item.create'),
  inputAudioTranscriptionCompleted(
    'conversation.item.input_audio_transcription.completed',
  ),
  mascotExpression('mascot.expression'),

  // OpenAI Realtime response messages
  responseCreated('response.created'),
  responseDone('response.done'),
  responseAudioTranscriptDelta('response.audio_transcript.delta'),
  responseAudioTranscriptDone('response.audio_transcript.done'),
  responseTextDelta('response.text.delta'),
  responseTextDone('response.text.done'),
  responseAudioDelta('response.audio.delta'),
  responseAudio('response.audio'),
  responseOutputAudioDelta('response.output_audio.delta'),
  responseOutputAudio('response.output_audio'),
  outputAudioDelta('output_audio.delta'),

  // Error messages
  responseError('response.error'),
  error('error'),
  unknown('unknown');

  const RealtimeServerMessageType(this.value);
  final String value;

  static RealtimeServerMessageType fromString(String type) {
    return RealtimeServerMessageType.values.firstWhere(
      (e) => e.value == type,
      orElse: () => RealtimeServerMessageType.unknown,
    );
  }
}

/// Phase of the realtime voice session.
enum RealtimeVoicePhase {
  /// Not connected
  idle,

  /// Connecting to WebSocket
  connecting,

  /// Connected, waiting for story_session_ready
  waitingForReady,

  /// Story session is ready, can stream audio
  ready,

  /// Recording user audio
  recording,

  /// Processing user input
  processing,

  /// Playing AI response audio
  playing,

  /// Session error
  error,

  /// Session paused
  paused,

  /// Connection closed
  closed,
}

/// Story session state from server.
class StorySessionInfo {
  final String sessionId;
  final String storyId;
  final String? roomId;
  final String? currentNodeId;
  final Map<String, dynamic>? storyContext;

  const StorySessionInfo({
    required this.sessionId,
    required this.storyId,
    this.roomId,
    this.currentNodeId,
    this.storyContext,
  });

  factory StorySessionInfo.fromJson(Map<String, dynamic> json) {
    return StorySessionInfo(
      sessionId:
          json['session_id'] as String? ??
          json['story_session_id'] as String? ??
          '',
      storyId: json['story_id'] as String? ?? '',
      roomId: json['room_id'] as String?,
      currentNodeId: json['current_node_id'] as String?,
      storyContext: json['story_context'] as Map<String, dynamic>?,
    );
  }

  StorySessionInfo copyWith({
    String? sessionId,
    String? storyId,
    String? roomId,
    String? currentNodeId,
    Map<String, dynamic>? storyContext,
  }) {
    return StorySessionInfo(
      sessionId: sessionId ?? this.sessionId,
      storyId: storyId ?? this.storyId,
      roomId: roomId ?? this.roomId,
      currentNodeId: currentNodeId ?? this.currentNodeId,
      storyContext: storyContext ?? this.storyContext,
    );
  }

  bool get isValid => sessionId.isNotEmpty;
}

/// Room state from server.
class RoomState {
  final String roomId;
  final List<String> participants;
  final String? currentDevice;

  const RoomState({
    required this.roomId,
    this.participants = const [],
    this.currentDevice,
  });

  factory RoomState.fromJson(Map<String, dynamic> json) {
    return RoomState(
      roomId: json['room_id'] as String? ?? '',
      participants:
          (json['participants'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      currentDevice: json['current_device'] as String?,
    );
  }
}

/// Device takeover request/response.
class DeviceTakeoverResult {
  final bool granted;
  final String? reason;
  final String? previousDevice;

  const DeviceTakeoverResult({
    required this.granted,
    this.reason,
    this.previousDevice,
  });

  factory DeviceTakeoverResult.fromJson(
    Map<String, dynamic> json,
    bool granted,
  ) {
    return DeviceTakeoverResult(
      granted: granted,
      reason: json['reason'] as String?,
      previousDevice: json['previous_device'] as String?,
    );
  }
}

/// Error response from server.
class RealtimeVoiceError {
  final String code;
  final String message;
  final bool retryable;

  const RealtimeVoiceError({
    required this.code,
    required this.message,
    this.retryable = false,
  });

  factory RealtimeVoiceError.fromJson(Map<String, dynamic> json) {
    final error = json['error'] as Map<String, dynamic>?;
    return RealtimeVoiceError(
      code: error?['code'] as String? ?? json['code'] as String? ?? 'unknown',
      message:
          error?['message'] as String? ??
          json['message'] as String? ??
          'Unknown error',
      retryable:
          error?['retryable'] as bool? ?? json['retryable'] as bool? ?? false,
    );
  }

  bool get isStoryContextRequired => code == 'story_context_required';
  bool get isStorySessionRequired => code == 'story_session_required';
  bool get isAuthRequired => code == 'auth_required' || code == 'unauthorized';
}

/// Conversation history item injected by server.
class ConversationItem {
  final String role;
  final String content;
  final String? audioId;

  const ConversationItem({
    required this.role,
    required this.content,
    this.audioId,
  });

  factory ConversationItem.fromJson(Map<String, dynamic> json) {
    final item = json['item'] as Map<String, dynamic>? ?? json;
    final contentList = item['content'] as List<dynamic>?;
    String contentText = '';
    String? audioId;

    if (contentList != null && contentList.isNotEmpty) {
      for (final part in contentList) {
        if (part is Map<String, dynamic>) {
          final type = part['type'] as String?;
          if (type == 'text' || type == 'input_text') {
            contentText = part['text'] as String? ?? '';
          } else if (type == 'audio' || type == 'input_audio') {
            audioId = part['audio_id'] as String?;
          }
        }
      }
    }

    return ConversationItem(
      role: item['role'] as String? ?? 'user',
      content: contentText,
      audioId: audioId,
    );
  }

  bool get isUser => role == 'user';
  bool get isAssistant => role == 'assistant';
}
