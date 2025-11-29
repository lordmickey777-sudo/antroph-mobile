import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
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
  bool _iosPermissionDeniedOnce = false;
  Completer<bool>? _permissionDialogCompleter;
  String? _currentSequenceId;
  String _preferredContentType = 'audio/mpeg';
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

      // Get temporary directory for recording
      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/voice_input_${DateTime.now().millisecondsSinceEpoch}.wav';

      // Start recording
      await _audioRecorder!.startRecorder(
        toFile: filePath,
        codec: Codec.pcm16WAV,
        numChannels: 1,
        sampleRate: 16000,
      );

      state = state.copyWith(isRecording: true, errorMessage: null);
      _log.i('Recording started: $filePath');
    } catch (e, stackTrace) {
      _log.e('Failed to start recording', error: e, stackTrace: stackTrace);
      state = state.copyWith(isRecording: false, errorMessage: 'Failed to start recording: $e');
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

  /// Stop recording and send to backend
  Future<void> stopRecordingAndSend() async {
    try {
      if (!state.isRecording) {
        _log.w('Cannot stop recording: not recording');
        return;
      }

      // Stop recording
      final path = await _audioRecorder?.stopRecorder();
      state = state.copyWith(
        isRecording: false,
        isProcessing: true,
        isPlaying: false,
        isConnecting: true,
        errorMessage: null,
        aiResponse: null,
        userTranscription: null,
        clearFace: true,
      );

      if (path == null || path.isEmpty) {
        throw Exception('Recording failed: no file path returned');
      }

      _log.i('Recording stopped: $path');

      final audioFile = File(path);
      if (!await audioFile.exists()) {
        throw Exception('Recording file not found');
      }

      await _streamPlayer.stop();
      await _disposeSocket();

      final token = ref.read(authControllerProvider.notifier).tokens?.accessToken ?? '';
      if (token.isEmpty) {
        throw VoiceChatException('You must be logged in to use voice chat');
      }

      final deviceId = await _ensureDeviceId();
      final deviceType = Platform.isIOS ? 'ios' : 'android';
      final audioBytes = await audioFile.readAsBytes();
      final requestId = 'upload-${DateTime.now().millisecondsSinceEpoch}';

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

      _preferredContentType = _pickContentType(state.audioFormats);
      state = state.copyWith(isConnecting: false);

      _wsConnection!.sendJson({
        'type': 'voice_upload',
        'data': {
          'data': base64Encode(audioBytes),
          'encoding': 'wav',
          'language': 'en',
          'tts_voice': 'nova',
        },
        'request_id': requestId,
      });
      _log.i('Voice upload sent (${audioBytes.length} bytes)');

      audioFile.delete().catchError((e) {
        _log.w('Failed to delete recording file: $e');
        return audioFile;
      });
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

  void _handleServerMessage(VoiceServerMessage message) {
    switch (message.type) {
      case VoiceMessageType.connected:
        final payload = message.data != null ? VoiceConnectedPayload.fromJson(message.data!) : null;
        final formats = payload?.audioFormats ?? const <String>[];
        _preferredContentType = _pickContentType(formats);
        state = state.copyWith(
          isConnecting: false,
          audioFormats: formats,
          errorMessage: null,
        );
        break;
      case VoiceMessageType.voiceResponse:
        final ack = message.data != null ? VoiceResponseAck.fromJson(message.data!) : const VoiceResponseAck();
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
      case VoiceMessageType.error:
        final err = message.data != null ? VoiceErrorPayload.fromJson(message.data!) : const VoiceErrorPayload();
        _handleSocketError(err.message ?? err.code ?? 'Voice streaming error');
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
        state = state.copyWith(isPlaying: true, isProcessing: false, isConnecting: false, errorMessage: null);
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

    state = state.copyWith(
      currentFaceBitmap: decoded,
      faceTimestampMs: ts,
    );
  }

  Uint8List? _decodePackedFace(String packed) {
    if (packed.isEmpty) return null;
    // Try standard/base64-url decoding first.
    final normalized = base64.normalize(packed.replaceAll('-', '+').replaceAll('_', '/'));
    try {
      return Uint8List.fromList(base64Decode(normalized));
    } catch (_) {}
    try {
      return Uint8List.fromList(base64Url.decode(packed));
    } catch (_) {}

    // Fallback: treat as hex string (as emitted by FaceCompressor).
    final hex = packed.replaceAll(RegExp(r'[^0-9a-fA-F]'), '');
    if (hex.length % 2 != 0 || hex.isEmpty) return null;
    final bytes = Uint8List(hex.length ~/ 2);
    for (var i = 0; i < hex.length; i += 2) {
      final byte = hex.substring(i, i + 2);
      bytes[i ~/ 2] = int.tryParse(byte, radix: 16) ?? 0;
    }
    return bytes;
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
    state = state.copyWith(isConnecting: false, isProcessing: false);
  }

  Future<void> _disposeSocket() async {
    await _wsSubscription?.cancel();
    _wsSubscription = null;
    if (_wsConnection != null) {
      try {
        await _wsConnection!.close();
      } catch (_) {}
    }
    _wsConnection = null;
    _currentSequenceId = null;
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
    if (lower.contains('mp3')) return 'audio/mpeg';
    return 'audio/mpeg';
  }

  /// Cancel current recording
  Future<void> cancelRecording() async {
    try {
      if (state.isRecording) {
        final path = await _audioRecorder?.stopRecorder();
        if (path != null && path.isNotEmpty) {
          File(path).delete().catchError((e) {
            _log.w('Failed to delete cancelled recording: $e');
            return File(path);
          });
        }
        state = state.copyWith(isRecording: false, errorMessage: null, clearFace: true);
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
