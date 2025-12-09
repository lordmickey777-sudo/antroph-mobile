import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:logger/logger.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/auth/state/auth_state.dart';
import '../models/expression_models.dart';
import '../models/voice_ws_models.dart';
import '../services/voice_chat_service.dart';
import '../services/voice_stream_player.dart';
import '../services/voice_websocket_service.dart';

/// State for voice chat interaction
enum PermissionDialogType { none, education, settings }

class VoiceChatState {
  final RobotExpression currentExpression;
  final bool isRecording;
  final bool isPlaying;
  final bool isConnecting;
  final bool isProcessing;
  final String? userTranscription;
  final String? aiResponse;
  final String? errorMessage;
  final double playbackProgress;
  final PermissionDialogType permissionDialog;
  final List<String> audioFormats;
  final Uint8List? currentFaceBitmap;
  final int? faceTimestampMs;

  const VoiceChatState({
    this.currentExpression = RobotExpression.neutral,
    this.isRecording = false,
    this.isPlaying = false,
    this.isConnecting = false,
    this.isProcessing = false,
    this.userTranscription,
    this.aiResponse,
    this.errorMessage,
    this.playbackProgress = 0.0,
    this.permissionDialog = PermissionDialogType.none,
    this.audioFormats = const [],
    this.currentFaceBitmap,
    this.faceTimestampMs,
  });

  VoiceChatState copyWith({
    RobotExpression? currentExpression,
    bool? isRecording,
    bool? isPlaying,
    bool? isConnecting,
    bool? isProcessing,
    String? userTranscription,
    String? aiResponse,
    String? errorMessage,
    double? playbackProgress,
    PermissionDialogType? permissionDialog,
    List<String>? audioFormats,
    Uint8List? currentFaceBitmap,
    int? faceTimestampMs,
    bool clearFace = false,
  }) {
    return VoiceChatState(
      currentExpression: currentExpression ?? this.currentExpression,
      isRecording: isRecording ?? this.isRecording,
      isPlaying: isPlaying ?? this.isPlaying,
      isConnecting: isConnecting ?? this.isConnecting,
      isProcessing: isProcessing ?? this.isProcessing,
      userTranscription: userTranscription ?? this.userTranscription,
      aiResponse: aiResponse ?? this.aiResponse,
      errorMessage: errorMessage,
      playbackProgress: playbackProgress ?? this.playbackProgress,
      permissionDialog: permissionDialog ?? this.permissionDialog,
      audioFormats: audioFormats ?? this.audioFormats,
      currentFaceBitmap: clearFace ? null : (currentFaceBitmap ?? this.currentFaceBitmap),
      faceTimestampMs: clearFace ? null : (faceTimestampMs ?? this.faceTimestampMs),
    );
  }

  bool get isBusy => isRecording || isProcessing || isPlaying || isConnecting;
}

/// Controller for voice chat interactions
class VoiceChatController extends Notifier<VoiceChatState> {
  final VoiceWebSocketService _wsService = VoiceWebSocketService.instance;
  final VoiceStreamPlayer _streamPlayer = VoiceStreamPlayer();
  FlutterSoundRecorder? _audioRecorder;
  VoiceWebSocketConnection? _wsConnection;
  StreamSubscription<VoiceServerMessage>? _wsSubscription;
  final Logger _log = Logger();
  final Map<String, Uint8List> _faceCache = {};
  bool _iosPermissionDeniedOnce = false;
  Completer<bool>? _permissionDialogCompleter;
  String? _currentSequenceId;
  String _preferredContentType = 'audio/mpeg';
  Codec _activeCodec = Codec.opusOGG;
  String _activeEncoding = _preferredEncoding;
  StreamController<Uint8List>? _micStreamController;
  StreamSubscription<Uint8List>? _micStreamSubscription;
  DateTime? _recordingStartedAt;
  String? _recordingFilePath;
  int _chunkCount = 0;
  String? _currentRequestId;
  static const int _sampleRate = 16000;
  static const String _preferredEncoding = 'opus';
  static const String _permissionError = 'Microphone permission is required for voice chat';
  static const String _deviceIdPrefsKey = 'voice_chat_device_id';

  @override
  VoiceChatState build() {
    // Initialize recorder
    _audioRecorder = FlutterSoundRecorder();

    // Clean up on disposal
    ref.onDispose(() async {
      await _disposeSocket();
      await _streamPlayer.stop();
      await _cleanupRecordingFile();
      await _audioRecorder?.closeRecorder();
    });
    return const VoiceChatState();
  }

