import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

import '../../../core/auth/state/auth_state.dart';
import '../../../core/env/env.dart';
import '../models/chat_models.dart';
import '../services/chat_websocket_service.dart';

enum ChatConnectionStatus { connected, connecting, disconnected }

class ChatState {
  ChatState({
    this.connection = ChatConnectionStatus.connecting,
    this.retryIn,
    this.messages = const [],
    FacePose? face,
    this.error,
  }) : face = face ?? FacePose.neutral();

  final ChatConnectionStatus connection;
  final Duration? retryIn;
  final List<ChatMessageModel> messages;
  final FacePose face;
  final String? error;

  bool get isConnected => connection == ChatConnectionStatus.connected;
  bool get isConnecting => connection == ChatConnectionStatus.connecting;
  bool get isDisconnected => connection == ChatConnectionStatus.disconnected;

  ChatState copyWith({
    ChatConnectionStatus? connection,
    Object? retryIn = _keepRetry,
    List<ChatMessageModel>? messages,
    FacePose? face,
    Object? error = _keepError,
  }) {
    return ChatState(
      connection: connection ?? this.connection,
      retryIn: retryIn == _keepRetry ? this.retryIn : retryIn as Duration?,
      messages: messages ?? this.messages,
      face: face ?? this.face,
      error: error == _keepError ? this.error : error as String?,
    );
  }

  static const Object _keepError = Object();
  static const Object _keepRetry = Object();
}

class ChatController extends Notifier<ChatState> {
  final _service = ChatWebSocketService.instance;
  final _log = Logger();
  final _rand = Random();

  ChatSocketConnection? _connection;
  StreamSubscription<ChatEnvelope>? _subscription;
  Timer? _pingTimer;
  Timer? _retryTimer;
  Timer? _retryTicker;
  Timer? _faceThrottleTimer;
  Timer? _faceIdleTimer;
  int _retryAttempt = 0;
  FacePose? _pendingFace;
  DateTime? _lastFaceAt;

  static const _backoffSeconds = [1, 2, 4, 8, 16, 30];

  @override
  ChatState build() {
    ref.onDispose(_dispose);
    // Fire connect after build to avoid synchronous state churn.
    Timer.run(_connect);
    return ChatState(face: FacePose.neutral());
  }

