import 'dart:async';
import 'dart:convert';

import 'package:logger/logger.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;

import '../models/chat_models.dart';

class ChatSocketConnection {
  ChatSocketConnection({
    required this.channel,
    required this.messages,
    required this.close,
  });

  final WebSocketChannel channel;
  final Stream<ChatEnvelope> messages;
  final Future<void> Function() close;

  void sendEnvelope(ChatEnvelope envelope) {
    channel.sink.add(jsonEncode(envelope.toJson()));
  }

  void sendRaw(Map<String, dynamic> raw) {
    channel.sink.add(jsonEncode(raw));
  }
}

class ChatWebSocketService {
  ChatWebSocketService._();
  static final ChatWebSocketService instance = ChatWebSocketService._();

  final Logger _log = Logger();

  Future<ChatSocketConnection> connect({
    required Uri uri,
    Map<String, dynamic>? headers,
  }) async {
    _log.i('Connecting to chat websocket $uri');
    late final WebSocketChannel channel;
    try {
      channel = IOWebSocketChannel.connect(uri, headers: headers);
    } catch (e, st) {
      _log.e('Chat websocket connect failed', error: e, stackTrace: st);
      rethrow;
    }

    final controller = StreamController<ChatEnvelope>.broadcast();
    final subscription = channel.stream.listen(
      (raw) {
        _log.t('Chat ws recv: $raw');
        controller.add(ChatEnvelope.fromSocketData(raw));
      },
      onError: (err, st) {
        _log.e('Chat websocket error', error: err, stackTrace: st);
        controller.add(ChatEnvelope(type: ChatEnvelopeType.error, raw: err));
      },
      onDone: () {
        _log.w(
          'Chat websocket closed (code: ${channel.closeCode}, reason: ${channel.closeReason})',
        );
        controller.close();
      },
    );

    return ChatSocketConnection(
      channel: channel,
      messages: controller.stream,
      close: () async {
        await subscription.cancel();
        try {
          await channel.sink.close(status.normalClosure, 'client_close');
        } catch (_) {}
        await controller.close();
      },
    );
  }
}