  /// Start recording user voice
  Future<void> startRecording() async {
    try {
      if (state.isBusy) {
        _log.w('Cannot start recording: already busy');
        return;
      }

      final hasPermission = await _ensureMicrophonePermission();
      if (!hasPermission) {
        _log.w('Microphone permission not granted. Recording aborted.');
        return;
      }

      // Initialize recorder if needed
      if (_audioRecorder == null) {
        _audioRecorder = FlutterSoundRecorder();
      }

      if (!_audioRecorder!.isRecording) {
        await _audioRecorder!.openRecorder();
      }

      final supportsOpus = await _audioRecorder!.isEncoderSupported(Codec.opusOGG).catchError((
        e,
        st,
      ) {
        _log.w('Opus encoder support check failed: $e', error: e, stackTrace: st);
        return false;
      });
      if (supportsOpus) {
        _activeCodec = Codec.opusOGG;
        _activeEncoding = _preferredEncoding;
      } else {
        _activeCodec = Codec.pcm16WAV;
        _activeEncoding = 'wav';
        _log.w('Opus not supported on this device. Falling back to WAV container.');
      }
      _log.i('Voice recorder using codec=$_activeCodec encoding=$_activeEncoding');

      await _streamPlayer.stop();
      await _disposeSocket();

      final token = ref.read(authControllerProvider.notifier).tokens?.accessToken ?? '';
      if (token.isEmpty) {
        throw VoiceChatException('You must be logged in to use voice chat');
      }

      state = state.copyWith(
        isConnecting: true,
        isProcessing: false,
        isPlaying: false,
        aiResponse: null,
        userTranscription: null,
        errorMessage: null,
        clearFace: true,
      );

      final deviceId = await _ensureDeviceId();
      final deviceType = Platform.isIOS ? 'ios' : 'android';
      _wsConnection = await _wsService.connect(
        token: token,
        deviceId: deviceId,
        deviceType: deviceType,
      );
      _wsSubscription = _wsConnection!.messages.listen(
        _handleServerMessage,
        onError: (err, st) => _handleSocketError(err, st),
        onDone: _handleSocketDone,
      );

      // Set content type based on actual encoding being used
      _preferredContentType = _getContentTypeForEncoding(_activeEncoding);
      _currentRequestId = 'voice-${DateTime.now().millisecondsSinceEpoch}';
      _chunkCount = 0;

      _sendVoiceStart();
      await _startStreamingRecorder();
      _log.i('Voice session started (request=$_currentRequestId)');
    } catch (e, stackTrace) {
      _log.e('Failed to start recording', error: e, stackTrace: stackTrace);
      state = state.copyWith(isRecording: false, errorMessage: 'Failed to start recording: $e');
    }
  }

  Future<void> _startStreamingRecorder() async {
    try {
      if (_wsConnection == null) {
        throw VoiceChatException('Voice connection not ready');
      }
      await _micStreamSubscription?.cancel();
      await _micStreamController?.close();
      _micStreamController = StreamController<Uint8List>();
      _micStreamSubscription = _micStreamController!.stream.listen((bytes) {
        if (bytes.isEmpty) return;
        _chunkCount++;
        try {
          _wsConnection?.sendBinary(bytes);
        } catch (e, st) {
          _handleSocketError(e, st is StackTrace ? st : StackTrace.current);
        }
      }, onError: (err, st) => _handleSocketError(err, st));

      _recordingStartedAt = DateTime.now();
      final bitRate = (_activeCodec == Codec.pcm16 || _activeCodec == Codec.pcm16WAV)
          ? _sampleRate * 16
          : 16000;
      _recordingFilePath = await _prepareRecordingFilePath();
      await _audioRecorder!.startRecorder(
        toStream: _micStreamController!.sink,
        toFile: _recordingFilePath,
        codec: _activeCodec,
        numChannels: 1,
        sampleRate: _sampleRate,
        bitRate: bitRate,
      );

      state = state.copyWith(
        isRecording: true,
        isConnecting: false,
        isProcessing: false,
        isPlaying: false,
        errorMessage: null,
      );
    } catch (e, st) {
      _log.e('Failed to start streaming recorder', error: e, stackTrace: st);
      await _cleanupRecordingFile();
      state = state.copyWith(
        isRecording: false,
        isProcessing: false,
        isConnecting: false,
        isPlaying: false,
        clearFace: true,
        errorMessage: 'Failed to start recording: $e',
      );
      await _disposeSocket();
    }
  }

