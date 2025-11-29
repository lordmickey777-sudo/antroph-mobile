import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:logger/logger.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../core/env/env.dart';
import '../models/voice_ws_models.dart';

class VoiceSocketException implements Exception {
  VoiceSocketException(this.message);
  final String message;

  @override
  String toString() => 'VoiceSocketException: $message';
}

class VoiceWebSocketConnection {
  VoiceWebSocketConnection({
    required this.channel,
    required this.messages,
    required this.close,
  });

  final WebSocketChannel channel;
  final Stream<VoiceServerMessage> messages;
  final Future<void> Function() close;

  void sendBinary(List<int> data) => channel.sink.add(data);

  void sendJson(Map<String, dynamic> payload) => channel.sink.add(jsonEncode(payload));
}

class VoiceWebSocketService {
  VoiceWebSocketService._();
  static final VoiceWebSocketService instance = VoiceWebSocketService._();

  final _log = Logger();

  Future<VoiceWebSocketConnection> connect({
    required String token,
    required String deviceId,
    required String deviceType,
  }) async {
    final uri = _buildVoiceUri(token: token, deviceId: deviceId, deviceType: deviceType);
    _log.i('Connecting to voice websocket $uri');
    late final IOWebSocketChannel channel;
    try {
      channel = IOWebSocketChannel.connect(uri);
    } catch (e, st) {
      _log.e('Voice websocket connection failed', error: e, stackTrace: st);
      throw VoiceSocketException('Failed to open voice websocket: $e');
    }

    final controller = StreamController<VoiceServerMessage>.broadcast();
    final subscription = channel.stream.listen(
      (raw) => controller.add(VoiceServerMessage.fromSocketData(raw)),
      onError: (err, st) {
        _log.e('Voice websocket error', error: err, stackTrace: st);
        controller.add(
          VoiceServerMessage(
            type: VoiceMessageType.error,
            data: {'message': '$err'},
            raw: err,
          ),
        );
      },
      onDone: () => controller.close(),
    );

    return VoiceWebSocketConnection(
      channel: channel,
      messages: controller.stream,
      close: () async {
        await subscription.cancel();
        try {
          await channel.sink.close(WebSocketStatus.normalClosure, 'client_close');
        } catch (_) {}
        await controller.close();
      },
    );
  }

  Uri _buildVoiceUri({
    required String token,
    required String deviceId,
    required String deviceType,
  }) {
    final rawBase = AppEnv.apiBaseUrl.trim();
    if (rawBase.isEmpty) {
      throw VoiceSocketException('API_BASE_URL is missing; cannot derive voice websocket URL.');
    }
    Uri base;
    try {
      base = Uri.parse(rawBase);
    } catch (e) {
      throw VoiceSocketException('Invalid API_BASE_URL: $e');
    }
    final scheme = base.scheme == 'https' ? 'wss' : 'ws';
    final path = _joinPaths(base.path, '/ws/voice');
    final params = <String, String>{
      'token': token,
      'device_id': deviceId,
      'device_type': deviceType,
    };
    return base.replace(
      scheme: scheme,
      path: path,
      queryParameters: params,
    );
  }

  String _joinPaths(String first, String second) {
    final a = first.endsWith('/') ? first.substring(0, first.length - 1) : first;
    final b = second.startsWith('/') ? second : '/$second';
    return '$a$b';
  }
}
