import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Minimal realtime voice WebSocket client.
///
/// The backend is responsible for configuring the OpenAI session; this client
/// only streams JSON frames.
class RealtimeVoiceClient {
  WebSocket? _socket;
  StreamController<Map<String, dynamic>> _incoming =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get messages => _incoming.stream;

  bool get isOpen => _socket?.readyState == WebSocket.open;

  Future<void> connect(Uri uri) async {
    await close();
    if (_incoming.isClosed) {
      _incoming = StreamController<Map<String, dynamic>>.broadcast();
    }
    _socket = await WebSocket.connect(uri.toString());
    _socket!.listen(
      (data) {
        try {
          final msg = jsonDecode(data as String) as Map<String, dynamic>;
          _incoming.add(msg);
        } catch (_) {
          _socket?.close(WebSocketStatus.unsupportedData, 'Invalid JSON');
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

  Future<void> close([int code = WebSocketStatus.normalClosure]) async {
    await _socket?.close(code);
  }
}