  Future<String> _prepareRecordingFilePath() async {
    final tempDir = await getTemporaryDirectory();
    final extension = _fileExtensionForCodec(_activeCodec);
    final fileName = 'voice-${DateTime.now().millisecondsSinceEpoch}.$extension';
    return p.join(tempDir.path, fileName);
  }

  String _fileExtensionForCodec(Codec codec) {
    switch (codec) {
      case Codec.opusOGG:
        return 'opus';
      case Codec.pcm16WAV:
      case Codec.pcmFloat32WAV:
        return 'wav';
      case Codec.pcm16:
        return 'pcm';
      default:
        return 'aac';
    }
  }

  Future<void> _cleanupRecordingFile() async {
    final path = _recordingFilePath;
    _recordingFilePath = null;
    if (path == null || path.isEmpty) return;
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e, st) {
      _log.w('Failed to delete temp recording file: $e', error: e, stackTrace: st);
    }
  }

  Future<bool> _ensureMicrophonePermission() async {
    var status = await Permission.microphone.status;
    _log.i('Current microphone permission status: $status');

    if (_isMicrophonePermissionUsable(status)) {
      _handleMicrophonePermissionGranted();
      return true;
    }

    if (_shouldOpenMicrophoneSettings(status)) {
      await _showSettingsDialog();
      _setPermissionError();
      return false;
    }

    if (status.isDenied) {
      final proceed = await _showEducationDialogAndWait();
      if (!proceed) {
        _setPermissionError();
        return false;
      }
    }

    status = await Permission.microphone.request();
    _log.i('Microphone permission request result: $status');

    if (_isMicrophonePermissionUsable(status)) {
      _handleMicrophonePermissionGranted();
      return true;
    }

    if (_isIOS && status.isDenied) {
      _iosPermissionDeniedOnce = true;
    }

    await _showSettingsDialog();
    _setPermissionError();
    return false;
  }

  Future<bool> _showEducationDialogAndWait() async {
    if (_permissionDialogCompleter != null && !_permissionDialogCompleter!.isCompleted) {
      return _permissionDialogCompleter!.future;
    }
    final completer = Completer<bool>();
    _permissionDialogCompleter = completer;
    state = state.copyWith(permissionDialog: PermissionDialogType.education);
    return completer.future;
  }

  Future<void> _showSettingsDialog() async {
    _permissionDialogCompleter?.complete(false);
    _permissionDialogCompleter = null;
    state = state.copyWith(permissionDialog: PermissionDialogType.settings);
  }

  bool _shouldOpenMicrophoneSettings(PermissionStatus status) {
    if (status.isPermanentlyDenied || status.isRestricted) {
      return true;
    }
    if (_isIOS && _iosPermissionDeniedOnce && status.isDenied) {
      return true;
    }
    return false;
  }

  bool _isMicrophonePermissionUsable(PermissionStatus status) {
    return status.isGranted || status.isLimited;
  }

  bool get _isIOS => Platform.isIOS;

  void _handleMicrophonePermissionGranted() {
    _resetPermissionDialogState();
    _iosPermissionDeniedOnce = false;
    state = state.copyWith(errorMessage: null);
  }

  void handleEducationDialogResult(bool accepted) {
    if (_permissionDialogCompleter != null && !_permissionDialogCompleter!.isCompleted) {
      _permissionDialogCompleter!.complete(accepted);
    }
    _permissionDialogCompleter = null;
    _resetPermissionDialogState();
  }

  void dismissPermissionDialog() {
    if (_permissionDialogCompleter != null && !_permissionDialogCompleter!.isCompleted) {
      _permissionDialogCompleter!.complete(false);
    }
    _permissionDialogCompleter = null;
    _resetPermissionDialogState();
  }

  void _resetPermissionDialogState() {
    state = state.copyWith(permissionDialog: PermissionDialogType.none);
  }

  void _setPermissionError() {
    state = state.copyWith(errorMessage: _permissionError);
  }

  void _sendVoiceStart() {
    if (_wsConnection == null) return;
    final reqId = _currentRequestId ?? 'voice-${DateTime.now().millisecondsSinceEpoch}';
    _currentRequestId = reqId;
    _wsConnection!.sendJson({
      'type': 'voice_start',
      'data': {
        'conversation_type': 'general',
        'language': 'en',
        'sample_rate': _sampleRate,
        'encoding': _activeEncoding,
      },
      'request_id': reqId,
    });
  }

  void _sendVoiceEnd({required int totalChunks, required int durationMs}) {
    if (_wsConnection == null || _currentRequestId == null) return;
    _wsConnection!.sendJson({
      'type': 'voice_end',
      'data': {'total_chunks': totalChunks, 'total_duration_ms': durationMs},
      'request_id': _currentRequestId,
    });
  }

  /// Stop recording and send to backend
  Future<void> stopRecordingAndSend() async {
    try {
      if (!state.isRecording) {
        _log.w('Cannot stop recording: not recording');
        return;
      }

      final durationMs = _recordingStartedAt != null
          ? DateTime.now().difference(_recordingStartedAt!).inMilliseconds
          : 0;

      await _audioRecorder?.stopRecorder();
      await _micStreamSubscription?.cancel();
      await _micStreamController?.close();
      _recordingStartedAt = null;

      await _sendBufferedRecordingIfNeeded();
      state = state.copyWith(
        isRecording: false,
        isProcessing: true,
        isPlaying: false,
        isConnecting: false,
        errorMessage: null,
      );

      _sendVoiceEnd(totalChunks: _chunkCount, durationMs: durationMs);
      _log.i('Voice stream ended. chunks=$_chunkCount duration=${durationMs}ms');
      await _cleanupRecordingFile();
      _chunkCount = 0;
    } catch (e, stackTrace) {
      _log.e('Failed to process voice message', error: e, stackTrace: stackTrace);
      state = state.copyWith(
        isRecording: false,
        isProcessing: false,
        isConnecting: false,
        isPlaying: false,
        clearFace: true,
        errorMessage: e is VoiceChatException ? e.message : 'Failed to process voice: $e',
      );
    }
  }

  /// iOS flutter_sound currently does not forward live audio chunks to Dart.
  /// If we didn't stream any bytes, fall back to reading the recorded file and
  /// push it through the websocket before we send voice_end.
  Future<void> _sendBufferedRecordingIfNeeded() async {
    if (_chunkCount > 0) return;
    final path = _recordingFilePath;
    if (_wsConnection == null || path == null || path.isEmpty) {
      _log.w('No websocket or recording file available for fallback streaming.');
      return;
    }
    final file = File(path);
    if (!await file.exists()) {
      _log.w('Recording file missing for fallback streaming: $path');
      return;
    }
    try {
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        _log.w('Recording file empty for fallback streaming: $path');
        return;
      }
      const chunkSize = 8192;
      var localChunks = 0;
      for (var offset = 0; offset < bytes.length; offset += chunkSize) {
        final end = math.min(offset + chunkSize, bytes.length);
        final chunk = bytes.sublist(offset, end);
        _wsConnection?.sendBinary(chunk);
        localChunks++;
      }
      _chunkCount = localChunks;
      _log.i(
        'Fallback streamed $_chunkCount chunks from recorded file (${bytes.length} bytes).',
      );
    } catch (e, st) {
      _log.e(
        'Failed to fallback-stream recorded audio file',
        error: e,
        stackTrace: st,
      );
    }
  }

  void _handleServerMessage(VoiceServerMessage message) {
    switch (message.type) {
      case VoiceMessageType.connected:
        final payload = message.data != null ? VoiceConnectedPayload.fromJson(message.data!) : null;
        final formats = payload?.audioFormats ?? const <String>[];
        _preferredContentType = _pickContentType(formats);
        state = state.copyWith(isConnecting: false, audioFormats: formats, errorMessage: null);
        break;
      case VoiceMessageType.voiceResponse:
        final ack = message.data != null
            ? VoiceResponseAck.fromJson(message.data!)
            : const VoiceResponseAck();
        state = state.copyWith(
          isProcessing: false,
          isConnecting: false,
          aiResponse: ack.aiText ?? state.aiResponse,
          userTranscription: ack.transcription ?? state.userTranscription,
          errorMessage: null,
        );
        break;
      case VoiceMessageType.voiceAudioChunk:
        if (message.data != null) {
          unawaited(_handleAudioChunk(VoiceAudioChunk.fromJson(message.data!)));
        }
        break;
      case VoiceMessageType.voiceTranscription:
        final payload = message.data != null
            ? VoiceTranscriptionPayload.fromJson(message.data!)
            : null;
        if (payload != null && payload.text.isNotEmpty) {
          state = state.copyWith(userTranscription: payload.text, errorMessage: null);
        }
        break;
      case VoiceMessageType.error:
        final err = message.data != null
            ? VoiceErrorPayload.fromJson(message.data!)
            : const VoiceErrorPayload();
        _handleSocketError(err.message ?? err.code ?? 'Voice streaming error');
        break;
      case VoiceMessageType.ping:
        _wsConnection?.sendJson({'type': 'pong'});
        break;
      default:
        break;
    }
  }

  Future<void> _handleAudioChunk(VoiceAudioChunk chunk) async {
    _applyExpressionFrames(chunk.frames);

    if (chunk.sequenceId.isNotEmpty && _currentSequenceId != chunk.sequenceId) {
      await _streamPlayer.stop();
      _currentSequenceId = chunk.sequenceId;
    } else if (_currentSequenceId == null && chunk.sequenceId.isNotEmpty) {
      _currentSequenceId = chunk.sequenceId;
    }

    if (chunk.data != null && chunk.data!.isNotEmpty) {
      try {
        await _ensurePlayerReady();
        final bytes = base64Decode(chunk.data!);
        await _streamPlayer.addChunk(bytes);
        state = state.copyWith(
          isPlaying: true,
          isProcessing: false,
          isConnecting: false,
          errorMessage: null,
        );
      } catch (e, st) {
        _handlePlaybackError(e, st);
      }
    }

    if (chunk.isFinal) {
      state = state.copyWith(isProcessing: false, isConnecting: false);
      await _streamPlayer.markComplete();
      _currentSequenceId = null;
      await _disposeSocket();
    }
  }

  void _applyExpressionFrames(List<VoiceExpressionFrame> frames) {
    if (frames.isEmpty) return;
    final latest = frames.lastWhere((f) => f.packedFace.isNotEmpty, orElse: () => frames.last);
    if (latest.packedFace.isEmpty) return;
    final decoded = _decodePackedFace(latest.packedFace);
    if (decoded == null || decoded.isEmpty) return;

    final ts = latest.timestampMs ?? DateTime.now().millisecondsSinceEpoch;
    if (state.faceTimestampMs != null && ts < state.faceTimestampMs!) return;

    state = state.copyWith(currentFaceBitmap: decoded, faceTimestampMs: ts);
  }

  Uint8List? _decodePackedFace(String packed) {
    if (packed.isEmpty) return null;
    if (_faceCache.containsKey(packed)) return _faceCache[packed];

    // Preferred: numeric base-64 RLE (FaceCompressor.encode_to_base64)
    final rleDecoded = _decodeNumericBase64Face(packed);
    if (rleDecoded != null) {
      _cacheFace(packed, rleDecoded);
      return rleDecoded;
    }

    // Fallback: packed bitmap encoded via standard/base64-url
    final normalized = base64.normalize(packed.replaceAll('-', '+').replaceAll('_', '/'));
    try {
      final bytes = _normalizeFaceBits(Uint8List.fromList(base64Decode(normalized)));
      if (bytes != null) {
        _cacheFace(packed, bytes);
        return bytes;
      }
    } catch (_) {}
    try {
      final bytes = _normalizeFaceBits(Uint8List.fromList(base64Url.decode(packed)));
      if (bytes != null) {
        _cacheFace(packed, bytes);
        return bytes;
      }
    } catch (_) {}

    // Fallback: treat as hex string (as emitted by FaceCompressor.pack_bitmap_to_base64)
    final hex = packed.replaceAll(RegExp(r'[^0-9a-fA-F]'), '');
    if (hex.length % 2 != 0 || hex.isEmpty) return null;
    final bytes = Uint8List(hex.length ~/ 2);
    for (var i = 0; i < hex.length; i += 2) {
      final byte = hex.substring(i, i + 2);
      bytes[i ~/ 2] = int.tryParse(byte, radix: 16) ?? 0;
    }
    final normalizedHex = _normalizeFaceBits(bytes);
    if (normalizedHex != null) {
      _cacheFace(packed, normalizedHex);
    }
    return normalizedHex;
  }

  Uint8List? _normalizeFaceBits(Uint8List raw) {
    if (raw.isEmpty) return null;
    const facePixels = 128 * 128;
    const packedLength = facePixels ~/ 8;

    // Already packed to bits (2048 bytes expected).
    if (raw.length == packedLength) return raw;

    // If we have at least one bit per pixel, pack down to bits to keep painting predictable.
    if (raw.length * 8 >= facePixels) {
      final packed = Uint8List(packedLength);
      for (var i = 0; i < facePixels; i++) {
        final byteIndex = i >> 3;
        final bitMask = 1 << (7 - (i & 7));
        final isOn = raw.length >= facePixels ? raw[i] != 0 : (raw[byteIndex] & bitMask) != 0;
        if (isOn) {
          packed[byteIndex] |= bitMask;
        }
      }
      return packed;
    }

    return raw;
  }

  Uint8List? _decodeNumericBase64Face(String data) {
    try {
      final bytes = _base64DigitsToBytes(data);
      if (bytes.isEmpty) return null;

      Uint8List? attemptDecode(Uint8List candidate) {
        var buf = candidate;
        if (buf.length.isEven) {
          buf = Uint8List(buf.length + 1)..setRange(1, buf.length + 1, buf);
        }
        final startBit = buf[0] & 1;
        final runs = <int>[];
        var i = 1;
        while (i + 1 < buf.length) {
          runs.add((buf[i] << 8) | buf[i + 1]);
          i += 2;
        }
        final bitsTotal = runs.fold<int>(0, (acc, v) => acc + v);
        if (bitsTotal != 128 * 128 || runs.any((r) => r <= 0)) {
          return null;
        }
        return _runsToPackedBits(runs, startBit: startBit);
      }

      for (var pad = 0; pad <= 4; pad++) {
        final padded = Uint8List(pad + bytes.length)..setRange(pad, pad + bytes.length, bytes);
        final decoded = attemptDecode(padded);
        if (decoded != null) return decoded;
      }

      // Fallback compatibility from backend: ensure at least a leading start byte
      var fallback = bytes;
      if (fallback.isEmpty || (fallback.first != 0 && fallback.first != 1)) {
        fallback = Uint8List(fallback.length + 1)..setRange(1, fallback.length + 1, fallback);
      }
      if (fallback.length.isEven) {
        fallback = Uint8List(fallback.length + 1)..setRange(1, fallback.length + 1, fallback);
      }
      return attemptDecode(fallback);
    } catch (_) {
      return null;
    }
  }

  Uint8List _runsToPackedBits(List<int> runs, {int startBit = 0}) {
    const facePixels = 128 * 128;
    final packed = Uint8List(facePixels ~/ 8);
    var bit = startBit & 1;
    var bitIndex = 0;
    for (final run in runs) {
      for (var i = 0; i < run; i++) {
        if (bit != 0) {
          final byteIndex = bitIndex >> 3;
          final mask = 1 << (7 - (bitIndex & 7));
          packed[byteIndex] |= mask;
        }
        bitIndex++;
      }
      bit ^= 1;
    }
    return packed;
  }

  Uint8List _base64DigitsToBytes(String input) {
    const alphabet = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-_';
    if (input.isEmpty) return Uint8List(0);
    var n = BigInt.zero;
    for (final ch in input.split('')) {
      final idx = alphabet.indexOf(ch);
      if (idx == -1) throw FormatException('Invalid base64 digit: $ch');
      n = (n * BigInt.from(64)) + BigInt.from(idx);
    }

    final byteLen = (n.bitLength + 7) >> 3;
    if (byteLen == 0) return Uint8List.fromList([0]);

    final bytes = Uint8List(byteLen);
    var temp = n;
    for (var i = 0; i < byteLen; i++) {
      bytes[byteLen - 1 - i] = (temp & BigInt.from(0xFF)).toInt();
      temp = temp >> 8;
    }
    return bytes;
  }

  void _cacheFace(String key, Uint8List face) {
    _faceCache[key] = face;
    const max = 64;
    if (_faceCache.length > max) {
      _faceCache.remove(_faceCache.keys.first);
    }
  }

  Future<void> _ensurePlayerReady() async {
    if (_streamPlayer.hasStream) return;
    await _streamPlayer.start(
      contentType: _preferredContentType,
      onComplete: _handlePlaybackComplete,
      onError: (err, st) => _handlePlaybackError(err, st),
    );
  }

  void _handlePlaybackComplete() {
    state = state.copyWith(
      isPlaying: false,
      currentExpression: RobotExpression.neutral,
      clearFace: true,
    );
  }

  void _handlePlaybackError(Object err, [StackTrace? st]) {
    _log.e('Playback error', error: err, stackTrace: st);
    state = state.copyWith(
      isPlaying: false,
      isProcessing: false,
      isConnecting: false,
      currentExpression: RobotExpression.neutral,
      clearFace: true,
      errorMessage: 'Failed to play audio: $err',
    );
  }

  void _handleSocketError(Object err, [StackTrace? st]) {
    _log.e('Voice websocket error', error: err, stackTrace: st);
    state = state.copyWith(
      isProcessing: false,
      isConnecting: false,
      isPlaying: false,
      clearFace: true,
      errorMessage: '$err',
    );
    unawaited(_disposeSocket());
  }

  void _handleSocketDone() {
    state = state.copyWith(isConnecting: false, isProcessing: false, isPlaying: false);
  }

  Future<void> _disposeSocket() async {
    await _micStreamSubscription?.cancel();
    _micStreamSubscription = null;
    await _micStreamController?.close();
    _micStreamController = null;
    _recordingStartedAt = null;
    _chunkCount = 0;
    await _wsSubscription?.cancel();
    _wsSubscription = null;
    if (_wsConnection != null) {
      try {
        await _wsConnection!.close();
      } catch (_) {}
    }
    _wsConnection = null;
    _currentSequenceId = null;
    _currentRequestId = null;
  }

  Future<String> _ensureDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_deviceIdPrefsKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final generated =
        '${Platform.isIOS ? "ios" : "android"}-${DateTime.now().millisecondsSinceEpoch}-${DateTime.now().microsecondsSinceEpoch.remainder(100000)}';
    await prefs.setString(_deviceIdPrefsKey, generated);
    return generated;
  }

  String _pickContentType(List<String> formats) {
    final lower = formats.map((f) => f.toLowerCase()).toList();
    if (lower.contains('opus')) return 'audio/ogg';
    if (lower.contains('wav')) return 'audio/wav';
    if (lower.contains('mp3')) return 'audio/mpeg';
    return 'audio/wav'; // default to WAV for safety
  }

  String _getContentTypeForEncoding(String encoding) {
    final lower = encoding.toLowerCase();
    if (lower.contains('opus') || lower == 'ogg') return 'audio/ogg';
    if (lower == 'wav') return 'audio/wav';
    if (lower.contains('mp3') || lower == 'mpeg') return 'audio/mpeg';
    return 'audio/wav'; // default to WAV
  }

  /// Cancel current recording
  Future<void> cancelRecording() async {
    try {
      if (state.isRecording) {
        final durationMs = _recordingStartedAt != null
            ? DateTime.now().difference(_recordingStartedAt!).inMilliseconds
            : 0;
        await _audioRecorder?.stopRecorder();
        await _micStreamSubscription?.cancel();
        await _micStreamController?.close();
        _recordingStartedAt = null;
        state = state.copyWith(
          isRecording: false,
          isProcessing: false,
          errorMessage: null,
          clearFace: true,
        );
        _sendVoiceEnd(totalChunks: _chunkCount, durationMs: durationMs);
        await _cleanupRecordingFile();
        _chunkCount = 0;
        _log.i('Recording cancelled');
      }
    } catch (e, stackTrace) {
      _log.e('Failed to cancel recording', error: e, stackTrace: stackTrace);
      state = state.copyWith(isRecording: false, clearFace: true);
    }
  }

  /// Stop audio playback
  Future<void> stopPlayback() async {
    await _streamPlayer.stop();
    await _disposeSocket();
    state = state.copyWith(
      isPlaying: false,
      isProcessing: false,
      isConnecting: false,
      currentExpression: RobotExpression.neutral,
      clearFace: true,
    );
  }

  /// Clear error message
  void clearError() {
    state = state.copyWith(errorMessage: null);
  }
}

/// Provider for voice chat controller
final voiceChatControllerProvider =
    NotifierProvider.autoDispose<VoiceChatController, VoiceChatState>(VoiceChatController.new);
