import 'dart:convert';

/// Envelope used for all JSON control messages.
class StoryWsEnvelope {
  StoryWsEnvelope({
    required this.type,
    required this.payload,
    this.messageId,
    this.correlationId,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now().toUtc();

  final String type;
  final String? messageId;
  final String? correlationId;
  final DateTime timestamp;
  final Map<String, dynamic> payload;

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      if (messageId != null) 'message_id': messageId,
      if (correlationId != null) 'correlation_id': correlationId,
      'timestamp': timestamp.toIso8601String(),
      'payload': payload,
    };
  }

  String toEncoded() => jsonEncode(toJson());
}

/// Common server message wrapper (text or binary).
class StoryServerMessage {
  StoryServerMessage({
    required this.type,
    this.messageId,
    this.correlationId,
    this.timestamp,
    this.payload = const <String, dynamic>{},
    this.binary,
  });

  final String type;
  final String? messageId;
  final String? correlationId;
  final DateTime? timestamp;
  final Map<String, dynamic> payload;
  final List<int>? binary;

  bool get isBinary => binary != null;

  factory StoryServerMessage.fromJson(Map<String, dynamic> json) {
    return StoryServerMessage(
      type: (json['type'] as String?)?.trim() ?? '',
      messageId: (json['message_id'] as String?)?.trim(),
      correlationId: (json['correlation_id'] as String?)?.trim(),
      timestamp: _parseDate(json['timestamp']),
      payload: (json['payload'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{},
    );
  }

  factory StoryServerMessage.binary(List<int> bytes) {
    return StoryServerMessage(type: 'binary', binary: bytes);
  }

  static DateTime? _parseDate(dynamic raw) {
    if (raw is String && raw.isNotEmpty) {
      try {
        return DateTime.parse(raw).toUtc();
      } catch (_) {
        return null;
      }
    }
    return null;
  }
}

class StoryContext {
  StoryContext({required this.storyId, required this.sceneId, required this.nodeId, this.turnId});

  final String storyId;
  final String sceneId;
  final String nodeId;
  final String? turnId;

  factory StoryContext.fromJson(Map<String, dynamic> json) => StoryContext(
        storyId: (json['story_id'] as String?)?.trim() ?? '',
        sceneId: (json['scene_id'] as String?)?.trim() ?? '',
        nodeId: (json['node_id'] as String?)?.trim() ?? '',
        turnId: (json['turn_id'] as String?)?.trim(),
      );

  Map<String, dynamic> toJson() => {
        'story_id': storyId,
        'scene_id': sceneId,
        'node_id': nodeId,
        if (turnId != null) 'turn_id': turnId,
      };
}

class StoryChoiceOption {
  StoryChoiceOption({required this.choiceId, required this.label, this.nextNodeId, this.metadata});

  final String choiceId;
  final String label;
  final String? nextNodeId;
  final Map<String, dynamic>? metadata;

  factory StoryChoiceOption.fromJson(Map<String, dynamic> json) => StoryChoiceOption(
        choiceId: (json['choice_id'] as String?)?.trim() ?? '',
        label: (json['label'] as String?)?.trim() ?? '',
        nextNodeId: (json['next_node_id'] as String?)?.trim(),
        metadata: (json['metadata'] as Map?)?.cast<String, dynamic>(),
      );
}

class StoryExpression {
  StoryExpression({
    required this.offsetMs,
    required this.name,
    required this.durationMs,
    this.params = const <String, dynamic>{},
  });

  final int offsetMs;
  final String name;
  final int durationMs;
  final Map<String, dynamic> params;

  factory StoryExpression.fromJson(Map<String, dynamic> json) => StoryExpression(
        offsetMs: (json['offset_ms'] as num?)?.toInt() ?? 0,
        name: (json['name'] as String?)?.trim() ?? '',
        durationMs: (json['duration_ms'] as num?)?.toInt() ?? 0,
        params: (json['params'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{},
      );
}

class StoryAudioMeta {
  StoryAudioMeta({
    required this.audioId,
    required this.format,
    required this.lengthMs,
    this.sampleRate,
    this.expressions = const <StoryExpression>[],
    this.storyContext,
  });

  final String audioId;
  final String format;
  final int lengthMs;
  final int? sampleRate;
  final List<StoryExpression> expressions;
  final StoryContext? storyContext;

  factory StoryAudioMeta.fromJson(Map<String, dynamic> json) => StoryAudioMeta(
        audioId: (json['audio_id'] as String?)?.trim() ?? '',
        format: (json['format'] as String?)?.trim() ?? '',
        lengthMs: (json['length_ms'] as num?)?.toInt() ?? 0,
        sampleRate: (json['sample_rate'] as num?)?.toInt(),
        expressions: ((json['expressions'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => StoryExpression.fromJson(e.cast<String, dynamic>()))
            .toList(),
        storyContext: json['story_context'] is Map
            ? StoryContext.fromJson((json['story_context'] as Map).cast<String, dynamic>())
            : null,
      );
}

/// Parsed view of the latest node payload for quick UI consumption.
class StoryNodeView {
  StoryNodeView({
    required this.nodeId,
    required this.nodeType,
    required this.text,
    required this.audioExpected,
    this.audioFormat,
    this.storyContext,
    this.availableChoices = const <StoryChoiceOption>[],
    this.rawPayload = const <String, dynamic>{},
  });

  final String nodeId;
  final String nodeType;
  final String text;
  final bool audioExpected;
  final String? audioFormat;
  final StoryContext? storyContext;
  final List<StoryChoiceOption> availableChoices;
  final Map<String, dynamic> rawPayload;

  factory StoryNodeView.fromStoryState(Map<String, dynamic> payload) {
    final availableChoices = ((payload['available_choices'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => StoryChoiceOption.fromJson(e.cast<String, dynamic>()))
        .toList();
    final nodePayload = (payload['node_payload'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
    return StoryNodeView(
      nodeId: (payload['node_id'] as String?)?.trim() ?? '',
      nodeType: (payload['node_type'] as String?)?.trim() ?? '',
      text: (nodePayload['text'] as String?)?.trim() ?? '',
      audioExpected: (nodePayload['audio_expected'] as bool?) ?? false,
      audioFormat: (nodePayload['audio_format'] as String?)?.trim(),
      storyContext: payload['story_context'] is Map
          ? StoryContext.fromJson((payload['story_context'] as Map).cast<String, dynamic>())
          : null,
      availableChoices: availableChoices,
      rawPayload: payload,
    );
  }
}

class StorySocketError {
  StorySocketError({required this.code, required this.message, this.retryable});

  final String code;
  final String message;
  final bool? retryable;

  factory StorySocketError.fromJson(Map<String, dynamic> json) => StorySocketError(
        code: (json['code'] as String?)?.trim() ?? '',
        message: (json['message'] as String?)?.trim() ?? 'Unknown error',
        retryable: json['retryable'] as bool?,
      );
}

class StoryLogEntry {
  StoryLogEntry({required this.label, DateTime? at}) : at = at ?? DateTime.now().toUtc();

  final String label;
  final DateTime at;
}
