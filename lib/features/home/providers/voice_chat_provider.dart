import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:logger/logger.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/auth/state/auth_state.dart';
import '../../../core/env/env.dart';
import '../models/expression_models.dart';
import '../services/pcm_audio_player.dart';
import '../services/realtime_voice_client.dart';

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
  final Uint8List? aiAudioBytes;
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
    this.aiAudioBytes,
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
    Uint8List? aiAudioBytes,
    String? errorMessage,
    double? playbackProgress,
    PermissionDialogType? permissionDialog,
    List<String>? audioFormats,
    Uint8List? currentFaceBitmap,
    int? faceTimestampMs,
    bool clearFace = false,
    bool clearAiAudio = false,
  }) {
    return VoiceChatState(
      currentExpression: currentExpression ?? this.currentExpression,
      isRecording: isRecording ?? this.isRecording,
      isPlaying: isPlaying ?? this.isPlaying,
      isConnecting: isConnecting ?? this.isConnecting,
      isProcessing: isProcessing ?? this.isProcessing,
      userTranscription: userTranscription ?? this.userTranscription,
      aiResponse: aiResponse ?? this.aiResponse,
      aiAudioBytes: clearAiAudio ? null : (aiAudioBytes ?? this.aiAudioBytes),
      errorMessage: errorMessage,
      playbackProgress: playbackProgress ?? this.playbackProgress,
      permissionDialog: permissionDialog ?? this.permissionDialog,
      audioFormats: audioFormats ?? this.audioFormats,
      currentFaceBitmap:
          clearFace ? null : (currentFaceBitmap ?? this.currentFaceBitmap),
      faceTimestampMs: clearFace ? null : (faceTimestampMs ?? this.faceTimestampMs),
    );
  }

  bool get isBusy => isRecording || isProcessing || isPlaying || isConnecting;
}

/// Controller for voice chat interactions
class VoiceChatController extends Notifier<VoiceChatState> {
  final Logger _log = Logger();
  final RealtimeVoiceClient _client = RealtimeVoiceClient();
  final PcmAudioPlayer _player = PcmAudioPlayer();
  FlutterSoundRecorder? _recorder;
  StreamSubscription<Map<String, dynamic>>? _socketSub;
  StreamController<Uint8List>? _micStreamController;
  StreamSubscription<Uint8List>? _micStreamSubscription;
  final StringBuffer _aiTextBuffer = StringBuffer();
  Completer<bool>? _permissionDialogCompleter;
  bool _iosPermissionDeniedOnce = false;
  bool _commitSent = false;
  bool _socketOpen = false;

  static const int _sampleRate = 16000;
  static const String _permissionError =
      'Microphone permission is required for voice chat';

  @override
  VoiceChatState build() {
    _recorder = FlutterSoundRecorder();

    ref.onDispose(() async {
      await _stopRecorder();
      await _teardownSocket();
      await _player.dispose();
    });

    return const VoiceChatState();
  }

  /// Start recording user voice and streaming it to the realtime endpoint.
  Future<void> startRecording() async {
    try {
      if (state.isBusy) {
        _log.w('Cannot start recording: already busy');
        return;
      }

      final hasPermission = await _ensureMicrophonePermission();
      if (!hasPermission) return;

      final token =
          ref.read(authControllerProvider.notifier).tokens?.accessToken ?? '';
      if (token.isEmpty) {
        throw VoiceChatException('You must be logged in to use voice chat');
      }

      _aiTextBuffer.clear();
      _commitSent = false;

      state = state.copyWith(
        isConnecting: true,
        isProcessing: false,
        isPlaying: false,
        aiResponse: null,
        userTranscription: null,
        clearAiAudio: true,
        errorMessage: null,
        clearFace: true,
      );

      await _connectSocket(token);
      await _startRecorder();
      _log.i('Voice session started');
    } catch (e, st) {
      _log.e('Failed to start recording', error: e, stackTrace: st);
      state = state.copyWith(
        isRecording: false,
        isProcessing: false,
        isConnecting: false,
        isPlaying: false,
        errorMessage: '$e',
      );
      await _teardownSocket();
    }
  }

