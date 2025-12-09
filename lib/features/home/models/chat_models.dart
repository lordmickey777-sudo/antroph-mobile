import 'dart:convert';

enum ChatEnvelopeType { chat, face, presence, error, ping, pong, ack, unknown }

ChatEnvelopeType chatEnvelopeTypeFromString(String raw) {
  switch (raw.toLowerCase()) {
    case 'chat':
      return ChatEnvelopeType.chat;
    case 'face':
      return ChatEnvelopeType.face;
    case 'presence':
      return ChatEnvelopeType.presence;
    case 'error':
      return ChatEnvelopeType.error;
    case 'ping':
      return ChatEnvelopeType.ping;
    case 'pong':
      return ChatEnvelopeType.pong;
    case 'ack':
      return ChatEnvelopeType.ack;
    default:
      return ChatEnvelopeType.unknown;
  }
}

class ChatEnvelope {
  ChatEnvelope({required this.type, this.data, this.id, this.ts, this.raw});

  final ChatEnvelopeType type;
  final Map<String, dynamic>? data;
  final String? id;
  final DateTime? ts;
  final dynamic raw;

  factory ChatEnvelope.fromJson(Map<String, dynamic> json) {
    final ts = json['ts'];
    DateTime? parsedTs;
    if (ts is num) {
      final millis = ts.toInt();
      parsedTs = DateTime.fromMillisecondsSinceEpoch(millis);
    } else if (ts is String) {
      parsedTs = DateTime.tryParse(ts);
    }
    Map<String, dynamic>? data;
    final rawData = json['data'];
    if (rawData is Map<String, dynamic>) {
      data = rawData;
    } else if (rawData is Map) {
      data = rawData.cast<String, dynamic>();
    }
    return ChatEnvelope(
      type: chatEnvelopeTypeFromString((json['type'] as String?) ?? ''),
      id: json['id']?.toString(),
      data: data,
      ts: parsedTs,
      raw: json,
    );
  }

  factory ChatEnvelope.fromSocketData(dynamic data) {
    if (data is String) {
      try {
        final parsed = ChatEnvelope.fromJson(
          (jsonDecode(data) as Map).cast<String, dynamic>(),
        );
        return parsed;
      } catch (_) {
        // Fall through to unknown envelope.
      }
    } else if (data is Map) {
      return ChatEnvelope.fromJson(data.cast<String, dynamic>());
    }
    return ChatEnvelope(type: ChatEnvelopeType.unknown, raw: data);
  }

  Map<String, dynamic> toJson() {
    return {
      'type': _typeToString(type),
      if (id != null) 'id': id,
      if (ts != null) 'ts': ts!.millisecondsSinceEpoch,
      if (data != null) 'data': data,
    };
  }

  static String _typeToString(ChatEnvelopeType type) {
    switch (type) {
      case ChatEnvelopeType.chat:
        return 'chat';
      case ChatEnvelopeType.face:
        return 'face';
      case ChatEnvelopeType.presence:
        return 'presence';
      case ChatEnvelopeType.error:
        return 'error';
      case ChatEnvelopeType.ping:
        return 'ping';
      case ChatEnvelopeType.pong:
        return 'pong';
      case ChatEnvelopeType.ack:
        return 'ack';
      case ChatEnvelopeType.unknown:
        return 'unknown';
    }
  }
}

enum ChatRole { user, assistant }

ChatRole chatRoleFromString(String raw) {
  switch (raw.toLowerCase()) {
    case 'user':
      return ChatRole.user;
    case 'assistant':
      return ChatRole.assistant;
    default:
      return ChatRole.assistant;
  }
}

enum ChatDeliveryState { sending, sent, failed }

class ChatMessageModel {
  ChatMessageModel({
    required this.id,
    required this.role,
    required this.message,
    required this.ts,
    this.delivery = ChatDeliveryState.sent,
  });

  final String id;
  final ChatRole role;
  final String message;
  final DateTime ts;
  final ChatDeliveryState delivery;

