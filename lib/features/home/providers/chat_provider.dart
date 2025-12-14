import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/status.dart' as ws_status;

import '../../../core/auth/state/auth_state.dart';
import '../../../core/env/env.dart';
import '../models/chat_models.dart';
import '../models/face_state.dart';

enum ChatConnectionStatus { connected, connecting, disconnected }

class ChatState {
  ChatState({
    this.connection = ChatConnectionStatus.connecting,
    this.retryIn,
    this.messages = const [],
    FaceState? face,
    this.error,
  }) : face = face ?? FaceState.neutral();

  final ChatConnectionStatus connection;
  final Duration? retryIn;
  final List<ChatMessageModel> messages;
  final FaceState face;
  final String? error;

  bool get isConnected => connection == ChatConnectionStatus.connected;
  bool get isConnecting => connection == ChatConnectionStatus.connecting;
  bool get isDisconnected => connection == ChatConnectionStatus.disconnected;

  ChatState copyWith({
    ChatConnectionStatus? connection,
    Object? retryIn = _keepRetry,
    List<ChatMessageModel>? messages,
    FaceState? face,
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
  final _log = Logger();
  final _rand = Random();

  IOWebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _retryTimer;
  Timer? _retryTicker;
  Timer? _faceThrottleTimer;
  Timer? _faceIdleTimer;
  int _retryAttempt = 0;
  FaceState? _pendingFace;
  DateTime? _lastFaceAt;
  final Map<String, ChatMessageModel> _streamingReplies = {};
  String? _deviceId;

  static const _backoffSeconds = [1, 2, 4, 8, 16, 30];
  static const _deviceIdPrefsKey = 'voice_chat_device_id';

  @override
  ChatState build() {
    ref.onDispose(_dispose);
    // Fire connect after build to avoid synchronous state churn.
    Timer.run(_connect);
    return ChatState(face: FaceState.neutral());
  }

  Future<void> _dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    try {
      await _channel?.sink.close(ws_status.normalClosure, 'dispose');
    } catch (_) {}
    _channel = null;
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
    try {
      await _channel?.sink.close(ws_status.normalClosure, 'reconnect');
    } catch (_) {}
    _channel = null;
    state = state.copyWith(
      connection: ChatConnectionStatus.connecting,
      retryIn: null,
      error: null,
    );

    final uri = await _chatUri();
    if (uri == null) {
      state = state.copyWith(
        connection: ChatConnectionStatus.disconnected,
        error: 'CHAT_WS_URL/API_BASE_URL missing; cannot open chat socket.',
      );
      return;
    }

    try {
      _log.i('Opening chat socket to $uri');
      _channel = IOWebSocketChannel.connect(uri, headers: _headers());
      _subscription = _channel!.stream.listen(
        _handleRaw,
        onError: _handleError,
        onDone: _handleDone,
        cancelOnError: true,
      );
      _channel?.innerWebSocket?.pingInterval = const Duration(seconds: 25);
      _retryAttempt = 0;
      state = state.copyWith(
        connection: ChatConnectionStatus.connected,
        retryIn: null,
        error: null,
      );
    } catch (e, st) {
      _log.e('Chat connect failed', error: e, stackTrace: st);
      _scheduleReconnect(e);
    }
  }

  Map<String, dynamic>? _headers() => null;

  Future<Uri?> _chatUri() async {
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
    final token = ref.read(authControllerProvider.notifier).tokens?.accessToken;
    final deviceId = await _ensureDeviceId();
    final deviceType = Platform.isIOS
        ? 'ios'
        : Platform.isAndroid
        ? 'android'
        : 'mobile';
    final qp = Map<String, String>.from(parsed.queryParameters);
    if (token != null && token.isNotEmpty) {
      qp['token'] = token;
    }
    qp.putIfAbsent('device_id', () => deviceId);
    qp.putIfAbsent('device_type', () => deviceType);
    parsed = parsed.replace(queryParameters: qp);
    return parsed;
  }

  void _handleRaw(dynamic raw) {
    final envelope = ChatEnvelope.fromSocketData(raw);
    _handleEnvelope(envelope);
  }

  void _handleEnvelope(ChatEnvelope envelope) {
    _log.t(
      'Chat envelope ${envelope.type} id=${envelope.id} ts=${envelope.ts}',
    );
    switch (envelope.type) {
      case ChatEnvelopeType.connected:
        break;
      case ChatEnvelopeType.chat:
        _handleIncomingChat(envelope);
        break;
      case ChatEnvelopeType.chatChunk:
        _handleChatChunk(envelope);
        break;
      case ChatEnvelopeType.chatDone:
        _handleChatDone(envelope);
        break;
      case ChatEnvelopeType.chatResponse:
        _handleChatResponse(envelope);
        break;
      case ChatEnvelopeType.face:
        _handleFace(envelope);
        break;
      case ChatEnvelopeType.error:
        _handleSocketError(envelope);
        break;
      case ChatEnvelopeType.ping:
        _sendRaw({'type': 'pong', 'ts': DateTime.now().millisecondsSinceEpoch});
        break;
      case ChatEnvelopeType.ack:
        if (envelope.id != null) {
          _markMessageSent(envelope.id!);
        }
        break;
      case ChatEnvelopeType.pong:
      case ChatEnvelopeType.presence:
        break;
      case ChatEnvelopeType.unknown:
        _handleUnknownEnvelope(envelope);
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

  void _handleChatChunk(ChatEnvelope envelope) {
    final data = envelope.data ?? const <String, dynamic>{};
    final chunk = data['content']?.toString() ?? '';
    if (chunk.isEmpty) return;
    final req = envelope.requestId ?? '';
    _upsertAssistantStream(
      req.isNotEmpty ? req : envelope.id ?? 'srv-stream',
      chunk,
      streaming: true,
    );
  }

  void _handleChatDone(ChatEnvelope envelope) {
    final req = envelope.requestId ?? envelope.id ?? '';
    if (req.isEmpty) return;
    _finalizeAssistantStream(req);
  }

  void _handleChatResponse(ChatEnvelope envelope) {
    final data = envelope.data ?? const <String, dynamic>{};
    final text =
        data['message']?.toString() ?? data['content']?.toString() ?? '';
    if (text.isEmpty) return;
    final req = envelope.requestId ?? envelope.id ?? _newId('asst');
    _upsertAssistantStream(req, text, streaming: false, replace: true);
  }

  void _handleFace(ChatEnvelope envelope) {
    final payload = envelope.data ?? _coerceRawData(envelope.raw);
    final face = FaceState.maybeFromDynamic(payload);
    if (face == null) return;
    _pendingFace = face;
    _flushFaceFrame();
  }

  dynamic _coerceRawData(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw['data'] ?? raw;
    if (raw is Map) return raw['data'] ?? raw;
    return raw;
  }

  void _flushFaceFrame() {
    if (_faceThrottleTimer != null) return;
    _faceThrottleTimer = Timer(const Duration(milliseconds: 16), () {
      _faceThrottleTimer?.cancel();
      _faceThrottleTimer = null;
      final face = _pendingFace;
      _pendingFace = null;
      if (face != null) _applyFace(face);
    });
  }

  void _applyFace(FaceState face) {
    _lastFaceAt = DateTime.now();
    state = state.copyWith(face: face);
    _log.t('Face update dna=${face.toArray().join(",")}');
    _faceIdleTimer?.cancel();
    _faceIdleTimer = Timer(const Duration(milliseconds: 650), () {
      if (_lastFaceAt == null) return;
      final elapsed = DateTime.now().difference(_lastFaceAt!);
      if (elapsed >= const Duration(milliseconds: 500)) {
        state = state.copyWith(face: FaceState.neutral());
      }
    });
  }

  void _handleSocketError(ChatEnvelope envelope) {
    final message = _errorMessageFromEnvelope(
          envelope,
          includeRawFallback: true,
        ) ??
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

  void _sendRaw(Map<String, dynamic> payload) {
    try {
      if (_channel == null) {
        _log.w('Attempted to send on null channel');
        return;
      }
      _channel!.sink.add(jsonEncode(payload));
    } catch (e, st) {
      _log.e('Send raw failed', error: e, stackTrace: st);
    }
  }

  void _scheduleReconnect(Object? reason) {
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
    if (_channel == null) {
      state = state.copyWith(error: 'Not connected');
      return;
    }
    final id = _newId('user');
    final requestId = id;
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
      _sendRaw({
        'type': 'chat',
        'request_id': requestId,
        'data': {
          'message': trimmed,
          'conversation_type': 'general',
          'stream': true,
        },
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
    if (_channel == null) {
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
      _sendRaw({
        'type': 'chat',
        'request_id': msg.id,
        'data': {
          'message': msg.message,
          'conversation_type': 'general',
          'stream': true,
        },
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
    _retryTimer?.cancel();
    _retryTicker?.cancel();
    _faceThrottleTimer?.cancel();
    _faceIdleTimer?.cancel();
    _subscription?.cancel();
    _subscription = null;
    _channel?.sink.close(ws_status.normalClosure, 'pause');
    _channel = null;
    state = state.copyWith(connection: ChatConnectionStatus.disconnected);
  }

  void resume() {
    if (state.isConnected || state.isConnecting) return;
    _connect();
  }

  Future<String> _ensureDeviceId() async {
    if (_deviceId != null && _deviceId!.isNotEmpty) return _deviceId!;
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_deviceIdPrefsKey);
    if (existing != null && existing.isNotEmpty) {
      _deviceId = existing;
      return existing;
    }
    final generated =
        '${Platform.isIOS
            ? "ios"
            : Platform.isAndroid
            ? "android"
            : "mobile"}-${DateTime.now().millisecondsSinceEpoch}-${DateTime.now().microsecondsSinceEpoch.remainder(100000)}';
    _deviceId = generated;
    await prefs.setString(_deviceIdPrefsKey, generated);
    return generated;
  }

  String _newId(String prefix) {
    final nonce = _rand.nextInt(0xFFFFFF).toRadixString(16);
    return 'm-$prefix-${DateTime.now().millisecondsSinceEpoch}-$nonce';
  }

  void _upsertAssistantStream(
    String requestId,
    String chunk, {
    bool streaming = true,
    bool replace = false,
  }) {
    if (requestId.isEmpty) return;
    final existing =
        _streamingReplies[requestId] ??
        ChatMessageModel(
          id: 'asst-$requestId',
          role: ChatRole.assistant,
          message: '',
          ts: DateTime.now(),
          streaming: true,
        );
    final merged = existing.copyWith(
      message: replace ? chunk : '${existing.message}$chunk',
      ts: DateTime.now(),
      streaming: streaming,
      delivery: ChatDeliveryState.sent,
    );
    _streamingReplies[requestId] = merged;
    final updatedList = List<ChatMessageModel>.from(state.messages);
    final idx = updatedList.indexWhere((m) => m.id == merged.id);
    if (idx >= 0) {
      updatedList[idx] = merged;
    } else {
      updatedList.add(merged);
    }
    state = state.copyWith(messages: updatedList);
  }

  void _finalizeAssistantStream(String requestId) {
    final existing = _streamingReplies.remove(requestId);
    if (existing == null) return;
    final merged = existing.copyWith(streaming: false);
    final updatedList = List<ChatMessageModel>.from(state.messages);
    final idx = updatedList.indexWhere((m) => m.id == merged.id);
    if (idx >= 0) {
      updatedList[idx] = merged;
      state = state.copyWith(messages: updatedList);
    }
  }

  void _handleUnknownEnvelope(ChatEnvelope envelope) {
    final message = _errorMessageFromEnvelope(envelope);
    if (message != null && message.isNotEmpty) {
      _log.w('Unknown chat envelope treated as error: $message');
      state = state.copyWith(error: message);
      return;
    }
    _log.w('Unknown chat envelope: ${envelope.raw}');
  }

  String? _errorMessageFromEnvelope(
    ChatEnvelope envelope, {
    bool includeRawFallback = false,
  }) {
    final fromData = _firstString([
      envelope.data?['message'],
      envelope.data?['detail'],
      envelope.data?['error'],
      envelope.data?['code'],
    ]);
    if (fromData != null) return fromData;

    final raw = envelope.raw;
    if (raw is Map) {
      final rawMessage = _firstString([
        raw['message'],
        raw['detail'],
        raw['error'],
        raw['code'],
      ]);
      if (rawMessage != null) return rawMessage;
    }

    if (includeRawFallback && raw != null) {
      final rawString = raw.toString();
      if (rawString.isNotEmpty) return rawString;
    }
    return null;
  }

  String? _firstString(Iterable<dynamic> values) {
    for (final value in values) {
      if (value == null) continue;
      final text = value.toString();
      if (text.isNotEmpty) return text;
    }
    return null;
  }
}

final chatControllerProvider =
    NotifierProvider.autoDispose<ChatController, ChatState>(ChatController.new);
