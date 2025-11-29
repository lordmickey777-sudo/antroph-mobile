import 'dart:convert';

enum VoiceMessageType { connected, voiceResponse, voiceAudioChunk, error, ping, unknown }

VoiceMessageType voiceMessageTypeFromString(String raw) {
  switch (raw.toLowerCase()) {
    case 'connected':
      return VoiceMessageType.connected;
    case 'voice_response':
      return VoiceMessageType.voiceResponse;
    case 'voice_audio_chunk':
      return VoiceMessageType.voiceAudioChunk;
    case 'error':
      return VoiceMessageType.error;
    case 'ping':
      return VoiceMessageType.ping;
    default:
      return VoiceMessageType.unknown;
  }
}

class VoiceServerMessage {
  VoiceServerMessage({
    required this.type,
    this.data,
    this.requestId,
    this.timestamp,
    this.raw,
  });

  final VoiceMessageType type;
  final Map<String, dynamic>? data;
  final String? requestId;
  final DateTime? timestamp;
  final dynamic raw;

  factory VoiceServerMessage.fromSocketData(dynamic input) {
    if (input is String) {
      try {
        final decoded = jsonDecode(input);
        if (decoded is Map<String, dynamic>) {
          return VoiceServerMessage.fromJson(decoded);
        }
      } catch (_) {
        // Fall through to unknown message.
      }
    }
    return VoiceServerMessage(type: VoiceMessageType.unknown, raw: input);
  }

  factory VoiceServerMessage.fromJson(Map<String, dynamic> json) {
    final type = voiceMessageTypeFromString((json['type'] as String?) ?? '');
    final data = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : (json['data'] is Map ? (json['data'] as Map).cast<String, dynamic>() : null);
    final ts = json['timestamp'];
    DateTime? parsed;
    if (ts is String) {
      parsed = DateTime.tryParse(ts);
    } else if (ts is int) {
      parsed = DateTime.fromMillisecondsSinceEpoch(ts, isUtc: true);
    }
    return VoiceServerMessage(
      type: type,
      data: data,
      requestId: json['request_id'] as String?,
      timestamp: parsed,
      raw: json,
    );
  }
}

class VoiceConnectedPayload {
  VoiceConnectedPayload({
    this.reconnectToken,
    this.deviceId,
    this.deviceType,
    this.serverTime,
    this.capabilities = const <String>[],
    this.audioFormats = const <String>[],
  });

  final String? reconnectToken;
  final String? deviceId;
  final String? deviceType;
  final int? serverTime;
  final List<String> capabilities;
  final List<String> audioFormats;

  factory VoiceConnectedPayload.fromJson(Map<String, dynamic> json) => VoiceConnectedPayload(
        reconnectToken: json['reconnect_token'] as String?,
        deviceId: json['device_id'] as String?,
        deviceType: json['device_type'] as String?,
        serverTime: (json['server_time'] as num?)?.toInt(),
        capabilities: ((json['capabilities'] as List?) ?? const [])
            .whereType<String>()
            .map((e) => e.toString())
            .toList(),
        audioFormats: ((json['audio_formats'] as List?) ?? const [])
            .whereType<String>()
            .map((e) => e.toString())
            .toList(),
      );
}

class VoiceResponseAck {
  const VoiceResponseAck({this.message, this.transcription, this.aiText});

  final String? message;
  final String? transcription;
  final String? aiText;

  factory VoiceResponseAck.fromJson(Map<String, dynamic> json) => VoiceResponseAck(
        message: json['message'] as String?,
        transcription: json['transcription'] as String?,
        aiText: json['ai_text'] as String?,
      );
}

class VoiceExpressionFrame {
  VoiceExpressionFrame({
    required this.timestampMs,
    required this.packedFace,
    this.durationMs,
    this.subtitle,
    this.heading,
    this.headingDelta,
  });

  final int? timestampMs;
  final String packedFace;
  final int? durationMs;
  final String? subtitle;
  final List<num>? heading;
  final List<num>? headingDelta;

  factory VoiceExpressionFrame.fromJson(Map<String, dynamic> json) => VoiceExpressionFrame(
        timestampMs: (json['t'] as num?)?.toInt(),
        packedFace: (json['f'] as String?) ?? '',
        durationMs: (json['duration'] as num?)?.toInt(),
        subtitle: json['s'] as String?,
        heading: (json['h'] as List?)?.whereType<num>().toList(),
        headingDelta: (json['hd'] as List?)?.whereType<num>().toList(),
      );
}

class VoiceAudioChunk {
  VoiceAudioChunk({
    required this.sequenceId,
    this.sequence,
    this.chunkIndex,
    this.data,
    this.chunkServerTime,
    this.frames = const <VoiceExpressionFrame>[],
    this.isFinal = false,
  });

  final String sequenceId;
  final int? sequence;
  final int? chunkIndex;
  final String? data;
  final int? chunkServerTime;
  final List<VoiceExpressionFrame> frames;
  final bool isFinal;

  factory VoiceAudioChunk.fromJson(Map<String, dynamic> json) => VoiceAudioChunk(
        sequenceId: (json['sequence_id'] as String?) ?? '',
        sequence: (json['sequence'] as num?)?.toInt(),
        chunkIndex: (json['chunk_index'] as num?)?.toInt(),
        data: json['data'] as String?,
        chunkServerTime: (json['chunk_server_time'] as num?)?.toInt(),
        frames: ((json['frames'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => VoiceExpressionFrame.fromJson(e.cast<String, dynamic>()))
            .toList(),
        isFinal: json['is_final'] == true,
      );
}

class VoiceErrorPayload {
  const VoiceErrorPayload({this.code, this.message, this.severity, this.details});

  final String? code;
  final String? message;
  final String? severity;
  final Map<String, dynamic>? details;

  factory VoiceErrorPayload.fromJson(Map<String, dynamic> json) => VoiceErrorPayload(
        code: json['code'] as String?,
        message: json['message'] as String?,
        severity: json['severity'] as String?,
        details: json['details'] is Map ? (json['details'] as Map).cast<String, dynamic>() : null,
      );
}
