import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Minimal realtime voice WebSocket client.
///
/// The backend is responsible for configuring the OpenAI session; this client
/// only streams JSON frames.
class RealtimeIncomingMessage {
  const RealtimeIncomingMessage.json(this.json) : bytes = null;
  const RealtimeIncomingMessage.binary(this.bytes) : json = null;

  final Map<String, dynamic>? json;
  final Uint8List? bytes;

  bool get isJson => json != null;
  bool get isBinary => bytes != null;
}

class RealtimeVoiceClient {
  WebSocket? _socket;
  StreamController<RealtimeIncomingMessage> _incoming =
      StreamController<RealtimeIncomingMessage>.broadcast();

  Stream<RealtimeIncomingMessage> get messages => _incoming.stream;

  bool get isOpen => _socket?.readyState == WebSocket.open;

  Future<void> connect(Uri uri) async {
    await close();
    if (_incoming.isClosed) {
      _incoming = StreamController<RealtimeIncomingMessage>.broadcast();
    }
    _socket = await WebSocket.connect(uri.toString());
    _socket!.listen(
      (data) {
        if (data is String) {
          try {
            final msg = _decodeJson(data);
            if (msg != null) {
              _incoming.add(RealtimeIncomingMessage.json(msg));
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

  void send(Map<String, dynamic> message) {
    final socket = _socket;
    if (socket == null || socket.readyState != WebSocket.open) return;
    socket.add(jsonEncode(message));
  }

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