  Future<void> _connectSocket(String token) async {
    final uri = await _voiceUri(token);
    if (uri == null) {
      throw VoiceChatException('Voice websocket URL is missing or invalid');
    }

    await _teardownSocket();

    _log.i('Connecting to realtime voice socket $uri');
    await _client.connect(uri);
    _socketOpen = true;
    _socketSub = _client.messages.listen(
      _handleIncomingMessage,
      onError: (err, st) => unawaited(
        _handleSocketError(err, st is StackTrace ? st : null),
      ),
      onDone: _handleSocketClosed,
      cancelOnError: true,
    );
  }

  Future<Uri?> _voiceUri(String token) async {
    await AppEnv.load();
    final raw = AppEnv.voiceRealtimeWsUrl.trim();
    if (raw.isEmpty) return null;
    Uri? uri;
    try {
      uri = Uri.parse(raw);
    } catch (_) {
      return null;
    }
    if (uri.scheme == 'https') uri = uri.replace(scheme: 'wss');
    if (uri.scheme == 'http') uri = uri.replace(scheme: 'ws');
    if (uri.hasFragment) uri = uri.replace(fragment: '');
    final qp = Map<String, String>.from(uri.queryParameters);
    if (token.isNotEmpty) {
      qp.putIfAbsent('token', () => token);
    }
    return uri.replace(queryParameters: qp);
  }