  bool get isUser => role == ChatRole.user;
  bool get isFailed => delivery == ChatDeliveryState.failed;
  bool get isPending => delivery == ChatDeliveryState.sending;

  ChatMessageModel copyWith({
    String? id,
    ChatRole? role,
    String? message,
    DateTime? ts,
    ChatDeliveryState? delivery,
  }) {
    return ChatMessageModel(
      id: id ?? this.id,
      role: role ?? this.role,
      message: message ?? this.message,
      ts: ts ?? this.ts,
      delivery: delivery ?? this.delivery,
    );
  }
}

class FaceEyes {
  FaceEyes({required this.x, required this.y, required this.blink});

  final double x;
  final double y;
  final double blink;

  factory FaceEyes.fromJson(Map<String, dynamic>? json) {
    final map = json ?? const <String, dynamic>{};
    return FaceEyes(
      x: _clamp(map['x'] as num? ?? 0, -1, 1),
      y: _clamp(map['y'] as num? ?? 0, -1, 1),
      blink: _clamp(map['blink'] as num? ?? 0, 0, 1),
    );
  }

  FaceEyes copyWith({double? x, double? y, double? blink}) {
    return FaceEyes(x: x ?? this.x, y: y ?? this.y, blink: blink ?? this.blink);
  }
}

class FaceMouth {
  FaceMouth({required this.open, required this.smile, required this.talking});

  final double open;
  final double smile;
  final bool talking;

  factory FaceMouth.fromJson(Map<String, dynamic>? json) {
    final map = json ?? const <String, dynamic>{};
    return FaceMouth(
      open: _clamp(map['open'] as num? ?? 0, 0, 1),
      smile: _clamp(map['smile'] as num? ?? 0, -1, 1),
      talking: map['talking'] == true,
    );
  }

  FaceMouth copyWith({double? open, double? smile, bool? talking}) {
    return FaceMouth(
      open: open ?? this.open,
      smile: smile ?? this.smile,
      talking: talking ?? this.talking,
    );
  }
}

class FacePose {
  FacePose({required this.eyes, required this.mouth, DateTime? updatedAt})
    : updatedAt = updatedAt ?? DateTime.now();

  final FaceEyes eyes;
  final FaceMouth mouth;
  final DateTime updatedAt;

  static FacePose neutral({DateTime? updatedAt}) {
    return FacePose(
      eyes: FaceEyes(x: 0, y: 0, blink: 0),
      mouth: FaceMouth(open: 0, smile: 0, talking: false),
      updatedAt: updatedAt,
    );
  }

  factory FacePose.fromJson(Map<String, dynamic> json, {DateTime? ts}) {
    return FacePose(
      eyes: FaceEyes.fromJson(json['eyes'] as Map<String, dynamic>?),
      mouth: FaceMouth.fromJson(json['mouth'] as Map<String, dynamic>?),
      updatedAt: ts ?? DateTime.now(),
    );
  }

  FacePose copyWith({FaceEyes? eyes, FaceMouth? mouth, DateTime? updatedAt}) {
    return FacePose(
      eyes: eyes ?? this.eyes,
      mouth: mouth ?? this.mouth,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static FacePose lerp(FacePose a, FacePose b, double t) {
    final clampedT = t.clamp(0.0, 1.0);
    return FacePose(
      eyes: FaceEyes(
        x: _lerpDouble(a.eyes.x, b.eyes.x, clampedT),
        y: _lerpDouble(a.eyes.y, b.eyes.y, clampedT),
        blink: _lerpDouble(a.eyes.blink, b.eyes.blink, clampedT),
      ),
      mouth: FaceMouth(
        open: _lerpDouble(a.mouth.open, b.mouth.open, clampedT),
        smile: _lerpDouble(a.mouth.smile, b.mouth.smile, clampedT),
        talking: clampedT < 1
            ? a.mouth.talking || b.mouth.talking
            : b.mouth.talking,
      ),
      updatedAt: DateTime.now(),
    );
  }
}

double _clamp(num value, num min, num max) => value.clamp(min, max).toDouble();
double _lerpDouble(double a, double b, double t) => a + (b - a) * t;
