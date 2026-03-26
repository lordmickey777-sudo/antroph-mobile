/// Models for robot expression synchronization with AI voice responses
library;

/// Core expression enum matching backend expressions
enum RobotExpression {
  neutral('neutral'),
  smile('smile'),
  blink('blink'),
  frown('frown'),
  thinking('thinking'),
  surprised('surprised'),
  happy('happy'),
  sad('sad');

  const RobotExpression(this.value);
  final String value;

  /// Get asset path for the expression image
  String get assetPath => 'assets/images/antroph_$value.png';

  /// Parse from string value
  static RobotExpression fromString(String value) {
    return RobotExpression.values.firstWhere(
      (e) => e.value == value,
      orElse: () => RobotExpression.neutral,
    );
  }
}

/// Expression timing data from backend
class ExpressionTiming {
  final RobotExpression action;
  final double startTime;
  final double? duration;

  const ExpressionTiming({
    required this.action,
    required this.startTime,
    this.duration,
  });

  factory ExpressionTiming.fromJson(Map<String, dynamic> json) {
    return ExpressionTiming(
      action: RobotExpression.fromString(json['action'] as String),
      startTime: (json['start_time'] as num).toDouble(),
      duration: json['duration'] != null
          ? (json['duration'] as num).toDouble()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'action': action.value,
      'start_time': startTime,
      if (duration != null) 'duration': duration,
    };
  }

  @override
  String toString() =>
      'ExpressionTiming(action: ${action.value}, startTime: $startTime, duration: $duration)';
}

/// Voice chat response from backend
class VoiceChatResponse {
  final String transcription;
  final String text;
  final String audioUrl; // Base64 encoded MP3: "data:audio/mpeg;base64,<data>"
  final String conversationId;
  final List<ExpressionTiming> expressions;
  final int tokensUsed;

  const VoiceChatResponse({
    required this.transcription,
    required this.text,
    required this.audioUrl,
    required this.conversationId,
    required this.expressions,
    required this.tokensUsed,
  });

  factory VoiceChatResponse.fromJson(Map<String, dynamic> json) {
    return VoiceChatResponse(
      transcription: json['transcription'] as String,
      text: json['text'] as String,
      audioUrl: json['audio_url'] as String,
      conversationId: json['conversation_id'] as String,
      expressions: (json['expressions'] as List<dynamic>)
          .map((e) => ExpressionTiming.fromJson(e as Map<String, dynamic>))
          .toList(),
      tokensUsed: json['tokens_used'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'transcription': transcription,
      'text': text,
      'audio_url': audioUrl,
      'conversation_id': conversationId,
      'expressions': expressions.map((e) => e.toJson()).toList(),
      'tokens_used': tokensUsed,
    };
  }

  /// Check if audio is base64 encoded
  bool get isBase64Audio => audioUrl.startsWith('data:audio/');

  /// Extract base64 data from data URL
  String get base64Data {
    if (!isBase64Audio) return '';
    final parts = audioUrl.split(',');
    return parts.length > 1 ? parts[1] : '';
  }

  @override
  String toString() =>
      'VoiceChatResponse(transcription: $transcription, text: $text, conversationId: $conversationId, expressions: ${expressions.length}, tokensUsed: $tokensUsed)';
}

/// Realtime mascot expression event emitted during active voice sessions.
class MascotExpressionEvent {
  const MascotExpressionEvent({
    required this.expression,
    this.intensity = 1.0,
    this.durationMs = 2000,
    this.riveElementId,
    this.riveUrl,
    this.timestamp,
  });

  final String expression;
  final double intensity;
  final int durationMs;
  final String? riveElementId;
  final String? riveUrl;
  final DateTime? timestamp;

  factory MascotExpressionEvent.fromJson(Map<String, dynamic> json) {
    final rawExpression = (json['expression'] as String?)?.trim();
    final rawIntensity = (json['intensity'] as num?)?.toDouble() ?? 1.0;
    final rawDuration = (json['duration_ms'] as num?)?.toInt() ?? 2000;
    final rawTimestamp = json['timestamp'] as String?;

    return MascotExpressionEvent(
      expression: (rawExpression == null || rawExpression.isEmpty)
          ? RobotExpression.neutral.value
          : rawExpression,
      intensity: rawIntensity.clamp(0.0, 1.0),
      durationMs: rawDuration < 0 ? 0 : rawDuration,
      riveElementId: (json['rive_element_id'] as String?)?.trim(),
      riveUrl: (json['rive_url'] as String?)?.trim(),
      timestamp: rawTimestamp == null || rawTimestamp.isEmpty
          ? null
          : DateTime.tryParse(rawTimestamp)?.toUtc(),
    );
  }
}