  Future<void> _startRecorder() async {
    try {
      await _stopRecorder();
      if (_recorder == null) {
        _recorder = FlutterSoundRecorder();
      }
      if (!_recorder!.isRecording) {
        await _recorder!.openRecorder();
      }

      await _micStreamSubscription?.cancel();
      await _micStreamController?.close();
      _micStreamController = StreamController<Uint8List>();
      _micStreamSubscription = _micStreamController!.stream.listen(
        _handleMicChunk,
        onError: (err, st) => unawaited(
          _handleSocketError(err, st is StackTrace ? st : null),
        ),
      );

      await _recorder!.startRecorder(
        toStream: _micStreamController!.sink,
        codec: Codec.pcm16,
        numChannels: 1,
        sampleRate: _sampleRate,
        bitRate: _sampleRate * 16,
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
      await _stopRecorder();
      state = state.copyWith(
        isRecording: false,
        isProcessing: false,
        isConnecting: false,
        isPlaying: false,
        clearFace: true,
        errorMessage: 'Failed to start recording: $e',
      );
      await _teardownSocket();
    }
  }

  void _handleMicChunk(Uint8List bytes) {
    if (bytes.isEmpty || !_socketOpen) return;
    final payload = {
      'type': 'input_audio_buffer.append',
      'audio': base64Encode(bytes),
    };
    _client.send(payload);
  }

  /// Stop recording and tell backend the input is finished.
  Future<void> stopRecordingAndSend() async {
    try {
      if (!state.isRecording) {
        _log.w('Cannot stop recording: not recording');
        return;
      }

      await _stopRecorder();
      _commitInput();
      state = state.copyWith(
        isRecording: false,
        isProcessing: true,
        isPlaying: false,
        isConnecting: false,
        errorMessage: null,
      );
    } catch (e, st) {
      _log.e('Failed to stop recording', error: e, stackTrace: st);
      state = state.copyWith(
        isRecording: false,
        isProcessing: false,
        isConnecting: false,
        isPlaying: false,
        clearAiAudio: true,
        clearFace: true,
        errorMessage: 'Failed to process voice: $e',
      );
      await _teardownSocket();
    }
  }

  Future<void> _stopRecorder() async {
    try {
      await _recorder?.stopRecorder();
    } catch (_) {}
    await _micStreamSubscription?.cancel();
    _micStreamSubscription = null;
    await _micStreamController?.close();
    _micStreamController = null;
  }

  void _commitInput() {
    if (_commitSent || !_socketOpen) return;
    _client.send({'type': 'input_audio_buffer.commit'});
    _commitSent = true;
  }

  void _handleIncomingMessage(Map<String, dynamic> message) {
    final type = (message['type'] as String?) ?? '';
    _log.t('Voice socket message type=$type');
    switch (type) {
      case 'output_audio.delta':
        final audio = message['audio'] as String?;
        if (audio != null && audio.isNotEmpty) {
          unawaited(_handleAudioDelta(audio));
        }
        break;
      case 'response.output_text.delta':
        final text = message['text'] as String? ?? '';
        if (text.isNotEmpty) {
          _aiTextBuffer.write(text);
          state = state.copyWith(aiResponse: _aiTextBuffer.toString());
        }
        state = state.copyWith(isProcessing: false, isConnecting: false);
        break;
      default:
        break;
    }
  }

  Future<void> _handleAudioDelta(String base64Audio) async {
    try {
      final normalized = base64.normalize(base64Audio);
      final bytes = base64Decode(normalized);
      if (bytes.isEmpty) return;

      await _player.addChunk(
        bytes,
        sampleRate: _sampleRate,
        onFinished: _handlePlaybackComplete,
      );
      state = state.copyWith(
        isPlaying: true,
        isProcessing: false,
        isConnecting: false,
        errorMessage: null,
      );
    } catch (e, st) {
      _log.e('Playback error', error: e, stackTrace: st);
      state = state.copyWith(
        isPlaying: false,
        isProcessing: false,
        isConnecting: false,
        currentExpression: RobotExpression.neutral,
        clearFace: true,
        errorMessage: 'Failed to play audio: $e',
      );
    }
  }

  void _handlePlaybackComplete() {
    state = state.copyWith(
      isPlaying: false,
      isProcessing: false,
      currentExpression: RobotExpression.neutral,
      clearFace: true,
    );
  }

  Future<void> _handleSocketError(Object err, [StackTrace? st]) async {
    _log.e('Voice websocket error', error: err, stackTrace: st);
    state = state.copyWith(
      isProcessing: false,
      isConnecting: false,
      isPlaying: false,
      isRecording: false,
      clearFace: true,
      errorMessage: '$err',
    );
    await _teardownSocket();
  }

  void _handleSocketClosed() {
    _log.i('Voice websocket closed');
    _socketOpen = false;
    unawaited(_player.stop());
    _socketSub = null;
    state = state.copyWith(
      isConnecting: false,
      isProcessing: false,
      isPlaying: false,
      isRecording: false,
    );
  }

  /// Cancel current recording and tear down the current session.
  Future<void> cancelRecording() async {
    await _stopRecorder();
    await _player.stop();
    await _teardownSocket();
    _aiTextBuffer.clear();
    _commitSent = false;
    state = state.copyWith(
      isRecording: false,
      isProcessing: false,
      isConnecting: false,
      isPlaying: false,
      aiResponse: null,
      userTranscription: null,
      clearAiAudio: true,
      clearFace: true,
      errorMessage: null,
    );
  }

  /// Stop audio playback
  Future<void> stopPlayback() async {
    await _player.stop();
    await _teardownSocket();
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
    if (_permissionDialogCompleter != null &&
        !_permissionDialogCompleter!.isCompleted) {
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
    if (_permissionDialogCompleter != null &&
        !_permissionDialogCompleter!.isCompleted) {
      _permissionDialogCompleter!.complete(accepted);
    }
    _permissionDialogCompleter = null;
    _resetPermissionDialogState();
  }

  void dismissPermissionDialog() {
    if (_permissionDialogCompleter != null &&
        !_permissionDialogCompleter!.isCompleted) {
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

  Future<void> _teardownSocket() async {
    _socketOpen = false;
    await _socketSub?.cancel();
    _socketSub = null;
    await _client.close();
  }
}

class VoiceChatException implements Exception {
  VoiceChatException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Provider for voice chat controller
final voiceChatControllerProvider =
    NotifierProvider.autoDispose<VoiceChatController, VoiceChatState>(
      VoiceChatController.new,
    );