  Future<void> _dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    await _connection?.close();
    _connection = null;
    _pingTimer?.cancel();
    _retryTimer?.cancel();
    _retryTicker?.cancel();
    _faceThrottleTimer?.cancel();
    _faceIdleTimer?.cancel();
  }

  Future<void> _connect() async {
    _retryTimer?.cancel();
    _retryTicker?.cancel();
    await _subscription?.cancel();
    _subscription = null;
    await _connection?.close();
    _connection = null;
    state = state.copyWith(
      connection: ChatConnectionStatus.connecting,
      retryIn: null,
      error: null,
    );

    final uri = _chatUri();
    if (uri == null) {
      state = state.copyWith(
        connection: ChatConnectionStatus.disconnected,
        error: 'CHAT_WS_URL/API_BASE_URL missing; cannot open chat socket.',
      );
      return;
    }

    try {
      _log.i('Opening chat socket to $uri');
      _connection = await _service.connect(uri: uri, headers: _headers());
      _subscription = _connection!.messages.listen(
        _handleEnvelope,
        onError: _handleError,
        onDone: _handleDone,
        cancelOnError: true,
      );
      _retryAttempt = 0;
      _startPing();
      state = state.copyWith(
        connection: ChatConnectionStatus.connected,
        retryIn: null,
        error: null,
      );
      // Kick off a ping to establish liveness early.
      _connection!.sendRaw({
        'type': 'ping',
        'ts': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e, st) {
      _log.e('Chat connect failed', error: e, stackTrace: st);
      _scheduleReconnect(e);
    }
  }

  Map<String, dynamic>? _headers() {
    final tokens = ref.read(authControllerProvider.notifier).tokens;
    if (tokens == null || tokens.accessToken.isEmpty) return null;
    final type = tokens.tokenType.isNotEmpty ? tokens.tokenType : 'Bearer';
    return {'Authorization': '$type ${tokens.accessToken}'};
  }

  Uri? _chatUri() {
    final url = AppEnv.chatWsUrl;
    if (url.isEmpty) return null;
    Uri? parsed;
    try {
      parsed = Uri.parse(url);
    } catch (_) {
      return null;
    }
    if (parsed.scheme == 'https') {
      parsed = parsed.replace(scheme: 'wss');
      _log.w('CHAT_WS_URL uses https; normalized to $parsed');
    } else if (parsed.scheme == 'http') {
      parsed = parsed.replace(scheme: 'ws');
      _log.w('CHAT_WS_URL uses http; normalized to $parsed');
    }
    if (parsed.port == 0) {
      parsed = parsed.replace(port: null);
      _log.w('CHAT_WS_URL port was 0; falling back to default port -> $parsed');
    }
    if (parsed.hasFragment) {
      parsed = parsed.replace(fragment: '');
    }
    return parsed;
  }

  void _startPing() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      final ts = DateTime.now().millisecondsSinceEpoch;
      _log.t('Sending ping $ts');
      _connection?.sendRaw({'type': 'ping', 'ts': ts});
    });
  }

  void _handleEnvelope(ChatEnvelope envelope) {
    _log.t(
      'Chat envelope ${envelope.type} id=${envelope.id} ts=${envelope.ts}',
    );
    switch (envelope.type) {
      case ChatEnvelopeType.chat:
        _handleIncomingChat(envelope);
        break;
      case ChatEnvelopeType.face:
        _handleFace(envelope);
        break;
      case ChatEnvelopeType.error:
        _handleSocketError(envelope);
        break;
      case ChatEnvelopeType.ping:
        _connection?.sendRaw({
          'type': 'pong',
          'ts': DateTime.now().millisecondsSinceEpoch,
        });
        break;
      case ChatEnvelopeType.ack:
        if (envelope.id != null) {
          _markMessageSent(envelope.id!);
        }
        break;
      case ChatEnvelopeType.pong:
      case ChatEnvelopeType.presence:
      case ChatEnvelopeType.unknown:
        break;
    }
  }

  void _handleIncomingChat(ChatEnvelope envelope) {
    final data = envelope.data ?? const <String, dynamic>{};
    final text = data['message']?.toString() ?? '';
    if (text.isEmpty) return;
    final role = chatRoleFromString(data['role']?.toString() ?? 'assistant');
    final ts = envelope.ts ?? DateTime.now();
    final id = envelope.id ?? _newId('srv');
    final incoming = ChatMessageModel(
      id: id,
      role: role,
      message: text,
      ts: ts,
      delivery: ChatDeliveryState.sent,
    );
    final index = state.messages.indexWhere((m) => m.id == id);
    List<ChatMessageModel> next = List.of(state.messages);
    if (index != -1) {
      next[index] = next[index].copyWith(
        message: text,
        ts: ts,
        role: role,
        delivery: ChatDeliveryState.sent,
      );
    } else {
      next = [...next, incoming];
    }
    state = state.copyWith(messages: next);
  }

  void _handleFace(ChatEnvelope envelope) {
    final pose = FacePose.fromJson(
      envelope.data ?? const <String, dynamic>{},
      ts: envelope.ts,
    );
    _pendingFace = pose;
    _flushFaceFrame();
  }

  void _flushFaceFrame() {
    if (_faceThrottleTimer != null) return;
    _faceThrottleTimer = Timer(const Duration(milliseconds: 16), () {
      _faceThrottleTimer?.cancel();
      _faceThrottleTimer = null;
      final pose = _pendingFace;
      _pendingFace = null;
      if (pose != null) {
        _applyFace(pose);
      }
    });
  }

  void _applyFace(FacePose pose) {
    _lastFaceAt = DateTime.now();
    state = state.copyWith(face: pose);
    _log.t(
      'Face update eyes=(${pose.eyes.x.toStringAsFixed(2)}, ${pose.eyes.y.toStringAsFixed(2)}) '
      'blink=${pose.eyes.blink.toStringAsFixed(2)} '
      'mouth=open ${pose.mouth.open.toStringAsFixed(2)} smile ${pose.mouth.smile.toStringAsFixed(2)} '
      'talking=${pose.mouth.talking}',
    );
    _faceIdleTimer?.cancel();
    _faceIdleTimer = Timer(const Duration(milliseconds: 650), () {
      if (_lastFaceAt == null) return;
      final elapsed = DateTime.now().difference(_lastFaceAt!);
      if (elapsed >= const Duration(milliseconds: 500)) {
        state = state.copyWith(
          face: FacePose.neutral(updatedAt: DateTime.now()),
        );
      }
    });
  }

  void _handleSocketError(ChatEnvelope envelope) {
    final message =
        envelope.data?['message']?.toString() ??
        envelope.data?['code']?.toString() ??
        'Chat socket error';
    _log.w('Chat socket error envelope: $message');
    state = state.copyWith(error: message);
  }

  void _handleError(Object err, [StackTrace? st]) {
    _log.e('Chat socket error', error: err, stackTrace: st);
    state = state.copyWith(error: '$err');
    _scheduleReconnect(err);
  }

  void _handleDone() {
    _log.w('Chat socket stream done');
    _scheduleReconnect('socket_closed');
  }

  void _scheduleReconnect(Object? reason) {
    _pingTimer?.cancel();
    _retryTimer?.cancel();
    _retryTicker?.cancel();
    final idx = _retryAttempt.clamp(0, _backoffSeconds.length - 1);
    final delay = Duration(seconds: _backoffSeconds[idx]);
    _retryAttempt = (_retryAttempt + 1).clamp(0, _backoffSeconds.length - 1);

    final retryAt = DateTime.now().add(delay);
    state = state.copyWith(
      connection: ChatConnectionStatus.disconnected,
      retryIn: delay,
      error: reason?.toString(),
    );
    _log.w('Scheduling reconnect in ${delay.inSeconds}s (reason: $reason)');

    _retryTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      final remaining = retryAt.difference(DateTime.now());
      if (remaining.isNegative) return;
      state = state.copyWith(retryIn: remaining);
    });

    _retryTimer = Timer(delay, () {
      _retryTicker?.cancel();
      _retryTimer = null;
      _connect();
    });
  }

  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    if (_connection == null) {
      state = state.copyWith(error: 'Not connected');
      return;
    }
    final id = _newId('user');
    final ts = DateTime.now();
    final msg = ChatMessageModel(
      id: id,
      role: ChatRole.user,
      message: trimmed,
      ts: ts,
      delivery: ChatDeliveryState.sending,
    );
    state = state.copyWith(messages: [...state.messages, msg], error: null);
    try {
      _log.t('Sending chat message $id');
      _connection!.sendRaw({
        'type': 'chat',
        'id': id,
        'ts': ts.millisecondsSinceEpoch,
        'data': {'role': 'user', 'message': trimmed},
      });
    } catch (e, st) {
      _log.e('Send chat failed', error: e, stackTrace: st);
      _markFailed(id, '$e');
    }
  }

  void retrySend(String messageId) {
    final existing = state.messages.firstWhere(
      (m) => m.id == messageId,
      orElse: () => ChatMessageModel(
        id: '',
        role: ChatRole.user,
        message: '',
        ts: DateTime.now(),
      ),
    );
    if (existing.id.isEmpty) return;
    _sendRetry(existing);
  }

  void _sendRetry(ChatMessageModel msg) {
    if (_connection == null) {
      state = state.copyWith(error: 'Not connected');
      return;
    }
    final updated = msg.copyWith(delivery: ChatDeliveryState.sending);
    final nextMessages = state.messages
        .map((m) => m.id == msg.id ? updated : m)
        .toList();
    state = state.copyWith(messages: nextMessages, error: null);
    try {
      _log.t('Retry sending message ${msg.id}');
      _connection!.sendRaw({
        'type': 'chat',
        'id': msg.id,
        'ts': DateTime.now().millisecondsSinceEpoch,
        'data': {'role': 'user', 'message': msg.message},
      });
    } catch (e, st) {
      _log.e('Retry send failed', error: e, stackTrace: st);
      _markFailed(msg.id, '$e');
    }
  }

  void _markMessageSent(String id) {
    final index = state.messages.indexWhere((m) => m.id == id);
    if (index == -1) return;
    final updated = state.messages[index].copyWith(
      delivery: ChatDeliveryState.sent,
    );
    final next = List<ChatMessageModel>.from(state.messages)..[index] = updated;
    state = state.copyWith(messages: next);
  }

  void _markFailed(String id, String reason) {
    final index = state.messages.indexWhere((m) => m.id == id);
    if (index == -1) return;
    final updated = state.messages[index].copyWith(
      delivery: ChatDeliveryState.failed,
    );
    final next = List<ChatMessageModel>.from(state.messages)..[index] = updated;
    state = state.copyWith(messages: next, error: reason);
  }

  void forceReconnect() {
    _retryTimer?.cancel();
    _retryTicker?.cancel();
    _connect();
  }

  void clearError() {
    state = state.copyWith(error: null);
  }

  void pause() {
    _pingTimer?.cancel();
    _retryTimer?.cancel();
    _retryTicker?.cancel();
    _faceThrottleTimer?.cancel();
    _faceIdleTimer?.cancel();
    _subscription?.cancel();
    _subscription = null;
    _connection?.close();
    _connection = null;
    state = state.copyWith(connection: ChatConnectionStatus.disconnected);
  }

  void resume() {
    if (state.isConnected || state.isConnecting) return;
    _connect();
  }

  String _newId(String prefix) {
    final nonce = _rand.nextInt(0xFFFFFF).toRadixString(16);
    return 'm-$prefix-${DateTime.now().millisecondsSinceEpoch}-$nonce';
  }
}

final chatControllerProvider =
    NotifierProvider.autoDispose<ChatController, ChatState>(ChatController.new);
