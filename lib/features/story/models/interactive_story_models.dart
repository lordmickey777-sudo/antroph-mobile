class InteractiveOption {
  const InteractiveOption({
    required this.id,
    required this.label,
    this.metadata = const <String, dynamic>{},
  });

  final String id;
  final String label;
  final Map<String, dynamic> metadata;

  factory InteractiveOption.fromJson(Map<String, dynamic> json) {
    return InteractiveOption(
      id:
          (json['id'] as String?)?.trim() ??
          (json['option_id'] as String?)?.trim() ??
          '',
      label:
          (json['label'] as String?)?.trim() ??
          (json['text'] as String?)?.trim() ??
          '',
      metadata:
          (json['metadata'] as Map?)?.cast<String, dynamic>() ??
          <String, dynamic>{},
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    if (metadata.isNotEmpty) 'metadata': metadata,
  };
}

sealed class InteractiveBlock {
  const InteractiveBlock({required this.kind, this.metadata = const {}});

  final String kind;
  final Map<String, dynamic> metadata;

  factory InteractiveBlock.fromJson(Map<String, dynamic> json) {
    final kind = (json['kind'] as String?)?.trim() ?? '';
    switch (kind) {
      case 'text':
        return InteractiveTextBlock.fromJson(json);
      case 'choice_group':
        return InteractiveChoiceGroupBlock.fromJson(json);
      case 'quiz':
        return InteractiveQuizBlock.fromJson(json);
      case 'media':
        return InteractiveMediaBlock.fromJson(json);
      case 'timer':
        return InteractiveTimerBlock.fromJson(json);
      case 'scoreboard':
        return InteractiveScoreboardBlock.fromJson(json);
      case 'private_prompt':
        return InteractivePrivatePromptBlock.fromJson(json);
      case 'system':
        return InteractiveSystemBlock.fromJson(json);
      default:
        return InteractiveUnknownBlock.fromJson(json);
    }
  }

  Map<String, dynamic> toJson();

  static Map<String, dynamic> _metadata(Map<String, dynamic> json) =>
      (json['metadata'] as Map?)?.cast<String, dynamic>() ??
      <String, dynamic>{};
}

class InteractiveTextBlock extends InteractiveBlock {
  const InteractiveTextBlock({required this.text, super.metadata = const {}})
    : super(kind: 'text');

  final String text;

  factory InteractiveTextBlock.fromJson(Map<String, dynamic> json) {
    return InteractiveTextBlock(
      text:
          (json['text'] as String?)?.trim() ??
          (json['content'] as String?)?.trim() ??
          '',
      metadata: InteractiveBlock._metadata(json),
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'kind': kind,
    'text': text,
    if (metadata.isNotEmpty) 'metadata': metadata,
  };
}

class InteractiveChoiceGroupBlock extends InteractiveBlock {
  const InteractiveChoiceGroupBlock({
    required this.prompt,
    this.options = const <InteractiveOption>[],
    super.metadata = const {},
  }) : super(kind: 'choice_group');

  final String prompt;
  final List<InteractiveOption> options;

  factory InteractiveChoiceGroupBlock.fromJson(Map<String, dynamic> json) {
    return InteractiveChoiceGroupBlock(
      prompt: (json['prompt'] as String?)?.trim() ?? '',
      options: _parseOptions(json['options']),
      metadata: InteractiveBlock._metadata(json),
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'kind': kind,
    'prompt': prompt,
    'options': options.map((e) => e.toJson()).toList(),
    if (metadata.isNotEmpty) 'metadata': metadata,
  };
}

class InteractiveQuizBlock extends InteractiveBlock {
  const InteractiveQuizBlock({
    required this.question,
    this.options = const <InteractiveOption>[],
    this.timeLimitMs,
    super.metadata = const {},
  }) : super(kind: 'quiz');

  final String question;
  final List<InteractiveOption> options;
  final int? timeLimitMs;

  factory InteractiveQuizBlock.fromJson(Map<String, dynamic> json) {
    return InteractiveQuizBlock(
      question: (json['question'] as String?)?.trim() ?? '',
      options: _parseOptions(json['options']),
      timeLimitMs: (json['time_limit_ms'] as num?)?.toInt(),
      metadata: InteractiveBlock._metadata(json),
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'kind': kind,
    'question': question,
    'options': options.map((e) => e.toJson()).toList(),
    if (timeLimitMs != null) 'time_limit_ms': timeLimitMs,
    if (metadata.isNotEmpty) 'metadata': metadata,
  };
}

class InteractiveMediaBlock extends InteractiveBlock {
  const InteractiveMediaBlock({
    required this.mediaType,
    required this.url,
    this.text,
    super.metadata = const {},
  }) : super(kind: 'media');

  final String mediaType;
  final String url;
  final String? text;

  factory InteractiveMediaBlock.fromJson(Map<String, dynamic> json) {
    return InteractiveMediaBlock(
      mediaType: (json['media_type'] as String?)?.trim() ?? 'image',
      url: (json['url'] as String?)?.trim() ?? '',
      text: (json['text'] as String?)?.trim(),
      metadata: InteractiveBlock._metadata(json),
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'kind': kind,
    'media_type': mediaType,
    'url': url,
    if (text != null) 'text': text,
    if (metadata.isNotEmpty) 'metadata': metadata,
  };
}

class InteractiveTimerBlock extends InteractiveBlock {
  const InteractiveTimerBlock({this.expiresAt, super.metadata = const {}})
    : super(kind: 'timer');

  final DateTime? expiresAt;

  factory InteractiveTimerBlock.fromJson(Map<String, dynamic> json) {
    return InteractiveTimerBlock(
      expiresAt: _parseDate(json['expires_at']),
      metadata: InteractiveBlock._metadata(json),
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'kind': kind,
    if (expiresAt != null) 'expires_at': expiresAt!.toIso8601String(),
    if (metadata.isNotEmpty) 'metadata': metadata,
  };
}

class InteractiveScoreboardBlock extends InteractiveBlock {
  const InteractiveScoreboardBlock({
    this.players = const <Map<String, dynamic>>[],
    super.metadata = const {},
  }) : super(kind: 'scoreboard');

  final List<Map<String, dynamic>> players;

  factory InteractiveScoreboardBlock.fromJson(Map<String, dynamic> json) {
    return InteractiveScoreboardBlock(
      players: ((json['players'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList(),
      metadata: InteractiveBlock._metadata(json),
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'kind': kind,
    'players': players,
    if (metadata.isNotEmpty) 'metadata': metadata,
  };
}

class InteractivePrivatePromptBlock extends InteractiveBlock {
  const InteractivePrivatePromptBlock({
    required this.text,
    super.metadata = const {},
  }) : super(kind: 'private_prompt');

  final String text;

  factory InteractivePrivatePromptBlock.fromJson(Map<String, dynamic> json) {
    return InteractivePrivatePromptBlock(
      text:
          (json['text'] as String?)?.trim() ??
          (json['prompt'] as String?)?.trim() ??
          '',
      metadata: InteractiveBlock._metadata(json),
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'kind': kind,
    'text': text,
    if (metadata.isNotEmpty) 'metadata': metadata,
  };
}

class InteractiveSystemBlock extends InteractiveBlock {
  const InteractiveSystemBlock({required this.text, super.metadata = const {}})
    : super(kind: 'system');

  final String text;

  factory InteractiveSystemBlock.fromJson(Map<String, dynamic> json) {
    return InteractiveSystemBlock(
      text: (json['text'] as String?)?.trim() ?? '',
      metadata: InteractiveBlock._metadata(json),
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'kind': kind,
    'text': text,
    if (metadata.isNotEmpty) 'metadata': metadata,
  };
}

class InteractiveUnknownBlock extends InteractiveBlock {
  const InteractiveUnknownBlock({
    required super.kind,
    required this.raw,
    super.metadata = const {},
  });

  final Map<String, dynamic> raw;

  factory InteractiveUnknownBlock.fromJson(Map<String, dynamic> json) {
    return InteractiveUnknownBlock(
      kind: (json['kind'] as String?)?.trim() ?? 'unknown',
      raw: json,
      metadata: InteractiveBlock._metadata(json),
    );
  }

  @override
  Map<String, dynamic> toJson() => raw;
}

class InteractiveSpeaker {
  const InteractiveSpeaker({
    this.type = 'ai',
    this.role = 'host',
    this.userId,
    this.displayName,
  });

  final String type;
  final String role;
  final String? userId;
  final String? displayName;

  factory InteractiveSpeaker.fromJson(Map<String, dynamic> json) {
    return InteractiveSpeaker(
      type: (json['type'] as String?)?.trim() ?? 'ai',
      role: (json['role'] as String?)?.trim() ?? 'host',
      userId: (json['user_id'] as String?)?.trim(),
      displayName: (json['display_name'] as String?)?.trim(),
    );
  }

  Map<String, dynamic> toJson() => {
    'type': type,
    'role': role,
    if (userId != null) 'user_id': userId,
    if (displayName != null) 'display_name': displayName,
  };
}

class InteractiveTurn {
  const InteractiveTurn({
    required this.type,
    required this.sessionId,
    required this.turnId,
    required this.seq,
    required this.speaker,
    this.blocks = const <InteractiveBlock>[],
    this.inputRequests = const <Map<String, dynamic>>[],
    this.statePatch = const <String, dynamic>{},
  });

  final String type;
  final String sessionId;
  final String turnId;
  final int seq;
  final InteractiveSpeaker speaker;
  final List<InteractiveBlock> blocks;
  final List<Map<String, dynamic>> inputRequests;
  final Map<String, dynamic> statePatch;

  factory InteractiveTurn.fromJson(Map<String, dynamic> json) {
    return InteractiveTurn(
      type: (json['type'] as String?)?.trim() ?? 'interactive_turn.v1',
      sessionId: (json['session_id'] as String?)?.trim() ?? '',
      turnId: (json['turn_id'] as String?)?.trim() ?? '',
      seq: (json['seq'] as num?)?.toInt() ?? 0,
      speaker: InteractiveSpeaker.fromJson(
        (json['speaker'] as Map?)?.cast<String, dynamic>() ??
            <String, dynamic>{},
      ),
      blocks: ((json['blocks'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => InteractiveBlock.fromJson(e.cast<String, dynamic>()))
          .toList(),
      inputRequests: ((json['input_requests'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList(),
      statePatch:
          (json['state_patch'] as Map?)?.cast<String, dynamic>() ??
          <String, dynamic>{},
    );
  }

  Map<String, dynamic> toJson() => {
    'type': type,
    'session_id': sessionId,
    'turn_id': turnId,
    'seq': seq,
    'speaker': speaker.toJson(),
    'blocks': blocks.map((e) => e.toJson()).toList(),
    'input_requests': inputRequests,
    'state_patch': statePatch,
  };
}

class StoryParticipant {
  const StoryParticipant({
    required this.id,
    required this.sessionId,
    this.userId,
    this.deviceId,
    this.displayName,
    required this.role,
    required this.status,
    required this.score,
    this.metadata = const <String, dynamic>{},
    this.joinedAt,
    this.lastSeenAt,
    this.leftAt,
  });

  final String id;
  final String sessionId;
  final String? userId;
  final String? deviceId;
  final String? displayName;
  final String role;
  final String status;
  final int score;
  final Map<String, dynamic> metadata;
  final DateTime? joinedAt;
  final DateTime? lastSeenAt;
  final DateTime? leftAt;

  factory StoryParticipant.fromJson(Map<String, dynamic> json) {
    return StoryParticipant(
      id: (json['id'] as String?)?.trim() ?? '',
      sessionId: (json['session_id'] as String?)?.trim() ?? '',
      userId: (json['user_id'] as String?)?.trim(),
      deviceId: (json['device_id'] as String?)?.trim(),
      displayName: (json['display_name'] as String?)?.trim(),
      role: (json['role'] as String?)?.trim() ?? 'participant',
      status: (json['status'] as String?)?.trim() ?? 'active',
      score: (json['score'] as num?)?.toInt() ?? 0,
      metadata:
          (json['participant_metadata'] as Map?)?.cast<String, dynamic>() ??
          <String, dynamic>{},
      joinedAt: _parseDate(json['joined_at']),
      lastSeenAt: _parseDate(json['last_seen_at']),
      leftAt: _parseDate(json['left_at']),
    );
  }
}

class StorySessionEvent {
  const StorySessionEvent({
    required this.id,
    required this.sessionId,
    required this.seq,
    this.actorUserId,
    this.actorParticipantId,
    required this.actorType,
    required this.eventType,
    this.payload = const <String, dynamic>{},
    this.visibility = 'public',
    this.targetUserIds = const <String>[],
    this.createdAt,
  });

  final String id;
  final String sessionId;
  final int seq;
  final String? actorUserId;
  final String? actorParticipantId;
  final String actorType;
  final String eventType;
  final Map<String, dynamic> payload;
  final String visibility;
  final List<String> targetUserIds;
  final DateTime? createdAt;

  factory StorySessionEvent.fromJson(Map<String, dynamic> json) {
    return StorySessionEvent(
      id: (json['id'] as String?)?.trim() ?? '',
      sessionId: (json['session_id'] as String?)?.trim() ?? '',
      seq: (json['seq'] as num?)?.toInt() ?? 0,
      actorUserId: (json['actor_user_id'] as String?)?.trim(),
      actorParticipantId: (json['actor_participant_id'] as String?)?.trim(),
      actorType: (json['actor_type'] as String?)?.trim() ?? 'system',
      eventType: (json['event_type'] as String?)?.trim() ?? '',
      payload:
          (json['payload'] as Map?)?.cast<String, dynamic>() ??
          <String, dynamic>{},
      visibility: (json['visibility'] as String?)?.trim() ?? 'public',
      targetUserIds: ((json['target_user_ids'] as List?) ?? const [])
          .whereType<String>()
          .toList(),
      createdAt: _parseDate(json['created_at']),
    );
  }
}

class InteractiveSessionState {
  const InteractiveSessionState({
    required this.sessionId,
    required this.storyId,
    this.joinCode,
    required this.interactionMode,
    required this.aiRole,
    this.interactiveState = const <String, dynamic>{},
    this.participants = const <StoryParticipant>[],
    this.events = const <StorySessionEvent>[],
    this.currentTurn,
    this.lastSeq = 0,
    this.isCompleted = false,
    this.createdAt,
    this.updatedAt,
  });

  final String sessionId;
  final String storyId;
  final String? joinCode;
  final String interactionMode;
  final String aiRole;
  final Map<String, dynamic> interactiveState;
  final List<StoryParticipant> participants;
  final List<StorySessionEvent> events;
  final InteractiveTurn? currentTurn;
  final int lastSeq;
  final bool isCompleted;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory InteractiveSessionState.fromJson(Map<String, dynamic> json) {
    return InteractiveSessionState(
      sessionId: (json['session_id'] as String?)?.trim() ?? '',
      storyId: (json['story_id'] as String?)?.trim() ?? '',
      joinCode: (json['join_code'] as String?)?.trim(),
      interactionMode:
          (json['interaction_mode'] as String?)?.trim() ?? 'narrative',
      aiRole: (json['ai_role'] as String?)?.trim() ?? 'narrator',
      interactiveState:
          (json['interactive_state'] as Map?)?.cast<String, dynamic>() ??
          <String, dynamic>{},
      participants: ((json['participants'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => StoryParticipant.fromJson(e.cast<String, dynamic>()))
          .toList(),
      events: ((json['events'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => StorySessionEvent.fromJson(e.cast<String, dynamic>()))
          .toList(),
      currentTurn: json['current_turn'] is Map
          ? InteractiveTurn.fromJson(
              (json['current_turn'] as Map).cast<String, dynamic>(),
            )
          : null,
      lastSeq: (json['last_seq'] as num?)?.toInt() ?? 0,
      isCompleted: json['is_completed'] as bool? ?? false,
      createdAt: _parseDate(json['created_at']),
      updatedAt: _parseDate(json['updated_at']),
    );
  }

  InteractiveSessionState copyWith({
    Map<String, dynamic>? interactiveState,
    List<StoryParticipant>? participants,
    List<StorySessionEvent>? events,
    InteractiveTurn? currentTurn,
    int? lastSeq,
  }) {
    return InteractiveSessionState(
      sessionId: sessionId,
      storyId: storyId,
      joinCode: joinCode,
      interactionMode: interactionMode,
      aiRole: aiRole,
      interactiveState: interactiveState ?? this.interactiveState,
      participants: participants ?? this.participants,
      events: events ?? this.events,
      currentTurn: currentTurn ?? this.currentTurn,
      lastSeq: lastSeq ?? this.lastSeq,
      isCompleted: isCompleted,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

class InteractiveInput {
  const InteractiveInput({
    required this.inputType,
    this.questionId,
    this.value,
    this.optionId,
    this.text,
    this.metadata = const <String, dynamic>{},
    this.idempotencyKey,
  });

  final String inputType;
  final String? questionId;
  final dynamic value;
  final String? optionId;
  final String? text;
  final Map<String, dynamic> metadata;
  final String? idempotencyKey;

  Map<String, dynamic> toJson() => {
    'input_type': inputType,
    if (questionId != null) 'question_id': questionId,
    if (value != null) 'value': value,
    if (optionId != null) 'option_id': optionId,
    if (text != null) 'text': text,
    'metadata': metadata,
    if (idempotencyKey != null) 'idempotency_key': idempotencyKey,
  };
}

class InteractiveInputResponse {
  const InteractiveInputResponse({
    required this.status,
    required this.event,
    this.turn,
    this.state = const <String, dynamic>{},
  });

  final String status;
  final StorySessionEvent event;
  final InteractiveTurn? turn;
  final Map<String, dynamic> state;

  factory InteractiveInputResponse.fromJson(Map<String, dynamic> json) {
    return InteractiveInputResponse(
      status: (json['status'] as String?)?.trim() ?? '',
      event: StorySessionEvent.fromJson(
        (json['event'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{},
      ),
      turn: json['turn'] is Map
          ? InteractiveTurn.fromJson(
              (json['turn'] as Map).cast<String, dynamic>(),
            )
          : null,
      state:
          (json['state'] as Map?)?.cast<String, dynamic>() ??
          <String, dynamic>{},
    );
  }
}

List<InteractiveOption> _parseOptions(dynamic raw) {
  return ((raw as List?) ?? const [])
      .whereType<Map>()
      .map((e) => InteractiveOption.fromJson(e.cast<String, dynamic>()))
      .where((option) => option.id.isNotEmpty || option.label.isNotEmpty)
      .toList();
}

DateTime? _parseDate(dynamic raw) {
  if (raw is String && raw.trim().isNotEmpty) {
    final value = raw.trim();
    final hasTimezone = RegExp(r'(Z|[+-]\d\d:\d\d)$').hasMatch(value);
    return DateTime.tryParse(hasTimezone ? value : '${value}Z')?.toUtc();
  }
  return null;
}
