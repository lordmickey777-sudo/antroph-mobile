import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:logger/logger.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/story_socket_models.dart';

/// Lightweight WebSocket client dedicated to the story-driven API contract.
class StoryWebSocketService {
  StoryWebSocketService._();
  static final StoryWebSocketService instance = StoryWebSocketService._();

  final _logger = Logger();
  final _messages = StreamController<StoryServerMessage>.broadcast();
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _pingTimer;
  Map<String, dynamic> _headers = const {};
  String? _url;

  Stream<StoryServerMessage> get messages => _messages.stream;

  bool get isConnected => _channel != null;

  /// Establish the socket connection with optional headers (e.g., Authorization).
  Future<void> connect({
    required String url,
    Map<String, dynamic>? headers,
    Duration? pingInterval,
  }) async {
    await disconnect('reconnect');
    _url = url;
    _headers = headers ?? const {};

    try {
      _channel = IOWebSocketChannel.connect(
        Uri.parse(url),
        headers: _headers.isEmpty ? null : _headers,
      );
      _logger.i('Story socket connected to $url');
      _subscription = _channel!.stream.listen(
        _handleIncoming,
        onError: (err, st) {
          _logger.e('Story socket error: $err', error: err, stackTrace: st);
          _messages.add(StoryServerMessage(
            type: 'socket_error',
            payload: {'message': '$err'},
          ));
        },
        onDone: () {
          _logger.i('Story socket closed');
          _messages.add(StoryServerMessage(type: 'socket_closed'));
          _cleanup();
        },
      );

      // Keepalive ping; spec allows ping/pong.
      _pingTimer = Timer.periodic(pingInterval ?? const Duration(seconds: 30), (_) => sendPing());
    } catch (e, st) {
      _logger.e('Failed to connect to story socket', error: e, stackTrace: st);
      await disconnect('connect_error');
      rethrow;
    }
  }

  /// Send a ping frame.
  void sendPing() {
    try {
      _channel?.sink.add(jsonEncode({'type': 'ping'}));
    } catch (e) {
      _logger.w('Ping failed: $e');
    }
  }

  /// Send a typed envelope to the server.
  void sendEnvelope(StoryWsEnvelope envelope) {
    final payload = envelope.toEncoded();
    _logger.d('→ $payload');
    _channel?.sink.add(payload);
  }

  /// Convenience for plain map payloads (already formatted as the envelope).
  void sendRaw(Map<String, dynamic> raw) {
    final payload = jsonEncode(raw);
    _logger.d('→ $payload');
    _channel?.sink.add(payload);
  }

  /// Disconnect and clean up resources.
  Future<void> disconnect([String reason = 'client_close']) async {
    _pingTimer?.cancel();
    _pingTimer = null;
    await _subscription?.cancel();
    _subscription = null;
    try {
      await _channel?.sink.close(WebSocketStatus.normalClosure, reason);
    } catch (_) {}
    _channel = null;
  }

  void _handleIncoming(dynamic data) {
    try {
      if (data is String) {
        _logger.d('← $data');
        final decoded = jsonDecode(data);
        if (decoded is Map<String, dynamic>) {
          _messages.add(StoryServerMessage.fromJson(decoded));
        }
      } else if (data is List<int>) {
        _logger.d('← binary frame (${data.length} bytes)');
        _messages.add(StoryServerMessage.binary(List<int>.from(data)));
      }
    } catch (e, st) {
      _logger.e('Failed to parse incoming socket data', error: e, stackTrace: st);
      _messages.add(StoryServerMessage(
        type: 'parse_error',
        payload: {'message': '$e'},
      ));
    }
  }

  void _cleanup() {
    _pingTimer?.cancel();
    _pingTimer = null;
    _subscription = null;
    _channel = null;
  }

  /// Generates idempotent-ish message IDs that follow the `m-<prefix>-<random>` pattern.
  String newMessageId(String prefix) {
    final rand = Random();
    final suffix = rand.nextInt(0xFFFFFF);
    return 'm-$prefix-${DateTime.now().millisecondsSinceEpoch}-$suffix';
  }
}
