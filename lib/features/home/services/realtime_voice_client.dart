import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../models/realtime_voice_bridge_models.dart';

/// Incoming message from the realtime voice bridge.
class RealtimeIncomingMessage {
  const RealtimeIncomingMessage.json(this.json, this.type) : bytes = null;
  const RealtimeIncomingMessage.binary(this.bytes)
      : json = null,
        type = RealtimeServerMessageType.unknown;

  final Map<String, dynamic>? json;
  final Uint8List? bytes;
  final RealtimeServerMessageType type;

  bool get isJson => json != null;
  bool get isBinary => bytes != null;
}

/// Configuration for connecting to the realtime voice bridge.
class RealtimeVoiceConfig {
  final String? token;
  final String? storySessionId;

  const RealtimeVoiceConfig({
    this.token,
    this.storySessionId,
  });

  /// Build query parameters for the WebSocket URL.
  Map<String, String> toQueryParams() {
    final params = <String, String>{};
    if (token != null && token!.isNotEmpty) {
      params['token'] = token!;
    }
    if (storySessionId != null && storySessionId!.isNotEmpty) {
      params['story_session_id'] = storySessionId!;
    }
    return params;
  }
}

/// Realtime voice WebSocket client for the voice bridge.
///
/// Connects to `/ws/realtime/voice` with token and optional story_session_id.
/// Handles JSON and binary audio frames.
class RealtimeVoiceClient {
  WebSocket? _socket;
  StreamController<RealtimeIncomingMessage> _incoming =
      StreamController<RealtimeIncomingMessage>.broadcast();

  Stream<RealtimeIncomingMessage> get messages => _incoming.stream;

  bool get isOpen => _socket?.readyState == WebSocket.open;

  /// Connect to the realtime voice bridge.
  ///
  /// [baseUri] - The base WebSocket URI (e.g., wss://api.example.com/ws/realtime/voice)
  /// [config] - Configuration with token and optional story_session_id
  Future<void> connect(Uri baseUri, {RealtimeVoiceConfig? config}) async {
    await close();
    if (_incoming.isClosed) {
      _incoming = StreamController<RealtimeIncomingMessage>.broadcast();
    }

    // Add query parameters from config
    final queryParams = <String, String>{
      ...baseUri.queryParameters,
      ...?config?.toQueryParams(),
    };

    final uri = baseUri.replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

    _socket = await WebSocket.connect(uri.toString());
    _socket!.listen(
      (data) {
        if (data is String) {
          try {
            final msg = _decodeJson(data);
            if (msg != null) {
              final typeStr = (msg['type'] as String?) ?? '';
              final type = RealtimeServerMessageType.fromString(typeStr);
              _incoming.add(RealtimeIncomingMessage.json(msg, type));
            }
          } catch (_) {}
          return;
        }
        final bytes = _toBytes(data);
        if (bytes != null) {
          _incoming.add(RealtimeIncomingMessage.binary(bytes));
        }
      },
      onDone: () => _incoming.close(),
      onError: (_) => _incoming.close(),
      cancelOnError: true,
    );
  }

  /// Send a JSON message to the server.
  void send(Map<String, dynamic> message) {
    final socket = _socket;
    if (socket == null || socket.readyState != WebSocket.open) return;
    socket.add(jsonEncode(message));
  }

  /// Send a typed client message.
  void sendMessage(RealtimeClientMessageType type, Map<String, dynamic> payload) {
    send({
      'type': type.value,
      ...payload,
    });
  }

  /// Start a new story session.
  void sendStoryStart({
    required String storyId,
    required String deviceType,
    required String deviceId,
  }) {
    sendMessage(RealtimeClientMessageType.storyStart, {
      'story_id': storyId,
      'device_type': deviceType,
      'device_id': deviceId,
    });
  }

  /// Join an existing story room.
  void sendJoinRoom(String roomId) {
    sendMessage(RealtimeClientMessageType.joinRoom, {
      'room_id': roomId,
    });
  }

  /// Leave the current story room.
  void sendLeaveRoom() {
    sendMessage(RealtimeClientMessageType.leaveRoom, {});
  }

  /// Request device takeover for a session.
  void sendDeviceTakeover({
    required String sessionId,
    required String deviceType,
    required String deviceId,
  }) {
    sendMessage(RealtimeClientMessageType.deviceTakeover, {
      'session_id': sessionId,
      'device_type': deviceType,
      'device_id': deviceId,
    });
  }

  /// Pause the current story session.
  void sendStoryPause() {
    sendMessage(RealtimeClientMessageType.storyPause, {});
  }

  /// Resume a paused story session.
  void sendStoryResume() {
    sendMessage(RealtimeClientMessageType.storyResume, {});
  }

  /// Append audio data to the input buffer.
  void sendAudioAppend(String base64Audio, {int sampleRate = 24000}) {
    sendMessage(RealtimeClientMessageType.inputAudioBufferAppend, {
      'audio': base64Audio,
      'sample_rate': sampleRate,
    });
  }

  /// Commit the current audio buffer for transcription.
  void sendAudioCommit() {
    sendMessage(RealtimeClientMessageType.inputAudioBufferCommit, {});
  }

  /// Send binary audio data.
  void sendBinary(Uint8List data) {
    final socket = _socket;
    if (socket == null || socket.readyState != WebSocket.open) return;
    socket.add(data);
  }

  Future<void> close([int code = WebSocketStatus.normalClosure]) async {
    await _socket?.close(code);
  }

  Map<String, dynamic>? _decodeJson(String data) {
    try {
      return jsonDecode(data) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Uint8List? _toBytes(dynamic data) {
    if (data is Uint8List) return data;
    if (data is List<int>) return Uint8List.fromList(data);
    if (data is ByteBuffer) return data.asUint8List();
    return null;
  }
}
